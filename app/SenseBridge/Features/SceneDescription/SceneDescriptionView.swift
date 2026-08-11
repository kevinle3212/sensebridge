import SenseBridgeCore
import SwiftUI
import UIKit

/// Composes a hedged, best-effort description of what the camera sees in a
/// single captured photo — never asserts certainty about the scene. Kept to
/// one capture button and a plain description of the flow, so a VoiceOver
/// user reaches the action without swiping through decorative layout — see
/// docs/ARCHITECTURE.md "Navigation".
struct SceneDescriptionView: View {
    private let detector: ObjectClassificationService = .init()
    private let composer: FoundationModelsSceneComposer = .init()
    /// Shared app state — renders through the same output targets every
    /// other feature uses, rather than standing up its own synthesizer.
    @Environment(AppEnvironment.self) private var environment
    @State private var lastResult: String?

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                Text("Point the camera at a scene, then capture, for a hedged description of what's there.")
                    .font(.body)
                CameraPreviewView(cameraSource: environment.camera.source)
                    .frame(height: 300)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .accessibilityHidden(true)
                CameraControlsView(camera: environment.camera)
                Button("Capture") {
                    Task { await captureAndDescribe() }
                }
                .disabled(environment.camera.isCapturing)
                .accessibilityLabel("Describe scene")
                .accessibilityValue(environment.camera.isCapturing ? "Capturing" : "")
                .accessibilityHint("Takes a photo and composes a cautious description of what's in it.")
                if let lastResult {
                    Text(lastResult)
                        .font(.callout)
                        .foregroundStyle(Color("SecondaryText"))
                }
            }
            .padding()
        }
        .navigationTitle("Describe")
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

    private func captureAndDescribe() async {
        do {
            let photo = try await environment.camera.capturePhoto()
            let objects = try await detector.detect(photo)
            let records = objects.map {
                PerceptionRecord(kind: .detectedObject(label: $0.label, confidence: $0.confidence), capturedAt: .now)
            }
            let message = try await composer.compose(from: records)
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
            "Camera access is needed to describe the scene. Enable it in Settings."
        case CameraSource.CameraError.noCameraAvailable:
            "No camera is available on this device."
        default:
            "Couldn't describe the photo. Try again."
        }
    }
}

#Preview {
    SceneDescriptionView()
        .environment(AppEnvironment())
}
