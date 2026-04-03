import SwiftUI

struct CompletionRing: View {
    let completed: Int
    let total: Int
    var size: CGFloat = 36

    private var fraction: Double {
        guard total > 0 else { return 1.0 }
        return Double(completed) / Double(total)
    }

    private var ringColor: Color {
        if fraction >= 1.0 { return AppTheme.completedGreen }
        if fraction >= 0.8 { return AppTheme.legoYellow }
        return AppTheme.legoRed
    }

    var body: some View {
        ZStack {
            Circle()
                .stroke(ringColor.opacity(0.2), lineWidth: size * 0.1)

            Circle()
                .trim(from: 0, to: fraction)
                .stroke(ringColor, style: StrokeStyle(lineWidth: size * 0.1, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(AppTheme.Animation.spring, value: fraction)

            Text("\(Int(fraction * 100))%")
                .font(.system(size: size * 0.24, weight: .bold, design: .rounded))
                .foregroundStyle(ringColor)
        }
        .frame(width: size, height: size)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(Int(fraction * 100)) percent complete, \(completed) of \(total)")
    }
}
