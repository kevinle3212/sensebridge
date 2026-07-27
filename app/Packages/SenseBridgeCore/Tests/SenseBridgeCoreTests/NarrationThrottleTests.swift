import Foundation
import Testing
@testable import SenseBridgeCore

/// `shouldSpeak` is `mutating`, and `#expect` cannot expand a mutating call
/// directly ("cannot use mutating member on immutable value"), so every
/// decision below is bound to a local first and the local is asserted on.
struct NarrationThrottleTests {
    private let start: Date = .init(timeIntervalSince1970: 0)

    @Test
    func speaksTheFirstObservationImmediately() {
        var throttle = NarrationThrottle(minimumInterval: 4, repeatSuppressionInterval: 20)
        let spoke = throttle.shouldSpeak("it looks like there's a chair.", at: start)
        #expect(spoke)
    }

    @Test
    func holdsBackASecondObservationInsideTheMinimumInterval() {
        var throttle = NarrationThrottle(minimumInterval: 4, repeatSuppressionInterval: 20)
        _ = throttle.shouldSpeak("it looks like there's a chair.", at: start)

        let tooSoon = throttle.shouldSpeak(
            "it looks like there's a door.", at: start.addingTimeInterval(1)
        )
        let onTime = throttle.shouldSpeak(
            "it looks like there's a door.", at: start.addingTimeInterval(4)
        )

        #expect(tooSoon == false)
        #expect(onTime)
    }

    @Test
    func suppressesAnUnchangedSceneUntilTheRepeatInterval() {
        var throttle = NarrationThrottle(minimumInterval: 4, repeatSuppressionInterval: 20)
        let unchanged = "it looks like there's a refrigerator."
        _ = throttle.shouldSpeak(unchanged, at: start)

        // Past the minimum interval, but the scene has not changed — a user
        // standing still should not hear this every four seconds.
        let atFive = throttle.shouldSpeak(unchanged, at: start.addingTimeInterval(5))
        let atNineteen = throttle.shouldSpeak(unchanged, at: start.addingTimeInterval(19))
        // Re-stated eventually, so silence stays distinguishable from a
        // feature that has quietly stopped working.
        let atTwenty = throttle.shouldSpeak(unchanged, at: start.addingTimeInterval(20))

        #expect(atFive == false)
        #expect(atNineteen == false)
        #expect(atTwenty)
    }

    @Test
    func urgentMessagesBypassBothIntervals() {
        var throttle = NarrationThrottle(minimumInterval: 4, repeatSuppressionInterval: 20)
        _ = throttle.shouldSpeak("it looks like there's a chair.", at: start)

        // A real `AwarenessTransition` fires once per crossing, so it cannot
        // flood the channel — and holding it back for a cadence the user chose
        // for routine narration would defeat the point of the alert.
        let urgent = throttle.shouldSpeak(
            "it looks like there's something ahead.",
            at: start.addingTimeInterval(0.5),
            isUrgent: true
        )

        #expect(urgent)
    }

    @Test
    func urgentMessagesResetTheCadenceForWhatFollows() {
        var throttle = NarrationThrottle(minimumInterval: 4, repeatSuppressionInterval: 20)
        _ = throttle.shouldSpeak("alert", at: start, isUrgent: true)

        // The urgent message was spoken, so routine narration queues behind it
        // rather than talking over it a moment later.
        let immediatelyAfter = throttle.shouldSpeak("routine", at: start.addingTimeInterval(1))
        let laterOn = throttle.shouldSpeak("routine", at: start.addingTimeInterval(4))

        #expect(immediatelyAfter == false)
        #expect(laterOn)
    }

    @Test
    func resetLetsANewSessionSpeakImmediately() {
        var throttle = NarrationThrottle(minimumInterval: 4, repeatSuppressionInterval: 20)
        let text = "it looks like there's a chair."
        _ = throttle.shouldSpeak(text, at: start)

        throttle.reset()

        // A session that ended in one room must not start the next one holding
        // that room's narration back.
        let spoke = throttle.shouldSpeak(text, at: start.addingTimeInterval(0.1))
        #expect(spoke)
    }

    @Test
    func alternatingBetweenTwoScenesIsStillRateLimited() {
        var throttle = NarrationThrottle(minimumInterval: 4, repeatSuppressionInterval: 20)
        _ = throttle.shouldSpeak("a", at: start)

        // Different text clears the repeat check but not the cadence check —
        // otherwise a flickering classification would narrate continuously.
        let spoke = throttle.shouldSpeak("b", at: start.addingTimeInterval(2))
        #expect(spoke == false)
    }
}
