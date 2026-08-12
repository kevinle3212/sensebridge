import Foundation
import Testing
@testable import SenseBridgeCore

struct EndpointURLNormalizerTests {
    @Test func bareHostGetsTheChatCompletionsPathAppended() throws {
        let url = try EndpointURLNormalizer.normalize("http://192.168.1.20:11434")
        #expect(url.absoluteString == "http://192.168.1.20:11434/v1/chat/completions")
    }

    @Test func fullPathIsLeftAlone() throws {
        let url = try EndpointURLNormalizer.normalize("http://192.168.1.20:11434/v1/chat/completions")
        #expect(url.absoluteString == "http://192.168.1.20:11434/v1/chat/completions")
    }

    @Test func httpsSchemeIsAccepted() throws {
        let url = try EndpointURLNormalizer.normalize("https://my-server.example.com")
        #expect(url.scheme == "https")
    }

    @Test func nonHttpSchemeIsRejected() {
        #expect(throws: EndpointURLError.invalidScheme) {
            try EndpointURLNormalizer.normalize("ftp://192.168.1.20")
        }
    }

    @Test func embeddedCredentialsAreRejected() {
        #expect(throws: EndpointURLError.embeddedCredentials) {
            try EndpointURLNormalizer.normalize("http://user:pass@192.168.1.20:11434")
        }
    }

    @Test func malformedStringIsRejected() {
        #expect(throws: EndpointURLError.invalidURL) {
            try EndpointURLNormalizer.normalize("not a url at all")
        }
    }

    @Test func trailingSlashHostGetsPathAppendedCleanly() throws {
        let url = try EndpointURLNormalizer.normalize("http://localhost:11434/")
        #expect(url.absoluteString == "http://localhost:11434/v1/chat/completions")
    }
}
