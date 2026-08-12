import Foundation
import NaturalLanguage

/// Why a network reasoning composer's raw response was rejected.
public enum ReasoningOutputValidationError: Error, Sendable, Equatable {
    case empty
    case tooLong(wordCount: Int)
    case containsSentencePunctuationOrNewline
    case containsDisallowedTerm
    case containsNumeral
    case containsHedgeFragment
    case wrongLanguage
}

/// The actual safety enforcement point for every network reasoning composer.
///
/// `FoundationModelsSceneComposer` is safe because `@Generable` constrains
/// its model's reply *structurally, at the decoding layer* — Apple's
/// runtime, not a request the app sent. Over HTTP there is no decoding layer
/// the app controls: `response_format`/tool-use are requests to a server the
/// app doesn't run, and for a self-hosted endpoint that server is arbitrary.
/// This type is what stands between an HTTP response and `Phrasing`, and it
/// is deterministic and local — never trust a remote's own claim to have
/// followed instructions. See
/// docs/superpowers/specs/2026-08-11-awareness-ai-tiers-design.md
/// "The output validator".
public struct ReasoningOutputValidator: Sendable {
    private static let maximumWords = 12

    /// Distance/direction/safety/danger tokens a bare noun phrase
    /// ("a chair and a doorway") should never legitimately contain — if the
    /// model volunteered one, it stopped compressing labels and started
    /// making a claim about the physical world, which only `Phrasing` is
    /// allowed to do. Lowercased comparison; keys are `AppLanguage` raw
    /// values so this stays in step with the app's supported languages.
    private static let disallowedTerms: [String: [String]] = [
        "en": [
            "danger", "dangerous", "safe", "safety", "meter", "meters", "metre", "metres",
            "feet", "foot", "inch", "inches", "left", "right", "ahead", "behind",
            "close", "near", "far", "step", "careful", "watch out", "collision", "hazard"
        ],
        "es": [
            "peligro", "peligroso", "peligrosa", "seguro", "segura", "seguridad",
            "metro", "metros", "pie", "pies", "izquierda", "derecha", "adelante",
            "detrás", "cerca", "lejos", "cuidado", "colisión"
        ],
        "vi": [
            "nguy hiểm", "an toàn", "mét", "trái", "phải", "phía trước", "phía sau",
            "gần", "xa", "cẩn thận", "va chạm"
        ]
    ]

    // Empty but required: a public init is needed for cross-module init; nothing to initialize.
    // swiftlint:disable:next no_empty_block
    public init() {}

    /// Validates and trims `phrase`, throwing on the first rule it fails.
    /// The caller (a network `SceneComposer`) must treat any throw exactly
    /// like `FoundationModelsSceneComposer.modelPhrase(for:)` returning
    /// `nil`: fall back, never surface the raw text.
    public func validate(_ phrase: String, locale: Locale) throws -> String {
        let trimmed = phrase.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw ReasoningOutputValidationError.empty }
        guard trimmed.rangeOfCharacter(from: .newlines) == nil,
              !trimmed.contains(where: { ".!?".contains($0) })
        else {
            throw ReasoningOutputValidationError.containsSentencePunctuationOrNewline
        }
        let wordCount = trimmed.split(separator: " ").count
        guard wordCount <= Self.maximumWords else {
            throw ReasoningOutputValidationError.tooLong(wordCount: wordCount)
        }
        guard trimmed.rangeOfCharacter(from: .decimalDigits) == nil else {
            throw ReasoningOutputValidationError.containsNumeral
        }
        let lowered = trimmed.lowercased()
        let languageCode = locale.language.languageCode?.identifier ?? "en"
        let terms = Self.disallowedTerms[languageCode] ?? Self.disallowedTerms["en"] ?? []
        for term in terms where lowered.contains(term) {
            throw ReasoningOutputValidationError.containsDisallowedTerm
        }
        for fragment in Phrasing.hedgeFragments(locale: locale) where !fragment.isEmpty {
            if lowered.contains(fragment.lowercased()) {
                throw ReasoningOutputValidationError.containsHedgeFragment
            }
        }
        try Self.checkLanguage(trimmed, locale: locale)
        return trimmed
    }

    /// Best-effort: rejects only when the recognizer is confident *and* the
    /// phrase is long enough to detect reliably. Short noun phrases
    /// ("a chair") are frequently ambiguous across languages and must not
    /// false-positive-reject a correct response.
    private static func checkLanguage(_ phrase: String, locale: Locale) throws {
        guard phrase.split(separator: " ").count >= 3 else { return }
        guard let expected = locale.language.languageCode?.identifier else { return }
        let recognizer = NLLanguageRecognizer()
        recognizer.processString(phrase)
        guard let dominant = recognizer.dominantLanguage else { return }
        let confidence = recognizer.languageHypotheses(withMaximum: 1)[dominant] ?? 0
        if confidence > 0.7, dominant.rawValue != expected {
            throw ReasoningOutputValidationError.wrongLanguage
        }
    }
}
