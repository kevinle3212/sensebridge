import Foundation
import ImageIO
import Vision

/// Names what the camera sees using Vision's built-in image classifier — the
/// on-device perception step behind "Describe" and hands-free awareness (see
/// docs/ARCHITECTURE.md).
///
/// Uses Apple's bundled classifier rather than a third-party detection model
/// on purpose: it ships with the OS, so there is no model to license, no
/// weights in the repository, and nothing for the
/// [model-license-audit](.agents/skills/model-license-audit/SKILL.md) skill to
/// clear. AGPL and `apple-amlr` weights are hard blockers here, which rules out
/// most of the alternatives.
///
/// **Partial localization, deliberately not papered over:** the classifier's
/// identifiers are English. `SpokenVocabulary` carries reviewed `es`/`vi`
/// phrases for the identifiers a real walk produces, and `locale` selects
/// among them; the ~1,300-identifier long tail still reaches a Spanish or
/// Vietnamese user as an English noun inside a translated hedge, because
/// naming the object wrongly would be worse than naming it in the wrong
/// language. Extending the table is a review task, not a code change.
public struct ObjectClassificationService: PerceptionService, Sendable {
    /// Precision floor for a label to be reported, applied via Vision's own
    /// precision/recall curve rather than a raw confidence cutoff.
    ///
    /// A bare `confidence > x` test is not comparable across identifiers —
    /// the classifier is far better calibrated for "keyboard" than for
    /// "leisure" — and this app speaks its output aloud as a claim about the
    /// physical world, so an over-reported label is a doctrine problem and not
    /// just noise.
    public let minimumPrecision: Float
    /// Most labels to report from one frame. A spoken channel can carry two or
    /// three nouns before it stops being usable; the rest are dropped rather
    /// than queued.
    public let maximumLabels: Int
    /// Language the reported labels are phrased in, resolved through
    /// `SpokenVocabulary`. Affects wording only — the precision floor, the
    /// identifiers considered, and every confidence value are unchanged, so no
    /// locale can make this service report something it would not report in
    /// another.
    public let locale: Locale

    /// Creates a classification service.
    public init(minimumPrecision: Float = 0.7, maximumLabels: Int = 3, locale: Locale = .current) {
        self.minimumPrecision = minimumPrecision
        self.maximumLabels = maximumLabels
        self.locale = locale
    }

    /// Classifies an encoded still image — the `PerceptionService` path, used
    /// by the single-capture screens.
    public func process(_ input: Data) async throws -> [PerceptionRecord] {
        try await records(from: ClassifyImageRequest().perform(on: input, orientation: nil))
    }

    /// Classifies a live camera frame without a round-trip through JPEG.
    ///
    /// Hands-free awareness runs this every few seconds for as long as the
    /// user is walking; encoding each frame only to decode it again would burn
    /// battery on a device already holding a LiDAR session open.
    public func classify(
        _ pixelBuffer: CVPixelBuffer,
        orientation: CGImagePropertyOrientation
    ) async throws -> [PerceptionRecord] {
        try await records(from: ClassifyImageRequest().perform(on: pixelBuffer, orientation: orientation))
    }

    /// Smallest share of the frame a salient region may cover and still be
    /// classified.
    ///
    /// Objectness saliency happily returns slivers a few pixels across, and the
    /// classifier will name one anyway — confidently, and usually wrongly,
    /// because a 1% crop of a chair leg is not a chair leg to a model trained on
    /// whole objects. Discarding them is the single largest accuracy win here,
    /// and it is the honest choice too: an outline the app cannot justify is
    /// worse than no outline.
    private static let minimumRegionArea: Double = 0.02

    /// Names and locates the individual objects in an image, rather than
    /// labelling the frame as a whole.
    ///
    /// Two passes over one prepared image: objectness saliency proposes the
    /// regions that look like discrete things, then each region is classified on
    /// its own. That is more accurate than `classify(_:orientation:)` for a
    /// cluttered scene — a single whole-frame pass averages a room into one
    /// label and tends to answer with the wall — and it is the only path that
    /// yields a bounding box, which the awareness screen needs to outline what
    /// it is talking about.
    ///
    /// Regions that no identifier describes precisely enough are dropped rather
    /// than reported with a weak guess, so the returned list is exactly what the
    /// app is willing to both name aloud and draw a box around.
    public func detect(
        _ pixelBuffer: CVPixelBuffer,
        orientation: CGImagePropertyOrientation
    ) async throws -> [DetectedObject] {
        try await detect(using: ImageRequestHandler(pixelBuffer, orientation: orientation))
    }

    /// Names and locates objects in an encoded still image. Same pass as
    /// `detect(_:orientation:)`; this overload exists for callers holding
    /// encoded data, and for tests that render a synthetic image.
    public func detect(_ input: Data) async throws -> [DetectedObject] {
        try await detect(using: ImageRequestHandler(input))
    }

    /// The shared two-pass implementation, written against a handler so the
    /// image is prepared once and reused across every request below.
    private func detect(using handler: ImageRequestHandler) async throws -> [DetectedObject] {
        let saliency = try await handler.perform(GenerateObjectnessBasedSaliencyImageRequest())
        // Twice the reported budget: some candidates will fail the precision
        // floor below, and it is better to have spares than to return two
        // objects when three were visible.
        let candidates = saliency.salientObjects
            .filter { Double($0.boundingBox.width * $0.boundingBox.height) >= Self.minimumRegionArea }
            .sorted { $0.confidence > $1.confidence }
            .prefix(maximumLabels * 2)

        var detected = [DetectedObject]()
        for region in candidates {
            guard let label = try await bestLabel(in: region.boundingBox, using: handler) else { continue }
            detected.append(DetectedObject(
                label: Self.subjectPhrase(for: label.identifier, locale: locale),
                confidence: Double(label.confidence),
                // Vision normalizes from the bottom left and every view here
                // measures from the top left. Flipped once, at the boundary.
                boundingBox: region.boundingBox.verticallyFlipped().cgRect
            ))
        }
        return Self.deduplicated(detected, limit: maximumLabels)
    }

    /// Classifies one region and returns its best sufficiently-precise
    /// identifier, or `nil` when nothing describes the region well enough.
    private func bestLabel(
        in region: NormalizedRect,
        using handler: ImageRequestHandler
    ) async throws -> ClassificationObservation? {
        var request = ClassifyImageRequest()
        request.regionOfInterest = region
        // `.scaleToFit` rather than the center crop: the region has already been
        // chosen as the interesting part, and cropping it again would feed the
        // classifier the middle of an object instead of the object.
        request.cropAndScaleAction = .scaleToFit
        return try await handler.perform(request)
            .filter { $0.hasMinimumPrecision(minimumPrecision, forRecall: 0) }
            .max { $0.confidence < $1.confidence }
    }

    /// Keeps the most confident detection per label, most confident first, up to
    /// `limit`.
    ///
    /// Saliency regularly proposes two overlapping regions for one object, and
    /// both classify the same way. Outlining "a chair" twice makes the app look
    /// like it sees two chairs.
    static func deduplicated(_ objects: [DetectedObject], limit: Int) -> [DetectedObject] {
        var bestByLabel = [String: DetectedObject]()
        for object in objects where (bestByLabel[object.label]?.confidence ?? -1) < object.confidence {
            bestByLabel[object.label] = object
        }
        return Array(bestByLabel.values.sorted { $0.confidence > $1.confidence }.prefix(limit))
    }

    /// Filters and converts raw observations into `PerceptionRecord` values.
    private func records(from observations: [ClassificationObservation]) -> [PerceptionRecord] {
        let capturedAt = Date.now
        return observations
            // `forRecall: 0` asks "at any recall, is this identifier precise
            // enough?", which is the loosest form of the check and the one
            // Apple documents for filtering a general classification pass.
            .filter { $0.hasMinimumPrecision(minimumPrecision, forRecall: 0) }
            .sorted { $0.confidence > $1.confidence }
            .prefix(maximumLabels)
            .map { observation in
                PerceptionRecord(
                    kind: .detectedObject(
                        label: Self.subjectPhrase(for: observation.identifier, locale: locale),
                        confidence: Double(observation.confidence)
                    ),
                    capturedAt: capturedAt
                )
            }
    }

    /// Turns a Vision identifier into the noun phrase `Phrasing` expects.
    ///
    /// `Phrasing.describe(subject:certainty:)` renders "it looks like there's
    /// %@.", so the subject has to arrive article-first — the same shape the
    /// hand-written fixtures elsewhere in the codebase use ("a chair"). Vision
    /// hands back bare, underscore-joined identifiers ("coffee_mug"). Forwards
    /// to `SpokenPhrase`, the single implementation this and
    /// `SoundClassificationRunner.subjectPhrase(for:locale:)` both use.
    static func subjectPhrase(for identifier: String, locale: Locale = .current) -> String {
        SpokenPhrase.subject(for: identifier, locale: locale)
    }
}
