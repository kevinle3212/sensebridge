import Foundation
import SenseBridgeCore
import SwiftUI
import UIKit

/// Drives hands-free awareness: the continuous loop behind "start it, put the
/// phone away, and listen".
///
/// This is the whole pipeline in one place — `AmbientSensingSource` →
/// `ObjectClassificationService` / `DepthStatistics` →
/// `FoundationModelsSceneComposer` / `AwarenessEngine` →
/// `MultiRenderTarget` — and nothing else in the app runs a loop like it. Every
/// other feature is one capture in response to one tap.
///
/// ## Two cadences, one loop
///
/// Depth is sampled every `sampleInterval` because something stepping in front
/// of the user should not wait on a narration cadence chosen for comfort.
/// Classification and composition are far more expensive and run only every
/// `Settings.narrationIntervalSeconds`. Both live in the same loop so there is
/// one place that can be stopped, and one place holding the camera.
///
/// ## What it cannot do
///
/// iOS does not allow camera capture while an app is backgrounded or the screen
/// is locked. Hands-free awareness therefore needs SenseBridge foregrounded with
/// the display on, and holds `isIdleTimerDisabled` for as long as it runs. When
/// the app is backgrounded anyway, this stops and *says so*, then starts itself
/// again on return and says that too: a user with the phone strapped to their
/// chest cannot see either transition, and silence on this channel is
/// indistinguishable from "nothing to report", which docs/SAFETY-FRAMING.md
/// treats as the failure that matters most. See
/// `AmbientAwarenessSession+Lifecycle.swift`.
@MainActor
@Observable
final class AmbientAwarenessSession {
    /// What the session is doing, and why it is not running when it isn't.
    enum Status: Equatable {
        case idle
        case running
        /// Cannot run on this device or in this state. The payload is
        /// user-facing prose, already specific about which of the several
        /// reasons applies — "unavailable" alone leaves a blind user with no
        /// idea whether to check Settings or give up.
        case unavailable(String)
    }

    private(set) var status: Status = .idle
    /// The most recent narration, mirrored on screen. The screen is not the
    /// channel — speech is — but a sighted helper, a screenshot, or a braille
    /// display all need the text to exist somewhere.
    ///
    /// Internal rather than `private(set)` only so
    /// `AmbientAwarenessSession+Lifecycle.swift` can mirror its own
    /// announcements here — same type, different file. Nothing outside this
    /// type writes it.
    var lastNarration: String?

    /// What the last detection pass found, for the preview to outline.
    ///
    /// The same list the next narration is composed from, so a box on screen and
    /// a noun in the user's ear always refer to the same thing. Emptied whenever
    /// a pass finds nothing or fails — a stale outline left hanging over a scene
    /// that has moved on is a claim about the present built from the past.
    private(set) var detectedObjects: [DetectedObject] = []

    /// The on-screen mirror of this session — camera frames, on their own
    /// cadence. Purely presentational: switching it off would not change a word
    /// the app says.
    let preview: AwarenessPreviewFeed = .init()

    /// How often depth is read on a cool device. Fast enough to notice someone
    /// stepping in front of the user, slow enough not to hold the CPU at a
    /// walk's expense — the cost per tick is one pixel-buffer reduction, not a
    /// model run. Stretched by `ThermalBackoff` when the phone heats up.
    ///
    /// Not `private` — see `classifier`'s doc comment.
    static let sampleInterval: Duration = .milliseconds(750)

    private let source: AmbientSensingSource = .init()
    /// Not `private`: rebuilt by `configureReasoning(environment:)` in
    /// `AmbientAwarenessSession+Support.swift`, a same-type extension in a
    /// different file (split out purely for SwiftLint's `file_length` gate).
    var classifier: ObjectClassificationService = .init()
    let phrasing: Phrasing = .init()

    /// Not `private` — see `classifier`'s doc comment.
    var resolver: ReasoningComposerResolver?
    private var engine: AwarenessEngine = .init()
    /// Not `private` — see `classifier`'s doc comment;
    /// `AmbientAwarenessSession+Composition.swift` consults it before speaking.
    var throttle: NarrationThrottle = .init()
    private var loopTask: Task<Void, Never>?
    private var compositionTask: Task<Void, Never>?
    /// Lifecycle and thermal state. Not `private` — see `classifier`'s doc
    /// comment; `AmbientAwarenessSession+Lifecycle.swift` owns all four.
    var backgroundObserver: NSObjectProtocol?
    var foregroundObserver: NSObjectProtocol?
    /// Whether the next activation should restart the session. Set only by the
    /// backgrounding path, so a session the user ended by hand stays ended.
    var isAwaitingForegroundResume = false
    /// Last thermal level announced, so a change is spoken once rather than
    /// every tick.
    var thermalLevel: ThermalBackoff.Level = .normal
    private var lastDescribedAt: Date?
    /// Not `private` — see `classifier`'s doc comment.
    var locale: Locale = .current

    /// The most recent zoned depth reading, mirrored on screen so the user can
    /// see what the session is working from. Every figure is optional and `nil`
    /// means "could not be measured" — never "that side is clear".
    private(set) var lastReading: AwarenessDepthReading = .unmeasured
    /// How many alerts this session has raised, for the end-of-session summary.
    /// Counted rather than derived, because a transition is not recoverable
    /// from the final state.
    var alertCount = 0
    /// When the current run started, for the same summary. `nil` while idle.
    var startedAt: Date?
    /// The proximity band the last alert was announced at, so a measurement
    /// coming nearer is spoken once per band rather than on every tick.
    var lastAnnouncedBand: ProximityBand?
    /// The repeating haptic pulse, whose rate tracks the proximity band.
    /// Cancelled whenever the reading clears or the session stops.
    var pulseTask: Task<Void, Never>?
    /// The environment this run was started with, so `stop()` — which takes no
    /// arguments, and is called from the button, from `onDisappear`, and from
    /// the backgrounding path — can still speak its summary.
    private var activeEnvironment: AppEnvironment?

    /// Whether this device can run hands-free awareness at all. Checked by the
    /// view before offering the control, so the app never presents a button
    /// that silently does nothing — AGENTS.md doctrine 4, first corollary.
    static var isSupported: Bool {
        AmbientSensingSource.isDepthSupported
    }

    /// Starts the loop, or records why it could not start.
    func start(environment: AppEnvironment) async {
        guard status != .running else { return }

        guard Self.isSupported else {
            status = .unavailable("""
            Hands-free awareness needs a device with a LiDAR depth sensor, \
            which this one does not have.
            """)
            return
        }

        // ARKit and `CameraSource` both want the rear camera, and iOS grants it
        // to one session. Stopping the shared camera first is not politeness —
        // ARKit's own session would otherwise fail to start.
        await environment.camera.stop()

        do {
            try source.start()
        } catch {
            status = .unavailable(Self.message(for: error))
            return
        }

        locale = environment.settings.language.locale ?? .current
        configureReasoning(environment: environment)
        resolver?.resetSession()
        engine = .alerting(withinMeters: environment.settings.awarenessAlertDistanceMeters)
        let interval = environment.settings.narrationIntervalSeconds
        throttle = NarrationThrottle(
            minimumInterval: interval,
            // Re-state an unchanged scene after several cadences rather than
            // never, so the user can tell "nothing has changed" from "this
            // stopped working" without looking at a screen they cannot see.
            repeatSuppressionInterval: max(interval * 4, 20)
        )
        lastDescribedAt = nil
        // The display has to stay on for the camera to run at all, so the
        // choice is between holding it on and having the session die a minute
        // after the user pockets the phone.
        UIApplication.shared.isIdleTimerDisabled = true
        observeLifecycle(environment: environment)
        // A resumed session inherits the device's current heat, not the level
        // it had when it was stopped, so the first tick re-announces if the
        // phone cooled off while the app was away.
        thermalLevel = .normal
        alertCount = 0
        lastAnnouncedBand = nil
        startedAt = .now
        activeEnvironment = environment
        status = .running
        loopTask = Task { [weak self] in
            await self?.run(environment: environment)
        }
        preview.start(mirroring: source)
    }

    /// Stops the loop and releases the camera, display, and ARKit session.
    ///
    /// Speaks an end-of-session summary on the way out. Silence is how this
    /// channel reports "nothing to say", so a session that simply goes quiet is
    /// indistinguishable from one that crashed — the same reasoning behind
    /// `awarenessStoppedOffScreen`.
    func stop() {
        stopProximityPulse()
        if status == .running, let environment = activeEnvironment {
            let summary = sessionSummaryText()
            Task { [weak self] in
                await self?.deliver(summary, signal: .resultReady, isUrgent: true, to: environment)
            }
        }
        startedAt = nil
        lastAnnouncedBand = nil
        lastReading = .unmeasured
        activeEnvironment = nil
        loopTask?.cancel()
        loopTask = nil
        compositionTask?.cancel()
        compositionTask = nil
        source.stop()
        UIApplication.shared.isIdleTimerDisabled = false
        if let backgroundObserver {
            NotificationCenter.default.removeObserver(backgroundObserver)
            self.backgroundObserver = nil
        }
        // Any stop cancels a pending auto-resume. The backgrounding path re-arms
        // it immediately afterwards; every other caller — the button, leaving
        // the screen — means the user is done.
        isAwaitingForegroundResume = false
        removeForegroundObserver()
        // Reset both, or restarting in a different room would inherit this
        // room's alert state and swallow the first real alert of the next run.
        engine.reset()
        throttle.reset()
        resolver?.resetSession()
        lastDescribedAt = nil
        // The preview goes away with the session, and neither the last frame
        // nor its outlines may outlive the feed they came from.
        preview.stop()
        detectedObjects = []
        status = .idle
    }

    private func run(environment: AppEnvironment) async {
        while !Task.isCancelled {
            await tick(environment: environment)
            do {
                try await Task.sleep(for: thermalPacedInterval(environment: environment))
            } catch {
                // Cancellation is the only way this throws, and it means stop.
                return
            }
        }
    }

    private func tick(environment: AppEnvironment) async {
        // `nil` until this run's first frame arrives, which takes a moment
        // after `start()` — and stays `nil` rather than handing back the last
        // frame of a previous run, which is what a resume after backgrounding
        // would otherwise narrate. Not an error, and emphatically not "nothing
        // is there".
        guard let frame = source.latestFrame() else { return }
        // Zoned rather than whole-region: the overall figure inside the reading
        // is bit-identical to what `depthMeters(in:)` produced, so the alert
        // decision is unchanged and the zones only add a side to the sentence.
        let reading = await source.zonedDepth(in: frame)
        lastReading = reading
        if let depthMeters = reading.overallMeters {
            await report(engine.evaluate(depthMeters: depthMeters), reading: reading, to: environment)
        } else {
            // A frame that measured nothing never reaches the engine, so
            // `.becameClear` — the only other thing that ends the pulse — cannot
            // fire. Left alone, the phone goes on buzzing a proximity it can no
            // longer measure. See `stopPulseForUnmeasuredFrame`.
            stopPulseForUnmeasuredFrame()
        }
        await updateDetections(in: frame)
        describeIfDue(frame, environment: environment)
    }

    /// Re-runs object detection so the preview's outlines follow the scene.
    ///
    /// On the depth cadence rather than the narration cadence: outlines that
    /// only moved once every several seconds would sit over whatever the camera
    /// used to be pointed at, which is worse than not drawing them. The extra
    /// work is a saliency pass plus at most a few crops of a classifier that
    /// already runs on the neural engine — small beside the ARKit world-tracking
    /// session and the full-brightness screen this mode already holds on.
    ///
    /// Narration reads whatever this last left behind, so the expensive pass
    /// happens once and serves both channels.
    private func updateDetections(in frame: AmbientFrame) async {
        // A frame that cannot be detected in is routine — motion blur, a pass
        // that returned nothing. Clearing is the honest response: it removes the
        // outlines rather than leaving the last ones asserting a stale scene.
        let detected = await (try? classifier.detect(frame.image, orientation: frame.orientation)) ?? []
        // `stop()` can land while a pass is in flight. Assigning unconditionally
        // would resurrect outlines the stop had just cleared, and they would be
        // waiting on screen the next time the session starts.
        guard status == .running else { return }
        detectedObjects = detected
    }

    /// Classifies and narrates the scene, if enough time has passed, the
    /// channel is free, and no composition is already in flight.
    ///
    /// Composition runs as a **tracked, single-flight, cancellable child
    /// task** rather than being awaited inline — a network composer's
    /// round-trip must never stall the 750ms depth-sampling tick this method
    /// is called from, or hands-free awareness would stop noticing something
    /// stepping in front of the user for however long the request takes. See
    /// docs/superpowers/specs/2026-08-11-awareness-ai-tiers-design.md
    /// "Resolution, concurrency, and fallback".
    private func describeIfDue(_ frame: AmbientFrame, environment: AppEnvironment) {
        guard compositionTask == nil else { return } // single-flight: skip, don't queue
        let now = Date.now
        let interval = narrationInterval(environment: environment)
        if let lastDescribedAt, now.timeIntervalSince(lastDescribedAt) < interval {
            return
        }
        lastDescribedAt = now
        let capturedAt = frame.capturedAt
        let staleAfter = max(interval * 2, 12)
        let currentDetections = detectedObjects

        compositionTask = Task { [weak self] in
            defer { self?.compositionTask = nil }
            guard let self else { return }
            guard let records = await records(for: frame, detections: currentDetections) else { return }
            guard let resolver else { return }
            guard let result = await resolver.compose(
                from: records,
                settings: environment.settings,
                locale: locale,
                requestTimeout: Self.networkRequestTimeout
            ) else { return }
            guard !Task.isCancelled, status == .running else { return }
            // Staleness guard: a description of a frame captured this long
            // ago is a statement about somewhere the user may have already
            // walked away from — see the spec's non-blocking-composition
            // section.
            guard Date.now.timeIntervalSince(capturedAt) <= staleAfter else { return }
            await deliverComposedResult(result, records: records, environment: environment)
        }
    }

    /// Renders `text` through every channel the user's profile prefers.
    ///
    /// Internal rather than `private` so
    /// `AmbientAwarenessSession+Proximity.swift` — a same-type extension split
    /// out only for SwiftLint's length gates — can speak through it too.
    func deliver(
        _ text: String,
        signal: OutputSignal,
        isUrgent: Bool,
        to environment: AppEnvironment
    ) async {
        if isUrgent {
            // Recorded in the throttle even though an urgent message is never
            // held back, so routine narration queues behind the alert instead
            // of talking over it a moment later. The routine path has already
            // consulted the throttle by the time it reaches here.
            _ = throttle.shouldSpeak(text, at: Date.now, isUrgent: true)
        }
        lastNarration = text
        announceIfUnspoken(text, profile: environment.settings.outputProfile)
        await environment.output.render(OutputMessage(text: text, signal: signal))
    }
}
