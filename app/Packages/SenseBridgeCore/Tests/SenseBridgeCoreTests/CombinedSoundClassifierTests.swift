import Foundation
import Testing
@testable import SenseBridgeCore

private struct FakeSoundService: SoundService {
    let records: [PerceptionRecord]
    /// Not `throws`: this fake only ever returns its canned records, and
    /// declaring a throw the body cannot perform hides which tests actually
    /// exercise the failure path.
    func process(_: Data) async -> [PerceptionRecord] {
        records
    }
}

struct CombinedSoundClassifierTests {
    @Test
    func returnsTheHigherConfidenceHitAcrossBothClassifiers() async throws {
        let weakHit = PerceptionRecord(kind: .detectedSound(label: "dog_bark", confidence: 0.4), capturedAt: .now)
        let strongHit = PerceptionRecord(kind: .detectedSound(label: "doorbell", confidence: 0.9), capturedAt: .now)
        let combined = CombinedSoundClassifier(
            primary: FakeSoundService(records: [weakHit]),
            secondary: FakeSoundService(records: [strongHit])
        )

        let result = try await combined.process(Data([0x00]))

        #expect(result.count == 1)
        #expect(result.first?.kind == strongHit.kind)
    }

    @Test
    func returnsEmptyWhenNeitherClassifierRecognizesAnything() async throws {
        let combined = CombinedSoundClassifier(
            primary: FakeSoundService(records: []),
            secondary: FakeSoundService(records: [])
        )

        let result = try await combined.process(Data([0x00]))

        #expect(result.isEmpty)
    }
}
