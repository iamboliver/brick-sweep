import SwiftUI

struct SetRowView: View {
    let legoSet: LegoSet

    private var missingCount: Int {
        legoSet.parts.filter { $0.missingQty > 0 }.count
    }

    private var completedCount: Int {
        legoSet.parts.count - missingCount
    }

    var body: some View {
        HStack(spacing: AppTheme.Spacing.md) {
            PartImage(url: legoSet.imageUrl, size: 72, fallbackIcon: "square.stack.3d.up")

            VStack(alignment: .leading, spacing: AppTheme.Spacing.xs) {
                Text(legoSet.name)
                    .font(AppTheme.Typography.headline)
                    .lineLimit(2)

                HStack(spacing: AppTheme.Spacing.sm) {
                    Text(legoSet.setNum)
                        .font(.caption2)
                        .fontWeight(.medium)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(.quaternary, in: Capsule())

                    Text(verbatim: "\(legoSet.year)")
                        .font(AppTheme.Typography.caption)
                        .foregroundStyle(.secondary)
                }

                if missingCount > 0 {
                    Text("\(missingCount) missing")
                        .font(.caption2)
                        .fontWeight(.semibold)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(AppTheme.legoRed, in: Capsule())
                } else {
                    Text("\(legoSet.numParts) parts")
                        .font(AppTheme.Typography.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            if !legoSet.parts.isEmpty {
                CompletionRing(
                    completed: completedCount,
                    total: legoSet.parts.count,
                    size: 36
                )
            }
        }
        .padding(.vertical, AppTheme.Spacing.xs)
    }
}
