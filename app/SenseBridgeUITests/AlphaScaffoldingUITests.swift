import XCTest

/// Programmatic substitute for the manual VoiceOver device pass flagged as
/// outstanding in the project's tracked follow-up queue for this session's
/// alpha-scaffolding work (Identify/Describe wired to real Vision, Sound
/// Alerts, onboarding). No live device-interaction tool was available to
/// drive VoiceOver by hand, so this escalates per the global CLAUDE.md
/// "Escalate Manual Verification": `XCUIApplication.performAccessibilityAudit()`
/// (Xcode 15+/iOS 17+) walks the accessibility tree the same way VoiceOver
/// would and fails on unlabeled elements, insufficient contrast, and small
/// hit targets — the actual "zero unlabeled elements" gate, not an eyeball
/// check standing in for it.
@MainActor
final class AlphaScaffoldingUITests: XCTestCase {
    /// Onboarding's full happy path: every step's heading is reachable, the
    /// step transition doesn't just leave stale content on screen (the same
    /// defect `announceStepChange()` exists to prevent — this proves the
    /// *effect* of that notification, not just that the call site exists),
    /// and finishing lands on `HomeView` via `RootView`'s
    /// `hasCompletedOnboarding` swap.
    func testOnboardingWalkthroughAdvancesThroughEveryStepToHome() throws {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["-uiTestReset", "-uiTestShowOnboarding"]
        app.launch()

        let welcomeHeading = app.staticTexts["Welcome to SenseBridge"]
        XCTAssertTrue(welcomeHeading.waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts.matching(
            NSPredicate(format: "label CONTAINS %@", "not a mobility or safety device")
        ).firstMatch.exists, "Welcome step is missing the doctrine-mandated non-replacement statement")
        try performScopedAccessibilityAudit(app)

        // Waits for "Next" itself, not just the previous step's heading —
        // on a physical device the step-change animation can leave the
        // button briefly unhittable after the heading it's paired with
        // already exists, which read as a flaky tap failure the one time
        // this ran on real hardware instead of the Simulator.
        XCTAssertTrue(app.buttons["Next"].waitForExistence(timeout: 5))
        app.buttons["Next"].tap()
        let permissionsHeading = app.staticTexts["Camera and microphone"]
        XCTAssertTrue(permissionsHeading.waitForExistence(timeout: 5))
        XCTAssertFalse(welcomeHeading.exists, "Welcome content should be gone once the step changed")
        try performScopedAccessibilityAudit(app)

        XCTAssertTrue(app.buttons["Next"].waitForExistence(timeout: 5))
        app.buttons["Next"].tap()
        XCTAssertTrue(
            app.switches.firstMatch.waitForExistence(timeout: 5),
            "Diagnostics step should show the crash-reporting toggle"
        )
        XCTAssertFalse(permissionsHeading.exists, "Permissions content should be gone once the step changed")
        try performScopedAccessibilityAudit(app, allowsListFormAuditQuirks: true)

        XCTAssertTrue(app.buttons["Finish"].waitForExistence(timeout: 5))
        app.buttons["Finish"].tap()
        XCTAssertTrue(
            app.navigationBars["SenseBridge"].waitForExistence(timeout: 5),
            "Finishing onboarding should reach Home"
        )
    }

    /// Stepping back must return the previous step's content, not just its
    /// heading — a partially-restored step would still fail a VoiceOver
    /// user even if the static text matched.
    func testBackButtonReturnsToPreviousStep() throws {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["-uiTestReset", "-uiTestShowOnboarding"]
        app.launch()

        XCTAssertTrue(app.staticTexts["Welcome to SenseBridge"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["Back"].exists, "Welcome is the first step — there's nothing to go back to")

        XCTAssertTrue(app.buttons["Next"].waitForExistence(timeout: 5))
        app.buttons["Next"].tap()
        XCTAssertTrue(app.staticTexts["Camera and microphone"].waitForExistence(timeout: 5))

        XCTAssertTrue(app.buttons["Back"].waitForExistence(timeout: 5))
        app.buttons["Back"].tap()
        XCTAssertTrue(app.staticTexts["Welcome to SenseBridge"].waitForExistence(timeout: 5))
        try performScopedAccessibilityAudit(app)
    }

    /// Settings' "Replay walkthrough" row resets `hasCompletedOnboarding`,
    /// which only takes effect through `RootView`'s reactive swap back to
    /// `OnboardingView` — the accessibility review flagged this direction of
    /// the swap as unconfirmed without a live session.
    func testReplayWalkthroughReturnsToOnboarding() throws {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["-uiTestReset"]
        app.launch()

        element(app, labeled: "Settings").tap()
        let replayRow = app.buttons["Replay walkthrough"]
        scrollUntilExists(replayRow, in: app)
        replayRow.tap()

        XCTAssertTrue(
            app.staticTexts["Welcome to SenseBridge"].waitForExistence(timeout: 5),
            "Replay walkthrough should swap back to OnboardingView"
        )
        try performScopedAccessibilityAudit(app)
    }

    /// Identify's static chrome (it has no camera on a Simulator, so
    /// `startCameraIfNeeded()` settles on its "No camera is available"
    /// error state) — same audit floor as every other screen.
    func testIdentifyScreenPassesAccessibilityAudit() throws {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["-uiTestReset"]
        app.launch()

        element(app, labeled: "Identify object").tap()
        XCTAssertTrue(app.buttons["Capture object"].waitForExistence(timeout: 5))
        try performScopedAccessibilityAudit(app)
    }

    /// Describe's static chrome — same rationale as Identify above.
    func testDescribeScreenPassesAccessibilityAudit() throws {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["-uiTestReset"]
        app.launch()

        element(app, labeled: "Describe scene").tap()
        XCTAssertTrue(app.buttons["Describe scene"].waitForExistence(timeout: 5))
        try performScopedAccessibilityAudit(app)
    }

    /// Sound Alerts' on-screen limitation disclaimer (the safety-framing
    /// fix that put "not a substitute for hearing, and not a safety device"
    /// in front of the user, not just in source) must actually be present
    /// and reachable, plus the same accessibility audit floor.
    func testSoundAlertsScreenShowsDisclaimerAndPassesAccessibilityAudit() throws {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["-uiTestReset"]
        app.launch()

        element(app, labeled: "Sound alerts").tap()
        XCTAssertTrue(app.buttons["Listen once for sounds"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts.matching(
            NSPredicate(format: "label CONTAINS %@", "not a safety device")
        ).firstMatch.exists, "Sound Alerts is missing its on-screen limitation disclaimer")
        try performScopedAccessibilityAudit(app)
    }

    /// Awareness screen (`List`-based, unlike the `VStack` screens above) —
    /// same audit floor, plus confirming the safety-framing disclaimer is
    /// reachable. Escalates the manual VoiceOver pass the follow-up queue
    /// asked for on this screen.
    func testAwarenessScreenPassesAccessibilityAudit() throws {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["-uiTestReset"]
        app.launch()

        element(app, labeled: "Obstacle awareness").tap()
        XCTAssertTrue(app.staticTexts.matching(
            NSPredicate(format: "label CONTAINS %@", "not a safety or mobility device")
        ).firstMatch.exists, "Awareness is missing its on-screen limitation disclaimer")
        try performScopedAccessibilityAudit(app, allowsListFormAuditQuirks: true)
    }

    /// Settings' "Awareness" section (narration interval / alert distance
    /// sliders) must be reachable and pass the same audit floor. Escalates
    /// the manual VoiceOver pass the follow-up queue asked for on this
    /// section.
    ///
    /// The only audit in the suite that has to scroll to reach what it is
    /// about, which is why it is the only one that audits twice — see the call
    /// site.
    func testSettingsAwarenessSectionPassesAccessibilityAudit() throws {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["-uiTestReset"]
        app.launch()

        element(app, labeled: "Settings").tap()
        // Twice, and deliberately: the full audit — contrast included — runs on
        // the screen at rest, where it costs under a second, and the scrolled
        // pass covers the Awareness section itself. See
        // `performScopedAccessibilityAudit` for why the scrolled one asks for
        // no contrast.
        try performScopedAccessibilityAudit(app, allowsListFormAuditQuirks: true)
        let alertDistanceSlider = app.sliders["Alert distance"]
        scrollUntilExists(alertDistanceSlider, in: app)
        XCTAssertTrue(alertDistanceSlider.exists, "Settings is missing the Awareness section's alert-distance slider")
        XCTAssertNotNil(
            alertDistanceSlider.value as? String,
            "the alert-distance slider must speak its current value, not just its name"
        )
        try performScopedAccessibilityAudit(app, allowsListFormAuditQuirks: true, isScrolled: true)
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
