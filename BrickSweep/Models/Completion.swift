import Foundation

/// Shared completion math so every screen renders the same clamped
/// percentage regardless of which counts (quantities or unique part types)
/// it uses as the numerator/denominator.
enum Completion {
    static func fraction(completed: Int, total: Int) -> Double {
        guard total > 0 else { return 1.0 }
        return min(1.0, max(0.0, Double(completed) / Double(total)))
    }
}
