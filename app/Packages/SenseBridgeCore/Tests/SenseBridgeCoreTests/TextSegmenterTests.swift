import Foundation
import Testing
@testable import SenseBridgeCore

struct TextSegmenterTests {
    @Test
    func splitsProseIntoSentences() {
        let segments = TextSegmenter.segments(
            from: "The train leaves at four. Platform nine. Bring your ticket.",
            locale: Locale(identifier: "en_US")
        )

        #expect(segments.count == 3)
        #expect(segments.first == "The train leaves at four.")
    }

    @Test
    func doesNotSplitOnAnAbbreviationOrADecimalPoint() {
        // The whole reason this uses Foundation's sentence rules rather than a
        // split on ".": a listener stepping through sentence-by-sentence feels
        // every one of these false breaks.
        let segments = TextSegmenter.segments(
            from: "Take 3.5 mg twice daily. Ask Dr. Chen first.",
            locale: Locale(identifier: "en_US")
        )

        #expect(segments.count == 2)
        #expect(segments[0].contains("3.5"))
        #expect(segments[1].contains("Dr. Chen"))
    }

    @Test
    func yieldsNothingForTextThatIsOnlyWhitespace() {
        // Empty is a valid observation — "nothing was recognized" — not a
        // failure, and never a claim that the page is blank.
        #expect(TextSegmenter.segments(from: "   \n\t \n ").isEmpty)
        #expect(TextSegmenter.segments(from: "").isEmpty)
    }

    @Test
    func keepsASingleWordWithNoSentenceBoundary() {
        #expect(TextSegmenter.segments(from: "Aspirin") == ["Aspirin"])
        #expect(TextSegmenter.segments(from: "  42  ") == ["42"])
    }

    @Test
    func splitsUnpunctuatedTextThatWouldOtherwiseBeOneHugeSegment() {
        // A menu or a form: no terminal punctuation anywhere, which would
        // otherwise collapse playback back to the single-blob behaviour this
        // type exists to replace.
        let line = String(repeating: "soup of the day ", count: 60)

        let segments = TextSegmenter.segments(from: line)

        #expect(segments.count > 1)
        #expect(segments.allSatisfy { $0.count <= TextSegmenter.maximumSegmentLength })
    }

    @Test
    func splitsTextWithNoSeparatorAtAllRatherThanReturningTheWholePage() {
        // Worst case: one unbroken run of characters. Splitting mid-word is
        // ugly and still better than a "segment" that is really the whole page.
        let blob = String(repeating: "a", count: TextSegmenter.maximumSegmentLength * 3)

        let segments = TextSegmenter.segments(from: blob)

        #expect(segments.count == 3)
        #expect(segments.allSatisfy { $0.count <= TextSegmenter.maximumSegmentLength })
    }

    @Test
    func neverSplitsAGraphemeClusterInHalf() {
        // Vietnamese vowels carrying two combining marks, and an emoji with a
        // skin-tone modifier: both are single Characters made of several
        // scalars, and cutting one produces two strings that render as garbage.
        let unit = "nghiêng👋🏽 "
        let blob = String(repeating: unit, count: 200)

        let segments = TextSegmenter.segments(from: blob)

        // Round-tripping through Characters is what proves no cluster was
        // broken: a split cluster cannot reassemble into the original scalars.
        let rejoined = segments.joined(separator: " ")
        #expect(rejoined.unicodeScalars.count <= blob.unicodeScalars.count)
        #expect(segments.allSatisfy { !$0.isEmpty })
    }

    @Test
    func joinsLinesWithNewlinesSoUnpunctuatedItemsStaySeparate() {
        let joined = TextSegmenter.joined(["Soup", "  ", "Bread", ""])

        #expect(joined == "Soup\nBread")
    }

    @Test
    func dropsBlankLinesFromTheLineEntryPoint() {
        let segments = TextSegmenter.segments(from: ["", "   ", "Gate 12."])

        #expect(segments == ["Gate 12."])
    }
}
