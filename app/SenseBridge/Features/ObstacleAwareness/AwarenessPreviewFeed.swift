import CoreGraphics
import Foundation
import SenseBridgeCore

/// The on-screen mirror of a running awareness session: camera frames, pulled
/// and converted for display.
///
/// Separate from `AmbientAwarenessSession` because it answers a different
/// question. The session's loop decides *what to say*, on a cadence chosen for
/// how often a walking person can absorb a sentence. This decides *what to
/// show*, on a cadence chosen so a live feed reads as live. Folding the two
/// together would stall the preview behind a classification pass every time one
/// ran, which is exactly when a user is most likely to be looking at it.
///
/// Purely presentational: nothing here feeds perception, reasoning, or any
/// spoken output, so it can be switched off without changing a word the app
/// says.
@MainActor
@Observable
final class AwarenessPreviewFeed {
    /// The most recent camera frame, upright and ready to draw, or `nil` before
    /// the first one arrives. ARKit takes a moment to deliver frame one, which
    /// is a state the view states rather than hides.
    private(set) var image: CGImage?

    /// Width ÷ height of the camera image, in portrait.
    ///
    /// Measured from the frames ARKit actually delivers rather than assumed:
    /// world tracking picks a video format per device, and a preview shaped to
    /// the wrong ratio would letterbox the feed and pull every outline off the
    /// object it belongs to. The default is the 4:3 sensor, transposed for
    /// portrait, which is what the first frame almost always confirms.
    private(set) var aspectRatio: Double = 3.0 / 4.0

    /// How often the preview is refreshed — roughly 12 frames a second.
    ///
    /// Not the camera's 60. This sits beside a feature whose real channel is
    /// audio, and each refresh costs a colour conversion and a downscale. Fast
    /// enough to read as live, slow enough not to compete with the perception
    /// work for the same silicon.
    private static let interval: Duration = .milliseconds(80)

    private var task: Task<Void, Never>?

    /// Begins mirroring `source`, which the caller must already have started.
    ///
    /// Safe to call twice: the previous loop is cancelled rather than left
    /// running alongside a second one.
    func start(mirroring source: AmbientSensingSource) {
        stop()
        task = Task { [weak self] in
            await self?.run(mirroring: source)
        }
    }

    /// Stops mirroring and clears the last frame.
    ///
    /// The frame is dropped, not kept: a still image left on screen after the
    /// camera has been released is indistinguishable from a live feed of a room
    /// that happens to be motionless.
    func stop() {
        task?.cancel()
        task = nil
        image = nil
    }

    private func run(mirroring source: AmbientSensingSource) async {
        while !Task.isCancelled {
            if let frame = source.latestFrame() {
                // ARKit reports the resolution in the camera's landscape
                // orientation and the app is portrait, so the two are transposed.
                if frame.imageResolution.width > 0 {
                    aspectRatio = frame.imageResolution.height / frame.imageResolution.width
                }
                let rendered = await source.previewImage(for: frame)
                // `stop()` can land while a conversion is in flight; assigning
                // unconditionally would put a frame back after the feed ended.
                guard !Task.isCancelled else { return }
                image = rendered
            }
            do {
                try await Task.sleep(for: Self.interval)
            } catch {
                // Cancellation is the only way this throws, and it means stop.
                return
            }
        }
    }
}
