import SwiftUI

struct APIKeyHelpView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Label {
                        Text("You don't need a key. BrickSweep downloads set inventories from its own copy of Rebrickable's data, updated daily.")
                    } icon: {
                        Image(systemName: "square.stack.3d.up.fill")
                    }

                    Label {
                        Text("With a free Rebrickable API key, BrickSweep looks sets up on Rebrickable directly instead, so sets added there today appear straight away. Paste your key into Settings, then tap Test Connection.")
                    } icon: {
                        Image(systemName: "key.fill")
                    }

                    Label {
                        Text("Your key is stored in this device's Keychain and sent only to Rebrickable.")
                    } icon: {
                        Image(systemName: "lock.shield.fill")
                    }
                }

                Section {
                    Link(destination: URL(string: AppConstants.Support.rebrickableAPIURL)!) {
                        Label("Get a free API key", systemImage: "safari")
                    }
                }
            }
            .navigationTitle("Your Own API Key")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}
