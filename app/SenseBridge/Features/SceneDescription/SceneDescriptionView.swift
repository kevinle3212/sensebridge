import SenseBridgeCore
import SwiftUI

/// Composes a hedged, best-effort description of what the camera sees in a
/// single captured photo — never asserts certainty about the scene. Kept to
/// one capture button and a plain description of the flow, so a VoiceOver
/// user reaches the action without swiping through decorative layout — see
/// docs/ARCHITECTURE.md "Navigation".
struct SceneDescriptionView: View {
    // ponytail: no Vision detect+OCR/camera SensingSource yet — composes
    // canned detection records through the real SceneComposer + RenderTarget.
    // Swap in real Vision + camera capture once those land.
    private let composer: LabelListSceneComposer = .init()
    private let renderTarget: SpeechRenderTarget = .init()
    @State private var lastResult: String?

    var body: some View {
        VStack(spacing: 16) {
            Text("Point the camera at a scene, then capture, for a hedged description of what's there.")
                .font(.body)
            Button("Capture") {
                Task {
                    let records = [
                        PerceptionRecord(kind: .detectedObject(label: "a chair", confidence: 0.85), capturedAt: .now),
                        PerceptionRecord(kind: .detectedObject(label: "a window", confidence: 0.6), capturedAt: .now)
                    ]
                    guard let message = try? await composer.compose(from: records) else { return }
                    lastResult = message
                    await renderTarget.render(message)
                }
            }
            .accessibilityLabel("Describe scene")
            .accessibilityHint("Takes a photo and composes a cautious description of what's in it.")
            if let lastResult {
                Text(lastResult)
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .navigationTitle("Describe")
    }
}

#Preview {
    SceneDescriptionView()
}
