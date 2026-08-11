#if canImport(ARKit) && os(iOS)
    import ARKit
    import CoreImage
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

    /// Continuous camera-plus-LiDAR sensing for hands-free awareness, built on
    /// `ARSession` because it is the only API that hands back a camera frame and
    /// a registered `sceneDepth` map from one session — see
    /// docs/ARCHITECTURE.md "Sensing Layer" and the depth-capture module in
    /// deprecated/planning/SENSEBRIDGE-02-FEATURES-AND-SCOPE.md.
    ///
    /// **Deliberately does not conform to `SensingSource`.** That protocol is
    /// push-based (`start()` returns a stream of everything captured), which is
    /// right for `CameraSource`'s discrete photos and wrong here: ARKit produces
    /// 60 frames a second and this feature consumes fewer than two, so a stream
    /// would exist only to have 97% of its elements dropped. `latestFrame()` is
    /// a pull instead, and the consumer's own cadence is the only cadence.
    ///
    /// **Exclusive with `CameraSource`.** Both want the rear camera and iOS
    /// grants it to one session; a caller must stop the other before starting
    /// this.
    @MainActor
    public final class AmbientSensingSource {
        /// Why hands-free sensing could not start. Distinguished rather than
        /// collapsed into one case because the honest thing to tell the user
        /// differs: a permission is recoverable in Settings, missing LiDAR
        /// never is.
        public enum SensingError: Error, Sendable, Equatable {
            /// The device does not support world tracking at all.
            case unsupportedDevice
            /// The device supports tracking but has no LiDAR scene depth, so
            /// distance is unavailable — object naming would still work.
            case depthUnavailable
        }

        /// The region of the raw depth map to measure, in normalized buffer
        /// coordinates.
        ///
        /// This trims the **periphery** only: things off to the side are not
        /// what "ahead" means, and a doorframe the user is walking past should
        /// not be narrated as an obstacle in front of them. It deliberately
        /// does *not* trim the floor. Excluding the floor by rectangle would
        /// require knowing the strap's pitch angle in advance, and the strap is
        /// elastic that gets re-tightened every morning; that job belongs to
        /// `DepthGeometry`, which measures which way is down on every frame.
        ///
        /// The axes are ARKit's, not the screen's. ARKit delivers depth in the
        /// camera's native landscape orientation, and the app is portrait, so
        /// the two are transposed: **raw x runs top-to-bottom of what the user
        /// faces** and **raw y runs across it**. Trimming the periphery
        /// therefore means centring raw `y` and leaving raw `x` whole.
        ///
        /// `nonisolated let` so the off-main reduction in `depthMeters(in:)`
        /// can read it without hopping to the main actor for a `CGRect`. Change
        /// it by constructing a new source, which is what the session does when
        /// the user changes the relevant setting.
        public nonisolated let regionOfInterest: CGRect

        /// How far above the lowest surface in view something must stand to be
        /// treated as an obstacle rather than as ground — see
        /// `DepthStatistics.nearestConfidentDepth`.
        ///
        /// The remaining tuning knob, and a far safer one than a pixel
        /// rectangle: it is expressed in metres of real headroom, so it means
        /// the same thing at every mount angle. Too low and floor texture reads
        /// as an obstacle; too high and a kerb goes unmentioned.
        public nonisolated let floorClearanceMeters: Float

        /// The ARKit session, kept for the lifetime of this object so a
        /// stop/start pair resumes rather than rebuilding tracking state.
        private let session: ARSession = .init()
        private(set) var isRunning = false

        /// Creates a sensing source.
        ///
        /// - Parameters:
        ///   - regionOfInterest: See `regionOfInterest`. The default keeps the
        ///     full vertical extent of what the user faces and the middle half
        ///     across, so the floor is measured and then rejected on geometry
        ///     rather than excluded on a guess.
        ///   - floorClearanceMeters: See `floorClearanceMeters`. The default
        ///     sits below kerb height so a step up is still reported.
        public init(
            regionOfInterest: CGRect = CGRect(x: 0, y: 0.25, width: 1.0, height: 0.5),
            floorClearanceMeters: Float = 0.2
        ) {
            self.regionOfInterest = regionOfInterest
            self.floorClearanceMeters = floorClearanceMeters
        }

        /// Whether this device can report distance at all. Callers must check
        /// it before offering distance-based awareness — offering a control
        /// that silently measures nothing is what AGENTS.md doctrine 4's first
        /// corollary forbids.
        public static var isDepthSupported: Bool {
            ARWorldTrackingConfiguration.isSupported
                && ARWorldTrackingConfiguration.supportsFrameSemantics(.sceneDepth)
        }

        /// Starts the session. Throws before starting anything when the device
        /// cannot deliver depth, so the caller can say which of the two reasons
        /// applies rather than reporting a generic failure.
        public func start() throws {
            guard ARWorldTrackingConfiguration.isSupported else { throw SensingError.unsupportedDevice }
            guard ARWorldTrackingConfiguration.supportsFrameSemantics(.sceneDepth) else {
                throw SensingError.depthUnavailable
            }
            let configuration = ARWorldTrackingConfiguration()
            configuration.frameSemantics = .sceneDepth
            // Plane detection and environment texturing are off: nothing here
            // consumes either, and both cost power on a session the user is
            // expected to leave running while walking.
            configuration.planeDetection = []
            configuration.environmentTexturing = .none
            session.run(configuration, options: [.resetTracking, .removeExistingAnchors])
            isRunning = true
        }

        /// Stops the session and releases the camera back to `CameraSource`.
        public func stop() {
            guard isRunning else { return }
            session.pause()
            isRunning = false
        }

        /// The most recent frame ARKit has produced, or `nil` before the first
        /// one arrives.
        ///
        /// Does no pixel work of its own — it retains buffers and returns. The
        /// reduction in `depthMeters(in:)` is the expensive half and runs off
        /// the main actor, because this class has to stay on the main actor
        /// (`ARSession` requires it) and docs/ARCHITECTURE.md "Main thread
        /// stays free" is a hard rule for a VoiceOver-first app.
        public func latestFrame(
            orientation: CGImagePropertyOrientation = .right
        ) -> AmbientFrame? {
            guard isRunning, let frame = session.currentFrame else { return nil }
            let intrinsics = frame.camera.intrinsics
            let rotation = frame.camera.transform
            let projection = CameraProjection(
                focalLength: SIMD2(intrinsics[0][0], intrinsics[1][1]),
                principalPoint: SIMD2(intrinsics[2][0], intrinsics[2][1]),
                upInCameraSpace: CameraProjection.upInCameraSpace(
                    rotationColumn0: simd_make_float3(rotation.columns.0),
                    rotationColumn1: simd_make_float3(rotation.columns.1),
                    rotationColumn2: simd_make_float3(rotation.columns.2)
                )
            )
            return AmbientFrame(
                image: frame.capturedImage,
                depthMap: frame.sceneDepth?.depthMap,
                depthConfidenceMap: frame.sceneDepth?.confidenceMap,
                orientation: orientation,
                projection: projection,
                imageResolution: frame.camera.imageResolution,
                capturedAt: Date.now
            )
        }

        /// Turns a frame's camera image into something a view can draw,
        /// upright and scaled down for display.
        ///
        /// Deliberately a plain image rather than an `ARSCNView`/`ARView`
        /// binding. Nothing in this app renders 3D content, so a SceneKit view
        /// would buy nothing while importing a stack of implicit requirements —
        /// it expects to own the session, to drive its own render loop, and to
        /// live somewhere more ordinary than a `List` row. A `CGImage` this
        /// class produced either appears or is visibly absent, with no third
        /// state where a renderer silently draws nothing.
        ///
        /// `nonisolated` and off the main actor: colour conversion and scaling
        /// per displayed frame is exactly the work docs/ARCHITECTURE.md "Main
        /// thread stays free" exists to keep away from VoiceOver.
        ///
        /// - Parameter maximumDimension: Longest edge of the result, in pixels.
        ///   The camera image is far larger than any preview, and scaling here
        ///   rather than at draw time is what keeps this affordable to repeat.
        @concurrent
        public nonisolated func previewImage(
            for frame: AmbientFrame,
            maximumDimension: CGFloat = 640
        ) async -> CGImage? {
            let upright = CIImage(cvPixelBuffer: frame.image).oriented(frame.orientation)
            let longestEdge = max(upright.extent.width, upright.extent.height)
            guard longestEdge > 0 else { return nil }
            let scale = min(1, maximumDimension / longestEdge)
            let scaled = upright.transformed(by: CGAffineTransform(scaleX: scale, y: scale))
            return Self.renderContext.createCGImage(scaled, from: scaled.extent)
        }

        /// One context for every conversion. Creating a `CIContext` per frame is
        /// the classic way to make this path expensive — each one allocates its
        /// own GPU resources. `nonisolated` because the conversion that uses it
        /// runs off the main actor this class is otherwise pinned to.
        private nonisolated static let renderContext: CIContext = .init()

        /// Reduces `frame`'s depth map to a single distance in metres, or `nil`
        /// when the frame carried no usable measurement.
        ///
        /// `nil` means "this frame could not be measured" and never "nothing is
        /// ahead" — see `DepthStatistics.nearestConfidentDepth`, and
        /// docs/SAFETY-FRAMING.md on why the app never asserts an absence.
        @concurrent
        public nonisolated func depthMeters(in frame: AmbientFrame) async -> Double? {
            guard let depthMap = frame.depthMap, let confidenceMap = frame.depthConfidenceMap else {
                return nil
            }
            let region = Self.readDepthRegion(
                depthMap: depthMap,
                confidenceMap: confidenceMap,
                region: regionOfInterest,
                camera: (frame.projection, frame.imageResolution)
            )
            return DepthStatistics.nearestConfidentDepth(
                samples: region.depths,
                confidences: region.confidences,
                heights: region.heights,
                floorClearanceMeters: floorClearanceMeters
            )
        }

        /// Copies the depth and confidence values inside `region` out of their
        /// pixel buffers into plain arrays, alongside each sample's height
        /// along gravity, so the reduction itself stays pure and unit-testable
        /// — see `DepthStatistics` and `DepthGeometry`.
        ///
        /// `nonisolated` because it is the expensive half of `depthMeters(in:)`
        /// and must not run on the main actor this class is otherwise pinned to
        /// — see docs/ARCHITECTURE.md "Main thread stays free". It touches no
        /// instance state, only its arguments.
        private nonisolated static func readDepthRegion(
            depthMap: CVPixelBuffer,
            confidenceMap: CVPixelBuffer,
            region: CGRect,
            camera: (projection: CameraProjection, imageResolution: CGSize)
        ) -> DepthSamples {
            CVPixelBufferLockBaseAddress(depthMap, .readOnly)
            CVPixelBufferLockBaseAddress(confidenceMap, .readOnly)
            defer {
                CVPixelBufferUnlockBaseAddress(confidenceMap, .readOnly)
                CVPixelBufferUnlockBaseAddress(depthMap, .readOnly)
            }

            let width = CVPixelBufferGetWidth(depthMap)
            let height = CVPixelBufferGetHeight(depthMap)
            // ARKit documents the two maps as the same dimensions; a mismatch
            // would silently pair each depth with an unrelated confidence, so
            // bail rather than reporting a distance built from mixed pixels.
            guard CVPixelBufferGetWidth(confidenceMap) == width,
                  CVPixelBufferGetHeight(confidenceMap) == height,
                  let depthBase = CVPixelBufferGetBaseAddress(depthMap),
                  let confidenceBase = CVPixelBufferGetBaseAddress(confidenceMap),
                  camera.imageResolution.width > 0, camera.imageResolution.height > 0
            else { return DepthSamples() }

            let minX = max(Int(region.minX * CGFloat(width)), 0)
            let maxX = min(Int(region.maxX * CGFloat(width)), width)
            let minY = max(Int(region.minY * CGFloat(height)), 0)
            let maxY = min(Int(region.maxY * CGFloat(height)), height)
            guard minX < maxX, minY < maxY else { return DepthSamples() }

            return walk(Traversal(
                depthBase: depthBase,
                confidenceBase: confidenceBase,
                depthStride: CVPixelBufferGetBytesPerRow(depthMap),
                confidenceStride: CVPixelBufferGetBytesPerRow(confidenceMap),
                columns: minX ..< maxX,
                rows: minY ..< maxY,
                projection: camera.projection.scaled(by: SIMD2(
                    Float(CGFloat(width) / camera.imageResolution.width),
                    Float(CGFloat(height) / camera.imageResolution.height)
                ))
            ))
        }

        /// Everything `walk(_:)` needs to read one rectangle out of a locked
        /// pair of pixel buffers. A parameter object rather than a long
        /// argument list, because these are meaningless apart and every one of
        /// them is an easy thing to pass in the wrong order.
        private struct Traversal {
            let depthBase: UnsafeMutableRawPointer
            let confidenceBase: UnsafeMutableRawPointer
            let depthStride: Int
            let confidenceStride: Int
            let columns: Range<Int>
            let rows: Range<Int>
            /// Already scaled to the depth map's resolution.
            let projection: CameraProjection
        }

        /// The hot loop, split out from the buffer locking and validation
        /// around it. Runs once per depth sample in the region, so it stays
        /// free of anything that allocates per iteration.
        ///
        /// - Precondition: both buffers are locked and their bases valid for
        ///   the whole traversal, which `readDepthRegion(...)` guarantees with
        ///   its `defer`.
        private nonisolated static func walk(_ traversal: Traversal) -> DepthSamples {
            var result = DepthSamples()
            let capacity = traversal.columns.count * traversal.rows.count
            result.depths.reserveCapacity(capacity)
            result.confidences.reserveCapacity(capacity)
            result.heights.reserveCapacity(capacity)
            for row in traversal.rows {
                let depthRow = traversal.depthBase
                    .advanced(by: row * traversal.depthStride)
                    .assumingMemoryBound(to: Float.self)
                let confidenceRow = traversal.confidenceBase
                    .advanced(by: row * traversal.confidenceStride)
                    .assumingMemoryBound(to: UInt8.self)
                for column in traversal.columns {
                    let depth = depthRow[column]
                    result.depths.append(depth)
                    result.confidences.append(confidenceRow[column])
                    result.heights.append(DepthGeometry.heightRelativeToCamera(
                        depthMeters: depth,
                        column: column,
                        row: row,
                        projection: traversal.projection
                    ))
                }
            }
            return result
        }
    }
#endif
