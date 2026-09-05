import CoreGraphics
import CoreImage
import Foundation
import ImageIO
import Vision

/// Finds a page in a captured photo and flattens it before OCR runs.
///
/// A blind user photographs a document by holding the phone roughly over it,
/// which means the page arrives as a trapezoid with one end noticeably smaller
/// than the other. Vision's recognizer copes with mild skew and degrades on
/// real ones — most visibly on the far edge, where a menu's last three lines
/// stop being recognized at all and the listener is given a page that quietly
/// ends early. Flattening first is what turns that into a full read.
///
/// ## It never replaces the original on a guess
///
/// Correction is applied only when a plausible page was found
/// (``DocumentQuad/isPlausiblePage``). Everything else — a sign, a screen, a
/// pill bottle, a page the detector missed — is passed through untouched.
/// The failure mode this guards against is specific and silent: a correction
/// applied to a wrongly-detected quad crops away real text, and the listener
/// hears a shorter document with no indication anything was lost.
public struct DocumentScanner: Sendable {
    // Creates a scanner. Empty but required: a public init is needed for
    // cross-module construction, and there is no state to initialize — every
    // input this type needs arrives as an argument. A `///` comment here trips
    // `orphaned_doc_comment`, which is why this is a plain one, matching
    // `CameraSource` and `Phrasing`.
    // swiftlint:disable:next no_empty_block
    public init() {}

    /// Flattens the page in `input`, or returns `input` unchanged.
    ///
    /// - Parameter input: An encoded photo (PNG, JPEG — anything ImageIO reads).
    /// - Returns: JPEG data for the corrected page, or `input` itself when no
    ///   plausible page was found or the correction could not be rendered.
    ///   Returning the input rather than throwing is deliberate: a photo with no
    ///   detectable page is the *normal* case for "Read" — a bus ticket, a
    ///   label, a handwritten note — and treating it as an error would make the
    ///   common path the failing one.
    /// - Throws: ``OCRError/invalidImageData`` when the bytes are not a
    ///   decodable image, matching what `OCRService` throws for the same input,
    ///   so a caller has one error to handle rather than two.
    @concurrent
    public func flattened(_ input: Data) async throws -> Data {
        guard let source = CGImageSourceCreateWithData(input as CFData, nil),
              let cgImage = CGImageSourceCreateImageAtIndex(source, 0, nil)
        else {
            throw OCRError.invalidImageData
        }
        guard let quad = Self.detectPage(in: cgImage), quad.isPlausiblePage else { return input }
        return Self.corrected(cgImage, to: quad) ?? input
    }

    /// The page Vision found in `image`, or `nil` when it found none.
    ///
    /// Uses the document-segmentation request rather than the general rectangle
    /// detector: the latter happily returns picture frames, tabletops, and
    /// laptop screens, and this step's whole value depends on the quad actually
    /// being a page.
    static func detectPage(in image: CGImage) -> DocumentQuad? {
        let request = VNDetectDocumentSegmentationRequest()
        let handler = VNImageRequestHandler(cgImage: image, options: [:])
        guard (try? handler.perform([request])) != nil,
              let observation = request.results?.first
        else { return nil }
        return DocumentQuad(
            topLeft: observation.topLeft,
            topRight: observation.topRight,
            bottomLeft: observation.bottomLeft,
            bottomRight: observation.bottomRight
        )
    }

    /// Renders `image` with `quad`'s perspective removed, as JPEG data.
    ///
    /// Core Image's own perspective filter rather than a hand-rolled homography:
    /// it is GPU-backed, correct, and already on the device. Corners are scaled
    /// from normalized units into pixels here because Vision reports normalized
    /// and Core Image expects pixels — both use a bottom-left origin, so there
    /// is no flip, and adding one is the classic way to get an upside-down page
    /// that still OCRs to nothing.
    private static func corrected(_ image: CGImage, to quad: DocumentQuad) -> Data? {
        let extent = CGSize(width: image.width, height: image.height)
        let filter = CIFilter(name: "CIPerspectiveCorrection")
        filter?.setValue(CIImage(cgImage: image), forKey: kCIInputImageKey)
        filter?.setValue(CIVector(cgPoint: scale(quad.topLeft, to: extent)), forKey: "inputTopLeft")
        filter?.setValue(CIVector(cgPoint: scale(quad.topRight, to: extent)), forKey: "inputTopRight")
        filter?.setValue(CIVector(cgPoint: scale(quad.bottomLeft, to: extent)), forKey: "inputBottomLeft")
        filter?.setValue(CIVector(cgPoint: scale(quad.bottomRight, to: extent)), forKey: "inputBottomRight")
        guard let output = filter?.outputImage, !output.extent.isInfinite, !output.extent.isEmpty else {
            return nil
        }
        // 0.9 rather than 1.0: the difference is invisible to a recognizer and
        // meaningfully smaller to hold in memory across a multi-page capture.
        return renderContext.jpegRepresentation(
            of: output,
            colorSpace: CGColorSpace(name: CGColorSpace.sRGB) ?? output.colorSpace ?? CGColorSpaceCreateDeviceRGB(),
            options: [kCGImageDestinationLossyCompressionQuality as CIImageRepresentationOption: 0.9]
        )
    }

    /// Converts one normalized corner into pixel coordinates.
    private static func scale(_ point: CGPoint, to size: CGSize) -> CGPoint {
        CGPoint(x: point.x * size.width, y: point.y * size.height)
    }

    /// One context for every correction, for the same reason
    /// `AmbientSensingSource` keeps one: a fresh `CIContext` allocates its own
    /// GPU resources, and creating one per page is how this step becomes the
    /// expensive part of a capture.
    private static let renderContext: CIContext = .init()
}
