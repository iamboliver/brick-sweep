import Foundation

protocol RebrickableAPIClientProtocol: Sendable {
    func fetchSet(setNum: String) async throws -> RebrickableSetDTO
    func fetchSetParts(setNum: String) async throws -> [RebrickableSetPartDTO]
    func fetchSetMinifigs(setNum: String) async throws -> [RebrickableMinifigDTO]
    func fetchColor(id: Int) async throws -> RebrickableColorDTO
    func addSetToCollection(userToken: String, setNum: String) async throws
}

struct RebrickableAPIClient: RebrickableAPIClientProtocol {
    private let baseURL = "https://rebrickable.com/api/v3/lego/"
    private let maxPages = 100
    private let session: URLSession
    private let apiKeyProvider: @Sendable () -> String?

    init(
        session: URLSession = {
            let config = URLSessionConfiguration.default
            config.timeoutIntervalForRequest = 15
            return URLSession(configuration: config)
        }(),
        apiKeyProvider: @escaping @Sendable () -> String?
    ) {
        self.session = session
        self.apiKeyProvider = apiKeyProvider
    }

    func fetchSet(setNum: String) async throws -> RebrickableSetDTO {
        let url = "\(baseURL)sets/\(setNum)/"
        return try await fetch(urlString: url)
    }

    func fetchSetParts(setNum: String) async throws -> [RebrickableSetPartDTO] {
        var allParts: [RebrickableSetPartDTO] = []
        var urlString: String? =
            "\(baseURL)sets/\(setNum)/parts/?page_size=1000&inc_color_details=1&inc_part_details=1&inc_minifig_parts=1"
        var pageCount = 0

        while let currentURL = urlString, pageCount < maxPages {
            let page: PaginatedResponse<RebrickableSetPartDTO> = try await fetch(urlString: currentURL)
            allParts.append(contentsOf: page.results)
            urlString = page.next
            pageCount += 1
        }

        return allParts
    }

    func fetchSetMinifigs(setNum: String) async throws -> [RebrickableMinifigDTO] {
        var allMinifigs: [RebrickableMinifigDTO] = []
        var urlString: String? = "\(baseURL)sets/\(setNum)/minifigs/"
        var pageCount = 0

        while let currentURL = urlString, pageCount < maxPages {
            let page: PaginatedResponse<RebrickableMinifigDTO> = try await fetch(urlString: currentURL)
            allMinifigs.append(contentsOf: page.results)
            urlString = page.next
            pageCount += 1
        }

        return allMinifigs
    }

    func fetchColor(id: Int) async throws -> RebrickableColorDTO {
        let url = "\(baseURL)colors/\(id)/"
        return try await fetch(urlString: url)
    }

    func addSetToCollection(userToken: String, setNum: String) async throws {
        guard let apiKey = apiKeyProvider(), !apiKey.isEmpty else {
            throw APIError.missingAPIKey
        }

        let urlString = "https://rebrickable.com/api/v3/users/\(userToken)/sets/"
        guard let url = URL(string: urlString) else {
            throw APIError.invalidURL(urlString)
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("key \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.httpBody = "set_num=\(setNum)".data(using: .utf8)

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw APIError.networkError(underlying: error)
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.networkError(underlying: URLError(.badServerResponse))
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            let body = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw APIError.syncFailed(body)
        }
    }

    private func fetch<T: Decodable>(urlString: String) async throws -> T {
        guard let apiKey = apiKeyProvider(), !apiKey.isEmpty else {
            throw APIError.missingAPIKey
        }

        guard let url = URL(string: urlString) else {
            throw APIError.invalidURL(urlString)
        }

        var request = URLRequest(url: url)
        request.setValue("key \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw APIError.networkError(underlying: error)
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.networkError(underlying: URLError(.badServerResponse))
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            if httpResponse.statusCode == 404 {
                throw APIError.setNotFound(urlString)
            }
            let body = String(data: data, encoding: .utf8)
            throw APIError.httpError(statusCode: httpResponse.statusCode, body: body)
        }

        do {
            let decoder = JSONDecoder()
            return try decoder.decode(T.self, from: data)
        } catch {
            throw APIError.decodingError(underlying: error)
        }
    }
}
