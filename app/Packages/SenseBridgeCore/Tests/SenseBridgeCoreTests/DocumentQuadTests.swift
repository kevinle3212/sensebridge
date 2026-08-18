import CoreGraphics
import Testing
@testable import SenseBridgeCore

struct DocumentQuadTests {
    /// An axis-aligned quad covering `side` × `side` of the frame, anchored at
    /// the origin.
    private func quad(side: CGFloat) -> DocumentQuad {
        DocumentQuad(
            topLeft: CGPoint(x: 0, y: side),
            topRight: CGPoint(x: side, y: side),
            bottomLeft: .zero,
            bottomRight: CGPoint(x: side, y: 0)
        )
    }

    @Test
    func measuresAnAxisAlignedQuadAsItsRectangleArea() {
        #expect(quad(side: 1).area == 1)
        #expect(abs(quad(side: 0.5).area - 0.25) < 0.0001)
    }

    @Test
    func measuresTheSameAreaWhicheverWayTheCornersWind() {
        // A detector is free to hand back corners in either winding order, and a
        // signed area would reject half of them as negative.
        let clockwise = quad(side: 0.8)
        let counterClockwise = DocumentQuad(
            topLeft: clockwise.topRight,
            topRight: clockwise.topLeft,
            bottomLeft: clockwise.bottomRight,
            bottomRight: clockwise.bottomLeft
        )

        #expect(abs(counterClockwise.area - clockwise.area) < 0.0001)
    }

    @Test
    func measuresATrapezoidRatherThanItsBoundingBox() {
        // The shape a page photographed at an angle actually makes.
        let trapezoid = DocumentQuad(
            topLeft: CGPoint(x: 0.2, y: 1.0),
            topRight: CGPoint(x: 0.8, y: 1.0),
            bottomLeft: .zero,
            bottomRight: CGPoint(x: 1.0, y: 0.0)
        )

        // (0.6 + 1.0) / 2 × 1.0 = 0.8, not the 1.0 its bounding box would give.
        #expect(abs(trapezoid.area - 0.8) < 0.0001)
    }

    @Test
    func acceptsAQuadCoveringEnoughOfTheFrameToBeThePageInFront() {
        #expect(quad(side: 0.5).isPlausiblePage)
        #expect(quad(side: 1.0).isPlausiblePage)
    }

    @Test
    func rejectsASmallQuadBecauseItIsMoreLikelyASignAcrossTheRoom() {
        // Correcting the perspective of a distant rectangle crops away the text
        // the user aimed at — a worse failure than not correcting at all.
        #expect(!quad(side: 0.4).isPlausiblePage)
    }

    @Test
    func rejectsADegenerateQuadWhoseCornersCollapsedTogether() {
        let collapsed = DocumentQuad(
            topLeft: .zero, topRight: .zero, bottomLeft: .zero, bottomRight: .zero
        )

        #expect(collapsed.area == 0)
        #expect(!collapsed.isPlausiblePage)
    }

    @Test
    func rejectsNonFiniteCornersRatherThanMeasuringThem() {
        // What a tracker hands back on the frame it loses the page.
        let broken = DocumentQuad(
            topLeft: CGPoint(x: CGFloat.nan, y: 1),
            topRight: CGPoint(x: 1, y: CGFloat.infinity),
            bottomLeft: .zero,
            bottomRight: CGPoint(x: 1, y: 0)
        )

        #expect(broken.area == 0)
        #expect(!broken.isPlausiblePage)
    }

    @Test
    func treatsTheCoverageThresholdAsInclusive() {
        // Exactly at the threshold is accepted, so the constant reads as the
        // smallest allowed coverage rather than the largest rejected one.
        let side = DocumentQuad.minimumFrameCoverage.squareRoot()

        #expect(quad(side: side).isPlausiblePage)
    }
}
