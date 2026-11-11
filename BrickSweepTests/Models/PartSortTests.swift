import Foundation
import Testing

@testable import BrickSweep

@Suite("Part Number Sort Tests")
struct PartSortTests {
    private func ordered(_ a: (String, Int, String), _ b: (String, Int, String)) -> Bool {
        PartSortOption.isOrderedByNumber(
            (number: a.0, colorId: a.1, name: a.2),
            (number: b.0, colorId: b.1, name: b.2)
        )
    }

    @Test("Shows the element ID when there is one, else the part number")
    func displayedNumber() {
        #expect(PartSortOption.displayedNumber(elementId: "300501", partNum: "3005") == "300501")
        #expect(PartSortOption.displayedNumber(elementId: nil, partNum: "3005") == "3005")
    }

    @Test("Digits compare as numbers, not text")
    func numericOrder() {
        #expect(ordered(("3005", 15, "Brick"), ("30000", 15, "Brick")))
        #expect(!ordered(("30000", 15, "Brick"), ("3005", 15, "Brick")))
        #expect(ordered(("300501", 15, "A"), ("6070698", 15, "B")))
    }

    @Test("Equal numbers fall back to colour, then name")
    func tieBreak() {
        // White (15) sorts before Black (0 is not in the table, so use two known colours)
        let white = LegoColorSortOrder.sortPosition(for: 15)
        let red = LegoColorSortOrder.sortPosition(for: 4)
        #expect(white != red)
        #expect(ordered(("3005", 15, "Brick"), ("3005", 4, "Brick")) == (white < red))
        #expect(ordered(("3005", 15, "Alpha"), ("3005", 15, "Beta")))
    }
}
