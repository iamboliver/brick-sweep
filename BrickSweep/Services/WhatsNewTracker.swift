import Foundation

/// Decides whether to show What's New: once per version, only to people who used an
/// earlier version, never on a fresh install.
///
/// 1.0 didn't record a last-seen version, so on the first launch of 1.1 an upgrade and
/// a fresh install look the same. Founder status settles it: a founding member first
/// installed 1.0 (bs-btk.1). From 1.1 on, the recorded version is enough.
struct WhatsNewTracker {
    private let defaults: UserDefaults
    private let currentVersion: String
    private let releaseForVersion: (String) -> WhatsNewRelease?

    init(
        defaults: UserDefaults = .standard,
        currentVersion: String = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "",
        releaseForVersion: @escaping (String) -> WhatsNewRelease? = WhatsNewRelease.release(for:)
    ) {
        self.defaults = defaults
        self.currentVersion = currentVersion
        self.releaseForVersion = releaseForVersion
    }

    private var lastSeenVersion: String? {
        defaults.string(forKey: AppConstants.UserDefaultsKeys.whatsNewLastSeenVersion)
    }

    /// The release to show now, if any. Once it has decided, it records this version as
    /// seen, so the sheet appears at most once per version.
    /// - Parameter isFoundingUser: Nil while founder status isn't known yet (first launch
    ///   offline, say); with no recorded version it then decides on a later launch.
    func releaseToShow(isFoundingUser: Bool?) -> WhatsNewRelease? {
        guard !currentVersion.isEmpty, lastSeenVersion != currentVersion else { return nil }

        if lastSeenVersion == nil {
            guard let isFoundingUser else { return nil }
            if !isFoundingUser {
                // A fresh install: nothing is new to them.
                markSeen()
                return nil
            }
        }
        markSeen()
        return releaseForVersion(currentVersion)
    }

    /// True once this version has been recorded as seen, so there's nothing left to decide.
    var hasDecided: Bool { lastSeenVersion == currentVersion }

    private func markSeen() {
        defaults.set(currentVersion, forKey: AppConstants.UserDefaultsKeys.whatsNewLastSeenVersion)
    }
}
