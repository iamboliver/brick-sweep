import SwiftData
import SwiftUI

@main
struct LegoMissingPartsApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(for: [LegoSet.self, LegoPartInstance.self])
    }
}
