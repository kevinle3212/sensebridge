import Testing
@testable import SenseBridgeCore

struct AwarenessEngineTests {
    @Test
    func firesWhenWithinAlertThreshold() {
        var engine = AwarenessEngine(alertThresholdMeters: 1.5, clearThresholdMeters: 2.5)
        #expect(engine.evaluate(depthMeters: 1.0) == .becameAlerting)
        #expect(engine.isAlerting)
    }

    @Test
    func staysClearWhenBeyondClearThreshold() {
        var engine = AwarenessEngine(alertThresholdMeters: 1.5, clearThresholdMeters: 2.5)
        #expect(engine.evaluate(depthMeters: 3.0) == .unchanged)
        #expect(!engine.isAlerting)
    }

    @Test
    func hysteresisHoldsAlertInsideDeadBand() {
        var engine = AwarenessEngine(alertThresholdMeters: 1.5, clearThresholdMeters: 2.5)

        #expect(engine.evaluate(depthMeters: 1.0) == .becameAlerting)
        // 2.0m is between the two thresholds: should stay alerting rather
        // than flap, which is the entire point of hysteresis.
        #expect(engine.evaluate(depthMeters: 2.0) == .unchanged)
        #expect(engine.isAlerting)
        #expect(engine.evaluate(depthMeters: 2.5) == .becameClear)
        #expect(!engine.isAlerting)
    }

    @Test
    func repeatedNearReadingsReportOnlyTheFirstAsATransition() {
        var engine = AwarenessEngine(alertThresholdMeters: 1.5, clearThresholdMeters: 2.5)

        #expect(engine.evaluate(depthMeters: 1.0) == .becameAlerting)
        // The whole reason `.awarenessClear` can finally be emitted is that a
        // steady state is distinguishable from a change. If a held reading
        // reported `.becameAlerting` every frame, a continuous session would
        // interrupt the user several times a second.
        #expect(engine.evaluate(depthMeters: 1.0) == .unchanged)
        #expect(engine.evaluate(depthMeters: 0.8) == .unchanged)
    }

    @Test
    func clearingIsOnlyReportedAfterAnActualAlert() {
        var engine = AwarenessEngine(alertThresholdMeters: 1.5, clearThresholdMeters: 2.5)

        // Never alerted, so there is no change to report — and nothing that
        // would justify a "clear" cue. See `OutputSignal.awarenessClear`.
        #expect(engine.evaluate(depthMeters: 5.0) == .unchanged)
        #expect(engine.evaluate(depthMeters: 4.0) == .unchanged)
    }

    @Test
    func resetSuppressesAStaleAlertFromAPreviousSession() {
        var engine = AwarenessEngine(alertThresholdMeters: 1.5, clearThresholdMeters: 2.5)
        #expect(engine.evaluate(depthMeters: 1.0) == .becameAlerting)

        engine.reset()

        #expect(!engine.isAlerting)
        // Without the reset this would report `.unchanged`, and the first real
        // alert of the new session would never be spoken.
        #expect(engine.evaluate(depthMeters: 1.0) == .becameAlerting)
    }

    @Test
    func derivedHysteresisInitializerNeverInvertsTheBand() {
        let engine = AwarenessEngine.alerting(withinMeters: 2.0)
        #expect(engine.clearThresholdMeters > engine.alertThresholdMeters)

        // A caller passing a nonsensical band still gets a valid one rather
        // than tripping the precondition in the designated initializer.
        let clamped = AwarenessEngine.alerting(withinMeters: 2.0, hysteresisMeters: 0)
        #expect(clamped.clearThresholdMeters > clamped.alertThresholdMeters)
    }
}
