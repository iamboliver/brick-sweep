import XCTest

/// bs-8ll: adding a set while the Themes view is showing must update that theme's row
/// and the list it opens, not only the All view.
@MainActor
final class ThemeGroupUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUp() async throws {
        continueAfterFailure = false
        app = XCUIApplication()
        // An empty in-memory collection, with sets from the app's offline test files.
        app.launchEnvironment["BRICKSWEEP_UI_TEST"] = "1"
        // Use the data files even if the simulator has a key saved, and keep What's New closed.
        app.launchArguments += ["-hasVerifiedAPIKey", "NO", "-whatsNewLastSeenVersion", "1.1"]
        app.launch()
    }

    func testAddingASetUpdatesItsThemeRowAndList() {
        addSet("75001")
        XCTAssertTrue(element(labelled: "Test Set 75001-1").waitForExistence(timeout: 10))
        addSet("60001")
        XCTAssertTrue(element(labelled: "Test Set 60001-1").waitForExistence(timeout: 10))
        app.buttons["Themes"].tap()

        let starWars = themeRow("Star Wars")
        XCTAssertTrue(starWars.waitForExistence(timeout: 10))
        XCTAssertTrue(starWars.label.contains("1 set"), "Unexpected row: \(starWars.label)")

        // The bug: added while Themes is showing, the row kept "1 set" and its old list.
        addSet("75002")
        let updated = NSPredicate(format: "label CONTAINS %@", "2 sets")
        let rowUpdated = expectation(for: updated, evaluatedWith: starWars)
        wait(for: [rowUpdated], timeout: 10)
        XCTAssertTrue(themeRow("City").label.contains("1 set"), "City should be unchanged")

        starWars.tap()
        XCTAssertTrue(element(labelled: "Test Set 75001-1").waitForExistence(timeout: 5))
        XCTAssertTrue(element(labelled: "Test Set 75002-1").waitForExistence(timeout: 5))
        XCTAssertFalse(element(labelled: "Test Set 60001-1").exists)
    }

    private func addSet(_ number: String) {
        let addButton = app.buttons["Add set"]
        XCTAssertTrue(addButton.waitForExistence(timeout: 10))
        addButton.tap()

        let field = app.textFields["Set number (e.g. 60272)"]
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        field.tap()
        field.typeText("\(number)\n")
        XCTAssertTrue(field.waitForNonExistence(timeout: 5))
    }

    private func themeRow(_ name: String) -> XCUIElement {
        app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "\(name),")).firstMatch
    }

    private func element(labelled text: String) -> XCUIElement {
        app.descendants(matching: .any).matching(NSPredicate(format: "label CONTAINS %@", text)).firstMatch
    }
}
