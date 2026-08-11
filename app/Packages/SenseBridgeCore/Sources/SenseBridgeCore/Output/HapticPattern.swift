import Foundation

/// One vibration within a `HapticPattern`, described independently of any
/// haptics engine so patterns are testable off-device — `HapticRenderTarget`
/// is the only place that turns these into `CHHapticEvent`s.
public struct HapticEvent: Sendable, Equatable {
    /// When this event starts, in seconds relative to the pattern's start.
    public let relativeTime: TimeInterval
    /// Vibration strength, `0` weakest to `1` strongest.
    public let intensity: Double
    /// Vibration texture, `0` softest/dullest to `1` sharpest/crispest.
    public let sharpness: Double
    /// How long the event plays, in seconds. `0` is a transient (a single
    /// tap); anything greater is a continuous buzz for that duration.
    public let duration: TimeInterval

    /// Creates a haptic event. `duration` defaults to `0`, a transient tap.
    public init(relativeTime: TimeInterval, intensity: Double, sharpness: Double, duration: TimeInterval = 0) {
        self.relativeTime = relativeTime
        self.intensity = intensity
        self.sharpness = sharpness
        self.duration = duration
    }
}

/// A pure, engine-free description of a haptic pattern: a sequence of
/// `HapticEvent`s, so a pattern is testable off-device without
/// `CHHapticEngine`.
///
/// **These are a small, fixed set of awareness cues, not a haptic
/// language.** Each `OutputSignal` maps to one memorable rhythm — enough to
/// tell "photo taken" from "error" by feel — nothing more. A real deaf-blind
/// haptic vocabulary requires co-design with deaf-blind collaborators and is
/// deliberately out of scope here; see
/// deprecated/planning/SENSEBRIDGE-01-STRATEGY-AND-PRODUCT.md:144. Do not
/// extend this type to imply a vocabulary exists.
public struct HapticPattern: Sendable, Equatable {
    /// The events that make up this pattern, in playback order.
    public let events: [HapticEvent]

    /// Creates a pattern from an explicit event list.
    public init(events: [HapticEvent]) {
        self.events = events
    }

    /// The pattern for a given signal. Each is distinguishable from the
    /// others by rhythm (tap count, timing, continuous-vs-transient), not
    /// just by strength, so it reads by feel alone:
    /// - `captureTaken`: a single confirming tap.
    /// - `resultReady`: two quick taps — "something's here, go check it".
    /// - `nothingFound`: one soft, dull tap — low-key, easy to miss on purpose.
    /// - `error`: three sharp taps in quick succession — the most urgent-feeling cue.
    /// - `awarenessAlert`: a short continuous buzz that ramps up — attention rising.
    /// - `awarenessClear`: a continuous buzz that fades out — the alert relaxing, not stopping abruptly.
    public static func pattern(for signal: OutputSignal) -> HapticPattern {
        switch signal {
        case .captureTaken:
            HapticPattern(events: [
                HapticEvent(relativeTime: 0, intensity: 0.7, sharpness: 0.6)
            ])
        case .resultReady:
            HapticPattern(events: [
                HapticEvent(relativeTime: 0, intensity: 0.7, sharpness: 0.6),
                HapticEvent(relativeTime: 0.12, intensity: 0.7, sharpness: 0.6)
            ])
        case .nothingFound:
            HapticPattern(events: [
                HapticEvent(relativeTime: 0, intensity: 0.3, sharpness: 0.2)
            ])
        case .error:
            HapticPattern(events: [
                HapticEvent(relativeTime: 0, intensity: 0.9, sharpness: 1.0),
                HapticEvent(relativeTime: 0.1, intensity: 0.9, sharpness: 1.0),
                HapticEvent(relativeTime: 0.2, intensity: 0.9, sharpness: 1.0)
            ])
        case .awarenessAlert:
            HapticPattern(events: [
                HapticEvent(relativeTime: 0, intensity: 0.4, sharpness: 0.5, duration: 0.2),
                HapticEvent(relativeTime: 0.2, intensity: 0.7, sharpness: 0.5, duration: 0.2),
                HapticEvent(relativeTime: 0.4, intensity: 1.0, sharpness: 0.5, duration: 0.2)
            ])
        case .awarenessClear:
            HapticPattern(events: [
                HapticEvent(relativeTime: 0, intensity: 0.6, sharpness: 0.3, duration: 0.2),
                HapticEvent(relativeTime: 0.2, intensity: 0.2, sharpness: 0.3, duration: 0.2)
            ])
        }
    }

    /// Multiplies every event's intensity by a user-set multiplier, clamped
    /// to `0...1` so an out-of-range setting can't invert or overdrive the
    /// pattern.
    public func scaled(by intensity: Double) -> HapticPattern {
        let multiplier = min(max(intensity, 0), 1)
        return HapticPattern(events: events.map { event in
            HapticEvent(
                relativeTime: event.relativeTime,
                intensity: event.intensity * multiplier,
                sharpness: event.sharpness,
                duration: event.duration
            )
        })
    }
}
