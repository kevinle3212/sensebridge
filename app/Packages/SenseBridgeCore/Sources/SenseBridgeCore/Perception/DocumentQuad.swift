import CoreGraphics
import Foundation

/// The four corners of a page found in a frame, normalized with Vision's
/// bottom-left origin.
///
/// Split out from the Vision request that produces it so the two questions that
/// actually have answers worth testing — "is this quadrilateral a plausible
/// page?" and "how much of the frame does it cover?" — are answerable without a
/// camera. Vision's observation types cannot be constructed in a test, which is
/// the same constraint that shaped `OCRService.inReadingOrder`.
public struct DocumentQuad: Sendable, Equatable {
    public let topLeft: CGPoint
    public let topRight: CGPoint
    public let bottomLeft: CGPoint
    public let bottomRight: CGPoint

    /// Creates a quad from four normalized corners, bottom-left origin.
    public init(topLeft: CGPoint, topRight: CGPoint, bottomLeft: CGPoint, bottomRight: CGPoint) {
        self.topLeft = topLeft
        self.topRight = topRight
        self.bottomLeft = bottomLeft
        self.bottomRight = bottomRight
    }

    /// The smallest fraction of the frame a quad must cover to be treated as a
    /// page rather than as a rectangular *thing* in the scene.
    ///
    /// A quarter of the frame. Below that, the detector is usually outlining a
    /// sign, a screen, or a book on a table several feet away — correcting the
    /// perspective of one of those crops away the text the user actually aimed
    /// at, which is a worse failure than not correcting at all.
    public static let minimumFrameCoverage: CGFloat = 0.25

    /// Whether this quad is worth correcting the perspective of.
    ///
    /// Three ways it can fail, all seen in practice from a real detector:
    /// a non-finite corner (a frame the tracker lost), a degenerate shape with
    /// near-zero area (two corners collapsed together), and a quad too small to
    /// be the page in front of the user. Rejecting here rather than downstream
    /// keeps the correction filter from producing a plausible-looking image of
    /// the wrong thing, which is the outcome a listener has no way to notice.
    public var isPlausiblePage: Bool {
        guard corners.allSatisfy({ $0.x.isFinite && $0.y.isFinite }) else { return false }
        return area >= Self.minimumFrameCoverage
    }

    /// The four corners, in a fixed order for iteration.
    public var corners: [CGPoint] {
        [topLeft, topRight, bottomRight, bottomLeft]
    }

    /// The fraction of the frame this quad covers.
    ///
    /// The shoelace formula over the corners in perimeter order, absolute-valued
    /// so a quad whose corners wind the other way still measures positive rather
    /// than reporting a negative area that fails every threshold. Exact for any
    /// simple quadrilateral, which a page always is; a self-intersecting one
    /// under-reports and is correctly rejected as implausible.
    public var area: CGFloat {
        let points = corners
        guard points.allSatisfy({ $0.x.isFinite && $0.y.isFinite }) else { return 0 }
        var total: CGFloat = 0
        for index in points.indices {
            let current = points[index]
            let next = points[(index + 1) % points.count]
            total += current.x * next.y - next.x * current.y
        }
        return abs(total) / 2
    }
}
