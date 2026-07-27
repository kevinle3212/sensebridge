import Foundation

/// Everything about one frame's camera needed to turn a depth sample into a
/// height: where the lens points, and which way is down.
///
/// Bundled into one value because the three travel together and are only ever
/// meaningful together — a focal length paired with another frame's gravity
/// vector would silently produce plausible, wrong heights.
public struct CameraProjection: Sendable, Equatable {
    /// Focal length in pixels, expressed for the buffer being sampled.
    public let focalLength: SIMD2<Float>
    /// Principal point in pixels, expressed for the buffer being sampled.
    public let principalPoint: SIMD2<Float>
    /// The world's up axis in camera space. Captured per frame, so floor
    /// rejection tracks the mount's actual pitch instead of assuming one.
    public let upInCameraSpace: SIMD3<Float>

    public init(
        focalLength: SIMD2<Float>,
        principalPoint: SIMD2<Float>,
        upInCameraSpace: SIMD3<Float>
    ) {
        self.focalLength = focalLength
        self.principalPoint = principalPoint
        self.upInCameraSpace = upInCameraSpace
    }

    /// The same camera, re-expressed for a buffer of a different size.
    ///
    /// ARKit states intrinsics for the captured image, which is several times
    /// larger than the depth map actually sampled. Both focal length and
    /// principal point scale by the same ratio; scaling one without the other
    /// tilts the computed ground plane, which is the kind of error that looks
    /// like a calibration problem rather than a bug.
    public func scaled(by scale: SIMD2<Float>) -> CameraProjection {
        CameraProjection(
            focalLength: focalLength * scale,
            principalPoint: principalPoint * scale,
            upInCameraSpace: upInCameraSpace
        )
    }

    /// The world's up axis in camera space, from a camera rotation's columns.
    ///
    /// ARKit's default world alignment puts world `+Y` along gravity, so up in
    /// camera space is the transpose of the rotation applied to `(0, 1, 0)` —
    /// which, for a rotation matrix, is just its second row. Taking the row of
    /// a column-major matrix means reading the `y` of each column; reading the
    /// second *column* instead is the easy mistake, and it yields the camera's
    /// own up axis rather than gravity's.
    ///
    /// Pass the upper-left 3×3 of `ARCamera.transform`. The translation is
    /// irrelevant because this is a direction, not a point.
    public static func upInCameraSpace(
        rotationColumn0: SIMD3<Float>,
        rotationColumn1: SIMD3<Float>,
        rotationColumn2: SIMD3<Float>
    ) -> SIMD3<Float> {
        SIMD3(rotationColumn0.y, rotationColumn1.y, rotationColumn2.y)
    }
}

/// Turns a depth sample's position in the frame into its height along gravity,
/// relative to the camera.
///
/// This exists so floor rejection can be a *measurement* rather than a guess.
/// A phone strapped to a chest points downward by some unknown angle, so the
/// floor occupies some unknown part of the frame — and the floor is always the
/// nearest large surface in view, which means a naive reduction reports it
/// forever. Choosing a fixed rectangle to exclude requires knowing the strap's
/// pitch in advance, and the strap is a piece of elastic the user re-tightens
/// every morning.
///
/// ARKit already knows which way is down, on every frame, whatever the strap is
/// doing. Projecting each sample onto that axis gives its height relative to
/// the camera, and "is this the floor" becomes a question about the world
/// instead of a question about pixel coordinates.
///
/// Pure functions over plain numbers, deliberately free of ARKit, so the
/// arithmetic is verifiable without a LiDAR device attached — the same split as
/// `DepthStatistics`.
public enum DepthGeometry {
    /// The height of one depth sample above or below the camera, in metres,
    /// measured along gravity.
    ///
    /// Negative is below the camera. A chest-mounted phone sees floor at
    /// roughly `-1.3 m` and a door handle at roughly `-0.4 m`, whatever
    /// direction the phone is pointing, because the axis is gravity rather than
    /// the camera's own tilt.
    ///
    /// - Parameters:
    ///   - depthMeters: The sample's distance from the camera along the view
    ///     ray, which is what LiDAR reports.
    ///   - column: The sample's horizontal pixel position in the depth map.
    ///   - row: The sample's vertical pixel position in the depth map.
    ///   - projection: The camera, already scaled to the depth map's
    ///     resolution — see `CameraProjection.scaled(by:)`.
    /// - Returns: The height in metres, or `nan` for a sample that carries no
    ///   usable geometry. `nan` is deliberate: it propagates into the caller's
    ///   `isFinite` filter and is discarded there, rather than being silently
    ///   substituted with a plausible-looking zero.
    public static func heightRelativeToCamera(
        depthMeters: Float,
        column: Int,
        row: Int,
        projection: CameraProjection
    ) -> Float {
        guard depthMeters.isFinite, depthMeters > 0,
              projection.focalLength.x != 0, projection.focalLength.y != 0
        else { return .nan }

        // ARKit camera space is +X right, +Y up, -Z forward, while image
        // coordinates run downward from a top-left origin — hence the flip on
        // the vertical term. Getting this backwards would put the floor
        // overhead, which no test of the reduction alone would catch.
        let rightward = (Float(column) - projection.principalPoint.x)
            * depthMeters / projection.focalLength.x
        let upward = (projection.principalPoint.y - Float(row))
            * depthMeters / projection.focalLength.y
        let backward = -depthMeters

        let up = projection.upInCameraSpace
        return rightward * up.x + upward * up.y + backward * up.z
    }
}
