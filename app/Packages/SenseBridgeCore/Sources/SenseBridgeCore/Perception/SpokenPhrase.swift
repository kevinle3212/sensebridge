import Foundation

/// Turns a bare Vision or Sound Analysis identifier ("coffee_mug", "tv") into
/// the article-first noun phrase `Phrasing.describe(subject:certainty:)`
/// expects ("a coffee mug", "a television").
///
/// One implementation for both classifiers on purpose:
/// `ObjectClassificationService` and `SoundClassificationRunner` each carried a
/// byte-identical copy before this type existed, so a pronunciation fix landed
/// in one and not the other would make a sound event read differently from an
/// object seen in the same room.
///
/// **Localized for the identifiers in `SpokenVocabulary`, English elsewhere.**
/// The identifier vocabularies of both frameworks are English. Rather than
/// machine-translate ~1,600 of them — where the long tail would produce a
/// confidently wrong noun, which `docs/SAFETY-FRAMING.md` ranks above a crash —
/// a curated table covers the identifiers a real walk produces, and everything
/// outside it keeps the previous behaviour: the English noun inside a
/// translated hedge. The fallback is the safe direction, so an absent entry
/// degrades the language and never the accuracy.
public enum SpokenPhrase {
    /// Written-abbreviation identifiers whose spoken form is a different,
    /// unambiguous word. Deliberately tiny and hand-verified rather than
    /// generated: an entry that guesses wrong makes the app confidently
    /// mis-name a physical object, which docs/SAFETY-FRAMING.md ranks above a
    /// crash. Extend only with an identifier observed in a real classifier
    /// result.
    ///
    /// Provenance of the 2026-08-25 additions (`cd`, `atv`): both appear in a
    /// dump of `ClassifyImageRequest().supportedIdentifiers` from the
    /// development host. The older entries predate that taxonomy revision and
    /// deliberately stay — the device-side vocabulary can differ from any one
    /// host's dump, and an unused mapping is harmless where a wrong one is not.
    ///
    /// Not localized: the keys are English identifiers and the values are
    /// English words, per this type's documented English-only scope.
    private static let spokenForms: [String: String] = [
        "tv": "television",
        "tv monitor": "television",
        "cd player": "compact disc player",
        "dvd player": "digital video disc player",
        "atm": "cash machine",
        "atv": "all-terrain vehicle",
        "suv": "sport utility vehicle",
        "pc": "personal computer",
        "rv": "recreational vehicle",
        "cd": "compact disc",
        // A catch-all taxonomy label, not an abbreviation — mapped because the
        // raw form is both ungrammatical aloud ("a consumer electronics") and
        // information-free. `ObjectClassificationService` additionally prefers
        // any specific sibling label over this one; this entry covers the
        // frames where no sibling passed the precision floor.
        "consumer electronics": "electronic device"
    ]

    /// Identifiers whose written first letter disagrees with the sound that
    /// starts them. `ObjectClassificationService` documented "a unicycle" as an
    /// accepted wrong answer; the list is short enough to just be right.
    private static let consonantSoundedVowelPrefixes = [
        "uni", "use", "user", "eu", "ewe", "one"
    ]
    private static let vowelSoundedConsonantPrefixes = ["hour", "honest", "honou", "honor"]

    /// The article-first spoken phrase for `identifier` in `locale`.
    ///
    /// Falls back to the English phrase — not to the raw identifier — when
    /// `SpokenVocabulary` has no reviewed entry for this identifier in this
    /// language. That fallback is the whole safety argument for shipping a
    /// partial table: the worst outcome is a correctly-named object in the
    /// wrong language, never a wrongly-named one.
    public static func subject(for identifier: String, locale: Locale) -> String {
        let normalized = identifier.replacing("_", with: " ").lowercased()
        if let translations = SpokenVocabulary.phrases[normalized] {
            for code in languageCandidates(for: locale) {
                if let phrase = translations[code] {
                    return phrase
                }
            }
        }
        return subject(for: identifier)
    }

    /// Language keys to try for `locale`, most specific first, so a future
    /// regional entry (`es_MX`) wins over the bare language (`es`). Mirrors
    /// `LocalizedCatalog`'s resolution order deliberately: two different
    /// answers for the same locale in one spoken sentence would be worse than
    /// either answer alone.
    private static func languageCandidates(for locale: Locale) -> [String] {
        let identifier = locale.identifier
        guard let code = locale.language.languageCode?.identifier, code != identifier else {
            return [identifier]
        }
        return [identifier, code]
    }

    /// The article-first spoken phrase for `identifier` in English.
    public static func subject(for identifier: String) -> String {
        let words = spokenForms[identifier.replacing("_", with: " ").lowercased()]
            ?? identifier.replacing("_", with: " ")
        guard let first = words.first else { return words }
        let lowered = words.lowercased()
        if vowelSoundedConsonantPrefixes.contains(where: lowered.hasPrefix) {
            return "an \(words)"
        }
        if consonantSoundedVowelPrefixes.contains(where: lowered.hasPrefix) {
            return "a \(words)"
        }
        return "aeiou".contains(first.lowercased()) ? "an \(words)" : "a \(words)"
    }
}
