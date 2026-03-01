import SwiftUI

struct SetLoadingOverlay: View {
    private static let phrases = [
        "Sorting through the bricks...",
        "Checking under the sofa cushions...",
        "Consulting the instruction manual...",
        "Stepping on a stray piece...",
        "Locating all 7,541 pieces...",
        "Asking the minifigs for help...",
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
        // 2×4 LEGO brick shape
        VStack(spacing: 0) {
            // Studs row
            HStack(spacing: 6) {
                ForEach(0..<4) { _ in
                    Circle()
                        .fill(AppTheme.legoYellow.shadow(.inner(radius: 1)))
                        .frame(width: 10, height: 10)
                }
            }
            .offset(y: 3)
            .zIndex(1)

            // Brick body
            RoundedRectangle(cornerRadius: 4)
                .fill(AppTheme.legoYellow)
                .frame(width: 60, height: 28)
        }
        .offset(y: bouncing ? -6 : 0)
        .animation(
            .spring(duration: 0.5, bounce: 0.6).repeatForever(autoreverses: true),
            value: bouncing
        )
        .onAppear { bouncing = true }
    }
}
