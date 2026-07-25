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

    @Test
    func throwsOnInvalidImageData() async {
        await #expect(throws: OCRError.invalidImageData) {
            _ = try await OCRService().process(Data("not an image".utf8))
        }
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
