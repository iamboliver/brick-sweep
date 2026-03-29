import Observation

@MainActor
@Observable
final class AppNavigator {
    var selectedTab: AppTab = .sets
}

enum AppTab: String {
    case sets, missing, replaced, settings
}
