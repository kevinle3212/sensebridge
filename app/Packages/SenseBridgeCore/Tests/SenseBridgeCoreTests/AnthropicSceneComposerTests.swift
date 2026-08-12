import Foundation
import Testing
@testable import SenseBridgeCore

/// A stubbed HTTP response `StubURLProtocol.handler` hands back for an
/// intercepted request.
struct StubResponse {
    let status: Int
    let data: Data
    let contentType: String
}

/// Intercepts every request instead of hitting the network — registered
/// per-test via a dedicated `URLSessionConfiguration`, never
/// `URLProtocol.registerClass` globally, so tests stay isolated from each
/// other.
final class StubURLProtocol: URLProtocol, @unchecked Sendable {
    nonisolated(unsafe) static var handler: (@Sendable (URLRequest) -> StubResponse)?

    override static func canInit(with _: URLRequest) -> Bool {
        true
    }

    override static func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        guard let handler = Self.handler, let url = request.url else {
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

    static func makeSession() -> URLSession {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [StubURLProtocol.self]
        return URLSession(configuration: configuration)
    }
}

/// Serialized: every test in this suite drives `StubURLProtocol` through its
/// shared `static var handler`, so tests must not run concurrently with each
/// other or one test's handler can intercept another's request (confirmed —
/// this suite flakes under Swift Testing's default parallel execution
/// without `.serialized`).
@Suite(.serialized)
struct AnthropicSceneComposerTests {
    private let records: [PerceptionRecord] = [
        PerceptionRecord(kind: .detectedObject(label: "chair", confidence: 0.6), capturedAt: .now)
    ]

    @Test func successfulResponseIsHedgedAndReturned() async throws {
        StubURLProtocol.handler = { _ in
            let body = Data(#"{"content":[{"type":"text","text":"a chair"}]}"#.utf8)
            return StubResponse(status: 200, data: body, contentType: "application/json")
        }
        let composer = AnthropicSceneComposer(
            apiKey: "sk-ant-test", session: StubURLProtocol.makeSession()
        )
        let result = try await composer.compose(from: records)
        #expect(result.contains("a chair"))
        #expect(result != "a chair") // must be hedged, not the bare phrase
    }

    @Test func malformedJSONThrows() async {
        StubURLProtocol.handler = { _ in
            StubResponse(status: 200, data: Data("not json".utf8), contentType: "application/json")
        }
        let composer = AnthropicSceneComposer(apiKey: "sk-ant-test", session: StubURLProtocol.makeSession())
        await #expect(throws: (any Error).self) {
            try await composer.compose(from: records)
        }
    }

    @Test func httpErrorThrows() async {
        StubURLProtocol.handler = { _ in
            StubResponse(status: 401, data: Data(), contentType: "application/json")
        }
        let composer = AnthropicSceneComposer(apiKey: "sk-ant-test", session: StubURLProtocol.makeSession())
        await #expect(throws: (any Error).self) {
            try await composer.compose(from: records)
        }
    }

    /// The regression test that matters most for this type: even if the
    /// remote ignores every instruction and returns a full unhedged
    /// sentence, `compose` must throw — the validator, not the prompt, is
    /// what stands between this response and `Phrasing`.
    @Test func unhedgedDangerousSentenceIsRejectedNotSpoken() async {
        StubURLProtocol.handler = { _ in
            let body = Data(
                #"{"content":[{"type":"text","text":"There is a car about 2 feet ahead — dangerous"}]}"#.utf8
            )
            return StubResponse(status: 200, data: body, contentType: "application/json")
        }
        let composer = AnthropicSceneComposer(apiKey: "sk-ant-test", session: StubURLProtocol.makeSession())
        await #expect(throws: (any Error).self) {
            try await composer.compose(from: records)
        }
    }

    @Test func emptyRecordsReturnsNothingRecognizedWithoutMakingARequest() async throws {
        StubURLProtocol.handler = { _ in
            Issue.record("should not make a request for empty records")
            return StubResponse(status: 200, data: Data(), contentType: "application/json")
        }
        let composer = AnthropicSceneComposer(apiKey: "sk-ant-test", session: StubURLProtocol.makeSession())
        let result = try await composer.compose(from: [])
        #expect(!result.isEmpty)
    }
}
