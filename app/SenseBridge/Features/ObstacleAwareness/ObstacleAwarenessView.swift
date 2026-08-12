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
    /// The one-shot depth source behind "Check once" — a separate instance
    /// from `session`'s own, so a single check never contends with a
    /// running continuous session for the camera.
    @State private var oneShotSource: AmbientSensingSource = .init()
    @State private var isTakingReading = false
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
        Section {
            if AmbientAwarenessSession.isSupported {
                Text(handsFreeLimits)
                    .font(.footnote)
                    .foregroundStyle(Color("SecondaryText"))
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
                        .foregroundStyle(Color("SecondaryText"))
                } else {
                    Text(previewPending)
                        .font(.footnote)
                        .foregroundStyle(Color("SecondaryText"))
                }
                // Which composer is running changes how the output sounds. Left
                // unsaid, a user cannot tell the simpler mode from a fault.
                Text(session.activeBackendDescription(settings: environment.settings))
                    .font(.footnote)
                    .foregroundStyle(Color("SecondaryText"))
            } else {
                // Named as unavailable rather than hidden, per AGENTS.md
                // doctrine 4: an absent control teaches the user nothing.
                Text("""
                Hands-free awareness needs a device with a LiDAR depth sensor. \
                This device does not have one, so it is not available here.
                """)
                .font(.footnote)
                .foregroundStyle(Color("SecondaryText"))
            }
            if case let .unavailable(reason) = session.status {
                Text(reason)
                    .font(.callout)
                    .foregroundStyle(Color("SecondaryText"))
            }
            if let narration = session.lastNarration {
                Text(narration)
                    .font(.callout)
                    .foregroundStyle(Color("SecondaryText"))
                    .accessibilityLabel("Last heard: \(narration)")
            }
        } header: {
            Text("Hands-free")
                .foregroundStyle(Color("SecondaryText"))
        }
    }

    // MARK: - Single check

    private var singleCheckSection: some View {
        Section {
            // Labelled as a single check, not "Start awareness". One tap is one
            // evaluation of one depth sample; a user who believes continuous
            // monitoring is running would read the silence between taps as
            // "nothing is there", which is a claim this app never makes.
            Button(isTakingReading ? "Measuring…" : "Check once for what may be ahead") {
                Task { await takeOneShotReading() }
            }
            .disabled(session.status == .running || isTakingReading)
            // Disabled while the continuous loop holds the camera, or while
            // a reading is already in flight. Without a value, a VoiceOver
            // user meets a control that has silently gone dim with no
            // explanation.
            .accessibilityValue(
                session.status == .running ? "Unavailable while hands-free awareness is running"
                    : isTakingReading ? "Measuring" : ""
            )
            .accessibilityHint("""
            Takes one cautious reading of what may be nearby. It does not keep \
            watching, and it is not a safety feature.
            """)
            if let lastResult {
                Text(lastResult)
                    .font(.callout)
                    .foregroundStyle(Color("SecondaryText"))
            }
        } header: {
            Text("One reading")
                .foregroundStyle(Color("SecondaryText"))
        }
    }

    /// Takes one real depth reading. A **fresh** `AwarenessEngine` per
    /// call, deliberately: the continuous session's hysteresis band is
    /// right for a loop and wrong for a one-shot check, where reusing state
    /// across taps could report "something ahead" from a reading taken in
    /// a different room minutes earlier.
    private func takeOneShotReading() async {
        isTakingReading = true
        defer { isTakingReading = false }
        let depthMeters: Double?
        do {
            depthMeters = try await oneShotSource.sampleOnce()
        } catch {
            let spoken = phrasing.couldNotMeasure()
            lastResult = spoken
            announceIfUnspoken(spoken, profile: environment.settings.outputProfile)
            await environment.output.render(OutputMessage(text: spoken, signal: .error))
            return
        }
        guard let depthMeters else {
            // A frame arrived but nothing was measurable — distinct from
            // "nothing recognized" and never `.awarenessClear`, matching
            // `DepthStatistics`'s own "could not measure" contract.
            let spoken = phrasing.couldNotMeasure()
            lastResult = spoken
            announceIfUnspoken(spoken, profile: environment.settings.outputProfile)
            await environment.output.render(OutputMessage(text: spoken, signal: .error))
            return
        }
        var freshEngine = AwarenessEngine(alertThresholdMeters: environment.settings.awarenessAlertDistanceMeters)
        _ = freshEngine.evaluate(depthMeters: depthMeters)
        let isAlerting = freshEngine.isAlerting
        let message = isAlerting
            ? phrasing.describe(subject: phrasing.somethingAhead(), certainty: .medium)
            : phrasing.nothingRecognized()
        lastResult = message
        let signal: OutputSignal = isAlerting ? .awarenessAlert : .nothingFound
        announceIfUnspoken(message, profile: environment.settings.outputProfile)
        await environment.output.render(OutputMessage(text: message, signal: signal))
    }
}

#Preview {
    NavigationStack {
        ObstacleAwarenessView()
            .environment(AppEnvironment())
    }
}
