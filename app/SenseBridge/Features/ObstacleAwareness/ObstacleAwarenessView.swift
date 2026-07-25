import SenseBridgeCore
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

    // ponytail: no depth SensingSource yet — feeds alternating mock depth
    // readings through the real AwarenessEngine + Phrasing + RenderTarget.
    // Swap in real ARKit/LiDAR depth capture once that lands.
    private let phrasing: Phrasing = .init()
    private let renderTarget: SpeechRenderTarget = .init()
    @State private var engine: AwarenessEngine = .init()
    @State private var isNearReading = true
    @State private var lastResult: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(disclaimer)
                .font(.callout)
                .accessibilityLabel(disclaimerAccessibilityLabel)
            Button("Start awareness") {
                let mockDepthMeters = isNearReading ? 1.0 : 3.0
                isNearReading.toggle()
                let isAlerting = engine.evaluate(depthMeters: mockDepthMeters)
                let message = isAlerting
                    ? phrasing.describe(subject: "something ahead", certainty: .medium)
                    : "The way ahead seems clear for now."
                lastResult = message
                Task { await renderTarget.render(message) }
            }
            .accessibilityLabel("Start obstacle awareness")
            .accessibilityHint("Begins cautious alerts about what may be nearby. This is not a safety feature.")
            if let lastResult {
                Text(lastResult)
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .navigationTitle("Awareness")
    }
}

#Preview {
    ObstacleAwarenessView()
}
