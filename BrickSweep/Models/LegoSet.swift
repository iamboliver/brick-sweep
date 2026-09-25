import Foundation
import SwiftData

@Model
final class LegoSet {
    @Attribute(.unique) var setNum: String
    var name: String
    var year: Int
    var numParts: Int
    var imageUrl: String?
    var dateAdded: Date
    var isImporting: Bool = false
    var importFailed: Bool = false

    @Relationship(deleteRule: .cascade, inverse: \LegoPartInstance.set)
    var parts: [LegoPartInstance] = []

    init(
        setNum: String,
        name: String,
        year: Int,
        numParts: Int,
        imageUrl: String?,
        dateAdded: Date = .now,
        isImporting: Bool = false,
        importFailed: Bool = false
    ) {
        self.setNum = setNum
        self.name = name
        self.year = year
        self.numParts = numParts
        self.imageUrl = imageUrl
        self.dateAdded = dateAdded
        self.isImporting = isImporting
        self.importFailed = importFailed
    }

    /// Sum of required quantities across imported parts. This is the
    /// authoritative denominator for quantity-based completion — it can
    /// differ from `numParts` (API set metadata) once parts are actually
    /// imported, so it must not be mixed with `numParts` in a single ratio.
    var totalRequiredQty: Int {
        parts.reduce(0) { $0 + $1.requiredQty }
    }

    var totalMissingQty: Int {
        parts.reduce(0) { $0 + $1.missingQty }
    }

    var accountedQty: Int {
        totalRequiredQty - totalMissingQty
    }

    var completionFraction: Double {
        Completion.fraction(completed: accountedQty, total: totalRequiredQty)
    }
}
