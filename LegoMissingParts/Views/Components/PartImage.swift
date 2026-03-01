import SwiftUI

struct PartImage: View {
    let url: String?
    var size: CGFloat = 56
    var fallbackIcon: String = "puzzlepiece"

    var body: some View {
        Group {
            if let imageUrl = url, let resolved = URL(string: imageUrl) {
                AsyncImage(url: resolved) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                    case .failure:
                        fallbackView
                    case .empty:
                        shimmerView
                    @unknown default:
                        EmptyView()
                    }
                }
            } else {
                fallbackView
            }
        }
        .frame(width: size, height: size)
        .background(Color(.tertiarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.sm))
    }

    private var fallbackView: some View {
        Image(systemName: fallbackIcon)
            .font(.system(size: size * 0.35))
            .foregroundStyle(.secondary)
    }

    private var shimmerView: some View {
        RoundedRectangle(cornerRadius: AppTheme.Radius.sm)
            .fill(Color(.quaternarySystemFill))
            .phaseAnimator([false, true]) { content, phase in
                content.opacity(phase ? 0.4 : 0.8)
            } animation: { _ in
                .easeInOut(duration: 0.8)
            }
    }
}
