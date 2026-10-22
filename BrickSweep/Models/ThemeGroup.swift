import Foundation

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

    var completedTypeCount: Int {
        sets.reduce(0) { total, set in
            total + set.parts.filter { $0.missingQty == 0 }.count
        }
    }

    var trackedTypeCount: Int {
        sets.reduce(0) { $0 + $1.parts.count }
    }

    init(name: String, sets: [LegoSet]) {
        self.id = name
        self.name = name
        self.sets = sets
    }

    static func == (lhs: ThemeGroup, rhs: ThemeGroup) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
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
