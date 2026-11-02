import Foundation
import Testing
@testable import BrickSweep

@MainActor
@Suite("Founding member Pro access")
struct StoreManagerTests {
    @MainActor
    private final class State {
        var purchased = false
        var version = "1"
    }

    private func withDefaults(_ body: (UserDefaults) async throws -> Void) async rethrows {
        let name = "StoreManagerTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        defer { defaults.removePersistentDomain(forName: name) }
        try await body(defaults)
    }

    @Test("Only the verified founding build unlocks Pro", arguments: ["1", "2", "10", "1.0", ""])
    func originalBuild(_ version: String) async {
        await withDefaults { defaults in
            let store = StoreManager(defaults: defaults,
                appTransactionProvider: { .verified(originalAppVersion: version) },
                purchasedProProvider: { false }, startsAutomatically: false)
            store.foundingUserOverride = nil
            await store.refreshPurchaseStatus()
            #expect(store.isFoundingUser == (version == "1"))
            #expect(store.isPro == (version == "1"))
            #expect(store.hasCheckedFoundingStatus)
            #expect(defaults.bool(forKey: AppConstants.UserDefaultsKeys.verifiedFoundingUser) == (version == "1"))
        }
    }

    @Test("Unverified records do not unlock Pro, including after a cached result")
    func unverified() async {
        await withDefaults { defaults in
            defaults.set(true, forKey: AppConstants.UserDefaultsKeys.verifiedFoundingUser)
            let store = StoreManager(defaults: defaults, appTransactionProvider: { .unverified },
                purchasedProProvider: { false }, startsAutomatically: false)
            store.foundingUserOverride = nil
            await store.refreshPurchaseStatus()
            #expect(!store.isPro)
            #expect(!defaults.bool(forKey: AppConstants.UserDefaultsKeys.verifiedFoundingUser))
        }
    }

    @Test("Verified founder access survives a new offline launch")
    func offlineCache() async {
        await withDefaults { defaults in
            let online = StoreManager(defaults: defaults,
                appTransactionProvider: { .verified(originalAppVersion: "1") },
                purchasedProProvider: { false }, startsAutomatically: false)
            online.foundingUserOverride = nil
            await online.refreshPurchaseStatus()
            let offline = StoreManager(defaults: defaults,
                appTransactionProvider: { throw URLError(.notConnectedToInternet) },
                purchasedProProvider: { false }, startsAutomatically: false)
            offline.foundingUserOverride = nil
            #expect(offline.isPro)
            await offline.refreshPurchaseStatus()
            #expect(offline.isPro)
            #expect(offline.hasCheckedFoundingStatus)
        }
    }

    @Test("Offline first launch does not invent founder access")
    func offlineWithoutCache() async {
        await withDefaults { defaults in
            let store = StoreManager(defaults: defaults,
                appTransactionProvider: { throw URLError(.notConnectedToInternet) },
                purchasedProProvider: { false }, startsAutomatically: false)
            store.foundingUserOverride = nil
            await store.refreshPurchaseStatus()
            #expect(!store.isPro)
            #expect(store.hasCheckedFoundingStatus)
        }
    }

    @Test("Purchase and founder access are independent", arguments: [true, false], [true, false])
    func combinedAccess(founder: Bool, purchased: Bool) async {
        await withDefaults { defaults in
            let state = State()
            state.purchased = purchased
            let store = StoreManager(defaults: defaults,
                appTransactionProvider: { .verified(originalAppVersion: founder ? "1" : "2") },
                purchasedProProvider: { state.purchased }, startsAutomatically: false)
            store.foundingUserOverride = nil
            await store.refreshPurchaseStatus()
            #expect(store.isPro == (founder || purchased))
            #expect(store.isFoundingUser == founder)
            state.purchased = false
            await store.refreshPurchaseStatus()
            #expect(store.isPro == founder)
        }
    }

    @Test("A later verified record replaces the cached result")
    func recheck() async {
        await withDefaults { defaults in
            let state = State()
            let store = StoreManager(defaults: defaults,
                appTransactionProvider: { .verified(originalAppVersion: state.version) },
                purchasedProProvider: { false }, startsAutomatically: false)
            store.foundingUserOverride = nil
            await store.refreshPurchaseStatus()
            state.version = "2"
            await store.refreshPurchaseStatus()
            #expect(!store.isPro)
            #expect(!defaults.bool(forKey: AppConstants.UserDefaultsKeys.verifiedFoundingUser))
        }
    }

    @Test("Debug simulation never persists as a verified result")
    func debugOverride() async {
        await withDefaults { defaults in
            let store = StoreManager(defaults: defaults,
                appTransactionProvider: { .verified(originalAppVersion: "2") },
                purchasedProProvider: { false }, startsAutomatically: false)
            store.foundingUserOverride = true
            await store.refreshPurchaseStatus()
            #expect(store.isPro)
            #expect(!defaults.bool(forKey: AppConstants.UserDefaultsKeys.verifiedFoundingUser))
            store.foundingUserOverride = false
            #expect(!store.isPro)
            store.foundingUserOverride = nil
            #expect(!store.isPro)
        }
    }

    @Test("The shipped app build must be newer than the founding build (bs-91d)")
    func releaseBuildNumber() throws {
        let build = try #require(Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String)
        #expect(build != AppConstants.foundingBuildNumber,
                "bs-91d must bump the app build before shipping founder access")
        #expect((Int(build) ?? 0) > 1)
    }
}
