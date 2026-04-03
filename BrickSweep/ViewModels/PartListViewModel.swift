import Foundation
import SwiftData

enum PartFilter: String, CaseIterable {
    case all = "All"
    case missing = "Missing"
    case untouched = "Accounted for"
}

@MainActor
@Observable
final class PartListViewModel {
    var filter: PartFilter = .all
    var sortOption: PartSortOption = .color
    var searchText: String = ""

    func filteredParts(_ parts: [LegoPartInstance]) -> [LegoPartInstance] {
        var base: [LegoPartInstance]
        switch filter {
        case .all:
            base = parts
        case .missing:
            base = parts.filter { $0.missingQty > 0 }
        case .untouched:
            base = parts.filter { $0.missingQty == 0 }
        }

        let query = searchText.trimmingCharacters(in: .whitespaces)
        if !query.isEmpty {
            base = base.filter {
                $0.partNum.localizedCaseInsensitiveContains(query)
                || $0.elementId?.localizedCaseInsensitiveContains(query) == true
                || $0.brickLinkPartNum?.localizedCaseInsensitiveContains(query) == true
            }
        }

        return base.sorted(by: partComparator)
    }

    private var partComparator: (LegoPartInstance, LegoPartInstance) -> Bool {
        switch sortOption {
        case .color:
            return { a, b in
                let ca = LegoColorSortOrder.sortPosition(for: a.colorId)
                let cb = LegoColorSortOrder.sortPosition(for: b.colorId)
                if ca != cb { return ca < cb }
                if a.colorName != b.colorName { return a.colorName < b.colorName }
                return a.name < b.name
            }
        case .partNumber:
            return { a, b in a.partNum < b.partNum }
        }
    }

    func resetAllParts(_ parts: [LegoPartInstance]) {
        for part in parts {
            part.missingQty = 0
        }
    }
}
