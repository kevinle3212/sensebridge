import SwiftUI

/// Listens for recognizable sounds nearby and announces them; not a
/// substitute for hearing. Kept to one start button and a plain description
/// of the flow, so a VoiceOver user reaches the action without swiping
/// through decorative layout — see docs/ARCHITECTURE.md "Navigation".
struct SoundAlertsView: View {
    var body: some View {
        VStack(spacing: 16) {
            Text("Listens for recognizable sounds nearby and announces them.")
                .font(.body)
            Button("Start listening") {
                // Pipeline: SensingSource (microphone) -> SoundService -> Phrasing -> RenderTarget.
            }
            .accessibilityLabel("Start sound alerts")
            .accessibilityHint("Begins listening for recognizable sounds nearby.")
        }
        .padding()
        .navigationTitle("Sounds")
    }
}

#Preview {
    SoundAlertsView()
}
