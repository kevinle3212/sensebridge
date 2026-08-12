import Foundation
import Testing
@testable import SenseBridgeCore

struct OpenAICompatibleSceneComposerTests {
    private let records: [PerceptionRecord] = [
        PerceptionRecord(kind: .detectedObject(label: "doorway", confidence: 0.7), capturedAt: .now)
    ]

    @Test func successfulResponseIsHedgedAndReturned() async throws {
        let session = StubURLProtocol.makeSession { _ in
            let body = Data(#"{"choices":[{"message":{"content":"a doorway"}}]}"#.utf8)
            return StubResponse(status: 200, data: body, contentType: "application/json")
        }
        let composer = try OpenAICompatibleSceneComposer(
            endpointURL: "https://api.openai.com/v1/chat/completions",
            apiKey: "sk-test", model: "gpt-4o-mini",
            session: session
        )
        let result = try await composer.compose(from: records)
        #expect(result.contains("a doorway"))
    }

    @Test func selfHostedEndpointWithNoKeyWorks() async throws {
        let session = StubURLProtocol.makeSession { request in
            #expect(request.value(forHTTPHeaderField: "Authorization") == nil)
            let body = Data(#"{"choices":[{"message":{"content":"a doorway"}}]}"#.utf8)
            return StubResponse(status: 200, data: body, contentType: "application/json")
        }
        let composer = try OpenAICompatibleSceneComposer(
            endpointURL: "http://192.168.1.20:11434", apiKey: nil, model: "llama3.2",
            session: session
        )
        let result = try await composer.compose(from: records)
        #expect(!result.isEmpty)
    }

    @Test func rejectsEmbeddedCredentialsAtConstruction() {
        let session = StubURLProtocol.makeSession { _ in
            StubResponse(status: 200, data: Data(), contentType: "application/json")
        }
        #expect(throws: EndpointURLError.embeddedCredentials) {
            _ = try OpenAICompatibleSceneComposer(
                endpointURL: "http://user:pass@192.168.1.20:11434", apiKey: nil, model: "llama3.2",
                session: session
            )
        }
    }

    @Test func malformedJSONThrows() async throws {
        let session = StubURLProtocol.makeSession { _ in
            StubResponse(status: 200, data: Data("<html>wrong host</html>".utf8), contentType: "text/html")
        }
        let composer = try OpenAICompatibleSceneComposer(
            endpointURL: "http://192.168.1.20:11434", apiKey: nil, model: "llama3.2",
            session: session
        )
        await #expect(throws: (any Error).self) {
            try await composer.compose(from: records)
        }
    }

    @Test func unhedgedDangerousSentenceIsRejectedNotSpoken() async throws {
        let session = StubURLProtocol.makeSession { _ in
            let body = Data(
                #"{"choices":[{"message":{"content":"There is a car about 2 feet ahead — dangerous"}}]}"#.utf8
            )
            return StubResponse(status: 200, data: body, contentType: "application/json")
        }
        let composer = try OpenAICompatibleSceneComposer(
            endpointURL: "https://integrate.api.nvidia.com/v1/chat/completions",
            apiKey: "nvapi-test", model: "meta/llama-3.1-8b-instruct",
            session: session
        )
        await #expect(throws: (any Error).self) {
            try await composer.compose(from: records)
        }
    }

    @Test func oversizedOrNonJSONResponseIsRejected() async throws {
        let session = StubURLProtocol.makeSession { _ in
            StubResponse(status: 200, data: Data(repeating: 0x41, count: 2_000_000), contentType: "text/html")
        }
        let composer = try OpenAICompatibleSceneComposer(
            endpointURL: "http://192.168.1.20:11434", apiKey: nil, model: "llama3.2",
            session: session
        )
        await #expect(throws: (any Error).self) {
            try await composer.compose(from: records)
        }
    }
}
