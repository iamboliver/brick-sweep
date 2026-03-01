import Foundation

struct ExportService: Sendable {
    private let colorMapping: ColorMappingService

    init(colorMapping: ColorMappingService = ColorMappingService()) {
        self.colorMapping = colorMapping
    }

    func generateBrickLinkXML(from parts: [GlobalMissingPart]) async -> String {
        var lines: [String] = []
        lines.append("<INVENTORY>")

        for part in parts {
            let itemId = part.brickLinkPartNum ?? part.partNum
            let colorId = await colorMapping.brickLinkColorId(
                for: part.colorId,
                stored: part.brickLinkColorId
            )

            lines.append("  <ITEM>")
            lines.append("    <ITEMTYPE>P</ITEMTYPE>")
            lines.append("    <ITEMID>\(escapeXML(itemId))</ITEMID>")
            if let colorId {
                lines.append("    <COLOR>\(colorId)</COLOR>")
            }
            lines.append("    <MINQTY>\(part.totalMissingQty)</MINQTY>")
            lines.append("  </ITEM>")
        }

        lines.append("</INVENTORY>")
        return lines.joined(separator: "\n")
    }

    func generateCSV(from parts: [GlobalMissingPart]) -> String {
        var lines: [String] = []
        lines.append("Part Number,Name,Color,Quantity,Sets")

        for part in parts {
            let name = csvEscape(part.name)
            let color = csvEscape(part.colorName)
            let sets = csvEscape(part.contributingSets.joined(separator: "; "))
            lines.append("\(part.partNum),\(name),\(color),\(part.totalMissingQty),\(sets)")
        }

        return lines.joined(separator: "\n")
    }

    private func escapeXML(_ string: String) -> String {
        string
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
            .replacingOccurrences(of: "'", with: "&apos;")
    }

    private func csvEscape(_ string: String) -> String {
        if string.contains(",") || string.contains("\"") || string.contains("\n") {
            return "\"\(string.replacingOccurrences(of: "\"", with: "\"\""))\""
        }
        return string
    }
}
