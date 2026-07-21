import SwiftUI

/// Identifies an object from a single captured photo. Kept to one capture
/// button and a plain description of the flow, so a VoiceOver user reaches
/// the action without swiping through decorative layout — see
/// docs/ARCHITECTURE.md "Navigation". The result is a best-guess label, not
/// a guarantee of what the object is.
struct LabelingView: View {
    var body: some View {
        VStack(spacing: 16) {
            Text("Point the camera at an object, then capture, to hear what it might be.")
                .font(.body)
            Button("Capture") {
                // Pipeline: SensingSource (camera) -> DetectionService -> Phrasing -> RenderTarget.
            }
            .accessibilityLabel("Capture object")
            .accessibilityHint("Takes a photo and describes what's in it.")
        }
        .padding()
        .navigationTitle("Identify")
    }
}

#Preview {
    LabelingView()
}
