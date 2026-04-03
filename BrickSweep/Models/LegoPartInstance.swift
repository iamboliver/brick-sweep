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
