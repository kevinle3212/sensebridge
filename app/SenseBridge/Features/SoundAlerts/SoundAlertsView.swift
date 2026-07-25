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
    private let renderTarget: SpeechRenderTarget = .init()
    @State private var lastResult: String?

    var body: some View {
        VStack(spacing: 16) {
            Text("Listens for recognizable sounds nearby and announces them.")
                .font(.body)
            Button("Start listening") {
                let message = phrasing.describe(subject: "a doorbell", certainty: .high)
                lastResult = message
                Task { await renderTarget.render(message) }
            }
            .accessibilityLabel("Start sound alerts")
            .accessibilityHint("Begins listening for recognizable sounds nearby.")
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
}
