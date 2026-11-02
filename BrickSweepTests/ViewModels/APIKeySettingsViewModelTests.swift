import Foundation
import Testing

@testable import BrickSweep

@MainActor
@Suite("API Key Settings")
struct APIKeySettingsViewModelTests {
    @Test("Loading shows a saved, tested key as verified")
    func loadsVerifiedKey() {
        let store = MockAPIKeyStore(key: "abc", verified: true)
        let model = APIKeySettingsViewModel(store: store, verify: { _ in })

        model.load()

        #expect(model.apiKey == "abc")
        #expect(model.hasStoredKey)
        #expect(model.testResult == .success)
    }

    @Test("A passing test marks the saved key verified")
    func testPasses() async {
        let store = MockAPIKeyStore()
        let model = APIKeySettingsViewModel(store: store, verify: { _ in })
        model.load()
        model.apiKey = "abc"

        model.test()
        await model.waitForTest()

        #expect(store.key == "abc")
        #expect(store.verified)
        #expect(model.testResult == .success)
        #expect(!model.isTesting)
    }

    @Test("A failing test leaves the key unverified and says why")
    func testFails() async {
        let store = MockAPIKeyStore()
        let model = APIKeySettingsViewModel(store: store, verify: { _ in
            throw APIError.httpError(statusCode: 401, body: nil)
        })
        model.load()
        model.apiKey = "bad"

        model.test()
        await model.waitForTest()

        #expect(!store.verified)
        guard case .failure(let message) = model.testResult else {
            Issue.record("expected a failure, got \(String(describing: model.testResult))")
            return
        }
        #expect(message.contains("not accepted"))
    }

    @Test("Testing a new key unverifies the old one while the check runs")
    func newKeyUnverifiedDuringTest() async {
        let gate = Gate()
        let store = MockAPIKeyStore(key: "old", verified: true)
        let model = APIKeySettingsViewModel(store: store, verify: { _ in await gate.wait() })
        model.load()
        model.apiKey = "new"

        model.test()

        #expect(store.key == "new")
        #expect(!store.verified)
        await gate.release()
        await model.waitForTest()
        #expect(store.verified)
    }

    @Test("Removing the key clears it and its verified flag")
    func removes() {
        let store = MockAPIKeyStore(key: "abc", verified: true)
        let model = APIKeySettingsViewModel(store: store, verify: { _ in })
        model.load()

        model.remove()

        #expect(store.key == nil)
        #expect(!store.verified)
        #expect(model.apiKey.isEmpty)
        #expect(!model.hasStoredKey)
        #expect(model.testResult == nil)
        #expect(model.removalError == nil)
    }

    @Test("If the Keychain won't delete the key, everything stays and the user is told")
    func removalFailureKeepsKey() {
        let store = MockAPIKeyStore(key: "abc", verified: true)
        store.deleteSucceeds = false
        let model = APIKeySettingsViewModel(store: store, verify: { _ in })
        model.load()

        model.remove()

        #expect(store.key == "abc")
        #expect(store.verified)
        #expect(model.apiKey == "abc")
        #expect(model.hasStoredKey)
        #expect(model.testResult == .success)
        #expect(model.removalError != nil)
    }

    @Test("A test that finishes after the key was removed changes nothing")
    func lateResultAfterRemoval() async {
        let gate = Gate()
        let store = MockAPIKeyStore()
        let model = APIKeySettingsViewModel(store: store, verify: { _ in await gate.wait() })
        model.load()
        model.apiKey = "abc"
        model.test()

        model.remove()
        await gate.release()
        await model.waitForTest()

        #expect(store.key == nil)
        #expect(!store.verified)
        #expect(model.testResult == nil)
        #expect(!model.isTesting)
        #expect(!model.hasStoredKey)
    }

    @Test("A test that finishes after a different key was saved doesn't verify that key")
    func lateResultAfterNewKeySaved() async {
        let gate = Gate()
        let store = MockAPIKeyStore()
        let model = APIKeySettingsViewModel(store: store, verify: { _ in await gate.wait() })
        model.load()
        model.apiKey = "tested"
        model.test()

        model.apiKey = "untested"
        model.save()
        await gate.release()
        await model.waitForTest()

        #expect(store.key == "untested")
        #expect(!store.verified)
        #expect(model.testResult == nil)
        #expect(!model.isTesting)
    }
}

/// An in-memory key store. Main-actor only, like the settings it backs.
final class MockAPIKeyStore: APIKeyStore {
    var key: String?
    var verified: Bool
    var deleteSucceeds = true

    init(key: String? = nil, verified: Bool = false) {
        self.key = key
        self.verified = verified
    }

    func read() -> String? { key }

    func save(_ key: String) -> Bool {
        self.key = key
        return true
    }

    func delete() -> Bool {
        guard deleteSucceeds else { return false }
        key = nil
        return true
    }

    func isVerified() -> Bool { verified }
    func setVerified(_ verified: Bool) { self.verified = verified }
}
