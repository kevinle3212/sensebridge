import Foundation

/// Composes a scene description against any OpenAI-compatible
/// `/v1/chat/completions` endpoint. One implementation serves OpenAI cloud,
/// NVIDIA NIM (hosted or self-hosted), and a user's self-hosted server
/// (Ollama, LM Studio, vLLM) — base URL, key, and model are the whole delta.
/// The key is optional: a self-hosted NIM container commonly needs none.
/// Safety comes from `ReasoningOutputValidator`, never from
/// `response_format` — see that type's doc comment.
public struct OpenAICompatibleSceneComposer: SceneComposer {
    /// Why `compose(from:)` failed to produce a validated phrase.
    public enum ComposerError: Error, Sendable, Equatable {
        case httpError(status: Int)
        case malformedResponse
        case responseTooLarge
    }

    /// One turn of the conversation sent to the model.
    private struct RequestMessage: Encodable {
        let role: String
        let content: String
    }

    /// The `/v1/chat/completions` request body.
    private struct Request: Encodable {
        let model: String
        let messages: [RequestMessage]
        let maxTokens: Int
    }

    /// One choice's message content in the response.
    private struct ResponseMessage: Decodable {
        let content: String
    }

    /// One completion choice in the response; only the first is read.
    private struct ResponseChoice: Decodable {
        let message: ResponseMessage
    }

    /// The subset of the `/v1/chat/completions` response this composer reads.
    private struct Response: Decodable {
        let choices: [ResponseChoice]
    }

    /// A misconfigured host returning an HTML error page must fail fast
    /// rather than be parsed as JSON. This is a post-hoc size check on the
    /// fully-downloaded response, not a streaming abort.
    /// # ponytail: not streaming-capped — add true mid-download truncation
    /// only if a misbehaving self-hosted endpoint's bandwidth use becomes a
    /// real problem; the safety-critical path is the validator, not this.
    private static let maximumResponseBytes = 1_048_576

    private let endpoint: URL
    private let apiKey: String?
    private let model: String
    private let session: URLSession
    private let phrasing: Phrasing
    private let locale: Locale
    private let detail: SpokenDetail

    /// Throws at construction, not at request time, if `endpointURL` fails
    /// `EndpointURLNormalizer` — a bad or credential-embedding URL must never
    /// reach a network call.
    ///
    /// - Parameters:
    ///   - endpointURL: A bare host or full path; normalized via `EndpointURLNormalizer`.
    ///   - apiKey: The user's key, or `nil` for a self-hosted endpoint that needs none.
    ///   - model: The model identifier the target endpoint expects.
    ///   - session: Injected so tests can intercept requests via `StubURLProtocol`.
    ///   - phrasing: Wraps the validated phrase in a hedge template.
    ///   - locale: Drives both the requested response language and the hedge template chosen.
    ///   - detail: How many words the validated phrase may run — see `SpokenDetail`.
    ///     Not built into a stored `ReasoningOutputValidator` because the ceiling is
    ///     scaled by the label count, which is only known inside `compose(from:)`.
    public init(
        endpointURL: String,
        apiKey: String?,
        model: String,
        session: URLSession,
        phrasing: Phrasing = .init(),
        locale: Locale = .current,
        detail: SpokenDetail = .standard
    ) throws {
        endpoint = try EndpointURLNormalizer.normalize(endpointURL)
        self.apiKey = apiKey
        self.model = model
        self.session = session
        self.phrasing = phrasing
        self.locale = locale
        self.detail = detail
    }

    /// Sends the perceived object labels to the configured endpoint,
    /// validates the reply through `ReasoningOutputValidator`, and returns a
    /// hedged phrase. Throws — never falls back silently — on any HTTP
    /// error, oversized or malformed response, or a validation failure; the
    /// caller (`ReasoningComposerResolver`) is responsible for falling back
    /// to on-device composition.
    public func compose(from records: [PerceptionRecord]) async throws -> String {
        let labels = records.detectedObjectLabelsForNetwork()
        guard !labels.isEmpty else { return phrasing.nothingRecognized(locale: locale) }
        let maximumWords = detail.maximumPhraseWords(labelCount: labels.count)

        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        if let apiKey {
            request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        }
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let body = Request(
            model: model,
            messages: [
                RequestMessage(role: "system", content: Self.instructions(locale: locale, maximumWords: maximumWords)),
                RequestMessage(role: "user", content: "Labels: \(labels.joined(separator: ", "))")
            ],
            maxTokens: 40
        )
        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        request.httpBody = try encoder.encode(body)

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse, (200 ..< 300).contains(http.statusCode) else {
            throw ComposerError.httpError(status: (response as? HTTPURLResponse)?.statusCode ?? -1)
        }
        guard data.count <= Self.maximumResponseBytes else { throw ComposerError.responseTooLarge }
        guard http.mimeType?.contains("json") == true,
              let decoded = try? JSONDecoder().decode(Response.self, from: data),
              let text = decoded.choices.first?.message.content
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

    /// Same constraint as `AnthropicSceneComposer.instructions` — see its
    /// doc comment. `response_format: json_schema` is deliberately not sent
    /// here: providers and self-hosted servers vary on whether they honor
    /// forced structured output, and with the validator as the real
    /// enforcement point, a provider ignoring this prompt degrades to
    /// "rejected and falls back," not "speaks an unhedged claim."
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
        "\(locale.identifier)". Use at most \(maximumWords) words.
        """
    }
}
