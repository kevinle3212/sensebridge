import Foundation

/// One frame's depth reduced two ways: overall, and per zone.
///
/// The overall figure is what `AwarenessEngine` has always been fed, and it must
/// keep meaning exactly what it meant before directions existed — a low
/// percentile over the whole region of interest — or adding direction would
/// quietly change how often the app alerts at all. The per-zone figures only
/// ever *qualify* an alert that the overall figure already decided to raise.
///
/// ## The two regions are deliberately different sizes
///
/// The distance is measured over `AmbientSensingSource.regionOfInterest`, which
/// trims the across-axis to the middle half. Zones are cut from the full width —
/// see `AwarenessZoneGeometry.zoneRegion(measuring:)` for why an 8°-wide zone
/// could not honestly be called "your left".
///
/// That difference is what ``namedZone`` exists to police. Because a side zone
/// now reaches into periphery the distance never looked at, the nearest zone is
/// no longer guaranteed to be the thing that triggered the alert — and naming a
/// side that describes a *different* object than the sentence's distance is
/// exactly the confidently-wrong claim docs/SAFETY-FRAMING.md exists to prevent.
public struct AwarenessDepthReading: Sendable, Equatable {
    /// The distance the alert decision is made from, or `nil` when the frame
    /// carried no usable measurement — never "nothing is ahead".
    public let overallMeters: Double?
    /// The same frame split into left, centre, and right.
    public let zones: AwarenessZoneReading

    /// Creates a reading.
    public init(overallMeters: Double?, zones: AwarenessZoneReading) {
        self.overallMeters = overallMeters
        self.zones = zones
    }

    /// An unmeasurable frame — every zone and the overall figure alike.
    public static let unmeasured: AwarenessDepthReading = .init(overallMeters: nil, zones: AwarenessZoneReading())

    /// How far a zone's distance may sit from the overall distance and still be
    /// treated as describing the same thing, in metres.
    ///
    /// The two reductions run over different regions and take a percentile
    /// each, so even the same object measures a little differently in the two.
    /// This is that slack and nothing more — wide enough to survive the
    /// percentile, narrow enough that a lamp post in the periphery cannot pass
    /// itself off as the wall the sentence is about.
    public static let zoneAgreementMeters = 0.5

    /// The side to name, or `nil` when naming one would describe something other
    /// than what the alert is about.
    ///
    /// This is the property callers should use — never ``zones`` directly.
    /// `AwarenessZoneReading.significantZone` answers "is one zone clearly
    /// nearer than the others", which is necessary and not sufficient: the zone
    /// also has to be the thing the spoken distance came from. A bollard 8° off
    /// to the side, outside the measured region entirely, satisfies the first
    /// test and fails this one.
    public var namedZone: AwarenessZone? {
        guard let overallMeters, let zone = zones.significantZone else { return nil }
        guard let meters = zones.distance(in: zone) else { return nil }
        guard abs(meters - overallMeters) <= Self.zoneAgreementMeters else { return nil }
        return zone
    }
}
