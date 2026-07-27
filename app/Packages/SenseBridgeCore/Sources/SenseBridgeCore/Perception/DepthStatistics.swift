import Foundation

/// One region of a depth frame, copied out of its pixel buffers into plain
/// arrays so the reduction over it stays pure and testable.
///
/// The three arrays are parallel and index-aligned; nothing here enforces that,
/// because the only producer is the pixel-buffer walk in `AmbientSensingSource`
/// and a check per sample would cost more than the walk itself.
public struct DepthSamples: Sendable, Equatable {
    /// Per-pixel distances in metres.
    public var depths: [Float]
    /// Per-pixel `ARConfidenceLevel` raw values.
    public var confidences: [UInt8]
    /// Per-pixel height relative to the camera along gravity. Empty when the
    /// frame carried no usable camera geometry, which disables floor rejection
    /// rather than guessing at it.
    public var heights: [Float]

    public init(depths: [Float] = [], confidences: [UInt8] = [], heights: [Float] = []) {
        self.depths = depths
        self.confidences = confidences
        self.heights = heights
    }
}

/// Reduces a frame of depth samples to the one distance the Reasoning layer
/// acts on.
///
/// Kept as pure functions over plain arrays, deliberately separate from the
/// `CVPixelBuffer` walk in `AmbientSensingSource`: this is the part with real
/// logic in it (outlier rejection, confidence filtering), and it is the part
/// that has to be verifiable without a LiDAR device attached.
public enum DepthStatistics {
    /// ARKit's `ARConfidenceLevel` raw values, restated as plain integers so
    /// this file stays free of ARKit and testable on any platform.
    /// `low = 0`, `medium = 1`, `high = 2`.
    public static let mediumConfidence: UInt8 = 1

    /// The distance to report for a frame, or `nil` when the frame carries no
    /// usable sample.
    ///
    /// Returns a low **percentile** of the confident samples rather than the
    /// strict minimum. The minimum of a 49k-sample LiDAR frame is routinely a
    /// single stray pixel — a speck of dust, a specular highlight, a depth
    /// discontinuity at an object edge — and letting one such pixel drive a
    /// spoken alert produces exactly the confidently-wrong physical-world
    /// claim docs/SAFETY-FRAMING.md treats as the worst bug in this project.
    ///
    /// - Parameters:
    ///   - samples: Per-pixel distances in metres, in any order.
    ///   - confidences: Per-pixel confidence, parallel to `samples`. A shorter
    ///     array than `samples` treats the missing tail as unusable rather
    ///     than trusting it.
    ///   - heights: Per-pixel height relative to the camera along gravity,
    ///     parallel to `samples` — see `DepthGeometry`. Supplying it enables
    ///     floor rejection; empty measures every sample, which is only correct
    ///     for a handheld frame the user has deliberately aimed.
    ///   - floorClearanceMeters: How far above the lowest surface in view a
    ///     sample must sit to count as an obstacle rather than as ground.
    ///   - minimumConfidence: Samples below this are discarded entirely.
    ///   - percentile: Which quantile of the surviving samples to report,
    ///     `0` being the nearest. The default rejects the nearest 5%.
    /// - Returns: The reported distance in metres, or `nil` if no sample
    ///   survived filtering — which means "this frame could not be measured",
    ///   never "nothing is ahead".
    public static func nearestConfidentDepth(
        samples: [Float],
        confidences: [UInt8],
        heights: [Float] = [],
        floorClearanceMeters: Float = 0.2,
        minimumConfidence: UInt8 = mediumConfidence,
        percentile: Double = 0.05
    ) -> Double? {
        let measuringHeights = !heights.isEmpty
        var usableDepths = [Float]()
        var usableHeights = [Float]()
        usableDepths.reserveCapacity(samples.count)
        for (index, sample) in samples.enumerated() {
            // A missing confidence entry is treated as unusable, not as
            // implicitly confident — a truncated confidence map is a bug
            // somewhere upstream, and guessing in the optimistic direction
            // here would surface it as a false distance rather than silence.
            guard index < confidences.count, confidences[index] >= minimumConfidence else { continue }
            // ARKit writes 0 and non-finite values for pixels it could not
            // resolve; both would otherwise read as "touching the lens".
            guard sample.isFinite, sample > 0 else { continue }
            if measuringHeights {
                // A sample whose height could not be computed is dropped rather
                // than exempted from floor rejection. Exempting it would let
                // precisely the samples with broken geometry bypass the check
                // that exists to catch the floor.
                guard index < heights.count, heights[index].isFinite else { continue }
                usableHeights.append(heights[index])
            }
            usableDepths.append(sample)
        }
        guard !usableDepths.isEmpty else { return nil }

        let candidates = usableHeights.isEmpty
            ? usableDepths
            : aboveFloor(depths: usableDepths, heights: usableHeights, clearance: floorClearanceMeters)
        // Empty here means every surface in view was ground — the phone is
        // aimed at the floor, or the user is facing a downward slope. That is a
        // frame with no obstacle measurement in it, not a frame proving the way
        // is clear, so it takes the same `nil` path as an unreadable frame.
        guard !candidates.isEmpty else { return nil }

        return Double(quantile(candidates.sorted(), percentile))
    }

    /// Discards the samples that belong to the ground plane.
    ///
    /// The floor's height is taken from the frame itself — a low quantile of
    /// the heights in view — rather than from a configured mount height, so it
    /// needs no calibration and follows the user onto a ramp, a kerb, or a
    /// staircase. A quantile rather than the strict lowest sample, for the same
    /// outlier reason the distance reduction uses one.
    ///
    /// Note this keeps objects *resting* on the floor: a box 30 cm high stands
    /// above the ground plane by more than the clearance, so it survives, while
    /// the floor stretching away beneath it does not.
    private static func aboveFloor(depths: [Float], heights: [Float], clearance: Float) -> [Float] {
        let floorHeight = quantile(heights.sorted(), 0.05)
        let cutoff = floorHeight + clearance
        return zip(depths, heights).lazy.filter { $0.1 >= cutoff }.map(\.0)
    }

    /// The value at `fraction` through an already-sorted array.
    ///
    /// - Parameter fraction: Clamped into `0...1`, so a caller's bad input
    ///   yields the nearest or furthest sample rather than trapping on an
    ///   out-of-bounds index mid-walk.
    private static func quantile(_ sorted: [Float], _ fraction: Double) -> Float {
        let clamped = min(max(fraction, 0), 1)
        let index = min(Int(Double(sorted.count - 1) * clamped), sorted.count - 1)
        return sorted[index]
    }
}
