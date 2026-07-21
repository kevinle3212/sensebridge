import XCTest

@MainActor
final class SenseBridgeUITests: XCTestCase {
    func testHomeScreenShowsAllModes() {
        let app = XCUIApplication()
        // Guards against leftover persisted language state from other UI
        // tests in the same run (see LanguageSelectionUITests).
        app.launchArguments = ["-uiTestReset"]
        app.launch()

        XCTAssertTrue(app.navigationBars["SenseBridge"].waitForExistence(timeout: 5))
        for mode in ["Read document", "Identify object", "Describe scene", "Obstacle awareness", "Sound alerts"] {
            let element = app.descendants(matching: .any).matching(NSPredicate(format: "label == %@", mode)).firstMatch
            XCTAssertTrue(element.exists, "Missing mode element labeled: \(mode)")
        }
    }
}
