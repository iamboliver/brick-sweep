import StoreKit
import SwiftUI

enum PaywallContext {
    case setLimit
    case export
    case proFeature
}

struct PaywallView: View {
    let context: PaywallContext
    @Environment(StoreManager.self) private var storeManager
    @Environment(\.dismiss) private var dismiss
    /// Set once this paywall has tried the founder check, so a failed check (offline,
    /// or a StoreKit error) shows the paywall instead of a spinner that never ends.
    @State private var hasTriedFoundingCheck = false

    var body: some View {
        NavigationStack {
            Group {
                if !storeManager.hasCheckedFoundingStatus && !hasTriedFoundingCheck {
                    ProgressView("Checking Pro access…")
                } else {
                    purchaseContent
                }
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(dismissLabel) { dismiss() }
                        .foregroundStyle(.secondary)
                }
            }
        }
        .task {
            if !storeManager.hasCheckedFoundingStatus {
                await storeManager.refreshPurchaseStatus()
            }
            hasTriedFoundingCheck = true
        }
        .onChange(of: storeManager.isPro, initial: true) { _, isPro in
            if isPro { dismiss() }
        }
        .presentationDetents(context == .setLimit ? [.large] : [.medium, .large])
        .presentationDragIndicator(.visible)
    }

    private var purchaseContent: some View {
        ScrollView {
                VStack(spacing: AppTheme.Spacing.xl) {

                    // MARK: Header
                    VStack(spacing: AppTheme.Spacing.sm) {
                        Image(systemName: "crown.fill")
                            .font(.system(size: 48))
                            .foregroundStyle(AppTheme.legoYellow)

                        Text("BrickSweep Pro")
                            .font(AppTheme.Typography.title)

                        Text(subtitle)
                            .font(AppTheme.Typography.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, AppTheme.Spacing.xl)
                    }
                    .padding(.top, AppTheme.Spacing.xl)

                    if !storeManager.hasCheckedFoundingStatus {
                        Text("Installed BrickSweep before version 1.1? Your free founding-member Pro unlocks once BrickSweep can reach the App Store. Check your connection, then tap Restore Purchases.")
                            .font(AppTheme.Typography.caption)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, AppTheme.Spacing.xl)
                    }

                    // MARK: Feature list
                    VStack(alignment: .leading, spacing: AppTheme.Spacing.lg) {
                        PaywallFeatureRow(
                            icon: "square.stack.3d.up.fill",
                            iconColor: AppTheme.legoYellow,
                            title: "Unlimited Sets",
                            description: "Track as many sets as you own, no limits."
                        )
                        PaywallFeatureRow(
                            icon: "square.and.arrow.up",
                            iconColor: .blue,
                            title: "Export to BrickLink",
                            description: "Export missing parts as BrickLink XML or CSV to order with ease."
                        )
                        PaywallFeatureRow(
                            icon: "heart.fill",
                            iconColor: .red,
                            title: "Support a Fellow AFOL",
                            description: "One-time purchase funds continued development — no subscription, ever."
                        )
                    }
                    .padding(.horizontal, AppTheme.Spacing.xl)

                    // MARK: Price line
                    Text(priceLine)
                        .font(AppTheme.Typography.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, AppTheme.Spacing.xl)

                    if case .failed(let message) = storeManager.productFetchState {
                        Text(message)
                            .font(AppTheme.Typography.caption)
                            .foregroundStyle(.red)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, AppTheme.Spacing.xl)
                    }

                    // MARK: Error
                    if let error = storeManager.purchaseError {
                        Text(error)
                            .font(AppTheme.Typography.caption)
                            .foregroundStyle(.red)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, AppTheme.Spacing.xl)
                    }

                    if let message = storeManager.purchaseMessage {
                        Text(message)
                            .font(AppTheme.Typography.caption)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, AppTheme.Spacing.xl)
                    }

                    // MARK: Buttons
                    VStack(spacing: AppTheme.Spacing.md) {
                        Button {
                            Task {
                                let purchased = await storeManager.purchase()
                                if purchased { dismiss() }
                            }
                        } label: {
                            Group {
                                if storeManager.isLoading {
                                    ProgressView()
                                        .tint(Color(.label))
                                } else {
                                    Text(buyButtonLabel)
                                        .fontWeight(.semibold)
                                }
                            }
                            .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(AppTheme.legoYellow)
                        .foregroundStyle(Color(.label))
                        .controlSize(.large)
                        .disabled(storeManager.isLoading || storeManager.productFetchState == .loading)

                        if case .failed = storeManager.productFetchState {
                            Button("Try Again") {
                                Task { await storeManager.retryProductFetch() }
                            }
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .disabled(storeManager.isLoading)
                        }

                        Button {
                            Task {
                                await storeManager.restorePurchases()
                                if storeManager.isPro { dismiss() }
                            }
                        } label: {
                            Text("Restore Purchases")
                        }
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .disabled(storeManager.isLoading)
                    }
                    .padding(.horizontal, AppTheme.Spacing.xl)

                    // MARK: Legal
                    Text("Payment charged to your Apple ID. This is a one-time purchase.")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, AppTheme.Spacing.xl)
                        .padding(.bottom, AppTheme.Spacing.xl)
                }
            }
    }

    // MARK: - Context-specific copy

    private var subtitle: String {
        switch context {
        case .setLimit: "Track your whole LEGO universe with BrickSweep Pro."
        case .export: "Export missing parts to BrickLink with BrickSweep Pro."
        case .proFeature: "You're using BrickSweep like a true LEGO collector."
        }
    }

    private var dismissLabel: String {
        switch context {
        case .setLimit: "Keep \(AppConstants.IAP.freeTierSetLimit)-set limit"
        case .export: "Not now"
        case .proFeature: "Not now"
        }
    }

    private var buyButtonLabel: String {
        if storeManager.productFetchState == .loading {
            return "Loading purchase options…"
        }
        if let product = storeManager.proProduct {
            return "Unlock BrickSweep Pro — \(product.displayPrice)"
        }
        return "Unlock BrickSweep Pro (Try Again)"
    }

    private var priceLine: String {
        if let product = storeManager.proProduct {
            return "One-time purchase · \(product.displayPrice) · No subscription, ever."
        }
        return "One-time purchase · No subscription, ever."
    }
}

// MARK: - Feature row

private struct PaywallFeatureRow: View {
    let icon: String
    let iconColor: Color
    let title: String
    let description: String

    var body: some View {
        HStack(alignment: .top, spacing: AppTheme.Spacing.lg) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(iconColor)
                .frame(width: 32)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: AppTheme.Spacing.xs) {
                Text(title)
                    .font(AppTheme.Typography.headline)
                Text(description)
                    .font(AppTheme.Typography.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .accessibilityElement(children: .combine)
    }
}
