import CoreGraphics
import Testing
@testable import SenseBridgeCore

/// Regression coverage for `DetectionStabilizer` — the temporal filter that
/// keeps awareness outlines and nouns from flickering between ticks. Each test
/// drives ticks through `update(_:malfunction:limit:)` and pins what is
/// visible, because the visible list is exactly what the session speaks and
/// outlines.
struct DetectionStabilizerTests {
    private func object(
        _ label: String,
        _ confidence: Double = 0.9,
        originX: Double = 0.1,
        originY: Double = 0.1,
        width: Double = 0.3,
        height: Double = 0.3
    ) -> DetectedObject {
        DetectedObject(
            label: label,
            confidence: confidence,
            boundingBox: CGRect(
                x: originX,
                y: originY,
                width: width,
                height: height
            )
        )
    }

    /// A label needs `confirmationTicks` consecutive sightings before it is
    /// shown at all — one clean pass is not enough to outline or speak it.
    @Test
    func firstSightingStaysHiddenUntilConfirmed() {
        var stabilizer = DetectionStabilizer()
        let first = stabilizer.update([object("a chair")])
        #expect(first.isEmpty)
        let second = stabilizer.update([object("a chair")])
        #expect(second.map(\.label) == ["a chair"])
    }

    /// A confirmed label survives a single missed tick (streak resets, the
    /// confirmed flag does not), and drops only after persistence runs out.
    @Test
    func confirmedLabelSurvivesOneMissedTickThenDropsAfterPersistence() {
        var stabilizer = DetectionStabilizer(confirmationTicks: 2, persistenceTicks: 2)
        _ = stabilizer.update([object("a chair")])
        let shown = stabilizer.update([object("a chair")])
        #expect(shown.count == 1)

        // A missed tick keeps a confirmed label visible; only its streak breaks.
        let missedOnce = stabilizer.update([] as [DetectedObject])
        #expect(missedOnce.count == 1)

        // Still inside the persistence window (misses == persistenceTicks).
        let missedTwice = stabilizer.update([] as [DetectedObject])
        #expect(missedTwice.count == 1)

        // Third consecutive miss exceeds persistenceTicks — gone entirely.
        let dropped = stabilizer.update([] as [DetectedObject])
        #expect(dropped.isEmpty)

        // A re-sighting now starts from scratch: one tick is not enough.
        let reseen = stabilizer.update([object("a chair")])
        #expect(reseen.isEmpty)
    }

    /// The box tracks the latest sighting and confidence keeps the max, so a
    /// moving object's outline follows it while its hedge never downgrades.
    @Test
    func boxRefreshesAndConfidenceKeepsTheMax() {
        var stabilizer = DetectionStabilizer()
        _ = stabilizer.update([object("a chair", 0.62)])
        let refreshed = stabilizer.update([object("a chair", 0.55, originX: 0.7)])

        #expect(refreshed.count == 1)
        #expect(refreshed[0].boundingBox.origin.x == 0.7)
        #expect(refreshed[0].confidence == 0.62)
    }

    /// A malfunction pass holds the previous output without counting a miss,
    /// so a transient Vision failure neither flickers the scene nor extends a
    /// dying label's lease.
    @Test
    func malfunctionPassHoldsPreviousOutputWithoutCountingAMiss() {
        var stabilizer = DetectionStabilizer(confirmationTicks: 2, persistenceTicks: 3)
        _ = stabilizer.update([object("a chair")])
        let shown = stabilizer.update([object("a chair")])
        #expect(shown.count == 1)

        // Holds through failures without aging anything.
        let held = stabilizer.update([], malfunction: true)
        #expect(held.count == 1)
        let heldAgain = stabilizer.update([], malfunction: true)
        #expect(heldAgain.count == 1)

        // The hold aged nothing: three more real empty ticks run persistence
        // out exactly, then the fourth drops it.
        _ = stabilizer.update([] as [DetectedObject])
        _ = stabilizer.update([] as [DetectedObject])
        _ = stabilizer.update([] as [DetectedObject])
        let gone = stabilizer.update([] as [DetectedObject])
        #expect(gone.isEmpty)
    }

    /// Output is capped at `limit`, most-confident first, across labels
    /// confirmed in the same tick.
    @Test
    func outputIsCappedAtTheLimitMostConfidentFirst() {
        var stabilizer = DetectionStabilizer(confirmationTicks: 1)
        let capped = stabilizer.update([
            object("a table", 0.95),
            object("a chair", 0.62),
            object("a bed", 0.8)
        ], limit: 2)

        #expect(capped.map(\.label) == ["a table", "a bed"])
    }
}
