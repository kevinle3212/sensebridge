import Foundation
import Testing
@testable import SenseBridgeCore

struct SceneComposerTests {
    /// Pinned baseline from
    /// docs/superpowers/specs/2026-07-19-LANGUAGE-SUPPORT-DESIGN.md
    /// "Doctrine-pinned strings".
    @Test(arguments: [
        (localeIdentifier: "en", expected: "Couldn't name anything."),
        (localeIdentifier: "es", expected: "No se pudo identificar nada."),
        (localeIdentifier: "vi", expected: "Không nhận ra được vật nào.")
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

    @Test
    func groupsObjectsByCertaintyMostConfidentFirst() async throws {
        let composer = LabelListSceneComposer(locale: Locale(identifier: "en"))
        let records = [
            PerceptionRecord(kind: .detectedObject(label: "a chair", confidence: 0.9), capturedAt: .now),
            PerceptionRecord(kind: .detectedObject(label: "a table", confidence: 0.85), capturedAt: .now),
            PerceptionRecord(kind: .detectedObject(label: "a lamp", confidence: 0.3), capturedAt: .now)
        ]

        let description = try await composer.compose(from: records)

        #expect(description == "it looks like there's likely a chair and a table. there might be a lamp.")
    }

    /// Depth is not scene content — distance narration is AwarenessEngine's
    /// job, so a depth-only frame still reads as "nothing recognized" here.
    /// (Sounds and text used to fall through the same way; since fusion they
    /// get their own sentences — see `SoundTextSceneFusionTests`.)
    @Test
    func depthOnlyRecordsYieldTheNothingRecognizedFallback() async throws {
        let composer = LabelListSceneComposer(locale: Locale(identifier: "en"))

        let description = try await composer.compose(
            from: [PerceptionRecord(kind: .depthReading(meters: 1.2), capturedAt: .now)]
        )

        #expect(description == "Couldn't name anything.")
    }

    @Test
    func oneBucketYieldsExactlyOneSentence() async throws {
        let composer = LabelListSceneComposer(locale: Locale(identifier: "en"))
        let records = [
            PerceptionRecord(kind: .detectedObject(label: "a chair", confidence: 0.9), capturedAt: .now),
            PerceptionRecord(kind: .detectedObject(label: "a table", confidence: 0.95), capturedAt: .now)
        ]

        let description = try await composer.compose(from: records)

        #expect(description == "it looks like there's likely a chair and a table.")
    }

    @Test
    func conciseDetailCapsTheListAtTwoLabels() async throws {
        let composer = LabelListSceneComposer(locale: Locale(identifier: "en"), detail: .concise)
        let records = [
            PerceptionRecord(kind: .detectedObject(label: "a chair", confidence: 0.9), capturedAt: .now),
            PerceptionRecord(kind: .detectedObject(label: "a table", confidence: 0.9), capturedAt: .now),
            PerceptionRecord(kind: .detectedObject(label: "a lamp", confidence: 0.9), capturedAt: .now)
        ]

        let description = try await composer.compose(from: records)

        #expect(description == "it looks like there's likely a chair and a table.")
    }

    @Test
    func zeroConfidenceStillProducesALowHedgeNeverAnUnhedgedClaim() async throws {
        let composer = LabelListSceneComposer(locale: Locale(identifier: "en"))
        let record = PerceptionRecord(kind: .detectedObject(label: "a shadow", confidence: 0.0), capturedAt: .now)

        let description = try await composer.compose(from: [record])

        #expect(description == "there might be a shadow.")
    }

    @Test(arguments: [
        [0.95, 0.6, 0.1],
        [0.4, 0.4, 0.4],
        [0.99],
        [0.1, 0.99, 0.55, 0.2]
    ])
    func everySentenceCarriesAKnownHedgeFragment(confidences: [Double]) async throws {
        let composer = LabelListSceneComposer(locale: Locale(identifier: "en"))
        let records = confidences.enumerated().map { index, confidence in
            PerceptionRecord(kind: .detectedObject(label: "object \(index)", confidence: confidence), capturedAt: .now)
        }

        let description = try await composer.compose(from: records)
        let sentences = description.split(separator: ". ")
        let fragments = Phrasing.hedgeFragments(locale: Locale(identifier: "en"))

        for sentence in sentences {
            #expect(fragments.contains { sentence.hasPrefix($0) })
        }
    }
}
