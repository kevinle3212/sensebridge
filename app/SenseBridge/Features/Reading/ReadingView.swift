import SwiftUI

/// Reads aloud any text found in a single captured photo. Kept to one
/// capture button and a plain description of the flow, so a VoiceOver user
/// reaches the action without swiping through decorative layout — see
/// docs/ARCHITECTURE.md "Navigation".
struct ReadingView: View {
    var body: some View {
        VStack(spacing: 16) {
            Text("Point the camera at text, then capture, to hear it read aloud.")
                .font(.body)
            Button("Capture") {
                // Pipeline: SensingSource (camera) -> OCRService -> Phrasing -> RenderTarget.
            }
            .accessibilityLabel("Capture document")
            .accessibilityHint("Takes a photo and reads any text found aloud.")
        }
        .padding()
        .navigationTitle("Read")
    }
}

#Preview {
    ReadingView()
}
