import Foundation

/// Where playback is within a read document, and how it moves.
///
/// A cursor over segments and nothing more — it holds no synthesizer, starts no
/// task, and speaks nothing. That separation is the point: "what should be
/// spoken next after the user pressed back twice at the end of a document" is
/// ordinary logic with a dozen edge cases, and it is only cheap to test when it
/// is not entangled with `AVSpeechSynthesizer`. The app layer owns the speaking;
/// this owns the answer to *what*.
///
/// ## Why the end is a state, not an index
///
/// Running off the end is not the same as sitting on the last segment. A
/// listener who has heard the whole page and one who is part-way through its
/// final sentence need different things offered to them — "read it again" versus
/// "carry on" — and a blind listener cannot see which of the two they are in.
/// `isFinished` makes that distinction explicit rather than leaving callers to
/// infer it from an index comparison each one gets subtly wrong.
public struct ReadingPlayback: Sendable, Equatable {
    /// The segments, in reading order. Empty is a legitimate state: a photo of
    /// a blank wall produces one.
    public private(set) var segments: [String]

    /// Which segment is current, or `nil` when playback has run past the end or
    /// there is nothing to play.
    public private(set) var index: Int?

    /// Creates a cursor positioned at the first segment.
    ///
    /// - Parameter segments: Playback units in reading order, as produced by
    ///   ``TextSegmenter``. Blank and whitespace-only entries are dropped here
    ///   rather than trusted, so a caller assembling segments by hand cannot
    ///   introduce a silent gap in playback — a segment that speaks as nothing
    ///   is indistinguishable, to a listener, from the app having stopped.
    public init(segments: [String]) {
        let usable = segments
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        self.segments = usable
        index = usable.isEmpty ? nil : 0
    }

    /// The segment to speak now, or `nil` when there is nothing to speak.
    public var current: String? {
        guard let index, segments.indices.contains(index) else { return nil }
        return segments[index]
    }

    /// Whether playback has run past the last segment.
    ///
    /// `false` for an empty document: nothing was ever played, so nothing has
    /// finished. Conflating the two would have the app offer "read it again"
    /// for a page it never read.
    public var isFinished: Bool {
        index == nil && !segments.isEmpty
    }

    /// How many segments there are — the denominator of "3 of 12", which is the
    /// only progress indication a listener gets.
    public var count: Int {
        segments.count
    }

    /// The current segment's position, 1-based, or `nil` when there is no
    /// current segment. 1-based because it is spoken to a person, and "segment
    /// zero of twelve" is not a sentence anyone says.
    public var position: Int? {
        index.map { $0 + 1 }
    }

    /// Advances to the next segment, running past the end when there is none.
    ///
    /// - Returns: The segment now current, or `nil` if playback just finished.
    ///   Returning the segment rather than `Void` is what lets a caller write
    ///   `while let next = playback.advance()` instead of interleaving a
    ///   mutation and a read that can drift apart.
    @discardableResult
    public mutating func advance() -> String? {
        guard let index else { return nil }
        let next = index + 1
        self.index = segments.indices.contains(next) ? next : nil
        return current
    }

    /// Steps back one segment.
    ///
    /// From past the end this lands on the **last** segment rather than doing
    /// nothing, which is what a listener means by "back" after hearing a
    /// document finish. Already at the first segment, it stays there and
    /// re-reads it — a no-op would be silence, and silence on a channel a blind
    /// user cannot see is indistinguishable from a broken control.
    ///
    /// - Returns: The segment now current, or `nil` for an empty document.
    @discardableResult
    public mutating func retreat() -> String? {
        guard !segments.isEmpty else { return nil }
        guard let index else {
            index = segments.count - 1
            return current
        }
        self.index = max(index - 1, 0)
        return current
    }

    /// Returns to the first segment, from anywhere including past the end.
    @discardableResult
    public mutating func restart() -> String? {
        index = segments.isEmpty ? nil : 0
        return current
    }

    /// Moves to a specific segment, for a history list or a re-read.
    ///
    /// Out-of-range input is clamped rather than trapping: the argument
    /// originates in a list selection, and a list that has been reloaded
    /// underneath a stale selection is an ordinary race, not a programming
    /// error worth crashing a blind user's app over.
    @discardableResult
    public mutating func move(to position: Int) -> String? {
        guard !segments.isEmpty else { return nil }
        index = min(max(position, 0), segments.count - 1)
        return current
    }
}
