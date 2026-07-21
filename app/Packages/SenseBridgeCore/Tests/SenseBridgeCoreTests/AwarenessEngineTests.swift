import Testing
@testable import SenseBridgeCore

struct AwarenessEngineTests {
    @Test
    func firesWhenWithinAlertThreshold() {
        var engine = AwarenessEngine(alertThresholdMeters: 1.5, clearThresholdMeters: 2.5)
        #expect(engine.evaluate(depthMeters: 1.0) == true)
    }

    @Test
    func staysClearWhenBeyondClearThreshold() {
        var engine = AwarenessEngine(alertThresholdMeters: 1.5, clearThresholdMeters: 2.5)
        #expect(engine.evaluate(depthMeters: 3.0) == false)
    }

    @Test
    func hysteresisHoldsAlertInsideDeadBand() {
        var engine = AwarenessEngine(alertThresholdMeters: 1.5, clearThresholdMeters: 2.5)

        #expect(engine.evaluate(depthMeters: 1.0) == true)
        // 2.0m is between the two thresholds: should stay alerting rather
        // than flap, which is the entire point of hysteresis.
        #expect(engine.evaluate(depthMeters: 2.0) == true)
        #expect(engine.evaluate(depthMeters: 2.5) == false)
    }
}
