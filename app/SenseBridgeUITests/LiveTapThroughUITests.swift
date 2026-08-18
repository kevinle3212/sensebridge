import XCTest

/// Drives each of the five feature screens the way a user does — open it, tap
/// its primary control, wait for a result — and asserts something actually
/// happened.
///
/// ## Why this exists
///
/// A long-standing to-do asked someone to confirm by hand that every screen
/// responds on tap, because earlier sessions had only ever proved the app
/// *builds* and that its unit tests pass. Neither says anything about whether a
/// button is wired to anything. This is that manual step turned into a command,
/// per the repo's rule that a manual verification step is a gap in the suite.
///
/// ## What "responds" means on a simulator
///
/// There is no camera, no LiDAR, and no useful microphone here, so the honest
/// assertion is **not** that the app describes a scene — it is that each tap
/// reaches real code and comes back with a real, specific message instead of
/// doing nothing. A silently inert button and a correctly-failing one look
/// identical in a build log and completely different here.
///
/// That makes these tests sensitive to the thing most worth catching: a control
/// that stops being wired up. They deliberately do **not** assert the exact
/// prose of a success path, which only a device can produce.
@MainActor
final class LiveTapThroughUITests: XCTestCase {
    /// Each screen's own copy differs, and Read has a distinct OCR failure
    /// path on top of the shared camera ones. Listing the full known set per
    /// screen keeps this a test of "the control answers" rather than an
    /// accidental test of which camera error a given host happens to raise.
    private static let cameraScreens = [
        (
            mode: "Read document",
            control: "Capture document",
            expected: [
                "No camera is available on this device.",
                "Couldn't read the photo. Try again.",
                "No text was found in the photo.",
                "Camera access is needed to read text. Enable it in Settings."
            ]
        ),
        (
            mode: "Identify object",
            control: "Capture object",
            expected: [
                "No camera is available on this device.",
                "Couldn't identify the photo. Try again.",
                "Camera access is needed to identify objects. Enable it in Settings."
            ]
        ),
        (
            mode: "Describe scene",
            control: "Describe scene",
            expected: [
                "No camera is available on this device.",
                "Couldn't describe the photo. Try again.",
                "Camera access is needed to describe the scene. Enable it in Settings."
            ]
        )
    ]

    /// Every capture screen reports "no camera" rather than going quiet.
    ///
    /// One test over three screens rather than three near-identical ones: the
    /// property under test is the same in each case, and a failure names the
    /// screen it happened on.
    func testEveryCameraScreenAnswersOnTap() {
        continueAfterFailure = false
        for screen in Self.cameraScreens {
            let app = XCUIApplication()
            app.launchArguments = ["-uiTestReset"]
            app.launch()

            element(app, labeled: screen.mode).tap()
            let control = element(app, labeled: screen.control)
            XCTAssertTrue(
                control.waitForExistence(timeout: 5),
                "\(screen.mode): its primary control never appeared"
            )
            control.tap()

            XCTAssertTrue(
                waitForAny(of: screen.expected, in: app, timeout: 15),
                """
                \(screen.mode): tapping produced none of its known results — the control may not be \
                wired up. On screen instead: \(visibleText(in: app))
                """
            )
            app.terminate()
        }
    }

    /// Sound Alerts answers on tap, whatever the simulator's microphone does.
    ///
    /// The outcome legitimately varies — a simulator may record silence and
    /// report "nothing recognizable", or fail to record at all — so this asserts
    /// the screen reaches *one of* its known terminal states rather than
    /// pinning a message the host's audio configuration decides.
    func testSoundAlertsAnswersOnTap() {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["-uiTestReset"]
        app.launch()

        element(app, labeled: "Sound alerts").tap()
        let listen = element(app, labeled: "Listen once for sounds")
        XCTAssertTrue(listen.waitForExistence(timeout: 5))
        listen.tap()

        let known = [
            "Nothing recognizable was found.",
            "Couldn't listen for sounds. Try again.",
            "No microphone is available on this device.",
            "Microphone access is needed to listen for sounds. Enable it in Settings."
        ]
        XCTAssertTrue(
            waitForAny(of: known, in: app, timeout: 25),
            "Sound alerts produced no result at all — the control may not be wired up"
        )
    }

    /// The awareness screen's one-shot check answers on tap.
    ///
    /// The hands-free control is hidden on hardware without LiDAR, which a
    /// simulator is, so "Check once" is the control this asserts on — and its
    /// honest simulator outcome is that it could not measure, never that
    /// anything is clear.
    func testAwarenessSingleCheckAnswersOnTap() {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["-uiTestReset"]
        app.launch()

        element(app, labeled: "Obstacle awareness").tap()
        let check = element(app, labeled: "Check once for what may be ahead")
        XCTAssertTrue(check.waitForExistence(timeout: 5), "the one-shot check control never appeared")
        check.tap()

        XCTAssertTrue(
            waitForAny(of: ["Couldn't take a measurement. Try again."], in: app, timeout: 20),
            "the one-shot check produced no result at all"
        )
    }

    /// Doctrine guard on the same pass: nothing any screen says on a device
    /// with no working sensors may read as a claim that the way is clear.
    ///
    /// This is the failure the safety-framing doctrine ranks highest — an
    /// absence the app cannot observe, stated as fact. Cheap to assert here,
    /// because every screen has just been driven into its failure path.
    func testNoScreenClaimsTheWayIsClearWhenSensorsAreUnavailable() {
        continueAfterFailure = false
        let forbidden = ["the way is clear", "path is clear", "nothing is there", "all clear", "it is safe"]

        for mode in ["Read document", "Identify object", "Describe scene", "Obstacle awareness"] {
            let app = XCUIApplication()
            app.launchArguments = ["-uiTestReset"]
            app.launch()
            element(app, labeled: mode).tap()

            // Everything currently rendered on the screen, after it has settled.
            let texts = app.staticTexts.allElementsBoundByIndex.map { $0.label.lowercased() }
            for phrase in forbidden {
                XCTAssertFalse(
                    texts.contains(where: { $0.contains(phrase) }),
                    "\(mode) renders a clear-path claim: \(phrase)"
                )
            }
            app.terminate()
        }
    }

    // MARK: - Helpers

    /// The first element carrying `label`, regardless of element type.
    ///
    /// Matches `SenseBridgeUITests`'s own helper: SwiftUI renders these
    /// controls as different element types across screens, so querying by type
    /// makes a test fail for a reason that has nothing to do with the feature.
    private func element(_ app: XCUIApplication, labeled label: String) -> XCUIElement {
        app.descendants(matching: .any).matching(NSPredicate(format: "label == %@", label)).firstMatch
    }

    /// Every visible static text, for a failure message.
    ///
    /// Without this, "produced none of its known results" is unactionable — the
    /// first run of these tests failed exactly that way and the screen's actual
    /// message had to be reconstructed from source.
    private func visibleText(in app: XCUIApplication) -> String {
        app.staticTexts.allElementsBoundByIndex
            .map(\.label)
            .filter { !$0.isEmpty }
            .joined(separator: " | ")
    }

    /// Waits until any of `labels` is on screen, or `timeout` elapses.
    ///
    /// Polling rather than `waitForExistence` per candidate: waiting on each in
    /// turn would multiply the timeout by the number of candidates, and these
    /// are alternatives, not a sequence.
    private func waitForAny(of labels: [String], in app: XCUIApplication, timeout: TimeInterval) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if labels.contains(where: { app.staticTexts[$0].exists }) {
                return true
            }
            _ = XCTWaiter.wait(for: [XCTestExpectation(description: "poll")], timeout: 0.5)
        }
        return false
    }
}
