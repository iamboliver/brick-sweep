import SwiftUI

struct SetLoadingOverlay: View {
    private static let phrases = [
        "Sorting through the bricks...",
        "Checking under the sofa cushions...",
        "Consulting the instruction manual...",
        "Stepping on a stray piece...",
        "Locating all 7,541 pieces...",
        "Asking the figures for help...",
        "Organising by colour (obviously)...",
        "Following the instructions for once...",
        "Searching the carpet on hands and knees...",
        "Nearly there, just one more bag...",
    ]

    @State private var bouncing = false
    @State private var phraseIndex = Int.random(in: 0..<phrases.count)

    private let timer = Timer.publish(every: 2.5, on: .main, in: .common).autoconnect()

    var body: some View {
        VStack(spacing: AppTheme.Spacing.lg) {
            brickView
            Text(Self.phrases[phraseIndex])
                .font(AppTheme.Typography.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .contentTransition(.numericText())
                .animation(.easeInOut(duration: 0.4), value: phraseIndex)
        }
        .padding(AppTheme.Spacing.xl)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: AppTheme.Radius.lg))
        .elevatedShadow()
        .onReceive(timer) { _ in
            var next: Int
            repeat {
                next = Int.random(in: 0..<Self.phrases.count)
            } while next == phraseIndex
            phraseIndex = next
        }
    }

    private var brickView: some View {
        let yellow = AppTheme.legoYellow
        let studSize: CGFloat = 14

        return VStack(spacing: 0) {
            // Studs row
            HStack(spacing: 5) {
                ForEach(0..<4, id: \.self) { _ in
                    studView(color: yellow, size: studSize)
                }
            }
            .offset(y: studSize * 0.42)
            .zIndex(1)

            // Brick body
            RoundedRectangle(cornerRadius: 5)
                .fill(
                    LinearGradient(
                        colors: [
                            yellow.mix(with: .white, by: 0.06),
                            yellow,
                            yellow.mix(with: .black, by: 0.14)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(width: 70, height: 32)
                .overlay(alignment: .bottom) {
                    // Bottom face — gives the brick a 3D block feel
                    UnevenRoundedRectangle(cornerRadii: .init(bottomLeading: 5, bottomTrailing: 5))
                        .fill(yellow.mix(with: .black, by: 0.22))
                        .frame(height: 6)
                }
        }
        .offset(y: bouncing ? -8 : 0)
        .animation(
            .spring(duration: 0.5, bounce: 0.6).repeatForever(autoreverses: true),
            value: bouncing
        )
        .onAppear { bouncing = true }
    }

    private func studView(color: Color, size: CGFloat) -> some View {
        ZStack {
            // Cylinder side shadow — a squashed ellipse sitting below the stud
            Ellipse()
                .fill(color.mix(with: .black, by: 0.28))
                .frame(width: size, height: size * 0.38)
                .offset(y: size * 0.52)

            // Stud top face
            Circle()
                .fill(color)
                .frame(width: size, height: size)

            // Rim — thin dark ring for definition
            Circle()
                .strokeBorder(color.mix(with: .black, by: 0.2), lineWidth: 1)
                .frame(width: size, height: size)

            // Specular highlight — small soft circle offset upper-left
            Circle()
                .fill(
                    RadialGradient(
                        colors: [.white.opacity(0.55), .clear],
                        center: UnitPoint(x: 0.28, y: 0.28),
                        startRadius: 0,
                        endRadius: size * 0.45
                    )
                )
                .frame(width: size, height: size)
        }
        // Frame taller than the stud so the shadow ellipse isn't clipped
        .frame(width: size, height: size + size * 0.52)
    }
}
