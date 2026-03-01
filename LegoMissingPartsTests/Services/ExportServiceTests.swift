import Foundation
import Testing

@testable import LegoMissingParts

@Suite("Export Service Tests")
struct ExportServiceTests {
    let sampleParts: [GlobalMissingPart] = [
        GlobalMissingPart(
            partNum: "3001",
            colorId: 1,
            colorName: "Blue",
            colorRgb: "0055BF",
            name: "Brick 2 x 4",
            imageUrl: nil,
            totalMissingQty: 3,
            contributingSets: ["75192-1", "10281-1"],
            elementId: "300123",
            brickLinkPartNum: "3001",
            brickLinkColorId: 7
        ),
        GlobalMissingPart(
            partNum: "3004",
            colorId: 4,
            colorName: "Red",
            colorRgb: "C91A09",
            name: "Brick 1 x 2",
            imageUrl: nil,
            totalMissingQty: 1,
            contributingSets: ["10281-1"],
            elementId: nil,
            brickLinkPartNum: nil,
            brickLinkColorId: nil
        ),
    ]

    @Test("Generate BrickLink XML")
    func generateXML() async throws {
        let service = ExportService()
        let xml = await service.generateBrickLinkXML(from: sampleParts)

        #expect(xml.contains("<INVENTORY>"))
        #expect(xml.contains("</INVENTORY>"))
        #expect(xml.contains("<ITEMTYPE>P</ITEMTYPE>"))
        #expect(xml.contains("<ITEMID>3001</ITEMID>"))
        #expect(xml.contains("<COLOR>7</COLOR>"))
        #expect(xml.contains("<MINQTY>3</MINQTY>"))
        #expect(xml.contains("<ITEMID>3004</ITEMID>"))
        #expect(xml.contains("<MINQTY>1</MINQTY>"))
    }

    @Test("Generate CSV")
    func generateCSV() throws {
        let service = ExportService()
        let csv = service.generateCSV(from: sampleParts)

        let lines = csv.components(separatedBy: "\n")
        #expect(lines[0] == "Part Number,Name,Color,Quantity,Sets")
        #expect(lines.count == 3)
        #expect(lines[1].contains("3001"))
        #expect(lines[1].contains("Brick 2 x 4"))
        #expect(lines[1].contains("3"))
    }

    @Test("XML escapes special characters")
    func xmlEscaping() async throws {
        let parts = [
            GlobalMissingPart(
                partNum: "3001pr<test>",
                colorId: 1,
                colorName: "Blue",
                colorRgb: "0055BF",
                name: "Test & Part",
                imageUrl: nil,
                totalMissingQty: 1,
                contributingSets: ["75192-1"],
                elementId: nil,
                brickLinkPartNum: "3001pr<test>",
                brickLinkColorId: 7
            )
        ]

        let service = ExportService()
        let xml = await service.generateBrickLinkXML(from: parts)
        #expect(xml.contains("3001pr&lt;test&gt;"))
        #expect(!xml.contains("<test>"))
    }

    @Test("CSV escapes commas in fields")
    func csvEscaping() throws {
        let parts = [
            GlobalMissingPart(
                partNum: "3001",
                colorId: 1,
                colorName: "Blue",
                colorRgb: "0055BF",
                name: "Brick, Large 2 x 4",
                imageUrl: nil,
                totalMissingQty: 1,
                contributingSets: ["75192-1"],
                elementId: nil,
                brickLinkPartNum: nil,
                brickLinkColorId: nil
            )
        ]

        let service = ExportService()
        let csv = service.generateCSV(from: parts)
        #expect(csv.contains("\"Brick, Large 2 x 4\""))
    }
}
