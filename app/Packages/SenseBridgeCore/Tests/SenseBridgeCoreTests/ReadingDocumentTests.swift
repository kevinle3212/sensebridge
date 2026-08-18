import Foundation
import Testing
@testable import SenseBridgeCore

struct ReadingDocumentTests {
    @Test
    func joinsPagesWithABlankLineSoNoSegmentSpansAPageTurn() {
        let document = ReadingDocument(pages: ["Page one.", "Page two."])

        #expect(document.text == "Page one.\n\nPage two.")
    }

    @Test
    func keepsBlankPagesInThePageArrayButOutOfThePlaybackText() {
        // Dropping the page would renumber every page after it, so "page 2 of 3"
        // would start naming the wrong page.
        let document = ReadingDocument(pages: ["One.", "   ", "Three."])

        #expect(document.pages.count == 3)
        #expect(document.text == "One.\n\nThree.")
    }

    @Test
    func reportsThatRecognitionFoundNothingRatherThanThatThePageIsBlank() {
        // The property name is the assertion under test: this is a claim about
        // recognition, not about the paper. See docs/SAFETY-FRAMING.md.
        #expect(ReadingDocument(pages: []).recognizedNothing)
        #expect(ReadingDocument(pages: ["", "  \n "]).recognizedNothing)
        #expect(!ReadingDocument(pages: ["Gate 12."]).recognizedNothing)
    }

    @Test
    func returnsShortTextUnchangedAsItsSummary() {
        #expect(ReadingDocument(pages: ["Gate 12."]).summary() == "Gate 12.")
    }

    @Test
    func truncatesASummaryOnAWordBoundaryBecauseVoiceOverReadsItAloud() {
        let document = ReadingDocument(pages: [String(repeating: "alpha ", count: 40)])

        let summary = document.summary(limit: 20)

        #expect(summary.hasSuffix("…"))
        #expect(!summary.contains("alph…"))
        #expect(summary.count <= 21)
    }

    @Test
    func flattensNewlinesIntoSpacesSoASummaryReadsAsOneLine() {
        let document = ReadingDocument(pages: ["Soup\nBread", "Cheese"])

        #expect(document.summary() == "Soup Bread  Cheese")
    }

    @Test
    func fallsBackToACharacterClipWhenThereIsNoSpaceToBreakOn() {
        let document = ReadingDocument(pages: [String(repeating: "a", count: 100)])

        #expect(document.summary(limit: 10) == String(repeating: "a", count: 10))
    }

    @Test
    func roundTripsThroughJSONSoAStoredHistoryDecodesBackIdentically() throws {
        let original = try ReadingDocument(
            id: #require(UUID(uuidString: "11111111-2222-3333-4444-555555555555")),
            capturedAt: Date(timeIntervalSince1970: 1_700_000_000),
            pages: ["Ngày mai", "👋🏽 hello"]
        )

        let decoded = try JSONDecoder().decode(
            ReadingDocument.self, from: JSONEncoder().encode(original)
        )

        #expect(decoded == original)
    }

    @Test
    func givesTwoPhotosOfTheSameSignDistinctIdentities() {
        let first = ReadingDocument(pages: ["Exit"])
        let second = ReadingDocument(pages: ["Exit"])

        #expect(first.id != second.id)
        #expect(first != second)
    }
}
