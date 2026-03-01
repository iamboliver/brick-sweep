import SwiftUI

struct ColorBadge: View {
    let colorName: String
    let colorRgb: String

    var body: some View {
        HStack(spacing: AppTheme.Spacing.xs) {
            Circle()
                .fill(color)
                .frame(width: 12, height: 12)
                .overlay(Circle().stroke(.secondary.opacity(0.3), lineWidth: 0.5))
                .shadow(color: color.opacity(0.3), radius: 1, x: 0, y: 1)

            Text(colorName)
                .font(AppTheme.Typography.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var color: Color {
        Color(hex: colorRgb)
    }
}

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        let scanner = Scanner(string: hex)
        var rgbValue: UInt64 = 0
        scanner.scanHexInt64(&rgbValue)

        let r = Double((rgbValue & 0xFF0000) >> 16) / 255.0
        let g = Double((rgbValue & 0x00FF00) >> 8) / 255.0
        let b = Double(rgbValue & 0x0000FF) / 255.0

        self.init(red: r, green: g, blue: b)
    }
}
