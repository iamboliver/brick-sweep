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

    @State private var rotating = false
    @State private var phraseIndex = Int.random(in: 0..<phrases.count)
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let timer = Timer.publish(every: 2.5, on: .main, in: .common).autoconnect()

    var body: some View {
        VStack(spacing: AppTheme.Spacing.lg) {
            if reduceMotion {
                ProgressView()
                    .controlSize(.large)
            } else {
                spinnerView
            }
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
        .accessibilityLabel("Loading set, please wait")
        .accessibilityAddTraits(.updatesFrequently)
        .onReceive(timer) { _ in
            guard !reduceMotion else { return }
            var next: Int
            repeat {
                next = Int.random(in: 0..<Self.phrases.count)
            } while next == phraseIndex
            phraseIndex = next
        }
    }

    private var spinnerView: some View {
        Circle()
            .trim(from: 0, to: 0.75)
            .stroke(AppTheme.legoYellow, style: StrokeStyle(lineWidth: 5, lineCap: .round))
            .frame(width: 44, height: 44)
            .rotationEffect(.degrees(rotating ? 360 : 0))
            .animation(.linear(duration: 0.9).repeatForever(autoreverses: false), value: rotating)
            .onAppear { rotating = true }
    }
}
