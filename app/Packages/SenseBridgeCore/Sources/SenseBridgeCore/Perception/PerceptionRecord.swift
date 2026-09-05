import Foundation

/// A structured fact extracted from raw sensor data. This is the boundary
/// type between Perception and Reasoning: Reasoning only ever sees
/// `PerceptionRecord` values, never raw pixels, audio, or depth buffers, so
/// Reasoning logic stays device-agnostic and testable without fixtures of
/// real sensor data.
public struct PerceptionRecord: Sendable, Equatable {
    public enum Kind: Sendable, Equatable {
        case recognizedText(String)
        case detectedObject(label: String, confidence: Double)
        case detectedSound(label: String, confidence: Double)
        case depthReading(meters: Double)
    }

    public let kind: Kind
    public let capturedAt: Date

    public init(kind: Kind, capturedAt: Date) {
        self.kind = kind
        self.capturedAt = capturedAt
    }
}

/// The wire contract for every network reasoning composer — see
/// docs/superpowers/specs/2026-08-11-awareness-ai-tiers-design.md "The wire
/// contract". `.recognizedText`, `.detectedSound`, and `.depthReading` never
/// leave the device; only object labels do, and confidence values are never
/// serialized (the hedge is computed from them locally).
public extension [PerceptionRecord] {
    /// Object labels only, in order, for building a network composer's
    /// request body.
    func detectedObjectLabelsForNetwork() -> [String] {
        compactMap { record in
            guard case let .detectedObject(label, _) = record.kind else { return nil }
            return label
        }
    }

    /// The lowest detector confidence among `.detectedObject` records, or
    /// `nil` when there are none. A composed phrase naming several objects is
    /// only as trustworthy as its weakest member — see
    /// `FoundationModelsSceneComposer`'s identical reasoning for the
    /// on-device path.
    func weakestDetectedObjectConfidence() -> Double? {
        compactMap { record in
            guard case let .detectedObject(_, confidence) = record.kind else { return nil }
            return confidence
        }.min()
    }
}
