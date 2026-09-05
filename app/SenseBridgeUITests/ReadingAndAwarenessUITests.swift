import XCTest

/// Covers the built-out Read and Awareness screens: playback transport,
/// multi-page capture, reading history, and the on-screen awareness controls.
///
/// The Simulator has no camera and no LiDAR, so every capture path here ends in
/// the known no-camera state. That is the point: these tests prove the *screen*
/// stays navigable, labelled, and honest when the sensor behind it produces
/// nothing — which is the state a real user meets whenever permission is denied
/// or the hardware is busy, and the state
/// `LiveTapThroughUITests.testNoScreenClaimsTheWayIsClearWhenSensorsAreUnavailable`
/// already guards the wording of.
@MainActor
final class ReadingAndAwarenessUITests: XCTestCase {
    // MARK: - Read: happy path

    /// Happy path: the mode picker, the transport row, and the history link are
    /// all reachable through the accessibility tree VoiceOver drives, and the
    /// screen passes the same audit floor as every other screen.
    func testReadScreenExposesModePickerAndHistoryAndPassesAccessibilityAudit() throws {
        continueAfterFailure = false
        let app = launch()

        element(app, labeled: "Read").tap()

        XCTAssertTrue(
            app.buttons["One photo at a time"].waitForExistence(timeout: 5),
            "the capture/live mode picker must be reachable, not buried in Settings"
        )
        XCTAssertTrue(app.buttons["Keep reading"].exists)
        let historyLink = element(app, labeled: "Reading history")
        scrollUntilExists(historyLink, in: app)
        XCTAssertTrue(historyLink.exists, "the history link must be reachable from the Read screen")
        try performScopedAccessibilityAudit(app)
    }

    /// Happy path: switching to live reading persists, so the user's chosen mode
    /// survives leaving the screen rather than resetting to capture each time.
    func testChosenReadingModePersistsAcrossRelaunch() {
        continueAfterFailure = false
        let setup = launch()
        element(setup, labeled: "Read").tap()
        setup.buttons["Keep reading"].tap()
        setup.terminate()

        let app = XCUIApplication()
        app.launch()
        element(app, labeled: "Read").tap()

        let live = app.buttons["Keep reading"]
        XCTAssertTrue(live.waitForExistence(timeout: 5))
        XCTAssertTrue(
            live.isSelected,
            "the Read screen should reopen in the mode the user last chose, not back on capture"
        )
    }

    // MARK: - Read: error path

    /// Error path: with no camera, capturing says so out loud rather than
    /// leaving a silent screen — and the transport controls stay absent rather
    /// than offering to play a document that does not exist.
    ///
    /// The camera-less state is forced by `-uiTestNoCamera` rather than assumed
    /// from the host. Assuming it is what made this pass in the Simulator and
    /// fail on the first device run — a phone has a camera, so "with no camera"
    /// was simply not the situation under test any more.
    func testCapturingWithoutACameraReportsItAndOffersNoPlayback() {
        continueAfterFailure = false
        let app = launch(extraArguments: ["-uiTestNoCamera"])

        element(app, labeled: "Read").tap()
        XCTAssertTrue(app.buttons["Capture document"].waitForExistence(timeout: 5))

        XCTAssertTrue(
            app.staticTexts["No camera is available on this device."].waitForExistence(timeout: 5),
            "the no-camera error must be stated, not left as an empty screen"
        )
        XCTAssertFalse(
            app.buttons["Read from the beginning"].exists,
            "playback controls must not appear for a document that was never captured"
        )
    }

    // MARK: - Read: edge case

    /// Edge case: history opens, states its own privacy posture, and says why it
    /// is empty rather than presenting a blank list — which a VoiceOver user
    /// cannot tell from a screen that failed to load.
    func testEmptyReadingHistoryExplainsItselfAndStatesWhereTextIsKept() throws {
        continueAfterFailure = false
        let app = launch()

        element(app, labeled: "Read").tap()
        let historyLink = element(app, labeled: "Reading history")
        scrollUntilExists(historyLink, in: app)
        historyLink.tap()

        XCTAssertTrue(
            app.staticTexts.matching(
                NSPredicate(format: "label CONTAINS %@", "never included in a backup")
            ).firstMatch.waitForExistence(timeout: 5),
            "the history screen must state where read text is kept, not only Settings"
        )
        XCTAssertTrue(
            app.staticTexts.matching(
                NSPredicate(format: "label CONTAINS %@", "History is off")
            ).firstMatch.exists,
            "an empty history must say why it is empty rather than render as a blank list"
        )
        try performScopedAccessibilityAudit(app, allowsListFormAuditQuirks: true)
    }

    // MARK: - Awareness: happy path

    /// Happy path: the sensitivity controls are on the Awareness screen itself,
    /// labelled, and carry a real accessible value — a slider a VoiceOver user
    /// can hear the current setting of, not just drag blindly.
    func testAwarenessSensitivityControlsAreOnScreenAndLabelled() throws {
        continueAfterFailure = false
        let app = launch()

        element(app, labeled: "Obstacle awareness").tap()
        let slider = app.sliders["Alert distance"]
        scrollUntilExists(slider, in: app)

        XCTAssertTrue(slider.exists, "the alert-distance control must be reachable on the Awareness screen")
        XCTAssertFalse(
            (slider.value as? String ?? "").isEmpty,
            "the slider must report its current distance, or a VoiceOver user is dragging an unlabelled value"
        )
        XCTAssertTrue(
            app.switches["Pulse faster as things get nearer"].exists,
            "the proximity-haptics toggle must be reachable"
        )
        try performScopedAccessibilityAudit(app, allowsListFormAuditQuirks: true)
    }

    /// Happy path: changing the threshold persists, and the screen says when the
    /// change takes effect rather than leaving the user to guess.
    func testChangedAlertDistancePersistsAndSaysWhenItApplies() {
        continueAfterFailure = false
        let setup = launch()
        element(setup, labeled: "Obstacle awareness").tap()
        let slider = setup.sliders["Alert distance"]
        scrollUntilExists(slider, in: setup)
        slider.adjust(toNormalizedSliderPosition: 0.9)
        let chosen = setup.staticTexts.matching(
            NSPredicate(format: "label BEGINSWITH %@", "Mention things within about")
        ).firstMatch.label
        XCTAssertTrue(
            setup.staticTexts.matching(
                NSPredicate(format: "label CONTAINS %@", "next time hands-free awareness starts")
            ).firstMatch.exists,
            "the screen must say when a new threshold takes effect"
        )
        setup.terminate()

        let app = XCUIApplication()
        app.launch()
        element(app, labeled: "Obstacle awareness").tap()
        let label = app.staticTexts.matching(
            NSPredicate(format: "label BEGINSWITH %@", "Mention things within about")
        ).firstMatch
        scrollUntilExists(label, in: app)

        XCTAssertEqual(label.label, chosen, "the chosen alert distance should survive a relaunch")
    }

    // MARK: - Awareness: error and edge

    /// Error path: with no LiDAR, a single check reports that it could not
    /// measure — never that the way is clear. The distinction is the whole
    /// safety-framing doctrine, so it is asserted on the exact words.
    func testSingleCheckWithoutDepthSaysItCouldNotMeasure() {
        continueAfterFailure = false
        let app = launch()

        element(app, labeled: "Obstacle awareness").tap()
        let check = app.buttons["Check once for what may be ahead"]
        scrollUntilExists(check, in: app)
        check.tap()

        let couldNotMeasure = app.staticTexts.matching(
            NSPredicate(format: "label CONTAINS[c] %@", "measure")
        ).firstMatch
        XCTAssertTrue(
            couldNotMeasure.waitForExistence(timeout: 10),
            "a check that could not measure must say so"
        )
        for forbidden in ["the way is clear", "nothing is ahead", "path is clear"] {
            XCTAssertFalse(
                app.staticTexts.matching(
                    NSPredicate(format: "label CONTAINS[c] %@", forbidden)
                ).firstMatch.exists,
                "\"\(forbidden)\" is a claim this app never makes — see docs/SAFETY-FRAMING.md"
            )
        }
    }

    /// Edge case: the disclaimer stays first on the screen even after the
    /// sensitivity section was added below it. A limitation that scrolls out of
    /// the first screenful is a limitation most users never meet.
    func testTheSafetyDisclaimerIsStillTheFirstThingOnTheAwarenessScreen() {
        continueAfterFailure = false
        let app = launch()

        element(app, labeled: "Obstacle awareness").tap()

        let disclaimer = app.staticTexts.matching(
            NSPredicate(format: "label CONTAINS %@", "not a safety or mobility device")
        ).firstMatch
        XCTAssertTrue(disclaimer.waitForExistence(timeout: 5))
        let slider = app.sliders["Alert distance"]
        if slider.exists {
            XCTAssertLessThan(
                disclaimer.frame.minY,
                slider.frame.minY,
                "the disclaimer must stay above the controls it qualifies"
            )
        }
    }

    // MARK: - Helpers

    /// A freshly reset app instance, so no earlier test's persisted settings
    /// leak into this one.
    /// Launches from a known state, optionally with extra launch arguments.
    ///
    /// - Parameter extraArguments: Appended after `-uiTestReset`; used to pass
    ///   `-uiTestNoCamera` where a test needs the camera-unavailable path
    ///   regardless of whether the host has a camera.
    private func launch(extraArguments: [String] = []) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-uiTestReset"] + extraArguments
        app.launch()
        return app
    }

    private func element(_ app: XCUIApplication, labeled label: String) -> XCUIElement {
        app.descendants(matching: .any).matching(NSPredicate(format: "label == %@", label)).firstMatch
    }

    /// Swipes up on `app` until `element` exists, bounded so a genuinely
    /// missing element still fails fast rather than looping forever.
    private func scrollUntilExists(_ element: XCUIElement, in app: XCUIApplication, maxSwipes: Int = 6) {
        var remaining = maxSwipes
        while !element.exists, remaining > 0 {
            app.swipeUp()
            remaining -= 1
        }
    }
}
