import Foundation
import Testing
@testable import SenseBridgeCore

/// A stubbed HTTP response a `StubURLProtocol` handler hands back for an
/// intercepted request.
struct StubResponse {
    let status: Int
    let data: Data
    let contentType: String
}

/// Intercepts every request instead of hitting the network. Handlers are
/// keyed by a random per-session token embedded in a session-default header
/// (`tokenHeader`, applied to every request `makeSession(handler:)`'s
/// session sends) rather than stored in one shared static — Swift Testing
/// runs suites in parallel by default, and two different `SceneComposer`
/// test suites intercepting through the same `URLProtocol` subclass would
/// otherwise race on a single shared handler (confirmed: this shared-static
/// design flaked even within one suite before this token scheme, and would
/// flake across suites too — `OpenAICompatibleSceneComposerTests` is the
/// second consumer that exposed it).
final class StubURLProtocol: URLProtocol, @unchecked Sendable {
    private static let tokenHeader = "X-SenseBridge-Test-Stub-Token"
    private static let lock: NSLock = .init()
    private nonisolated(unsafe) static var handlers: [String: @Sendable (URLRequest) -> StubResponse] = [:]

    override static func canInit(with request: URLRequest) -> Bool {
        request.value(forHTTPHeaderField: tokenHeader) != nil
    }

    override static func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        guard let token = request.value(forHTTPHeaderField: Self.tokenHeader),
              let handler = Self.lock.withLock({ Self.handlers[token] }),
              let url = request.url
        else {
            client?.urlProtocol(self, didFailWithError: URLError(.badServerResponse))
            return
        }
        let stubbed = handler(request)
        guard let response = HTTPURLResponse(
            url: url, statusCode: stubbed.status,
            httpVersion: "HTTP/1.1", headerFields: ["Content-Type": stubbed.contentType]
        ) else {
            client?.urlProtocol(self, didFailWithError: URLError(.badServerResponse))
            return
        }
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: stubbed.data)
        client?.urlProtocolDidFinishLoading(self)
    }

    // Nothing to cancel: the stubbed response completes synchronously in startLoading().
    // swiftlint:disable:next no_empty_block
    override func stopLoading() {}

    /// Returns a session whose every request carries a fresh random token
    /// mapped only to `handler` — concurrent callers, even in other test
    /// suites, never see each other's stub.
    static func makeSession(handler: @escaping @Sendable (URLRequest) -> StubResponse) -> URLSession {
        let token = UUID().uuidString
        lock.withLock { handlers[token] = handler }
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [StubURLProtocol.self]
        configuration.httpAdditionalHeaders = [tokenHeader: token]
        return URLSession(configuration: configuration)
    }
}

struct AnthropicSceneComposerTests {
    private let records: [PerceptionRecord] = [
        PerceptionRecord(kind: .detectedObject(label: "chair", confidence: 0.6), capturedAt: .now)
    ]

    @Test func successfulResponseIsHedgedAndReturned() async throws {
        let session = StubURLProtocol.makeSession { _ in
            let body = Data(#"{"content":[{"type":"text","text":"a chair"}]}"#.utf8)
            return StubResponse(status: 200, data: body, contentType: "application/json")
        }
        let composer = AnthropicSceneComposer(apiKey: "sk-ant-test", session: session)
        let result = try await composer.compose(from: records)
        #expect(result.contains("a chair"))
        #expect(result != "a chair") // must be hedged, not the bare phrase
    }

    @Test func malformedJSONThrows() async {
        let session = StubURLProtocol.makeSession { _ in
            StubResponse(status: 200, data: Data("not json".utf8), contentType: "application/json")
        }
        let composer = AnthropicSceneComposer(apiKey: "sk-ant-test", session: session)
        await #expect(throws: (any Error).self) {
            try await composer.compose(from: records)
        }
    }

    @Test func httpErrorThrows() async {
        let session = StubURLProtocol.makeSession { _ in
            StubResponse(status: 401, data: Data(), contentType: "application/json")
        }
        let composer = AnthropicSceneComposer(apiKey: "sk-ant-test", session: session)
        await #expect(throws: (any Error).self) {
            try await composer.compose(from: records)
        }
    }

    /// The regression test that matters most for this type: even if the
    /// remote ignores every instruction and returns a full unhedged
    /// sentence, `compose` must throw — the validator, not the prompt, is
    /// what stands between this response and `Phrasing`.
    @Test func unhedgedDangerousSentenceIsRejectedNotSpoken() async {
        let session = StubURLProtocol.makeSession { _ in
            let body = Data(
                #"{"content":[{"type":"text","text":"There is a car about 2 feet ahead — dangerous"}]}"#.utf8
            )
            return StubResponse(status: 200, data: body, contentType: "application/json")
        }
        let composer = AnthropicSceneComposer(apiKey: "sk-ant-test", session: session)
        await #expect(throws: (any Error).self) {
            try await composer.compose(from: records)
        }
    }

    @Test func emptyRecordsReturnsNothingRecognizedWithoutMakingARequest() async throws {
        let session = StubURLProtocol.makeSession { _ in
            Issue.record("should not make a request for empty records")
            return StubResponse(status: 200, data: Data(), contentType: "application/json")
        }
        let composer = AnthropicSceneComposer(apiKey: "sk-ant-test", session: session)
        let result = try await composer.compose(from: [])
        #expect(!result.isEmpty)
    }
}
