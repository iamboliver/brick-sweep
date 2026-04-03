import Foundation

enum APIError: LocalizedError {
    case missingAPIKey
    case invalidURL(String)
    case httpError(statusCode: Int, body: String?)
    case decodingError(underlying: Error)
    case networkError(underlying: Error)
    case setNotFound(String)
    case syncFailed(String)

    var errorDescription: String? {
        switch self {
        case .missingAPIKey:
            "No API key configured. Please add your Rebrickable API key in Settings."
        case .invalidURL(let url):
            "Invalid URL: \(url)"
        case .httpError(let statusCode, _):
            "Server returned error \(statusCode)."
        case .decodingError(let underlying):
            "Failed to parse response: \(underlying.localizedDescription)"
        case .networkError(let underlying):
            "Network error: \(underlying.localizedDescription)"
        case .setNotFound(let setNum):
            "Set \(setNum) not found on Rebrickable."
        case .syncFailed(let detail):
            "Failed to sync set to Rebrickable: \(detail)"
        }
    }
}
