import CoreGraphics
import Foundation

/// One line of recognized text, named and located.
///
/// The located half is what `PerceptionRecord.recognizedText` cannot carry, and
/// it is what live reading needs: aiming guidance is entirely a question about
/// *where on the frame* text landed, and "is the page cut off" is unanswerable
/// from the strings alone. Same relationship `DetectedObject` has to a
/// `.detectedObject` record, for the same reason — one pass produces both, so a
/// spoken sentence and the guidance around it can never describe different
/// frames.
public struct RecognizedTextLine: Sendable, Equatable {
    /// The recognized string, exactly as Vision's top candidate reported it.
    public let text: String
    /// Vision's confidence in `text`, 0...1. Retained rather than discarded
    /// after the confidence filter so a caller can weight or re-threshold
    /// without re-running recognition.
    public let confidence: Double
    /// Where the line sits, normalized to the upright image with the origin at
    /// the **top left** — SwiftUI's convention, not Vision's. The flip happens
    /// once in `OCRService` so no caller has to remember Vision uses a
    /// bottom-left origin.
    public let boundingBox: CGRect

    /// Creates a recognized line.
    public init(text: String, confidence: Double, boundingBox: CGRect) {
        self.text = text
        self.confidence = confidence
        self.boundingBox = boundingBox
    }
}
