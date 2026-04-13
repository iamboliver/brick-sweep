import Foundation
import SwiftData

struct SetImportService: Sendable {
    private let apiClient: RebrickableAPIClientProtocol
    private let rebrickableBase = "https://rebrickable.com/api/v3/lego/"

    init(apiClient: RebrickableAPIClientProtocol) {
        self.apiClient = apiClient
    }

    static func normalizeSetNum(_ input: String) -> String {
        let trimmed = input.trimmingCharacters(in: .whitespaces)
        if trimmed.contains("-") {
            return trimmed
        }
        return "\(trimmed)-1"
    }

    // MARK: - Phase 1: create the set record and return immediately

    @MainActor
    func createSet(setNum: String, modelContext: ModelContext) async throws -> LegoSet {
        let normalized = Self.normalizeSetNum(setNum)

        let descriptor = FetchDescriptor<LegoSet>(
            predicate: #Predicate { $0.setNum == normalized }
        )
        let existing = try modelContext.fetch(descriptor)
        if let existingSet = existing.first {
            return existingSet
        }

        let setDTO = try await apiClient.fetchSet(setNum: normalized)

        let legoSet = LegoSet(
            setNum: setDTO.setNum,
            name: setDTO.name,
            year: setDTO.year,
            numParts: setDTO.numParts,
            imageUrl: setDTO.setImgUrl,
            isImporting: true
        )
        modelContext.insert(legoSet)
        try modelContext.save()
        return legoSet
    }

    // MARK: - Phase 2: page-by-page parts load

    @MainActor
    func loadParts(into legoSet: LegoSet, setNum: String, modelContext: ModelContext) async throws {
        async let minifigsFetch = apiClient.fetchSetMinifigs(setNum: setNum)

        do {
            var nextURL: String? =
                "\(rebrickableBase)sets/\(setNum)/parts/?page_size=500&inc_color_details=1&inc_part_details=1&inc_minifig_parts=1"

            while let url = nextURL {
                let page = try await apiClient.fetchSetPartsPage(urlString: url)
                for partDTO in page.results where !partDTO.isSpare {
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
                }
                try modelContext.save()
                nextURL = page.next
            }

            let minifigsDTO = try await minifigsFetch
            for minifigDTO in minifigsDTO {
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
            }
            try modelContext.save()

            legoSet.isImporting = false
            try modelContext.save()
        } catch {
            modelContext.delete(legoSet)
            try? modelContext.save()
            throw error
        }
    }

    // MARK: - Combined (kept for test compatibility)

    @MainActor
    func importSet(setNum: String, modelContext: ModelContext) async throws -> LegoSet {
        let set = try await createSet(setNum: setNum, modelContext: modelContext)
        try await loadParts(into: set, setNum: set.setNum, modelContext: modelContext)
        return set
    }
}
