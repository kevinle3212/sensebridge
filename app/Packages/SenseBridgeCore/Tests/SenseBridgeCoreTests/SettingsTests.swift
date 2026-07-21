import Foundation
import Testing
@testable import SenseBridgeCore

struct SettingsTests {
    @Test
    func roundTripsThroughJSON() throws {
        let settings = Settings(
            outputProfile: .deaf,
            speechRate: 0.7,
            cloudReasoningEnabled: true,
            language: .vi
        )

        let data = try JSONEncoder().encode(settings)
        let decoded = try JSONDecoder().decode(Settings.self, from: data)

        #expect(decoded == settings)
    }

    @Test
    func decodingSettingsPersistedBeforeLanguageExistedYieldsSystem() throws {
        // Shape of `Settings` before `language` was added — no "language" key.
        let legacyJSON = """
        {"outputProfile":"blind","speechRate":0.5,"cloudReasoningEnabled":false}
        """
        let decoded = try JSONDecoder().decode(Settings.self, from: Data(legacyJSON.utf8))

        #expect(decoded.language == .system)
        #expect(decoded.outputProfile == .blind)
        #expect(decoded.speechRate == 0.5)
        #expect(decoded.cloudReasoningEnabled == false)
    }
}
