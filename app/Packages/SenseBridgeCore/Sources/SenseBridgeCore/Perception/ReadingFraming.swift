import CoreGraphics
import Foundation

/// Turns where text landed on the frame into the one sentence that helps a
/// listener aim the camera.
///
/// This is the part of live reading that does the actual work. A sighted user
/// aims a phone at a page by looking at the preview and adjusting; a blind user
/// has no preview, so without this they aim by capturing, listening to a
/// partial result, and guessing — which is what made the previous single-photo
/// Read screen so hard to use on anything larger than a pill bottle.
///
/// ## Everything here is a claim about recognition, never about the page
///
/// "Text may continue past the top" says a recognized line touched the frame
/// edge, which is a fact about this app's own output. The tempting phrasing —
/// "the top of the page is cut off" — is a claim about a physical document the
/// app cannot see the edges of, and `docs/SAFETY-FRAMING.md` treats that class
/// of statement the same way it treats naming an object wrongly. Likewise
/// ``Guidance/noTextRecognized`` is never "the page is blank": an absence the
/// app inferred from one frame is not an absence it observed.
///
/// Pure functions over normalized rectangles, free of Vision, so every
/// threshold below is verifiable without a camera.
public enum ReadingFraming {
    /// Which side of the frame recognized text ran into.
    ///
    /// Named for what the *user* would turn toward, in the upright image's own
    /// terms, so a caller never has to reason about the camera's landscape
    /// origin.
    public enum Edge: String, Sendable, Equatable, CaseIterable {
        case top, bottom, leading, trailing
    }

    /// What to tell the listener about how the camera is aimed.
    public enum Guidance: Sendable, Equatable {
        /// Recognition ran and produced nothing. Distinct from every other
        /// case because it is the only one carrying no information about the
        /// page at all — see the type's note on never asserting a blank page.
        case noTextRecognized
        /// Text was recognized, and lines ran into these frame edges. Never
        /// empty; the empty case is ``wellFramed``.
        case textRunsPastEdges(Set<Edge>)
        /// Text was recognized but is small enough that recognition quality is
        /// likely suffering.
        case textLooksSmall
        /// Text was recognized, sits clear of every edge, and is large enough.
        case wellFramed
    }

    /// How close to an edge, in normalized units, a line must come before it
    /// counts as running into it.
    ///
    /// 1.5% of the frame. Vision's boxes are generous — a box hugs its glyphs
    /// with a little padding — so a strict `== 0` test would essentially never
    /// fire, and anything much wider reports a cut-off page for text that is
    /// merely near the margin.
    public static let edgeTolerance: CGFloat = 0.015

    /// The line height, as a fraction of frame height, below which text is
    /// called small.
    ///
    /// 2.2% of the frame. Below roughly this, Vision's accurate recognizer
    /// starts dropping candidates and inventing others on ordinary print, which
    /// is the failure this warning exists to pre-empt — a listener told to move
    /// closer gets a better read than one handed a plausible wrong word.
    public static let smallTextHeight: CGFloat = 0.022

    /// The guidance for one frame's recognized lines.
    ///
    /// - Parameter lines: Recognized lines with top-left-origin normalized
    ///   boxes, as `OCRService` produces them. Order is irrelevant.
    /// - Returns: The single most useful thing to say. Ordered by what blocks
    ///   the read most: nothing recognized, then text leaving the frame, then
    ///   text too small — a listener acts on one instruction at a time, and
    ///   stacking three of them into one utterance is how spoken guidance stops
    ///   being followed.
    public static func guidance(for lines: [RecognizedTextLine]) -> Guidance {
        guard !lines.isEmpty else { return .noTextRecognized }
        let edges = edgesRunPast(by: lines)
        if !edges.isEmpty {
            return .textRunsPastEdges(edges)
        }
        if looksSmall(lines) {
            return .textLooksSmall
        }
        return .wellFramed
    }

    /// Which frame edges any recognized line reaches.
    ///
    /// A **union** across lines rather than a per-line answer: a page wider and
    /// taller than the frame runs past two edges at once, and reporting only
    /// the first would have the listener fix one and re-discover the other.
    ///
    /// Degenerate boxes — zero-width, zero-height, non-finite — are skipped
    /// rather than measured. A `nan` origin compares `false` against every
    /// threshold, so it would silently contribute nothing anyway; skipping it
    /// explicitly means that behaviour is intended rather than incidental.
    public static func edgesRunPast(by lines: [RecognizedTextLine]) -> Set<Edge> {
        var edges = Set<Edge>()
        for box in lines.map(\.boundingBox) where isUsable(box) {
            if box.minY <= edgeTolerance {
                edges.insert(.top)
            }
            if box.maxY >= 1 - edgeTolerance {
                edges.insert(.bottom)
            }
            if box.minX <= edgeTolerance {
                edges.insert(.leading)
            }
            if box.maxX >= 1 - edgeTolerance {
                edges.insert(.trailing)
            }
        }
        return edges
    }

    /// Whether the recognized text is small enough to be worth mentioning.
    ///
    /// Judged on the **median** line height, not the mean and not the smallest.
    /// A page of body text with one footnote should not be called small, and the
    /// mean is dragged around by a single heading; the median is what most of
    /// the page actually looks like.
    public static func looksSmall(_ lines: [RecognizedTextLine]) -> Bool {
        let heights = lines
            .map(\.boundingBox)
            .filter(isUsable)
            .map(\.height)
            .sorted()
        guard !heights.isEmpty else { return false }
        return heights[heights.count / 2] < smallTextHeight
    }

    /// Whether a box carries a real measurement.
    ///
    /// Guards every threshold comparison above against the two things a
    /// bounding box can be when something upstream went wrong: non-finite, or
    /// collapsed to a point.
    private static func isUsable(_ box: CGRect) -> Bool {
        box.origin.x.isFinite && box.origin.y.isFinite
            && box.width.isFinite && box.height.isFinite
            && box.width > 0 && box.height > 0
    }
}
