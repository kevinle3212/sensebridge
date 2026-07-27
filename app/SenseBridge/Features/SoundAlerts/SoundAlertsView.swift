import SenseBridgeCore
import SwiftUI

/// Listens for recognizable sounds nearby and announces them; not a
/// substitute for hearing. Kept to one start button and a plain description
/// of the flow, so a VoiceOver user reaches the action without swiping
/// through decorative layout — see docs/ARCHITECTURE.md "Navigation".
struct SoundAlertsView: View {
    // ponytail: no SoundService/microphone SensingSource yet — hedges a
    // canned detection through the real Phrasing + RenderTarget. Swap in
    // Sound Analysis + microphone capture once those land.
    private let phrasing: Phrasing = .init()
    /// Shared app state — renders through the same output targets every
    /// other feature uses, rather than standing up its own synthesizer.
    @Environment(AppEnvironment.self) private var environment
    @State private var lastResult: String?

    var body: some View {
        VStack(spacing: 16) {
            Text("Listens once for a recognizable sound nearby and announces what it might be.")
                .font(.body)
            // "Listen once", not "Start listening". One tap is one sample; a
            // user who believes the app is monitoring continuously would read
            // the silence in between as "no sound happened".
            Button("Listen once") {
                let message = phrasing.describe(subject: "a doorbell", certainty: .high)
                lastResult = message
                announceIfUnspoken(message, profile: environment.settings.outputProfile)
                Task { await environment.output.render(OutputMessage(text: message, signal: .resultReady)) }
            }
            .accessibilityLabel("Listen once for sounds")
            .accessibilityHint("Takes one listen for a recognizable sound nearby. It does not keep listening.")
            if let lastResult {
                Text(lastResult)
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .navigationTitle("Sounds")
    }
}

#Preview {
    SoundAlertsView()
        .environment(AppEnvironment())
}
