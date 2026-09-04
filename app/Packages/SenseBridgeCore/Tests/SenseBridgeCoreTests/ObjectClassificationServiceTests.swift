import CoreGraphics
import Foundation
import ImageIO
import Testing
@testable import SenseBridgeCore

/// Exercises the region-based detection pass behind the awareness screen's
/// outlines.
///
/// The parts that are this project's own logic — deduplication, the label
/// budget, the article rule — are tested directly and deterministically. The
/// Vision pass itself is tested only for its *invariants* against a
/// synthetically rendered image, because what Apple's classifier names in a
/// drawing of coloured rectangles is not something this repository controls,
/// and asserting a specific label would buy a flaky test rather than coverage.
struct ObjectClassificationServiceTests {
    @Test
    func keepsTheMostConfidentDetectionPerLabel() {
        let deduplicated = ObjectClassificationService.deduplicated(
            [
                DetectedObject(
                    label: "a chair",
                    confidence: 0.4,
                    boundingBox: .init(x: 0, y: 0, width: 0.5, height: 0.5)
                ),
                DetectedObject(
                    label: "a chair",
                    confidence: 0.9,
                    boundingBox: .init(x: 0.1, y: 0.1, width: 0.5, height: 0.5)
                ),
                DetectedObject(
                    label: "a door",
                    confidence: 0.6,
                    boundingBox: .init(x: 0.5, y: 0, width: 0.4, height: 0.9)
                )
            ],
            limit: 3
        )

        #expect(deduplicated.map(\.label) == ["a chair", "a door"])
        #expect(deduplicated[0].confidence == 0.9)
        // The surviving box must be the confident one's, not the discarded
        // duplicate's — an outline drawn in the wrong place is the failure this
        // guards against.
        #expect(deduplicated[0].boundingBox.origin.x == 0.1)
    }

    @Test
    func reportsTheMostConfidentDetectionsFirstAndNoMoreThanTheLimit() {
        let deduplicated = ObjectClassificationService.deduplicated(
            [
                DetectedObject(label: "a mug", confidence: 0.3, boundingBox: .zero),
                DetectedObject(label: "a lamp", confidence: 0.8, boundingBox: .zero),
                DetectedObject(label: "a plant", confidence: 0.5, boundingBox: .zero)
            ],
            limit: 2
        )

        #expect(deduplicated.map(\.label) == ["a lamp", "a plant"])
    }

    @Test
    func namesObjectsWithAnArticleSoPhrasingCanUseThemAsASubject() {
        #expect(ObjectClassificationService.subjectPhrase(for: "coffee_mug") == "a coffee mug")
        #expect(ObjectClassificationService.subjectPhrase(for: "escalator") == "an escalator")
    }

    /// Vagueness is decided on the normalized identifier — same normalization
    /// `SpokenPhrase` applies before its table lookups — so an identifier
    /// cannot be vague to the detector yet specific in speech.
    @Test
    func vaguenessIsDecidedOnTheNormalizedIdentifier() {
        #expect(ObjectClassificationService.isVague("consumer_electronics"))
        #expect(ObjectClassificationService.isVague("Consumer Electronics"))
        #expect(!ObjectClassificationService.isVague("television"))
    }

    /// A specific label wins even when a catch-all outscores it, and
    /// confidence orders within each group: the sentence names the thing when
    /// a name passed the precision floor and falls back to the category only
    /// when none did.
    @Test
    func orderingIsSpecificFirstThenByConfidence() {
        let ordered = ObjectClassificationService.orderedSpecificFirst(
            [
                (identifier: "consumer_electronics", confidence: 0.9),
                (identifier: "television", confidence: 0.7),
                (identifier: "monitor", confidence: 0.5)
            ],
            identifier: { $0.identifier },
            confidence: { $0.confidence }
        )

        #expect(ordered.map(\.identifier) == ["television", "monitor", "consumer_electronics"])
    }

    /// With no specific sibling available, vague labels keep their chance:
    /// they pass through with confidence order intact rather than being
    /// dropped for their vagueness.
    @Test
    func vagueLabelsKeepTheirChanceWhenNothingSpecificRemains() {
        let ordered = ObjectClassificationService.orderedSpecificFirst(
            [
                (identifier: "consumer_electronics", confidence: 0.6),
                (identifier: "consumer_electronics", confidence: 0.8)
            ],
            identifier: { $0.identifier },
            confidence: { $0.confidence }
        )

        #expect(ordered.map(\.confidence) == [0.8, 0.6])
    }

    @Test
    func everyDetectionIsWellFormedAndInsideTheFrame() async throws {
        let image = try Self.renderShapes()
        let service = ObjectClassificationService()

        let detected = try await service.detect(image)

        #expect(detected.count <= service.maximumLabels)
        #expect(Set(detected.map(\.label)).count == detected.count)
        for object in detected {
            #expect(object.boundingBox.minX >= 0)
            #expect(object.boundingBox.minY >= 0)
            #expect(object.boundingBox.maxX <= 1)
            #expect(object.boundingBox.maxY <= 1)
            // Slivers are dropped before classification; anything reported here
            // covered a meaningful share of the frame.
            #expect(object.boundingBox.width * object.boundingBox.height >= 0.02)
            #expect(object.confidence > 0)
            #expect(!object.label.isEmpty)
        }
    }

    /// Renders a few solid shapes on a plain background and encodes the result
    /// as PNG `Data` — a real image Vision can run saliency and classification
    /// against, built without touching disk or the app bundle. Mirrors
    /// `OCRServiceTests.renderText(_:)`.
    private static func renderShapes(width: Int = 640, height: Int = 480) throws -> Data {
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let context = try #require(CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ))
        context.setFillColor(CGColor(red: 0.9, green: 0.9, blue: 0.88, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        context.setFillColor(CGColor(red: 0.15, green: 0.2, blue: 0.5, alpha: 1))
        context.fill(CGRect(x: 60, y: 80, width: 200, height: 260))
        context.setFillColor(CGColor(red: 0.6, green: 0.25, blue: 0.15, alpha: 1))
        context.fillEllipse(in: CGRect(x: 360, y: 140, width: 200, height: 200))

        let image = try #require(context.makeImage())
        let output = NSMutableData()
        let destination = try #require(
            CGImageDestinationCreateWithData(output, "public.png" as CFString, 1, nil)
        )
        CGImageDestinationAddImage(destination, image, nil)
        #expect(CGImageDestinationFinalize(destination))
        return output as Data
    }
}
