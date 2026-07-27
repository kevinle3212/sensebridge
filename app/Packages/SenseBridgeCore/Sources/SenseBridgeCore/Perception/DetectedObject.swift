import CoreGraphics
import Foundation

/// One thing the camera saw, named and located.
///
/// The located half is what separates this from `PerceptionRecord`: a record
/// says *what* was recognized, this also says *where*, so the awareness screen
/// can outline it. Both come out of the same pass in
/// `ObjectClassificationService.detect(...)` on purpose — an outline drawn from
/// one source and a sentence spoken from another would eventually disagree, and
/// a highlight around something the app never names is a claim it cannot back
/// (docs/SAFETY-FRAMING.md).
public struct DetectedObject: Sendable, Equatable, Hashable {
    /// The noun phrase, article-first ("a chair"), matching what `Phrasing`
    /// expects as a subject. English-only — see the limitation documented on
    /// `ObjectClassificationService`.
    public let label: String
    /// The classifier's confidence in `label`, 0...1. Shown as a percentage
    /// beside the outline rather than hidden, because an outline with no
    /// confidence attached reads as certainty the app has not earned.
    public let confidence: Double
    /// Where it is, normalized to the upright image with the origin at the
    /// **top left** — SwiftUI's convention, not Vision's. The flip happens once
    /// in `ObjectClassificationService` so no view has to know Vision uses a
    /// bottom-left origin.
    public let boundingBox: CGRect

    /// Creates a detected object.
    public init(label: String, confidence: Double, boundingBox: CGRect) {
        self.label = label
        self.confidence = confidence
        self.boundingBox = boundingBox
    }
}
