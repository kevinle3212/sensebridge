import Foundation

#if os(iOS) && canImport(CoreHaptics)
    import CoreHaptics
    import UIKit
#endif

/// Delivers `OutputMessage`s as haptic cues built from `HapticPattern`, via
/// `CHHapticEngine` where the hardware supports it and `UIFeedbackGenerator`
/// otherwise (e.g. iPhone SE-class devices, Simulator). An actor so engine
/// setup and playback never run on the main thread — see
/// docs/ARCHITECTURE.md "Main thread stays free". This package also builds
/// for macOS 15, where there is no haptics hardware and `render` is a no-op.
public actor HapticRenderTarget: RenderTarget {
    private var isEnabled: Bool
    private var intensityMultiplier: Double

    #if os(iOS) && canImport(CoreHaptics)
        private var engine: CHHapticEngine?
        private var supportsHaptics = false
        private var hasPreparedEngine = false
    #endif

    /// Creates a haptic target. `intensity` is clamped to `0...1`.
    ///
    /// Deliberately does no hardware work: a non-`async` actor initializer
    /// runs on the **caller's** context, not the actor's executor, and
    /// `AppEnvironment` constructs this on `@MainActor` at app launch.
    /// Building and starting a `CHHapticEngine` there would block the main
    /// thread during startup — see `prepareEngineIfNeeded()`.
    public init(enabled: Bool = true, intensity: Double = 1.0) {
        isEnabled = enabled
        intensityMultiplier = min(max(intensity, 0), 1)
    }

    /// Enables or disables haptic output; `render` is a no-op while disabled.
    public func setEnabled(_ enabled: Bool) {
        isEnabled = enabled
    }

    /// Updates the intensity multiplier applied to every pattern via
    /// `HapticPattern.scaled(by:)`. Clamped to `0...1`.
    public func setIntensity(_ intensity: Double) {
        intensityMultiplier = min(max(intensity, 0), 1)
    }

    /// Plays the pattern for `message.signal`. `message.text` is ignored — a
    /// haptic cue carries a signal, not prose.
    public func render(_ message: OutputMessage) async {
        guard isEnabled else { return }
        #if os(iOS) && canImport(CoreHaptics)
            prepareEngineIfNeeded()
            let pattern = HapticPattern.pattern(for: message.signal).scaled(by: intensityMultiplier)
            if supportsHaptics, let engine {
                await play(pattern, on: engine)
            } else {
                await Self.playFallback(pattern)
            }
        #endif
    }

    #if os(iOS) && canImport(CoreHaptics)
        /// Builds and starts the haptics engine, once, on first use.
        ///
        /// Deferred out of `init` so this never runs on the main thread at
        /// app launch — see the initializer's note and
        /// docs/ARCHITECTURE.md "Main thread stays free".
        private func prepareEngineIfNeeded() {
            guard !hasPreparedEngine else { return }
            hasPreparedEngine = true
            supportsHaptics = CHHapticEngine.capabilitiesForHardware().supportsHaptics
            guard supportsHaptics, let created = try? CHHapticEngine() else { return }
            engine = created
            // CHHapticEngine dies on audio-session interruption and otherwise
            // stops working silently — both handlers restart it so haptics
            // keep working after e.g. a phone call.
            created.resetHandler = {
                Task { [weak self] in await self?.restartEngine() }
            }
            created.stoppedHandler = { _ in
                Task { [weak self] in await self?.restartEngine() }
            }
            try? created.start()
        }

        /// Restarts the engine after `resetHandler`/`stoppedHandler` fires.
        /// Best-effort: if the restart itself fails, haptics silently stay
        /// off rather than crashing — see the reliability priority order in
        /// docs/SAFETY-FRAMING.md (hedging, then not crashing, then performance).
        private func restartEngine() {
            try? engine?.start()
        }

        /// Converts `pattern` into a `CHHapticPattern` and plays it once.
        /// Never throws outward: any engine failure degrades to silence.
        private func play(_ pattern: HapticPattern, on engine: CHHapticEngine) async {
            do {
                let events = pattern.events.map { event in
                    CHHapticEvent(
                        eventType: event.duration > 0 ? .hapticContinuous : .hapticTransient,
                        parameters: [
                            CHHapticEventParameter(parameterID: .hapticIntensity, value: Float(event.intensity)),
                            CHHapticEventParameter(parameterID: .hapticSharpness, value: Float(event.sharpness))
                        ],
                        relativeTime: event.relativeTime,
                        duration: event.duration
                    )
                }
                let chPattern = try CHHapticPattern(events: events, parameters: [])
                let player = try engine.makePlayer(with: chPattern)
                try player.start(atTime: CHHapticTimeImmediate)
            } catch {
                // Degrade to silence — never crash on a haptics failure.
            }
        }

        /// Fallback for hardware without full Core Haptics support
        /// (Simulator, SE-class devices), replaying **the same
        /// `HapticPattern`** as a sequence of impacts.
        ///
        /// The previous mapping reached for `UINotificationFeedbackGenerator`
        /// and was wrong in three ways at once. `.warning`/`.error` are
        /// reserved by the system for "something is wrong, act now" — an
        /// urgency and a certainty this app's prose deliberately hedges, and
        /// the tactile channel carries no hedge to soften it. They are also
        /// neighbouring patterns, so "camera failed" and "possible obstacle
        /// ahead" became confusable. And it collapsed six signals into four
        /// cues, making `.captureTaken`/`.resultReady` identical and
        /// `.nothingFound`/`.awarenessClear` near-indistinguishable — so "no
        /// text in this photo" could read as "the obstacle cleared".
        ///
        /// Replaying the pattern keeps all six distinguishable by the rhythm
        /// `HapticPattern` documents them by, borrows no system semantics,
        /// and honours the user's intensity multiplier via
        /// `impactOccurred(intensity:)` — which the old mapping silently
        /// discarded, so a user who set intensity to 0.2 still got
        /// full-strength cues. On a tactile channel, strength reads as
        /// confidence.
        ///
        /// Continuous events collapse to one impact at their start time:
        /// `UIFeedbackGenerator` has no sustained-vibration equivalent. So
        /// `.awarenessAlert` reads as three rising taps rather than a swell —
        /// weaker than the real pattern, but the same claim, not a louder one.
        ///
        /// Must run on the main actor: Apple documents feedback generators as
        /// main-thread APIs.
        @MainActor
        private static func playFallback(_ pattern: HapticPattern) async {
            var elapsed: TimeInterval = 0
            for event in pattern.events {
                let wait = event.relativeTime - elapsed
                if wait > 0 {
                    try? await Task.sleep(for: .seconds(wait))
                    elapsed = event.relativeTime
                }
                let style: UIImpactFeedbackGenerator.FeedbackStyle = switch event.sharpness {
                case ...0.3: .soft
                case 0.7...: .rigid
                default: .medium
                }
                UIImpactFeedbackGenerator(style: style)
                    .impactOccurred(intensity: CGFloat(event.intensity))
            }
        }
    #endif
}
