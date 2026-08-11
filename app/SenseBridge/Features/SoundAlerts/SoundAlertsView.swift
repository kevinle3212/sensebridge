import SenseBridgeCore
import SwiftUI

/// Listens for recognizable sounds nearby and announces them; not a
/// substitute for hearing. Kept to one start button and a plain description
/// of the flow, so a VoiceOver user reaches the action without swiping
/// through decorative layout — see docs/ARCHITECTURE.md "Navigation".
struct SoundAlertsView: View {
    /// Stated on screen, not only in this file's doc comment — a safety-
    /// framing review found this limitation reachable only by a developer
    /// reading source, with no user-facing equivalent, even though this
    /// screen targets alarm-adjacent classes (siren, glass breaking, fire/smoke
    /// alarms, and more via both `CustomSoundClassifier` and
    /// `BuiltInSoundClassifier`). Mirrors `ObstacleAwarenessView`'s on-screen
    /// disclaimer pattern.
    private let disclaimer: LocalizedStringKey = """
    Not a substitute for hearing, and not a safety device. Do not rely on it to detect \
    alarms or emergencies.
    """

    private let microphone: MicrophoneSensingSource = .init()
    private let classifier: CombinedSoundClassifier = .init(
        primary: CustomSoundClassifier(),
        secondary: BuiltInSoundClassifier()
    )
    /// Shared app state — renders through the same output targets every
    /// other feature uses, rather than standing up its own synthesizer.
    @Environment(AppEnvironment.self) private var environment
    @State private var lastResult: String?
    @State private var isListening = false

    /// How long one "listen" samples for. Long enough for
    /// `SNClassifySoundRequest` to gather a stable window, short enough that
    /// a VoiceOver user isn't left waiting without feedback.
    private static let listenDuration: TimeInterval = 4

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                Text("Listens once for a recognizable sound nearby and announces what it might be.")
                    .font(.body)
                Text(disclaimer)
                    .font(.callout)
                    .foregroundStyle(Color("SecondaryText"))
                // "Listen once", not "Start listening". One tap is one sample; a
                // user who believes the app is monitoring continuously would read
                // the silence in between as "no sound happened".
                Button("Listen once") {
                    Task { await listenAndAnnounce() }
                }
                .disabled(isListening)
                .accessibilityLabel("Listen once for sounds")
                .accessibilityValue(isListening ? "Listening" : "")
                .accessibilityHint("Takes one listen for a recognizable sound nearby. It does not keep listening.")
                if let lastResult {
                    Text(lastResult)
                        .font(.callout)
                        .foregroundStyle(Color("SecondaryText"))
                }
            }
            .padding()
        }
        .navigationTitle("Sounds")
    }

    private func listenAndAnnounce() async {
        isListening = true
        defer { isListening = false }
        do {
            let audio = try await microphone.record(duration: Self.listenDuration)
            let records = try await classifier.process(audio)
            let phrasing = Phrasing()
            let message: String = if case let .detectedSound(label, confidence)? = records.first?.kind {
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
        case MicrophoneSensingSource.MicrophoneError.authorizationDenied:
            "Microphone access is needed to listen for sounds. Enable it in Settings."
        case MicrophoneSensingSource.MicrophoneError.noMicrophoneAvailable:
            "No microphone is available on this device."
        default:
            "Couldn't listen for sounds. Try again."
        }
    }
}

#Preview {
    SoundAlertsView()
        .environment(AppEnvironment())
}
