import CoreGraphics
import CoreVideo
import Foundation
import ImageIO
import Vision

/// Extracts text from a captured image via Apple's Vision framework — the
/// on-device OCR step in "Camera → Perception (Vision OCR) → Reasoning →
/// Output" (see docs/ARCHITECTURE.md). One `PerceptionRecord` per detected
/// text line, in reading order.
///
/// ## Reading order is banded, not sorted by `y`
///
/// Vision returns a bounding box per line, and two words on the same printed
/// row rarely share an exact `y` — different glyph heights, a comma dipping
/// below the baseline, and any camera tilt all shift it. Sorting purely by `y`
/// therefore interleaves columns and reads a receipt's item and its price as
/// two separate lines several lines apart. Grouping boxes that vertically
/// overlap into a row first, then ordering within the row by `x`, reads the way
/// the page is laid out. This is the "line/paragraph grouping" the repo's OCR
/// quality item asked for.
///
/// ## Low-confidence lines are dropped, not spoken
///
/// Vision reports a per-candidate confidence and will happily return a garbage
/// string for a smudge. Speaking one is a claim about text that may not exist,
/// which `docs/SAFETY-FRAMING.md` treats the same way as naming an object
/// wrongly. Below `minimumConfidence` a line is discarded rather than read
/// aloud — the honest failure is "no text was found", not a plausible-sounding
/// invention.
public struct OCRService: PerceptionService, Sendable {
    /// Confidence a recognized line must clear to be reported.
    ///
    /// Deliberately low. This is a floor against garbage, not a quality bar:
    /// legitimate text photographed at an angle or in poor light routinely
    /// scores in the middle of the range, and dropping it would trade a
    /// recognizable mistake for a silent omission — worse for someone who
    /// cannot see that anything was missed.
    public let minimumConfidence: Float

    /// Creates an OCR service.
    /// - Parameter minimumConfidence: Floor a line must clear to be reported.
    ///   See ``minimumConfidence`` for why the default is as low as it is.
    public init(minimumConfidence: Float = 0.3) {
        self.minimumConfidence = minimumConfidence
    }

    /// Recognizes text in an encoded still image.
    /// - Parameter input: Encoded image data (PNG, JPEG — anything ImageIO reads).
    /// - Returns: One `.recognizedText` record per line that cleared
    ///   ``minimumConfidence``, in reading order. Empty when the image holds no
    ///   text, which is a valid observation rather than a failure.
    /// - Throws: ``OCRError/invalidImageData`` when the bytes are not a
    ///   decodable image, or whatever Vision throws while performing the request.
    @concurrent
    public func process(_ input: Data) async throws -> [PerceptionRecord] {
        let capturedAt = Date.now
        return try recognizeLines(in: input).map {
            PerceptionRecord(kind: .recognizedText($0.text), capturedAt: capturedAt)
        }
    }

    /// Recognizes text in an encoded still image, keeping each line's position.
    ///
    /// The richer counterpart to ``process(_:)``, which discards geometry
    /// because `PerceptionRecord` has nowhere to put it. Aiming guidance
    /// (``ReadingFraming``) is entirely a question about position, so live
    /// reading calls this and the Reasoning layer keeps seeing records.
    ///
    /// - Parameter input: Encoded image data (PNG, JPEG — anything ImageIO reads).
    /// - Returns: One line per recognized string that cleared
    ///   ``minimumConfidence``, in reading order, with top-left-origin
    ///   normalized boxes.
    /// - Throws: ``OCRError/invalidImageData`` when the bytes are not a
    ///   decodable image, or whatever Vision throws while performing the request.
    @concurrent
    public func recognize(_ input: Data) async throws -> [RecognizedTextLine] {
        try recognizeLines(in: input)
    }

    /// Recognizes text in a live camera frame.
    ///
    /// Takes the pixel buffer directly rather than an encoded still: live
    /// reading runs this several times a second, and round-tripping every frame
    /// through JPEG encode/decode purely to reuse the `Data` entry point would
    /// spend more time compressing than recognizing.
    ///
    /// - Parameters:
    ///   - buffer: A camera frame in the camera's native orientation.
    ///   - orientation: What to tell Vision so the frame is analyzed upright.
    ///     Pass the frame's own orientation rather than rotating the buffer —
    ///     Vision applies it internally at no cost.
    /// - Returns: The same shape as ``recognize(_:)-(Data)``, boxes normalized
    ///   to the **upright** image, so a caller never has to un-rotate them.
    /// - Throws: Whatever Vision throws while performing the request.
    @concurrent
    public func recognize(
        _ buffer: CVPixelBuffer,
        orientation: CGImagePropertyOrientation
    ) async throws -> [RecognizedTextLine] {
        let request = Self.makeRequest(usesLanguageCorrection: false)
        let handler = VNImageRequestHandler(cvPixelBuffer: buffer, orientation: orientation, options: [:])
        try handler.perform([request])
        return lines(from: request)
    }

    /// The synchronous body behind both `Data` entry points, so the throwing
    /// decode and the request setup exist once rather than being kept in step
    /// by hand across two `@concurrent` methods.
    ///
    /// Deliberately **not** named `recognize`: an overload differing from the
    /// public `async` one only in its effects is resolved in favour of the
    /// `async` member inside an `async` body, so `try recognize(input)` there
    /// would call the public method and recurse until the stack ran out.
    private func recognizeLines(in input: Data) throws -> [RecognizedTextLine] {
        guard let source = CGImageSourceCreateWithData(input as CFData, nil),
              let cgImage = CGImageSourceCreateImageAtIndex(source, 0, nil)
        else {
            throw OCRError.invalidImageData
        }
        let request = Self.makeRequest(usesLanguageCorrection: true)
        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        try handler.perform([request])
        return lines(from: request)
    }

    /// A text request configured for this app.
    ///
    /// - Parameter usesLanguageCorrection: On for a deliberate still capture,
    ///   where the extra pass buys real accuracy on a photo the user framed and
    ///   held. Off for live frames: it is the most expensive part of the
    ///   request, and live reading re-recognizes the same page several times a
    ///   second, so a word it would have fixed is fixed by the next frame
    ///   instead — at a fraction of the battery.
    private static func makeRequest(usesLanguageCorrection: Bool) -> VNRecognizeTextRequest {
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = usesLanguageCorrection
        return request
    }

    /// Turns a performed request's observations into confidence-filtered lines
    /// in reading order, flipping Vision's bottom-left origin to top-left on the
    /// way out.
    private func lines(from request: VNRecognizeTextRequest) -> [RecognizedTextLine] {
        Self.inReadingOrder(request.results ?? [], boundingBox: \.boundingBox)
            .compactMap { observation -> RecognizedTextLine? in
                guard let candidate = observation.topCandidates(1).first,
                      candidate.confidence >= minimumConfidence
                else {
                    return nil
                }
                return RecognizedTextLine(
                    text: candidate.string,
                    confidence: Double(candidate.confidence),
                    boundingBox: Self.topLeftOrigin(observation.boundingBox)
                )
            }
    }

    /// Re-expresses a Vision box with the origin at the top left.
    ///
    /// Vision measures `y` upward from the bottom of the image; SwiftUI and
    /// every consumer in this app measure it downward from the top. Doing the
    /// flip once, here, is what lets `ReadingFraming` say "top" and mean the top
    /// of what the user is facing — matching the same choice
    /// `ObjectClassificationService` makes for `DetectedObject`.
    static func topLeftOrigin(_ box: CGRect) -> CGRect {
        CGRect(x: box.minX, y: 1 - box.maxY, width: box.width, height: box.height)
    }

    /// Orders `items` the way the page reads: rows top to bottom, and within a
    /// row, left to right.
    ///
    /// Generic over how a bounding box is obtained so the ordering can be
    /// tested against plain rectangles — Vision's observation types cannot be
    /// constructed in a test, which is why the previous version's ordering was
    /// only ever exercised through a rendered image.
    ///
    /// Boxes are assumed to use Vision's bottom-left origin, so a larger `y` is
    /// higher on the page.
    ///
    /// - Parameters:
    ///   - items: Recognized items in any order.
    ///   - boundingBox: Normalized box for one item.
    /// - Returns: The same items, in reading order.
    static func inReadingOrder<T>(_ items: [T], boundingBox: (T) -> CGRect) -> [T] {
        // Top-down first, so a row is always opened by its highest member and
        // every later candidate is compared against a row that is already at
        // its final vertical position.
        let topDown = items.sorted { boundingBox($0).midY > boundingBox($1).midY }

        var rows = [[T]]()
        for item in topDown {
            let box = boundingBox(item)
            // Same row when this box's vertical centre falls inside the row's
            // span. Centre-in-span rather than any-overlap: a tall heading
            // brushing the line beneath it overlaps by a pixel or two, and
            // treating that as one row would splice a heading into body text.
            if let index = rows.indices.last, let reference = rows[index].first.map(boundingBox),
               box.midY <= reference.maxY, box.midY >= reference.minY {
                rows[index].append(item)
            } else {
                rows.append([item])
            }
        }

        return rows.flatMap { row in
            row.sorted { boundingBox($0).minX < boundingBox($1).minX }
        }
    }
}

/// Errors specific to on-device OCR — surfaced as a thrown error rather than
/// an empty result, so a corrupt capture isn't silently read back as "no
/// text found".
public enum OCRError: Error, Sendable, Equatable {
    case invalidImageData
}
