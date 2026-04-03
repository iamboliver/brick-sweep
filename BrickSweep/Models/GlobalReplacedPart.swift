import Foundation

struct GlobalReplacedPart: Identifiable {
    var id: String { "\(partNum)-\(colorId)" }
    let partNum: String
    let colorId: Int
    let colorName: String
    let colorRgb: String
    let name: String
    let imageUrl: String?
    let totalReplacedQty: Int
    let contributingSets: [String]
    let elementId: String?
    let brickLinkPartNum: String?
    let brickLinkColorId: Int?

    static func aggregate(from parts: [LegoPartInstance], sortedBy sortOption: PartSortOption = .color) -> [GlobalReplacedPart] {
        let grouped = Dictionary(grouping: parts) { part in
            "\(part.partNum)-\(part.colorId)"
        }

        let aggregated = grouped.values.compactMap { group -> GlobalReplacedPart? in
            guard let first = group.first else { return nil }
            let totalReplaced = group.reduce(0) { $0 + $1.replacedQty }
            guard totalReplaced > 0 else { return nil }

            let setNums = group.compactMap { $0.set?.setNum }

            return GlobalReplacedPart(
                partNum: first.partNum,
                colorId: first.colorId,
                colorName: first.colorName,
                colorRgb: first.colorRgb,
                name: first.name,
                imageUrl: first.imageUrl,
                totalReplacedQty: totalReplaced,
                contributingSets: Array(Set(setNums)).sorted(),
                elementId: first.elementId,
                brickLinkPartNum: first.brickLinkPartNum,
                brickLinkColorId: first.brickLinkColorId
            )
        }

        switch sortOption {
        case .color:
            return aggregated.sorted { a, b in
                let ca = LegoColorSortOrder.sortPosition(for: a.colorId)
                let cb = LegoColorSortOrder.sortPosition(for: b.colorId)
                if ca != cb { return ca < cb }
                if a.colorName != b.colorName { return a.colorName < b.colorName }
                return a.name < b.name
            }
        case .partNumber:
            return aggregated.sorted { $0.partNum < $1.partNum }
        }
    }
}
