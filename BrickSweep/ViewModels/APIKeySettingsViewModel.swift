import Foundation

/// Where the user's own Rebrickable key and its "tested" flag are kept.
protocol APIKeyStore {
    func read() -> String?
    func save(_ key: String) -> Bool
    /// False when the key could not be removed and is still stored.
    func delete() -> Bool
    func isVerified() -> Bool
    func setVerified(_ verified: Bool)
}

/// The Keychain for the key, UserDefaults for whether it passed Test Connection.
struct KeychainAPIKeyStore: APIKeyStore {
    private static let keychainKey = AppConstants.Keychain.apiKey
    private static let verifiedKey = AppConstants.UserDefaultsKeys.hasVerifiedAPIKey

    func read() -> String? { KeychainHelper.read(key: Self.keychainKey) }
    func save(_ key: String) -> Bool { KeychainHelper.save(key: Self.keychainKey, value: key) }
    func delete() -> Bool { KeychainHelper.delete(key: Self.keychainKey) }
    func isVerified() -> Bool { UserDefaults.standard.bool(forKey: Self.verifiedKey) }
    func setVerified(_ verified: Bool) { UserDefaults.standard.set(verified, forKey: Self.verifiedKey) }
}

/// The "Your Own Rebrickable Key" section of Settings: saving, testing and removing the key.
@MainActor
@Observable
final class APIKeySettingsViewModel {
    enum TestResult: Equatable {
        case success
        case failure(String)
    }

    /// The key in the text field, which may differ from the saved key until it's saved.
    var apiKey = "" {
        didSet { keyEdited() }
    }
    private(set) var hasStoredKey = false
    private(set) var isTesting = false
    private(set) var testResult: TestResult?
    private(set) var removalError: String?
    var showSavedConfirmation = false

    private let store: APIKeyStore
    private let verify: @Sendable (String) async throws -> Void
    /// The key that last passed Test Connection, while it's still the saved key.
    private var lastVerifiedKey: String?
    private var testTask: Task<Void, Never>?
    /// Bumped whenever a pending test's result should no longer apply.
    private var testGeneration = 0

    /// - Parameter verify: Throws unless Rebrickable accepts the given key.
    init(
        store: APIKeyStore = KeychainAPIKeyStore(),
        verify: @escaping @Sendable (String) async throws -> Void = { key in
            // Colour 0 (Black) is a lightweight request that needs a valid key.
            _ = try await RebrickableAPIClient(apiKeyProvider: { key }).fetchColor(id: 0)
        }
    ) {
        self.store = store
        self.verify = verify
    }

    var canSubmitKey: Bool {
        !apiKey.trimmingCharacters(in: .whitespaces).isEmpty
    }

    func load() {
        let stored = store.read()
        lastVerifiedKey = nil
        apiKey = stored ?? ""
        hasStoredKey = stored != nil
        if hasStoredKey, store.isVerified() {
            lastVerifiedKey = apiKey
            testResult = .success
        }
    }

    func save() {
        guard canSubmitKey, store.save(apiKey) else { return }
        hasStoredKey = true
        removalError = nil
        if apiKey != lastVerifiedKey {
            markUnverified()
        }
        showSavedConfirmation = true
    }

    /// Saves the key in the field, then checks it with Rebrickable. The result only
    /// counts if that key is still the saved one when the response arrives.
    func test() {
        guard canSubmitKey else { return }
        guard store.save(apiKey) else {
            testResult = .failure("BrickSweep couldn't save this key. Try again.")
            return
        }
        hasStoredKey = true
        removalError = nil

        let key = apiKey
        if key != lastVerifiedKey {
            // The saved key is now untested; imports mustn't use it until it passes.
            markUnverified()
        }
        testTask?.cancel()
        testGeneration += 1
        let generation = testGeneration
        isTesting = true
        testResult = nil
        testTask = Task {
            let error: Error?
            do {
                try await verify(key)
                error = nil
            } catch let failure {
                error = failure
            }
            finishTest(generation: generation, key: key, error: error)
        }
    }

    /// Goes back to BrickSweep's data files for future imports. Sets already imported
    /// keep their parts and progress. If the Keychain refuses, nothing changes and the
    /// user is told.
    func remove() {
        guard store.delete() else {
            removalError = "BrickSweep couldn't remove your key from this device. Try again."
            return
        }
        testTask?.cancel()
        testGeneration += 1
        isTesting = false
        lastVerifiedKey = nil
        store.setVerified(false)
        testResult = nil
        removalError = nil
        apiKey = ""
        hasStoredKey = false
    }

    /// Waits for a pending Test Connection to finish. For tests.
    func waitForTest() async {
        await testTask?.value
    }

    private func finishTest(generation: Int, key: String, error: Error?) {
        // Removed, or superseded by a newer test, while this one was running.
        guard generation == testGeneration else { return }
        testTask = nil
        isTesting = false
        // A different key was saved meanwhile: this result says nothing about it.
        guard store.read() == key else { return }

        if let error {
            markUnverified()
            if apiKey == key {
                testResult = .failure(Self.failureMessage(for: error))
            }
        } else {
            store.setVerified(true)
            lastVerifiedKey = key
            if apiKey == key {
                testResult = .success
            }
        }
    }

    private func keyEdited() {
        guard let lastVerifiedKey, apiKey != lastVerifiedKey else { return }
        // The field no longer shows the tested key; the saved key stays verified until replaced.
        testResult = nil
    }

    private func markUnverified() {
        lastVerifiedKey = nil
        store.setVerified(false)
        testResult = nil
    }

    static func failureMessage(for error: Error) -> String {
        if let apiError = error as? APIError {
            switch apiError {
            case .missingAPIKey:
                return "Paste your Rebrickable API key, then tap Save API Key."
            case .httpError(let statusCode, _) where statusCode == 401 || statusCode == 403:
                return "That API key was not accepted. Copy it again from Rebrickable, paste it here, then tap Save API Key and Test Connection."
            case .rateLimited:
                return "Rebrickable is temporarily rate limiting requests. Wait a minute, then try again."
            case .networkError:
                return "BrickSweep could not reach Rebrickable. Check your connection, then try again."
            default:
                break
            }
        }
        return "BrickSweep could not verify this API key. Check it was copied correctly, then try again."
    }
}
