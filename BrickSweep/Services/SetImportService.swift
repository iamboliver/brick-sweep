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
    private let setDataClient: SetDataClientProtocol?
    private let usesOwnAPIKey: @Sendable () -> Bool
    private let themeNameCache: ThemeNameCache
    private static let rebrickableBase = "https://rebrickable.com/api/v3/lego/"

    /// - Parameters:
    ///   - setDataClient: BrickSweep's daily data files. When nil, every import uses the API.
    ///   - usesOwnAPIKey: True when the user has their own verified Rebrickable key; they
    ///     keep importing straight from the API. Checked on every import.
    init(
        apiClient: RebrickableAPIClientProtocol,
        setDataClient: SetDataClientProtocol? = nil,
        usesOwnAPIKey: @escaping @Sendable () -> Bool = { true },
        themeNameCache: ThemeNameCache = .shared
    ) {
        self.apiClient = apiClient
        self.setDataClient = setDataClient
        self.usesOwnAPIKey = usesOwnAPIKey
        self.themeNameCache = themeNameCache
    }

    /// The data files, when this import should use them instead of the API.
    private var dataFiles: SetDataClientProtocol? {
        guard let setDataClient, !usesOwnAPIKey() else { return nil }
        return setDataClient
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

        let legoSet = try await fetchNewSet(setNum: normalized)

        // Check again right before inserting, with no suspension in between: another
        // add of the same set may have inserted it while we awaited the download, and
        // the canonical number can differ from what was typed. setNum is unique, so a
        // second insert would merge into that record and re-import its parts on top.
        if let existing = try existingSet(setNum: legoSet.setNum, modelContext: modelContext) {
            return Self.outcome(forExisting: existing)
        }
        modelContext.insert(legoSet)
        try modelContext.save()
        return .created(legoSet)
    }

    /// Downloads a set's details into a new, not yet inserted, record.
    @MainActor
    private func fetchNewSet(setNum: String) async throws -> LegoSet {
        if let dataFiles {
            let info = try await dataFiles.fetchSetFile(setNum: setNum).set
            return LegoSet(
                setNum: info.setNum,
                name: info.name,
                year: info.year,
                themeId: info.themeId,
                themeName: info.themeName,
                numParts: info.numParts,
                imageUrl: info.imgUrl,
                isImporting: true
            )
        }

        let setDTO = try await apiClient.fetchSet(setNum: setNum)
        let themeName: String? = if let themeId = setDTO.themeId {
            await themeNameCache.topLevelName(for: themeId, apiClient: apiClient)
        } else {
            nil
        }
        return LegoSet(
            setNum: setDTO.setNum,
            name: setDTO.name,
            year: setDTO.year,
            themeId: setDTO.themeId,
            themeName: themeName,
            numParts: setDTO.numParts,
            imageUrl: setDTO.setImgUrl,
            isImporting: true
        )
    }

    private static func outcome(forExisting legoSet: LegoSet) -> SetAddOutcome {
        legoSet.isImporting || legoSet.importFailed ? .needsRetry(legoSet) : .alreadyInCollection(legoSet)
    }

    // MARK: - Phase 2: parts load (page by page from the API, or one data file)

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
                    Self.capCounts(of: kept)
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

        /// Keeps missing + replaced within the required quantity. Missing wins: it
        /// drives the shopping list and completion, while replaced is a record of
        /// pieces already bought (and moves back to missing if a replacement is undone,
        /// so the sum must never exceed what the set needs).
        static func capCounts(of row: LegoPartInstance) {
            row.missingQty = max(0, min(row.missingQty, row.requiredQty))
            row.replacedQty = max(0, min(row.replacedQty, row.requiredQty - row.missingQty))
        }

        /// Call once every page has downloaded.
        func finish() {
            for (key, quantity) in reusedQuantities {
                seen[key]?.requiredQty = quantity
            }
            seen.values.forEach(Self.capCounts)
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

        do {
            if let dataFiles {
                let file = try await dataFiles.fetchSetFile(setNum: setNum)
                Self.add(file, to: merge)
            } else {
                try await addFromAPI(setNum: setNum, to: merge, modelContext: modelContext)
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

    @MainActor
    private func addFromAPI(setNum: String, to merge: InventoryMerge, modelContext: ModelContext) async throws {
        async let minifigsFetch = apiClient.fetchSetMinifigs(setNum: setNum)
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

        for minifigDTO in try await minifigsFetch {
            Self.addMinifig(
                figNum: minifigDTO.setNum, name: minifigDTO.setName,
                imageUrl: minifigDTO.setImgUrl, quantity: minifigDTO.quantity, to: merge
            )
        }
    }

    /// Applies the same rules as the API path: spares dropped, rows for one part and
    /// colour summed, one row per minifigure. The file has no BrickLink colour IDs;
    /// exports fall back to the bundled colour mapping.
    @MainActor
    private static func add(_ file: SetDataFile, to merge: InventoryMerge) {
        for part in file.parts where !part.isSpare {
            merge.add(PartKey(partNum: part.partNum, colorId: part.colorId), quantity: part.quantity) {
                LegoPartInstance(
                    partNum: part.partNum,
                    colorId: part.colorId,
                    colorName: part.colorName,
                    colorRgb: part.rgb,
                    name: part.name,
                    imageUrl: part.imgUrl,
                    requiredQty: part.quantity,
                    isSpare: false,
                    elementId: part.elementId,
                    brickLinkPartNum: part.bricklinkPartNum
                )
            }
        }
        for minifig in file.minifigs {
            addMinifig(figNum: minifig.figNum, name: minifig.name, imageUrl: minifig.imgUrl, quantity: minifig.quantity, to: merge)
        }
    }

    @MainActor
    private static func addMinifig(figNum: String, name: String, imageUrl: String?, quantity: Int, to merge: InventoryMerge) {
        let key = PartKey(partNum: figNum, colorId: LegoColorSortOrder.minifigColorId)
        merge.add(key, quantity: quantity) {
            LegoPartInstance(
                partNum: figNum,
                colorId: LegoColorSortOrder.minifigColorId,
                colorName: "Minifigure",
                colorRgb: "FEC400",
                name: name,
                imageUrl: imageUrl,
                requiredQty: quantity,
                isSpare: false
            )
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
                if let dataFiles {
                    let info = try await dataFiles.fetchSetFile(setNum: legoSet.setNum).set
                    legoSet.themeId = info.themeId
                    legoSet.themeName = info.themeName
                } else {
                    let setDTO = try await apiClient.fetchSet(setNum: legoSet.setNum)
                    legoSet.themeId = setDTO.themeId
                    if let themeId = setDTO.themeId {
                        legoSet.themeName = await themeNameCache.topLevelName(for: themeId, apiClient: apiClient)
                    }
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
