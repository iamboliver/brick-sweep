import Testing

@testable import BrickSweep

@Suite("Set Import Service Normalization Tests")
struct SetImportServiceNormalizationTests {
    @Test("Bare numeric input appends -1")
    func bareNumericInputAppendsSuffix() {
        #expect(SetImportService.normalizeSetNum("60272") == "60272-1")
    }

    @Test("Hyphenated input is preserved")
    func hyphenatedInputIsPreserved() {
        #expect(SetImportService.normalizeSetNum("60272-2") == "60272-2")
    }

    @Test("Whitespace-padded bare input is trimmed and normalized")
    func whitespacePaddedBareInputIsTrimmedAndNormalized() {
        #expect(SetImportService.normalizeSetNum("  60272  ") == "60272-1")
    }

    @Test("Whitespace-padded hyphenated input is trimmed and preserved")
    func whitespacePaddedHyphenatedInputIsTrimmedAndPreserved() {
        #expect(SetImportService.normalizeSetNum("  60272-2  ") == "60272-2")
    }
}
