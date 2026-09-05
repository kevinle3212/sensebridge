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
        .navigationTitle("Sounds")
    }

    private func listenAndAnnounce() async {
        // Cleared up front so a granted permission retires the button on the
        // next attempt; only a fresh failure puts it back.
        isSettingsFixable = false
        isListening = true
        defer { isListening = false }
        do {
            // Built here rather than stored: both the sound label and the hedge
            // around it have to follow the language chosen in Settings, which
            // is only reachable through `environment`. Reading it per listen
            // also means a language change takes effect without leaving the
            // screen. Both classifiers are stateless structs, so constructing
            // them per tap costs nothing — the model load already happens
            // inside `process`.
            let locale = environment.settings.language.locale ?? .current
            let classifier = CombinedSoundClassifier(
                primary: CustomSoundClassifier(locale: locale),
                secondary: BuiltInSoundClassifier(locale: locale)
            )
            let audio = try await microphone.record(duration: Self.listenDuration)
            let records = try await classifier.process(audio)
            let phrasing = Phrasing()
            let message: String = if case let .detectedSound(label, confidence)? = records.first?.kind {
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
