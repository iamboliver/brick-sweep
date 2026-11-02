import SwiftData
import SwiftUI

@main
struct BrickSweepApp: App {
    @Environment(\.scenePhase) private var scenePhase
    @State private var navigator = AppNavigator()
    @State private var storeManager = StoreManager()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(navigator)
                .environment(storeManager)
                .onChange(of: scenePhase) { _, phase in
                    if phase == .active {
                        Task { await storeManager.refreshPurchaseStatus() }
                    }
                }
        }
        .modelContainer(for: [LegoSet.self, LegoPartInstance.self])
    }
}
