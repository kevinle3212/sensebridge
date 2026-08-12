import SenseBridgeCore
import SwiftUI
import UIKit

/// Identifies an object from a single captured photo. Kept to one capture
/// button and a plain description of the flow, so a VoiceOver user reaches
/// the action without swiping through decorative layout — see
/// docs/ARCHITECTURE.md "Navigation". The result is a best-guess label, not
/// a guarantee of what the object is.
struct LabelingView: View {
    /// Shared app state — the camera session and output targets live here so
    /// every feature drives the same instances rather than each standing up
    /// its own.
    @Environment(AppEnvironment.self) private var environment
    @State private var lastResult: String?

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                Text("Point the camera at an object, then capture, to hear what it might be.")
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
                    Task { await captureAndIdentify() }
                }
                .disabled(environment.camera.isCapturing)
                .accessibilityLabel("Capture object")
                .accessibilityValue(environment.camera.isCapturing ? "Capturing" : "")
                .accessibilityHint("Takes a photo and describes what's in it.")
                if let lastResult {
                    Text(lastResult)
                        .font(.callout)
                        .foregroundStyle(Color("SecondaryText"))
                }
            }
            .padding()
        }
        .navigationTitle("Identify")
        .task { await startCameraIfNeeded() }
        .onDisappear { Task { await environment.camera.stop() } }
    }

    private func startCameraIfNeeded() async {
        await environment.camera.start(applying: environment.settings)
        if let startError = environment.camera.startError {
            let spoken = message(for: startError)
            lastResult = spoken
            announceIfUnspoken(spoken, profile: environment.settings.outputProfile)
            await environment.output.render(OutputMessage(text: spoken, signal: .error))
        } else {
            UIAccessibility.post(notification: .layoutChanged, argument: nil)
        }
    }

    private func captureAndIdentify() async {
        do {
            let classifier = ObjectClassificationService(
                maximumLabels: environment.settings.spokenDetail.maximumLabels
            )
            let photo = try await environment.camera.capturePhoto()
            let records = try await classifier.process(photo)
            let phrasing = Phrasing()
            let message: String = if case let .detectedObject(label, confidence)? = records.first?.kind {
                phrasing.describe(
                    subject: label,
                    certainty: Phrasing.certainty(forConfidence: confidence)
                )
            } else {
                phrasing.nothingRecognized()
            }
            lastResult = message
            announceIfUnspoken(message, profile: environment.settings.outputProfile)
            await environment.output.render(OutputMessage(text: message, signal: .resultReady))
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
            "Camera access is needed to identify objects. Enable it in Settings."
        case CameraSource.CameraError.noCameraAvailable:
            "No camera is available on this device."
        default:
            "Couldn't identify the photo. Try again."
        }
    }
}

#Preview {
    LabelingView()
        .environment(AppEnvironment())
}
