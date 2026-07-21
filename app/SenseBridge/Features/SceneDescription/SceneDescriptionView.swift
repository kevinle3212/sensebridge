import SwiftUI

/// Composes a hedged, best-effort description of what the camera sees in a
/// single captured photo — never asserts certainty about the scene. Kept to
/// one capture button and a plain description of the flow, so a VoiceOver
/// user reaches the action without swiping through decorative layout — see
/// docs/ARCHITECTURE.md "Navigation".
struct SceneDescriptionView: View {
    var body: some View {
        VStack(spacing: 16) {
            Text("Point the camera at a scene, then capture, for a hedged description of what's there.")
                .font(.body)
            Button("Capture") {
                // Pipeline: SensingSource (camera) -> Vision detect+OCR -> SceneComposer -> RenderTarget.
            }
            .accessibilityLabel("Describe scene")
            .accessibilityHint("Takes a photo and composes a cautious description of what's in it.")
        }
        .padding()
        .navigationTitle("Describe")
    }
}

#Preview {
    SceneDescriptionView()
}
