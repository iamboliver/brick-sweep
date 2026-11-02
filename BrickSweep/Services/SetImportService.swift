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

    @MainActor
    func existingSet(setNum: String, modelContext: ModelContext) throws -> LegoSet? {
        let normalized = Self.normalizeSetNum(setNum)
        let descriptor = FetchDescriptor<LegoSet>(
            predicate: #Predicate { $0.setNum == normalized }
        )
        return try modelContext.fetch(descriptor).first
    }

    @MainActor
    func createSet(setNum: String, modelContext: ModelContext) async throws -> SetAddOutcome {
        let normalized = Self.normalizeSetNum(setNum)
        if let existing = try existingSet(setNum: normalized, modelContext: modelContext) {
            return Self.outcome(forExisting: existing)
        }

        let setDTO = try await apiClient.fetchSet(setNum: normalized)

        // Rebrickable's canonical number can differ from what was typed (e.g. "abc-1"
        // vs "ABC-1"). setNum is unique, so inserting a second record would merge into
        // the existing one and its parts would be imported again on top.
        if let existing = try existingSet(setNum: setDTO.setNum, modelContext: modelContext) {
            return Self.outcome(forExisting: existing)
        }
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

    /// Loads the set's full inventory, replacing any parts already stored for it, so
    /// calling it again can never leave duplicate rows.
    @MainActor
    func loadParts(into legoSet: LegoSet, setNum: String, modelContext: ModelContext) async throws {
        if !legoSet.parts.isEmpty {
            legoSet.parts.forEach { modelContext.delete($0) }
            try modelContext.save()
        }

        async let minifigsFetch = apiClient.fetchSetMinifigs(setNum: setNum)

        do {
            // One row per part and colour, summed across pages and sub-inventories
            var seen: [PartKey: LegoPartInstance] = [:]

            var nextURL: String? = Self.partsPageURL(setNum: setNum)

            while let url = nextURL {
                let page = try await apiClient.fetchSetPartsPage(urlString: url)
                for partDTO in page.results where !partDTO.isSpare {
                    let key = PartKey(partNum: partDTO.part.partNum, colorId: partDTO.color.id)
                    if let existing = seen[key] {
                        existing.requiredQty += partDTO.quantity
                    } else {
                        let part = LegoPartInstance(
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
                        part.set = legoSet
                        modelContext.insert(part)
                        seen[key] = part
                    }
                }
                try modelContext.save()
                nextURL = page.next
            }

            let minifigsDTO = try await minifigsFetch
            for minifigDTO in minifigsDTO {
                let key = PartKey(partNum: minifigDTO.setNum, colorId: LegoColorSortOrder.minifigColorId)
                if let existing = seen[key] {
                    existing.requiredQty += minifigDTO.quantity
                } else {
                    let minifig = LegoPartInstance(
                        partNum: minifigDTO.setNum,
                        colorId: LegoColorSortOrder.minifigColorId,
                        colorName: "Minifigure",
                        colorRgb: "FEC400",
                        name: minifigDTO.setName,
                        imageUrl: minifigDTO.setImgUrl,
                        requiredQty: minifigDTO.quantity,
                        isSpare: false
                    )
                    minifig.set = legoSet
                    modelContext.insert(minifig)
                    seen[key] = minifig
                }
            }
            try modelContext.save()

            legoSet.isImporting = false
            legoSet.importFailed = false
            try modelContext.save()
        } catch {
            legoSet.importFailed = true
            try? modelContext.save()
            throw error
        }
    }

    // MARK: - Retry: re-import from scratch (loadParts clears existing parts)

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
