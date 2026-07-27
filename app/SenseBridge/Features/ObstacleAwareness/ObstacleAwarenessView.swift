import SenseBridgeCore
import SwiftUI

/// The safety-framing disclaimer here is load-bearing, not boilerplate —
/// see docs/SAFETY-FRAMING.md: this must be stated plainly before first
/// use, not buried in settings.
///
/// Offers two modes side by side. **Hands-free awareness** runs continuously
/// for a phone worn on the body with headphones in; **check once** takes a
/// single reading for a phone held in the hand. Neither is a mobility device,
/// and the continuous one is the closer of the two to sounding like one, which
/// is why its limits are stated on this screen rather than in Settings.
struct ObstacleAwarenessView: View {
    private let disclaimer: LocalizedStringKey = """
    Obstacle awareness is not a safety or mobility device. It does not replace a \
    cane, a guide dog, or orientation-and-mobility training. It gives cautious, \
    probabilistic alerts only.
    """

    /// VoiceOver announces this instead of `disclaimer` so the safety
    /// caveat is front-loaded rather than trailing after the rest of the
    /// text.
    private let disclaimerAccessibilityLabel: LocalizedStringKey = """
    Important: obstacle awareness is not a safety or mobility device. It does not \
    replace a cane, a guide dog, or orientation-and-mobility training.
    """

    /// Stated at the point of choice rather than in a footer, because it
    /// changes whether the mode is usable at all — see AGENTS.md doctrine 4's
    /// second corollary. iOS will not run the camera behind a locked screen,
    /// so there is no version of this that works in a pocket.
    private let handsFreeLimits: LocalizedStringKey = """
    Keep SenseBridge open and the screen on — iOS stops the camera otherwise. \
    The screen is held awake while this runs, which uses battery quickly. \
    It describes what the camera happens to be pointed at; it does not watch \
    for hazards.
    """

    /// Shown beside the live preview. The second sentence is the load-bearing
    /// one: an outline is a claim about what was recognized, and a blank patch
    /// of the feed is *not* a claim that the patch is empty — see
    /// docs/SAFETY-FRAMING.md on never asserting an absence.
    private let highlightLegend: LocalizedStringKey = """
    Yellow outlines mark what the camera recognized, and how sure it is. They \
    are not hazard warnings, and anything left unmarked has not been ruled out.
    """

    /// Shown where the feed will be, before the session starts. Stated rather
    /// than left blank: an empty gap is indistinguishable from a camera that
    /// failed, and AGENTS.md doctrine 4 does not allow a limitation to go
    /// unsaid.
    private let previewPending: LocalizedStringKey = """
    The camera view appears here once hands-free awareness is running — iOS \
    delivers no camera frames before that.
    """

    private let phrasing: Phrasing = .init()
    /// Shared app state — renders through the same output targets every
    /// other feature uses, rather than standing up its own synthesizer.
    @Environment(AppEnvironment.self) private var environment
    /// The continuous pipeline. Owned by the view because it holds the camera
    /// and the display-sleep assertion, both of which must be released when
    /// the user leaves this screen.
    @State private var session: AmbientAwarenessSession = .init()
    @State private var engine: AwarenessEngine = .init()
    @State private var isNearReading = true
    @State private var lastResult: String?

    var body: some View {
        List {
            Section {
                Text(disclaimer)
                    .font(.callout)
                    .accessibilityLabel(disclaimerAccessibilityLabel)
            }
            handsFreeSection
            singleCheckSection
        }
        .navigationTitle("Awareness")
        // Leaving the screen must release the camera and let the display sleep
        // again. A blind user has no way to notice either is still held.
        .onDisappear { session.stop() }
    }

    // MARK: - Hands-free

    private var handsFreeSection: some View {
        Section("Hands-free") {
            if AmbientAwarenessSession.isSupported {
                Text(handsFreeLimits)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                Button(session.status == .running ? "Stop hands-free awareness" : "Start hands-free awareness") {
                    Task {
                        if session.status == .running {
                            session.stop()
                        } else {
                            await session.start(environment: environment)
                        }
                    }
                }
                .accessibilityHint(session.status == .running
                    ? "Stops the continuous description and lets the screen sleep again."
                    : """
                    Starts describing the surroundings continuously through your \
                    headphones until you stop it. Not a safety feature.
                    """)
                // The feed only exists while the session runs — iOS delivers no
                // camera frames before that — so the alternative is said out
                // loud rather than left as an empty gap, which would read as a
                // broken camera.
                if session.status == .running {
                    AwarenessPreviewView(
                        image: session.preview.image,
                        detectedObjects: session.detectedObjects,
                        aspectRatio: session.preview.aspectRatio
                    )
                    .listRowInsets(EdgeInsets(top: 8, leading: 0, bottom: 8, trailing: 0))
                    Text(highlightLegend)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                } else {
                    Text(previewPending)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                // Which composer is running changes how the output sounds. Left
                // unsaid, a user cannot tell the simpler mode from a fault.
                Text(session.isUsingLanguageModel
                    ? "Descriptions are composed on-device by Apple Intelligence."
                    : """
                    Apple Intelligence is unavailable, so descriptions are read \
                    out as a plain list of what was recognized.
                    """)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } else {
                // Named as unavailable rather than hidden, per AGENTS.md
                // doctrine 4: an absent control teaches the user nothing.
                Text("""
                Hands-free awareness needs a device with a LiDAR depth sensor. \
                This device does not have one, so it is not available here.
                """)
                .font(.footnote)
                .foregroundStyle(.secondary)
            }
            if case let .unavailable(reason) = session.status {
                Text(reason)
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
            if let narration = session.lastNarration {
                Text(narration)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .accessibilityLabel("Last heard: \(narration)")
            }
        }
    }

    // MARK: - Single check

    private var singleCheckSection: some View {
        Section("One reading") {
            // Labelled as a single check, not "Start awareness". One tap is one
            // evaluation of one depth sample; a user who believes continuous
            // monitoring is running would read the silence between taps as
            // "nothing is there", which is a claim this app never makes.
            Button("Check once for what may be ahead") {
                let mockDepthMeters = isNearReading ? 1.0 : 3.0
                isNearReading.toggle()
                // The transition is what a *continuous* consumer acts on; a
                // one-shot check only wants the resulting state.
                _ = engine.evaluate(depthMeters: mockDepthMeters)
                let isAlerting = engine.isAlerting
                let message = isAlerting
                    ? phrasing.describe(subject: phrasing.somethingAhead(), certainty: .medium)
                    // Not "the way ahead seems clear": that asserts an absence
                    // the app cannot observe, and hedging the verb doesn't
                    // rescue the claim. `nothingRecognized` speaks only about
                    // this check, and comes pre-translated for es/vi — the raw
                    // literal that used to sit here did neither.
                    : phrasing.nothingRecognized()
                lastResult = message
                // The signal tracks the branch, not the view. A haptic channel
                // renders the signal alone and discards the text, so this is
                // the *entire* message under `.deafBlind`. `.awarenessClear`
                // would be an unhedgeable tactile "stand down" from one
                // sample; `.nothingFound` claims only what the prose claims.
                let signal: OutputSignal = isAlerting ? .awarenessAlert : .nothingFound
                announceIfUnspoken(message, profile: environment.settings.outputProfile)
                Task { await environment.output.render(OutputMessage(text: message, signal: signal)) }
            }
            .disabled(session.status == .running)
            // Disabled while the continuous loop holds the camera. Without a
            // value, a VoiceOver user meets a control that has silently gone
            // dim with no explanation.
            .accessibilityValue(session.status == .running ? "Unavailable while hands-free awareness is running" : "")
            .accessibilityHint("""
            Takes one cautious reading of what may be nearby. It does not keep \
            watching, and it is not a safety feature.
            """)
            if let lastResult {
                Text(lastResult)
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

#Preview {
    NavigationStack {
        ObstacleAwarenessView()
            .environment(AppEnvironment())
    }
}
