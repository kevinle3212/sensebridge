import CoreGraphics
import CoreText
import Foundation
import ImageIO
import SenseBridgeCore
import UniformTypeIdentifiers
import Vision

/// AI evaluation harness — docs/TESTING.md's "AI evaluation" row.
///
/// Runs synthetic fixtures through the real perception services and the real
/// `LabelListSceneComposer`, then runs every composed sentence through
/// `ReasoningOutputValidator` — the same validator that gates network
/// composers at runtime — so an over-confident or hallucinated claim shows up
/// as a flagged rejection instead of passing silently. The network composers
/// are deliberately not exercised here: their wire contract forbids sending
/// anything but object labels off-device, and this harness is where the fully
/// local path gets eyeballed.
///
/// Fixtures are DRAWN, not committed binaries: each case renders its image at
/// run time with CoreGraphics, so the repo carries no test media and a case
/// can never drift from its description. Run:
///
///     swift run --package-path app/Packages/SenseBridgeCore eval-harness
///
/// or `npm run eval` from the repository root.
@main
enum EvalHarness {
    /// One synthetic scene: how to draw it, which sensor streams to inject,
    /// and the soft text keywords an eyeball review starts from.
    ///
    /// Property order matches the case list's argument order, so the
    /// memberwise initializer takes the drawing closure as its trailing
    /// argument. Computed rather than stored: a `static let` of non-Sendable
    /// closures is a global-mutable-state error under Swift 6.
    struct Case {
        let name: String
        let size: CGSize
        /// Sound events as (`SoundAnalysis`-style label, confidence) pairs,
        /// standing in for what `SoundClassificationRunner` would stream in.
        let sounds: [(label: String, confidence: Double)]
        let expectedTextKeywords: [String]
        let draw: (CGContext, CGSize) -> Void
    }

    static func main() async {
        print("SenseBridge AI evaluation harness")
        print("=================================")

        let phrasing = Phrasing()
        let locale = Locale(identifier: "en")
        var hardFailures = 0

        for testCase in cases {
            print("\n--- \(testCase.name) ---")
            let passed = await processCase(testCase, phrasing: phrasing, locale: locale)
            if !passed {
                hardFailures += 1
            }
        }

        print("\n--- deliberate over-claim probe ---")
        validate(deliberateOverClaim, labelCount: 2, locale: locale)

        print(hardFailures == 0 ? "\nREPORT COMPLETE (no hard failures)" :
            "\nREPORT COMPLETE WITH \(hardFailures) HARD FAILURE(S)")
        if hardFailures > 0 {
            exit(1)
        }
    }

    /// Renders, perceives, composes, and validates one fixture case.
    ///
    /// Returns `false` only on a HARD FAIL — the pipeline itself misbehaved —
    /// as opposed to the SOFT MISS lines an eyeball review starts from or the
    /// deliberate OVERCLAIM probe at the end of the report.
    static func processCase(_ testCase: Case, phrasing: Phrasing, locale: Locale) async -> Bool {
        guard let png = render(testCase) else {
            print("HARD FAIL: could not render fixture image")
            return false
        }

        do {
            let textRecords = try await OCRService().process(png)
            let objects = try await ObjectClassificationService().detect(png)

            var records = textRecords
            for object in objects {
                records.append(PerceptionRecord(
                    kind: .detectedObject(label: object.label, confidence: object.confidence),
                    capturedAt: .now
                ))
            }
            for sound in testCase.sounds {
                records.append(PerceptionRecord(
                    kind: .detectedSound(label: sound.label, confidence: sound.confidence),
                    capturedAt: .now
                ))
            }

            reportText(textRecords, expecting: testCase.expectedTextKeywords)
            print("detected objects (\(objects.count)):")
            for object in objects {
                print("  \(object.label) — confidence \(String(format: "%.2f", object.confidence))")
            }
            print("injected sounds (\(testCase.sounds.count)):")
            for sound in testCase.sounds {
                print("  \(sound.label) — confidence \(String(format: "%.2f", sound.confidence))")
            }

            let composer = LabelListSceneComposer(phrasing: phrasing, locale: locale, detail: .standard)
            let composed = try await composer.compose(from: records)
            print("composed: \"\(composed)\"")
            validate(composed, labelCount: objects.count + testCase.sounds.count, locale: locale)

            return hedged(composed, phrasing: phrasing, locale: locale)
        } catch {
            print("HARD FAIL: \(error)")
            return false
        }
    }

    /// Prints what OCR recognized, flagging lines none of whose expected
    /// keywords matched — a SOFT MISS, i.e. where an eyeball review starts.
    static func reportText(_ records: [PerceptionRecord], expecting keywords: [String]) {
        print("recognized text (\(records.count)):")
        for record in records {
            guard case let .recognizedText(line) = record.kind else { continue }
            print("  \"\(line)\"")
            if !keywords.contains(where: { line.localizedCaseInsensitiveContains($0) }) {
                print("  SOFT MISS: none of \(keywords) matched this line")
            }
        }
        if records.isEmpty, !keywords.isEmpty {
            print("SOFT MISS: expected text \(keywords), OCR found nothing")
        }
    }

    /// Doctrine spot-check: whatever was composed must carry one of the app's
    /// own hedges from the modality it speaks — the composer has nowhere else
    /// to get its verbs.
    static func hedged(_ phrase: String, phrasing: Phrasing, locale: Locale) -> Bool {
        let lowered = phrase.lowercased()
        let fragments = (Phrasing.hedgeFragments(locale: locale) + Phrasing.soundHedgeFragments(locale: locale))
            .map { $0.lowercased() }
            .filter { !$0.isEmpty }
        let carried = fragments.contains { lowered.contains($0) }
        if !carried, phrase != phrasing.nothingRecognized(locale: locale) {
            print("HARD FAIL: composed sentence carries no hedge fragment")
            return false
        }
        return true
    }

    /// Runs one composed phrase through the runtime validator and reports the
    /// outcome as the eval row.
    ///
    /// The validator's SHAPE rules (single short noun phrase, no sentence
    /// punctuation) exist to gate remote composer responses, so a locally
    /// composed multi-sentence description legitimately fails them — that is
    /// reported as a shape note, not an overclaim. Its CONTENT rules are the
    /// doctrine: certainty the labels did not earn, distance/direction/safety
    /// terms, numerals, or a hedge the model invented. Only content
    /// rejections are flagged OVERCLAIM here.
    static func validate(_ phrase: String, labelCount: Int, locale: Locale) {
        let validator = ReasoningOutputValidator(
            maximumWords: SpokenDetail.standard.maximumPhraseWords(labelCount: labelCount)
        )
        do {
            _ = try validator.validate(phrase, locale: locale)
            print("validator: accepted")
        } catch ReasoningOutputValidationError.empty,
            ReasoningOutputValidationError.tooLong,
            ReasoningOutputValidationError.containsSentencePunctuationOrNewline {
            print("shape note: rejected by a phrase-shape rule (expected for local multi-sentence output)")
        } catch {
            print("OVERCLAIM flagged by ReasoningOutputValidator: \(error)")
        }
    }

    // --- rendering -----------------------------------------------------------

    /// Renders a case to PNG data, drawing at run time so no binary fixture
    /// ever enters the repository.
    static func render(_ testCase: Case) -> Data? {
        let size = testCase.size
        guard let space = CGColorSpace(name: CGColorSpace.sRGB) else { return nil }
        guard let ctx = CGContext(
            data: nil,
            width: Int(size.width),
            height: Int(size.height),
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: space,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return nil }

        // Flip into a top-left-origin space so case coordinates read like the
        // app's own geometry instead of CoreGraphics' bottom-left one.
        ctx.translateBy(x: 0, y: size.height)
        ctx.scaleBy(x: 1, y: -1)
        testCase.draw(ctx, size)

        guard let image = ctx.makeImage() else { return nil }
        let mutable = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(
            mutable, UTType.png.identifier as CFString, 1, nil
        ) else { return nil }
        CGImageDestinationAddImage(destination, image, nil)
        guard CGImageDestinationFinalize(destination) else { return nil }
        return mutable as Data
    }

    static func fillWhite(_ ctx: CGContext, _ size: CGSize) {
        ctx.setFillColor(CGColor(gray: 1, alpha: 1))
        ctx.fill(CGRect(origin: .zero, size: size))
    }

    /// Draws one centered text run with CoreText, in the flipped coordinate
    /// space `render(_:)` sets up.
    static func drawText(_ string: String, size: CGFloat, centeredIn rect: CGRect, ctx: CGContext) {
        let font = CTFontCreateWithName("Helvetica Bold" as CFString, size, nil)
        // CoreText attribute keys — the Foundation aliases don't exist without
        // AppKit/UIKit, which this device-agnostic package target avoids.
        let attributes: [CFString: Any] = [
            kCTFontAttributeName: font,
            kCTForegroundColorAttributeName: CGColor(gray: 0, alpha: 1)
        ]
        guard let attributed = CFAttributedStringCreate(nil, string as CFString, attributes as CFDictionary) else {
            return
        }
        let line = CTLineCreateWithAttributedString(attributed)
        let width = CTLineGetTypographicBounds(line, nil, nil, nil)
        let ascent = CTFontGetAscent(font)
        let descent = CTFontGetDescent(font)
        ctx.textPosition = CGPoint(
            x: rect.midX - width / 2,
            y: rect.midY - (ascent - descent) / 2
        )
        CTLineDraw(line, ctx)
    }
}

/// The case table and the over-claim probe live in an extension so neither
/// type body crosses SwiftLint's line ceiling; same type, so call sites stay
/// unqualified.
extension EvalHarness {
    /// One synthetic scene per fixture: what to draw, which sensor streams to
    /// inject, and the soft text keywords an eyeball review starts from.
    static var cases: [Case] {
        [
            Case(
                name: "exit-sign",
                size: CGSize(width: 800, height: 500),
                sounds: [],
                expectedTextKeywords: ["EXIT", "FLOOR"]
            ) { ctx, size in
                fillWhite(ctx, size)
                drawText("EXIT", size: 140, centeredIn: CGRect(x: 0, y: 280, width: size.width, height: 160), ctx: ctx)
                drawText(
                    "FLOOR 3",
                    size: 72,
                    centeredIn: CGRect(x: 0, y: 120, width: size.width, height: 100),
                    ctx: ctx
                )
            },
            Case(
                name: "menu-and-mug",
                size: CGSize(width: 800, height: 600),
                sounds: [("speech", 0.62)],
                expectedTextKeywords: ["MENU"]
            ) { ctx, size in
                fillWhite(ctx, size)
                drawText("MENU", size: 110, centeredIn: CGRect(x: 0, y: 430, width: size.width, height: 140), ctx: ctx)
                drawText(
                    "COFFEE  TEA",
                    size: 54,
                    centeredIn: CGRect(x: 0, y: 330, width: size.width, height: 80),
                    ctx: ctx
                )
                // A mug-shaped silhouette: body plus handle. What the classifier
                // makes of it is exactly the kind of thing this report exists to
                // be eyeballed for, so no expectation is asserted.
                ctx.setFillColor(CGColor(gray: 0.15, alpha: 1))
                ctx.fill(CGRect(x: 300, y: 60, width: 160, height: 200))
                ctx.setStrokeColor(CGColor(gray: 0.15, alpha: 1))
                ctx.setLineWidth(26)
                ctx.strokeEllipse(in: CGRect(x: 440, y: 105, width: 110, height: 110))
            },
            Case(
                name: "cluttered-shapes",
                size: CGSize(width: 800, height: 600),
                sounds: [("alarm", 0.91)],
                expectedTextKeywords: []
            ) { ctx, size in
                fillWhite(ctx, size)
                ctx.setFillColor(CGColor(gray: 0.35, alpha: 1))
                ctx.fill(CGRect(x: 120, y: 340, width: 380, height: 220)) // monitor-like slab
                ctx.fill(CGRect(x: 260, y: 300, width: 100, height: 40)) // stand
                ctx.setFillColor(CGColor(gray: 0.55, alpha: 1))
                ctx.fill(CGRect(x: 180, y: 120, width: 440, height: 70)) // keyboard-like slab
                ctx.fill(CGRect(x: 620, y: 150, width: 130, height: 240)) // tower-like slab
            }
        ]
    }

    /// A deliberately over-claiming composition — certainty language plus a
    /// direction word and a safety word, short enough to pass the validator's
    /// shape rules so its CONTENT rejection is what gets exercised.
    static let deliberateOverClaim = "definitely a chair on the left, safe ahead"
}
