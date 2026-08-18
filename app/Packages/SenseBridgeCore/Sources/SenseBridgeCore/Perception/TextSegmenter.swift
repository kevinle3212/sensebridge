import Foundation
import NaturalLanguage

/// Splits recognized text into the units playback moves through.
///
/// Reading a whole page as one utterance is what the previous Read screen did,
/// and it is unusable for anything longer than a label: `AVSpeechSynthesizer`
/// offers no way to move back a sentence, so a listener who missed a line had
/// to re-capture the photo. Playback needs discrete, addressable pieces, and
/// this is where a page becomes them.
///
/// Segmentation is Foundation's, not a hand-rolled split on `.` — the naive
/// version breaks on "Dr. Chen", "3.5 mg", "www.example.com", and every
/// abbreviation in Spanish and Vietnamese, and a listener stepping through
/// sentence-by-sentence feels each of those breaks. `enumerateSubstrings`
/// applies the locale's own sentence rules, so the same code is correct in all
/// three shipped languages.
///
/// Pure functions over `String`, deliberately free of Vision and AVFoundation,
/// so every edge case below is verifiable without a camera or a synthesizer.
public enum TextSegmenter {
    /// The longest a single segment may be, in characters.
    ///
    /// A cap exists because sentence detection has a failure mode that matters
    /// here: OCR of a page with no terminal punctuation — a poster, a menu, a
    /// form — yields one "sentence" the length of the whole page, which
    /// collapses playback back to the single-blob behaviour this type exists to
    /// replace. Over the cap, a segment is split again on the widest separator
    /// it contains.
    ///
    /// 280 characters is roughly 20 seconds of speech at the default rate: long
    /// enough that ordinary prose is never split mid-thought, short enough that
    /// "go back one" is a useful amount of going back.
    public static let maximumSegmentLength = 280

    /// Splits `text` into playback segments.
    ///
    /// - Parameters:
    ///   - text: Recognized text, one line per element, in reading order.
    ///   - locale: Whose sentence rules to apply. The user's chosen language,
    ///     not the process locale — the two differ whenever someone runs the
    ///     app in a language their phone is not set to.
    /// - Returns: Non-empty, whitespace-trimmed segments in reading order.
    ///   Empty when `text` holds nothing but whitespace, which is a valid
    ///   observation ("nothing was recognized") rather than a failure.
    public static func segments(from lines: [String], locale: Locale = .current) -> [String] {
        segments(from: joined(lines), locale: locale)
    }

    /// Splits one already-joined string into playback segments.
    ///
    /// The single-string entry point, for callers holding text that never went
    /// through `OCRService` — history playback, most obviously, which reloads a
    /// stored document rather than re-running perception on it.
    public static func segments(from text: String, locale: Locale = .current) -> [String] {
        var sentences = [String]()
        // `NLTokenizer` rather than `enumerateSubstrings(options: .localized)`,
        // which resolves against the *process* locale — the one thing this
        // parameter exists to override. Someone running the app in Vietnamese on
        // an English phone was getting English sentence rules, silently, while
        // every caller dutifully threaded a locale through.
        let tokenizer = NLTokenizer(unit: .sentence)
        if let language = locale.language.languageCode?.identifier {
            tokenizer.setLanguage(NLLanguage(language))
        }
        tokenizer.string = text
        tokenizer.enumerateTokens(in: text.startIndex ..< text.endIndex) { range, _ in
            let trimmed = text[range].trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty {
                sentences.append(trimmed)
            }
            return true
        }
        // A string with no sentence boundary at all — a single word, a bare
        // number — enumerates to nothing in some locales. Falling back to the
        // trimmed whole is what keeps a one-word label readable.
        if sentences.isEmpty {
            let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
            sentences = trimmed.isEmpty ? [] : [trimmed]
        }
        return sentences.flatMap { split($0, at: maximumSegmentLength) }
    }

    /// Joins OCR lines into one string for segmentation.
    ///
    /// Newline-joined rather than space-joined, because a newline is a sentence
    /// boundary hint to `enumerateSubstrings` and a space is not: a menu whose
    /// items carry no punctuation segments per item this way and into one
    /// run-on blob the other way.
    public static func joined(_ lines: [String]) -> String {
        lines
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: "\n")
    }

    /// Splits an over-long segment at the widest separator available, falling
    /// back to a character-count split when the text offers none.
    ///
    /// Tries newline, then a clause separator, then whitespace, then raw
    /// characters. The last resort splits mid-word, which is ugly and is still
    /// better than the alternative: a "segment" that is really the whole page.
    ///
    /// Recursion is bounded — each level splits on a strictly narrower
    /// separator, and the character split always makes progress — so no input
    /// can loop here.
    private static func split(_ segment: String, at limit: Int) -> [String] {
        guard segment.count > limit else { return [segment] }
        for separator in ["\n", "; ", ", ", " "] where segment.contains(separator) {
            let pieces = accumulate(segment.components(separatedBy: separator), separator: separator, limit: limit)
            // A separator that yields one piece no shorter than the input has
            // not divided anything — try the next one rather than recursing on
            // an unchanged string.
            if pieces.count > 1 {
                return pieces.flatMap { split($0, at: limit) }
            }
        }
        return segment.chunked(into: limit)
    }

    /// Regroups `pieces` into runs that each stay within `limit`.
    ///
    /// Splitting on a separator and taking each piece as a segment would turn a
    /// comma-heavy page into a stream of two-word fragments. Packing pieces
    /// back together up to the limit keeps segments as long as they are allowed
    /// to be, which is what makes stepping through them useful.
    private static func accumulate(_ pieces: [String], separator: String, limit: Int) -> [String] {
        var result = [String]()
        var current = ""
        for piece in pieces {
            let candidate = current.isEmpty ? piece : current + separator + piece
            if candidate.count <= limit || current.isEmpty {
                current = candidate
            } else {
                result.append(current)
                current = piece
            }
        }
        if !current.isEmpty {
            result.append(current)
        }
        return result.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
    }
}

/// The last-resort split `TextSegmenter` falls back to, kept `private` to this
/// file so nothing else acquires a habit of cutting text at a character count —
/// it is the option of last resort here precisely because it ignores meaning.
private extension String {
    /// Cuts this string into runs of at most `size` characters.
    ///
    /// Operates on `Character`s, not UTF-8 bytes or UTF-16 code units, so a
    /// grapheme cluster — an emoji with a skin-tone modifier, a Vietnamese
    /// vowel carrying two combining marks — is never split down the middle into
    /// two strings that each render as garbage.
    func chunked(into size: Int) -> [String] {
        guard size > 0, count > size else { return [self] }
        var result = [String]()
        var index = startIndex
        while index < endIndex {
            let end = self.index(index, offsetBy: size, limitedBy: endIndex) ?? endIndex
            let piece = String(self[index ..< end]).trimmingCharacters(in: .whitespacesAndNewlines)
            if !piece.isEmpty {
                result.append(piece)
            }
            index = end
        }
        return result
    }
}
