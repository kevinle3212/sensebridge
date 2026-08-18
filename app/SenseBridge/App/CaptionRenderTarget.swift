import Observation
import SenseBridgeCore

/// Shows the most recent textual output as an on-screen caption.
///
/// This is deliberately an app-layer target: the Core package owns the
/// device-independent ``RenderTarget`` protocol, while this type owns the
/// SwiftUI-observable state that draws on screen. A message with no prose
/// carries a signal only (`.captureTaken`, say) and clears the previous
/// caption, so a result from an old camera frame is not left on screen as if
/// it described the frame now being captured.
@MainActor
@Observable
final class CaptionRenderTarget: RenderTarget {
    /// The current caption, or `nil` while there is no textual result to show.
    private(set) var text: String?

    /// Replaces the visible caption with this message's already-hedged text.
    func render(_ message: OutputMessage) async {
        let trimmed = message.text.trimmingCharacters(in: .whitespacesAndNewlines)
        text = trimmed.isEmpty ? nil : trimmed
    }
}
