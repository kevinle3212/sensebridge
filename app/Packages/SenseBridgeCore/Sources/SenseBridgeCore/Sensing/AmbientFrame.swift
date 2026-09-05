#if canImport(ARKit) && os(iOS)
    import CoreGraphics
    import CoreVideo
    import Foundation
    import ImageIO

    /// One moment of ambient sensing: what the camera saw, and how far away the
    /// nearest confident thing in front of the user was.
    ///
    /// `@unchecked Sendable` is justified narrowly. Both stored buffers are
    /// `CVPixelBuffer`s vended by ARKit's internal pool and **retained** by this
    /// struct; a pooled buffer is not recycled while a reference to it is
    /// outstanding, and nothing in this package writes to either one. That is
    /// the same guarantee Apple's own ARKit-plus-Vision samples rely on when
    /// they hand `ARFrame.capturedImage` to a request on a background queue.
    /// Adding a mutable stored property here would invalidate the reasoning —
    /// remove the property rather than widening the annotation.
    public struct AmbientFrame: @unchecked Sendable {
        /// The camera image, in ARKit's native landscape orientation. Pass
        /// `orientation` alongside it to Vision rather than rotating it.
        public let image: CVPixelBuffer
        /// LiDAR depth in metres, `nil` on a frame ARKit produced no depth for
        /// (the first frames after `start()`, or a device without LiDAR).
        public let depthMap: CVPixelBuffer?
        /// Per-pixel `ARConfidenceLevel`, parallel to `depthMap`.
        public let depthConfidenceMap: CVPixelBuffer?
        /// The orientation to hand Vision so the image is analyzed upright.
        public let orientation: CGImagePropertyOrientation
        /// The camera, expressed in pixels of `imageResolution` — **not** of
        /// `depthMap`, which is smaller. The reduction rescales it.
        public let projection: CameraProjection
        /// The resolution `projection` is expressed in.
        public let imageResolution: CGSize
        public let capturedAt: Date

        /// Creates a frame.
        ///
        /// Public so callers outside this package can build one — in practice
        /// tests, which stand a synthetic `CVPixelBuffer` in for ARKit because
        /// ARKit delivers no frames at all in a simulator. Without this, the
        /// type is public but constructible only by the one class that vends it.
        public init(
            image: CVPixelBuffer,
            depthMap: CVPixelBuffer?,
            depthConfidenceMap: CVPixelBuffer?,
            orientation: CGImagePropertyOrientation,
            projection: CameraProjection,
            imageResolution: CGSize,
            capturedAt: Date
        ) {
            self.image = image
            self.depthMap = depthMap
            self.depthConfidenceMap = depthConfidenceMap
            self.orientation = orientation
            self.projection = projection
            self.imageResolution = imageResolution
            self.capturedAt = capturedAt
        }
    }
#endif
