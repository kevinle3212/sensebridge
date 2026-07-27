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

    /// Covers `SettingsView`'s Speech section: each rate/pitch/volume slider
    /// exists and carries a distinct accessibility label — a VoiceOver user
    /// has no other way to tell them apart.
    func testSpeechSectionSlidersAreLabeled() {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["-uiTestReset"]
        app.launch()
        element(app, labeled: "Settings").tap()

        for label in ["Speech rate", "Speech pitch", "Speech volume"] {
            XCTAssertTrue(app.sliders[label].waitForExistence(timeout: 5), "Missing labeled slider: \(label)")
        }
    }

    /// Covers `SettingsView`'s Haptics section: the toggle actually changes
    /// state when tapped, rather than rendering inert.
    func testHapticsToggleFlips() {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["-uiTestReset"]
        app.launch()
        element(app, labeled: "Settings").tap()

        let toggle = app.switches["Enable haptics"]
        XCTAssertTrue(toggle.waitForExistence(timeout: 5))
        let initialValue = toggle.value as? String
        // SwiftUI's Form Toggle exposes the whole row as one accessibility
        // element, but only the switch glyph at its trailing edge is
        // actually hit-testable — a tap at the row's horizontal center (the
        // label text) lands outside it and is silently swallowed.
        toggle.coordinate(withNormalizedOffset: CGVector(dx: 0.95, dy: 0.5)).tap()
        XCTAssertNotEqual(toggle.value as? String, initialValue)
    }

    /// Covers `SettingsView`'s Output section: doctrine requires that a
    /// profile whose channels render nothing (Deaf, until a caption
    /// `RenderTarget` exists) is never offered — see
    /// `AppEnvironment.selectableProfiles`.
    func testOutputProfilePickerDoesNotOfferDeaf() {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["-uiTestReset"]
        app.launch()
        element(app, labeled: "Settings").tap()
        let outputRow = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Output profile")).firstMatch
        // The Output section sits below Speech/Haptics/Camera in the form,
        // so it can start below the fold — scroll it into view before
        // tapping, since SwiftUI's Form doesn't materialize off-screen rows.
        scrollUntilExists(outputRow, in: app)
        outputRow.tap()

        XCTAssertTrue(app.buttons["Blind"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["Deaf"].exists)
    }

    /// Doctrine 4's second corollary: an unbuilt capability is named as
    /// unavailable rather than hidden, so the user learns the option exists
    /// and why it is absent. The reason travels with the name in one
    /// accessibility element — a name announced alone would read as a choice.
    func testUnavailableProfileIsNamedWithItsReason() {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["-uiTestReset"]
        app.launch()
        element(app, labeled: "Settings").tap()
        let row = app.staticTexts.matching(
            NSPredicate(format: "label BEGINSWITH %@", "Deaf, not yet available")
        ).firstMatch
        scrollUntilExists(row, in: app)
        XCTAssertTrue(row.exists)
        XCTAssertTrue(row.label.contains("Captions aren't built yet"))
    }

    private func element(_ app: XCUIApplication, labeled label: String) -> XCUIElement {
        app.descendants(matching: .any).matching(NSPredicate(format: "label == %@", label)).firstMatch
    }

    /// Swipes up on `app` until `element` exists, bounded so a genuinely
    /// missing element still fails fast rather than looping forever.
    private func scrollUntilExists(_ element: XCUIElement, in app: XCUIApplication, maxSwipes: Int = 5) {
        var remaining = maxSwipes
        while !element.exists, remaining > 0 {
            app.swipeUp()
            remaining -= 1
        }
    }
}
