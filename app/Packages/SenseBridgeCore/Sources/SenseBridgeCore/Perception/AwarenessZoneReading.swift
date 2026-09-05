import Foundation

/// Which part of what the user faces a measurement came from.
///
/// Three zones, not five. The phone is worn or held, the mount angle is
/// uncalibrated, and the depth map is reduced to one percentile per zone — that
/// chain earns "off to your left", and it does not earn "ten degrees left of
/// centre". Adding zones would make the output sound more precise without any
/// of the precision being real, which docs/SAFETY-FRAMING.md treats as the same
/// failure as naming an object wrongly.
///
/// Named in the user's frame of reference, not the camera's or the buffer's.
public enum AwarenessZone: String, Sendable, Equatable, CaseIterable {
    case leading, center, trailing
}

/// One depth reading per zone, and the reasoning over the three.
///
/// Pure values, deliberately free of ARKit and pixel buffers, so "which side is
/// nearest" and "is one side meaningfully nearer than the others" are verifiable
/// without a LiDAR device — the same split `DepthStatistics` uses, for the same
/// reason.
///
/// Every distance is optional, and `nil` carries the meaning it carries
/// everywhere else in this app: **this zone could not be measured**, never
/// "this zone is empty". A frame where only the left zone resolved says nothing
/// whatsoever about the right.
public struct AwarenessZoneReading: Sendable, Equatable {
    /// Distance in metres for the zone to the user's left, or `nil` when it
    /// could not be measured.
    public let leading: Double?
    /// Distance in metres straight ahead, or `nil` when it could not be measured.
    public let center: Double?
    /// Distance in metres for the zone to the user's right, or `nil` when it
    /// could not be measured.
    public let trailing: Double?

    /// Creates a reading. Every zone defaults to unmeasured.
    public init(leading: Double? = nil, center: Double? = nil, trailing: Double? = nil) {
        self.leading = leading
        self.center = center
        self.trailing = trailing
    }

    /// How much nearer one zone must be than the next-nearest before the
    /// difference is worth saying out loud, in metres.
    ///
    /// 0.4 m. Below that the two zones are within the noise of a percentile
    /// taken over a confidence-filtered region through an uncalibrated mount,
    /// and announcing a side would be reporting sensor jitter as a fact about
    /// the room — which on a continuously-narrating channel sounds like the
    /// obstacle is swinging from side to side.
    public static let sideSignificanceMeters = 0.4

    /// The distance in `zone`, or `nil` when it could not be measured.
    public func distance(in zone: AwarenessZone) -> Double? {
        switch zone {
        case .leading: leading
        case .center: center
        case .trailing: trailing
        }
    }

    /// Every zone that produced a measurement, paired with it.
    public var measured: [(zone: AwarenessZone, meters: Double)] {
        AwarenessZone.allCases.compactMap { zone in
            guard let meters = distance(in: zone), meters.isFinite, meters > 0 else { return nil }
            return (zone, meters)
        }
    }

    /// The nearest measured distance across all zones, or `nil` when no zone
    /// could be measured.
    ///
    /// This is what drives `AwarenessEngine`, unchanged: the alert threshold is
    /// about *how near the nearest thing is*, and direction is a detail added to
    /// the sentence afterwards rather than a second decision about whether to
    /// speak at all.
    public var nearestMeters: Double? {
        measured.map(\.meters).min()
    }

    /// The zone to name, or `nil` when naming one would overstate the reading.
    ///
    /// Returns a zone only when it is nearer than every other **measured** zone
    /// by at least ``sideSignificanceMeters``. Two consequences worth stating,
    /// because both are deliberate:
    ///
    /// - A single measured zone never names a side. One zone resolving while
    ///   the other two did not is a fact about the depth map, not about where
    ///   the obstacle is, and "on your left" would be inferred entirely from the
    ///   other two being unreadable.
    /// - A wall across the whole frame names no side either, correctly: three
    ///   similar distances mean nothing is off to one side.
    /// - **The centre must have been measured.** Naming a side while the
    ///   direction of travel is unreadable invites exactly the wrong inference:
    ///   a listener told "on your left" reasonably concludes the way in front is
    ///   comparatively free, and a glass door or a dark matte surface ahead is
    ///   precisely what returns no confident depth. The side is only meaningful
    ///   relative to a centre that was actually read.
    public var significantZone: AwarenessZone? {
        let readings = measured
        guard readings.contains(where: { $0.zone == .center }) else { return nil }
        guard readings.count > 1 else { return nil }
        let sorted = readings.sorted { $0.meters < $1.meters }
        guard let nearest = sorted.first, let runnerUp = sorted.dropFirst().first else { return nil }
        guard runnerUp.meters - nearest.meters >= Self.sideSignificanceMeters else { return nil }
        return nearest.zone
    }

    /// Whether no zone at all could be measured.
    ///
    /// Named for the measurement, not the world — a caller reaching for
    /// "isClear" here is about to write the one sentence this app never says.
    public var isUnmeasured: Bool {
        measured.isEmpty
    }
}
