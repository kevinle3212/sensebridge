@preconcurrency import AVFoundation
import SenseBridgeCore
import SwiftUI

/// Live camera feed so a sighted companion (or a low-vision user with some
/// usable vision) can help aim the phone at text. VoiceOver users drive the
/// feature by the capture button alone, not this preview — see it marked
/// `accessibilityHidden` at the call site, since a live video feed has no
/// accessible content to expose. Wraps `AVCaptureVideoPreviewLayer` because
/// SwiftUI has no native camera preview view.
struct CameraPreviewView: UIViewRepresentable {
    let cameraSource: CameraSource

    func makeUIView(context _: Context) -> PreviewUIView {
        let view = PreviewUIView()
        view.videoPreviewLayer.session = cameraSource.session
        view.videoPreviewLayer.videoGravity = .resizeAspectFill
        return view
    }

    // Empty but required by UIViewRepresentable; the session is set once in makeUIView and
    // AVCaptureVideoPreviewLayer follows it automatically, so there's nothing to update.
    // swiftlint:disable:next no_empty_block
    func updateUIView(_: PreviewUIView, context _: Context) {}

    final class PreviewUIView: UIView {
        override static var layerClass: AnyClass {
            AVCaptureVideoPreviewLayer.self
        }

        var videoPreviewLayer: AVCaptureVideoPreviewLayer {
            guard let layer = layer as? AVCaptureVideoPreviewLayer else {
                preconditionFailure("PreviewUIView.layerClass must stay AVCaptureVideoPreviewLayer")
            }
            return layer
        }
    }
}
