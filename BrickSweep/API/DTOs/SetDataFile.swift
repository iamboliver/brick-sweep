import Foundation

/// One set's inventory from BrickSweep's daily data files, built from Rebrickable's
/// public downloads (the bricksweep-data repo; its SCHEMA.md describes the format).
/// Decoded with `.convertFromSnakeCase`.
struct SetDataFile: Decodable, Sendable {
    static let supportedSchemaVersion = 1

    let schemaVersion: Int
    let set: SetInfo
    /// Every inventory row, not merged: includes spares and each minifigure's own
    /// parts (already multiplied by how many of that minifigure the set has).
    let parts: [Part]
    let minifigs: [Minifig]

    struct SetInfo: Decodable, Sendable {
        let setNum: String
        let name: String
        let year: Int
        let themeId: Int?
        /// The top-level theme ("City" for a City Police set).
        let themeName: String?
        let numParts: Int
        let imgUrl: String?
    }

    struct Part: Decodable, Sendable {
        let partNum: String
        let name: String
        let colorId: Int
        let colorName: String
        let rgb: String
        let quantity: Int
        let isSpare: Bool
        let imgUrl: String?
        let elementId: String?
        let bricklinkPartNum: String?
    }

    struct Minifig: Decodable, Sendable {
        let figNum: String
        let name: String
        let quantity: Int
        let imgUrl: String?
    }
}
