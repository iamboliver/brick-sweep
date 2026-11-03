import Foundation
import SwiftData
import Testing

@testable import BrickSweep

/// Missing + replaced must never exceed the required quantity (bs-gsj).
@MainActor
@Suite("Missing and replaced counts")
struct PartCountTests {
    private func part(required: Int, missing: Int = 0, replaced: Int = 0) -> LegoPartInstance {
        LegoPartInstance(
            partNum: "3001", colorId: 1, colorName: "Blue", colorRgb: "0055BF", name: "Brick 2 x 4",
            imageUrl: nil, requiredQty: required, missingQty: missing, replacedQty: replaced, isSpare: false
        )
    }

    @Test("Replaced pieces lower how many can be marked missing")
    func maxMissing() {
        #expect(part(required: 2, replaced: 1).maxMissingQty == 1)
        #expect(part(required: 2, replaced: 2).maxMissingQty == 0)
        #expect(part(required: 2).maxMissingQty == 2)
        #expect(part(required: 1, replaced: 3).maxMissingQty == 0)
    }

    @Test("Incrementing stops at the pieces not yet replaced, then wraps to none")
    func increment() {
        let brick = part(required: 2, replaced: 1)
        brick.incrementMissing()
        #expect(brick.missingQty == 1)
        brick.incrementMissing()
        #expect(brick.missingQty == 0)
    }

    @Test("Mark All Missing marks only the pieces not yet replaced")
    func markAll() {
        let brick = part(required: 2, replaced: 1)
        brick.markAllMissing()
        #expect((brick.missingQty, brick.replacedQty) == (1, 1))
    }

    @Test("Decrementing steps down one at a time, even from counts over the limit")
    func decrement() {
        let brick = part(required: 2, missing: 2, replaced: 1)
        brick.decrementMissing()
        #expect(brick.missingQty == 1)
        brick.decrementMissing()
        brick.decrementMissing()
        #expect(brick.missingQty == 0)
    }

    @Test("Undoing a replacement makes those pieces missing, up to the required quantity", arguments: [
        (missing: 1, replaced: 1, expectedMissing: 2),
        (missing: 0, replaced: 2, expectedMissing: 2),
        (missing: 2, replaced: 1, expectedMissing: 2),
    ])
    func undoReplacement(missing: Int, replaced: Int, expectedMissing: Int) {
        let brick = part(required: 2, missing: missing, replaced: replaced)
        brick.markReplacedAsMissing()
        #expect((brick.missingQty, brick.replacedQty) == (expectedMissing, 0))
    }

    @Test("Marking missing pieces replaced never records more than the required quantity")
    func markReplaced() {
        let valid = part(required: 3, missing: 2, replaced: 1)
        valid.markMissingAsReplaced()
        #expect((valid.missingQty, valid.replacedQty) == (0, 3))

        let overLimit = part(required: 2, missing: 2, replaced: 1)
        overLimit.markMissingAsReplaced()
        #expect((overLimit.missingQty, overLimit.replacedQty) == (0, 2))
    }

    @Test("Capping keeps missing first, then fits replaced into what's left")
    func cap() {
        let brick = part(required: 2, missing: 2, replaced: 1)
        brick.capCounts()
        #expect((brick.missingQty, brick.replacedQty) == (2, 0))

        let shrunk = part(required: 1, missing: 3, replaced: 2)
        shrunk.capCounts()
        #expect((shrunk.missingQty, shrunk.replacedQty) == (1, 0))
    }

    // MARK: - The Replaced and Missing tabs

    @Test("Mark as not replaced in the Replaced tab can't push missing past the required quantity")
    func replacedTabUndo() throws {
        let (container, context) = try Self.store()
        defer { withExtendedLifetime(container) {} }
        // 2 missing and 1 replaced of 2: what 1.1's + button allowed. Undoing used to show 3 of 2.
        let brick = part(required: 2, missing: 2, replaced: 1)
        context.insert(brick)
        try context.save()
        let viewModel = ReplacedPartsViewModel()
        viewModel.refresh(modelContext: context)

        viewModel.markAsNotReplaced(try #require(viewModel.replacedParts.first), modelContext: context)

        #expect((brick.missingQty, brick.replacedQty) == (2, 0))
    }

    @Test("Mark as replaced in the Missing tab moves the missing pieces to replaced")
    func missingTabReplace() throws {
        let (container, context) = try Self.store()
        defer { withExtendedLifetime(container) {} }
        let brick = part(required: 2, missing: 1, replaced: 1)
        context.insert(brick)
        try context.save()
        let viewModel = MissingPartsViewModel()
        viewModel.refresh(modelContext: context)

        viewModel.markAsReplaced(try #require(viewModel.missingParts.first), modelContext: context)

        #expect((brick.missingQty, brick.replacedQty) == (0, 2))
    }

    private static func store() throws -> (ModelContainer, ModelContext) {
        let container = try ModelContainer(
            for: LegoSet.self, LegoPartInstance.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        return (container, ModelContext(container))
    }
}
