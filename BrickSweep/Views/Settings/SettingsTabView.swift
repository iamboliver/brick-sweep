import SwiftUI

struct SettingsTabView: View {
    @Environment(StoreManager.self) private var storeManager
    @Environment(\.openURL) private var openURL
    @FocusState private var isFieldFocused: Bool
    @State private var keySettings = APIKeySettingsViewModel()
    @State private var showPaywall = false
    @State private var showAPIKeyHelp = false
    @State private var showFeedbackFallback = false

    var body: some View {
        NavigationStack {
            Form {
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

                        Text(storeManager.proProduct.map { "One-time purchase — \($0.displayPrice)" } ?? "One-time purchase")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }

                    Button {
                        Task { await storeManager.restorePurchases() }
                    } label: {
                        Text("Restore Purchases")
                    }
                    .disabled(storeManager.isLoading)

                    if let error = storeManager.purchaseError {
                        Text(error)
                            .font(.footnote)
                            .foregroundStyle(.red)
                    } else if let message = storeManager.purchaseMessage {
                        Text(message)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                } header: {
                    Label("BrickSweep Pro", systemImage: "crown.fill")
                } footer: {
                    if storeManager.isFoundingUser {
                        Text("Founding member: Pro unlocked. Thank you for being here early.")
                    } else if storeManager.isPro {
                        Text("You have BrickSweep Pro. Thank you for your support!")
                    } else {
                        Text("Unlock unlimited sets and BrickLink export. One-time purchase — no subscription, ever.")
                    }
                }

                Section {
                    SecureField("Rebrickable API Key", text: $keySettings.apiKey)
                        .focused($isFieldFocused)
                        .textContentType(.password)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)

                    Button("Save API Key") {
                        isFieldFocused = false
                        keySettings.save()
                    }
                    .disabled(!keySettings.canSubmitKey)

                    Button {
                        isFieldFocused = false
                        keySettings.test()
                    } label: {
                        HStack {
                            Text("Test Connection")
                            Spacer()
                            if keySettings.isTesting {
                                ProgressView()
                            } else if let result = keySettings.testResult {
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
                    .disabled(!keySettings.canSubmitKey || keySettings.isTesting)

                    if keySettings.hasStoredKey {
                        Button("Remove API Key", role: .destructive) {
                            isFieldFocused = false
                            keySettings.remove()
                        }
                    }

                    Button {
                        showAPIKeyHelp = true
                    } label: {
                        Label("Why use your own key?", systemImage: "questionmark.circle")
                    }
                } header: {
                    Label("Your Own Rebrickable Key", systemImage: "key.fill")
                } footer: {
                    if let message = keySettings.removalError {
                        Text(message)
                            .foregroundStyle(.red)
                    } else if case .failure(let message) = keySettings.testResult {
                        Text(message)
                            .foregroundStyle(.red)
                    } else {
                        Text("Optional. BrickSweep works without a key, using its own daily copy of Rebrickable's data. With a tested key of your own, sets download straight from Rebrickable instead, so sets added there today appear straight away.")
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
                    Link(destination: URL(string: "https://rebrickable.com/api/")!) {
                        Label("Get a free Rebrickable API key", systemImage: "globe")
                    }
                    Link(destination: URL(string: "https://rebrickable.com/api/v3/docs/")!) {
                        Label("Rebrickable Documentation", systemImage: "book")
                    }
                } header: {
                    Text("Resources")
                } footer: {
                    Text("Set data comes from Rebrickable's free community database of 1M+ LEGO sets and parts. Not affiliated with or endorsed by Rebrickable.")
                }

                Section("Support") {
                    Button {
                        sendFeedback()
                    } label: {
                        Label("Send Feedback", systemImage: "envelope")
                    }
                }

                Section {
                    Label("Without an API key, BrickSweep downloads set lists from data.bricksweep.app, which receives the set number and standard request details such as your IP address. If you add a key, it's stored in your device's Keychain and only sent to rebrickable.com. Your collection and progress stay on your device.", systemImage: "lock.shield")
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
            .sheet(isPresented: $showPaywall) {
                PaywallView(context: .proFeature)
            }
            .sheet(isPresented: $showAPIKeyHelp) {
                APIKeyHelpView()
            }
            .alert("API Key Saved", isPresented: $keySettings.showSavedConfirmation) {
                Button("OK", role: .cancel) {}
            }
            .alert("Email Unavailable", isPresented: $showFeedbackFallback) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("Please email \(AppConstants.Support.feedbackEmail) with your feedback.")
            }
            .onAppear {
                keySettings.load()
            }
        }
        .tint(.blue)
    }

    private func sendFeedback() {
        guard let url = feedbackURL else {
            showFeedbackFallback = true
            return
        }

        openURL(url) { accepted in
            if !accepted {
                showFeedbackFallback = true
            }
        }
    }

    private var feedbackURL: URL? {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "Unknown"
        let body = """


        ---
        App version: \(version) (\(build))
        Device: \(UIDevice.current.model)
        iOS: \(UIDevice.current.systemVersion)
        """

        var components = URLComponents()
        components.scheme = "mailto"
        components.path = AppConstants.Support.feedbackEmail
        components.queryItems = [
            URLQueryItem(name: "subject", value: "BrickSweep Feedback"),
            URLQueryItem(name: "body", value: body),
        ]
        return components.url
    }
}

enum APIKeyProvider {
    static func getAPIKey() -> String? {
        KeychainHelper.read(key: AppConstants.Keychain.apiKey)
    }

    /// True when the user has saved their own key and it passed Test Connection.
    static func hasVerifiedAPIKey() -> Bool {
        getAPIKey() != nil && UserDefaults.standard.bool(forKey: AppConstants.UserDefaultsKeys.hasVerifiedAPIKey)
    }
}

enum SyncTokenProvider {
    static func getUserToken() -> String? {
        KeychainHelper.read(key: AppConstants.Keychain.userToken)
    }
}
