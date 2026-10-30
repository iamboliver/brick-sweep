import Foundation

/// Shared completion math so every screen renders the same clamped
/// percentage. Callers pass piece quantities (required vs accounted for),
/// never unique part-type counts.
enum Completion {
    static func fraction(completed: Int, total: Int) -> Double {
        guard total > 0 else { return 1.0 }
        return min(1.0, max(0.0, Double(completed) / Double(total)))
    }

    /// Whole-number percentage, rounded down using integer math so that any
    /// missing piece displays below 100% and exact values are never shaved by
    /// floating-point error (e.g. 29 of 100 shows 29%, not 28%).
    static func percent(completed: Int, total: Int) -> Int {
        guard total > 0 else { return 100 }
        let clamped = min(total, max(0, completed))
        return clamped * 100 / total
    }
}
