import Foundation
import FoundationModels
import SenseBridgeCore

/// Composes a scene description with Apple's on-device language model, and
/// falls back to `LabelListSceneComposer` whenever it cannot.
///
/// Lives in the App layer rather than in `SenseBridgeCore` because it needs
/// `SystemLanguageModel`, which the device-agnostic package deliberately does
/// not depend on — see the `SceneComposer` protocol's own doc comment.
///
/// ## Why the model never writes the sentence
///
/// The obvious design — hand the model the labels and let it return "There's a
/// chair and a doorway ahead of you" — is the one this type refuses. That
/// sentence is an unhedged assertion about the physical world, and whether any
/// given generation carries a hedge would depend on the prompt surviving
/// contact with a model update. docs/SAFETY-FRAMING.md treats a
/// confidently-wrong physical-world claim as the worst bug in this project, so
/// the hedge cannot be something the model is asked to remember.
///
/// Instead the model returns a **subject phrase only** ("a chair and a
/// doorway"), and `Phrasing.describe(subject:certainty:)` applies the hedge —
/// the same enforcement point every other spoken string in the app goes
/// through. The certainty comes from the *detector's* confidence, not the
/// model's fluency, so the strength of the hedge stays tied to evidence
/// perception actually produced. A model regression can make the phrasing
/// clumsy; it cannot make the app sound certain.
struct FoundationModelsSceneComposer: SceneComposer {
    /// The noun phrase the model is constrained to produce at `.concise` and
    /// `.standard` detail.
    ///
    /// Guided generation rather than free text: `@Generable` forces the reply
    /// into this shape at the decoding layer, so "return only a noun phrase"
    /// is a structural constraint and not a polite request in a prompt.
    ///
    /// Not `private`: the `@Generable` macro generates code that refers to this
    /// type from outside its scope, so a private declaration fails to compile
    /// ("'SceneSubject' is inaccessible due to 'private' protection level").
    /// Nesting keeps it out of the way instead.
    @Generable
    struct SceneSubject {
        @Guide(description: """
        A short noun phrase naming the things in the scene, article first, \
        joined with "and" — for example "a chair and a doorway". Name only \
        what the list contains. No adjectives or details that are not in the \
        list. No verbs, no sentence, no punctuation at the end, no mention of \
        distance, direction, danger, or safety. At most twelve words.
        """)
        let phrase: String
    }

    /// The same contract as `SceneSubject`, with the word ceiling `@Guide`'s
    /// macro requires as a literal raised for `.detailed` — the extra budget
    /// exists to join more labels, not to describe any one of them, which is
    /// why every prohibition below is copied verbatim from `SceneSubject`.
    ///
    /// A second `@Generable` type rather than a computed `@Guide` description:
    /// `@Guide(description:)` is parsed by its macro at the call site, so it
    /// requires a string literal and rejects a `static let`/computed
    /// expression there.
    @Generable
    struct DetailedSceneSubject {
        @Guide(description: """
        A short noun phrase naming the things in the scene, article first, \
        joined with "and" — for example "a chair, a table, and a doorway". \
        Name only what the list contains. No adjectives or details that are \
        not in the list. No verbs, no sentence, no punctuation at the end, no \
        mention of distance, direction, danger, or safety. At most \
        twenty-four words.
        """)
        let phrase: String
    }

    /// Instructions kept short and negative-space heavy: the model's job here
    /// is compression, and every capability it is not told about is one it
    /// cannot volunteer into a spoken claim.
    ///
    /// Pins the reply language to `locale` — without this, `es`/`vi` users
    /// could get an English noun phrase wrapped in a translated hedge
    /// template. Caught during the 2026-08-11 reasoning-tier design review
    /// while adding the same instruction to the new network composers.
    ///
    /// - Parameter maximumWords: Steers the model toward the word budget its
    ///   `@Guide` description already enforces structurally — this is a hint
    ///   on top of that enforcement, not a substitute for it.
    private static func instructions(locale: Locale, maximumWords: Int) -> String {
        """
        You compress a list of detected object labels into one short noun phrase \
        for a blind user's screen reader. Name only objects present in the list. \
        Never add objects, never guess what the place is, never describe distance, \
        direction, movement, or safety, and never write a full sentence. Respond \
        only with the noun phrase, in the language identified by locale \
        "\(locale.identifier)". Another part of the app adds the wording around \
        your phrase. Use at most \(maximumWords) words.
        """
    }

    private let fallback: LabelListSceneComposer
    private let phrasing: Phrasing
    private let locale: Locale
    private let detail: SpokenDetail

    /// Creates a composer over `locale`, with the label-list composer as its
    /// fallback for every path where the model cannot be used.
    ///
    /// - Parameter detail: How many objects are named and how long the
    ///   composed phrase may run — see `SpokenDetail`.
    init(phrasing: Phrasing = Phrasing(), locale: Locale = .current, detail: SpokenDetail = .standard) {
        self.phrasing = phrasing
        self.locale = locale
        self.detail = detail
        fallback = LabelListSceneComposer(phrasing: phrasing, locale: locale, detail: detail)
    }

    /// Whether the on-device model is usable right now — device eligibility,
    /// the Apple Intelligence toggle, and model download all have to line up.
    /// Surfaced so the UI can say which composer is in use rather than leaving
    /// the difference invisible.
    static var isModelAvailable: Bool {
        SystemLanguageModel.default.availability == .available
    }

    func compose(from records: [PerceptionRecord]) async throws -> String {
        let objects = records.compactMap { record -> (label: String, confidence: Double)? in
            guard case let .detectedObject(label, confidence) = record.kind else { return nil }
            return (label, confidence)
        }
        guard !objects.isEmpty else {
            return phrasing.nothingRecognized(locale: locale)
        }
        guard Self.isModelAvailable, let phrase = await modelPhrase(for: objects.map(\.label)) else {
            return try await fallback.compose(from: records)
        }
        // The *lowest* detector confidence in the frame, not the average or
        // the highest: the composed phrase names every object, so it is only
        // as trustworthy as its weakest member. Averaging would let two
        // confident labels launder a doubtful third into a stronger hedge.
        let weakest = objects.map(\.confidence).min() ?? 0
        return phrasing.describe(
            subject: phrase,
            certainty: Phrasing.certainty(forConfidence: weakest),
            locale: locale
        )
    }

    /// Runs one generation, returning `nil` for every failure mode so the
    /// caller falls back rather than surfacing an error.
    ///
    /// A fresh session per call, deliberately. A reused `LanguageModelSession`
    /// accumulates a transcript, and hands-free awareness composes for as long
    /// as someone is walking — an hour of retained context would grow latency
    /// and eventually overflow the window, to no benefit, since each
    /// description is independent of the last.
    private func modelPhrase(for labels: [String]) async -> String? {
        let maximumWords = detail.maximumPhraseWords(labelCount: labels.count)
        do {
            let session = LanguageModelSession(
                instructions: Self.instructions(locale: locale, maximumWords: maximumWords)
            )
            let prompt = "Labels: \(labels.joined(separator: ", "))"
            let phrase: String = if detail == .detailed {
                try await session.respond(to: prompt, generating: DetailedSceneSubject.self)
                    .content.phrase.trimmingCharacters(in: .whitespacesAndNewlines)
            } else {
                try await session.respond(to: prompt, generating: SceneSubject.self)
                    .content.phrase.trimmingCharacters(in: .whitespacesAndNewlines)
            }
            // An empty or degenerate reply must not become "it looks like
            // there's ." — fall back to reading the labels out instead.
            guard !phrase.isEmpty else { return nil }
            // The guide asks for a word budget; this enforces it. Fail closed,
            // exactly like every other failure mode in this method: an
            // over-long phrase means the model started describing rather than
            // naming, and the label-list composer says the same thing less
            // fluently but within its evidence.
            guard phrase.split(separator: " ").count <= maximumWords else { return nil }
            return phrase
        } catch {
            // Includes guardrail refusals, context overflow, and the model
            // becoming unavailable mid-session. None of them are worth
            // reporting to someone who is walking: the fallback composer says
            // the same thing less fluently.
            return nil
        }
    }
}
