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

    @Test
    func decodingSettingsPersistedByTheCurrentShippingBuildYieldsDocumentedDefaults() throws {
        // The current shipping shape: outputProfile, speechRate,
        // cloudReasoningEnabled, language — none of the fields added by this
        // change exist yet.
        let currentShippingJSON = """
        {"outputProfile":"blind","speechRate":0.5,"cloudReasoningEnabled":false,"language":"system"}
        """
        let decoded = try JSONDecoder().decode(Settings.self, from: Data(currentShippingJSON.utf8))

        #expect(decoded.speechPitch == 0.5)
        #expect(decoded.speechVolume == 1.0)
        #expect(decoded.hapticsEnabled == true)
        #expect(decoded.hapticIntensity == 1.0)
        #expect(decoded.preferredLens == .wide)
        #expect(decoded.torchDefaultOn == false)
    }
}
