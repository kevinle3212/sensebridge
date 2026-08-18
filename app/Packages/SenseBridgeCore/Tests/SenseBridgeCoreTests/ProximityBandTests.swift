import Foundation
import Testing
@testable import SenseBridgeCore

struct ProximityBandTests {
    @Test
    func bandsDistancesByWhatTheyMeanToAWalkingPerson() {
        #expect(ProximityBand.band(forMeters: 0.3) == .immediate)
        #expect(ProximityBand.band(forMeters: 1.0) == .near)
        #expect(ProximityBand.band(forMeters: 2.0) == .moderate)
        #expect(ProximityBand.band(forMeters: 5.0) == .distant)
    }

    @Test
    func treatsEachBoundaryAsTheStartOfTheFurtherBand() {
        // Pinned because a boundary that drifted by one band would change how
        // fast the phone buzzes at exactly the distances people walk at.
        #expect(ProximityBand.band(forMeters: 0.6) == .near)
        #expect(ProximityBand.band(forMeters: 1.2) == .moderate)
        #expect(ProximityBand.band(forMeters: 2.5) == .distant)
    }

    @Test
    func readsABogusDistanceAsDistantRatherThanAsTouchingTheUsersFace() {
        // These arrive only from a frame something already went wrong in. The
        // failure that matters is buzzing at maximum urgency because of one.
        #expect(ProximityBand.band(forMeters: .nan) == .distant)
        #expect(ProximityBand.band(forMeters: .infinity) == .distant)
        #expect(ProximityBand.band(forMeters: -1) == .distant)
        #expect(ProximityBand.band(forMeters: 0) == .distant)
    }

    @Test
    func ordersBandsNearestFirstSoMinIsTheNearest() {
        #expect(ProximityBand.immediate < ProximityBand.near)
        #expect(ProximityBand.near < ProximityBand.moderate)
        #expect(ProximityBand.moderate < ProximityBand.distant)
        #expect([ProximityBand.distant, .immediate, .moderate].min() == .immediate)
    }

    @Test
    func repeatsFasterTheNearerTheMeasurement() {
        // The cadence is what carries urgency on a channel that cannot carry
        // prose, so the ordering matters more than the exact numbers.
        let intervals = [ProximityBand.immediate, .near, .moderate].compactMap(\.repeatInterval)

        #expect(intervals.count == 3)
        #expect(intervals == intervals.sorted())
    }

    @Test
    func doesNotRepeatAtAllAtTheFurthestBand() {
        // Indoors there is always a wall three metres away, and a cue that never
        // stops is a cue that stops being noticed.
        #expect(ProximityBand.distant.repeatInterval == nil)
    }

    @Test
    func staysAtFourBandsSoTheHapticChannelDoesNotBecomeAVocabulary() {
        // A real deaf-blind haptic vocabulary needs co-design with deaf-blind
        // collaborators; growing this enum is not the way to get one.
        #expect(ProximityBand.allCases.count == 4)
    }
}
