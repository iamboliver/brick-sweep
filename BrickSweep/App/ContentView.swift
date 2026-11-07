import SwiftUI

struct ContentView: View {
    @Environment(AppNavigator.self) private var navigator
    @Environment(StoreManager.self) private var storeManager
    @State private var whatsNew: WhatsNewRelease?
    @State private var didCheckWhatsNew = false

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
        .onChange(of: storeManager.hasCheckedFoundingStatus, initial: true) { _, checked in
            checkWhatsNew(founderStatusKnown: checked)
        }
        .sheet(item: $whatsNew) { release in
            WhatsNewView(release: release, isFoundingUser: storeManager.isFoundingUser) {
                navigator.selectedTab = .settings
            }
        }
    }

    /// Runs at launch and again once founder status is known, deciding at most once.
    private func checkWhatsNew(founderStatusKnown: Bool) {
        guard !didCheckWhatsNew else { return }
        let tracker = WhatsNewTracker()
        let release = tracker.releaseToShow(isFoundingUser: founderStatusKnown ? storeManager.isFoundingUser : nil)
        if release != nil || tracker.hasDecided {
            didCheckWhatsNew = true
            whatsNew = release
        }
    }
}
