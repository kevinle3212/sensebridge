import CoreGraphics
import Foundation
import Testing
@testable import SenseBridgeCore

/// Property tests over randomized depth input.
///
/// A real depth frame is 49k samples of hardware output, and the failures that
/// matter are not the ones a hand-written example finds — they are a NaN in one
/// pixel, a confidence map one entry short, a frame aimed at the floor. These
/// run each reduction over thousands of adversarial arrays and assert the two
/// invariants that must never break: the app never reports a distance it did not
/// measure, and it never turns an unreadable frame into a claim that the way is
/// clear.
///
/// Seeded rather than `Double.random`, so a failure reproduces exactly. Seeds
/// are fixed literals for the same reason.
struct DepthFuzzTests {
    /// A small deterministic PRNG, so a failing case is reproducible from its
    /// seed alone rather than only on the machine that happened to hit it.
    private struct Seeded: RandomNumberGenerator {
        private var state: UInt64

        init(seed: UInt64) {
            state = seed &* 6_364_136_223_846_793_005 &+ 1
        }

        mutating func next() -> UInt64 {
            state ^= state << 13
            state ^= state >> 7
            state ^= state << 17
            return state
        }
    }

    /// Values a real depth map has been seen to carry, including the ones that
    /// mean "this pixel failed" rather than a distance.
    private static let adversarialDepths: [Float] = [
        .nan, .infinity, -.infinity, .greatestFiniteMagnitude, .leastNonzeroMagnitude,
        0, -0, -1, -0.001, 0.001, 0.5, 1, 2.5, 10, 100
    ]

    /// One value from `items`, chosen by the seeded generator — `randomElement`
    /// returns an optional this file has no sensible answer for.
    private func pick<Element>(_ items: [Element], using generator: inout Seeded) -> Element {
        items[Int.random(in: 0 ..< items.count, using: &generator)]
    }

    /// One randomized sample set, with an independently randomized confidence
    /// map that is deliberately allowed to be shorter than the depths.
    private func randomSamples(using generator: inout Seeded) -> DepthSamples {
        let count = Int.random(in: 0 ... 64, using: &generator)
        let depths = (0 ..< count).map { _ in
            Bool.random(using: &generator)
                ? pick(Self.adversarialDepths, using: &generator)
                : Float.random(in: -5 ... 20, using: &generator)
        }
        // A truncated confidence map is a real upstream bug, and the reduction's
        // documented contract is to treat the missing tail as unusable.
        let confidenceCount = Int.random(in: 0 ... count, using: &generator)
        let confidences = (0 ..< confidenceCount).map { _ in UInt8.random(in: 0 ... 3, using: &generator) }
        let heights = Bool.random(using: &generator)
            ? (0 ..< Int.random(in: 0 ... count, using: &generator)).map { _ in
                Bool.random(using: &generator) ? Float.nan : Float.random(in: -3 ... 3, using: &generator)
            }
            : []
        return DepthSamples(depths: depths, confidences: confidences, heights: heights)
    }

    @Test
    func neverReportsADistanceThatIsNotAPositiveFiniteNumber() {
        // A NaN or a negative reaching the Reasoning layer would be spoken as a
        // distance and would band as `immediate` — the phone buzzing at maximum
        // urgency because of one bad pixel.
        var generator = Seeded(seed: 0xDEAD_BEEF)

        for _ in 0 ..< 2000 {
            let samples = randomSamples(using: &generator)
            guard let meters = DepthStatistics.nearestConfidentDepth(
                samples: samples.depths, confidences: samples.confidences, heights: samples.heights
            ) else { continue }
            #expect(meters.isFinite)
            #expect(meters > 0)
        }
    }

    @Test
    func onlyEverReportsADistanceThatWasActuallyInTheInput() {
        // The reduction picks a percentile, never interpolates. A reported
        // distance no pixel measured is a number the app invented.
        var generator = Seeded(seed: 0xC0FFEE)

        for _ in 0 ..< 2000 {
            let samples = randomSamples(using: &generator)
            guard let meters = DepthStatistics.nearestConfidentDepth(
                samples: samples.depths, confidences: samples.confidences, heights: samples.heights
            ) else { continue }
            #expect(samples.depths.contains { Double($0) == meters })
        }
    }

    @Test
    func aFrameWithNoConfidentSampleIsUnmeasuredRatherThanClear() {
        // The whole doctrine in one property: no confident pixel must produce
        // `nil` ("could not measure"), never a distance standing in for
        // "nothing is there". See docs/SAFETY-FRAMING.md.
        var generator = Seeded(seed: 0xFACE)

        for _ in 0 ..< 1000 {
            let count = Int.random(in: 0 ... 64, using: &generator)
            let depths = (0 ..< count).map { _ in Float.random(in: 0.1 ... 20, using: &generator) }
            let confidences = Array(repeating: UInt8.zero, count: count)

            let meters = DepthStatistics.nearestConfidentDepth(samples: depths, confidences: confidences)

            #expect(meters == nil)
        }
    }

    @Test
    func zoneReductionNeverInventsAZoneTheSamplesDidNotSupport() {
        var generator = Seeded(seed: 0xBEEF)

        for _ in 0 ..< 1000 {
            var samples = [AwarenessZone: DepthSamples]()
            for zone in AwarenessZone.allCases where Bool.random(using: &generator) {
                samples[zone] = randomSamples(using: &generator)
            }

            let reading = AwarenessZoneGeometry.reading(from: samples, floorClearanceMeters: 0.2)

            for zone in AwarenessZone.allCases where samples[zone] == nil {
                #expect(reading.zones.distance(in: zone) == nil)
            }
            for (zone, meters) in reading.zones.measured {
                #expect(meters.isFinite && meters > 0)
                #expect(samples[zone] != nil)
            }
        }
    }

    @Test
    func theOverallFigureAlwaysMatchesAWholeRegionWalkOfTheSamePixels() {
        // The alert decision runs on this number and always has. Zones must add
        // direction to the sentence without moving the threshold it crosses.
        var generator = Seeded(seed: 0xD00D)

        for _ in 0 ..< 1000 {
            var samples = [AwarenessZone: DepthSamples]()
            for zone in AwarenessZone.allCases {
                samples[zone] = randomSamples(using: &generator)
            }
            var union = DepthSamples()
            for zone in AwarenessZone.allCases {
                guard let set = samples[zone] else { continue }
                union.depths += set.depths
                union.confidences += set.confidences
                union.heights += set.heights
            }

            let reading = AwarenessZoneGeometry.reading(from: samples, floorClearanceMeters: 0.2)
            let wholeRegion = DepthStatistics.nearestConfidentDepth(
                samples: union.depths, confidences: union.confidences, heights: union.heights,
                floorClearanceMeters: 0.2
            )

            #expect(reading.overallMeters == wholeRegion)
        }
    }

    @Test
    func bandingNeverTrapsAndNeverOverstatesUrgencyForABogusReading() {
        var generator = Seeded(seed: 0xABBA)

        for _ in 0 ..< 5000 {
            let meters = Bool.random(using: &generator)
                ? Double(pick(Self.adversarialDepths, using: &generator))
                : Double.random(in: -100 ... 100, using: &generator)

            let band = ProximityBand.band(forMeters: meters)

            if !meters.isFinite || meters <= 0 {
                #expect(band == .distant)
                #expect(band.repeatInterval == nil)
            } else if band == .immediate {
                #expect(meters < 0.6)
            }
        }
    }

    @Test
    func namingASideAlwaysMeansThatSideWasMeasuredAndIsTheNearest() {
        var generator = Seeded(seed: 0x1DEA)

        for _ in 0 ..< 5000 {
            func maybeDistance() -> Double? {
                Bool.random(using: &generator)
                    ? nil
                    : Double.random(in: -2 ... 12, using: &generator)
            }
            let reading = AwarenessZoneReading(
                leading: maybeDistance(), center: maybeDistance(), trailing: maybeDistance()
            )

            guard let zone = reading.significantZone else { continue }
            #expect(reading.distance(in: zone) != nil)
            #expect(reading.distance(in: zone) == reading.nearestMeters)
            // Never named off a single resolved zone: that would be an inference
            // from the other two being unreadable, not from where anything is.
            #expect(reading.measured.count > 1)
        }
    }
}
