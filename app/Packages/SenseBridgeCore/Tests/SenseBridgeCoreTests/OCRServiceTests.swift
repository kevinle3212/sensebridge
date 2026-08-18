import CoreGraphics
import CoreText
import Foundation
import ImageIO
import Testing
@testable import SenseBridgeCore

/// Exercises OCRService against a synthetically rendered image rather than a
/// bundled fixture file, so the test stays a pure function of CoreGraphics +
/// CoreText — no image asset to keep in sync, no Package.swift resource
/// wiring, works identically under `xcodebuild test -destination
/// 'platform=macOS'` (see docs/TESTING.md "swift test cannot validate...").
struct OCRServiceTests {
    @Test
    func recognizesTextFromACapturedImage() async throws {
        let image = try Self.renderText(["Welcome to SenseBridge"])
        let records = try await OCRService().process(image)

        let recognized = records.compactMap { record -> String? in
            if case let .recognizedText(text) = record.kind {
                return text
            }
            return nil
        }
        #expect(recognized.contains { $0.localizedCaseInsensitiveContains("SenseBridge") })
    }

    @Test
    func ordersMultipleLinesTopToBottom() async throws {
        let image = try Self.renderText(["First line", "Second line", "Third line"])
        let records = try await OCRService().process(image)

        let recognized = records.compactMap { record -> String? in
            if case let .recognizedText(text) = record.kind {
                return text
            }
            return nil
        }
        #expect(recognized.count == 3)
        #expect(recognized[0].localizedCaseInsensitiveContains("First"))
        #expect(recognized[1].localizedCaseInsensitiveContains("Second"))
        #expect(recognized[2].localizedCaseInsensitiveContains("Third"))
    }

    /// Two boxes on the same printed row, at slightly different `y` — the
    /// normal case for any real photograph, and what a plain `y` sort gets
    /// wrong. Must read left to right as one row, not as two rows.
    @Test
    func sameRowBoxesReadLeftToRightDespiteUnequalY() {
        let items = [
            ("price", CGRect(x: 0.80, y: 0.501, width: 0.1, height: 0.04)),
            ("item", CGRect(x: 0.10, y: 0.500, width: 0.3, height: 0.05))
        ]
        let ordered = OCRService.inReadingOrder(items, boundingBox: \.1).map(\.0)
        #expect(ordered == ["item", "price"])
    }

    @Test
    func separateRowsReadTopToBottom() {
        // Vision's origin is bottom-left, so a larger y is higher on the page.
        let items = [
            ("bottom", CGRect(x: 0.1, y: 0.10, width: 0.3, height: 0.05)),
            ("top", CGRect(x: 0.1, y: 0.80, width: 0.3, height: 0.05)),
            ("middle", CGRect(x: 0.1, y: 0.45, width: 0.3, height: 0.05))
        ]
        let ordered = OCRService.inReadingOrder(items, boundingBox: \.1).map(\.0)
        #expect(ordered == ["top", "middle", "bottom"])
    }

    /// A tall heading whose box brushes the line beneath it must not swallow
    /// that line into its row — centre-in-span, not any-overlap.
    @Test
    func aTallHeadingDoesNotAbsorbTheLineBelowIt() {
        let items = [
            ("heading", CGRect(x: 0.1, y: 0.70, width: 0.6, height: 0.12)),
            ("body", CGRect(x: 0.1, y: 0.66, width: 0.6, height: 0.04))
        ]
        let ordered = OCRService.inReadingOrder(items, boundingBox: \.1).map(\.0)
        #expect(ordered == ["heading", "body"])
    }

    @Test
    func readingOrderHandlesEmptyAndSingleInput() {
        #expect(OCRService.inReadingOrder([(String, CGRect)](), boundingBox: \.1).isEmpty)
        let one = [("only", CGRect(x: 0.1, y: 0.5, width: 0.2, height: 0.05))]
        #expect(OCRService.inReadingOrder(one, boundingBox: \.1).map(\.0) == ["only"])
    }

    /// A three-column row stays in column order rather than in the arbitrary
    /// order Vision happened to return it.
    @Test
    func multipleColumnsInOneRowStayInColumnOrder() {
        let items = [
            ("c", CGRect(x: 0.70, y: 0.500, width: 0.1, height: 0.04)),
            ("a", CGRect(x: 0.10, y: 0.502, width: 0.1, height: 0.04)),
            ("b", CGRect(x: 0.40, y: 0.499, width: 0.1, height: 0.04))
        ]
        let ordered = OCRService.inReadingOrder(items, boundingBox: \.1).map(\.0)
        #expect(ordered == ["a", "b", "c"])
    }

    @Test
    func throwsOnInvalidImageData() async {
        await #expect(throws: OCRError.invalidImageData) {
            _ = try await OCRService().process(Data("not an image".utf8))
        }
    }

    @Test
    func returnsLinesWithBoxesAndConfidenceForFramingGuidance() async throws {
        // `process` throws the geometry away; the aiming guidance on the Read
        // screen is built entirely out of it, so it needs its own entry point.
        let image = try Self.renderText(["Welcome to SenseBridge"])

        let lines = try await OCRService().recognize(image)

        let line = try #require(lines.first)
        #expect(line.text.localizedCaseInsensitiveContains("SenseBridge"))
        #expect(line.confidence > 0)
        #expect(line.boundingBox.width > 0 && line.boundingBox.height > 0)
        #expect((0 ... 1).contains(line.boundingBox.minY))
    }

    @Test
    func recognizeThrowsOnInvalidImageDataToo() async {
        await #expect(throws: OCRError.invalidImageData) {
            _ = try await OCRService().recognize(Data("still not an image".utf8))
        }
    }

    @Test
    func flipsVisionsBottomLeftBoxesIntoTheTopLeftOriginSwiftUIDraws() {
        // Getting this backwards would report text running off the top edge as
        // running off the bottom, and send the user's aim the wrong way.
        let bottomOfFrame = CGRect(x: 0.1, y: 0.0, width: 0.5, height: 0.1)

        let flipped = OCRService.topLeftOrigin(bottomOfFrame)

        #expect(flipped.minY == 0.9)
        #expect(flipped.maxY == 1.0)
        #expect(flipped.minX == bottomOfFrame.minX)
        #expect(flipped.width == bottomOfFrame.width)
        #expect(flipped.height == bottomOfFrame.height)
    }

    @Test
    func flippingTwiceReturnsTheOriginalBox() {
        // To within floating-point rounding: `1 - maxY` is not exactly its own
        // inverse in binary, and a box off by 10⁻¹⁶ of the frame is not a
        // difference any camera or any listener can tell.
        let box = CGRect(x: 0.2, y: 0.35, width: 0.4, height: 0.07)

        let roundTripped = OCRService.topLeftOrigin(OCRService.topLeftOrigin(box))

        #expect(abs(roundTripped.minY - box.minY) < 0.000_001)
        #expect(roundTripped.minX == box.minX)
        #expect(roundTripped.size == box.size)
    }

    /// Renders `lines` as high-contrast black-on-white text and encodes the
    /// result as PNG `Data` — a real image Vision can run text recognition
    /// against, built without touching disk or the app bundle.
    private static func renderText(_ lines: [String], width: Int = 800, height: Int = 400) throws -> Data {
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

        context.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))

        // CoreText's own attribute keys (not NSAttributedString.Key, which
        // needs the AppKit/UIKit .font/.foregroundColor extensions this
        // cross-platform package doesn't import) so this compiles identically
        // for the macOS test destination and the iOS app.
        let font = CTFontCreateWithName("Helvetica" as CFString, 36, nil)
        let attributes = [
            kCTFontAttributeName: font,
            kCTForegroundColorAttributeName: CGColor(red: 0, green: 0, blue: 0, alpha: 1)
        ] as CFDictionary

        var lineTop = CGFloat(height) - 60
        for line in lines {
            let attributedLine = try #require(CFAttributedStringCreate(nil, line as CFString, attributes))
            let ctLine = CTLineCreateWithAttributedString(attributedLine)
            context.textPosition = CGPoint(x: 40, y: lineTop)
            CTLineDraw(ctLine, context)
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
