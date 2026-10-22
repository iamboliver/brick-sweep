import SwiftUI

struct ThemeGroupRowView: View {
    let group: ThemeGroup

    var body: some View {
        HStack(spacing: AppTheme.Spacing.lg) {
            VStack(alignment: .leading, spacing: AppTheme.Spacing.xs) {
                Text(group.name)
                    .font(AppTheme.Typography.headline)
                    .lineLimit(1)

                Text("\(group.setCount) \(group.setCount == 1 ? "set" : "sets") · \(group.totalPartCount) parts")
                    .font(AppTheme.Typography.caption)
                    .foregroundStyle(.secondary)

                if group.missingTypeCount > 0 {
                    Text("\(group.missingTypeCount) missing")
                        .font(.caption2)
                        .fontWeight(.semibold)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(AppTheme.legoRed, in: Capsule())
                }
            }

            Spacer()

            if group.trackedTypeCount > 0 {
                CompletionRing(
                    completed: group.completedTypeCount,
                    total: group.trackedTypeCount,
                    size: 36
                )
            }
        }
        .padding(.vertical, AppTheme.Spacing.xs)
        .accessibilityElement(children: .combine)
    }
}
