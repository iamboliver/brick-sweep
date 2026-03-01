import SwiftUI

struct ContentView: View {
    var body: some View {
        TabView {
            Tab("Sets", systemImage: "square.stack.3d.up.fill") {
                SetsTabView()
            }

            Tab("Missing", systemImage: "exclamationmark.triangle.fill") {
                MissingPartsTabView()
            }

            Tab("Settings", systemImage: "gearshape.fill") {
                SettingsTabView()
            }
        }
        .tint(AppTheme.legoYellow)
    }
}
