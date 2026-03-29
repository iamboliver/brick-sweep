import SwiftUI

struct ContentView: View {
    @Environment(AppNavigator.self) private var navigator

    var body: some View {
        TabView(selection: Binding(
            get: { navigator.selectedTab },
            set: { navigator.selectedTab = $0 }
        )) {
            Tab("Sets", systemImage: "square.stack.3d.up.fill", value: AppTab.sets) {
                SetsTabView()
            }

            Tab("Missing", systemImage: "exclamationmark.triangle.fill", value: AppTab.missing) {
                MissingPartsTabView()
            }

            Tab("Replaced", systemImage: "checkmark.circle.fill", value: AppTab.replaced) {
                ReplacedPartsTabView()
            }

            Tab("Settings", systemImage: "gearshape.fill", value: AppTab.settings) {
                SettingsTabView()
            }
        }
        .tint(AppTheme.legoYellow)
    }
}
