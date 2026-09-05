import SenseBridgeCore
import SwiftUI

/// Owns the app's single shared `CameraSource` and republishes its
/// actor-isolated state as main-actor `@Observable` properties SwiftUI can
/// bind to. Exactly one instance lives on `AppEnvironment`: views each
/// building their own `CameraSource` would mean several `AVCaptureSession`s
/// competing for one physical camera.
@MainActor
@Observable
final class CameraController {
    /// The underlying capture actor. Exposed only so `CameraPreviewView` can
    /// attach an `AVCaptureVideoPreviewLayer` to `source.session` — drive
    /// everything else through this controller, so the published state below
    /// stays in step with the device.
    let source: CameraSource

    /// Lenses this device offers, widest to narrowest. `[.wide]` until
    /// `start(applying:)` resolves a device.
    private(set) var availableLenses: [CameraLens] = [.wide]
    /// The lens most recently selected through `select(lens:)`.
    private(set) var currentLens: CameraLens = .wide
    /// The zoom factor the device is at (or ramping toward).
    private(set) var zoomFactor: Double = 1
    /// Bounds for a zoom control. `1...1` — nothing to adjust — until a
    /// device is resolved.
    private(set) var zoomRange: ClosedRange<Double> = 1 ... 1
    /// Whether this device has a torch at all, so a UI can omit the control
    /// rather than offer a toggle that does nothing.
    private(set) var isTorchAvailable = false
    /// Whether the torch is currently lit.
    private(set) var isTorchOn = false
    /// Whether a capture is in flight, for disabling the capture button.
    private(set) var isCapturing = false
    /// Whether the capture session is running.
    private(set) var isRunning = false
    /// Why the most recent `start(applying:)` failed, or `nil` if it
    /// succeeded. Views map this to their own copy — the wording differs per
    /// feature ("read text", "identify objects"), so it isn't decided here.
    private(set) var startError: CameraSource.CameraError?

    /// The in-flight `start`/`stop`, so the two serialize instead of racing.
    /// Navigating away and straight back fires `stop()` and `start()` as two
    /// independent `Task`s with no ordering guarantee between them, which
    /// could otherwise leave `isRunning`/`isTorchOn`/`zoomFactor` describing
    /// a session state the actor isn't actually in.
    private var sessionTask: Task<Void, Never>?

    /// The newest zoom the user has asked for, and the single task draining
    /// it to the device — see `setZoom(_:)`.
    private var requestedZoom: Double?
    private var zoomDrainTask: Task<Void, Never>?

    /// Whether this launch was told to behave as though the device has no
    /// camera, via `-uiTestNoCamera`.
    ///
    /// Three UI tests assert the no-camera *error* path — that a capture screen
    /// says so out loud instead of going silent. They used to get that state
    /// for free, because the Simulator genuinely has no camera. The first
    /// device run of the suite (2026-08-19) failed all three for the most
    /// boring reason available: the phone has a camera, so the error path they
    /// assert is correctly never entered. Reading the real camera's output
    /// instead would make them assert whatever the lens happened to be pointed
    /// at, which is not a test. This flag lets them force the one path they are
    /// about, identically on both destinations.
    ///
    /// Compiled out of release builds entirely. iOS gives no third party a way
    /// to inject launch arguments into someone else's app, so this is not a
    /// reachable attack surface either way — but a switch that disables the
    /// camera has no business existing in a shipped binary, and `#if DEBUG`
    /// costs nothing to say so.
    private static var forcesNoCamera: Bool {
        #if DEBUG
            ProcessInfo.processInfo.arguments.contains("-uiTestNoCamera")
        #else
            false
        #endif
    }

    /// Creates a controller over `source`; injectable so previews and tests
    /// can supply their own.
    init(source: CameraSource = CameraSource()) {
        self.source = source
    }

    /// Current camera permission state — lets a caller tell "not asked yet"
    /// (starting will show the system prompt) from "denied" (only Settings
    /// can change that, so re-prompting is a dead end).
    var authorizationStatus: CameraSource.AuthorizationStatus {
        CameraSource.authorizationStatus
    }

    /// Starts the shared session if it isn't already running, then applies
    /// the user's preferred lens and torch default.
    ///
    /// Idempotent for concurrent callers, not just sequential ones — several
    /// views calling this from `.task` is the expected pattern. The
    /// `!isRunning` guard alone would not achieve that, because `isRunning`
    /// is only set after the `await` returns, so two calls could both pass it;
    /// serializing on `sessionTask` closes that window and also orders this
    /// against a `stop()` racing in from `.onDisappear`.
    func start(applying settings: Settings) async {
        let previous = sessionTask
        let task = Task { [weak self] in
            await previous?.value
            await self?.performStart(applying: settings)
        }
        sessionTask = task
        await task.value
    }

    private func performStart(applying settings: Settings) async {
        guard !isRunning else { return }
        // Set before any hardware is touched, so the state a view reads is the
        // same one a camera-less device would produce.
        guard !Self.forcesNoCamera else {
            startError = .noCameraAvailable
            return
        }
        do {
            _ = try await source.start()
        } catch let error as CameraSource.CameraError {
            startError = error
            return
        } catch {
            startError = .noCameraAvailable
            return
        }
        startError = nil
        isRunning = true
        availableLenses = await source.availableLenses
        zoomRange = await source.zoomRange
        isTorchAvailable = await source.isTorchAvailable

        // A preference saved on a three-lens phone can be restored on a
        // single-lens one; fall back to the widest lens the hardware has
        // rather than selecting a lens that isn't there.
        let preferred = availableLenses.contains(settings.preferredLens)
            ? settings.preferredLens
            : (availableLenses.first ?? .wide)
        await select(lens: preferred)
        if settings.torchDefaultOn {
            await setTorch(true)
        }
    }

    /// Stops the session, extinguishing the torch first — leaving it lit
    /// after the user navigates away would quietly drain the battery, and a
    /// blind user has no way to notice it is still on.
    func stop() async {
        let previous = sessionTask
        let task = Task { [weak self] in
            await previous?.value
            await self?.performStop()
        }
        sessionTask = task
        await task.value
    }

    private func performStop() async {
        guard isRunning else { return }
        if isTorchOn {
            await setTorch(false)
        }
        await source.stop()
        isRunning = false
    }

    /// Captures one photo, publishing `isCapturing` around the call.
    ///
    /// Honors `-uiTestNoCamera` as well as `start(applying:)` does: a screen
    /// reached without starting the session would otherwise still capture a
    /// real frame, and the flag would hold on one path but not the other.
    func capturePhoto() async throws -> Data {
        guard !Self.forcesNoCamera else {
            throw CameraSource.CameraError.noCameraAvailable
        }
        isCapturing = true
        defer { isCapturing = false }
        return try await source.capturePhoto()
    }

    /// Selects `lens`, publishing the zoom factor it ramps toward. A no-op
    /// when the session isn't started or the device lacks that lens.
    func select(lens: CameraLens) async {
        guard let factor = await source.select(lens: lens) else { return }
        currentLens = lens
        zoomFactor = factor
    }

    /// Sets the zoom factor, clamped to `zoomRange`, coalescing intermediate
    /// values from a drag.
    ///
    /// Synchronous on purpose. A `Slider` binding fires dozens of times per
    /// second, and spawning one unstructured `Task` per tick did real
    /// hardware I/O (`lockForConfiguration`) on every intermediate frame —
    /// while giving no ordering guarantee, so an earlier value could reach
    /// the device last and leave the physical zoom behind where the user let
    /// go. This publishes immediately so the control still tracks the finger,
    /// then drains only the newest requested value to the device, one at a
    /// time.
    func setZoom(_ factor: Double) {
        let clamped = min(max(factor, zoomRange.lowerBound), zoomRange.upperBound)
        zoomFactor = clamped
        requestedZoom = clamped
        guard zoomDrainTask == nil else { return }
        zoomDrainTask = Task { [weak self] in
            while let next = self?.takeRequestedZoom() {
                await self?.source.setZoom(next)
            }
            self?.zoomDrainTask = nil
        }
    }

    /// Removes and returns the pending zoom request, or `nil` when the drain
    /// loop has caught up with the user.
    private func takeRequestedZoom() -> Double? {
        defer { requestedZoom = nil }
        return requestedZoom
    }

    /// Turns the torch on or off. Returns whether it took effect — `false`
    /// on hardware without a torch, which is routine variation, not an error.
    @discardableResult
    func setTorch(_ isOn: Bool) async -> Bool {
        let applied = await source.setTorch(isOn)
        if applied {
            isTorchOn = isOn
        }
        return applied
    }
}
