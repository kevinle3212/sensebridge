import Foundation

/// The semantic meaning behind an `OutputMessage`, independent of its spoken
/// text — a haptic or caption target has no prose to render, only a signal to
/// react to (see `HapticPattern.pattern(for:)`).
public enum OutputSignal: Sendable, Equatable, CaseIterable {
    /// A photo was captured; work is starting.
    case captureTaken
    /// A perception/reasoning result is ready to present.
    case resultReady
    /// Perception ran but found nothing to report.
    case nothingFound
    /// A failure occurred and could not be recovered from silently.
    case error
    /// An awareness condition started (e.g. a possible obstacle detected).
    case awarenessAlert
    /// A previously alerted awareness condition has cleared.
    ///
    /// **No caller emits this yet, on purpose.** It is only honest on a real
    /// alerting → not-alerting *transition*, where the app is reporting a
    /// change it actually observed. Emitting it on a first or standalone
    /// evaluation is a tactile "stand down" derived from one sample — and
    /// unlike prose, a fading buzz carries no hedge to soften it. Awareness
    /// screens send `.nothingFound` instead, which claims only that nothing
    /// was recognized. Wire this up when continuous depth sensing lands and
    /// there is a transition to report.
    case awarenessClear
}

/// A message to deliver to the user, paired with the semantic signal behind
/// it. `text` is prose for channels that can speak or caption; `signal` is
/// what a haptic-only channel reacts to when there is no text to render.
public struct OutputMessage: Sendable, Equatable {
    /// The spoken/captioned prose, already hedged per docs/SAFETY-FRAMING.md.
    public let text: String
    /// The semantic signal this message represents.
    public let signal: OutputSignal

    /// Creates a message pairing prose with its semantic signal.
    public init(text: String, signal: OutputSignal) {
        self.text = text
        self.signal = signal
    }
}

/// Delivers a composed message to the user through one sense. Speech is the
/// MVP target; caption and haptic targets arrive later without Reasoning
/// changing at all — see docs/ARCHITECTURE.md "Output Layer".
public protocol RenderTarget: Sendable {
    /// Delivers `message` to the user through this target's sense.
    func render(_ message: OutputMessage) async
}

// A `render(_ text: String)` convenience defaulting to `.resultReady`
// deliberately does **not** exist. It was added during the migration to keep
// old `String` call sites compiling, and it is backwards for a channel whose
// entire purpose is that the signal tracks meaning: a future error or
// awareness string passed as bare prose would silently buzz "a result is
// ready". Every caller now names its `OutputSignal`, which is the point —
// make the compiler ask, since a haptic target renders the signal alone and
// discards the text.
