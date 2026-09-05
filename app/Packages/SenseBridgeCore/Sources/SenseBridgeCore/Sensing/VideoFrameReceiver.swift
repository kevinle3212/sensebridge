@preconcurrency import AVFoundation
import CoreVideo
import Foundation
import ImageIO

/// One camera frame from the live video feed, with what Vision needs to read it
/// upright.
///
/// The still-capture counterpart of `AmbientFrame`, and deliberately the same
/// shape: a retained pixel buffer plus an orientation, never a rotated copy.
/// Rotating a buffer per frame is real work Vision does for free.
///
/// `@unchecked Sendable` carries the same narrow justification `AmbientFrame`
/// carries — the single stored buffer is retained by this struct, and nothing in
/// this package writes to it. Adding a mutable stored property invalidates that
/// reasoning; remove the property rather than widening the annotation.
public struct CameraVideoFrame: @unchecked Sendable {
    /// The camera image, in the camera's native orientation.
    public let image: CVPixelBuffer
    /// What to tell Vision so the frame is analyzed upright.
    public let orientation: CGImagePropertyOrientation
    public let capturedAt: Date

    /// Creates a frame. Public so tests can stand a synthetic buffer in for the
    /// camera, which produces nothing in a simulator.
    public init(image: CVPixelBuffer, orientation: CGImagePropertyOrientation, capturedAt: Date) {
        self.image = image
        self.orientation = orientation
        self.capturedAt = capturedAt
    }
}

/// Keeps the most recent video frame, for a consumer that pulls rather than
/// subscribes.
///
/// ## Why one frame, and why a pull
///
/// The camera delivers 30 frames a second and live reading consumes two or
/// three: a stream would exist to have 90% of its elements dropped, which is
/// exactly the reasoning `AmbientSensingSource` gives for not conforming to
/// `SensingSource`. Keeping only the newest frame also bounds memory to a single
/// buffer no matter how far behind the consumer falls — an unbounded queue of
/// 12-megapixel buffers is a memory warning within seconds.
///
/// ## Holding a pooled buffer
///
/// `AVCaptureVideoDataOutput` vends buffers from a fixed pool and stalls capture
/// when the pool empties. Retaining exactly one, replaced on every delivery, is
/// the documented safe bound; `alwaysDiscardsLateVideoFrames` on the output side
/// means a slow consumer drops frames rather than backing the pool up.
///
/// The lock is `NSLock` rather than an actor because `captureOutput` is called
/// on AVFoundation's own queue and cannot `await` — an actor here would mean
/// hopping every delivered frame onto another executor purely to store it.
final class VideoFrameReceiver: NSObject, AVCaptureVideoDataOutputSampleBufferDelegate, @unchecked Sendable {
    /// Guards `latest`, which is written from the capture queue and read from
    /// whichever context pulled.
    private let lock: NSLock = .init()
    private var latest: CameraVideoFrame?

    /// The newest frame, or `nil` before the first one arrives — which is not an
    /// error and emphatically not "the camera sees nothing".
    func latestFrame() -> CameraVideoFrame? {
        lock.withLock { latest }
    }

    /// Discards the held frame, so a stopped session leaves nothing behind for
    /// a later reader to mistake for a live view.
    func reset() {
        lock.withLock { latest = nil }
    }

    /// Stores each delivered frame, replacing the previous one.
    ///
    /// Frames are stamped `.up` because `CameraSource` sets the video
    /// connection's `videoRotationAngle` from the same rotation coordinator it
    /// uses for stills, so the buffer arrives already upright. Rotating in the
    /// connection rather than tracking an angle here removes the whole class of
    /// bug where a frame is analysed sideways and OCR quietly returns nothing —
    /// a failure a blind user would experience as "Read stopped working".
    func captureOutput(
        _: AVCaptureOutput,
        didOutput sampleBuffer: CMSampleBuffer,
        from _: AVCaptureConnection
    ) {
        guard let buffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        lock.withLock {
            latest = CameraVideoFrame(image: buffer, orientation: .up, capturedAt: .now)
        }
    }
}
