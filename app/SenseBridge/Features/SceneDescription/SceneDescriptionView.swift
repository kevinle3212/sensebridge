import SenseBridgeCore
import SwiftUI
import UIKit

/// Composes a hedged, best-effort description of what the camera sees in a
/// single captured photo — never asserts certainty about the scene. Kept to
/// one capture button and a plain description of the flow, so a VoiceOver
/// user reaches the action without swiping through decorative layout — see
/// docs/ARCHITECTURE.md "Navigation".
struct SceneDescriptionView: View {
    /// Shared app state — renders through the same output targets every
    /// other feature uses, rather than standing up its own synthesizer.
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

    /// A single capture can afford a longer timeout than the hands-free
    /// narration cadence — see `AmbientAwarenessSession.networkRequestTimeout`
    /// for the shorter hands-free figure and why it differs.
    private static let networkRequestTimeout: TimeInterval = 8

    /// Builds a resolver scoped to one capture rather than one view instance —
    /// a single capture is a single request, so unlike `AmbientAwarenessSession`
    /// there's no session lifetime for a circuit breaker to matter within, and
    /// building it in `captureAndDescribe()` (rather than `init()`, where
    /// `@Environment` isn't yet readable) means it always sees the detail
    /// level current in Settings, not whatever was true when the view first
    /// appeared.
    private static func makeResolver(detail: SpokenDetail) -> ReasoningComposerResolver {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.waitsForConnectivity = false
        configuration.timeoutIntervalForRequest = Self.networkRequestTimeout
        configuration.allowsConstrainedNetworkAccess = false
        let urlSession = URLSession(configuration: configuration)
        return ReasoningComposerResolver(
            onDeviceComposer: FoundationModelsSceneComposer(detail: detail),
            credentialStore: KeychainCredentialStore(),
            factory: LiveNetworkComposerFactory(
                session: urlSession, requestTimeout: Self.networkRequestTimeout, locale: .current
            )
        )
    }

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
        .navigationTitle("Describe")
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

    /// Captures a photo, detects objects in it, and speaks a hedged
    /// description composed through `resolver` (falling back to on-device
    /// per its own contract). The resolver returning `nil` is unreachable
    /// in normal operation — `FoundationModelsSceneComposer`'s on-device
    /// fallback never throws — but is handled with a spoken error rather
    /// than a silent skip: this is a one-shot action the user is actively
    /// waiting on, not a continuous channel, so leaving a stale
    /// `lastResult` on screen with no explanation would be worse than
    /// speaking *some* error.
    private func captureAndDescribe() async {
        // Cleared up front so a granted permission retires the button on the
        // next attempt; only a fresh failure puts it back.
        isSettingsFixable = false
        // The previous description describes the previous frame, so it is
        // retired before this one is taken rather than left standing until the
        // replacement arrives. On a caption-only profile that stale sentence is
        // the entire output, and it reads as a description of the shot the user
        // just took. `ReadingSession.capturePage` does the same.
        lastResult = nil
        await environment.output.render(OutputMessage(text: "", signal: .captureTaken))
        do {
            let detail = environment.settings.spokenDetail
            // The language chosen in Settings, not the process locale: the
            // object noun and the hedge composed around it have to agree, and
            // `.current` would have spoken an English sentence to a user who
            // had picked Español.
            let locale = environment.settings.language.locale ?? .current
            let detector = ObjectClassificationService(maximumLabels: detail.maximumLabels, locale: locale)
            let resolver = Self.makeResolver(detail: detail)
            let photo = try await environment.camera.capturePhoto()
            let objects = try await detector.detect(photo)
            let records = objects.map {
                PerceptionRecord(kind: .detectedObject(label: $0.label, confidence: $0.confidence), capturedAt: .now)
            }
            guard let result = await resolver.compose(
                from: records, settings: environment.settings, locale: locale,
                requestTimeout: Self.networkRequestTimeout
            ) else {
                let spoken = message(for: CameraSource.CameraError.noCameraAvailable)
                lastResult = spoken
                announceIfUnspoken(spoken, profile: environment.settings.outputProfile)
                await environment.output.render(OutputMessage(text: spoken, signal: .error))
                return
            }
            if let announcement = result.announcement {
                announceIfUnspoken(announcement, profile: environment.settings.outputProfile)
                await environment.output.render(OutputMessage(text: announcement, signal: .error))
            }
            lastResult = result.text
            announceIfUnspoken(result.text, profile: environment.settings.outputProfile)
            await environment.output.render(OutputMessage(text: result.text, signal: .resultReady))
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
