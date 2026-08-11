import AVFoundation
import Foundation

/// Captures a short, single microphone recording as WAV `Data` — the mic
/// capture behind "Sounds". An actor so capture never runs on the main
/// thread — see docs/ARCHITECTURE.md "Main thread stays free".
///
/// One recording per call, never a continuous stream: Sound Alerts is
/// "Listen once", not "Start listening" — see `SoundAlertsView`. The WAV
/// data is written to a temporary file only because `AVAudioFile` requires a
/// URL to encode to; that file is deleted before `record(duration:)`
/// returns, so nothing survives the call. No audio is ever cached, streamed
/// off-device, or written anywhere durable — see docs/PRIVACY.md.
public actor MicrophoneSensingSource {
    public enum MicrophoneError: Error, Sendable, Equatable {
        case authorizationDenied
        case noMicrophoneAvailable
        case recordingFailed
    }

    /// Microphone permission state, mirroring `CameraSource.AuthorizationStatus`
    /// so the app layer can tell "haven't asked yet" from "denied" the same
    /// way it already does for the camera.
    public enum AuthorizationStatus: Sendable, Equatable {
        case notDetermined
        case authorized
        case denied
    }

    /// The current microphone permission state, queryable without calling
    /// `record(duration:)` — see `AuthorizationStatus`. Uses
    /// `AVCaptureDevice`'s audio authorization API (mirroring how
    /// `CameraSource.authorizationStatus` queries `.video`) rather than
    /// `AVAudioApplication`, which is unavailable on macOS and would break
    /// this package's macOS target.
    public nonisolated static var authorizationStatus: AuthorizationStatus {
        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .authorized: .authorized
        case .notDetermined: .notDetermined
        case .denied, .restricted: .denied
        @unknown default: .denied
        }
    }

    private let engine: AVAudioEngine = .init()

    /// Whether a tap is currently installed on the engine's input node.
    ///
    /// Makes `stopCapture(tappedBy:)` idempotent so the success path can release
    /// the microphone before reading the file while the `defer` still covers the
    /// error and cancellation paths. Actor-isolated, so no lock is needed.
    private var isCapturing = false

    /// Creates a source backed by a fresh `AVAudioEngine`.
    ///
    /// Holds no permission and touches no hardware — the engine is only started
    /// inside `record(duration:)`, so constructing one is free and does not
    /// prompt the wearer.
    public init() {
        // No stored state beyond `engine`, which is initialised inline.
    }

    /// Requests microphone permission if not yet determined, then records
    /// `duration` seconds from the input node and returns it as WAV `Data`.
    public func record(duration: TimeInterval) async throws -> Data {
        guard await Self.requestAuthorization() else {
            throw MicrophoneError.authorizationDenied
        }

        #if os(iOS)
            // AVAudioSession doesn't exist on macOS; the session category only
            // needs configuring on-device.
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.record, mode: .measurement)
            try session.setActive(true)
            defer { try? session.setActive(false) }
        #endif

        let input = engine.inputNode
        let format = input.outputFormat(forBus: 0)
        guard format.sampleRate > 0 else { throw MicrophoneError.noMicrophoneAvailable }

        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("wav")
        let file = try AVAudioFile(forWriting: tempURL, settings: format.settings)
        defer { try? FileManager.default.removeItem(at: tempURL) }

        input.installTap(onBus: 0, bufferSize: 4096, format: format) { buffer, _ in
            try? file.write(from: buffer)
        }
        isCapturing = true
        // Registered before `engine.start()` can fail, so the tap is removed on
        // every exit from here on: success, throw, or cancellation.
        defer { stopCapture(tappedBy: input) }

        do {
            try engine.start()
        } catch {
            throw MicrophoneError.recordingFailed
        }

        // Awaited directly rather than inside a `withCheckedThrowingContinuation`
        // driven by an unstructured `Task`. That closure is not an async context,
        // so the `Task` it created had no parent and inherited no cancellation:
        // cancelling the caller left the sleep running to completion, holding the
        // engine open and the microphone indicator lit for the rest of `duration`
        // after the wearer had already moved on. Sleeping in this task makes
        // cancellation immediate and lets `defer` own teardown.
        try await Task.sleep(for: .seconds(duration))

        // Stopped explicitly, not left to the `defer`: a `defer` runs after the
        // return value is computed, so the file would be read while the tap
        // could still be appending to it. The `defer` stays as the cancellation
        // and error path, and `stopCapture` is idempotent so running twice on
        // the success path is harmless.
        stopCapture(tappedBy: input)

        return try Data(contentsOf: tempURL)
    }

    /// Stops the engine and removes the capture tap, if one is installed.
    ///
    /// Every exit from `record(duration:)` — normal completion, a throw, or
    /// cancellation — releases the microphone through this one path. Leaving a
    /// tap on a running engine keeps the mic indicator lit after recording is
    /// over, which for this app is a privacy signal the wearer would rightly
    /// read as "still listening".
    ///
    /// Idempotent: calling it twice is a no-op, which is what lets the success
    /// path stop before reading the file while the `defer` still guards the
    /// other paths.
    ///
    /// - Parameter input: The node the tap was installed on.
    private func stopCapture(tappedBy input: AVAudioNode) {
        guard isCapturing else { return }
        isCapturing = false
        engine.stop()
        input.removeTap(onBus: 0)
    }

    private static func requestAuthorization() async -> Bool {
        switch authorizationStatus {
        case .authorized: true
        case .notDetermined: await AVCaptureDevice.requestAccess(for: .audio)
        case .denied: false
        }
    }
}
