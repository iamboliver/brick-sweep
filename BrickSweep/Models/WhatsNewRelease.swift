import Foundation

/// One version's What's New sheet. Add an entry for each release with something to
/// announce; a version without an entry never shows the sheet.
struct WhatsNewRelease: Identifiable {
    struct Feature: Identifiable {
        let symbol: String
        let title: String
        let detail: String

        var id: String { title }
    }

    struct Gift {
        let title: String
        let detail: String
    }

    /// The marketing version, e.g. "1.1".
    let version: String
    let note: String
    let signature: String
    let features: [Feature]
    /// Shown only to founding members (bs-btk.1).
    let foundingGift: Gift?

    var id: String { version }

    static func release(for version: String) -> WhatsNewRelease? {
        all.first { $0.version == version }
    }

    static let all: [WhatsNewRelease] = [
        WhatsNewRelease(
            version: "1.1",
            note: "Hi, I'm Oliver. I built BrickSweep for my autistic son, who loves building sets but often loses pieces. I wanted a quick way to see exactly what was missing and order replacements, without writing lists by hand. Thank you for using it so early. Several of the fixes below came straight from your reports.",
            signature: "Oliver",
            features: [
                Feature(
                    symbol: "bolt.fill",
                    title: "No API key needed",
                    detail: "Add a set straight away. BrickSweep now looks sets up in its own daily copy of Rebrickable's data. Your own key is still optional in Settings."
                ),
                Feature(
                    symbol: "square.grid.2x2.fill",
                    title: "Sets by theme",
                    detail: "Switch to Themes on the Sets tab to see your collection grouped by theme, like City or Star Wars."
                ),
                Feature(
                    symbol: "wrench.and.screwdriver.fill",
                    title: "Fixes you reported",
                    detail: "Adding a set twice no longer doubles its parts, completion figures agree everywhere, and set numbers open the number keyboard."
                ),
            ],
            foundingGift: Gift(
                title: "Pro is yours, free",
                detail: "You installed BrickSweep early, so Pro is now unlocked for good: unlimited sets and BrickLink export. There's nothing to buy, and it stays with your Apple ID if you reinstall or change phones."
            )
        ),
    ]
}
