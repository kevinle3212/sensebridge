import Foundation

/// Decides whether a freshly composed narration should actually be spoken.
///
/// Hands-free awareness composes a description every few seconds, and most of
/// those descriptions are identical to the last one — a user standing still in
/// a kitchen would otherwise hear "it looks like there's a refrigerator."
/// every four seconds for as long as they stand there. That is not merely
/// annoying: a channel that repeats regardless of whether anything changed
/// teaches the user to stop listening to it, which is the failure mode that
/// matters when something *has* changed.
///
/// Pure value logic with the clock injected at the call site, so the interval
/// and repeat behaviour are verifiable without waiting in real time.
public struct NarrationThrottle: Sendable {
    /// Shortest gap between two spoken narrations, however different.
    public let minimumInterval: TimeInterval
    /// How long an identical narration stays suppressed. Longer than
    /// `minimumInterval` on purpose — an unchanged scene should go quiet, but
    /// not permanently, or the user cannot tell "unchanged" from "stopped
    /// working". Re-speaking it periodically is the liveness cue.
    public let repeatSuppressionInterval: TimeInterval

    private var lastSpokenText: String?
    private var lastSpokenAt: Date?

    /// Creates a throttle. Defaults suit an in-ear channel worn continuously:
    /// speak at most every 4 s, and re-state an unchanged scene every 20 s.
    public init(minimumInterval: TimeInterval = 4, repeatSuppressionInterval: TimeInterval = 20) {
        self.minimumInterval = minimumInterval
        self.repeatSuppressionInterval = repeatSuppressionInterval
    }

    /// Whether `text` should be spoken now, recording it as spoken when so.
    ///
    /// - Parameters:
    ///   - text: The composed narration.
    ///   - now: The current time, injected rather than read, so this is testable.
    ///   - isUrgent: `true` only for a real `AwarenessTransition` — something
    ///     changed that the user asked to be told about. Urgent messages
    ///     bypass both intervals, because a transition fires once per crossing
    ///     rather than once per frame, so it cannot flood the channel.
    /// - Returns: `true` if the caller should render `text`.
    public mutating func shouldSpeak(_ text: String, at now: Date, isUrgent: Bool = false) -> Bool {
        guard !isUrgent else {
            record(text, at: now)
            return true
        }
        if let lastSpokenAt, now.timeIntervalSince(lastSpokenAt) < minimumInterval {
            return false
        }
        if text == lastSpokenText,
           let lastSpokenAt,
           now.timeIntervalSince(lastSpokenAt) < repeatSuppressionInterval {
            return false
        }
        record(text, at: now)
        return true
    }

    /// Clears the history so a newly started session speaks its first
    /// observation immediately, rather than inheriting the suppression state
    /// of a session that ended in a different room.
    public mutating func reset() {
        lastSpokenText = nil
        lastSpokenAt = nil
    }

    private mutating func record(_ text: String, at now: Date) {
        lastSpokenText = text
        lastSpokenAt = now
    }
}
