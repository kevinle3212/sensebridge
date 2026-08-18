import CoreGraphics
import Foundation
import Testing
@testable import SenseBridgeCore

struct AwarenessZoneGeometryTests {
    /// Confident samples at one distance, with no heights so floor rejection
    /// stays out of the way of what these tests are actually about.
    private func samples(_ meters: Float, count: Int = 20) -> DepthSamples {
        DepthSamples(
            depths: Array(repeating: meters, count: count),
            confidences: Array(repeating: DepthStatistics.mediumConfidence, count: count)
        )
    }

    @Test
    func splitsTheRegionIntoThreeEqualThirdsThatCoverItExactly() {
        let region = CGRect(x: 0.1, y: 0.2, width: 0.6, height: 0.6)

        let regions = AwarenessZoneGeometry.regions(in: region)

        #expect(regions.count == 3)
        #expect(regions.allSatisfy { abs($0.rect.height - 0.2) < 0.0001 })
        #expect(regions.allSatisfy { $0.rect.minX == region.minX && $0.rect.width == region.width })
        #expect(abs(regions.map(\.rect.height).reduce(into: 0) { $0 += $1 } - region.height) < 0.0001)
    }

    @Test
    func leavesNoGapOrOverlapBetweenAdjacentZones() {
        // The overall distance is the concatenation of these three sample sets,
        // so a gap would silently drop pixels the whole-region walk measured and
        // an overlap would weight them twice.
        let sorted = AwarenessZoneGeometry.regions(in: CGRect(x: 0, y: 0, width: 1, height: 0.9))
            .map(\.rect)
            .sorted { $0.minY < $1.minY }

        #expect(abs(sorted[0].maxY - sorted[1].minY) < 0.0001)
        #expect(abs(sorted[1].maxY - sorted[2].minY) < 0.0001)
    }

    @Test
    func mapsTheLowRawAxisToTheUsersRightAndTheHighOneToTheirLeft() throws {
        // Frames carry `CGImagePropertyOrientation.right`, whose 0th row appears
        // on the right of the upright view. Getting this backwards would
        // confidently send someone the wrong way, so it is pinned here — though
        // only a device can prove the orientation constant matches the hardware.
        let regions = AwarenessZoneGeometry.regions(in: CGRect(x: 0, y: 0, width: 1, height: 1))
        let byZone = Dictionary(uniqueKeysWithValues: regions.map { ($0.zone, $0.rect) })
        let right = try #require(byZone[.trailing])
        let ahead = try #require(byZone[.center])
        let left = try #require(byZone[.leading])

        #expect(right.minY < ahead.minY)
        #expect(ahead.minY < left.minY)
    }

    @Test
    func cutsZonesFromTheFullWidthRatherThanTheTrimmedMeasuringRegion() {
        // The region of interest keeps only the middle half of the across-axis,
        // so thirds of *it* spanned about 8° — less than the yaw of a chest
        // strap re-tightened each morning. "On your left" cannot mean a cone
        // narrower than the mount's own error.
        let measuring = CGRect(x: 0, y: 0.25, width: 1.0, height: 0.5)

        let zoneRegion = AwarenessZoneGeometry.zoneRegion(measuring: measuring)

        #expect(zoneRegion.height == 1.0)
        #expect(zoneRegion.minY == 0)
        // The along-axis is untouched: this widens where zones look across, not
        // how far up and down the frame they reach.
        #expect(zoneRegion.minX == measuring.minX)
        #expect(zoneRegion.width == measuring.width)
        // Each zone is now a third of the whole width, not a third of a half.
        let widths = AwarenessZoneGeometry.regions(in: zoneRegion).map(\.rect.height)
        #expect(widths.allSatisfy { abs($0 - 1.0 / 3) < 0.0001 })
    }

    @Test
    func namesNoSideWhenTheNearestZoneIsNotWhatTheDistanceMeasured() {
        // A bollard in the periphery can be the nearest *zone* while the spoken
        // distance came from a wall dead ahead. Naming a side there would
        // attach a direction to a different object than the sentence is about.
        let reading = AwarenessDepthReading(
            overallMeters: 3.0,
            zones: AwarenessZoneReading(leading: 0.8, center: 3.0, trailing: 3.1)
        )

        #expect(reading.zones.significantZone == .leading)
        #expect(reading.namedZone == nil)
    }

    @Test
    func namesTheSideWhenItAgreesWithTheDistanceBeingSpoken() {
        let reading = AwarenessDepthReading(
            overallMeters: 1.0,
            zones: AwarenessZoneReading(leading: 1.1, center: 2.0, trailing: 2.4)
        )

        #expect(reading.namedZone == .leading)
    }

    @Test
    func namesNoSideWhenTheFrameCouldNotBeMeasuredOverall() {
        let reading = AwarenessDepthReading(
            overallMeters: nil,
            zones: AwarenessZoneReading(leading: 0.5, center: 2.0, trailing: 2.2)
        )

        #expect(reading.namedZone == nil)
    }

    @Test
    func reducesEachZoneToItsOwnDistance() {
        let reading = AwarenessZoneGeometry.reading(
            from: [.leading: samples(1.0), .center: samples(2.0), .trailing: samples(3.0)],
            floorClearanceMeters: 0.2
        )

        #expect(reading.zones.leading == 1.0)
        #expect(reading.zones.center == 2.0)
        #expect(reading.zones.trailing == 3.0)
    }

    @Test
    func reportsTheOverallDistanceFromTheUnionOfEveryZone() {
        // Load-bearing: the alert decision has always run on a whole-region
        // walk, and adding zones must not move the number it acts on.
        let zoned = AwarenessZoneGeometry.reading(
            from: [.leading: samples(1.0), .center: samples(2.0), .trailing: samples(3.0)],
            floorClearanceMeters: 0.2
        )
        let wholeRegion = DepthStatistics.nearestConfidentDepth(
            samples: samples(1.0).depths + samples(2.0).depths + samples(3.0).depths,
            confidences: samples(1.0, count: 60).confidences,
            floorClearanceMeters: 0.2
        )

        #expect(zoned.overallMeters == wholeRegion)
    }

    @Test
    func treatsAMissingZoneAsUnmeasuredRatherThanEmpty() {
        let reading = AwarenessZoneGeometry.reading(from: [.center: samples(1.5)], floorClearanceMeters: 0.2)

        #expect(reading.zones.leading == nil)
        #expect(reading.zones.trailing == nil)
        #expect(reading.overallMeters == 1.5)
    }

    @Test
    func reportsNothingMeasurableWhenNoZoneCarriedAUsableSample() {
        let reading = AwarenessZoneGeometry.reading(from: [:], floorClearanceMeters: 0.2)

        #expect(reading.overallMeters == nil)
        #expect(reading.zones.isUnmeasured)
    }

    @Test
    func dropsZeroAndNonFiniteSamplesInsteadOfReadingThemAsTouchingTheLens() {
        let broken = DepthSamples(
            depths: [0, .nan, .infinity, -1],
            confidences: Array(repeating: DepthStatistics.mediumConfidence, count: 4)
        )

        let reading = AwarenessZoneGeometry.reading(from: [.center: broken], floorClearanceMeters: 0.2)

        #expect(reading.zones.center == nil)
        #expect(reading.overallMeters == nil)
    }

    @Test
    func dropsSamplesWhoseConfidenceEntryIsMissingRatherThanTrustingThem() {
        // A truncated confidence map is a bug upstream, and guessing optimistically
        // here would surface it as a false distance rather than as silence.
        let truncated = DepthSamples(depths: [1.0, 1.0, 1.0], confidences: [])

        let reading = AwarenessZoneGeometry.reading(from: [.center: truncated], floorClearanceMeters: 0.2)

        #expect(reading.zones.center == nil)
    }
}
