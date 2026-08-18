import SenseBridgeCore
import SwiftUI
import UIKit

/// A button that opens SenseBridge's own page in the Settings app.
///
/// Shown only after a permission has actually been denied. iOS asks for camera
/// and microphone access exactly once; every later attempt fails silently from
/// the app's point of view, so "Enable it in Settings" on its own is a dead end
/// — it names a destination and offers no way to get there. For a blind user
/// that is worse than for a sighted one: leaving the app, finding SenseBridge
/// in a long Settings list, and finding the right toggle is a far longer
/// journey by VoiceOver than one button.
///
/// Shared by all four sensor-gated screens (Read, Identify, Describe, Sounds)
/// rather than reimplemented per screen — the copy, the hint, and the URL are
/// the same everywhere, and four copies would drift.
struct OpenSettingsButton: View {
    @Environment(\.openURL) private var openURL

    /// Whether `error` is the one failure a user can only fix in Settings.
    ///
    /// Deliberately narrow: a missing camera, a failed capture, or an OCR miss
    /// are all things Settings cannot help with, and offering the button for
    /// them would send someone on a pointless trip through a system app.
    static func canResolve(_ error: Error) -> Bool {
        switch error {
        case CameraSource.CameraError.authorizationDenied,
             MicrophoneSensingSource.MicrophoneError.authorizationDenied:
            true
        default:
            false
        }
    }

    var body: some View {
        if let url = URL(string: UIApplication.openSettingsURLString) {
            Button("Open Settings") { openURL(url) }
                .accessibilityHint("""
                Opens SenseBridge in the Settings app, where camera and \
                microphone access can be turned back on.
                """)
        }
    }
}

#Preview {
    OpenSettingsButton()
}
