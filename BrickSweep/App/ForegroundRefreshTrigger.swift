import SwiftUI

/// Decides when returning to the app should recheck Pro access: once each time the app
/// comes back from the background. iOS reports that as background → inactive → active,
/// so waiting for a direct background → active change never fires. Brief interruptions
/// such as Control Center (active → inactive → active) don't trigger a recheck.
struct ForegroundRefreshTrigger {
    private var wasInBackground = false

    /// Records a scene phase change. True when it's time to refresh.
    mutating func shouldRefresh(after phase: ScenePhase) -> Bool {
        switch phase {
        case .background:
            wasInBackground = true
            return false
        case .active where wasInBackground:
            wasInBackground = false
            return true
        default:
            return false
        }
    }
}
