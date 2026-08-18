import Foundation
import SenseBridgeCore

/// Continuous reading: no capture tap, aiming guidance spoken as the user moves
/// the camera, and the torch offered when the frame is genuinely dark.
///
/// A same-type extension in its own file purely for SwiftLint's `file_length`
/// gate — `isLive`, `guidance`, `liveTask`, and `didEnableTorch` are internal on
/// `ReadingSession` specifically so this file can reach them.
///
/// ## Why this is a poll and not a stream
///
/// `CameraSource` already runs an `AVCaptureVideoDataOutput` at the camera's own
/// frame rate and keeps only the newest frame. Recognition costs far more than a
/// frame interval, so consuming every frame would build a queue of work
/// describing where the camera *used to be* pointed. Pulling the latest frame
/// when the previous pass finishes keeps the guidance about the present, which
/// is the only thing a user aiming a camera can act on.
extension ReadingSession {
    /// How long to wait between recognition passes on the live feed.
    ///
    /// Slower than the camera and faster than a person can re-aim. Tighter than
    /// this spends battery re-reading a frame the user has not had time to
    /// change; looser makes the guidance lag behind the hand holding the phone.
    static let livePassInterval: Duration = .milliseconds(600)

    /// How many consecutive dark frames before the torch is offered.
    ///
    /// Three, not one: a hand passing over the lens produces a single dark
    /// frame, and a torch that flicks on and off is worse than no torch — for
    /// the user's battery and for whoever is sitting opposite them.
    static let dimFramesBeforeTorch = 3

    /// How many passes with no camera frame before saying so.
    ///
    /// Five, about three seconds. Long enough to ride out the gap between
    /// starting the session and the first frame arriving, short enough that a
    /// genuinely dead feed does not leave the user aiming at nothing.
    static let framelessPassesBeforeSaying = 5

    /// Starts continuous reading.
    func startLive(environment: AppEnvironment) async {
        guard !isLive else { return }
        locale = environment.settings.language.locale ?? .current
        isLive = true
        guidance = nil
        liveTask = Task { [weak self] in
            await self?.runLive(environment: environment)
        }
    }

    /// Stops continuous reading and puts the torch back as it was found.
    func stopLive(environment: AppEnvironment) async {
        liveTask?.cancel()
        liveTask = nil
        isLive = false
        guidance = nil
        if didEnableTorch {
            didEnableTorch = false
            _ = await environment.camera.setTorch(false)
        }
    }

    /// The live loop: recognize, guide, and read a page that has settled.
    private func runLive(environment: AppEnvironment) async {
        // A page is read aloud only once its recognized text repeats, so the
        // user hears a page they have finished aiming at rather than a
        // half-framed one — and only once, so holding still does not restart it.
        var previousText = ""
        var lastReadText = ""
        var dimFrames = 0
        var framelessPasses = 0
        var throttle = NarrationThrottle(minimumInterval: 3, repeatSuppressionInterval: 12)

        while !Task.isCancelled {
            guard let frame = await environment.camera.source.latestVideoFrame() else {
                framelessPasses += 1
                // Said out loud rather than spun on in silence. If the camera
                // stops delivering — another feature took it, the session
                // dropped — a user aiming at a page hears nothing at all, which
                // on this screen is indistinguishable from the app having died.
                if framelessPasses == Self.framelessPassesBeforeSaying {
                    await announce(
                        String(localized: "The camera isn't sending anything to read right now."),
                        signal: .error,
                        environment: environment
                    )
                }
                try? await Task.sleep(for: Self.livePassInterval)
                continue
            }
            framelessPasses = 0
            dimFrames = await updateTorch(for: frame, dimFrames: dimFrames, environment: environment)

            let lines = await (try? ocrLines(in: frame)) ?? []
            guard !Task.isCancelled else { return }
            let verdict = ReadingFraming.guidance(for: lines)
            guidance = phrasing.framingGuidance(for: verdict, locale: locale)
            if let spoken = guidance, throttle.shouldSpeak(spoken, at: .now) {
                // `.resultReady`, not `.nothingFound`. `HapticPattern` builds
                // the latter as "one soft, dull tap — low-key, easy to miss on
                // purpose", which is the wrong cue for an instruction the user
                // is meant to act on, and it would make one tap mean both
                // "nothing found" and "move the camera up".
                await announce(spoken, signal: .resultReady, environment: environment)
            }

            let text = TextSegmenter.joined(lines.map(\.text))
            if verdict == .wellFramed, !text.isEmpty, text == previousText, text != lastReadText {
                lastReadText = text
                await readSettledPage(text, environment: environment)
            }
            previousText = text
            try? await Task.sleep(for: Self.livePassInterval)
        }
    }

    /// Recognition over one live frame.
    ///
    /// Separate from the capture path's `recognize(_ Data:)` because a live
    /// frame is already a pixel buffer: encoding it to JPEG and decoding it
    /// again for every pass would cost more than the recognition itself.
    private func ocrLines(in frame: CameraVideoFrame) async throws -> [RecognizedTextLine] {
        try await ocr.recognize(frame.image, orientation: frame.orientation)
    }

    /// Reads a page whose recognized text has stopped changing, and keeps it as
    /// the current document so the transport controls work on it.
    ///
    /// Arms a resume before it stops. Live reading used to end here for good
    /// while the picker still said "Keep reading" and the screen still promised
    /// that it keeps looking — so a user who turned to the second page got
    /// nothing, permanently, with no way to tell that from a crash.
    private func readSettledPage(_ text: String, environment: AppEnvironment) async {
        shouldResumeLiveAfterPlayback = environment.settings.readingMode == .live
        await stopLive(environment: environment)
        adoptLiveText(text)
        await play(environment: environment)
    }

    /// Switches the torch on after enough consecutive dark frames, and says so.
    ///
    /// - Returns: The updated consecutive-dark-frame count.
    private func updateTorch(
        for frame: CameraVideoFrame,
        dimFrames: Int,
        environment: AppEnvironment
    ) async -> Int {
        // `.unmeasured` means an unreadable pixel format, not a dark room.
        // Resetting the count rather than incrementing it keeps a format this
        // build cannot read from leaving the torch on permanently.
        guard FrameLuminance.brightness(of: frame.image) == .dim else { return 0 }
        let count = dimFrames + 1
        guard count >= Self.dimFramesBeforeTorch,
              !didEnableTorch,
              environment.camera.isTorchAvailable,
              !environment.camera.isTorchOn
        else { return count }

        // Claimed *before* the await, not after. `stopLive` decides whether to
        // switch the torch back off by reading this flag, and it can run while
        // this call is suspended — leaving a lit torch nothing owns. Claiming
        // first means a concurrent stop always sees the intent and undoes it.
        didEnableTorch = true
        guard await environment.camera.setTorch(true) else {
            didEnableTorch = false
            return count
        }
        // A stop, or a switch back to capture mode, can land during that await.
        // Announcing afterwards would tell a blind user a light is on that this
        // screen no longer has any part in.
        if isLive, !Task.isCancelled {
            // Said out loud. A torch switching itself on is a change to the
            // world around the user — including for anyone facing them — and a
            // blind user has no other way to know it happened.
            await announce(
                String(localized: "The view looked dark, so the light is on. Turn it off in the camera controls."),
                signal: .resultReady,
                environment: environment
            )
        }
        return count
    }
}
