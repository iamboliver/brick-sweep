import SwiftUI

struct SettingsTabView: View {
    private static let keychainKey = "rebrickable_api_key"
    private static let userTokenKey = "rebrickable_user_token"

    @State private var apiKey: String = ""
    @State private var showSavedConfirmation = false
    @State private var userToken: String = ""
    @State private var showTokenSavedConfirmation = false
    @State private var syncOnImport: Bool = UserDefaults.standard.bool(forKey: "syncSetsToRebrickable")

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    SecureField("Rebrickable API Key", text: $apiKey)
                        .textContentType(.password)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)

                    Button("Save API Key") {
                        let success = KeychainHelper.save(key: Self.keychainKey, value: apiKey)
                        if success {
                            showSavedConfirmation = true
                        }
                    }
                    .disabled(apiKey.trimmingCharacters(in: .whitespaces).isEmpty)
                } header: {
                    Label("API Key", systemImage: "key.fill")
                } footer: {
                    Text("Get a free API key from rebrickable.com/api/")
                }

                Section {
                    SecureField("User Token", text: $userToken)
                        .textContentType(.password)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)

                    Button("Save Token") {
                        let success = KeychainHelper.save(key: Self.userTokenKey, value: userToken)
                        if success {
                            showTokenSavedConfirmation = true
                        }
                    }
                    .disabled(userToken.trimmingCharacters(in: .whitespaces).isEmpty)

                    Toggle("Sync sets on import", isOn: $syncOnImport)
                        .onChange(of: syncOnImport) { _, newValue in
                            UserDefaults.standard.set(newValue, forKey: "syncSetsToRebrickable")
                        }
                } header: {
                    Label("Rebrickable Sync", systemImage: "arrow.triangle.2.circlepath")
                } footer: {
                    Text("Paste your user token from rebrickable.com → Account → Settings → API. When enabled, imported sets are automatically added to your Rebrickable collection.")
                }

                Section("Resources") {
                    Link(destination: URL(string: "https://rebrickable.com/api/")!) {
                        Label("Get API Key", systemImage: "globe")
                    }
                    Link(destination: URL(string: "https://rebrickable.com/api/v3/docs/")!) {
                        Label("Rebrickable Documentation", systemImage: "book")
                    }
                }

                Section("About") {
                    LabeledContent {
                        Text(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0")
                    } label: {
                        Label("Version", systemImage: "info.circle")
                    }
                    LabeledContent {
                        Text(UIDevice.current.systemName + " " + UIDevice.current.systemVersion)
                    } label: {
                        Label("System", systemImage: "iphone")
                    }
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .alert("API Key Saved", isPresented: $showSavedConfirmation) {
                Button("OK", role: .cancel) {}
            }
            .alert("User Token Saved", isPresented: $showTokenSavedConfirmation) {
                Button("OK", role: .cancel) {}
            }
            .onAppear {
                if let stored = KeychainHelper.read(key: Self.keychainKey) {
                    apiKey = stored
                }
                if let storedToken = KeychainHelper.read(key: Self.userTokenKey) {
                    userToken = storedToken
                }
            }
        }
    }
}

enum APIKeyProvider {
    private static let keychainKey = "rebrickable_api_key"

    static func getAPIKey() -> String? {
        KeychainHelper.read(key: keychainKey)
    }
}

enum SyncTokenProvider {
    private static let keychainKey = "rebrickable_user_token"

    static func getUserToken() -> String? {
        KeychainHelper.read(key: keychainKey)
    }
}
