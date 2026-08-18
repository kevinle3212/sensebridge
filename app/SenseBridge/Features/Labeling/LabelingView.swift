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

    /// The language chosen in Settings, for casing the on-screen caption —
    /// not the process locale, which may differ from what the user picked.
    private var displayLocale: Locale {
        environment.settings.language.locale ?? .current
    }

    @State private var lastResult: String?
    /// Whether the last failure was a denied permission, which is the only
    /// error on this screen that the Settings app can actually fix. Drives the
    /// `OpenSettingsButton` below the message rather than being inferred from
    /// the message text, which is localized prose and a poor thing to match on.
    @State private var isSettingsFixable = false

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
                    // Capitalized for the screen only. The hedge templates are lowercase
                    // because they are built for speech and for mid-sentence embedding;
                    // rendering one verbatim as a caption reads as a typo, not caution.
                    Text(Phrasing.forDisplay(lastResult, locale: displayLocale))
                        .font(.callout)
                        .foregroundStyle(Color("SecondaryText"))
                    if isSettingsFixable {
                        OpenSettingsButton()
                    }
                }
            }
            .padding()
        }
        .navigationTitle("Identify")
        .task { await startCameraIfNeeded() }
        .onDisappear { Task { await environment.camera.stop() } }
    }

    private func startCameraIfNeeded() async {
        // Cleared up front so a granted permission retires the button on the
        // next attempt; only a fresh failure puts it back.
        isSettingsFixable = false
        await environment.camera.start(applying: environment.settings)
        if let startError = environment.camera.startError {
            let spoken = message(for: startError)
            isSettingsFixable = OpenSettingsButton.canResolve(startError)
            lastResult = spoken
            announceIfUnspoken(spoken, profile: environment.settings.outputProfile)
            await environment.output.render(OutputMessage(text: spoken, signal: .error))
        } else {
            UIAccessibility.post(notification: .layoutChanged, argument: nil)
        }
    }

    private func captureAndIdentify() async {
        // Cleared up front so a granted permission retires the button on the
        // next attempt; only a fresh failure puts it back.
        isSettingsFixable = false
        // The previous label describes the previous frame, so it is retired
        // before this one is taken rather than left standing until the
        // replacement arrives. On a caption-only profile that stale sentence
        // is the entire output, and it reads as a description of the shot the
        // user just took. `ReadingSession.capturePage` does the same.
        lastResult = nil
        await environment.output.render(OutputMessage(text: "", signal: .captureTaken))
        do {
            // The language chosen in Settings, not the process locale — see the
            // same note in `SceneDescriptionView.captureAndDescribe()`.
            let locale = environment.settings.language.locale ?? .current
            let classifier = ObjectClassificationService(
                maximumLabels: environment.settings.spokenDetail.maximumLabels,
                locale: locale
            )
            let photo = try await environment.camera.capturePhoto()
            let records = try await classifier.process(photo)
            let phrasing = Phrasing()
            let message: String = if case let .detectedObject(label, confidence)? = records.first?.kind {
                phrasing.describe(
                    subject: label,
                    certainty: Phrasing.certainty(forConfidence: confidence),
                    locale: locale
                )
            } else {
                phrasing.nothingRecognized(locale: locale)
            }
            lastResult = message
            announceIfUnspoken(message, profile: environment.settings.outputProfile)
            await environment.output.render(OutputMessage(text: message, signal: .resultReady))
        } catch {
            let spoken = message(for: error)
            isSettingsFixable = OpenSettingsButton.canResolve(error)
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
