// Both length rules are waived for this file. The two genuinely separable
// pieces are already extracted (`CameraDeviceResolution.swift`,
// `PhotoCaptureDelegate.swift`); what remains is one cohesive unit — the
// capture session's lifecycle — whose stored state (`pendingCapture`,
// `streamContinuation`, `notificationObservers`, `rotationObservation`) is
// deliberately `private`. Splitting further would force those to `internal`
// purely to satisfy a line count, weakening exactly the isolation this actor
// exists to provide. The real fix is extracting rotation tracking into its
// own type, which is logged on the repo's to-do list rather than rushed under
// a lint deadline.
// swiftlint:disable file_length
//
// `@preconcurrency` is justified for `AVCaptureSession` and
// `AVCaptureDevice` specifically — Apple documents both as usable across
// threads — but it silences Sendable diagnostics for *every* AVFoundation
// type in this file. It is not blanket cover: anything added here that
// crosses an isolation boundary (an `AVCapturePhoto`, say) needs its own
// justification, because the compiler will no longer ask for one.
@preconcurrency import AVFoundation
import Foundation
#if canImport(UIKit)
    import UIKit
#endif

// swiftlint:disable type_body_length
/// Captures still photos from the device camera as JPEG `Data` — the
/// concrete `SensingSource` behind "Read" and "Describe" (see
/// docs/ARCHITECTURE.md "Sensing Layer"). An actor so session setup and
/// capture never run on the main thread, keeping VoiceOver responsive during
/// capture — see docs/ARCHITECTURE.md "Main thread stays free".
///
/// Prefers the device's virtual multi-lens camera (triple → dual-wide → dual
/// → single wide, whichever the hardware has) over binding to one physical
/// lens, so every lens in `availableLenses` is reachable through a single
/// `AVCaptureDeviceInput` and `videoZoomFactor` ramps continuously across
/// lenses. Swapping inputs per lens instead would glitch the preview and
/// break continuous zoom.
public actor CameraSource: SensingSource {
    public enum CameraError: Error, Sendable, Equatable {
        case authorizationDenied
        case noCameraAvailable
        case captureFailed
        case captureInProgress
        case notStarted
        /// The session stopped (the app backgrounded, or `stop()` was called)
        /// while a capture was in flight, so its photo will never arrive.
        case sessionStopped
    }

    /// Camera permission state, mirroring `AVAuthorizationStatus` without
    /// putting an AVFoundation type on this package's public surface. Exists
    /// so the App layer can tell "haven't asked yet" (show the system
    /// prompt) apart from "denied" (only Settings can change that; showing
    /// the same prompt again is a dead end) — `CameraError.authorizationDenied`
    /// alone can't make that distinction.
    public enum AuthorizationStatus: Sendable, Equatable {
        /// Never asked; `start()` will show the system permission prompt.
        case notDetermined
        /// Access is granted.
        case authorized
        /// The user declined; `start()` throws `.authorizationDenied` without
        /// prompting again. Route the user to Settings instead.
        case denied
        /// Blocked by a system policy (e.g. parental controls). Settings
        /// cannot change this either.
        case restricted
    }

    /// The underlying session, exposed so the app layer can attach an
    /// `AVCaptureVideoPreviewLayer` for on-screen framing.
    ///
    /// **Attach a preview layer to this and nothing else.** Being
    /// `nonisolated` makes it a deliberate hole in this actor's isolation:
    /// any caller can reach it and invoke `beginConfiguration()`,
    /// `addInput(_:)` or `stopRunning()` directly, racing this actor's own
    /// calls, and the compiler will not stop them. Apple's documented
    /// thread-safety covers reading `isRunning`, KVO observation, and
    /// blocking `startRunning()`/`stopRunning()` from a background thread —
    /// it does **not** extend to two uncoordinated call sites mutating
    /// configuration. "Only this actor configures the session" is therefore a
    /// convention this comment asks you to keep, not an invariant the type
    /// system enforces.
    public nonisolated let session: AVCaptureSession = .init()

    /// The lenses available on the resolved device, widest to narrowest.
    /// `[.wide]` until `start()` resolves a device, and thereafter on any
    /// single-lens device — see `Self.lenses(for:)`.
    public private(set) var availableLenses: [CameraLens] = [.wide]

    private let photoOutput: AVCapturePhotoOutput = .init()
    private var streamContinuation: AsyncThrowingStream<Data, Error>.Continuation?
    private var pendingCapture: CheckedContinuation<Data, Error>?
    private var pendingDelegate: PhotoCaptureDelegate?

    /// The resolved capture device. `nil` until the first `start()` call
    /// configures the session; kept alive afterward (never cleared by
    /// `stop()`) so a later `start()` can just resume `session.startRunning()`
    /// instead of re-adding an input `AVCaptureSession` would then reject.
    private var device: AVCaptureDevice?

    /// The single in-flight `start()`, so concurrent callers share one
    /// startup instead of racing — see `start()`. Cleared by `stop()` and on
    /// failure.
    private var startTask: Task<AsyncThrowingStream<Data, Error>, Error>?

    #if os(iOS)
        /// Declared iOS-only because zoom is: macOS AVFoundation exposes no
        /// `videoZoomFactor` at all, so on that platform this would be a
        /// stored property provably never written and never read.
        private var zoomFactorsByLens: [CameraLens: Double] = [:]
    #endif

    /// Tracks the device's rotation as it changes so a photo captured while
    /// the phone is in landscape still reaches Vision OCR upright — the app
    /// is portrait-locked, but the phone is not. `nil` until `start()` resolves
    /// a device.
    private var rotationCoordinator: AVCaptureDevice.RotationCoordinator?
    /// Keeps `horizonLevelCaptureAngle` current via KVO; invalidated
    /// automatically when replaced or when this actor deinitializes.
    private var rotationObservation: NSKeyValueObservation?
    /// The rotation angle applied to the photo connection before each
    /// capture. Cached from `rotationCoordinator` (rather than read fresh
    /// off the main-queue-delivered KVO value at capture time) so
    /// `capturePhoto()` never has to hop to the main queue to read it.
    private var horizonLevelCaptureAngle: CGFloat = 0

    /// Tokens for the interruption/runtime-error/background notifications
    /// registered in `start()`; removed in `stop()` so a later `start()` on
    /// the same instance doesn't register duplicate observers.
    private var notificationObservers: [NSObjectProtocol] = []

    /// A moderate zoom-ramp speed for `select(lens:)` transitions — fast
    /// enough to feel responsive, slow enough not to blur the frame mid-ramp.
    /// Fixed rather than configurable: there is no caller-specific need for a
    /// different speed.
    private static let zoomRampRate: Float = 8

    // Empty but required: a public init is needed for cross-module init; nothing to initialize.
    // swiftlint:disable:next no_empty_block
    public init() {}

    /// The current camera permission state, queryable without calling
    /// `start()` — see `AuthorizationStatus`.
    public nonisolated static var authorizationStatus: AuthorizationStatus {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized: .authorized
        case .notDetermined: .notDetermined
        case .restricted: .restricted
        case .denied: .denied
        @unknown default: .denied
        }
    }

    /// Starts the capture session, returning a stream that yields every
    /// subsequent capture.
    ///
    /// Safe against concurrent callers, which is not automatic: the
    /// authorization request below is a suspension point, and actors are
    /// reentrant across `await`. A second `start()` entering that window
    /// would re-register every lifecycle observer and overwrite
    /// `streamContinuation`, orphaning the first stream's continuation with
    /// no consumer ever seeing another value or a completion. Holding the
    /// single in-flight `Task` and awaiting it makes the second caller share
    /// the first call's result instead of racing it — and makes the
    /// "idempotent" claim true for concurrent calls, not just sequential ones.
    public func start() async throws -> AsyncThrowingStream<Data, Error> {
        if let startTask {
            return try await startTask.value
        }
        let task = Task { try await performStart() }
        startTask = task
        do {
            return try await task.value
        } catch {
            // Leave no failed task cached, or every later `start()` would
            // replay the same failure instead of retrying.
            startTask = nil
            throw error
        }
    }

    private func performStart() async throws -> AsyncThrowingStream<Data, Error> {
        guard await Self.requestAuthorization() else {
            throw CameraError.authorizationDenied
        }

        // First-time setup only: session input/output are added exactly
        // once ever, since `AVCaptureSession.canAddInput` would silently
        // refuse a duplicate input for the same device on a later `start()`
        // and re-running this block would re-register the observers below.
        if device == nil {
            guard let selectedDevice = Self.discoverDevice(),
                  let input = try? AVCaptureDeviceInput(device: selectedDevice)
            else {
                throw CameraError.noCameraAvailable
            }

            session.beginConfiguration()
            session.sessionPreset = .photo
            if session.canAddInput(input) {
                session.addInput(input)
            }
            if session.canAddOutput(photoOutput) {
                session.addOutput(photoOutput)
            }
            session.commitConfiguration()

            device = selectedDevice
            availableLenses = Self.lenses(for: selectedDevice)
            #if os(iOS)
                zoomFactorsByLens = CameraConfiguration.zoomFactors(
                    constituents: availableLenses,
                    switchOverFactors: selectedDevice.virtualDeviceSwitchOverVideoZoomFactors.map(\.doubleValue)
                )
            #endif
            configureCenterFocusAndExposure(on: selectedDevice)
            configureRotationTracking(for: selectedDevice)
        }

        observeLifecycleNotifications()
        session.startRunning()

        let (stream, continuation) = AsyncThrowingStream<Data, Error>.makeStream()
        streamContinuation = continuation
        return stream
    }

    public func stop() async {
        session.stopRunning()
        for observer in notificationObservers {
            NotificationCenter.default.removeObserver(observer)
        }
        notificationObservers.removeAll()
        failPendingCapture(with: .sessionStopped)
        streamContinuation?.finish()
        streamContinuation = nil
        startTask = nil
    }

    /// Fails an in-flight capture whose delegate callback will now never
    /// arrive, because the session stopped underneath it.
    ///
    /// Without this the continuation is never resumed, and the damage is
    /// worse than one hung `await`: `pendingCapture` stays non-nil forever,
    /// so `capturePhoto()`'s `captureInProgress` guard rejects **every**
    /// later capture on this instance. Capture silently stops working for
    /// the rest of the process lifetime, with no error surfaced anywhere.
    /// Backgrounding the app mid-capture is enough to trigger it.
    private func failPendingCapture(with error: CameraError) {
        pendingDelegate = nil
        guard let capture = pendingCapture else { return }
        pendingCapture = nil
        capture.resume(throwing: error)
    }

    /// Selects a lens by ramping `videoZoomFactor` to the factor that
    /// selects it, computed by `CameraConfiguration` from this device's
    /// constituent lenses and switch-over factors. A no-op if `start()`
    /// hasn't resolved a device yet, or if `lens` isn't one of this device's
    /// constituents (e.g. `.telephoto` on a dual-wide device) — there is no
    /// unsupported-lens error case because "not every device has every lens"
    /// is an expected, not exceptional, condition. Also a no-op on macOS,
    /// which exposes no zoom control at all — the method stays on the API
    /// surface so callers need no platform branch of their own.
    ///
    /// Returns the zoom factor the device is ramping toward, or `nil` when
    /// the call was a no-op — the ramp is animated, so reading
    /// `videoZoomFactor` back immediately would report the pre-ramp value,
    /// and a UI showing current zoom needs the target instead.
    @discardableResult
    public func select(lens: CameraLens) async -> Double? {
        #if os(iOS)
            guard let device, let factor = zoomFactorsByLens[lens] else { return nil }
            guard (try? device.lockForConfiguration()) != nil else { return nil }
            defer { device.unlockForConfiguration() }
            device.ramp(toVideoZoomFactor: CGFloat(factor), withRate: Self.zoomRampRate)
            return factor
        #else
            return nil
        #endif
    }

    /// Whether the resolved device has a torch to control. `false` until
    /// `start()` resolves a device, and on hardware without one — so a UI can
    /// omit the torch control entirely rather than offering a dead toggle.
    public var isTorchAvailable: Bool {
        device?.hasTorch ?? false
    }

    /// The zoom range the resolved device supports, for a UI slider's bounds.
    /// `1...1` until `start()` resolves a device, and on macOS, where
    /// AVFoundation exposes no zoom control — a degenerate range a slider
    /// reads as "nothing to adjust".
    public var zoomRange: ClosedRange<Double> {
        #if os(iOS)
            guard let device else { return 1 ... 1 }
            let lower = Double(device.minAvailableVideoZoomFactor)
            let upper = Double(device.maxAvailableVideoZoomFactor)
            return lower <= upper ? lower ... upper : 1 ... 1
        #else
            return 1 ... 1
        #endif
    }

    /// Sets `videoZoomFactor` directly to `factor`, clamped into the
    /// device's supported range. A no-op if `start()` hasn't resolved a
    /// device yet, and on macOS — see `select(lens:)`.
    public func setZoom(_ factor: Double) async {
        #if os(iOS)
            guard let device else { return }
            let clamped = CameraConfiguration.clampZoom(
                factor,
                min: Double(device.minAvailableVideoZoomFactor),
                max: Double(device.maxAvailableVideoZoomFactor)
            )
            guard (try? device.lockForConfiguration()) != nil else { return }
            defer { device.unlockForConfiguration() }
            device.videoZoomFactor = CGFloat(clamped)
        #endif
    }

    /// Sets the torch on or off. Returns whether the request took effect —
    /// devices without a torch (most Macs, some iPhone lens configurations
    /// mid-zoom) report `false` rather than throwing, since a missing torch
    /// is routine hardware variation, not a failure.
    @discardableResult
    public func setTorch(_ isOn: Bool) async -> Bool {
        guard let device, device.hasTorch else { return false }
        let mode: AVCaptureDevice.TorchMode = isOn ? .on : .off
        guard device.isTorchModeSupported(mode) else { return false }
        guard (try? device.lockForConfiguration()) != nil else { return false }
        defer { device.unlockForConfiguration() }
        device.torchMode = mode
        return true
    }

    /// Captures a single photo and returns its JPEG data directly — the
    /// simple request/response path a single "Capture" button wants. The
    /// same data is also delivered through the stream from `start()`, for a
    /// future consumer that wants to observe every capture as it happens.
    public func capturePhoto() async throws -> Data {
        guard streamContinuation != nil else { throw CameraError.notStarted }
        // A capture already in flight would otherwise overwrite
        // `pendingCapture` below, permanently orphaning its continuation —
        // reject the overlapping call instead of leaking a hung `await`.
        guard pendingCapture == nil else { throw CameraError.captureInProgress }
        applyHorizonLevelRotation()
        return try await withCheckedThrowingContinuation { continuation in
            pendingCapture = continuation
            let delegate = PhotoCaptureDelegate { [weak self] result in
                Task { await self?.handleCaptureResult(result) }
            }
            pendingDelegate = delegate
            photoOutput.capturePhoto(with: AVCapturePhotoSettings(), delegate: delegate)
        }
    }

    private func handleCaptureResult(_ result: Result<Data, Error>) {
        pendingDelegate = nil
        let capture = pendingCapture
        pendingCapture = nil
        switch result {
        case let .success(data):
            streamContinuation?.yield(data)
            capture?.resume(returning: data)
        case let .failure(error):
            streamContinuation?.finish(throwing: error)
            capture?.resume(throwing: error)
        }
    }

    /// Applies the horizon-level rotation angle to the photo output's video
    /// connection before capture — without this, a photo taken while the
    /// phone is physically rotated (the app is portrait-locked, but the
    /// phone isn't) reaches Vision OCR sideways and recognition quality
    /// degrades. A no-op if the connection can't support the exact angle
    /// (only 0/90/180/270 are ever valid, which is all this ever produces).
    private func applyHorizonLevelRotation() {
        guard let connection = photoOutput.connection(with: .video),
              connection.isVideoRotationAngleSupported(horizonLevelCaptureAngle)
        else { return }
        connection.videoRotationAngle = horizonLevelCaptureAngle
    }

    /// Creates the rotation coordinator for `device` and seeds/observes
    /// `horizonLevelCaptureAngle`. No `previewLayer` is passed — this actor
    /// doesn't own the App layer's preview layer, and the capture-side angle
    /// (unlike the preview-side one) doesn't depend on it.
    private func configureRotationTracking(for device: AVCaptureDevice) {
        let coordinator = AVCaptureDevice.RotationCoordinator(device: device, previewLayer: nil)
        rotationCoordinator = coordinator
        horizonLevelCaptureAngle = coordinator.videoRotationAngleForHorizonLevelCapture
        rotationObservation = coordinator.observe(
            \.videoRotationAngleForHorizonLevelCapture,
            options: [.new]
        ) { [weak self] _, change in
            guard let angle = change.newValue else { return }
            Task { await self?.setHorizonLevelCaptureAngle(angle) }
        }
    }

    private func setHorizonLevelCaptureAngle(_ angle: CGFloat) {
        horizonLevelCaptureAngle = angle
    }

    /// Sets continuous autofocus/autoexposure anchored at the frame's
    /// centre. There is no tap-to-focus UI — a blind user has no way to tap
    /// a subject they can't see — so continuous focus on the centre of frame
    /// is the only default that makes sense.
    private func configureCenterFocusAndExposure(on device: AVCaptureDevice) {
        guard (try? device.lockForConfiguration()) != nil else { return }
        defer { device.unlockForConfiguration() }

        let center = CGPoint(x: 0.5, y: 0.5)
        if device.isFocusPointOfInterestSupported {
            device.focusPointOfInterest = center
        }
        if device.isFocusModeSupported(.continuousAutoFocus) {
            device.focusMode = .continuousAutoFocus
        }
        if device.isExposurePointOfInterestSupported {
            device.exposurePointOfInterest = center
        }
        if device.isExposureModeSupported(.continuousAutoExposure) {
            device.exposureMode = .continuousAutoExposure
        }
    }

    /// Registers recovery for the ways a capture session silently dies
    /// without them: a phone call or another app taking the camera
    /// (interruption), the OS resetting media services (runtime error), and
    /// the app backgrounding. `AVCaptureSessionWasInterruptedNotification`
    /// needs no handler of its own — the session already stops itself when
    /// interrupted: the only action needed is resuming once it ends.
    private func observeLifecycleNotifications() {
        let center = NotificationCenter.default
        notificationObservers.append(center.addObserver(
            forName: AVCaptureSession.interruptionEndedNotification, object: session, queue: nil
        ) { [weak self] _ in
            Task { await self?.resumeIfActive() }
        })
        notificationObservers.append(center.addObserver(
            forName: AVCaptureSession.runtimeErrorNotification, object: session, queue: nil
        ) { [weak self] _ in
            Task { await self?.resumeIfActive() }
        })
        #if canImport(UIKit)
            notificationObservers.append(center.addObserver(
                forName: UIApplication.didEnterBackgroundNotification, object: nil, queue: nil
            ) { [weak self] _ in
                Task { await self?.pauseForBackground() }
            })
            notificationObservers.append(center.addObserver(
                forName: UIApplication.willEnterForegroundNotification, object: nil, queue: nil
            ) { [weak self] _ in
                Task { await self?.resumeIfActive() }
            })
        #endif
    }

    /// Restarts a session that stopped for a reason other than the app
    /// calling `stop()` — guarded on `streamContinuation` so a runtime error
    /// or backgrounding delivered after an intentional `stop()` doesn't
    /// resurrect the session behind the app's back.
    private func resumeIfActive() {
        guard streamContinuation != nil, !session.isRunning else { return }
        session.startRunning()
    }

    private func pauseForBackground() {
        session.stopRunning()
        // The photo delegate will not fire once the session stops — see
        // `failPendingCapture(with:)` for why leaving it pending would wedge
        // capture permanently rather than merely losing this one photo.
        failPendingCapture(with: .sessionStopped)
    }

    private static func requestAuthorization() async -> Bool {
        switch authorizationStatus {
        case .authorized: true
        case .notDetermined: await AVCaptureDevice.requestAccess(for: .video)
        case .denied, .restricted: false
        }
    }
}

// swiftlint:enable type_body_length
// swiftlint:enable file_length
