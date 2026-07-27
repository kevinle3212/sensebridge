import SenseBridgeCore
import UIKit

/// Posts a VoiceOver announcement for an async result, so the user is
/// never left stranded waiting for something that already finished — see
/// docs/ACCESSIBILITY.md "Deliberate focus management".
@MainActor
func announceToVoiceOver(_ message: String) {
    UIAccessibility.post(notification: .announcement, argument: message)
}

/// Announces `message` only when `profile` has no speech channel.
///
/// The condition is the entire point. Under `.blind` the result is already
/// being spoken by `SpeechRenderTarget`, so announcing unconditionally would
/// say it twice — once as speech, once as a VoiceOver announcement that
/// interrupts the first. Under `.deafBlind` the only output is a short haptic
/// cue that carries no text at all, and a VoiceOver user who has braille
/// output attached would otherwise get nothing readable. This closes that gap
/// without introducing the double-speak.
@MainActor
func announceIfUnspoken(_ message: String, profile: OutputProfile) {
    guard !profile.preferredChannels.contains(.speech) else { return }
    announceToVoiceOver(message)
}
