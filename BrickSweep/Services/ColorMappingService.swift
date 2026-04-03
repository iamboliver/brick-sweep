import Foundation

struct ColorMappingService: Sendable {
    private let apiClient: RebrickableAPIClientProtocol?

    init(apiClient: RebrickableAPIClientProtocol? = nil) {
        self.apiClient = apiClient
    }

    func brickLinkColorId(for rebrickableColorId: Int, stored: Int?) async -> Int? {
        if let stored {
            return stored
        }

        if let apiClient {
            if let color = try? await apiClient.fetchColor(id: rebrickableColorId),
               let blId = color.externalIds?.brickLink?.extIds?.first
            {
                return blId
            }
        }

        return Self.staticMapping[rebrickableColorId]
    }

    static let staticMapping: [Int: Int] = {
        guard let url = Bundle.main.url(forResource: "rebrickable_bricklink_colors", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let mapping = try? JSONDecoder().decode([String: Int].self, from: data)
        else {
            return [:]
        }
        var result: [Int: Int] = [:]
        for (key, value) in mapping {
            if let intKey = Int(key) {
                result[intKey] = value
            }
        }
        return result
    }()
}
