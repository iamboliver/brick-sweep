import Foundation
import SwiftData
import Testing

@testable import BrickSweep

@Suite("Completion Math Tests")
struct CompletionTests {
    @Test("Fraction clamps above 100%")
    func fractionClampsAboveOne() {
        #expect(Completion.fraction(completed: 120, total: 100) == 1.0)
    }

    @Test("Fraction clamps below 0%")
    func fractionClampsBelowZero() {
        #expect(Completion.fraction(completed: -5, total: 100) == 0.0)
    }

    @Test("Fraction handles zero total as complete")
    func fractionZeroTotal() {
        #expect(Completion.fraction(completed: 0, total: 0) == 1.0)
    }

    @Test("Fraction is exact within bounds")
    func fractionWithinBounds() {
        #expect(Completion.fraction(completed: 1, total: 4) == 0.25)
    }

    @Test("Percent rounds down so a large set with 2 missing shows 99% (GitHub #1)")
    func percentLargeSetWithTwoMissing() {
        #expect(Completion.percent(completed: 1_198, total: 1_200) == 99)
        #expect(Completion.percent(completed: 99_999, total: 100_000) == 99)
    }

    @Test("Percent is exactly 100 only when nothing is missing")
    func percentExactlyComplete() {
        #expect(Completion.percent(completed: 1_200, total: 1_200) == 100)
        #expect(Completion.percent(completed: 1_199, total: 1_200) < 100)
    }

    @Test("Percent is not shaved by floating-point error", arguments: [29, 57, 58])
    func percentAvoidsFloatingPointError(value: Int) {
        // Int(Double(29) / 100 * 100) == 28, which the integer path avoids.
        #expect(Completion.percent(completed: value, total: 100) == value)
    }

    @Test("Percent clamps out-of-range inputs and treats zero total as complete")
    func percentClampsAndHandlesZeroTotal() {
        #expect(Completion.percent(completed: 120, total: 100) == 100)
        #expect(Completion.percent(completed: -5, total: 100) == 0)
        #expect(Completion.percent(completed: 0, total: 0) == 100)
    }
}

@MainActor
@Suite("LegoSet Completion Tests")
struct LegoSetCompletionTests {
    private func makeContext() throws -> ModelContext {
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(
            for: LegoSet.self,
            LegoPartInstance.self,
            configurations: configuration
        )
        return ModelContext(container)
    }

    private func makeSet(setNum: String = "1234-1", numParts: Int, context: ModelContext) -> LegoSet {
        let set = LegoSet(setNum: setNum, name: "Test Set", year: 2024, numParts: numParts, imageUrl: nil)
        context.insert(set)
        return set
    }

    private func makePart(requiredQty: Int, missingQty: Int = 0, set: LegoSet, context: ModelContext) -> LegoPartInstance {
        let part = LegoPartInstance(
            partNum: "3001",
            colorId: 1,
            colorName: "Red",
            colorRgb: "FF0000",
            name: "Brick",
            imageUrl: nil,
            requiredQty: requiredQty,
            missingQty: missingQty,
            isSpare: false
        )
        part.set = set
        set.parts.append(part)
        context.insert(part)
        return part
    }

    @Test("Marking a part missing then restoring it returns to exactly 100%")
    func addRemoveTransitionRestoresFullCompletion() throws {
        let context = try makeContext()
        let set = makeSet(numParts: 10, context: context)
        let part = makePart(requiredQty: 10, set: set, context: context)

        #expect(set.completionFraction == 1.0)

        part.missingQty = 4
        #expect(set.completionFraction == 0.6)

        part.missingQty = 0
        #expect(set.completionFraction == 1.0)
    }

    @Test("Completion never exceeds 100% when set metadata numParts differs from imported quantity total")
    func mismatchedNumPartsDoesNotExceedFullCompletion() throws {
        let context = try makeContext()
        // API metadata claims 8 parts, but only 5 were actually imported (spares filtered, etc).
        let set = makeSet(numParts: 8, context: context)
        _ = makePart(requiredQty: 5, set: set, context: context)

        #expect(set.totalRequiredQty == 5)
        #expect(set.accountedQty == 5)
        #expect(set.completionFraction == 1.0)
    }

    @Test("Completion never drops below 0% and quantities cannot go negative")
    func completionNeverGoesNegative() throws {
        let context = try makeContext()
        let set = makeSet(numParts: 5, context: context)
        let part = makePart(requiredQty: 5, set: set, context: context)

        part.missingQty = 5
        #expect(set.accountedQty == 0)
        #expect(set.completionFraction == 0.0)
    }

    @Test("Repeated increments across multiple parts keep completion within bounds")
    func repeatedTransitionsAcrossPartsStayInBounds() throws {
        let context = try makeContext()
        let set = makeSet(numParts: 6, context: context)
        let partA = makePart(requiredQty: 3, set: set, context: context)
        let partB = makePart(requiredQty: 3, set: set, context: context)

        partA.missingQty = 2
        partB.missingQty = 1
        #expect(set.totalRequiredQty == 6)
        #expect(set.totalMissingQty == 3)
        #expect(set.accountedQty == 3)
        #expect(set.completionFraction == 0.5)

        partA.missingQty = 0
        partB.missingQty = 0
        #expect(set.completionFraction == 1.0)
    }

    @Test("Set completion is quantity-based, not part-type based")
    func setCompletionUsesQuantities() throws {
        let context = try makeContext()
        let set = makeSet(numParts: 12, context: context)
        let partA = makePart(requiredQty: 10, set: set, context: context)
        _ = makePart(requiredQty: 1, set: set, context: context)
        _ = makePart(requiredQty: 1, set: set, context: context)

        // 1 of 3 part types missing would show 66%; 1 of 12 pieces missing is 91%.
        partA.missingQty = 1
        #expect(set.accountedQty == 11)
        #expect(set.totalRequiredQty == 12)
        #expect(Completion.percent(completed: set.accountedQty, total: set.totalRequiredQty) == 91)
    }

    @Test("Theme group completion sums piece quantities across its sets")
    func themeGroupCompletionUsesQuantities() throws {
        let context = try makeContext()
        let large = makeSet(setNum: "1000-1", numParts: 1_200, context: context)
        let largePart = makePart(requiredQty: 1_200, set: large, context: context)
        let small = makeSet(setNum: "2000-1", numParts: 50, context: context)
        _ = makePart(requiredQty: 50, set: small, context: context)

        let group = ThemeGroup(name: "City", sets: [large, small])
        #expect(group.totalRequiredQty == 1_250)
        #expect(group.accountedQty == 1_250)
        #expect(Completion.percent(completed: group.accountedQty, total: group.totalRequiredQty) == 100)

        largePart.missingQty = 2
        #expect(group.accountedQty == 1_248)
        #expect(Completion.percent(completed: group.accountedQty, total: group.totalRequiredQty) == 99)
    }
}
