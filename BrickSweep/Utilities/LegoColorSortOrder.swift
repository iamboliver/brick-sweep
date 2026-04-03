import Foundation

enum PartSortOption: String, CaseIterable {
    case color = "Colour"
    case partNumber = "Part Number"
}

/// Sort order for Rebrickable color IDs matching the LEGO instruction manual
/// bill-of-materials layout: whites → grays → black → reds → oranges →
/// yellows → greens → blues → purples → pinks → tans → browns →
/// transparent → metallic.
enum LegoColorSortOrder {
    /// Maps Rebrickable color ID → sort position.
    /// Colors not in this table sort to the end by color name.
    static let order: [Int: Int] = [
        // Whites / Grays / Black
        15: 0,      // White
        159: 1,     // Glow in Dark White
        151: 2,     // Very Light Bluish Gray
        71: 3,      // Light Bluish Gray
        72: 4,      // Dark Bluish Gray
        0: 5,       // Black

        // Reds
        59: 10,     // Dark Red
        4: 11,      // Red
        330: 12,    // Coral
        25: 13,     // Salmon

        // Oranges
        484: 20,    // Dark Orange
        462: 21,    // Medium Orange
        106: 22,    // Orange (alt)
        179: 22,    // Orange (alt 2)
        110: 23,    // Bright Light Orange
        191: 23,    // Bright Light Orange (alt)

        // Yellows
        14: 30,     // Yellow
        226: 31,    // Bright Light Yellow

        // Greens
        34: 40,     // Lime
        27: 41,     // Lime (alt)
        115: 42,    // Medium Lime
        10: 43,     // Bright Green
        326: 43,    // Bright Green (alt)
        6: 44,      // Green
        2: 44,      // Green (alt)
        288: 45,    // Dark Green
        155: 46,    // Olive Green
        378: 47,    // Sand Green

        // Teals / Aquas
        3: 50,      // Dark Turquoise
        11: 51,     // Light Turquoise
        152: 52,    // Light Aqua
        323: 52,    // Light Aqua (alt)

        // Blues
        156: 60,    // Medium Azure
        322: 60,    // Medium Azure (alt)
        153: 61,    // Dark Azure
        321: 61,    // Dark Azure (alt)
        212: 62,    // Bright Light Blue
        73: 63,     // Medium Blue
        1: 64,      // Blue
        379: 65,    // Sand Blue
        63: 66,     // Dark Blue
        272: 66,    // Dark Blue (alt)

        // Purples
        69: 70,     // Dark Purple
        157: 71,    // Medium Lavender
        154: 72,    // Lavender

        // Pinks
        29: 80,     // Bright Pink
        13: 81,     // Pink
        5: 82,      // Dark Pink
        26: 83,     // Magenta

        // Tans / Nougats / Browns
        19: 90,     // Tan
        28: 91,     // Dark Tan
        78: 92,     // Light Nougat
        283: 93,    // Light Nougat (alt)
        84: 94,     // Medium Nougat
        150: 95,    // Medium Dark Flesh
        70: 96,     // Reddish Brown
        308: 97,    // Dark Brown

        // Transparent
        47: 110,    // Trans-Clear
        36: 111,    // Trans-Red
        182: 112,   // Trans-Orange
        164: 113,   // Trans-Light Orange
        46: 114,    // Trans-Yellow
        43: 115,    // Trans-Bright Green
        42: 116,    // Trans-Green
        41: 117,    // Trans-Dark Blue
        74: 118,    // Trans-Medium Blue
        9: 119,     // Trans-Light Blue
        44: 120,    // Trans-Light Purple
        51: 121,    // Trans-Purple
        40: 122,    // Trans-Black / Smoke

        // Metallic / Special
        95: 130,    // Flat Silver
        77: 131,    // Pearl Dark Gray
        297: 132,   // Pearl Gold
        176: 133,   // Metallic Gold
        315: 134,   // Metallic Silver
    ]

    /// Sentinel color ID used for minifigures (not a real Rebrickable color).
    static let minifigColorId = -1

    static func sortPosition(for colorId: Int) -> Int {
        if colorId == minifigColorId { return 1000 }
        return order[colorId] ?? 999
    }
}
