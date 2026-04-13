import SwiftUI

struct SettingsTabView: View {
    private static let keychainKey = AppConstants.Keychain.apiKey

    @Environment(StoreManager.self) private var storeManager
    @FocusState private var isFieldFocused: Bool
    @State private var apiKey: String = ""
    @State private var showSavedConfirmation = false
    @State private var isTestingKey = false
    @State private var testResult: TestResult?
    @State private var showPaywall = false

    private enum TestResult {
        case success
        case failure(String)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    SecureField("Rebrickable API Key", text: $apiKey)
                        .focused($isFieldFocused)
                        .textContentType(.password)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)

                    Button("Save API Key") {
                        isFieldFocused = false
                        let success = KeychainHelper.save(key: Self.keychainKey, value: apiKey)
                        if success {
                            showSavedConfirmation = true
                        }
                    }
                    .disabled(apiKey.trimmingCharacters(in: .whitespaces).isEmpty)

                    Button {
                        testAPIKey()
                    } label: {
                        HStack {
                            Text("Test Connection")
                            Spacer()
                            if isTestingKey {
                                ProgressView()
                            } else if let result = testResult {
                                switch result {
                                case .success:
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundStyle(.green)
                                case .failure:
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundStyle(.red)
                                }
                            }
                        }
                    }
                    .disabled(apiKey.trimmingCharacters(in: .whitespaces).isEmpty || isTestingKey)
                } header: {
                    Label("API Key", systemImage: "key.fill")
                } footer: {
                    if case .failure(let message) = testResult {
                        Text(message)
                            .foregroundStyle(.red)
                    } else {
                        Text("BrickSweep uses Rebrickable's free community database of 1M+ LEGO sets and parts. Not affiliated with or endorsed by Rebrickable.")
                    }
                }

                Section {
                    Label {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Rebrickable Sync")
                                .font(.body)
                            Text("Coming soon")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    } icon: {
                        Image(systemName: "arrow.triangle.2.circlepath")
                            .foregroundStyle(.secondary)
                    }
                    .foregroundStyle(.secondary)
                } header: {
                    Label("Sync", systemImage: "arrow.triangle.2.circlepath")
                } footer: {
                    Text("Automatic syncing of your sets to your Rebrickable collection is coming in a future update.")
                }

                Section {
                    if storeManager.isPro {
                        HStack {
                            Label("BrickSweep Pro", systemImage: "crown.fill")
                                .foregroundStyle(AppTheme.legoYellow)
                            Spacer()
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                        }
                    } else {
                        Button {
                            showPaywall = true
                        } label: {
                            Label("Upgrade to Pro", systemImage: "crown.fill")
                        }
                        .foregroundStyle(AppTheme.legoYellow)

                        Text(storeManager.proProduct.map { "One-time purchase — \($0.displayPrice)" } ?? "One-time purchase — £2.99")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }

                    Button {
                        Task { await storeManager.restorePurchases() }
                    } label: {
                        Text("Restore Purchases")
                    }
                    .disabled(storeManager.isLoading)
                } header: {
                    Label("BrickSweep Pro", systemImage: "crown.fill")
                } footer: {
                    if storeManager.isPro {
                        Text("You have BrickSweep Pro. Thank you for your support!")
                    } else {
                        Text("Unlock unlimited sets and BrickLink export. One-time purchase — no subscription, ever.")
                    }
                }

                Section("Resources") {
                    Link(destination: URL(string: "https://rebrickable.com/api/")!) {
                        Label("Get a free Rebrickable API key", systemImage: "globe")
                    }
                    Link(destination: URL(string: "https://rebrickable.com/api/v3/docs/")!) {
                        Label("Rebrickable Documentation", systemImage: "book")
                    }
                }

                Section {
                    Label("Your API key and user token are stored securely in your device's Keychain and are only sent directly to rebrickable.com. This app has no server — your data never leaves your device.", systemImage: "lock.shield")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    Link(destination: URL(string: "https://github.com/iamboliver/brick-sweep/blob/main/PRIVACY.md")!) {
                        Label("Privacy Policy", systemImage: "hand.raised")
                    }
                    Link(destination: URL(string: "https://github.com/iamboliver/brick-sweep")!) {
                        Label("View Source Code", systemImage: "chevron.left.forwardslash.chevron.right")
                    }
                } header: {
                    Label("Privacy", systemImage: "hand.raised.fill")
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
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") {
                        isFieldFocused = false
                    }
                }
            }
            .sheet(isPresented: $showPaywall) {
                PaywallView(context: .proFeature)
            }
            .alert("API Key Saved", isPresented: $showSavedConfirmation) {
                Button("OK", role: .cancel) {}
            }
            .onAppear {
                if let stored = KeychainHelper.read(key: Self.keychainKey) {
                    apiKey = stored
                }
            }
        }
    }

    private func testAPIKey() {
        isTestingKey = true
        testResult = nil
        // Save the current key first so the API client picks it up
        _ = KeychainHelper.save(key: Self.keychainKey, value: apiKey)
        let client = RebrickableAPIClient(apiKeyProvider: { APIKeyProvider.getAPIKey() })
        Task {
            do {
                // Fetch color 0 (Black) as a lightweight connectivity test
                _ = try await client.fetchColor(id: 0)
                testResult = .success
            } catch {
                testResult = .failure(error.localizedDescription)
            }
            isTestingKey = false
        }
    }
}

enum APIKeyProvider {
    static func getAPIKey() -> String? {
        KeychainHelper.read(key: AppConstants.Keychain.apiKey)
    }
}

enum SyncTokenProvider {
    static func getUserToken() -> String? {
        KeychainHelper.read(key: AppConstants.Keychain.userToken)
    }
}
