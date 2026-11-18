import Foundation

/// Equality includes the sets, not just the name: SwiftUI skips redrawing a row whose
/// group compares equal, so a name-only == left a theme's row stale after adding a set.
struct ThemeGroup: Identifiable, Hashable {
    let id: String
    let name: String
    let sets: [LegoSet]

    var setCount: Int {
        sets.count
    }

    var totalPartCount: Int {
        sets.reduce(0) { $0 + $1.numParts }
    }

    var missingTypeCount: Int {
        sets.reduce(0) { total, set in
            total + set.parts.filter { $0.missingQty > 0 }.count
        }
    }

    var totalRequiredQty: Int {
        sets.reduce(0) { $0 + $1.totalRequiredQty }
    }

    var accountedQty: Int {
        sets.reduce(0) { $0 + $1.accountedQty }
    }

    var completionProgress: CompletionProgress {
        CompletionProgress(completed: accountedQty, total: totalRequiredQty)
    }

    init(name: String, sets: [LegoSet]) {
        self.id = name
        self.name = name
        self.sets = sets
    }

    static func groups(from sets: [LegoSet]) -> [ThemeGroup] {
        let grouped = Dictionary(grouping: sets) { set in
            let name = set.themeName?.trimmingCharacters(in: .whitespacesAndNewlines)
            if let name, !name.isEmpty {
                return name
            }
            if let themeId = set.themeId {
                return "Theme \(themeId)"
            }
            return "Unknown Theme"
        }

        return grouped
            .map { ThemeGroup(name: $0.key, sets: $0.value.sorted { $0.name < $1.name }) }
            .sorted { lhs, rhs in
                if lhs.name == "Unknown Theme" { return false }
                if rhs.name == "Unknown Theme" { return true }
                return lhs.name.localizedStandardCompare(rhs.name) == .orderedAscending
            }
    }
}
