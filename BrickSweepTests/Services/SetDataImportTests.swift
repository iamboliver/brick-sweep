import Foundation
import SwiftData
import Testing

@testable import BrickSweep

// MARK: - Decoding the data files

@Suite("Set Data File Decoding")
struct SetDataFileDecodingTests {
    @Test("Decodes a 60272-1 file as the data job writes it")
    func decodes60272() throws {
        let file = try SetDataClient.decode(Data(Self.file60272.utf8))

        #expect(file.set.setNum == "60272-1")
        #expect(file.set.name == "Elite Police Boat Transport")
        #expect(file.set.year == 2020)
        #expect(file.set.themeId == 61)
        #expect(file.set.themeName == "City")
        #expect(file.set.numParts == 166)
        #expect(file.set.imgUrl == "https://cdn.rebrickable.com/media/sets/60272-1.jpg")
        #expect(file.parts.count == 5)
        #expect(file.minifigs.map(\.figNum) == ["fig-010285", "fig-010286"])

        let wheel = try #require(file.parts.first)
        #expect(wheel.partNum == "11208")
        #expect(wheel.colorId == 0)
        #expect(wheel.colorName == "Black")
        #expect(wheel.rgb == "05131D")
        #expect(wheel.quantity == 2)
        #expect(!wheel.isSpare)
        #expect(wheel.imgUrl == "https://cdn.rebrickable.com/media/parts/elements/6050828.jpg")
        #expect(wheel.elementId == "6050828")
        #expect(wheel.bricklinkPartNum == nil)
    }

    @Test("Refuses a newer schema version with an update-the-app message")
    func refusesNewerSchema() throws {
        let json = #"{"schema_version": 2, "set": {"renamed": true}}"#

        #expect {
            try SetDataClient.decode(Data(json.utf8))
        } throws: { error in
            guard case SetDataError.unsupportedSchema(let version) = error else { return false }
            return version == 2 && error.localizedDescription.contains("Update the app")
        }
    }

    @Test("Reports a damaged file as invalid data")
    func reportsInvalidData() {
        #expect {
            try SetDataClient.decode(Data(#"{"schema_version": 1, "set": {}}"#.utf8))
        } throws: { error in
            if case SetDataError.invalidData = error { return true }
            return false
        }
    }

    @Test(
        "File names are the lowercased set number",
        arguments: [
            ("60272-1", "https://data.bricksweep.app/v1/sets/60272-1.json"),
            ("ABC-1", "https://data.bricksweep.app/v1/sets/abc-1.json"),
            ("6.5-1", "https://data.bricksweep.app/v1/sets/6.5-1.json"),
        ]
    )
    func fileURL(setNum: String, expected: String) {
        #expect(SetDataClient.fileURL(setNum: setNum)?.absoluteString == expected)
    }

    @Test("Set numbers with characters no set uses have no file", arguments: ["60272/1", "../index", "", "60 272-1", ".hidden"])
    func rejectsUnusualSetNumbers(setNum: String) {
        #expect(SetDataClient.fileURL(setNum: setNum) == nil)
    }

    /// Trimmed from the real file, plus a spare and a split row the importer must handle.
    static let file60272 = """
    {"schema_version":1,"source":"Rebrickable (https://rebrickable.com)",
     "set":{"set_num":"60272-1","name":"Elite Police Boat Transport","year":2020,"theme_id":61,"theme_name":"City",
            "num_parts":166,"img_url":"https://cdn.rebrickable.com/media/sets/60272-1.jpg"},
     "parts":[
      {"part_num":"11208","name":"Wheel 14mm D. x 9.9mm with Centre Groove, Fake Bolts and 6 Spokes","color_id":0,
       "color_name":"Black","rgb":"05131D","quantity":2,"is_spare":false,
       "img_url":"https://cdn.rebrickable.com/media/parts/elements/6050828.jpg","element_id":"6050828",
       "bricklink_part_num":null,"from_minifig":null},
      {"part_num":"3001","name":"Brick 2 x 4","color_id":4,"color_name":"Red","rgb":"C91A09","quantity":1,
       "is_spare":false,"img_url":null,"element_id":"300121","bricklink_part_num":"3001","from_minifig":null},
      {"part_num":"3001","name":"Brick 2 x 4","color_id":4,"color_name":"Red","rgb":"C91A09","quantity":2,
       "is_spare":false,"img_url":null,"element_id":"300121","bricklink_part_num":"3001","from_minifig":null},
      {"part_num":"3001","name":"Brick 2 x 4","color_id":4,"color_name":"Red","rgb":"C91A09","quantity":1,
       "is_spare":true,"img_url":null,"element_id":"300121","bricklink_part_num":"3001","from_minifig":null},
      {"part_num":"25409","name":"Hair Tousled Mid-Length with Side Part","color_id":308,"color_name":"Dark Brown",
       "rgb":"352100","quantity":1,"is_spare":false,
       "img_url":"https://cdn.rebrickable.com/media/parts/elements/6303723.jpg","element_id":"6303723",
       "bricklink_part_num":null,"from_minifig":"fig-010285"}],
     "minifigs":[
      {"fig_num":"fig-010285","name":"Clara the Criminal","quantity":1,"num_parts":4,
       "img_url":"https://cdn.rebrickable.com/media/sets/fig-010285.jpg"},
      {"fig_num":"fig-010286","name":"Duke Detain, Helmet and Goggles","quantity":1,"num_parts":5,
       "img_url":"https://cdn.rebrickable.com/media/sets/fig-010286.jpg"}],
     "subsets":[]}
    """
}

// MARK: - Importing from the data files

@MainActor
@Suite("Set Import From Data Files")
struct SetDataImportTests {
    @Test("A new set gets its details and top-level theme from the file, with no API calls")
    func createSetFromFile() async throws {
        let apiClient = MockRebrickableAPIClient(setDTO: SetImportServiceTests.setDTO, partsPages: [:])
        let dataClient = MockSetDataClient(.success(try Self.decoded60272()))
        let harness = try TestHarness(apiClient: apiClient, setDataClient: dataClient, usesOwnAPIKey: { false })

        let set = try requireCreated(try await harness.service.createSet(setNum: "60272", modelContext: harness.context))

        #expect(set.setNum == "60272-1")
        #expect(set.name == "Elite Police Boat Transport")
        #expect(set.themeId == 61)
        #expect(set.themeName == "City")
        #expect(set.numParts == 166)
        #expect(set.isImporting)
        #expect(dataClient.calls.requested == ["60272-1"])
        #expect(apiClient.state.fetchSetCalls == 0)
        #expect(apiClient.state.fetchThemeCalls == 0)
    }

    @Test("Loading parts drops spares, sums split rows and adds minifigures")
    func loadPartsFromFile() async throws {
        let harness = try TestHarness(
            apiClient: MockRebrickableAPIClient(setDTO: SetImportServiceTests.setDTO, partsPages: [:]),
            setDataClient: MockSetDataClient(.success(try Self.decoded60272())),
            usesOwnAPIKey: { false }
        )

        let set = try await harness.service.importSet(setNum: "60272", modelContext: harness.context)

        #expect(!set.isImporting)
        #expect(!set.importFailed)
        let rows = set.parts.map { "\($0.partNum)/\($0.colorId)=\($0.requiredQty)" }.sorted()
        let minifig = LegoColorSortOrder.minifigColorId
        #expect(rows == ["11208/0=2", "25409/308=1", "3001/4=3", "fig-010285/\(minifig)=1", "fig-010286/\(minifig)=1"])

        let brick = try #require(set.parts.first { $0.partNum == "3001" })
        #expect(brick.elementId == "300121")
        #expect(brick.brickLinkPartNum == "3001")
        #expect(brick.brickLinkColorId == nil)
        let clara = try #require(set.parts.first { $0.partNum == "fig-010285" })
        #expect(clara.name == "Clara the Criminal")
        #expect(clara.colorName == "Minifigure")
        #expect(clara.imageUrl == "https://cdn.rebrickable.com/media/sets/fig-010285.jpg")
    }

    @Test("The same inventory imports identically from the API and from a data file")
    func parityWithAPIImport() async throws {
        let parts: [(String, Int, Int, Bool)] = [
            ("3001", 1, 2, false), ("3001", 1, 3, false), ("3001", 1, 1, true),
            ("3002", 2, 1, false), ("973pr1", 0, 2, false),
        ]
        let minifigs = [("fig-001", 1), ("fig-002", 2)]

        let apiHarness = try TestHarness(apiClient: MockRebrickableAPIClient(
            setDTO: SetImportServiceTests.setDTO,
            partsPages: [
                SetImportService.partsPageURL(setNum: "60272-1"): SetImportServiceTests.page(
                    parts.map { SetImportServiceTests.partDTO(partNum: $0.0, colorId: $0.1, quantity: $0.2, isSpare: $0.3) }
                ),
            ],
            minifigs: minifigs.map { SetImportServiceTests.minifigDTO(setNum: $0.0, quantity: $0.1) }
        ))
        let fileHarness = try TestHarness(
            apiClient: MockRebrickableAPIClient(setDTO: SetImportServiceTests.setDTO, partsPages: [:]),
            setDataClient: MockSetDataClient(.success(try Self.file(parts: parts, minifigs: minifigs))),
            usesOwnAPIKey: { false }
        )

        let fromAPI = try await apiHarness.service.importSet(setNum: "60272", modelContext: apiHarness.context)
        let fromFile = try await fileHarness.service.importSet(setNum: "60272", modelContext: fileHarness.context)

        #expect(Self.describe(fromFile.parts) == Self.describe(fromAPI.parts))
        #expect(fromFile.parts.count == 5)
    }

    @Test("A verified own key keeps the API path; otherwise the data files are used", arguments: [true, false])
    func selectsSource(usesOwnKey: Bool) async throws {
        let apiClient = MockRebrickableAPIClient(setDTO: SetImportServiceTests.setDTO, partsPages: [:])
        let dataClient = MockSetDataClient(.success(try Self.decoded60272()))
        let harness = try TestHarness(apiClient: apiClient, setDataClient: dataClient, usesOwnAPIKey: { usesOwnKey })

        _ = try await harness.service.importSet(setNum: "60272", modelContext: harness.context)

        #expect((apiClient.state.fetchSetCalls > 0) == usesOwnKey)
        #expect((apiClient.state.partPageCalls > 0) == usesOwnKey)
        #expect(dataClient.calls.requested.isEmpty == usesOwnKey)
    }

    @Test("A set missing from the files explains itself, points to Settings, and adds nothing")
    func setNotInFiles() async throws {
        let harness = try TestHarness(
            apiClient: MockRebrickableAPIClient(setDTO: SetImportServiceTests.setDTO, partsPages: [:]),
            setDataClient: MockSetDataClient(.failure(.notInCatalogue(setNum: "99999-1"))),
            usesOwnAPIKey: { false }
        )

        await #expect {
            _ = try await harness.service.createSet(setNum: "99999", modelContext: harness.context)
        } throws: { error in
            guard case SetDataError.notInCatalogue = error else { return false }
            let message = error.localizedDescription
            return message.contains("99999-1") && message.contains("Settings")
        }
        #expect(try harness.context.fetchCount(FetchDescriptor<LegoSet>()) == 0)
    }

    @Test("Retrying from a data file keeps the user's missing and replaced counts")
    func retryFromFileKeepsCounts() async throws {
        let harness = try TestHarness(
            apiClient: MockRebrickableAPIClient(setDTO: SetImportServiceTests.setDTO, partsPages: [:]),
            setDataClient: MockSetDataClient(.success(try Self.decoded60272())),
            usesOwnAPIKey: { false }
        )
        let set = try SetImportServiceTests.insertSet(
            setNum: "60272-1",
            parts: [.init("3001", 4, 3, missing: 2, replaced: 1), .init("gone", 1, 1, missing: 1)],
            importFailed: true,
            in: harness.context
        )

        try await harness.service.retryLoadParts(into: set, modelContext: harness.context)

        let brick = try #require(set.parts.first { $0.partNum == "3001" })
        #expect((brick.requiredQty, brick.missingQty, brick.replacedQty) == (3, 2, 1))
        #expect(!set.parts.contains { $0.partNum == "gone" })
        #expect(set.parts.count == 5)
        #expect(!set.importFailed)
    }

    @Test("A failed file download marks the set for retry and keeps its rows")
    func failedDownloadMarksSetFailed() async throws {
        let harness = try TestHarness(
            apiClient: MockRebrickableAPIClient(setDTO: SetImportServiceTests.setDTO, partsPages: [:]),
            setDataClient: MockSetDataClient(.failure(.unavailable(underlying: nil))),
            usesOwnAPIKey: { false }
        )
        let set = try SetImportServiceTests.insertSet(
            setNum: "60272-1",
            parts: [.init("3001", 4, 3, missing: 2)],
            importFailed: true,
            in: harness.context
        )

        await #expect(throws: SetDataError.self) {
            try await harness.service.retryLoadParts(into: set, modelContext: harness.context)
        }
        #expect(set.importFailed)
        #expect(set.isImporting)
        #expect(set.parts.map(\.missingQty) == [2])
    }

    @Test("A new set downloads its file once, and a retry downloads it again")
    func newImportFetchesFileOnce() async throws {
        let dataClient = MockSetDataClient(.success(try Self.decoded60272()))
        let harness = try TestHarness(
            apiClient: MockRebrickableAPIClient(setDTO: SetImportServiceTests.setDTO, partsPages: [:]),
            setDataClient: dataClient,
            usesOwnAPIKey: { false }
        )

        let set = try requireCreated(try await harness.service.createSet(setNum: "60272", modelContext: harness.context))
        dataClient.calls.setResult(.failure(.unavailable(underlying: nil)))
        try await harness.service.loadParts(into: set, setNum: set.setNum, modelContext: harness.context)

        #expect(dataClient.calls.requested == ["60272-1"])
        #expect(!set.isImporting)
        #expect(set.parts.count == 5)

        dataClient.calls.setResult(.success(try Self.decoded60272()))
        try await harness.service.retryLoadParts(into: set, modelContext: harness.context)

        #expect(dataClient.calls.requested == ["60272-1", "60272-1"])
    }

    @Test("Theme categorising uses the file when the user has no key")
    func refreshThemeFromFile() async throws {
        let apiClient = MockRebrickableAPIClient(setDTO: SetImportServiceTests.setDTO, partsPages: [:])
        let harness = try TestHarness(
            apiClient: apiClient,
            setDataClient: MockSetDataClient(.success(try Self.decoded60272())),
            usesOwnAPIKey: { false }
        )
        let set = try SetImportServiceTests.insertSet(setNum: "60272-1", parts: [], in: harness.context)

        await harness.service.refreshThemeMetadata(for: [set], modelContext: harness.context)

        #expect(set.themeId == 61)
        #expect(set.themeName == "City")
        #expect(apiClient.state.fetchSetCalls == 0)
    }

    // MARK: Helpers

    static func decoded60272() throws -> SetDataFile {
        try SetDataClient.decode(Data(SetDataFileDecodingTests.file60272.utf8))
    }

    /// A data file with the same names, colours and images SetImportServiceTests.partDTO
    /// and minifigDTO give the API path.
    static func file(parts: [(String, Int, Int, Bool)], minifigs: [(String, Int)]) throws -> SetDataFile {
        let json: [String: Any] = [
            "schema_version": 1,
            "set": [
                "set_num": "60272-1", "name": "Elite Police Boat Transport", "year": 2020,
                "theme_id": 52, "theme_name": "City", "num_parts": 166,
            ],
            "parts": parts.map { part in
                [
                    "part_num": part.0, "name": "Part \(part.0)", "color_id": part.1, "color_name": "Color \(part.1)",
                    "rgb": "FFFFFF", "quantity": part.2, "is_spare": part.3,
                ] as [String: Any]
            },
            "minifigs": minifigs.map { ["fig_num": $0.0, "name": "Minifig \($0.0)", "quantity": $0.1] as [String: Any] },
            "subsets": [],
        ]
        return try SetDataClient.decode(try JSONSerialization.data(withJSONObject: json))
    }

    static func describe(_ parts: [LegoPartInstance]) -> [String] {
        parts.map { part in
            [
                part.partNum, "\(part.colorId)", part.colorName, part.colorRgb, part.name, part.imageUrl ?? "-",
                "\(part.requiredQty)", "\(part.isSpare)", part.elementId ?? "-", part.brickLinkPartNum ?? "-",
                part.brickLinkColorId.map(String.init) ?? "-",
            ].joined(separator: "|")
        }
        .sorted()
    }
}

// MARK: - The HTTP client

@Suite("Set Data Client")
struct SetDataClientTests {
    @Test("Requests the lowercased file and decodes it")
    func fetchesLowercasedFile() async throws {
        let stub = StubServer(responses: [(200, Data(SetDataFileDecodingTests.file60272.utf8))])

        let file = try await stub.client.fetchSetFile(setNum: "ABC-1")

        #expect(file.set.setNum == "60272-1")
        #expect(stub.requestedPaths == ["/v1/sets/abc-1.json"])
    }

    @Test("A 404 means the set isn't in the files, and is not retried")
    func notFound() async throws {
        let stub = StubServer(responses: [(404, Data())])

        await #expect {
            _ = try await stub.client.fetchSetFile(setNum: "99999-1")
        } throws: { error in
            guard case SetDataError.notInCatalogue(let setNum) = error else { return false }
            return setNum == "99999-1"
        }
        #expect(stub.requestedPaths.count == 1)
    }

    @Test("Rate limiting and server errors are retried after a backoff", arguments: [429, 503])
    func retriesTransientErrors(status: Int) async throws {
        let stub = StubServer(responses: [(status, Data()), (200, Data(SetDataFileDecodingTests.file60272.utf8))])

        let file = try await stub.client.fetchSetFile(setNum: "60272-1")

        #expect(file.set.name == "Elite Police Boat Transport")
        #expect(stub.requestedPaths.count == 2)
        #expect(stub.sleeps == [.seconds(1)])
    }

    @Test("A 429 is retried after the wait its Retry-After header asks for")
    func honoursRetryAfter() async throws {
        let stub = StubServer(replies: [
            (429, Data(), ["Retry-After": "5"]),
            (200, Data(SetDataFileDecodingTests.file60272.utf8), [:]),
        ])

        let file = try await stub.client.fetchSetFile(setNum: "60272-1")

        #expect(file.set.name == "Elite Police Boat Transport")
        #expect(stub.sleeps == [.seconds(5)])
    }

    @Test("A Retry-After too long to wait through fails at once, saying when to try again")
    func longRetryAfterFailsFast() async throws {
        let stub = StubServer(replies: [(429, Data(), ["Retry-After": "60"])])

        await #expect {
            _ = try await stub.client.fetchSetFile(setNum: "60272-1")
        } throws: { error in
            guard case SetDataError.rateLimited(let wait) = error else { return false }
            return wait == .seconds(60) && error.localizedDescription.contains("60 seconds")
        }
        #expect(stub.requestedPaths.count == 1)
        #expect(stub.sleeps.isEmpty)
    }

    @Test("Still rate limited after every attempt reports the last Retry-After")
    func rateLimitedThroughout() async throws {
        let stub = StubServer(replies: Array(repeating: (429, Data(), ["Retry-After": "2"]), count: 3))

        await #expect {
            _ = try await stub.client.fetchSetFile(setNum: "60272-1")
        } throws: { error in
            guard case SetDataError.rateLimited(let wait) = error else { return false }
            return wait == .seconds(2)
        }
        #expect(stub.sleeps == [.seconds(2), .seconds(2)])
    }

    @Test("Gives up after three attempts")
    func givesUp() async throws {
        let stub = StubServer(responses: Array(repeating: (503, Data()), count: 3))

        await #expect {
            _ = try await stub.client.fetchSetFile(setNum: "60272-1")
        } throws: { error in
            if case SetDataError.unavailable = error { return true }
            return false
        }
        #expect(stub.requestedPaths.count == 3)
        #expect(stub.sleeps == [.seconds(1), .seconds(2)])
    }

    @Test("An unusual set number is rejected without a request")
    func rejectsWithoutRequest() async throws {
        let stub = StubServer(responses: [])

        await #expect(throws: SetDataError.self) {
            _ = try await stub.client.fetchSetFile(setNum: "60272/1")
        }
        #expect(stub.requestedPaths.isEmpty)
    }
}

// MARK: - Test doubles

final class MockSetDataClient: SetDataClientProtocol {
    final class Calls: @unchecked Sendable {
        private let lock = NSLock()
        private var _requested: [String] = []
        private var result: Result<SetDataFile, SetDataError>

        init(_ result: Result<SetDataFile, SetDataError>) { self.result = result }

        var requested: [String] { lock.withLock { _requested } }
        func setResult(_ result: Result<SetDataFile, SetDataError>) { lock.withLock { self.result = result } }
        func record(_ setNum: String) -> Result<SetDataFile, SetDataError> {
            lock.withLock {
                _requested.append(setNum)
                return result
            }
        }
    }

    let calls: Calls

    init(_ result: Result<SetDataFile, SetDataError>) {
        calls = Calls(result)
    }

    func fetchSetFile(setNum: String) async throws -> SetDataFile {
        try calls.record(setNum).get()
    }
}

/// Serves queued responses to a SetDataClient through URLProtocol. Each server has
/// its own host, so tests running in parallel don't share responses. The client's
/// waits between attempts are recorded instead of slept.
final class StubServer: @unchecked Sendable {
    typealias Reply = (status: Int, data: Data, headers: [String: String])

    private final class SleepLog: @unchecked Sendable {
        let lock = NSLock()
        var sleeps: [Duration] = []
    }

    let client: SetDataClient
    private let host = "stub-\(UUID().uuidString.lowercased()).test"
    private let lock = NSLock()
    private let sleepLog: SleepLog
    private var replies: [Reply]
    private var _requestedPaths: [String] = []

    var requestedPaths: [String] { lock.withLock { _requestedPaths } }
    var sleeps: [Duration] { sleepLog.lock.withLock { sleepLog.sleeps } }

    convenience init(responses: [(Int, Data)]) {
        self.init(replies: responses.map { ($0.0, $0.1, [:]) })
    }

    init(replies: [Reply]) {
        self.replies = replies
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [StubURLProtocol.self]
        let sleepLog = SleepLog()
        self.sleepLog = sleepLog
        client = SetDataClient(
            session: URLSession(configuration: configuration),
            baseURL: URL(string: "https://\(host)/v1/")!,
            sleep: { duration in sleepLog.lock.withLock { sleepLog.sleeps.append(duration) } }
        )
        StubURLProtocol.register(self, for: host)
    }

    fileprivate func respond(to request: URLRequest) -> Reply {
        lock.withLock {
            _requestedPaths.append(request.url?.path ?? "")
            return replies.isEmpty ? (500, Data(), [:]) : replies.removeFirst()
        }
    }
}

private final class StubURLProtocol: URLProtocol {
    private static let lock = NSLock()
    nonisolated(unsafe) private static var servers: [String: StubServer] = [:]

    static func register(_ server: StubServer, for host: String) {
        lock.withLock { servers[host] = server }
    }

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        guard let url = request.url,
              let server = Self.lock.withLock({ Self.servers[url.host ?? ""] }),
              let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)
        else {
            client?.urlProtocol(self, didFailWithError: URLError(.cannotFindHost))
            return
        }
        let (status, data, headers) = server.respond(to: request)
        let reply = HTTPURLResponse(url: url, statusCode: status, httpVersion: nil, headerFields: headers) ?? response
        client?.urlProtocol(self, didReceive: reply, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: data)
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}
