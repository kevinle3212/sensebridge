import Foundation
import Testing
@testable import SenseBridgeCore

struct SettingsTests {
    @Test
    func roundTripsThroughJSON() throws {
        let settings = Settings(
            outputProfile: .deaf,
            speechRate: 0.7,
            language: .vi,
            reasoningBackend: .cloud
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
        #expect(decoded.reasoningBackend == .onDevice)
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

    @Test
    func freshSettingsHaveNotCompletedOnboarding() {
        #expect(Settings().hasCompletedOnboarding == false)
    }

    @Test
    func decodingSettingsPersistedBeforeOnboardingExistedYieldsCompleted() throws {
        // An existing install upgrading into this field already knows the app —
        // a missing key here means a settings blob existed before onboarding
        // did, which only a pre-existing install can be true of.
        let preOnboardingJSON = """
        {"outputProfile":"blind","speechRate":0.5,"cloudReasoningEnabled":false,"language":"system"}
        """
        let decoded = try JSONDecoder().decode(Settings.self, from: Data(preOnboardingJSON.utf8))

        #expect(decoded.hasCompletedOnboarding == true)
    }

    @Test func decodingLegacyCloudReasoningEnabledTrueFallsBackToOnDeviceUntilProviderChosen() throws {
        let legacyCloudEnabledJSON = """
        {"outputProfile":"blind","speechRate":0.5,"cloudReasoningEnabled":true,"language":"system"}
        """
        let decoded = try JSONDecoder().decode(Settings.self, from: Data(legacyCloudEnabledJSON.utf8))
        #expect(decoded.reasoningBackend == .cloud)
        #expect(decoded.cloudProvider == nil)
    }

    @Test func decodingUnrecognizedReasoningBackendFallsBackToOnDevice() throws {
        let unrecognizedBackendJSON = """
        {"outputProfile":"blind","speechRate":0.5,"reasoningBackend":"somethingFutureBuildsAdded"}
        """
        let decoded = try JSONDecoder().decode(Settings.self, from: Data(unrecognizedBackendJSON.utf8))
        #expect(decoded.reasoningBackend == .onDevice)
    }

    @Test func decodingSettingsPersistedBeforeSpokenDetailExistedYieldsStandard() throws {
        let preSpokenDetailJSON = """
        {"outputProfile":"blind","speechRate":0.5,"reasoningBackend":"onDevice"}
        """
        let decoded = try JSONDecoder().decode(Settings.self, from: Data(preSpokenDetailJSON.utf8))
        #expect(decoded.spokenDetail == .standard)
    }

    @Test func decodingUnrecognizedSpokenDetailFallsBackToStandardWithoutResettingOtherFields() throws {
        let unrecognizedDetailJSON = """
        {"outputProfile":"deaf","speechRate":0.7,"reasoningBackend":"onDevice","spokenDetail":"gigantic"}
        """
        let decoded = try JSONDecoder().decode(Settings.self, from: Data(unrecognizedDetailJSON.utf8))
        #expect(decoded.spokenDetail == .standard)
        #expect(decoded.outputProfile == .deaf)
        #expect(decoded.speechRate == 0.7)
    }

    @Test func roundTripsDetailedSpokenDetailThroughJSON() throws {
        let settings = Settings(spokenDetail: .detailed)
        let data = try JSONEncoder().encode(settings)
        let decoded = try JSONDecoder().decode(Settings.self, from: data)
        #expect(decoded.spokenDetail == .detailed)
    }
}
