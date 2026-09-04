import Foundation
import Testing
@testable import SenseBridgeCore

struct SpokenPhraseTests {
    @Test
    func joinsUnderscoresAndPicksTheCorrectArticle() {
        #expect(SpokenPhrase.subject(for: "coffee_mug") == "a coffee mug")
        #expect(SpokenPhrase.subject(for: "escalator") == "an escalator")
    }

    @Test
    func expandsKnownAbbreviationsToTheirSpokenWords() {
        #expect(SpokenPhrase.subject(for: "tv") == "a television")
        #expect(SpokenPhrase.subject(for: "cd_player") == "a compact disc player")
        // Added from the real `ClassifyImageRequest` identifier set, 2026-08-25.
        #expect(SpokenPhrase.subject(for: "cd") == "a compact disc")
        #expect(SpokenPhrase.subject(for: "atv") == "an all-terrain vehicle")
    }

    /// Catch-all taxonomy labels get a speakable form: the raw identifier is
    /// both ungrammatical aloud ("a consumer electronics") and names a
    /// category rather than a thing. `ObjectClassificationService` prefers any
    /// specific sibling over these; this pin covers frames where none passed
    /// the precision floor and the catch-all still has to be speakable.
    @Test
    func mapsCatchAllTaxonomyLabelsToASpeakableForm() {
        #expect(SpokenPhrase.subject(for: "consumer_electronics") == "an electronic device")
    }

    @Test
    func handlesWrittenVowelsThatSoundLikeConsonants() {
        #expect(SpokenPhrase.subject(for: "unicycle") == "a unicycle")
    }

    @Test
    func handlesWrittenConsonantsThatSoundLikeVowels() {
        #expect(SpokenPhrase.subject(for: "hourglass") == "an hourglass")
    }

    @Test
    func handlesAnEmptyIdentifierWithoutCrashing() {
        #expect(SpokenPhrase.subject(for: "").isEmpty)
    }

    @Test
    func passesUnicodeThroughUnchanged() {
        #expect(SpokenPhrase.subject(for: "café_table") == "a café table")
    }

    @Test
    func speaksAReviewedIdentifierInTheRequestedLanguage() {
        #expect(SpokenPhrase.subject(for: "chair", locale: Locale(identifier: "es")) == "una silla")
        #expect(SpokenPhrase.subject(for: "chair", locale: Locale(identifier: "vi")) == "một cái ghế")
        #expect(SpokenPhrase.subject(for: "dog_bark", locale: Locale(identifier: "es")) == "un ladrido de perro")
    }

    @Test
    func fallsBackToTheEnglishPhraseRatherThanTheRawIdentifier() {
        // The whole safety argument for shipping a partial table: an
        // unreviewed identifier degrades the *language*, never the accuracy,
        // and never leaks an underscore-joined identifier into speech.
        #expect(SpokenVocabulary.phrases["hourglass"] == nil, "test needs an identifier outside the table")
        let spoken = SpokenPhrase.subject(for: "hourglass", locale: Locale(identifier: "vi"))
        #expect(spoken == "an hourglass")
        #expect(!spoken.contains("_"))
    }

    @Test
    func englishRequestsGetTheEnglishPhraseEvenForTranslatedIdentifiers() {
        #expect(SpokenPhrase.subject(for: "chair", locale: Locale(identifier: "en")) == "a chair")
        #expect(SpokenPhrase.subject(for: "chair", locale: Locale(identifier: "en_US")) == "a chair")
    }

    @Test
    func prefersARegionalEntryOverTheBareLanguage() {
        // No `es_MX` entry exists yet, so the bare language must still answer —
        // the ordering only matters when a regional entry is added later.
        #expect(SpokenPhrase.subject(for: "chair", locale: Locale(identifier: "es_MX")) == "una silla")
    }

    @Test
    func everyVocabularyEntryCoversEveryShippedLanguage() {
        // A half-translated entry would speak Spanish to a Vietnamese user
        // rather than falling back to English, which is the one outcome the
        // fallback design is meant to make impossible.
        for (identifier, translations) in SpokenVocabulary.phrases {
            for code in ["es", "vi"] {
                let phrase = translations[code]
                #expect(phrase != nil, "\(identifier) is missing \(code)")
                #expect(phrase?.isEmpty == false, "\(identifier) has an empty \(code)")
            }
        }
    }

    @Test
    func everyShippedSoundClassHasAReviewedTranslation() {
        // Sound Analysis' shipped set is small and safety-adjacent, so unlike
        // Vision's vocabulary it is expected to be complete, not partial.
        for identifier in BuiltInSoundClassifier.targetClassNames {
            let normalized = identifier.replacing("_", with: " ")
            #expect(SpokenVocabulary.phrases[normalized] != nil, "no translation for sound class \(identifier)")
        }
    }
}
