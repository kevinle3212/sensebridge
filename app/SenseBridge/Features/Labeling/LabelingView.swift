import SenseBridgeCore
import SwiftUI

/// Identifies an object from a single captured photo. Kept to one capture
/// button and a plain description of the flow, so a VoiceOver user reaches
/// the action without swiping through decorative layout — see
/// docs/ARCHITECTURE.md "Navigation". The result is a best-guess label, not
/// a guarantee of what the object is.
struct LabelingView: View {
    // ponytail: no DetectionService/camera SensingSource yet — hedges a
    // canned detection through the real Phrasing + RenderTarget. Swap in
    // Vision object detection + camera capture once those land.
    private let phrasing: Phrasing = .init()
    /// Shared app state — renders through the same output targets every
    /// other feature uses, rather than standing up its own synthesizer.
    @Environment(AppEnvironment.self) private var environment
    @State private var lastResult: String?

    var body: some View {
        VStack(spacing: 16) {
            Text("Point the camera at an object, then capture, to hear what it might be.")
                .font(.body)
            Button("Capture") {
                let message = phrasing.describe(subject: "a coffee mug", certainty: .medium)
                lastResult = message
                announceIfUnspoken(message, profile: environment.settings.outputProfile)
                Task { await environment.output.render(OutputMessage(text: message, signal: .resultReady)) }
            }
            .accessibilityLabel("Capture object")
            .accessibilityHint("Takes a photo and describes what's in it.")
            if let lastResult {
                Text(lastResult)
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .navigationTitle("Identify")
    }
}

#Preview {
    LabelingView()
        .environment(AppEnvironment())
}
