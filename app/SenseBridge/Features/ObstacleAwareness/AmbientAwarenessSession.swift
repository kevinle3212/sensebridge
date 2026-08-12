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
/// the app is backgrounded anyway, this stops and *says so*: a user with the
/// phone strapped to their chest cannot see that it stopped, and silence on this
/// channel is indistinguishable from "nothing to report", which
/// docs/SAFETY-FRAMING.md treats as the failure that matters most.
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
    private(set) var lastNarration: String?

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

    /// How often depth is read. Fast enough to notice someone stepping in
    /// front of the user, slow enough not to hold the CPU at a walk's expense
    /// — the cost per tick is one pixel-buffer reduction, not a model run.
    private static let sampleInterval: Duration = .milliseconds(750)

    private let source: AmbientSensingSource = .init()
    /// Not `private`: rebuilt by `configureReasoning(environment:)` in
    /// `AmbientAwarenessSession+Support.swift`, a same-type extension in a
    /// different file (split out purely for SwiftLint's `file_length` gate).
    var classifier: ObjectClassificationService = .init()
    let phrasing: Phrasing = .init()

    /// Not `private` — see `classifier`'s doc comment.
    var resolver: ReasoningComposerResolver?
    private var engine: AwarenessEngine = .init()
    private var throttle: NarrationThrottle = .init()
    private var loopTask: Task<Void, Never>?
    private var compositionTask: Task<Void, Never>?
    private var backgroundObserver: NSObjectProtocol?
    private var lastDescribedAt: Date?
    /// Not `private` — see `classifier`'s doc comment.
    var locale: Locale = .current

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
        observeBackgrounding(environment: environment)
        status = .running
        loopTask = Task { [weak self] in
            await self?.run(environment: environment)
        }
        preview.start(mirroring: source)
    }

    /// Stops the loop and releases the camera, display, and ARKit session.
    func stop() {
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
                try await Task.sleep(for: Self.sampleInterval)
            } catch {
                // Cancellation is the only way this throws, and it means stop.
                return
            }
        }
    }

    private func tick(environment: AppEnvironment) async {
        // `nil` before ARKit's first frame arrives, which takes a moment after
        // `start()`. Not an error, and emphatically not "nothing is there".
        guard let frame = source.latestFrame() else { return }
        if let depthMeters = await source.depthMeters(in: frame) {
            await report(engine.evaluate(depthMeters: depthMeters), depthMeters: depthMeters, to: environment)
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

    /// Speaks the awareness alert or clear cue, but only on a real transition.
    private func report(
        _ transition: AwarenessTransition,
        depthMeters: Double,
        to environment: AppEnvironment
    ) async {
        switch transition {
        case .becameAlerting:
            let subject = phrasing.somethingAhead(
                atDistance: Self.formattedDistance(meters: depthMeters, locale: locale),
                locale: locale
            )
            // `.medium`, not `.high`. The reading is a percentile of a
            // confidence-filtered region measured through an uncalibrated
            // chest mount; "it looks like" is what that earns, and "likely" is
            // not.
            let text = phrasing.describe(subject: subject, certainty: .medium, locale: locale)
            await deliver(text, signal: .awarenessAlert, isUrgent: true, to: environment)
        case .becameClear:
            // The first honest emitter of `.awarenessClear` — see its doc
            // comment in `RenderTarget.swift`. It is honest here and only here
            // because a transition is a change the app observed, rather than
            // an absence inferred from one sample.
            await deliver(
                phrasing.nearestMeasurementMovedAway(locale: locale),
                signal: .awarenessClear,
                isUrgent: true,
                to: environment
            )
        case .unchanged:
            break
        }
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
        if let lastDescribedAt,
           now.timeIntervalSince(lastDescribedAt) < environment.settings.narrationIntervalSeconds {
            return
        }
        lastDescribedAt = now
        let capturedAt = frame.capturedAt
        let staleAfter = max(environment.settings.narrationIntervalSeconds * 2, 12)
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
    private func deliver(
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

    /// Stops the session when the app is backgrounded, and says so out loud.
    ///
    /// iOS revokes camera access on backgrounding, so the loop would otherwise
    /// keep running against frames that never arrive — perfectly silent, and
    /// indistinguishable from a quiet room to someone who cannot see the
    /// screen. The `audio` background mode exists in this target so this one
    /// announcement is audible; nothing else in the app plays in the
    /// background.
    private func observeBackgrounding(environment: AppEnvironment) {
        backgroundObserver = NotificationCenter.default.addObserver(
            forName: UIApplication.didEnterBackgroundNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self, status == .running else { return }
                stop()
                let text = "Hands-free awareness stopped because SenseBridge is no longer on screen."
                lastNarration = text
                await environment.output.render(OutputMessage(text: text, signal: .error))
            }
        }
    }
}

/// Composition-pipeline helpers that touch session state (`classifier`,
/// `throttle`, `deliver`), split out of the class body purely to keep it
/// under SwiftLint's `type_body_length` — unlike
/// `AmbientAwarenessSession+Support.swift`, these need `private` access to
/// the type and so must stay in this file.
private extension AmbientAwarenessSession {
    // swiftlint:disable discouraged_optional_collection
    /// Builds the records to compose from — detections if the last pass
    /// found any discrete objects, otherwise a whole-frame classification
    /// pass. Split out of `describeIfDue` so that method reads as the
    /// scheduling/cancellation logic it is, not classification plumbing.
    ///
    /// Returns `nil`, not an empty array, when classification itself
    /// failed — a real, distinct signal from "classified as empty" that
    /// `describeIfDue` uses to skip the tick entirely rather than announce
    /// "nothing recognized" for a frame that was never actually read.
    func records(for frame: AmbientFrame, detections: [DetectedObject]) async -> [PerceptionRecord]? {
        if detections.isEmpty {
            do {
                return try await classifier.classify(frame.image, orientation: frame.orientation)
            } catch {
                return nil
            }
        }
        return detections.map {
            PerceptionRecord(kind: .detectedObject(label: $0.label, confidence: $0.confidence), capturedAt: .now)
        }
    }

    // swiftlint:enable discouraged_optional_collection

    /// Delivers a resolver result: the breaker announcement first (if any,
    /// always spoken), then the routine narration itself — gated on speech
    /// not already being in flight and the throttle's dedup/cadence rules.
    /// Split out of `describeIfDue`'s composition `Task` to keep that
    /// closure's cyclomatic complexity within SwiftLint's limit.
    func deliverComposedResult(
        _ result: ReasoningComposeResult,
        records: [PerceptionRecord],
        environment: AppEnvironment
    ) async {
        if let announcement = result.announcement {
            await deliver(announcement, signal: .error, isUrgent: true, to: environment)
        }
        // Routine narration is skipped, not queued, while speech is already
        // in flight — `render` interrupts, which is right for a one-shot
        // capture and wrong here, where it would cut every sentence off
        // with the next one. The breaker announcement above is deliberately
        // exempt (`isUrgent: true`), matching
        // `SpeechRenderTarget.isSpeaking`'s documented contract.
        guard await !environment.speech.isSpeaking else { return }
        guard throttle.shouldSpeak(result.text, at: Date.now) else { return }
        await deliver(
            result.text,
            signal: records.isEmpty ? .nothingFound : .resultReady,
            isUrgent: false,
            to: environment
        )
    }
}
