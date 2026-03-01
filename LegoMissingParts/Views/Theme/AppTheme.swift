import SwiftUI

enum AppTheme {

    // MARK: - Colors

    static let legoYellow = Color(red: 1.0, green: 0.804, blue: 0.0)        // #FFCD00
    static let legoRed = Color(red: 0.851, green: 0.118, blue: 0.090)       // #D91E17
    static let completedGreen = Color.green

    static let missingBackground = Color.red.opacity(0.08)
    static let missingBackgroundDark = Color.red.opacity(0.15)
    static let missingBorder = Color.red.opacity(0.3)

    // MARK: - Spacing (4-point grid)

    enum Spacing {
        static let xs: CGFloat = 4
        static let sm: CGFloat = 8
        static let md: CGFloat = 12
        static let lg: CGFloat = 16
        static let xl: CGFloat = 24
    }

    // MARK: - Corner Radius

    enum Radius {
        static let sm: CGFloat = 6
        static let md: CGFloat = 10
        static let lg: CGFloat = 14
        static let xl: CGFloat = 20
    }

    // MARK: - Typography

    enum Typography {
        static let title = Font.system(.title, design: .rounded).weight(.bold)
        static let headline = Font.system(.headline, design: .rounded).weight(.semibold)
        static let subheadline = Font.subheadline.weight(.medium)
        static let caption = Font.caption
        static let statNumber = Font.system(.title, design: .rounded).weight(.bold)
        static let statLabel = Font.system(.caption2, design: .rounded).weight(.medium)
    }

    // MARK: - Animations

    enum Animation {
        static let snappy = SwiftUI.Animation.snappy(duration: 0.3)
        static let spring = SwiftUI.Animation.spring(duration: 0.35, bounce: 0.3)
        static let easeInOut = SwiftUI.Animation.easeInOut(duration: 0.25)
    }
}

// MARK: - Shadow View Modifiers

struct CardShadow: ViewModifier {
    func body(content: Content) -> some View {
        content
            .shadow(color: .black.opacity(0.06), radius: 4, x: 0, y: 2)
    }
}

struct ElevatedShadow: ViewModifier {
    func body(content: Content) -> some View {
        content
            .shadow(color: .black.opacity(0.12), radius: 8, x: 0, y: 4)
    }
}

extension View {
    func cardShadow() -> some View {
        modifier(CardShadow())
    }

    func elevatedShadow() -> some View {
        modifier(ElevatedShadow())
    }
}
