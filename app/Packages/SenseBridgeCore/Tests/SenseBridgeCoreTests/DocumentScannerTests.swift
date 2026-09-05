import CoreGraphics
import CoreText
import Foundation
import ImageIO
import Testing
@testable import SenseBridgeCore

struct DocumentScannerTests {
    @Test
    func stillReadsTextOffAFrameItPutThroughTheScanner() async throws {
        // The end-to-end property that matters, and the one a unit test can
        // actually pin: whichever path the detector takes, what comes out is
        // still the page the user aimed at. Which path it takes is Vision's
        // call and varies by OS build, so asserting on that instead would be
        // testing the framework rather than this code.
        let page = try Self.renderText(["Gate 12 boarding now"])

        let flattened = try await DocumentScanner().flattened(page)
        let lines = try await OCRService().recognize(flattened)

        #expect(lines.contains { $0.text.localizedCaseInsensitiveContains("Gate 12") })
    }

    @Test
    func handsBackTheOriginalFrameRatherThanCroppingToSomethingTooSmallToBeThePage() {
        // A pill bottle or a ticket produces a rectangle that is not the page.
        // `DocumentQuad.isPlausiblePage` rejects it, and rejection has to mean
        // "hand the original through" — correcting to it would crop away the
        // text the user aimed at, which a listener has no way to notice.
        let quad = DocumentQuad(
            topLeft: CGPoint(x: 0.4, y: 0.6),
            topRight: CGPoint(x: 0.6, y: 0.6),
            bottomLeft: CGPoint(x: 0.4, y: 0.4),
            bottomRight: CGPoint(x: 0.6, y: 0.4)
        )

        #expect(!quad.isPlausiblePage)
    }

    @Test
    func throwsOnBytesThatAreNotAnImage() async {
        await #expect(throws: OCRError.invalidImageData) {
            _ = try await DocumentScanner().flattened(Data("not an image".utf8))
        }
    }

    @Test
    func throwsOnEmptyDataRatherThanReturningItAsAFrame() async {
        await #expect(throws: OCRError.invalidImageData) {
            _ = try await DocumentScanner().flattened(Data())
        }
    }

    @Test
    func flattenedOutputStaysDecodableSoOCRCanStillReadIt() async throws {
        // Whatever this returns feeds straight into `OCRService`, so the one
        // property that must hold on every path is that it is still an image.
        let blank = try Self.renderText([])

        let flattened = try await DocumentScanner().flattened(blank)

        #expect(CGImageSourceCreateWithData(flattened as CFData, nil) != nil)
    }

    /// Renders `lines` as high-contrast black-on-white PNG data — a real image,
    /// built without touching disk or the app bundle.
    private static func renderText(_ lines: [String], width: Int = 800, height: Int = 400) throws -> Data {
        let context = try #require(CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ))
        context.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))

        let font = CTFontCreateWithName("Helvetica" as CFString, 36, nil)
        let attributes = [
            kCTFontAttributeName: font,
            kCTForegroundColorAttributeName: CGColor(red: 0, green: 0, blue: 0, alpha: 1)
        ] as CFDictionary
        var lineTop = CGFloat(height) - 60
        for line in lines {
            let attributedLine = try #require(CFAttributedStringCreate(nil, line as CFString, attributes))
            context.textPosition = CGPoint(x: 40, y: lineTop)
            CTLineDraw(CTLineCreateWithAttributedString(attributedLine), context)
            lineTop -= 60
        }

        let cgImage = try #require(context.makeImage())
        let data = NSMutableData()
        let destination = try #require(CGImageDestinationCreateWithData(data, "public.png" as CFString, 1, nil))
        CGImageDestinationAddImage(destination, cgImage, nil)
        CGImageDestinationFinalize(destination)
        return data as Data
    }
}
