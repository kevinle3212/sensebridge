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
}
