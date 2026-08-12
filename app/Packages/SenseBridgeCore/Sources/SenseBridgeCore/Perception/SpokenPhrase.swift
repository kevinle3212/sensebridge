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
/// **English-only, and knowingly so.** The identifier vocabularies of both
/// frameworks are English, which `ObjectClassificationService` already
/// documents as a limitation: a Spanish or Vietnamese user hears an English
/// noun inside a translated hedge, because naming the object *wrongly* would be
/// worse than naming it in the wrong language. This type inherits that
/// limitation unchanged — it does not add one.
public enum SpokenPhrase {
    /// Written-abbreviation identifiers whose spoken form is a different,
    /// unambiguous word. Deliberately tiny and hand-verified rather than
    /// generated: an entry that guesses wrong makes the app confidently
    /// mis-name a physical object, which docs/SAFETY-FRAMING.md ranks above a
    /// crash. Extend only with an identifier observed in a real classifier
    /// result.
    ///
    /// Not localized: the keys are English identifiers and the values are
    /// English words, per this type's documented English-only scope.
    private static let spokenForms: [String: String] = [
        "tv": "television",
        "tv monitor": "television",
        "cd player": "compact disc player",
        "dvd player": "digital video disc player",
        "atm": "cash machine",
        "suv": "sport utility vehicle",
        "pc": "personal computer",
        "rv": "recreational vehicle"
    ]

    /// Identifiers whose written first letter disagrees with the sound that
    /// starts them. `ObjectClassificationService` documented "a unicycle" as an
    /// accepted wrong answer; the list is short enough to just be right.
    private static let consonantSoundedVowelPrefixes = [
        "uni", "use", "user", "eu", "ewe", "one"
    ]
    private static let vowelSoundedConsonantPrefixes = ["hour", "honest", "honou", "honor"]

    /// The article-first spoken phrase for `identifier`.
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
