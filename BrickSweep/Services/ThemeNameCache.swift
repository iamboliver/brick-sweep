import Foundation

actor ThemeNameCache {
    static let shared = ThemeNameCache()

    private var namesById: [Int: String] = [:]

    func name(for id: Int, apiClient: RebrickableAPIClientProtocol) async -> String? {
        if let cached = namesById[id] {
            return cached
        }

        guard let theme = try? await apiClient.fetchTheme(id: id) else {
            return nil
        }

        namesById[id] = theme.name
        return theme.name
    }

    func topLevelName(for id: Int, apiClient: RebrickableAPIClientProtocol) async -> String? {
        var currentId = id
        var currentName: String?
        var visited: Set<Int> = []

        while !visited.contains(currentId) {
            visited.insert(currentId)

            guard let theme = try? await apiClient.fetchTheme(id: currentId) else {
                return currentName ?? namesById[id]
            }

            namesById[theme.id] = theme.name
            currentName = theme.name

            guard let parentId = theme.parentId else {
                return theme.name
            }
            currentId = parentId
        }

        return currentName
    }
}
