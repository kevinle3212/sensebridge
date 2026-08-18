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

    /// Covers `SettingsView`'s Output section: the Deaf profile becomes a
    /// real choice only after `CaptionRenderTarget` is registered.
    func testOutputProfilePickerOffersDeaf() {
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
        XCTAssertTrue(app.buttons["Deaf"].exists)
    }

    /// Selecting the Deaf profile must persist as a working choice rather
    /// than reverting to speech or leaving Settings with a blank picker row.
    func testDeafOutputProfileCanBeSelected() {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["-uiTestReset"]
        app.launch()
        // The assertion lives in `selectDeafProfile`: the selection has to
        // survive the picker's pop for every later test that depends on it,
        // so it is checked where it is made rather than only here.
        selectDeafProfile(in: app)
    }

    /// The Deaf profile's whole point: prose the other profiles hear has to
    /// appear on screen. Asserted end to end — the capture path composes real
    /// prose and pushes it through `MultiRenderTarget` to `CaptionRenderTarget`
    /// and out to `CaptionOverlay`, so this fails if any link is missing, not
    /// only if the view is wrong.
    ///
    /// The Simulator has no camera, so the prose is an error message rather
    /// than a label. That is deliberate: which sentence arrives is not the
    /// claim under test, only that *some* output reaches the screen on a
    /// profile whose sole channel is this one.
    func testDeafProfileShowsOutputAsAnOnScreenCaption() {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["-uiTestReset"]
        app.launch()
        selectDeafProfile(in: app)
        app.navigationBars.buttons.element(boundBy: 0).tap()

        element(app, labeled: "Identify object").tap()
        let capture = app.buttons["Capture object"]
        XCTAssertTrue(capture.waitForExistence(timeout: 10))
        capture.tap()

        let caption = app.descendants(matching: .any)
            .matching(NSPredicate(format: "label BEGINSWITH %@", "Caption:"))
            .firstMatch
        XCTAssertTrue(caption.waitForExistence(timeout: 10))
    }

    /// Drives Settings → Output profile → Deaf, leaving the app on Settings.
    private func selectDeafProfile(in app: XCUIApplication) {
        element(app, labeled: "Settings").tap()
        let outputRow = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Output profile")).firstMatch
        scrollUntilExists(outputRow, in: app)
        outputRow.tap()
        let deaf = app.buttons["Deaf"]
        XCTAssertTrue(deaf.waitForExistence(timeout: 5))
        deaf.tap()
        expectation(
            for: NSPredicate(format: "label CONTAINS %@", "Deaf"),
            evaluatedWith: outputRow
        )
        waitForExpectations(timeout: 5)
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
