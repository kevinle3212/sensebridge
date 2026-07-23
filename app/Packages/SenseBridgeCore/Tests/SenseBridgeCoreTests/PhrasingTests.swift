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
}
