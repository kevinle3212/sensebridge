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
    private let resolver: ReasoningComposerResolver
    /// Shared app state — renders through the same output targets every
    /// other feature uses, rather than standing up its own synthesizer.
    @Environment(AppEnvironment.self) private var environment
    @State private var lastResult: String?

    /// A single capture can afford a longer timeout than the hands-free
    /// narration cadence — see `AmbientAwarenessSession.networkRequestTimeout`
    /// for the shorter hands-free figure and why it differs.
    private static let networkRequestTimeout: TimeInterval = 8

    /// Builds a resolver scoped to this view instance — a single capture is
    /// a single request, so unlike `AmbientAwarenessSession` there's no
    /// session lifetime for a circuit breaker to matter within, and a fresh
    /// resolver per instance is simpler than trying to share one.
    init() {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.waitsForConnectivity = false
        configuration.timeoutIntervalForRequest = Self.networkRequestTimeout
        configuration.allowsConstrainedNetworkAccess = false
        let urlSession = URLSession(configuration: configuration)
        resolver = ReasoningComposerResolver(
            onDeviceComposer: FoundationModelsSceneComposer(),
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
        do {
            let photo = try await environment.camera.capturePhoto()
            let objects = try await detector.detect(photo)
            let records = objects.map {
                PerceptionRecord(kind: .detectedObject(label: $0.label, confidence: $0.confidence), capturedAt: .now)
            }
            guard let result = await resolver.compose(
                from: records, settings: environment.settings, locale: .current,
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
