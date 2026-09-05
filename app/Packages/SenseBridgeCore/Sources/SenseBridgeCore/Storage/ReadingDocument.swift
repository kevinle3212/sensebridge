import Foundation

/// One thing the user read, as pages of recognized text.
///
/// Pages rather than a single blob because a multi-page capture is one
/// *document* — a listener stepping back through a two-page letter expects to
/// cross the page boundary, not to find two unrelated entries in a history list.
/// The pages are kept separate rather than pre-joined so a caller can still say
/// "page 2 of 3", which is the only orientation a blind reader gets in a
/// document long enough to get lost in.
public struct ReadingDocument: Sendable, Equatable, Codable, Identifiable {
    /// Stable identity, so a history list can reorder or delete without keying
    /// on the text — two photos of the same sign produce identical text and
    /// must still be two entries.
    public let id: UUID
    /// When the first page was captured.
    public let capturedAt: Date
    /// Recognized text, one entry per captured page, in capture order.
    public let pages: [String]

    /// Creates a document.
    ///
    /// - Parameters:
    ///   - id: Defaults to a fresh identity; injectable so tests are
    ///     deterministic.
    ///   - capturedAt: When capture happened.
    ///   - pages: One text blob per page. Blank pages are kept rather than
    ///     dropped — a page that recognized nothing is a real event the reader
    ///     needs to hear about, and silently removing it would renumber every
    ///     page after it.
    public init(id: UUID = UUID(), capturedAt: Date = .now, pages: [String]) {
        self.id = id
        self.capturedAt = capturedAt
        self.pages = pages
    }

    /// Every page joined for playback, blank-line separated.
    ///
    /// A blank line rather than a newline: `TextSegmenter` treats a newline as a
    /// segmentation hint, and running the last line of one page into the first
    /// line of the next would produce a segment that spans a page turn.
    public var text: String {
        pages.filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
            .joined(separator: "\n\n")
    }

    /// Whether nothing was recognized on any page.
    ///
    /// Named for what it observes — that recognition produced nothing — rather
    /// than `isBlank`, which would be a claim about the paper. See
    /// docs/SAFETY-FRAMING.md.
    public var recognizedNothing: Bool {
        text.isEmpty
    }

    /// A short label for a history row, taken from the start of the text.
    ///
    /// Truncated on a word boundary rather than mid-word: this string is read
    /// aloud by VoiceOver when the user swipes over the row, and a clipped word
    /// is heard as a mispronunciation rather than as an abbreviation.
    ///
    /// - Parameter limit: Longest label to produce, in characters.
    public func summary(limit: Int = 60) -> String {
        let flattened = text
            .replacing("\n", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard flattened.count > limit else { return flattened }
        let clipped = String(flattened.prefix(limit))
        guard let lastSpace = clipped.lastIndex(of: " ") else { return clipped }
        return String(clipped[clipped.startIndex ..< lastSpace]) + "…"
    }
}
