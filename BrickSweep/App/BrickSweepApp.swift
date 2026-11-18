import SwiftData
import SwiftUI

@main
struct BrickSweepApp: App {
    @Environment(\.scenePhase) private var scenePhase
    @State private var navigator = AppNavigator()
    @State private var storeManager = StoreManager()
    @State private var foregroundRefresh = ForegroundRefreshTrigger()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(navigator)
                .environment(storeManager)
                .onChange(of: scenePhase) { _, phase in
                    if foregroundRefresh.shouldRefresh(after: phase) {
                        Task { await storeManager.refreshPurchaseStatus() }
                    }
                }
        }
        .modelContainer(for: [LegoSet.self, LegoPartInstance.self], inMemory: Self.storesInMemory)
    }

    /// UI tests start from an empty collection on every launch and leave the real one alone.
    private static var storesInMemory: Bool {
        #if DEBUG
        ProcessInfo.processInfo.environment["BRICKSWEEP_UI_TEST"] == "1"
        #else
        false
        #endif
    }
}
