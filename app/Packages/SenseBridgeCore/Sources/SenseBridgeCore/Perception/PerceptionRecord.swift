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
