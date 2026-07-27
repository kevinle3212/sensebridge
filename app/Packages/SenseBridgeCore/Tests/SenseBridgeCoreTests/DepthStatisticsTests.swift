import Testing
@testable import SenseBridgeCore

struct DepthStatisticsTests {
    @Test
    func reportsNilWhenNoSampleIsConfidentEnough() {
        let depth = DepthStatistics.nearestConfidentDepth(
            samples: [1.0, 1.2, 0.9],
            confidences: [0, 0, 0]
        )

        // `nil` is "this frame could not be measured", never "nothing is
        // ahead" — see docs/SAFETY-FRAMING.md on asserting absence.
        #expect(depth == nil)
    }

    @Test
    func ignoresLowConfidenceSamplesEvenWhenTheyAreNearest() {
        let depth = DepthStatistics.nearestConfidentDepth(
            samples: [0.2, 3.0, 3.0, 3.0],
            confidences: [0, 2, 2, 2],
            percentile: 0
        )

        #expect(depth == 3.0)
    }

    @Test
    func discardsZeroAndNonFiniteSamplesArkitWritesForUnresolvedPixels() {
        let depth = DepthStatistics.nearestConfidentDepth(
            samples: [0, .nan, .infinity, -1, 2.5],
            confidences: [2, 2, 2, 2, 2],
            percentile: 0
        )

        #expect(depth == 2.5)
    }

    @Test
    func percentileRejectsAStrayNearPixelRatherThanAlertingOnIt() {
        // One speck at 10 cm against a wall two metres away. Taking the strict
        // minimum would speak an alert about a dust mote; the 5th percentile
        // ignores it.
        var samples = Array(repeating: Float(2.0), count: 99)
        samples.insert(0.1, at: 0)
        let confidences = Array(repeating: UInt8(2), count: 100)

        let depth = DepthStatistics.nearestConfidentDepth(samples: samples, confidences: confidences)

        #expect(depth == 2.0)
    }

    @Test
    func percentileStillReportsAGenuinelyNearSurface() {
        // A real object fills a large share of the region rather than one
        // pixel, so outlier rejection must not swallow it.
        //
        // 0.75 rather than 0.8 because the samples are `Float` and the result
        // is `Double`: widening 0.8 yields 0.800000011920929, so an equality
        // assertion on it fails for reasons that have nothing to do with the
        // logic under test. 0.75 is exactly representable in both.
        let samples = Array(repeating: Float(0.75), count: 100)
        let confidences = Array(repeating: UInt8(2), count: 100)

        let depth = DepthStatistics.nearestConfidentDepth(samples: samples, confidences: confidences)

        #expect(depth == 0.75)
    }

    @Test
    func treatsATruncatedConfidenceMapAsUnusableRatherThanTrusted() {
        // A short confidence array is an upstream bug. Guessing optimistically
        // would surface it as a confident distance rather than as silence.
        let depth = DepthStatistics.nearestConfidentDepth(
            samples: [3.0, 0.5, 0.4],
            confidences: [2],
            percentile: 0
        )

        #expect(depth == 3.0)
    }

    @Test
    func handlesAnEmptyFrame() {
        #expect(DepthStatistics.nearestConfidentDepth(samples: [], confidences: []) == nil)
    }

    @Test
    func rejectsTheFloorAndReportsTheObstacleBehindIt() {
        // The chest-mount failure this exists to prevent: floor 1 m ahead is
        // nearer than the wall 3 m ahead, so without height information the
        // channel would announce an obstacle continuously, everywhere, forever.
        let samples = Array(repeating: Float(1.0), count: 90) + Array(repeating: Float(3.0), count: 10)
        let heights = Array(repeating: Float(-1.35), count: 90) + Array(repeating: Float(-0.2), count: 10)
        let confidences = Array(repeating: UInt8(2), count: 100)

        let depth = DepthStatistics.nearestConfidentDepth(
            samples: samples, confidences: confidences, heights: heights
        )

        #expect(depth == 3.0)
    }

    @Test
    func keepsAnObjectRestingOnTheFloor() {
        // A 30 cm box stands proud of the ground plane, so it must survive the
        // same filter that discards the ground it is sitting on. Rejecting a
        // whole band above the floor instead would hide exactly the obstacles
        // a walking user trips over.
        let samples = Array(repeating: Float(4.0), count: 90) + Array(repeating: Float(1.5), count: 10)
        let heights = Array(repeating: Float(-1.35), count: 90) + Array(repeating: Float(-1.05), count: 10)
        let confidences = Array(repeating: UInt8(2), count: 100)

        let depth = DepthStatistics.nearestConfidentDepth(
            samples: samples, confidences: confidences, heights: heights
        )

        #expect(depth == 1.5)
    }

    @Test
    func reportsNilWhenEverythingInViewIsGround() {
        // Aimed at the floor. There is no obstacle measurement in this frame,
        // and "could not measure" is the honest answer — reporting the floor's
        // own distance would be a confident claim about nothing.
        let samples = Array(repeating: Float(1.2), count: 50)
        let heights = Array(repeating: Float(-1.3), count: 50)
        let confidences = Array(repeating: UInt8(2), count: 50)

        let depth = DepthStatistics.nearestConfidentDepth(
            samples: samples, confidences: confidences, heights: heights
        )

        #expect(depth == nil)
    }

    @Test
    func discardsSamplesWhoseHeightCouldNotBeComputed() {
        // `DepthGeometry` returns `nan` for a sample with no usable geometry.
        // Exempting those from floor rejection would let precisely the broken
        // samples bypass the check that catches the floor.
        // The stray 30 cm reading is what an exemption would surface as an
        // alert, so the frame around it has to be otherwise measurable for the
        // assertion to mean anything.
        let samples = [0.3] + Array(repeating: Float(1.0), count: 90) + Array(repeating: Float(3.0), count: 10)
        let heights = [Float.nan] + Array(repeating: Float(-1.35), count: 90)
            + Array(repeating: Float(-0.2), count: 10)
        let confidences = Array(repeating: UInt8(2), count: 101)

        let depth = DepthStatistics.nearestConfidentDepth(
            samples: samples, confidences: confidences, heights: heights
        )

        #expect(depth == 3.0)
    }

    @Test
    func raisingTheClearanceDiscardsAnObstacleWithLessHeadroom() {
        // Sanity check on the cutoff itself: raising clearance above the
        // obstacle's headroom must discard it, or the knob does nothing.
        let samples = Array(repeating: Float(1.0), count: 90) + Array(repeating: Float(3.0), count: 10)
        let heights = Array(repeating: Float(-1.35), count: 90) + Array(repeating: Float(-1.05), count: 10)
        let confidences = Array(repeating: UInt8(2), count: 100)

        let generous = DepthStatistics.nearestConfidentDepth(
            samples: samples, confidences: confidences, heights: heights, floorClearanceMeters: 0.2
        )
        let strict = DepthStatistics.nearestConfidentDepth(
            samples: samples, confidences: confidences, heights: heights, floorClearanceMeters: 0.5
        )

        #expect(generous == 3.0)
        #expect(strict == nil)
    }

    @Test
    func clampsAnOutOfRangePercentile() {
        let samples: [Float] = [1.0, 2.0, 3.0, 4.0]
        let confidences = Array(repeating: UInt8(2), count: 4)

        #expect(DepthStatistics.nearestConfidentDepth(
            samples: samples, confidences: confidences, percentile: -5
        ) == 1.0)
        #expect(DepthStatistics.nearestConfidentDepth(
            samples: samples, confidences: confidences, percentile: 5
        ) == 4.0)
    }
}
