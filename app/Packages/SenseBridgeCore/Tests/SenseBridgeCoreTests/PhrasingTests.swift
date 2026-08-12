import Foundation
import Testing
@testable import SenseBridgeCore

struct PhrasingTests {
    @Test(arguments: [
        (confidence: 0.1, expected: Certainty.low),
        (confidence: 0.49, expected: Certainty.low),
        (confidence: 0.5, expected: Certainty.medium),
        (confidence: 0.79, expected: Certainty.medium),
        (confidence: 0.8, expected: Certainty.high),
        (confidence: 1.0, expected: Certainty.high)
    ])
    func certaintyBucketing(confidence: Double, expected: Certainty) {
        #expect(Phrasing.certainty(forConfidence: confidence) == expected)
    }

    @Test(arguments: [Certainty.low, .medium, .high])
    func everyCertaintyLevelProducesHedgedOutput(certainty: Certainty) {
        let phrase = Phrasing().describe(subject: "a chair", certainty: certainty)

        // The core safety-framing invariant (docs/SAFETY-FRAMING.md): never
        // an unhedged assertion, no matter how confident the detector was.
        let unhedgedAssertionPrefixes = ["there is ", "there's ", "a chair is"]
        for prefix in unhedgedAssertionPrefixes {
            #expect(!phrase.lowercased().hasPrefix(prefix))
        }
        #expect(!phrase.lowercased().contains("safe"))
        #expect(phrase.contains("a chair"))
    }

    @Test(arguments: [
        (localeIdentifier: "en", expected: "Nothing recognizable was found."),
        (localeIdentifier: "es", expected: "No se reconoció nada."),
        (localeIdentifier: "vi", expected: "Không nhận ra được gì.")
    ])
    func nothingRecognizedIsTranslatedAndClaimsNoAbsence(localeIdentifier: String, expected: String) {
        let phrase = Phrasing().nothingRecognized(locale: Locale(identifier: localeIdentifier))
        #expect(phrase == expected)
    }

    /// Guards the C1 regression directly: the awareness screen used to say
    /// "The way ahead seems clear for now." A hedged verb does not rescue a
    /// claim about absence — see `audits/AGENT-GUIDE.md`. Every phrase this
    /// type produces must describe what was *recognized*, never what is
    /// *there*.
    @Test
    func nothingRecognizedNeverAssertsThatSomethingIsAbsent() {
        let phrase = Phrasing().nothingRecognized(locale: Locale(identifier: "en")).lowercased()
        let absenceClaims = ["clear", "empty", "safe", "no obstacle", "nothing is", "nothing ahead"]
        for claim in absenceClaims {
            #expect(!phrase.contains(claim))
        }
    }

    /// Pinned baseline from
    /// docs/superpowers/specs/2026-07-19-LANGUAGE-SUPPORT-DESIGN.md
    /// "Doctrine-pinned strings" — reviewers verify, native speakers validate
    /// later. Every language must produce the exact hedge template, never a
    /// bare assertion.
    @Test(arguments: [
        (localeIdentifier: "en", certainty: Certainty.low, template: "there might be %@."),
        (localeIdentifier: "en", certainty: .medium, template: "it looks like there's %@."),
        (localeIdentifier: "en", certainty: .high, template: "it looks like there's likely %@."),
        (localeIdentifier: "es", certainty: .low, template: "puede que haya %@."),
        (localeIdentifier: "es", certainty: .medium, template: "parece que hay %@."),
        (localeIdentifier: "es", certainty: .high, template: "parece que probablemente hay %@."),
        (localeIdentifier: "vi", certainty: .low, template: "có thể có %@."),
        (localeIdentifier: "vi", certainty: .medium, template: "hình như có %@."),
        (localeIdentifier: "vi", certainty: .high, template: "rất có thể có %@.")
    ])
    func localizedHedgeMatchesPinnedTemplate(localeIdentifier: String, certainty: Certainty, template: String) {
        let phrase = Phrasing().describe(
            subject: "a chair",
            certainty: certainty,
            locale: Locale(identifier: localeIdentifier)
        )

        #expect(phrase == String(format: template, "a chair"))
        // No language ever gets an unhedged assertion, including "high".
        #expect(phrase != "a chair.")
        #expect(!phrase.hasPrefix("a chair"))
    }

    @Test func hedgeFragmentsCoversAllThreeCertaintyTemplatesInEnglish() {
        let fragments = Phrasing.hedgeFragments(locale: Locale(identifier: "en"))
        #expect(fragments.contains("there might be"))
        #expect(fragments.contains("it looks like there's"))
    }

    @Test func couldNotMeasureIsDistinctFromNothingRecognized() {
        let phrasing = Phrasing()
        let couldNotMeasure = phrasing.couldNotMeasure(locale: Locale(identifier: "en"))
        let nothingRecognized = phrasing.nothingRecognized(locale: Locale(identifier: "en"))
        #expect(couldNotMeasure != nothingRecognized)
        #expect(couldNotMeasure.lowercased().contains("measure"))
    }
}
