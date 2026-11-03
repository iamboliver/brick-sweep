import Foundation
import SwiftData

@Model
final class LegoPartInstance {
    var partNum: String
    var colorId: Int
    var colorName: String
    var colorRgb: String
    var name: String
    var imageUrl: String?
    var requiredQty: Int
    var missingQty: Int
    var replacedQty: Int
    var isSpare: Bool

    var elementId: String?
    var brickLinkPartNum: String?
    var brickLinkColorId: Int?

    var set: LegoSet?

    init(
        partNum: String,
        colorId: Int,
        colorName: String,
        colorRgb: String,
        name: String,
        imageUrl: String?,
        requiredQty: Int,
        missingQty: Int = 0,
        replacedQty: Int = 0,
        isSpare: Bool,
        elementId: String? = nil,
        brickLinkPartNum: String? = nil,
        brickLinkColorId: Int? = nil
    ) {
        self.partNum = partNum
        self.colorId = colorId
        self.colorName = colorName
        self.colorRgb = colorRgb
        self.name = name
        self.imageUrl = imageUrl
        self.requiredQty = requiredQty
        self.missingQty = missingQty
        self.replacedQty = replacedQty
        self.isSpare = isSpare
        self.elementId = elementId
        self.brickLinkPartNum = brickLinkPartNum
        self.brickLinkColorId = brickLinkColorId
    }
}

// MARK: - Missing and replaced counts

/// Every change to the counts keeps missing + replaced within the required quantity: a
/// piece is either found, missing, or missing and since replaced, never two of those.
extension LegoPartInstance {
    /// The most pieces that can be marked missing: the ones already replaced count
    /// towards the required quantity too.
    var maxMissingQty: Int { max(0, requiredQty - replacedQty) }

    /// One more missing. At the maximum it wraps back to none, so tapping a card cycles.
    /// A count already over the maximum (left by older versions) comes down to it
    /// instead, so a tap never discards those missing marks.
    func incrementMissing() {
        if missingQty > maxMissingQty {
            missingQty = maxMissingQty
        } else if missingQty == maxMissingQty {
            missingQty = 0
        } else {
            missingQty += 1
        }
    }

    func decrementMissing() {
        missingQty = max(0, missingQty - 1)
    }

    func markAllMissing() {
        missingQty = maxMissingQty
    }

    /// The missing pieces have been bought.
    func markMissingAsReplaced() {
        replacedQty = min(requiredQty, replacedQty + missingQty)
        missingQty = 0
    }

    /// The replacement is undone, so those pieces are missing again.
    func markReplacedAsMissing() {
        missingQty = min(requiredQty, missingQty + replacedQty)
        replacedQty = 0
    }

    /// Brings counts that break the rule back within it, for example after the required
    /// quantity drops on a re-download. Missing wins: it drives the shopping list and
    /// completion, while replaced is a record of pieces already bought.
    func capCounts() {
        missingQty = max(0, min(missingQty, requiredQty))
        replacedQty = max(0, min(replacedQty, requiredQty - missingQty))
    }
}
