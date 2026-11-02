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
        let existing = try Self.insertSet(setNum: "60272-1", parts: [.init("3001", 1, 4)], in: harness.context)

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
        let existing = try Self.insertSet(setNum: "60272-1", parts: [.init("3001", 1, 4)], importFailed: true, in: harness.context)

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
        let existing = try Self.insertSet(setNum: "ABC-1", parts: [.init("3001", 1, 4)], in: harness.context)

        let outcome = try await harness.service.createSet(setNum: "abc-1", modelContext: harness.context)

        guard case .alreadyInCollection(let set) = outcome else {
            Issue.record("expected .alreadyInCollection, got \(outcome)")
            return
        }
        #expect(set === existing)
        #expect(apiClient.state.fetchSetCalls == 0)
        #expect(try harness.context.fetchCount(FetchDescriptor<LegoSet>()) == 1)
        #expect(existing.parts.count == 1)
        #expect(existing.parts.first?.requiredQty == 4)
    }

    @Test("A typed number Rebrickable resolves to a stored set is caught before inserting")
    func createSetRechecksCanonicalNumberBeforeInsert() async throws {
        let apiClient = MockRebrickableAPIClient(setDTO: Self.setDTO, partsPages: [:])
        let harness = try TestHarness(apiClient: apiClient)
        let existing = try Self.insertSet(setNum: "60272-1", parts: [.init("3001", 1, 4)], in: harness.context)

        // "60272-01" doesn't match locally, but Rebrickable answers with "60272-1".
        let outcome = try await harness.service.createSet(setNum: "60272-01", modelContext: harness.context)

        guard case .alreadyInCollection(let set) = outcome else {
            Issue.record("expected .alreadyInCollection, got \(outcome)")
            return
        }
        #expect(set === existing)
        #expect(try harness.context.fetchCount(FetchDescriptor<LegoSet>()) == 1)
    }

    @Test("Two quick adds of the same set create it once")
    func concurrentCreateSetInsertsOnce() async throws {
        let themeGate = Gate()
        let apiClient = MockRebrickableAPIClient(setDTO: Self.setDTO, partsPages: [:], themeGate: themeGate)
        let harness = try TestHarness(apiClient: apiClient)

        // Models aren't Sendable, so each task reports its outcome kind and the set's ID.
        let add = { @MainActor () async throws -> (kind: String, id: PersistentIdentifier) in
            switch try await harness.service.createSet(setNum: "60272", modelContext: harness.context) {
            case .created(let set): ("created", set.persistentModelID)
            case .needsRetry(let set): ("needsRetry", set.persistentModelID)
            case .alreadyInCollection(let set): ("alreadyInCollection", set.persistentModelID)
            }
        }
        let first = Task { try await add() }
        let second = Task { try await add() }
        try await waitUntil { apiClient.state.fetchThemeCalls >= 2 }
        await themeGate.release()
        let outcomes = [try await first.value, try await second.value]

        #expect(outcomes.map(\.kind).sorted() == ["created", "needsRetry"])
        #expect(outcomes[0].id == outcomes[1].id)
        #expect(try harness.context.fetchCount(FetchDescriptor<LegoSet>()) == 1)
    }

    // MARK: - Retry keeps the user's counts (review of PR #12)

    @Test("Retry keeps missing and replaced counts for parts still in the inventory")
    func retryPreservesCounts() async throws {
        let firstURL = SetImportService.partsPageURL(setNum: "60272-1")
        let apiClient = MockRebrickableAPIClient(
            setDTO: Self.setDTO,
            partsPages: [firstURL: Self.page([
                Self.partDTO(partNum: "3001", colorId: 1, quantity: 4),
                Self.partDTO(partNum: "3002", colorId: 2, quantity: 1),
            ])]
        )
        let harness = try TestHarness(apiClient: apiClient)
        let set = try Self.insertSet(
            setNum: "60272-1",
            parts: [.init("3001", 1, 4, missing: 2, replaced: 1), .init("stale", 1, 1, missing: 1)],
            importFailed: true,
            in: harness.context
        )

        try await harness.service.retryLoadParts(into: set, modelContext: harness.context)

        let rows = Dictionary(uniqueKeysWithValues: set.parts.map { ($0.partNum, $0) })
        #expect(rows.keys.sorted() == ["3001", "3002"])
        #expect(rows["3001"]?.missingQty == 2)
        #expect(rows["3001"]?.replacedQty == 1)
        #expect(rows["3001"]?.requiredQty == 4)
        #expect(rows["3002"]?.missingQty == 0)
    }

    @Test(
        "When a part's quantity drops, missing + replaced is capped to it, missing first",
        arguments: [
            // (stored missing, stored replaced, expected missing, expected replaced) for 4 -> 2 pieces
            (3, 1, 2, 0),
            (1, 3, 1, 1),
            (0, 4, 0, 2),
            (1, 0, 1, 0),
        ]
    )
    func retryCapsCombinedCountsToNewQuantity(counts: (Int, Int, Int, Int)) async throws {
        let (storedMissing, storedReplaced, expectedMissing, expectedReplaced) = counts
        let firstURL = SetImportService.partsPageURL(setNum: "60272-1")
        let apiClient = MockRebrickableAPIClient(
            setDTO: Self.setDTO,
            partsPages: [firstURL: Self.page([Self.partDTO(partNum: "3001", colorId: 1, quantity: 2)])]
        )
        let harness = try TestHarness(apiClient: apiClient)
        let set = try Self.insertSet(
            setNum: "60272-1",
            parts: [.init("3001", 1, 4, missing: storedMissing, replaced: storedReplaced)],
            importFailed: true,
            in: harness.context
        )

        try await harness.service.retryLoadParts(into: set, modelContext: harness.context)

        let row = try #require(set.parts.first)
        #expect(row.requiredQty == 2)
        #expect(row.missingQty == expectedMissing)
        #expect(row.replacedQty == expectedReplaced)
        #expect(row.missingQty + row.replacedQty <= row.requiredQty)
    }

    @Test("Folding duplicate rows never tracks more pieces than required, even if the retry then fails")
    func foldedDuplicatesStayWithinRequiredQuantity() async throws {
        let firstURL = SetImportService.partsPageURL(setNum: "60272-1")
        let apiClient = MockRebrickableAPIClient(
            setDTO: Self.setDTO,
            partsPages: [:],
            failingPartPageURLs: [firstURL]
        )
        let harness = try TestHarness(apiClient: apiClient)
        let set = try Self.insertSet(
            setNum: "60272-1",
            parts: [.init("3001", 1, 4, missing: 3, replaced: 1), .init("3001", 1, 4, missing: 2, replaced: 2)],
            importFailed: true,
            in: harness.context
        )

        await #expect(throws: MockRebrickableAPIClient.MockError.pageFailed) {
            try await harness.service.retryLoadParts(into: set, modelContext: harness.context)
        }

        let row = try #require(set.parts.first)
        #expect(set.parts.count == 1)
        #expect(row.missingQty == 4)
        #expect(row.replacedQty == 0)
        #expect(row.missingQty + row.replacedQty <= row.requiredQty)
    }

    @Test("A retry that fails partway leaves every stored row and count untouched")
    func failedRetryLosesNothing() async throws {
        let firstURL = SetImportService.partsPageURL(setNum: "60272-1")
        let secondURL = "https://example.com/page-2"
        let apiClient = MockRebrickableAPIClient(
            setDTO: Self.setDTO,
            partsPages: [firstURL: Self.page([Self.partDTO(partNum: "3001", colorId: 1, quantity: 6)], next: secondURL)],
            failingPartPageURLs: [secondURL]
        )
        let harness = try TestHarness(apiClient: apiClient)
        let set = try Self.insertSet(
            setNum: "60272-1",
            parts: [.init("3001", 1, 4, missing: 2), .init("3002", 2, 1, missing: 1)],
            importFailed: true,
            in: harness.context
        )

        await #expect(throws: MockRebrickableAPIClient.MockError.pageFailed) {
            try await harness.service.retryLoadParts(into: set, modelContext: harness.context)
        }

        let rows = Dictionary(uniqueKeysWithValues: set.parts.map { ($0.partNum, $0) })
        #expect(rows.keys.sorted() == ["3001", "3002"])
        #expect(rows["3001"]?.requiredQty == 4)
        #expect(rows["3001"]?.missingQty == 2)
        #expect(rows["3002"]?.missingQty == 1)
        #expect(set.importFailed)
    }

    @Test("Extra copies left by the 1.0 duplicate bug are folded into one row on retry")
    func retryFoldsLegacyDuplicateRows() async throws {
        let firstURL = SetImportService.partsPageURL(setNum: "60272-1")
        let apiClient = MockRebrickableAPIClient(
            setDTO: Self.setDTO,
            partsPages: [firstURL: Self.page([Self.partDTO(partNum: "3001", colorId: 1, quantity: 4)])]
        )
        let harness = try TestHarness(apiClient: apiClient)
        let set = try Self.insertSet(
            setNum: "60272-1",
            parts: [.init("3001", 1, 4, missing: 1), .init("3001", 1, 4, missing: 2)],
            importFailed: true,
            in: harness.context
        )

        try await harness.service.retryLoadParts(into: set, modelContext: harness.context)

        #expect(set.parts.count == 1)
        #expect(set.parts.first?.requiredQty == 4)
        #expect(set.parts.first?.missingQty == 3)
        #expect((set.parts.first?.missingQty ?? 0) + (set.parts.first?.replacedQty ?? 0) <= 4)
        #expect(try harness.context.fetchCount(FetchDescriptor<LegoPartInstance>()) == 1)
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

enum TestFailure: Error { case unexpectedOutcome }

/// Yields until the condition holds; fails the test (instead of hanging) if it never does.
@MainActor
private func waitUntil(_ condition: () -> Bool, sourceLocation: SourceLocation = #_sourceLocation) async throws {
    for _ in 0..<10_000 where !condition() {
        await Task.yield()
    }
    try #require(condition(), "condition never became true", sourceLocation: sourceLocation)
}

func requireCreated(_ outcome: SetAddOutcome) throws -> LegoSet {
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

    struct StoredRow {
        let partNum: String
        let colorId: Int
        let quantity: Int
        var missing = 0
        var replaced = 0

        init(_ partNum: String, _ colorId: Int, _ quantity: Int, missing: Int = 0, replaced: Int = 0) {
            self.partNum = partNum
            self.colorId = colorId
            self.quantity = quantity
            self.missing = missing
            self.replaced = replaced
        }
    }

    @discardableResult
    static func insertSet(
        setNum: String,
        parts: [StoredRow],
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
                name: "Part \(part.partNum)", imageUrl: nil, requiredQty: part.quantity,
                missingQty: part.missing, replacedQty: part.replaced, isSpare: false
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
        let existing = try SetImportServiceTests.insertSet(setNum: "60272-1", parts: [.init("3001", 1, 4)], in: harness.context)
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
        let existing = try SetImportServiceTests.insertSet(setNum: "60272-1", parts: [.init("3002", 2, 3)], importFailed: true, in: harness.context)
        let viewModel = SetListViewModel(importService: harness.service)

        viewModel.setNumInput = "60272-1"
        await viewModel.loadSet(modelContext: harness.context)

        #expect(viewModel.existingSetNotice == nil)
        #expect(existing.parts.count == 1)
        #expect(existing.parts.first?.requiredQty == 6)
        #expect(!existing.isImporting)
        #expect(!existing.importFailed)
    }

    @Test("Re-adding a set whose import failed keeps the counts already entered")
    func readdingFailedSetKeepsCounts() async throws {
        let firstURL = SetImportService.partsPageURL(setNum: "60272-1")
        let apiClient = MockRebrickableAPIClient(
            setDTO: SetImportServiceTests.setDTO,
            partsPages: [firstURL: SetImportServiceTests.page([SetImportServiceTests.partDTO(partNum: "3001", colorId: 1, quantity: 4)])]
        )
        let harness = try TestHarness(apiClient: apiClient)
        let existing = try SetImportServiceTests.insertSet(
            setNum: "60272-1", parts: [.init("3001", 1, 4, missing: 3, replaced: 1)], importFailed: true, in: harness.context
        )
        let viewModel = SetListViewModel(importService: harness.service)

        viewModel.setNumInput = "60272"
        await viewModel.loadSet(modelContext: harness.context)

        #expect(existing.parts.count == 1)
        #expect(existing.parts.first?.missingQty == 3)
        #expect(existing.parts.first?.replacedQty == 1)
        #expect(!existing.importFailed)
    }

    @Test("At the free limit, a set already in the collection skips the paywall, whatever its case")
    func paywallSkipsSetsAlreadyInCollection() throws {
        let harness = try TestHarness(apiClient: MockRebrickableAPIClient(setDTO: SetImportServiceTests.setDTO, partsPages: [:]))
        try SetImportServiceTests.insertSet(setNum: "ABC-1", parts: [.init("3001", 1, 4)], in: harness.context)
        let viewModel = SetListViewModel(importService: harness.service)
        let limit = AppConstants.IAP.freeTierSetLimit

        viewModel.setNumInput = "abc-1"
        #expect(!viewModel.shouldShowPaywall(setCount: limit, isPro: false, modelContext: harness.context))

        viewModel.setNumInput = "99999"
        #expect(viewModel.shouldShowPaywall(setCount: limit, isPro: false, modelContext: harness.context))
        #expect(!viewModel.shouldShowPaywall(setCount: limit, isPro: true, modelContext: harness.context))
        #expect(!viewModel.shouldShowPaywall(setCount: limit - 1, isPro: false, modelContext: harness.context))
    }

    @Test("Two quick adds of the same set import it once")
    func concurrentAddsImportOnce() async throws {
        let firstURL = SetImportService.partsPageURL(setNum: "60272-1")
        let themeGate = Gate()
        let apiClient = MockRebrickableAPIClient(
            setDTO: SetImportServiceTests.setDTO,
            partsPages: [firstURL: SetImportServiceTests.page([SetImportServiceTests.partDTO(partNum: "3001", colorId: 1, quantity: 2)])],
            themeGate: themeGate
        )
        let harness = try TestHarness(apiClient: apiClient)
        let viewModel = SetListViewModel(importService: harness.service)

        viewModel.setNumInput = "60272"
        let first = Task { await viewModel.loadSet(modelContext: harness.context) }
        viewModel.setNumInput = "60272"
        let second = Task { await viewModel.loadSet(modelContext: harness.context) }
        try await waitUntil { apiClient.state.fetchThemeCalls >= 2 }
        await themeGate.release()
        await first.value
        await second.value

        let set = try #require(try harness.service.existingSet(setNum: "60272-1", modelContext: harness.context))
        #expect(try harness.context.fetchCount(FetchDescriptor<LegoSet>()) == 1)
        #expect(set.parts.count == 1)
        #expect(set.parts.first?.requiredQty == 2)
        #expect(apiClient.state.partPageCalls == 1)
        #expect(viewModel.existingSetNotice != nil)
        #expect(viewModel.importsInProgress.isEmpty)
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
        try await waitUntil { apiClient.state.partPageCalls == 1 }
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
struct TestHarness {
    let container: ModelContainer
    let context: ModelContext
    let service: SetImportService

    init(
        apiClient: MockRebrickableAPIClient,
        setDataClient: SetDataClientProtocol? = nil,
        usesOwnAPIKey: @escaping @Sendable () -> Bool = { true }
    ) throws {
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        container = try ModelContainer(
            for: LegoSet.self,
            LegoPartInstance.self,
            configurations: configuration
        )
        context = ModelContext(container)
        service = SetImportService(apiClient: apiClient, setDataClient: setDataClient, usesOwnAPIKey: usesOwnAPIKey)
    }
}

/// Holds the first parts download until the test releases it. Later downloads are
/// not held, so a wrongly started second import fails the test instead of hanging it.
actor Gate {
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
final class MockState: @unchecked Sendable {
    private let lock = NSLock()
    private var _fetchSetCalls = 0
    private var _partPageCalls = 0
    private var _fetchThemeCalls = 0
    private var failingURLs: Set<String>

    init(failingURLs: Set<String>) { self.failingURLs = failingURLs }

    var fetchSetCalls: Int { lock.withLock { _fetchSetCalls } }
    var partPageCalls: Int { lock.withLock { _partPageCalls } }
    var fetchThemeCalls: Int { lock.withLock { _fetchThemeCalls } }
    func recordFetchTheme() { lock.withLock { _fetchThemeCalls += 1 } }

    func recordFetchSet() { lock.withLock { _fetchSetCalls += 1 } }
    /// Returns the call number (1 for the first call).
    func recordPartPage() -> Int { lock.withLock { _partPageCalls += 1; return _partPageCalls } }
    func isFailing(_ url: String) -> Bool { lock.withLock { failingURLs.contains(url) } }
    func setFailingURLs(_ urls: Set<String>) { lock.withLock { failingURLs = urls } }
}

struct MockRebrickableAPIClient: RebrickableAPIClientProtocol {
    enum MockError: Error, Equatable {
        case pageFailed
    }

    let setDTO: RebrickableSetDTO
    let partsPages: [String: PaginatedResponse<RebrickableSetPartDTO>]
    let minifigs: [RebrickableMinifigDTO]
    let gate: Gate?
    /// Holds every theme lookup until released, to line up two adds mid-request.
    let themeGate: Gate?
    let state: MockState

    init(
        setDTO: RebrickableSetDTO,
        partsPages: [String: PaginatedResponse<RebrickableSetPartDTO>],
        minifigs: [RebrickableMinifigDTO] = [],
        failingPartPageURLs: Set<String> = [],
        gate: Gate? = nil,
        themeGate: Gate? = nil
    ) {
        self.setDTO = setDTO
        self.partsPages = partsPages
        self.minifigs = minifigs
        self.gate = gate
        self.themeGate = themeGate
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
        state.recordFetchTheme()
        if let themeGate { await themeGate.wait() }
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
