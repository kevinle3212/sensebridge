import Foundation
import ImageIO
import Vision

/// Extracts text from a captured image via Apple's Vision framework — the
/// on-device OCR step in "Camera → Perception (Vision OCR) → Reasoning →
/// Output" (see docs/ARCHITECTURE.md). One `PerceptionRecord` per detected
/// text line, ordered top-to-bottom then left-to-right: Vision's bounding
/// boxes use a bottom-left origin, so descending `y` (then ascending `x`)
/// approximates reading order without needing a separate layout pass.
public struct OCRService: PerceptionService, Sendable {
    // Empty but required: a public init is needed for cross-module init; nothing to initialize.
    // swiftlint:disable:next no_empty_block
    public init() {}

    @concurrent
    public func process(_ input: Data) async throws -> [PerceptionRecord] {
        guard let source = CGImageSourceCreateWithData(input as CFData, nil),
              let cgImage = CGImageSourceCreateImageAtIndex(source, 0, nil)
        else {
            throw OCRError.invalidImageData
        }

        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = true

        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        try handler.perform([request])

        let capturedAt = Date.now
        let observations = request.results ?? []
        return observations
            .sorted {
                $0.boundingBox.origin.y != $1.boundingBox.origin.y
                    ? $0.boundingBox.origin.y > $1.boundingBox.origin.y
                    : $0.boundingBox.origin.x < $1.boundingBox.origin.x
            }
            .compactMap { observation in
                observation.topCandidates(1).first.map {
                    PerceptionRecord(kind: .recognizedText($0.string), capturedAt: capturedAt)
                }
            }
    }
}

/// Errors specific to on-device OCR — surfaced as a thrown error rather than
/// an empty result, so a corrupt capture isn't silently read back as "no
/// text found".
public enum OCRError: Error, Sendable, Equatable {
    case invalidImageData
}
