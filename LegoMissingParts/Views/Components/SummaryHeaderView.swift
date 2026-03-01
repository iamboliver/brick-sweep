import SwiftUI

struct SummaryHeaderView: View {
    let stats: [StatCard]

    var body: some View {
        HStack(spacing: 0) {
            ForEach(Array(stats.enumerated()), id: \.offset) { index, stat in
                if index > 0 {
                    Divider()
                        .frame(height: 32)
                }
                stat
            }
        }
        .padding(.vertical, AppTheme.Spacing.md)
        .padding(.horizontal, AppTheme.Spacing.sm)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: AppTheme.Radius.lg))
        .cardShadow()
    }
}
