import Foundation
import SwiftUI
import Testing
@testable import BrickSweep

@MainActor
@Suite("Founding member Pro access")
struct StoreManagerTests {
    @MainActor
    private final class State {
        var purchased = false
        var version = "6"
    }

    private func withDefaults(_ body: (UserDefaults) async throws -> Void) async rethrows {
        let name = "StoreManagerTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        defer { defaults.removePersistentDomain(forName: name) }
        try await body(defaults)
    }

    @Test("Only verified builds through 6 unlock Pro", arguments: ["1", "5", "6", "7", "10", "1.0", "6.0", "", "invalid"])
    func originalBuild(_ version: String) async {
        await withDefaults { defaults in
            let store = StoreManager(defaults: defaults,
                appTransactionProvider: { .verified(originalAppVersion: version) },
                purchasedProProvider: { false }, startsAutomatically: false)
            store.foundingUserOverride = nil
            await store.refreshPurchaseStatus()
            #expect(store.isFoundingUser == ["1", "5", "6"].contains(version))
            #expect(store.isPro == ["1", "5", "6"].contains(version))
            #expect(store.hasCheckedFoundingStatus)
            #expect(defaults.bool(forKey: AppConstants.UserDefaultsKeys.verifiedFoundingUser) == ["1", "5", "6"].contains(version))
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
                appTransactionProvider: { .verified(originalAppVersion: "6") },
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
            #expect(!store.hasCheckedFoundingStatus)
        }
    }

    @Test("Purchase and founder access are independent", arguments: [true, false], [true, false])
    func combinedAccess(founder: Bool, purchased: Bool) async {
        await withDefaults { defaults in
            let state = State()
            state.purchased = purchased
            let store = StoreManager(defaults: defaults,
                appTransactionProvider: { .verified(originalAppVersion: founder ? "6" : "7") },
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
            state.version = "7"
            await store.refreshPurchaseStatus()
            #expect(!store.isPro)
            #expect(!defaults.bool(forKey: AppConstants.UserDefaultsKeys.verifiedFoundingUser))
        }
    }

    @Test("Debug simulation never persists as a verified result")
    func debugOverride() async {
        await withDefaults { defaults in
            let store = StoreManager(defaults: defaults,
                appTransactionProvider: { .verified(originalAppVersion: "7") },
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

    @Test("A failed founder check can be retried, then unlocks Pro")
    func retryAfterFailedCheck() async {
        await withDefaults { defaults in
            let state = State()
            state.version = "offline"
            let store = StoreManager(defaults: defaults,
                appTransactionProvider: {
                    if state.version == "offline" { throw URLError(.notConnectedToInternet) }
                    return .verified(originalAppVersion: state.version)
                },
                purchasedProProvider: { false }, startsAutomatically: false)
            store.foundingUserOverride = nil
            await store.refreshPurchaseStatus()
            #expect(!store.hasCheckedFoundingStatus)
            #expect(!store.isPro)

            state.version = "6"
            await store.refreshPurchaseStatus()
            #expect(store.hasCheckedFoundingStatus)
            #expect(store.isPro)
        }
    }

    @Test("Restore tells a founder without a purchase why they have Pro")
    func restoreMessages() {
        #expect(StoreManager.restoreMessage(hasPurchasedPro: true, isFoundingUser: true) == "Purchases restored.")
        #expect(StoreManager.restoreMessage(hasPurchasedPro: true, isFoundingUser: false) == "Purchases restored.")
        #expect(StoreManager.restoreMessage(hasPurchasedPro: false, isFoundingUser: true).contains("founding member"))
        #expect(StoreManager.restoreMessage(hasPurchasedPro: false, isFoundingUser: false).contains("No previous"))
    }

    @Test("The shipped app build must be newer than the founding build (bs-91d)")
    func releaseBuildNumber() throws {
        let build = try #require(Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String)
        let buildNumber = try #require(Int(build))
        #expect(buildNumber > AppConstants.lastFoundingBuild,
                "bs-91d must bump the app build above 6 before shipping founder access")
    }
}

@Suite("Recheck Pro access on returning to the app")
struct ForegroundRefreshTriggerTests {
    @Test("Returning from the background refreshes once, through inactive as iOS reports it")
    func returnFromBackground() {
        var trigger = ForegroundRefreshTrigger()
        let phases: [ScenePhase] = [.active, .inactive, .background, .inactive, .active, .inactive, .active]
        #expect(phases.map { trigger.shouldRefresh(after: $0) } == [false, false, false, false, true, false, false])
    }

    @Test("A brief interruption without going to the background doesn't refresh")
    func briefInterruption() {
        var trigger = ForegroundRefreshTrigger()
        #expect(![ScenePhase.inactive, .active].contains { trigger.shouldRefresh(after: $0) })
    }
}
