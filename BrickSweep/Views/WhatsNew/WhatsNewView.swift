import SwiftUI

/// The one-time sheet after an update: a note from Oliver, what's new, and for
/// founding members, their free Pro.
struct WhatsNewView: View {
    let release: WhatsNewRelease
    let isFoundingUser: Bool
    /// Opens Settings, where Send Feedback lives.
    let onSendFeedback: () -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: AppTheme.Spacing.xl) {
                    note

                    if isFoundingUser, let gift = release.foundingGift {
                        giftCard(gift)
                    }

                    VStack(alignment: .leading, spacing: AppTheme.Spacing.lg) {
                        ForEach(release.features) { feature in
                            featureRow(feature)
                        }
                    }

                    feedback
                }
                .padding(.horizontal, AppTheme.Spacing.xl)
                .padding(.vertical, AppTheme.Spacing.lg)
            }
            .navigationTitle("What's New in \(release.version)")
            .navigationBarTitleDisplayMode(.inline)
            .safeAreaInset(edge: .bottom) {
                Button {
                    dismiss()
                } label: {
                    Text("Continue")
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(AppTheme.legoYellow)
                // The yellow is light in both modes, so the label stays black.
                .foregroundStyle(.black)
                .controlSize(.large)
                .padding(.horizontal, AppTheme.Spacing.xl)
                .padding(.vertical, AppTheme.Spacing.md)
                .background(.bar)
            }
        }
    }

    private var note: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
            Text(release.note)
            Text("– \(release.signature)")
                .foregroundStyle(.secondary)
        }
        .accessibilityElement(children: .combine)
    }

    private func giftCard(_ gift: WhatsNewRelease.Gift) -> some View {
        HStack(alignment: .top, spacing: AppTheme.Spacing.md) {
            Image(systemName: "gift.fill")
                .font(.title2)
                .foregroundStyle(AppTheme.legoYellow)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: AppTheme.Spacing.xs) {
                Text(gift.title)
                    .font(AppTheme.Typography.headline)
                Text(gift.detail)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(AppTheme.Spacing.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppTheme.legoYellow.opacity(0.15), in: RoundedRectangle(cornerRadius: AppTheme.Radius.lg))
        .accessibilityElement(children: .combine)
    }

    private func featureRow(_ feature: WhatsNewRelease.Feature) -> some View {
        HStack(alignment: .top, spacing: AppTheme.Spacing.md) {
            Image(systemName: feature.symbol)
                .font(.title3)
                .foregroundStyle(AppTheme.legoYellow)
                .frame(width: 32)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: AppTheme.Spacing.xs) {
                Text(feature.title)
                    .font(AppTheme.Typography.headline)
                Text(feature.detail)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .accessibilityElement(children: .combine)
    }

    private var feedback: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
            Text("Ideas or problems? I read every message.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Button {
                dismiss()
                onSendFeedback()
            } label: {
                Label("Send Feedback in Settings", systemImage: "envelope")
            }
        }
    }
}
