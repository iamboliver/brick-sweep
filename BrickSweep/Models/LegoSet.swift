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

    @Relationship(deleteRule: .cascade, inverse: \LegoPartInstance.set)
    var parts: [LegoPartInstance] = []

    init(
        setNum: String,
        name: String,
        year: Int,
        numParts: Int,
        imageUrl: String?,
        dateAdded: Date = .now,
        isImporting: Bool = false
    ) {
        self.setNum = setNum
        self.name = name
        self.year = year
        self.numParts = numParts
        self.imageUrl = imageUrl
        self.dateAdded = dateAdded
        self.isImporting = isImporting
    }
}
