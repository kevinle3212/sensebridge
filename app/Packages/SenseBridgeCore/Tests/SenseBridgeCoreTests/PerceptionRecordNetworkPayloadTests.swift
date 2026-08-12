import Foundation
import Testing
@testable import SenseBridgeCore

struct PerceptionRecordNetworkPayloadTests {
    @Test func onlyDetectedObjectLabelsAreIncluded() {
        let records: [PerceptionRecord] = [
            PerceptionRecord(kind: .detectedObject(label: "chair", confidence: 0.9), capturedAt: .now),
            PerceptionRecord(kind: .recognizedText("bank statement, account 12345"), capturedAt: .now),
            PerceptionRecord(kind: .detectedSound(label: "dog_bark", confidence: 0.8), capturedAt: .now),
            PerceptionRecord(kind: .depthReading(meters: 1.2), capturedAt: .now),
            PerceptionRecord(kind: .detectedObject(label: "doorway", confidence: 0.4), capturedAt: .now)
        ]
        #expect(records.detectedObjectLabelsForNetwork() == ["chair", "doorway"])
    }

    @Test func weakestConfidenceIsTheMinimumAcrossDetectedObjectsOnly() {
        let records: [PerceptionRecord] = [
            PerceptionRecord(kind: .detectedObject(label: "chair", confidence: 0.9), capturedAt: .now),
            PerceptionRecord(kind: .detectedSound(label: "siren", confidence: 0.1), capturedAt: .now),
            PerceptionRecord(kind: .detectedObject(label: "doorway", confidence: 0.4), capturedAt: .now)
        ]
        #expect(records.weakestDetectedObjectConfidence() == 0.4)
    }

    @Test func emptyRecordsProduceEmptyLabelsAndNilConfidence() {
        let records = [PerceptionRecord]()
        #expect(records.detectedObjectLabelsForNetwork().isEmpty)
        #expect(records.weakestDetectedObjectConfidence() == nil)
    }
}
