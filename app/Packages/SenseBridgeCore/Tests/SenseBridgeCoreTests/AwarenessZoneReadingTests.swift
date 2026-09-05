import Foundation
import Testing
@testable import SenseBridgeCore

struct AwarenessZoneReadingTests {
    @Test
    func reportsEveryZoneThatProducedAMeasurement() {
        let reading = AwarenessZoneReading(leading: 1.0, center: nil, trailing: 2.0)

        #expect(reading.measured.map(\.zone) == [.leading, .trailing])
        #expect(reading.distance(in: .center) == nil)
        #expect(!reading.isUnmeasured)
    }

    @Test
    func treatsAZoneThatCouldNotBeMeasuredAsUnknownRatherThanEmpty() {
        // The one sentence this app never says. A frame where nothing resolved
        // says nothing whatsoever about what is ahead.
        let reading = AwarenessZoneReading()

        #expect(reading.isUnmeasured)
        #expect(reading.nearestMeters == nil)
        #expect(reading.significantZone == nil)
    }

    @Test
    func discardsBogusDistancesRatherThanReportingThem() {
        let reading = AwarenessZoneReading(leading: .nan, center: -3, trailing: 0)

        #expect(reading.isUnmeasured)
        #expect(reading.nearestMeters == nil)
    }

    @Test
    func reportsTheNearestMeasuredDistanceAcrossZones() {
        let reading = AwarenessZoneReading(leading: 2.4, center: 0.9, trailing: 1.7)

        #expect(reading.nearestMeters == 0.9)
    }

    @Test
    func namesASideOnlyWhenItIsClearlyNearerThanTheRest() {
        let reading = AwarenessZoneReading(leading: 0.8, center: 2.0, trailing: 2.4)

        #expect(reading.significantZone == .leading)
    }

    @Test
    func namesNoSideWhenTheZonesAreWithinSensorNoiseOfEachOther() {
        // Announcing a side here would report jitter as a fact about the room,
        // which on a narrating channel sounds like the obstacle is swinging
        // from side to side.
        let reading = AwarenessZoneReading(leading: 1.0, center: 1.2, trailing: 1.3)

        #expect(reading.significantZone == nil)
    }

    @Test
    func namesNoSideForAWallAcrossTheWholeFrame() {
        let wall = AwarenessZoneReading(leading: 1.5, center: 1.5, trailing: 1.5)

        #expect(wall.significantZone == nil)
        #expect(wall.nearestMeters == 1.5)
    }

    @Test
    func namesNoSideWhenOnlyOneZoneResolved() {
        // "On your left" would be inferred entirely from the other two zones
        // being unreadable — a fact about the depth map, not about the room.
        let reading = AwarenessZoneReading(leading: 0.5)

        #expect(reading.measured.count == 1)
        #expect(reading.significantZone == nil)
    }

    @Test
    func treatsTheSignificanceGapAsInclusive() {
        // 0.9 − 0.5 is exactly the stored `Double` 0.4, so this really does sit
        // on the boundary rather than a hair either side of it.
        #expect(AwarenessZoneReading.sideSignificanceMeters == 0.9 - 0.5)
        #expect(AwarenessZoneReading(center: 0.5, trailing: 0.9).significantZone == .center)
        #expect(AwarenessZoneReading(center: 0.5, trailing: 0.89).significantZone == nil)
    }

    @Test
    func namesNoSideWhileTheDirectionOfTravelIsUnmeasured() {
        // A listener told "on your left" reasonably concludes the way in front
        // is comparatively free. A glass door or a dark matte surface straight
        // ahead is exactly what returns no confident depth, so the side is only
        // meaningful relative to a centre that was actually read.
        let reading = AwarenessZoneReading(leading: 1.0, center: nil, trailing: 5.0)

        #expect(reading.measured.count == 2)
        #expect(reading.significantZone == nil)
        // The nearest figure still stands — that measurement was real, and it is
        // what the alert threshold acts on.
        #expect(reading.nearestMeters == 1.0)
    }

    @Test
    func comparesAgainstTheRunnerUpRatherThanTheFurthestZone() {
        // Two zones close together and one far away is not a side: the
        // obstacle spans both near zones.
        let reading = AwarenessZoneReading(leading: 1.0, center: 1.1, trailing: 4.0)

        #expect(reading.significantZone == nil)
    }
}
