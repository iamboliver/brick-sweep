import Foundation
import Testing

@testable import BrickSweep

@Suite("What's New")
struct WhatsNewTrackerTests {
    private static let key = AppConstants.UserDefaultsKeys.whatsNewLastSeenVersion

    private func withDefaults(_ body: (UserDefaults) throws -> Void) rethrows {
        let name = "WhatsNewTrackerTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        defer { defaults.removePersistentDomain(forName: name) }
        try body(defaults)
    }

    private func tracker(_ defaults: UserDefaults, version: String = "1.1") -> WhatsNewTracker {
        WhatsNewTracker(defaults: defaults, currentVersion: version)
    }

    @Test("Upgrading from 1.0 shows it once; the next launch doesn't")
    func upgradeFrom10() {
        withDefaults { defaults in
            #expect(tracker(defaults).releaseToShow(isFoundingUser: true)?.version == "1.1")
            #expect(defaults.string(forKey: Self.key) == "1.1")
            #expect(tracker(defaults).releaseToShow(isFoundingUser: true) == nil)
        }
    }

    @Test("A fresh install doesn't show it, now or on a later launch")
    func freshInstall() {
        withDefaults { defaults in
            #expect(tracker(defaults).releaseToShow(isFoundingUser: false) == nil)
            #expect(defaults.string(forKey: Self.key) == "1.1")
            #expect(tracker(defaults).releaseToShow(isFoundingUser: false) == nil)
        }
    }

    @Test("While founder status is unknown it waits, recording nothing")
    func founderStatusUnknown() {
        withDefaults { defaults in
            let first = tracker(defaults)
            #expect(first.releaseToShow(isFoundingUser: nil) == nil)
            #expect(!first.hasDecided)
            #expect(defaults.string(forKey: Self.key) == nil)

            #expect(tracker(defaults).releaseToShow(isFoundingUser: true)?.version == "1.1")
        }
    }

    @Test("After 1.1, a recorded older version is enough: founder status doesn't matter")
    func laterUpdate() {
        withDefaults { defaults in
            defaults.set("1.0", forKey: Self.key)
            #expect(tracker(defaults).releaseToShow(isFoundingUser: false)?.version == "1.1")
            defaults.set("1.0", forKey: Self.key)
            #expect(tracker(defaults).releaseToShow(isFoundingUser: nil)?.version == "1.1")
        }
    }

    @Test("A version with nothing to announce shows nothing but is still recorded")
    func versionWithoutRelease() {
        withDefaults { defaults in
            defaults.set("1.1", forKey: Self.key)
            let next = tracker(defaults, version: "1.1.1")
            #expect(next.releaseToShow(isFoundingUser: true) == nil)
            #expect(next.hasDecided)
            #expect(defaults.string(forKey: Self.key) == "1.1.1")
        }
    }

    @Test("1.1 has a note, its features and a founding-member gift")
    func content11() throws {
        let release = try #require(WhatsNewRelease.release(for: "1.1"))
        #expect(!release.note.isEmpty)
        #expect(release.features.count == 3)
        #expect(release.foundingGift != nil)
    }
}
