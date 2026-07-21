import UIKit

/// Posts a VoiceOver announcement for an async result, so the user is
/// never left stranded waiting for something that already finished — see
/// docs/ACCESSIBILITY.md "Deliberate focus management".
@MainActor
func announceToVoiceOver(_ message: String) {
    UIAccessibility.post(notification: .announcement, argument: message)
}
