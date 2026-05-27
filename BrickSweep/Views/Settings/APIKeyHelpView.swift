import SwiftUI

struct APIKeyHelpView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Label {
                        Text("BrickSweep uses Rebrickable to download set inventories and part details.")
                    } icon: {
                        Image(systemName: "square.stack.3d.up.fill")
                    }

                    Label {
                        Text("Create a free Rebrickable API key, then paste it into Settings.")
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
            .navigationTitle("API Key Help")
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
