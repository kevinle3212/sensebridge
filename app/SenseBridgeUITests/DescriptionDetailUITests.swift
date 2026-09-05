import XCTest

/// Covers `DetailLevelSettingsSection` (`SettingsSections.swift`) — the
/// `SpokenDetail` preference controlling how many things a description names
/// and how much wording it uses.
@MainActor
final class DescriptionDetailUITests: XCTestCase {
    /// Happy path: picking "Detailed" persists across a relaunch, the same
    /// contract `LanguageSelectionUITests.testPickedLanguagePersistsAcrossRelaunch`
    /// proves for the language picker.
    func testSelectingDetailedPersistsAcrossRelaunch() {
        continueAfterFailure = false
        let setup = XCUIApplication()
        setup.launchArguments = ["-uiTestReset"]
        setup.launch()
        selectDetail("Detailed", in: setup)
        setup.terminate()

        let app = XCUIApplication()
        app.launch()

        element(app, labeled: "Settings").tap()
        let detailRow = app.buttons.matching(
            NSPredicate(format: "label BEGINSWITH %@", "Description detail")
        ).firstMatch
        scrollUntilExists(detailRow, in: app)
        XCTAssertTrue(
            detailRow.label.contains("Detailed"),
            "the picker should still read \"Detailed\" after relaunch, not have reverted to \"Standard\""
        )
    }

    /// Error path: with "Detailed" selected, the Describe screen's no-camera
    /// error path still speaks its known message rather than crashing or going
    /// silent — proving the detail-level plumbing added to
    /// `SceneDescriptionView` didn't disturb the failure path.
    ///
    /// `-uiTestNoCamera` forces that path rather than relying on the host to
    /// lack a camera. It used to rely on exactly that, which is why it passed
    /// in the Simulator for months and failed on the first device run: a phone
    /// has a camera, so the error being asserted correctly never happened.
    func testDescribeScreenStillReportsNoCameraAtDetailedLevel() {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["-uiTestReset", "-uiTestNoCamera"]
        app.launch()
        selectDetail("Detailed", in: app)
        app.navigationBars.buttons.firstMatch.tap()

        element(app, labeled: "Describe scene").tap()

        XCTAssertTrue(
            app.staticTexts["No camera is available on this device."].waitForExistence(timeout: 5),
            "the no-camera error must still be spoken/shown, not an empty or crashed screen"
        )
    }

    /// Edge case: all three options are reachable through the accessibility
    /// tree VoiceOver drives, and the doctrine-disclosure footer — required,
    /// not decorative, per `DetailLevelSettingsSection`'s own doc comment —
    /// is exposed as its own element rather than folded away.
    func testAllThreeDetailLevelsAreAccessibleAndTheFooterIsExposed() {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["-uiTestReset"]
        app.launch()

        element(app, labeled: "Settings").tap()
        let footer = app.staticTexts.matching(
            NSPredicate(format: "label CONTAINS %@", "not that it is more sure about any of it")
        ).firstMatch
        scrollUntilExists(footer, in: app)
        XCTAssertTrue(footer.exists, "the doctrine-disclosure footer must be its own reachable element")

        let detailRow = app.buttons.matching(
            NSPredicate(format: "label BEGINSWITH %@", "Description detail")
        ).firstMatch
        scrollUntilExists(detailRow, in: app)
        detailRow.tap()
        for option in ["Brief", "Standard", "Detailed"] {
            XCTAssertTrue(app.buttons[option].waitForExistence(timeout: 5), "\"\(option)\" must be a reachable option")
        }
    }

    /// Navigates from Home into Settings and picks `option` from the
    /// description-detail menu.
    private func selectDetail(_ option: String, in app: XCUIApplication) {
        element(app, labeled: "Settings").tap()
        let detailRow = app.buttons.matching(
            NSPredicate(format: "label BEGINSWITH %@", "Description detail")
        ).firstMatch
        scrollUntilExists(detailRow, in: app)
        detailRow.tap()
        app.buttons[option].tap()
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

    private func element(_ app: XCUIApplication, labeled label: String) -> XCUIElement {
        app.descendants(matching: .any).matching(NSPredicate(format: "label == %@", label)).firstMatch
    }
}
