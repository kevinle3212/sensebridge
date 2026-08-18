import Foundation

/// Reading-screen copy: aiming guidance and playback position.
///
/// Split from `Phrasing.swift` for SwiftLint's length gates, not because the
/// doctrine differs — see `Phrasing+Awareness.swift`.
///
/// Nothing here is hedged, and that is correct rather than an oversight. Every
/// sentence in this file is a statement about **this app's own state**: what its
/// recognizer produced, where its playback cursor is. There is no claim about
/// the physical world to be uncertain about. The one place that boundary is easy
/// to cross is ``framingGuidance(for:locale:)``, whose copy is written about
/// recognition ("no text is being recognized") rather than about paper ("the
/// page is blank") — see docs/SAFETY-FRAMING.md on never asserting an absence.
public extension Phrasing {
    /// The one sentence to speak for a framing verdict, or `nil` when the frame
    /// is fine and there is nothing to say.
    ///
    /// `nil` for ``ReadingFraming/Guidance/wellFramed`` rather than a cheerful
    /// confirmation. Live reading evaluates several frames a second, and a
    /// channel that says "looks good" every time it has nothing to report is a
    /// channel the listener turns off.
    func framingGuidance(for guidance: ReadingFraming.Guidance, locale: Locale = .current) -> String? {
        switch guidance {
        case .noTextRecognized:
            LocalizedCatalog.string(
                "No text is being recognized. Try moving closer, or adding light.",
                locale: locale
            )
        case .textLooksSmall:
            LocalizedCatalog.string("The text looks small. Try moving closer.", locale: locale)
        case let .textRunsPastEdges(edges):
            LocalizedCatalog.string(Self.edgeGuidanceKey(for: edges), locale: locale)
        case .wellFramed:
            nil
        }
    }

    /// Where playback is, for a listener who has no progress bar.
    ///
    /// Spoken on demand rather than before every segment: prefixing "sentence 4
    /// of 30" to each utterance is how a two-minute page becomes a four-minute
    /// one. The Read screen offers it as its own control.
    func playbackPosition(_ position: Int, of total: Int, locale: Locale = .current) -> String {
        let template = LocalizedCatalog.string("Sentence %1$@ of %2$@.", locale: locale)
        let formatter = Self.numberFormatter(for: locale)
        let current = formatter.string(from: NSNumber(value: position)) ?? "\(position)"
        let count = formatter.string(from: NSNumber(value: total)) ?? "\(total)"
        return String(format: template, current, count)
    }

    /// What to say when playback reaches the end.
    ///
    /// Said out loud rather than left as silence. Silence at the end of a
    /// document is indistinguishable from speech that failed part-way through,
    /// and a listener who cannot see the screen has no other way to tell the
    /// two apart — the same reasoning behind
    /// ``Phrasing/awarenessStoppedOffScreen(locale:)``.
    func endOfDocument(locale: Locale = .current) -> String {
        LocalizedCatalog.string("End of the text.", locale: locale)
    }

    /// What to say when playback returns to the first segment.
    func restartedFromBeginning(locale: Locale = .current) -> String {
        LocalizedCatalog.string("Reading again from the beginning.", locale: locale)
    }

    /// Which page of a multi-page document is being read.
    func pagePosition(_ position: Int, of total: Int, locale: Locale = .current) -> String {
        let template = LocalizedCatalog.string("Page %1$@ of %2$@.", locale: locale)
        let formatter = Self.numberFormatter(for: locale)
        let current = formatter.string(from: NSNumber(value: position)) ?? "\(position)"
        let count = formatter.string(from: NSNumber(value: total)) ?? "\(total)"
        return String(format: template, current, count)
    }

    /// What to say when a page has been added to the document being built.
    func pageAdded(_ count: Int, locale: Locale = .current) -> String {
        let template = LocalizedCatalog.string("Page added. %@ pages so far.", locale: locale)
        let formatted = Self.numberFormatter(for: locale).string(from: NSNumber(value: count)) ?? "\(count)"
        return String(format: template, formatted)
    }

    /// The catalog key naming which way to move the camera.
    ///
    /// One complete sentence per case rather than a sentence assembled from an
    /// edge name, because "runs past the %@" would need every edge noun in a
    /// grammatical case the translator cannot see from the fragment alone.
    /// Two or more edges collapse to a single instruction: a listener follows
    /// one instruction at a time, and "move up and also left" is how spoken
    /// guidance stops being followed.
    private static func edgeGuidanceKey(for edges: Set<ReadingFraming.Edge>) -> String {
        guard edges.count == 1, let edge = edges.first else {
            return "Text runs past the edges of the frame. Try moving the camera back."
        }
        return switch edge {
        case .top: "Text runs past the top. Try tilting the camera up, or moving back."
        case .bottom: "Text runs past the bottom. Try tilting the camera down, or moving back."
        case .leading: "Text runs past the left. Try moving the camera left, or moving back."
        case .trailing: "Text runs past the right. Try moving the camera right, or moving back."
        }
    }
}
