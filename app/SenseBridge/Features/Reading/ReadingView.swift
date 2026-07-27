import SenseBridgeCore
import SwiftUI
import UIKit

/// Reads aloud any text found in a single captured photo. Kept to one
/// capture button and a plain description of the flow, so a VoiceOver user
/// reaches the action without swiping through decorative layout — see
/// docs/ARCHITECTURE.md "Navigation". Camera → Vision OCR → Speech, entirely
/// on-device — see docs/ARCHITECTURE.md "Data flow — read this document".
struct ReadingView: View {
    /// Shared app state — the camera session and output targets live here so
    /// every feature drives the same instances rather than each standing up
    /// its own.
    @Environment(AppEnvironment.self) private var environment

    private let ocrService: OCRService = .init()

    @State private var lastResult: String?

    var body: some View {
        VStack(spacing: 16) {
            Text("Point the camera at text, then capture, to hear it read aloud.")
                .font(.body)
            CameraPreviewView(cameraSource: environment.camera.source)
                .frame(height: 300)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                // A live camera feed has no accessible content of its own —
                // the capture button below is how a VoiceOver user drives
                // this screen, not the preview.
                .accessibilityHidden(true)
            CameraControlsView(camera: environment.camera)
            Button("Capture") {
                Task { await captureAndRead() }
            }
            .disabled(environment.camera.isCapturing)
            .accessibilityLabel("Capture document")
            // Capture is asynchronous and the button disables itself while it
            // runs. Without a value, a VoiceOver user gets a control that has
            // simply gone dim with no explanation of why or for how long.
            .accessibilityValue(environment.camera.isCapturing ? "Capturing" : "")
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
        .onDisappear { Task { await environment.camera.stop() } }
    }

    private func startCameraIfNeeded() async {
        await environment.camera.start(applying: environment.settings)
        // A start failure must reach the user, not just get swallowed —
        // `start(applying:)` records it rather than throwing.
        if let startError = environment.camera.startError {
            let spoken = message(for: startError)
            lastResult = spoken
            announceIfUnspoken(spoken, profile: environment.settings.outputProfile)
            await environment.output.render(OutputMessage(text: spoken, signal: .error))
        } else {
            // The lens/zoom/torch controls only exist once a device is
            // resolved, so they appear *after* this screen has already been
            // read out. Without this the new controls are simply absent from
            // the VoiceOver user's model of the screen until they swipe past
            // where they now are.
            UIAccessibility.post(notification: .layoutChanged, argument: nil)
        }
    }

    private func captureAndRead() async {
        do {
            let photo = try await environment.camera.capturePhoto()
            let records = try await ocrService.process(photo)
            let lines = records.compactMap { record -> String? in
                guard case let .recognizedText(text) = record.kind else { return nil }
                return text
            }
            let message = lines.isEmpty
                ? OutputMessage(text: "No text was found in the photo.", signal: .nothingFound)
                : OutputMessage(text: lines.joined(separator: "\n"), signal: .resultReady)
            lastResult = message.text
            announceIfUnspoken(message.text, profile: environment.settings.outputProfile)
            await environment.output.render(message)
        } catch {
            let spoken = message(for: error)
            lastResult = spoken
            announceIfUnspoken(spoken, profile: environment.settings.outputProfile)
            await environment.output.render(OutputMessage(text: spoken, signal: .error))
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
        .environment(AppEnvironment())
}
