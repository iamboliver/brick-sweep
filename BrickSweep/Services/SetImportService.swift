import Foundation
import SwiftData

/// What happened when the user asked to add a set.
enum SetAddOutcome {
    /// A new set record was created; its parts still need loading.
    case created(LegoSet)
    /// The set is already in the collection and fully imported. Nothing to load.
    case alreadyInCollection(LegoSet)
    /// The set exists but its import failed or never finished; it should be retried.
    case needsRetry(LegoSet)
}

struct SetImportService: Sendable {
    private let apiClient: RebrickableAPIClientProtocol
    private let themeNameCache: ThemeNameCache
    private static let rebrickableBase = "https://rebrickable.com/api/v3/lego/"

    init(apiClient: RebrickableAPIClientProtocol, themeNameCache: ThemeNameCache = .shared) {
        self.apiClient = apiClient
        self.themeNameCache = themeNameCache
    }

    static func normalizeSetNum(_ input: String) -> String {
        let trimmed = input.trimmingCharacters(in: .whitespaces)
        if trimmed.contains("-") {
            return trimmed
        }
        return "\(trimmed)-1"
    }

    static func partsPageURL(setNum: String) -> String {
        "\(rebrickableBase)sets/\(setNum)/parts/?page_size=500&inc_color_details=1&inc_part_details=1&inc_minifig_parts=1"
    }

    // MARK: - Phase 1: create the set record and return immediately

    /// Finds a stored set by number, ignoring letter case ("abc-1" finds "ABC-1").
    @MainActor
    func existingSet(setNum: String, modelContext: ModelContext) throws -> LegoSet? {
        let normalized = Self.normalizeSetNum(setNum)
        let descriptor = FetchDescriptor<LegoSet>(
            predicate: #Predicate { $0.setNum.localizedStandardContains(normalized) }
        )
        return try modelContext.fetch(descriptor).first {
            $0.setNum.caseInsensitiveCompare(normalized) == .orderedSame
        }
    }

    @MainActor
    func createSet(setNum: String, modelContext: ModelContext) async throws -> SetAddOutcome {
        let normalized = Self.normalizeSetNum(setNum)
        if let existing = try existingSet(setNum: normalized, modelContext: modelContext) {
            return Self.outcome(forExisting: existing)
        }

        let setDTO = try await apiClient.fetchSet(setNum: normalized)
        let themeName: String? = if let themeId = setDTO.themeId {
            await themeNameCache.topLevelName(for: themeId, apiClient: apiClient)
        } else {
            nil
        }

        let legoSet = LegoSet(
            setNum: setDTO.setNum,
            name: setDTO.name,
            year: setDTO.year,
            themeId: setDTO.themeId,
            themeName: themeName,
            numParts: setDTO.numParts,
            imageUrl: setDTO.setImgUrl,
            isImporting: true
        )

        // Check again right before inserting, with no suspension in between: another
        // add of the same set may have inserted it while we awaited the API, and the
        // canonical number can differ from what was typed. setNum is unique, so a
        // second insert would merge into that record and re-import its parts on top.
        if let existing = try existingSet(setNum: setDTO.setNum, modelContext: modelContext) {
            return Self.outcome(forExisting: existing)
        }
        modelContext.insert(legoSet)
        try modelContext.save()
        return .created(legoSet)
    }

    private static func outcome(forExisting legoSet: LegoSet) -> SetAddOutcome {
        legoSet.isImporting || legoSet.importFailed ? .needsRetry(legoSet) : .alreadyInCollection(legoSet)
    }

    // MARK: - Phase 2: page-by-page parts load

    /// Identifies one logical part row: a part number in a colour. Minifigures use
    /// LegoColorSortOrder.minifigColorId so they never collide with real colours.
    private struct PartKey: Hashable {
        let partNum: String
        let colorId: Int
    }

    /// Merges a downloaded inventory into the rows already stored for a set.
    ///
    /// Rows for the same part and colour are reused, so missing and replaced counts
    /// survive a retry. Stored rows the new inventory no longer contains are removed
    /// only once the download completes, so a failed retry loses nothing. Extra copies
    /// of one part (left by the 1.0 duplicate-import bug) are folded into a single row.
    @MainActor
    private final class InventoryMerge {
        private let legoSet: LegoSet
        private let modelContext: ModelContext
        private var reusable: [PartKey: LegoPartInstance] = [:]
        private var seen: [PartKey: LegoPartInstance] = [:]
        /// New quantities for reused rows, applied when the download completes so a
        /// failed retry leaves those rows exactly as they were.
        private var reusedQuantities: [PartKey: Int] = [:]

        init(legoSet: LegoSet, modelContext: ModelContext) {
            self.legoSet = legoSet
            self.modelContext = modelContext
            for row in legoSet.parts {
                let key = PartKey(partNum: row.partNum, colorId: row.colorId)
                if let kept = reusable[key] {
                    kept.missingQty += row.missingQty
                    kept.replacedQty += row.replacedQty
                    modelContext.delete(row)
                } else {
                    reusable[key] = row
                }
            }
        }

        func add(_ key: PartKey, quantity: Int, makeRow: () -> LegoPartInstance) {
            if let row = seen[key] {
                if reusedQuantities[key] != nil {
                    reusedQuantities[key, default: 0] += quantity
                } else {
                    row.requiredQty += quantity
                }
            } else if let reused = reusable.removeValue(forKey: key) {
                seen[key] = reused
                reusedQuantities[key] = quantity
            } else {
                let row = makeRow()
                row.set = legoSet
                modelContext.insert(row)
                seen[key] = row
            }
        }

        /// Call once every page has downloaded.
        func finish() {
            for (key, quantity) in reusedQuantities {
                seen[key]?.requiredQty = quantity
            }
            for row in seen.values {
                row.missingQty = min(row.missingQty, row.requiredQty)
                row.replacedQty = min(row.replacedQty, row.requiredQty)
            }
            reusable.values.forEach { modelContext.delete($0) }
            reusable.removeAll()
        }
    }

    /// Loads the set's full inventory, merging into any rows already stored for it:
    /// calling it again never duplicates rows and never discards the user's counts
    /// for parts that are still in the inventory.
    @MainActor
    func loadParts(into legoSet: LegoSet, setNum: String, modelContext: ModelContext) async throws {
        let merge = InventoryMerge(legoSet: legoSet, modelContext: modelContext)
        async let minifigsFetch = apiClient.fetchSetMinifigs(setNum: setNum)

        do {
            var nextURL: String? = Self.partsPageURL(setNum: setNum)

            while let url = nextURL {
                let page = try await apiClient.fetchSetPartsPage(urlString: url)
                for partDTO in page.results where !partDTO.isSpare {
                    let key = PartKey(partNum: partDTO.part.partNum, colorId: partDTO.color.id)
                    merge.add(key, quantity: partDTO.quantity) {
                        LegoPartInstance(
                            partNum: partDTO.part.partNum,
                            colorId: partDTO.color.id,
                            colorName: partDTO.color.name,
                            colorRgb: partDTO.color.rgb,
                            name: partDTO.part.name,
                            imageUrl: partDTO.part.partImgUrl,
                            requiredQty: partDTO.quantity,
                            isSpare: false,
                            elementId: partDTO.elementId,
                            brickLinkPartNum: partDTO.part.externalIds?.brickLink?.first,
                            brickLinkColorId: partDTO.color.externalIds?.brickLink?.extIds?.first
                        )
                    }
                }
                try modelContext.save()
                nextURL = page.next
            }

            let minifigsDTO = try await minifigsFetch
            for minifigDTO in minifigsDTO {
                let key = PartKey(partNum: minifigDTO.setNum, colorId: LegoColorSortOrder.minifigColorId)
                merge.add(key, quantity: minifigDTO.quantity) {
                    LegoPartInstance(
                        partNum: minifigDTO.setNum,
                        colorId: LegoColorSortOrder.minifigColorId,
                        colorName: "Minifigure",
                        colorRgb: "FEC400",
                        name: minifigDTO.setName,
                        imageUrl: minifigDTO.setImgUrl,
                        requiredQty: minifigDTO.quantity,
                        isSpare: false
                    )
                }
            }
            merge.finish()

            legoSet.isImporting = false
            legoSet.importFailed = false
            try modelContext.save()
        } catch {
            legoSet.importFailed = true
            try? modelContext.save()
            throw error
        }
    }

    // MARK: - Retry: download again, keeping counts for parts still in the inventory

    @MainActor
    func retryLoadParts(into legoSet: LegoSet, modelContext: ModelContext) async throws {
        legoSet.importFailed = false
        legoSet.isImporting = true
        try modelContext.save()
        try await loadParts(into: legoSet, setNum: legoSet.setNum, modelContext: modelContext)
    }

    @MainActor
    func refreshThemeMetadata(for sets: [LegoSet], modelContext: ModelContext) async {
        for legoSet in sets where legoSet.themeId == nil || legoSet.themeName == nil {
            do {
                let setDTO = try await apiClient.fetchSet(setNum: legoSet.setNum)
                legoSet.themeId = setDTO.themeId
                if let themeId = setDTO.themeId {
                    legoSet.themeName = await themeNameCache.topLevelName(for: themeId, apiClient: apiClient)
                }
                try modelContext.save()
            } catch {
                continue
            }
        }
    }

    // MARK: - Combined (kept for test compatibility)

    @MainActor
    func importSet(setNum: String, modelContext: ModelContext) async throws -> LegoSet {
        switch try await createSet(setNum: setNum, modelContext: modelContext) {
        case .created(let set):
            try await loadParts(into: set, setNum: set.setNum, modelContext: modelContext)
            return set
        case .needsRetry(let set):
            try await retryLoadParts(into: set, modelContext: modelContext)
            return set
        case .alreadyInCollection(let set):
            return set
        }
    }
}
