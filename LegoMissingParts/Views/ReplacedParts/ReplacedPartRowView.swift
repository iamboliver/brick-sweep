import SwiftUI

struct ReplacedPartRowView: View {
    let part: GlobalReplacedPart

    var body: some View {
        HStack(spacing: AppTheme.Spacing.md) {
            PartImage(url: part.imageUrl, size: 48)

            VStack(alignment: .leading, spacing: AppTheme.Spacing.xs) {
                Text(part.name)
                    .font(AppTheme.Typography.subheadline)
                    .lineLimit(2)

                HStack(spacing: AppTheme.Spacing.sm) {
                    if let elementId = part.elementId {
                        Text(elementId)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    } else {
                        Text(part.partNum)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }

                    ColorBadge(colorName: part.colorName, colorRgb: part.colorRgb)
                }

                HStack(spacing: AppTheme.Spacing.xs) {
                    ForEach(part.contributingSets, id: \.self) { setNum in
                        Text(setNum)
                            .font(.caption2)
                            .fontWeight(.medium)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(.quaternary, in: Capsule())
                    }
                }
            }

            Spacer()

            Text("\(part.totalReplacedQty)")
                .font(.system(.callout, design: .rounded, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 32, height: 32)
                .background(AppTheme.completedGreen, in: Circle())
        }
        .padding(.vertical, AppTheme.Spacing.xs)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(part.name), \(part.colorName), \(part.totalReplacedQty) replaced across \(part.contributingSets.joined(separator: ", "))")
        .accessibilityHint("Swipe left to undo replacement")
    }
}
