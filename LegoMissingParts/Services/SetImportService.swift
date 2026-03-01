import Foundation
import SwiftData

struct SetImportService: Sendable {
    private let apiClient: RebrickableAPIClientProtocol

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

    @MainActor
    func importSet(setNum: String, modelContext: ModelContext) async throws -> LegoSet {
        let normalized = Self.normalizeSetNum(setNum)

        let descriptor = FetchDescriptor<LegoSet>(
            predicate: #Predicate { $0.setNum == normalized }
        )
        let existing = try modelContext.fetch(descriptor)
        if let existingSet = existing.first {
            return existingSet
        }

        let setDTO = try await apiClient.fetchSet(setNum: normalized)
        async let partsFetch = apiClient.fetchSetParts(setNum: normalized)
        async let minifigsFetch = apiClient.fetchSetMinifigs(setNum: normalized)
        let partsDTO = try await partsFetch
        let minifigsDTO = try await minifigsFetch

        let legoSet = LegoSet(
            setNum: setDTO.setNum,
            name: setDTO.name,
            year: setDTO.year,
            numParts: setDTO.numParts,
            imageUrl: setDTO.setImgUrl
        )
        modelContext.insert(legoSet)

        for partDTO in partsDTO where !partDTO.isSpare {
            let brickLinkPartNum = partDTO.part.externalIds?.brickLink?.first
            let brickLinkColorId = partDTO.color.externalIds?.brickLink?.extIds?.first

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
                brickLinkPartNum: brickLinkPartNum,
                brickLinkColorId: brickLinkColorId
            )
            part.set = legoSet
            modelContext.insert(part)
        }

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

        if UserDefaults.standard.bool(forKey: "syncSetsToRebrickable"),
           let userToken = SyncTokenProvider.getUserToken(), !userToken.isEmpty
        {
            try? await apiClient.addSetToCollection(userToken: userToken, setNum: normalized)
        }

        return legoSet
    }
}
