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

        let set = try requireCreated(try await harness.service.createSet(setNum: "60272", modelContext: harness.context))

        #expect(set.setNum == "60272-1")
        #expect(set.themeId == 52)
        #expect(set.themeName == "City")
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

        let set = try requireCreated(try await harness.service.createSet(setNum: "60272", modelContext: harness.context))
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

        let set = try requireCreated(try await harness.service.createSet(setNum: "60272", modelContext: harness.context))
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

    // MARK: - Duplicate protection (bs-nzs.8, bs-0q7)

    @Test("Adding a set already in the collection does not fetch or import again")
    func createSetReturnsExistingCompleteSet() async throws {
        let apiClient = MockRebrickableAPIClient(setDTO: Self.setDTO, partsPages: [:])
        let harness = try TestHarness(apiClient: apiClient)
        let existing = try Self.insertSet(setNum: "60272-1", parts: [("3001", 1, 4)], in: harness.context)

        let outcome = try await harness.service.createSet(setNum: "60272", modelContext: harness.context)

        guard case .alreadyInCollection(let set) = outcome else {
            Issue.record("expected .alreadyInCollection, got \(outcome)")
            return
        }
        #expect(set === existing)
        #expect(apiClient.state.fetchSetCalls == 0)
        #expect(apiClient.state.partPageCalls == 0)
        #expect(existing.parts.count == 1)
    }

    @Test("A set whose import failed is returned for retry, not as complete")
    func createSetReturnsFailedSetForRetry() async throws {
        let harness = try TestHarness(apiClient: MockRebrickableAPIClient(setDTO: Self.setDTO, partsPages: [:]))
        let existing = try Self.insertSet(setNum: "60272-1", parts: [("3001", 1, 4)], importFailed: true, in: harness.context)

        let outcome = try await harness.service.createSet(setNum: "60272-1", modelContext: harness.context)

        guard case .needsRetry(let set) = outcome else {
            Issue.record("expected .needsRetry, got \(outcome)")
            return
        }
        #expect(set === existing)
    }

    @Test("A set typed in different case matches the stored set instead of merging into it")
    func createSetMatchesCanonicalSetNumber() async throws {
        let canonical = RebrickableSetDTO(setNum: "ABC-1", name: "Bundle", year: 2021, themeId: nil, numParts: 4, setImgUrl: nil)
        let apiClient = MockRebrickableAPIClient(setDTO: canonical, partsPages: [:])
        let harness = try TestHarness(apiClient: apiClient)
        let existing = try Self.insertSet(setNum: "ABC-1", parts: [("3001", 1, 4)], in: harness.context)

        let outcome = try await harness.service.createSet(setNum: "abc-1", modelContext: harness.context)

        guard case .alreadyInCollection(let set) = outcome else {
            Issue.record("expected .alreadyInCollection, got \(outcome)")
            return
        }
        #expect(set === existing)
        #expect(try harness.context.fetchCount(FetchDescriptor<LegoSet>()) == 1)
        #expect(existing.parts.count == 1)
        #expect(existing.parts.first?.requiredQty == 4)
    }

    @Test("Loading parts twice replaces the inventory instead of duplicating it")
    func loadPartsIsIdempotent() async throws {
        let firstURL = SetImportService.partsPageURL(setNum: "60272-1")
        let apiClient = MockRebrickableAPIClient(
            setDTO: Self.setDTO,
            partsPages: [firstURL: Self.page([Self.partDTO(partNum: "3001", colorId: 1, quantity: 2)])],
            minifigs: [Self.minifigDTO(setNum: "fig-001", quantity: 1)]
        )
        let harness = try TestHarness(apiClient: apiClient)
        let set = try requireCreated(try await harness.service.createSet(setNum: "60272", modelContext: harness.context))

        try await harness.service.loadParts(into: set, setNum: set.setNum, modelContext: harness.context)
        try await harness.service.loadParts(into: set, setNum: set.setNum, modelContext: harness.context)

        #expect(set.parts.count == 2)
        #expect(set.parts.first { $0.partNum == "3001" }?.requiredQty == 2)
        #expect(set.parts.first { $0.partNum == "fig-001" }?.requiredQty == 1)
        #expect(try harness.context.fetchCount(FetchDescriptor<LegoPartInstance>()) == 2)
    }

    @Test("Rows are one per part and colour across pages; spares are ignored")
    func loadPartsMergesAcrossPagesAndSkipsSpares() async throws {
        let firstURL = SetImportService.partsPageURL(setNum: "60272-1")
        let secondURL = "https://example.com/page-2"
        let apiClient = MockRebrickableAPIClient(
            setDTO: Self.setDTO,
            partsPages: [
                firstURL: Self.page([
                    Self.partDTO(partNum: "3001", colorId: 1, quantity: 2),
                    Self.partDTO(partNum: "3001", colorId: 4, quantity: 1),
                    Self.partDTO(partNum: "3001", colorId: 1, quantity: 9, isSpare: true),
                ], next: secondURL),
                secondURL: Self.page([Self.partDTO(partNum: "3001", colorId: 1, quantity: 3)]),
            ]
        )
        let harness = try TestHarness(apiClient: apiClient)
        let set = try requireCreated(try await harness.service.createSet(setNum: "60272", modelContext: harness.context))

        try await harness.service.loadParts(into: set, setNum: set.setNum, modelContext: harness.context)

        let rows = set.parts.map { "\($0.partNum)/\($0.colorId)=\($0.requiredQty)" }.sorted()
        #expect(rows == ["3001/1=5", "3001/4=1"])
    }

    @Test("Retrying an interrupted multi-page import leaves no duplicates")
    func retryAfterInterruptionLeavesNoDuplicates() async throws {
        let firstURL = SetImportService.partsPageURL(setNum: "60272-1")
        let secondURL = "https://example.com/page-2"
        let apiClient = MockRebrickableAPIClient(
            setDTO: Self.setDTO,
            partsPages: [
                firstURL: Self.page([Self.partDTO(partNum: "3001", colorId: 1, quantity: 2)], next: secondURL),
                secondURL: Self.page([
                    Self.partDTO(partNum: "3001", colorId: 1, quantity: 3),
                    Self.partDTO(partNum: "3002", colorId: 2, quantity: 1),
                ]),
            ],
            failingPartPageURLs: [secondURL]
        )
        let harness = try TestHarness(apiClient: apiClient)
        let set = try requireCreated(try await harness.service.createSet(setNum: "60272", modelContext: harness.context))
        await #expect(throws: MockRebrickableAPIClient.MockError.pageFailed) {
            try await harness.service.loadParts(into: set, setNum: set.setNum, modelContext: harness.context)
        }
        #expect(set.parts.count == 1)

        apiClient.state.setFailingURLs([])
        try await harness.service.retryLoadParts(into: set, modelContext: harness.context)

        let rows = set.parts.map { "\($0.partNum)/\($0.colorId)=\($0.requiredQty)" }.sorted()
        #expect(rows == ["3001/1=5", "3002/2=1"])
        #expect(!set.isImporting)
        #expect(!set.importFailed)
    }

    static let setDTO = RebrickableSetDTO(
        setNum: "60272-1",
        name: "Elite Police Boat Transport",
        year: 2020,
        themeId: 52,
        numParts: 166,
        setImgUrl: nil
    )

    static func partDTO(partNum: String, colorId: Int, quantity: Int, isSpare: Bool = false) -> RebrickableSetPartDTO {
        RebrickableSetPartDTO(
            id: colorId,
            quantity: quantity,
            isSpare: isSpare,
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

    static func minifigDTO(setNum: String, quantity: Int) -> RebrickableMinifigDTO {
        RebrickableMinifigDTO(
            id: quantity,
            setNum: setNum,
            setName: "Minifig \(setNum)",
            quantity: quantity,
            setImgUrl: nil
        )
    }
}

// MARK: - Helpers

private enum TestFailure: Error { case unexpectedOutcome }

private func requireCreated(_ outcome: SetAddOutcome) throws -> LegoSet {
    guard case .created(let set) = outcome else {
        Issue.record("expected .created, got \(outcome)")
        throw TestFailure.unexpectedOutcome
    }
    return set
}

extension SetImportServiceTests {
    static func page(_ results: [RebrickableSetPartDTO], next: String? = nil) -> PaginatedResponse<RebrickableSetPartDTO> {
        PaginatedResponse(count: results.count, next: next, previous: nil, results: results)
    }

    @discardableResult
    static func insertSet(
        setNum: String,
        parts: [(partNum: String, colorId: Int, quantity: Int)],
        importFailed: Bool = false,
        in context: ModelContext
    ) throws -> LegoSet {
        let set = LegoSet(
            setNum: setNum, name: "Existing \(setNum)", year: 2020, numParts: parts.reduce(0) { $0 + $1.quantity },
            imageUrl: nil, isImporting: importFailed, importFailed: importFailed
        )
        context.insert(set)
        for part in parts {
            let row = LegoPartInstance(
                partNum: part.partNum, colorId: part.colorId, colorName: "Color", colorRgb: "FFFFFF",
                name: "Part \(part.partNum)", imageUrl: nil, requiredQty: part.quantity, isSpare: false
            )
            row.set = set
            context.insert(row)
        }
        try context.save()
        return set
    }
}

// MARK: - Add-set flow in the view model (bs-nzs.8)

@MainActor
@Suite("Set List View Model Duplicate Protection")
struct SetListViewModelDuplicateTests {
    @Test("Adding a complete set again shows a notice and imports nothing")
    func addingExistingSetShowsNotice() async throws {
        let apiClient = MockRebrickableAPIClient(setDTO: SetImportServiceTests.setDTO, partsPages: [:])
        let harness = try TestHarness(apiClient: apiClient)
        let existing = try SetImportServiceTests.insertSet(setNum: "60272-1", parts: [("3001", 1, 4)], in: harness.context)
        let viewModel = SetListViewModel(importService: harness.service)

        viewModel.setNumInput = "60272"
        await viewModel.loadSet(modelContext: harness.context)

        #expect(viewModel.existingSetNotice?.legoSet === existing)
        #expect(viewModel.existingSetNotice?.isDownloading == false)
        #expect(viewModel.setNumInput.isEmpty)
        #expect(!viewModel.showError)
        #expect(apiClient.state.partPageCalls == 0)
        #expect(existing.parts.count == 1)
        #expect(existing.parts.first?.requiredQty == 4)
    }

    @Test("Adding a set whose import failed retries it cleanly")
    func addingFailedSetRetries() async throws {
        let firstURL = SetImportService.partsPageURL(setNum: "60272-1")
        let apiClient = MockRebrickableAPIClient(
            setDTO: SetImportServiceTests.setDTO,
            partsPages: [firstURL: SetImportServiceTests.page([SetImportServiceTests.partDTO(partNum: "3002", colorId: 2, quantity: 6)])]
        )
        let harness = try TestHarness(apiClient: apiClient)
        let existing = try SetImportServiceTests.insertSet(setNum: "60272-1", parts: [("3002", 2, 3)], importFailed: true, in: harness.context)
        let viewModel = SetListViewModel(importService: harness.service)

        viewModel.setNumInput = "60272-1"
        await viewModel.loadSet(modelContext: harness.context)

        #expect(viewModel.existingSetNotice == nil)
        #expect(existing.parts.count == 1)
        #expect(existing.parts.first?.requiredQty == 6)
        #expect(!existing.isImporting)
        #expect(!existing.importFailed)
    }

    @Test("Adding a set while it is still downloading does not start a second import")
    func addingSetMidDownloadDoesNotDuplicate() async throws {
        let firstURL = SetImportService.partsPageURL(setNum: "60272-1")
        let gate = Gate()
        let apiClient = MockRebrickableAPIClient(
            setDTO: SetImportServiceTests.setDTO,
            partsPages: [firstURL: SetImportServiceTests.page([SetImportServiceTests.partDTO(partNum: "3001", colorId: 1, quantity: 2)])],
            gate: gate
        )
        let harness = try TestHarness(apiClient: apiClient)
        let viewModel = SetListViewModel(importService: harness.service)

        viewModel.setNumInput = "60272"
        let firstImport = Task { await viewModel.loadSet(modelContext: harness.context) }
        var spins = 0
        while apiClient.state.partPageCalls == 0 && spins < 10_000 {
            await Task.yield()
            spins += 1
        }
        try #require(apiClient.state.partPageCalls == 1, "first import never reached the parts download")
        #expect(viewModel.importsInProgress.contains("60272-1"))

        viewModel.setNumInput = "60272"
        await viewModel.loadSet(modelContext: harness.context)

        #expect(viewModel.existingSetNotice?.isDownloading == true)
        #expect(apiClient.state.partPageCalls == 1)

        await gate.release()
        await firstImport.value

        let set = try #require(try harness.service.existingSet(setNum: "60272-1", modelContext: harness.context))
        #expect(set.parts.count == 1)
        #expect(set.parts.first?.requiredQty == 2)
        #expect(viewModel.importsInProgress.isEmpty)
    }
}

// MARK: - Test doubles

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

/// Holds the first parts download until the test releases it. Later downloads are
/// not held, so a wrongly started second import fails the test instead of hanging it.
private actor Gate {
    private var isOpen = false
    private var waiters: [CheckedContinuation<Void, Never>] = []

    func wait() async {
        if isOpen { return }
        await withCheckedContinuation { waiters.append($0) }
    }

    func release() {
        isOpen = true
        waiters.forEach { $0.resume() }
        waiters.removeAll()
    }
}

/// Call counts and switchable failures shared by copies of the mock client.
private final class MockState: @unchecked Sendable {
    private let lock = NSLock()
    private var _fetchSetCalls = 0
    private var _partPageCalls = 0
    private var failingURLs: Set<String>

    init(failingURLs: Set<String>) { self.failingURLs = failingURLs }

    var fetchSetCalls: Int { lock.withLock { _fetchSetCalls } }
    var partPageCalls: Int { lock.withLock { _partPageCalls } }

    func recordFetchSet() { lock.withLock { _fetchSetCalls += 1 } }
    /// Returns the call number (1 for the first call).
    func recordPartPage() -> Int { lock.withLock { _partPageCalls += 1; return _partPageCalls } }
    func isFailing(_ url: String) -> Bool { lock.withLock { failingURLs.contains(url) } }
    func setFailingURLs(_ urls: Set<String>) { lock.withLock { failingURLs = urls } }
}

private struct MockRebrickableAPIClient: RebrickableAPIClientProtocol {
    enum MockError: Error, Equatable {
        case pageFailed
    }

    let setDTO: RebrickableSetDTO
    let partsPages: [String: PaginatedResponse<RebrickableSetPartDTO>]
    let minifigs: [RebrickableMinifigDTO]
    let gate: Gate?
    let state: MockState

    init(
        setDTO: RebrickableSetDTO,
        partsPages: [String: PaginatedResponse<RebrickableSetPartDTO>],
        minifigs: [RebrickableMinifigDTO] = [],
        failingPartPageURLs: Set<String> = [],
        gate: Gate? = nil
    ) {
        self.setDTO = setDTO
        self.partsPages = partsPages
        self.minifigs = minifigs
        self.gate = gate
        self.state = MockState(failingURLs: failingPartPageURLs)
    }

    func fetchSet(setNum: String) async throws -> RebrickableSetDTO {
        state.recordFetchSet()
        return setDTO
    }

    func fetchSetParts(setNum: String) async throws -> [RebrickableSetPartDTO] {
        []
    }

    func fetchSetPartsPage(urlString: String) async throws -> PaginatedResponse<RebrickableSetPartDTO> {
        let call = state.recordPartPage()
        if let gate, call == 1 { await gate.wait() }
        if state.isFailing(urlString) {
            throw MockError.pageFailed
        }
        return partsPages[urlString] ?? PaginatedResponse(count: 0, next: nil, previous: nil, results: [])
    }

    func fetchSetMinifigs(setNum: String) async throws -> [RebrickableMinifigDTO] {
        minifigs
    }

    func fetchTheme(id: Int) async throws -> RebrickableThemeDTO {
        if id == 52 {
            return RebrickableThemeDTO(id: id, parentId: 1, name: "Police")
        }
        return RebrickableThemeDTO(id: id, parentId: nil, name: "City")
    }

    func fetchColor(id: Int) async throws -> RebrickableColorDTO {
        RebrickableColorDTO(id: id, name: "Color", rgb: "FFFFFF", externalIds: nil)
    }

    func addSetToCollection(userToken: String, setNum: String) async throws {}
}
