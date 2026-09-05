import Foundation

/// Composes a scene description via Anthropic's Messages API (BYOK). Safety
/// comes from `ReasoningOutputValidator`, not from the request — see that
/// type's doc comment and
/// docs/superpowers/specs/2026-08-11-awareness-ai-tiers-design.md "The output
/// validator".
public struct AnthropicSceneComposer: SceneComposer {
    /// Why `compose(from:)` failed to produce a validated phrase.
    public enum ComposerError: Error, Sendable, Equatable {
        case httpError(status: Int)
        case malformedResponse
    }

    /// One turn of the conversation sent to the model.
    private struct RequestMessage: Encodable {
        let role: String
        let content: String
    }

    /// The Anthropic Messages API request body.
    private struct Request: Encodable {
        let model: String
        let maxTokens: Int
        let system: String
        let messages: [RequestMessage]
    }

    /// One block of the model's reply; only `type == "text"` blocks carry a phrase.
    private struct ResponseContentBlock: Decodable {
        let type: String
        let text: String?
    }

    /// The subset of the Messages API response this composer reads.
    private struct Response: Decodable {
        let content: [ResponseContentBlock]
    }

    // A hardcoded, compile-time-verified literal can never fail to parse.
    // swiftlint:disable:next force_unwrapping
    private static let endpoint: URL = .init(string: "https://api.anthropic.com/v1/messages")!
    private static let apiVersion = "2023-06-01"
    private static let defaultModel = "claude-haiku-4-5-20251001"

    private let apiKey: String
    private let model: String
    private let session: URLSession
    private let phrasing: Phrasing
    private let locale: Locale
    private let detail: SpokenDetail

    /// - Parameters:
    ///   - apiKey: The user's own Anthropic API key (BYOK) — never persisted by this type.
    ///   - model: Overrides `defaultModel`; `nil` uses the pinned default.
    ///   - session: Injected so tests can intercept requests via `StubURLProtocol`.
    ///   - phrasing: Wraps the validated phrase in a hedge template.
    ///   - locale: Drives both the requested response language and the hedge template chosen.
    ///   - detail: How many words the validated phrase may run — see `SpokenDetail`.
    ///     Not built into a stored `ReasoningOutputValidator` because the ceiling is
    ///     scaled by the label count, which is only known inside `compose(from:)`.
    public init(
        apiKey: String,
        model: String? = nil,
        session: URLSession,
        phrasing: Phrasing = .init(),
        locale: Locale = .current,
        detail: SpokenDetail = .standard
    ) {
        self.apiKey = apiKey
        self.model = model ?? Self.defaultModel
        self.session = session
        self.phrasing = phrasing
        self.locale = locale
        self.detail = detail
    }

    /// Sends the perceived object labels to Anthropic, validates the reply
    /// through `ReasoningOutputValidator`, and returns a hedged phrase.
    /// Throws — never falls back silently — on any HTTP error, malformed
    /// response, or a validation failure; the caller (`ReasoningComposerResolver`)
    /// is responsible for falling back to on-device composition.
    public func compose(from records: [PerceptionRecord]) async throws -> String {
        let labels = records.detectedObjectLabelsForNetwork()
        guard !labels.isEmpty else { return phrasing.nothingRecognized(locale: locale) }
        let maximumWords = detail.maximumPhraseWords(labelCount: labels.count)

        var request = URLRequest(url: Self.endpoint)
        request.httpMethod = "POST"
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue(Self.apiVersion, forHTTPHeaderField: "anthropic-version")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let body = Request(
            model: model,
            maxTokens: 40,
            system: Self.instructions(locale: locale, maximumWords: maximumWords),
            messages: [RequestMessage(role: "user", content: "Labels: \(labels.joined(separator: ", "))")]
        )
        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        request.httpBody = try encoder.encode(body)

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse, (200 ..< 300).contains(http.statusCode) else {
            throw ComposerError.httpError(status: (response as? HTTPURLResponse)?.statusCode ?? -1)
        }
        guard let decoded = try? JSONDecoder().decode(Response.self, from: data),
              let text = decoded.content.first(where: { $0.type == "text" })?.text
        else {
            throw ComposerError.malformedResponse
        }
        // Built here, not stored: the ceiling is scaled by `labels.count`,
        // which is only known once a request is actually being composed.
        let validator = ReasoningOutputValidator(maximumWords: maximumWords)
        let validated = try validator.validate(text, locale: locale)
        let weakest = records.weakestDetectedObjectConfidence() ?? 0
        return phrasing.describe(
            subject: validated, certainty: Phrasing.certainty(forConfidence: weakest), locale: locale
        )
    }

    /// Near-identical to `FoundationModelsSceneComposer.instructions` on
    /// purpose — same constraint, same reason: compression only, never a
    /// claim about distance, direction, danger, or safety. Also pins the
    /// response language, closing the same latent gap
    /// `FoundationModelsSceneComposer` had (see Task 13).
    ///
    /// - Parameter maximumWords: Steers the model toward the ceiling
    ///   `ReasoningOutputValidator` actually enforces — a hint, not a
    ///   substitute for that enforcement.
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
}
