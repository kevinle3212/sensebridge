import Foundation
import SenseBridgeCore

/// Composition-pipeline helpers that touch session state (`classifier`,
/// `throttle`, `deliver`), split out of `AmbientAwarenessSession.swift` to
/// keep it under SwiftLint's `file_length` and `type_body_length` gates.
///
/// `classifier`, `throttle`, `resolver`, `locale`, and `deliver` are
/// internal on the class specifically so this same-type extension can reach
/// them from another file.
extension AmbientAwarenessSession {
    // swiftlint:disable discouraged_optional_collection
    /// Builds the records to compose from — detections if the last pass
    /// found any discrete objects, otherwise a whole-frame classification
    /// pass. Split out of `describeIfDue` so that method reads as the
    /// scheduling/cancellation logic it is, not classification plumbing.
    ///
    /// Returns `nil`, not an empty array, when classification itself
    /// failed — a real, distinct signal from "classified as empty" that
    /// `describeIfDue` uses to skip the tick entirely rather than announce
    /// "nothing recognized" for a frame that was never actually read.
    func records(for frame: AmbientFrame, detections: [DetectedObject]) async -> [PerceptionRecord]? {
        if detections.isEmpty {
            do {
                return try await classifier.classify(frame.image, orientation: frame.orientation)
            } catch {
                return nil
            }
        }
        return detections.map {
            PerceptionRecord(kind: .detectedObject(label: $0.label, confidence: $0.confidence), capturedAt: .now)
        }
    }

    // swiftlint:enable discouraged_optional_collection

    /// Delivers a resolver result: the breaker announcement first (if any,
    /// always spoken), then the routine narration itself — gated on speech
    /// not already being in flight and the throttle's dedup/cadence rules.
    /// Split out of `describeIfDue`'s composition `Task` to keep that
    /// closure's cyclomatic complexity within SwiftLint's limit.
    func deliverComposedResult(
        _ result: ReasoningComposeResult,
        records: [PerceptionRecord],
        environment: AppEnvironment
    ) async {
        if let announcement = result.announcement {
            await deliver(announcement, signal: .error, isUrgent: true, to: environment)
        }
        // Routine narration is skipped, not queued, while speech is already
        // in flight — `render` interrupts, which is right for a one-shot
        // capture and wrong here, where it would cut every sentence off
        // with the next one. The breaker announcement above is deliberately
        // exempt (`isUrgent: true`), matching
        // `SpeechRenderTarget.isSpeaking`'s documented contract.
        guard await !environment.speech.isSpeaking else { return }
        guard throttle.shouldSpeak(result.text, at: Date.now) else { return }
        await deliver(
            result.text,
            signal: records.isEmpty ? .nothingFound : .resultReady,
            isUrgent: false,
            to: environment
        )
    }
}
