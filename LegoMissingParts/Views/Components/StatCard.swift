import SwiftUI

struct StatCard: View {
    let icon: String
    let value: Int
    let label: String
    var iconColor: Color = .secondary

    var body: some View {
        VStack(spacing: AppTheme.Spacing.xs) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundStyle(iconColor)

            Text("\(value)")
                .font(AppTheme.Typography.statNumber)
                .contentTransition(.numericText())

            Text(label)
                .font(AppTheme.Typography.statLabel)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}
