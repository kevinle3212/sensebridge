import Foundation
import Testing
@testable import SenseBridgeCore

struct ReasoningOutputValidatorTests {
    private let validator: ReasoningOutputValidator = .init()
    private let en: Locale = .init(identifier: "en")

    /// The regression test for the worst bug this project can ship: a
    /// network model returning an unhedged, confident, distance-and-danger
    /// sentence must never reach `Phrasing.describe` unvalidated. See
    /// docs/superpowers/specs/2026-08-11-awareness-ai-tiers-design.md
    /// "The output validator".
    @Test func unhedgedDistanceAndDangerSentenceIsRejected() {
        #expect(throws: (any Error).self) {
            try validator.validate(
                "There is a car about 2 feet ahead — dangerous",
                locale: en
            )
        }
    }

    @Test func plainNounPhraseIsAccepted() throws {
        let result = try validator.validate("a chair and a doorway", locale: en)
        #expect(result == "a chair and a doorway")
    }

    @Test func sentencePunctuationIsRejected() {
        #expect(throws: (any Error).self) {
            try validator.validate("a chair.", locale: en)
        }
    }

    @Test func newlineIsRejected() {
        #expect(throws: (any Error).self) {
            try validator.validate("a chair\nand a doorway", locale: en)
        }
    }

    @Test func overTwelveWordsIsRejected() {
        let long = (1 ... 13).map { "word\($0)" }.joined(separator: " ")
        #expect(throws: (any Error).self) {
            try validator.validate(long, locale: en)
        }
    }

    @Test func emptyAfterTrimmingIsRejected() {
        #expect(throws: (any Error).self) {
            try validator.validate("   ", locale: en)
        }
    }

    @Test func distanceAndDangerTokensAreRejectedInEnglish() {
        for phrase in ["a chair 2 meters away", "a dangerous doorway", "something on your left"] {
            #expect(throws: (any Error).self, "\(phrase) should be rejected") {
                try validator.validate(phrase, locale: en)
            }
        }
    }

    @Test func distanceAndDangerTokensAreRejectedInSpanish() {
        let es = Locale(identifier: "es")
        #expect(throws: (any Error).self) {
            try validator.validate("una silla peligrosa", locale: es)
        }
    }

    @Test func distanceAndDangerTokensAreRejectedInVietnamese() {
        let vi = Locale(identifier: "vi")
        #expect(throws: (any Error).self) {
            try validator.validate("một cái ghế nguy hiểm", locale: vi)
        }
    }

    @Test func hedgeFragmentDoubleWrapIsRejected() {
        #expect(throws: (any Error).self) {
            try validator.validate("it looks like there's a chair", locale: en)
        }
    }

    @Test func numeralsAreRejected() {
        #expect(throws: (any Error).self) {
            try validator.validate("2 chairs", locale: en)
        }
    }
}
