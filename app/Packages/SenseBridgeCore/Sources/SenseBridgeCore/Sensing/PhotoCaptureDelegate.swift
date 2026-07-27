@preconcurrency import AVFoundation
import Foundation

/// Bridges `AVCapturePhotoCaptureDelegate`'s Objective-C callback into a
/// single closure — the delegate protocol requires an `NSObject` subclass,
/// which is why this can't just be a closure held on `CameraSource` itself.
///
/// The `Sendable` conformance is sound only because every stored property is
/// an immutable `let`. If you need mutable state here, remove the state —
/// don't reach for `@unchecked Sendable`, which would silently drop the
/// checking that currently makes this safe.
final class PhotoCaptureDelegate: NSObject, AVCapturePhotoCaptureDelegate, Sendable {
    private let completion: @Sendable (Result<Data, Error>) -> Void

    /// Creates a delegate that forwards its single callback to `completion`.
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
