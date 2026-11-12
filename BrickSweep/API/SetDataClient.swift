import Foundation

protocol SetDataClientProtocol: Sendable {
    func fetchSetFile(setNum: String) async throws -> SetDataFile
}

enum SetDataError: LocalizedError {
    case notInCatalogue(setNum: String)
    case unsupportedSchema(version: Int)
    case rateLimited(retryAfter: Duration)
    case unavailable(underlying: Error?)
    case invalidData(underlying: Error)

    var errorDescription: String? {
        switch self {
        case .notInCatalogue(let setNum):
            "Set \(setNum) isn't in BrickSweep's set list. Check the number on the box or instructions. Brand-new sets can take a day to appear. If you have a Rebrickable API key, you can add it in Settings to look sets up directly."
        case .unsupportedSchema:
            "This set's data needs a newer version of BrickSweep. Update the app from the App Store, then try again."
        case .rateLimited(let retryAfter):
            "BrickSweep's set data is busy. Try again in \(max(1, Int(retryAfter.components.seconds))) seconds."
        case .unavailable:
            "BrickSweep couldn't download this set. Check your connection, then try again."
        case .invalidData:
            "BrickSweep couldn't read this set's data. Please try again later."
        }
    }
}

/// Downloads per-set files from data.bricksweep.app. No API key is needed: the files
/// are static, rebuilt daily from Rebrickable's public downloads and served from
/// Cloudflare's cache.
struct SetDataClient: SetDataClientProtocol {
    static let defaultBaseURL = URL(string: "https://data.bricksweep.app/v1/")!
    private static let userAgent = AppConstants.userAgent
    private static let maxAttempts = 3
    private static let firstRetryDelay = Duration.seconds(1)
    /// The longest `Retry-After` worth waiting through while the import overlay is up.
    /// A longer one fails straight away and tells the user when to try again.
    static let maxRetryAfter = Duration.seconds(20)

    private let session: URLSession
    private let baseURL: URL
    private let sleep: @Sendable (Duration) async throws -> Void

    init(
        session: URLSession = .shared,
        baseURL: URL = Self.defaultBaseURL,
        sleep: @escaping @Sendable (Duration) async throws -> Void = { try await Task.sleep(for: $0) }
    ) {
        self.session = session
        self.baseURL = baseURL
        self.sleep = sleep
    }

    /// The file for a set: `sets/<set number lowercased>.json`. Nil for set numbers
    /// with characters no Rebrickable set number uses.
    static func fileURL(setNum: String, baseURL: URL = defaultBaseURL) -> URL? {
        let name = setNum.lowercased()
        let allowed = Set("abcdefghijklmnopqrstuvwxyz0123456789-.")
        guard !name.isEmpty, name.allSatisfy(allowed.contains), !name.hasPrefix(".") else {
            return nil
        }
        return URL(string: "sets/\(name).json", relativeTo: baseURL)?.absoluteURL
    }

    static func decode(_ data: Data) throws -> SetDataFile {
        struct Header: Decodable { let schemaVersion: Int }

        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        let header: Header
        do {
            header = try decoder.decode(Header.self, from: data)
        } catch {
            throw SetDataError.invalidData(underlying: error)
        }
        // Check the version first: a newer format may not decode as this one.
        guard header.schemaVersion == SetDataFile.supportedSchemaVersion else {
            throw SetDataError.unsupportedSchema(version: header.schemaVersion)
        }
        do {
            return try decoder.decode(SetDataFile.self, from: data)
        } catch {
            throw SetDataError.invalidData(underlying: error)
        }
    }

    func fetchSetFile(setNum: String) async throws -> SetDataFile {
        guard let url = Self.fileURL(setNum: setNum, baseURL: baseURL) else {
            throw SetDataError.notInCatalogue(setNum: setNum)
        }
        return try Self.decode(try await download(url, setNum: setNum))
    }

    // Retries network errors, 429s and 5xx responses with exponential backoff, waiting
    // instead for as long as a 429's Retry-After header asks.
    private func download(_ url: URL, setNum: String) async throws -> Data {
        var request = URLRequest(url: url)
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue(Self.userAgent, forHTTPHeaderField: "User-Agent")

        var delay = Self.firstRetryDelay
        var lastError: Error?
        var retryAfter: Duration?
        for attempt in 0..<Self.maxAttempts {
            if attempt > 0 {
                try await sleep(retryAfter ?? delay)
                delay *= 2
            }
            retryAfter = nil

            let data: Data
            let response: URLResponse
            do {
                (data, response) = try await session.data(for: request)
            } catch {
                if error is CancellationError || (error as? URLError)?.code == .cancelled {
                    throw error
                }
                lastError = error
                continue
            }

            let status = (response as? HTTPURLResponse)?.statusCode ?? 0
            switch status {
            case 200...299:
                return data
            case 404:
                throw SetDataError.notInCatalogue(setNum: setNum)
            case 429:
                lastError = URLError(.badServerResponse)
                if let seconds = (response as? HTTPURLResponse)?.retryAfter {
                    let wait = Duration.seconds(seconds)
                    guard wait <= Self.maxRetryAfter else {
                        throw SetDataError.rateLimited(retryAfter: wait)
                    }
                    retryAfter = wait
                }
            case 500...599:
                lastError = URLError(.badServerResponse)
            default:
                throw SetDataError.unavailable(underlying: URLError(.badServerResponse))
            }
        }
        if let retryAfter {
            throw SetDataError.rateLimited(retryAfter: retryAfter)
        }
        throw SetDataError.unavailable(underlying: lastError)
    }
}

extension SetDataClient {
    /// The client the app uses. Debug builds can slow or fail downloads from the scheme's
    /// environment, so the download and failure paths can be tried by hand without a network.
    static func forApp() -> SetDataClientProtocol {
        #if DEBUG
        DebugSetDataClient(wrapping: SetDataClient())
        #else
        SetDataClient()
        #endif
    }
}

#if DEBUG
/// BRICKSWEEP_SLOW_IMPORT=<seconds> waits before each download; BRICKSWEEP_FAIL_IMPORT=1
/// fails each one as if the device were offline. With neither set it passes straight through.
struct DebugSetDataClient: SetDataClientProtocol {
    let wrapping: SetDataClientProtocol

    func fetchSetFile(setNum: String) async throws -> SetDataFile {
        let environment = ProcessInfo.processInfo.environment
        if let seconds = environment["BRICKSWEEP_SLOW_IMPORT"].flatMap(Double.init), seconds > 0 {
            try await Task.sleep(for: .seconds(seconds))
        }
        if environment["BRICKSWEEP_FAIL_IMPORT"] == "1" {
            throw SetDataError.unavailable(underlying: URLError(.notConnectedToInternet))
        }
        return try await wrapping.fetchSetFile(setNum: setNum)
    }
}
#endif
