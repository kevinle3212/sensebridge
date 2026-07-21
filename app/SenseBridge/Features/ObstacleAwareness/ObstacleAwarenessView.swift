import SwiftUI

/// The safety-framing disclaimer here is load-bearing, not boilerplate —
/// see docs/SAFETY-FRAMING.md: this must be stated plainly before first
/// use, not buried in settings.
struct ObstacleAwarenessView: View {
    /// Typed as `LocalizedStringKey` (not `String`) so these lookup the
    /// String Catalog by value at render time — a plain `String` property
    /// passed to `Text(_:)` renders verbatim, bypassing localization.
    private let disclaimer: LocalizedStringKey = """
    Obstacle awareness is not a safety or mobility device. It does not replace a \
    cane, a guide dog, or orientation-and-mobility training. It gives cautious, \
    probabilistic alerts only.
    """

    /// VoiceOver announces this instead of `disclaimer` so the safety
    /// caveat is front-loaded rather than trailing after the rest of the
    /// text.
    private let disclaimerAccessibilityLabel: LocalizedStringKey = """
    Important: obstacle awareness is not a safety or mobility device. It does not \
    replace a cane, a guide dog, or orientation-and-mobility training.
    """

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(disclaimer)
                .font(.callout)
                .accessibilityLabel(disclaimerAccessibilityLabel)
            Button("Start awareness") {
                // Pipeline: SensingSource (depth) -> AwarenessEngine -> Phrasing -> RenderTarget.
            }
            .accessibilityLabel("Start obstacle awareness")
            .accessibilityHint("Begins cautious alerts about what may be nearby. This is not a safety feature.")
        }
        .padding()
        .navigationTitle("Awareness")
    }
}

#Preview {
    ObstacleAwarenessView()
}
