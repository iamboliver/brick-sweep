import SwiftData
import SwiftUI

@main
struct BrickSweepApp: App {
    @State private var navigator = AppNavigator()
    @State private var storeManager = StoreManager()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(navigator)
                .environment(storeManager)
        }
        .modelContainer(for: [LegoSet.self, LegoPartInstance.self])
    }
}
