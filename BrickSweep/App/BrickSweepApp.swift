import SwiftData
import SwiftUI

@main
struct BrickSweepApp: App {
    @State private var navigator = AppNavigator()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(navigator)
        }
        .modelContainer(for: [LegoSet.self, LegoPartInstance.self])
    }
}
