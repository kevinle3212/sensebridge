import SenseBridgeCore
import SwiftUI

/// Reads aloud any text found in a single captured photo. Kept to one
/// capture button and a plain description of the flow, so a VoiceOver user
/// reaches the action without swiping through decorative layout — see
/// docs/ARCHITECTURE.md "Navigation". Camera → Vision OCR → Speech, entirely
/// on-device — see docs/ARCHITECTURE.md "Data flow — read this document".
struct ReadingView: View {
    private let cameraSource: CameraSource = .init()
    private let ocrService: OCRService = .init()
    private let renderTarget: SpeechRenderTarget = .init()

    @State private var lastResult: String?
    @State private var isCapturing = false

    var body: some View {
        VStack(spacing: 16) {
            Text("Point the camera at text, then capture, to hear it read aloud.")
                .font(.body)
            CameraPreviewView(cameraSource: cameraSource)
                .frame(height: 300)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                // A live camera feed has no accessible content of its own —
                // the capture button below is how a VoiceOver user drives
                // this screen, not the preview.
                .accessibilityHidden(true)
            Button("Capture") {
                Task { await captureAndRead() }
            }
            .disabled(isCapturing)
            .accessibilityLabel("Capture document")
            .accessibilityHint("Takes a photo and reads any text found aloud.")
            if let lastResult {
                Text(lastResult)
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .navigationTitle("Read")
        .task { await startCameraIfNeeded() }
        .onDisappear { Task { await cameraSource.stop() } }
    }

    private func startCameraIfNeeded() async {
        do {
            _ = try await cameraSource.start()
        } catch {
            lastResult = message(for: error)
        }
    }

    private func captureAndRead() async {
        isCapturing = true
        defer { isCapturing = false }
        do {
            let photo = try await cameraSource.capturePhoto()
            let records = try await ocrService.process(photo)
            let lines = records.compactMap { record -> String? in
                guard case let .recognizedText(text) = record.kind else { return nil }
                return text
            }
            let message = lines.isEmpty ? "No text was found in the photo." : lines.joined(separator: "\n")
            lastResult = message
            await renderTarget.render(message)
        } catch {
            let spoken = message(for: error)
            lastResult = spoken
            await renderTarget.render(spoken)
        }
    }

    private func message(for error: Error) -> String {
        switch error {
        case CameraSource.CameraError.authorizationDenied:
            "Camera access is needed to read text. Enable it in Settings."
        case CameraSource.CameraError.noCameraAvailable:
            "No camera is available on this device."
        default:
            "Couldn't read the photo. Try again."
        }
    }
}

#Preview {
    ReadingView()
}
