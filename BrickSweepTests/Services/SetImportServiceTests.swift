import Foundation
import SwiftData
import Testing

@testable import BrickSweep

@MainActor
@Suite("Set Import Service Tests")
struct SetImportServiceTests {
    @Test("Create set saves importing metadata before parts load")
    func createSetSavesImportingMetadata() async throws {
        let harness = try TestHarness(
            apiClient: MockRebrickableAPIClient(
                setDTO: Self.setDTO,
                partsPages: [:]
            )
        )

        let set = try await harness.service.createSet(setNum: "60272", modelContext: harness.context)

        #expect(set.setNum == "60272-1")
        #expect(set.isImporting)
        #expect(!set.importFailed)
        #expect(set.parts.isEmpty)
    }

    @Test("Load parts deduplicates regular parts and minifigs")
    func loadPartsDeduplicatesQuantities() async throws {
        let firstURL = SetImportService.partsPageURL(setNum: "60272-1")
        let apiClient = MockRebrickableAPIClient(
            setDTO: Self.setDTO,
            partsPages: [
                firstURL: PaginatedResponse(
                    count: 3,
                    next: nil,
                    previous: nil,
                    results: [
                        Self.partDTO(partNum: "3001", colorId: 1, quantity: 2),
                        Self.partDTO(partNum: "3001", colorId: 1, quantity: 3),
                        Self.partDTO(partNum: "3002", colorId: 2, quantity: 1),
                    ]
                )
            ],
            minifigs: [
                Self.minifigDTO(setNum: "fig-001", quantity: 1),
                Self.minifigDTO(setNum: "fig-001", quantity: 2),
            ]
        )
        let harness = try TestHarness(apiClient: apiClient)

        let set = try await harness.service.createSet(setNum: "60272", modelContext: harness.context)
        try await harness.service.loadParts(into: set, setNum: set.setNum, modelContext: harness.context)

        #expect(!set.isImporting)
        #expect(!set.importFailed)
        #expect(set.parts.count == 3)
        #expect(set.parts.first { $0.partNum == "3001" }?.requiredQty == 5)
        #expect(set.parts.first { $0.partNum == "3002" }?.requiredQty == 1)
        #expect(set.parts.first { $0.partNum == "fig-001" }?.requiredQty == 3)
    }

    @Test("Load parts marks set as failed and keeps saved progress")
    func loadPartsMarksFailedAndKeepsProgress() async throws {
        let firstURL = SetImportService.partsPageURL(setNum: "60272-1")
        let secondURL = "https://example.com/page-2"
        let apiClient = MockRebrickableAPIClient(
            setDTO: Self.setDTO,
            partsPages: [
                firstURL: PaginatedResponse(
                    count: 2,
                    next: secondURL,
                    previous: nil,
                    results: [Self.partDTO(partNum: "3001", colorId: 1, quantity: 2)]
                ),
            ],
            failingPartPageURLs: [secondURL]
        )
        let harness = try TestHarness(apiClient: apiClient)

        let set = try await harness.service.createSet(setNum: "60272", modelContext: harness.context)
        await #expect(throws: MockRebrickableAPIClient.MockError.pageFailed) {
            try await harness.service.loadParts(into: set, setNum: set.setNum, modelContext: harness.context)
        }

        #expect(set.isImporting)
        #expect(set.importFailed)
        #expect(set.parts.count == 1)
        #expect(set.parts.first?.partNum == "3001")
    }

    @Test("Retry clears partial parts before reimport")
    func retryClearsPartialPartsBeforeReimport() async throws {
        let firstURL = SetImportService.partsPageURL(setNum: "60272-1")
        let apiClient = MockRebrickableAPIClient(
            setDTO: Self.setDTO,
            partsPages: [
                firstURL: PaginatedResponse(
                    count: 1,
                    next: nil,
                    previous: nil,
                    results: [Self.partDTO(partNum: "3002", colorId: 2, quantity: 4)]
                )
            ]
        )
        let harness = try TestHarness(apiClient: apiClient)
        let set = LegoSet(
            setNum: "60272-1",
            name: "Elite Police Boat Transport",
            year: 2020,
            numParts: 166,
            imageUrl: nil,
            isImporting: true,
            importFailed: true
        )
        let stalePart = LegoPartInstance(
            partNum: "stale",
            colorId: 1,
            colorName: "Blue",
            colorRgb: "0055BF",
            name: "Stale Part",
            imageUrl: nil,
            requiredQty: 1,
            isSpare: false
        )
        stalePart.set = set
        harness.context.insert(set)
        harness.context.insert(stalePart)
        try harness.context.save()

        try await harness.service.retryLoadParts(into: set, modelContext: harness.context)

        #expect(!set.isImporting)
        #expect(!set.importFailed)
        #expect(set.parts.count == 1)
        #expect(set.parts.first?.partNum == "3002")
        #expect(set.parts.first?.requiredQty == 4)
    }

    private static let setDTO = RebrickableSetDTO(
        setNum: "60272-1",
        name: "Elite Police Boat Transport",
        year: 2020,
        numParts: 166,
        setImgUrl: nil
    )

    private static func partDTO(partNum: String, colorId: Int, quantity: Int) -> RebrickableSetPartDTO {
        RebrickableSetPartDTO(
            id: colorId,
            quantity: quantity,
            isSpare: false,
            elementId: nil,
            part: .init(
                partNum: partNum,
                name: "Part \(partNum)",
                partImgUrl: nil,
                externalIds: nil
            ),
            color: .init(
                id: colorId,
                name: "Color \(colorId)",
                rgb: "FFFFFF",
                externalIds: nil
            )
        )
    }

    private static func minifigDTO(setNum: String, quantity: Int) -> RebrickableMinifigDTO {
        RebrickableMinifigDTO(
            id: quantity,
            setNum: setNum,
            setName: "Minifig \(setNum)",
            quantity: quantity,
            setImgUrl: nil
        )
    }
}

@MainActor
private struct TestHarness {
    let container: ModelContainer
    let context: ModelContext
    let service: SetImportService

    init(apiClient: MockRebrickableAPIClient) throws {
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        container = try ModelContainer(
            for: LegoSet.self,
            LegoPartInstance.self,
            configurations: configuration
        )
        context = ModelContext(container)
        service = SetImportService(apiClient: apiClient)
    }
}

private struct MockRebrickableAPIClient: RebrickableAPIClientProtocol {
    enum MockError: Error, Equatable {
        case pageFailed
    }

    let setDTO: RebrickableSetDTO
    let partsPages: [String: PaginatedResponse<RebrickableSetPartDTO>]
    var minifigs: [RebrickableMinifigDTO] = []
    var failingPartPageURLs: Set<String> = []

    func fetchSet(setNum: String) async throws -> RebrickableSetDTO {
        setDTO
    }

    func fetchSetParts(setNum: String) async throws -> [RebrickableSetPartDTO] {
        []
    }

    func fetchSetPartsPage(urlString: String) async throws -> PaginatedResponse<RebrickableSetPartDTO> {
        if failingPartPageURLs.contains(urlString) {
            throw MockError.pageFailed
        }
        return partsPages[urlString] ?? PaginatedResponse(count: 0, next: nil, previous: nil, results: [])
    }

    func fetchSetMinifigs(setNum: String) async throws -> [RebrickableMinifigDTO] {
        minifigs
    }

    func fetchColor(id: Int) async throws -> RebrickableColorDTO {
        RebrickableColorDTO(id: id, name: "Color", rgb: "FFFFFF", externalIds: nil)
    }

    func addSetToCollection(userToken: String, setNum: String) async throws {}
}
