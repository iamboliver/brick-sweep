import SwiftUI

struct PartCardView: View {
    @Bindable var part: LegoPartInstance
    @Environment(\.colorScheme) private var colorScheme
    @State private var isPressed = false

    var body: some View {
        HStack(spacing: AppTheme.Spacing.md) {
            PartImage(url: part.imageUrl, size: 56)

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
            }

            Spacer()

            HStack(spacing: AppTheme.Spacing.sm) {
                Button {
                    withAnimation(AppTheme.Animation.spring) {
                        decrementMissing()
                    }
                } label: {
                    Image(systemName: "minus.circle.fill")
                        .font(.title3)
                        .foregroundStyle(part.missingQty > 0 ? AnyShapeStyle(AppTheme.legoRed) : AnyShapeStyle(.quaternary))
                }
                .buttonStyle(.plain)
                .disabled(part.missingQty <= 0)

                VStack(spacing: 0) {
                    Text("\(part.missingQty)")
                        .font(.system(.title3, design: .rounded, weight: .bold))
                        .foregroundStyle(part.missingQty > 0 ? AppTheme.legoRed : .secondary)
                        .contentTransition(.numericText())

                    Text("of \(part.requiredQty)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                .frame(minWidth: 36)

                Button {
                    withAnimation(AppTheme.Animation.spring) {
                        incrementMissing()
                    }
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.title3)
                        .foregroundStyle(part.missingQty < part.requiredQty ? AnyShapeStyle(AppTheme.legoYellow) : AnyShapeStyle(.quaternary))
                }
                .buttonStyle(.plain)
                .disabled(part.missingQty >= part.requiredQty)
            }
        }
        .padding(AppTheme.Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: AppTheme.Radius.md)
                .fill(part.missingQty > 0
                      ? (colorScheme == .dark ? AppTheme.missingBackgroundDark : AppTheme.missingBackground)
                      : Color(.secondarySystemBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.Radius.md)
                .stroke(part.missingQty > 0 ? AppTheme.missingBorder : Color.clear, lineWidth: 1)
        )
        .scaleEffect(isPressed ? 0.97 : 1.0)
        .contentShape(Rectangle())
        .onTapGesture {
            withAnimation(AppTheme.Animation.spring) {
                isPressed = true
                incrementMissing()
            }
            withAnimation(AppTheme.Animation.spring.delay(0.15)) {
                isPressed = false
            }
        }
        .sensoryFeedback(.impact, trigger: part.missingQty)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(part.name), \(part.colorName), \(part.missingQty) of \(part.requiredQty) missing")
        .accessibilityHint("Double-tap to increment")
        .accessibilityAction(named: "Increment") { incrementMissing() }
        .accessibilityAction(named: "Decrement") { decrementMissing() }
        .accessibilityAction(named: "Reset to zero") { part.missingQty = 0 }
        .contextMenu {
            Button("Decrement Missing", systemImage: "minus.circle") {
                decrementMissing()
            }
            .disabled(part.missingQty <= 0)

            Button("Reset to 0", systemImage: "arrow.counterclockwise") {
                part.missingQty = 0
            }
            .disabled(part.missingQty == 0)

            Button("Mark All Missing", systemImage: "xmark.circle") {
                part.missingQty = part.requiredQty
            }
            .disabled(part.missingQty == part.requiredQty)
        }
    }

    private func incrementMissing() {
        if part.missingQty >= part.requiredQty {
            part.missingQty = 0
        } else {
            part.missingQty += 1
        }
    }

    private func decrementMissing() {
        if part.missingQty > 0 {
            part.missingQty -= 1
        }
    }
}
