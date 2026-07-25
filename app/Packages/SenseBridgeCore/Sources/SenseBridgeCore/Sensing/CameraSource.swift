@preconcurrency import AVFoundation
import Foundation

/// Captures still photos from the device camera as JPEG `Data` — the
/// concrete `SensingSource` behind "Read" and "Describe" (see
/// docs/ARCHITECTURE.md "Sensing Layer"). An actor so session setup and
/// capture never run on the main thread, keeping VoiceOver responsive during
/// capture — see docs/ARCHITECTURE.md "Main thread stays free".
public actor CameraSource: SensingSource {
    public enum CameraError: Error, Sendable, Equatable {
        case authorizationDenied
        case noCameraAvailable
        case captureFailed
        case captureInProgress
        case notStarted
    }

    /// The underlying session, exposed so the app layer can attach an
    /// `AVCaptureVideoPreviewLayer` for on-screen framing. `AVCaptureSession`
    /// is documented by Apple as safe to read/observe from any thread; only
    /// this actor ever calls its configuration or run/stop methods.
    public nonisolated let session: AVCaptureSession = .init()

    private let photoOutput: AVCapturePhotoOutput = .init()
    private var streamContinuation: AsyncThrowingStream<Data, Error>.Continuation?
    private var pendingCapture: CheckedContinuation<Data, Error>?
    private var pendingDelegate: PhotoCaptureDelegate?

    // Empty but required: a public init is needed for cross-module init; nothing to initialize.
    // swiftlint:disable:next no_empty_block
    public init() {}

    public func start() async throws -> AsyncThrowingStream<Data, Error> {
        guard await Self.requestAuthorization() else {
            throw CameraError.authorizationDenied
        }
        guard let device = AVCaptureDevice.default(for: .video),
              let input = try? AVCaptureDeviceInput(device: device)
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
        session.startRunning()

        let (stream, continuation) = AsyncThrowingStream<Data, Error>.makeStream()
        streamContinuation = continuation
        return stream
    }

    public func stop() async {
        session.stopRunning()
        streamContinuation?.finish()
        streamContinuation = nil
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

    private static func requestAuthorization() async -> Bool {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized: true
        case .notDetermined: await AVCaptureDevice.requestAccess(for: .video)
        default: false
        }
    }
}

/// Bridges `AVCapturePhotoCaptureDelegate`'s Objective-C callback into a
/// single closure — the delegate protocol requires an `NSObject` subclass,
/// which is why this can't just be a closure held on `CameraSource` itself.
private final class PhotoCaptureDelegate: NSObject, AVCapturePhotoCaptureDelegate, Sendable {
    private let completion: @Sendable (Result<Data, Error>) -> Void

    init(completion: @escaping @Sendable (Result<Data, Error>) -> Void) {
        self.completion = completion
    }

    func photoOutput(_: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        if let error {
            completion(.failure(error))
            return
        }
        guard let data = photo.fileDataRepresentation() else {
            completion(.failure(CameraSource.CameraError.captureFailed))
            return
        }
        completion(.success(data))
    }
}
