import CoreGraphics
import Foundation

/// Splitting a depth region into left, centre, and right, and reducing each.
///
/// Deliberately free of ARKit, like `DepthStatistics` and `DepthGeometry` beside
/// it, and for the same reason: `AmbientSensingSource` does not exist on any
/// platform `swift test` runs on, so anything left inside it is verifiable only
/// by holding a LiDAR iPhone. The parts with real decisions in them — which
/// third of the buffer is the user's left, and whether the overall figure still
/// matches what the whole-region walk produced — belong out here where a test
/// can reach them.
public enum AwarenessZoneGeometry {
    /// The region the three zones are cut from, given the region the *distance*
    /// is measured in.
    ///
    /// ## Why this is wider than the region of interest
    ///
    /// `AmbientSensingSource.regionOfInterest` trims the across-axis to the
    /// middle half deliberately: the distance it feeds is "how near is the thing
    /// in front of me", and periphery does not belong in that answer. Cutting
    /// *zones* from that same trimmed strip, though, made each zone about a
    /// third of half the sensor's ~48° across-FOV — roughly 8° — so "on your
    /// left" was really claiming "between about 4 and 12 degrees left of
    /// wherever the camera happens to be pointing".
    ///
    /// That is a claim the hardware cannot support. The mount is uncalibrated —
    /// a chest strap re-tightened each morning yaws by more than 8°, which is a
    /// whole zone — so a door frame genuinely straight ahead could land in the
    /// right-hand third and be announced as being on the user's right. Sending
    /// someone the wrong way is the worst outcome in this file's remit.
    ///
    /// Widening the across-axis to its full extent makes each zone about 16°,
    /// with the sides beginning 8° off-centre. A few degrees of mount yaw no
    /// longer moves a measurement between zones. It does not make the mount
    /// calibrated, and the residual error is on the device-validation list in
    /// docs/TESTING.md — but the claim now sits inside what the geometry earns.
    ///
    /// The measuring region is left exactly as it was, so the alert threshold is
    /// untouched by any of this.
    public static func zoneRegion(measuring region: CGRect) -> CGRect {
        CGRect(x: region.minX, y: 0, width: region.width, height: 1)
    }

    /// The three zone sub-rectangles of `region`, split across its raw `y` axis.
    ///
    /// ## Which end of the buffer is the user's left
    ///
    /// ARKit hands back the camera's native landscape image and this app is
    /// portrait, so the axes are transposed — the fact
    /// `AmbientSensingSource.regionOfInterest` documents: raw `x` runs
    /// top-to-bottom of what the user faces, and raw `y` runs across it.
    ///
    /// Which way across is the question this function answers. Frames carry
    /// `CGImagePropertyOrientation.right`, which means the encoded image's 0th
    /// row appears on the **right** of the upright view. So a low raw `y` is the
    /// user's right, and a high raw `y` is their left — hence the returned order.
    ///
    /// This is the one assumption here that arithmetic cannot self-check, and
    /// getting it backwards would confidently send someone the wrong way. It is
    /// pinned by `AwarenessZoneGeometryTests`, but a test cannot prove the
    /// orientation constant matches the hardware; that is on the
    /// device-validation list in docs/TESTING.md, because no simulator produces
    /// a real depth frame.
    ///
    /// Equal thirds rather than a wide centre and narrow sides: a listener told
    /// "on your left" is being told which way to turn their head, and a centre
    /// zone wide enough to swallow most of the frame would leave the side zones
    /// firing only for things already out of the way.
    public static func regions(in region: CGRect) -> [(zone: AwarenessZone, rect: CGRect)] {
        let third = region.height / 3
        return [
            (.trailing, CGRect(x: region.minX, y: region.minY, width: region.width, height: third)),
            (.center, CGRect(x: region.minX, y: region.minY + third, width: region.width, height: third)),
            (.leading, CGRect(x: region.minX, y: region.minY + 2 * third, width: region.width, height: third))
        ]
    }

    /// Reduces per-zone sample sets to distances, plus their union to the
    /// overall distance.
    ///
    /// The union is the **concatenation** of the three zones and nothing else,
    /// which is what makes the overall figure identical to the one a
    /// whole-region walk produces — see `AwarenessDepthReading` on why that
    /// identity is load-bearing rather than a nicety.
    ///
    /// - Parameters:
    ///   - samples: One sample set per zone. A missing zone is treated as
    ///     unmeasured rather than empty, which are different claims.
    ///   - floorClearanceMeters: Passed straight through to
    ///     `DepthStatistics.nearestConfidentDepth`.
    public static func reading(
        from samples: [AwarenessZone: DepthSamples],
        overall: DepthSamples? = nil,
        floorClearanceMeters: Float
    ) -> AwarenessDepthReading {
        var union = DepthSamples()
        for zone in AwarenessZone.allCases {
            guard let set = samples[zone] else { continue }
            union.depths += set.depths
            union.confidences += set.confidences
            union.heights += set.heights
        }
        // `overall` when the caller measured the distance over its own region —
        // which it does, because the zones are now cut from a wider strip than
        // the distance is measured in. Falling back to the union keeps the
        // simpler contract for callers that pass zones covering exactly the
        // measured region, which is what the tests exercise.
        return AwarenessDepthReading(
            overallMeters: distance(in: overall ?? union, floorClearanceMeters: floorClearanceMeters),
            zones: AwarenessZoneReading(
                leading: distance(in: samples[.leading], floorClearanceMeters: floorClearanceMeters),
                center: distance(in: samples[.center], floorClearanceMeters: floorClearanceMeters),
                trailing: distance(in: samples[.trailing], floorClearanceMeters: floorClearanceMeters)
            )
        )
    }

    /// One sample set's reported distance, or `nil` when it carried no usable
    /// measurement — which, as everywhere else here, means "could not be
    /// measured" and never "nothing is there".
    private static func distance(in samples: DepthSamples?, floorClearanceMeters: Float) -> Double? {
        guard let samples else { return nil }
        return DepthStatistics.nearestConfidentDepth(
            samples: samples.depths,
            confidences: samples.confidences,
            heights: samples.heights,
            floorClearanceMeters: floorClearanceMeters
        )
    }
}
