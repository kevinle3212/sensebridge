import Foundation
import Testing
@testable import SenseBridgeCore

struct SceneComposerTests {
    /// Pinned baseline from
    /// docs/superpowers/specs/2026-07-19-LANGUAGE-SUPPORT-DESIGN.md
    /// "Doctrine-pinned strings".
    @Test(arguments: [
        (localeIdentifier: "en", expected: "Nothing recognizable was found."),
        (localeIdentifier: "es", expected: "No se reconoció nada."),
        (localeIdentifier: "vi", expected: "Không nhận ra được gì.")
    ])
    func fallbackStringIsLocalizedWhenNoDetections(localeIdentifier: String, expected: String) async throws {
        let composer = LabelListSceneComposer(locale: Locale(identifier: localeIdentifier))
        let description = try await composer.compose(from: [])
        #expect(description == expected)
    }

    @Test
    func detectedObjectsAreDescribedInTheComposerLocale() async throws {
        let composer = LabelListSceneComposer(locale: Locale(identifier: "es"))
        let record = PerceptionRecord(kind: .detectedObject(label: "a chair", confidence: 0.9), capturedAt: .now)

        let description = try await composer.compose(from: [record])

        #expect(description == "parece que probablemente hay a chair.")
    }
}
