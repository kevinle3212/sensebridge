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

    /// Whether descriptions are being composed by the on-device language model
    /// or read out as a plain list of labels.
    ///
    /// Surfaced rather than hidden: the two produce noticeably different
    /// output, and a user who does not know which one they are hearing cannot
    /// tell a degraded mode from a bug. See AGENTS.md doctrine 4.
    ///
    /// Computed, not stored. Apple Intelligence can be switched off in system
    /// Settings, and the model can still be downloading, so a value captured
    /// at init would go stale and claim a composer that is no longer in use.
    var isUsingLanguageModel: Bool {
        FoundationModelsSceneComposer.isModelAvailable
    }

    /// How often depth is read. Fast enough to notice someone stepping in
    /// front of the user, slow enough not to hold the CPU at a walk's expense
    /// — the cost per tick is one pixel-buffer reduction, not a model run.
    private static let sampleInterval: Duration = .milliseconds(750)

    private let source: AmbientSensingSource = .init()
    private let classifier: ObjectClassificationService = .init()
    private let phrasing: Phrasing = .init()

    private var composer: FoundationModelsSceneComposer = .init()
    private var engine: AwarenessEngine = .init()
    private var throttle: NarrationThrottle = .init()
    private var loopTask: Task<Void, Never>?
    private var backgroundObserver: NSObjectProtocol?
    private var lastDescribedAt: Date?
    private var locale: Locale = .current

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
        composer = FoundationModelsSceneComposer(phrasing: phrasing, locale: locale)
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
        await describeIfDue(frame, environment: environment)
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

    /// Classifies and narrates the scene, if enough time has passed and the
    /// channel is free.
    private func describeIfDue(_ frame: AmbientFrame, environment: AppEnvironment) async {
        let now = Date.now
        if let lastDescribedAt,
           now.timeIntervalSince(lastDescribedAt) < environment.settings.narrationIntervalSeconds {
            return
        }
        // Skipped rather than queued while speech is in flight. `render`
        // interrupts, which is right for a one-shot capture and wrong here —
        // it would cut every sentence off with the next one.
        if await environment.speech.isSpeaking {
            return
        }
        // Stamped before the work, not after: classification plus a model run
        // can outlast one tick, and stamping afterwards would let several ticks
        // start overlapping generations.
        lastDescribedAt = now

        let records: [PerceptionRecord]
        if detectedObjects.isEmpty {
            // Nothing stood out as a discrete object. That is the case a
            // whole-frame pass handles well — a corridor, a wall, an open room
            // — so fall back to it rather than going silent, which on this
            // channel would read as "nothing is there".
            do {
                records = try await classifier.classify(frame.image, orientation: frame.orientation)
            } catch {
                // A single unclassifiable frame is routine. Announcing it would
                // train the user to ignore this channel; the next tick retries.
                return
            }
        } else {
            records = detectedObjects.map {
                PerceptionRecord(
                    kind: .detectedObject(label: $0.label, confidence: $0.confidence),
                    capturedAt: now
                )
            }
        }
        guard let text = try? await composer.compose(from: records) else { return }
        guard throttle.shouldSpeak(text, at: Date.now) else { return }
        await deliver(
            text,
            signal: records.isEmpty ? .nothingFound : .resultReady,
            isUrgent: false,
            to: environment
        )
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

/// Turning machine facts — an error, a distance in metres — into the words the
/// user actually hears.
///
/// Split off from the session body because none of it touches session state:
/// these are pure functions of their arguments, and the loop above is long
/// enough without them.
private extension AmbientAwarenessSession {
    /// Turns a sensing failure into prose that tells the user what to do next.
    static func message(for error: Error) -> String {
        switch error {
        case AmbientSensingSource.SensingError.depthUnavailable:
            """
            Hands-free awareness needs a LiDAR depth sensor, which this device \
            does not have.
            """
        case AmbientSensingSource.SensingError.unsupportedDevice:
            "This device cannot run hands-free awareness."
        default:
            "Hands-free awareness couldn't start. Check camera access in Settings, then try again."
        }
    }

    /// Formats a distance in the reader's own units — metres in most of the
    /// world, feet in the US — rather than hardcoding this file's.
    static func formattedDistance(meters: Double, locale: Locale) -> String {
        let formatter = MeasurementFormatter()
        formatter.locale = locale
        formatter.unitOptions = .naturalScale
        formatter.numberFormatter.maximumFractionDigits = 1
        return formatter.string(from: Measurement(value: meters, unit: UnitLength.meters))
    }
}
