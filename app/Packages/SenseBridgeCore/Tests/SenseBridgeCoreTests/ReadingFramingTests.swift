import CoreGraphics
import Testing
@testable import SenseBridgeCore

struct ReadingFramingTests {
    /// A line box well clear of every edge, at a comfortable size.
    private func line(
        originX: CGFloat = 0.2,
        originY: CGFloat = 0.4,
        width: CGFloat = 0.5,
        height: CGFloat = 0.05
    ) -> RecognizedTextLine {
        RecognizedTextLine(
            text: "text",
            confidence: 0.9,
            boundingBox: CGRect(x: originX, y: originY, width: width, height: height)
        )
    }

    @Test
    func reportsNothingRecognizedForAnEmptyFrame() {
        // Never "the page is blank": an absence inferred from one frame is not
        // an absence the app observed. See docs/SAFETY-FRAMING.md.
        #expect(ReadingFraming.guidance(for: []) == .noTextRecognized)
    }

    @Test
    func reportsWellFramedWhenTextSitsClearOfEveryEdge() {
        #expect(ReadingFraming.guidance(for: [line(), line(originY: 0.5)]) == .wellFramed)
    }

    @Test
    func namesTheEdgeTextRunsPast() {
        let guidance = ReadingFraming.guidance(for: [line(), line(originY: 0.001)])

        #expect(guidance == .textRunsPastEdges([.top]))
    }

    @Test
    func unionsEveryEdgeSoOneFixDoesNotRevealAnother() {
        // A page wider and taller than the frame runs past two edges at once.
        let guidance = ReadingFraming.guidance(for: [
            line(originX: 0.0, originY: 0.0, width: 1.0, height: 0.2),
            line(originX: 0.4, originY: 0.9, width: 0.5, height: 0.11)
        ])

        #expect(guidance == .textRunsPastEdges([.top, .bottom, .leading, .trailing]))
    }

    @Test
    func edgesTakePrecedenceOverSmallText() {
        // A listener acts on one instruction at a time, and text leaving the
        // frame blocks the read harder than text merely being small.
        let guidance = ReadingFraming.guidance(for: [line(originY: 0.0, height: 0.005)])

        #expect(guidance == .textRunsPastEdges([.top]))
    }

    @Test
    func reportsSmallTextFromTheMedianRatherThanTheSmallestLine() {
        // A page of body text with one footnote should not be called small.
        let body = (0 ..< 5).map { index in line(originY: 0.3 + CGFloat(index) * 0.06, height: 0.05) }
        let footnote = line(originY: 0.8, height: 0.005)

        #expect(ReadingFraming.guidance(for: body + [footnote]) == .wellFramed)
    }

    @Test
    func reportsSmallTextWhenMostOfThePageIsSmall() {
        let tiny = (0 ..< 5).map { index in line(originY: 0.3 + CGFloat(index) * 0.02, height: 0.008) }

        #expect(ReadingFraming.guidance(for: tiny) == .textLooksSmall)
    }

    @Test
    func skipsDegenerateAndNonFiniteBoxesRatherThanMeasuringThem() {
        let broken = [
            RecognizedTextLine(
                text: "a", confidence: 1,
                boundingBox: CGRect(x: CGFloat.nan, y: .nan, width: 1, height: 1)
            ),
            RecognizedTextLine(text: "b", confidence: 1, boundingBox: CGRect(x: 0.5, y: 0.5, width: 0, height: 0))
        ]

        // Non-empty input, so not `.noTextRecognized`; nothing measurable, so
        // no edge and no small-text claim either.
        #expect(ReadingFraming.edgesRunPast(by: broken).isEmpty)
        #expect(!ReadingFraming.looksSmall(broken))
        #expect(ReadingFraming.guidance(for: broken) == .wellFramed)
    }

    @Test
    func toleranceIsWideEnoughForVisionsPaddingAndNarrowEnoughForAMargin() {
        // Just inside the tolerance counts as running past; comfortably clear
        // of it does not.
        #expect(ReadingFraming.edgesRunPast(by: [line(originY: ReadingFraming.edgeTolerance / 2)]) == [.top])
        #expect(ReadingFraming.edgesRunPast(by: [line(originY: ReadingFraming.edgeTolerance * 3)]).isEmpty)
    }
}
