import CoreGraphics
import SenseBridgeCore
import SwiftUI

/// The live camera feed for hands-free awareness, with a yellow outline around
/// each object the app recognized.
///
/// Shows the same detections the narration is composed from — see
/// `AmbientAwarenessSession.detectedObjects` — so the outlines and the speech
/// can never disagree. Each outline is captioned with its label and the
/// classifier's confidence, because an unqualified box drawn around something is
/// a stronger claim than anything this app says out loud, and
/// docs/SAFETY-FRAMING.md does not allow the visual channel to assert what the
/// spoken one hedges.
///
/// **Draws frames directly rather than hosting `ARSCNView`.** Hands-free
/// awareness holds the camera through ARKit for the LiDAR depth map, so
/// `CameraPreviewView` and its `AVCaptureVideoPreviewLayer` cannot render it —
/// but a SceneKit view is the wrong replacement. Nothing here renders 3D
/// content, so it would buy nothing while expecting to own the session, drive
/// its own render loop, and live somewhere more ordinary than a `List` row.
/// A `CGImage` the session produced either appears or is visibly, explicably
/// absent; there is no third state where a renderer silently draws nothing.
struct AwarenessPreviewView: View {
    /// The most recent camera frame, upright. `nil` before the first one
    /// arrives, which is a state this view states rather than hides.
    let image: CGImage?
    /// What to outline, normalized to the upright image with a top-left origin.
    let detectedObjects: [DetectedObject]
    /// Width ÷ height of the camera image, so the view's shape matches the
    /// feed's and normalized boxes map straight onto it.
    let aspectRatio: Double

    /// How tall the feed is drawn, in points.
    ///
    /// A definite height, not an aspect ratio alone: a `List` row proposes a
    /// width but no height, so `.aspectRatio(_:contentMode:)` on its own has
    /// nothing to scale from and collapses the preview to nothing.
    /// `ReadingView` pins its preview's height for the same reason.
    private static let height: CGFloat = 320

    var body: some View {
        feed
            // The width is derived from the height and the camera's own aspect
            // ratio, so the view's shape matches the feed's exactly. Any other
            // shape would letterbox or crop, and every outline would then be
            // drawn a little off the thing it is outlining.
            .frame(width: Self.height * aspectRatio, height: Self.height)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            // Centred in the row, which is wider than the feed.
            .frame(maxWidth: .infinity)
            // A live feed and a set of boxes that move several times a second
            // have nothing usable to offer VoiceOver, and announcing each change
            // would talk over the narration that is this feature's actual
            // channel. The same labels are spoken, and mirrored as text beneath
            // this view.
            .accessibilityHidden(true)
    }

    @ViewBuilder
    private var feed: some View {
        if let image {
            // `.resizable()` with no aspect modifier is exact here, not sloppy:
            // the frame above is built from this image's own ratio, so there is
            // nothing to letterbox and nothing to crop.
            Image(decorative: image, scale: 1, orientation: .up)
                .resizable()
                .overlay { highlights }
        } else {
            // Said, not left blank. An empty rectangle is indistinguishable from
            // a camera that failed, and ARKit takes a moment to deliver its
            // first frame after the session starts.
            RoundedRectangle(cornerRadius: 12)
                .fill(.black)
                .overlay {
                    Text("Waiting for the camera…")
                        .font(.footnote)
                        .foregroundStyle(.white)
                }
        }
    }

    private var highlights: some View {
        GeometryReader { geometry in
            // Keyed by label rather than by value so a box that moves animates
            // to its new position instead of being torn down and rebuilt.
            // Labels are unique — the detector deduplicates them.
            ForEach(detectedObjects, id: \.label) { object in
                HighlightBox(object: object, in: geometry.size)
            }
        }
    }
}

/// One yellow outline and its caption, placed over the feed.
private struct HighlightBox: View {
    let object: DetectedObject
    /// The size of the preview the normalized box is being scaled onto.
    let size: CGSize

    /// Creates a highlight for `object` scaled onto a preview of `size`.
    init(object: DetectedObject, in size: CGSize) {
        self.object = object
        self.size = size
    }

    var body: some View {
        let rect = CGRect(
            x: object.boundingBox.minX * size.width,
            y: object.boundingBox.minY * size.height,
            width: object.boundingBox.width * size.width,
            height: object.boundingBox.height * size.height
        )
        RoundedRectangle(cornerRadius: 6)
            .strokeBorder(.yellow, lineWidth: 3)
            .overlay(alignment: .topLeading) { caption }
            .frame(width: rect.width, height: rect.height)
            .position(x: rect.midX, y: rect.midY)
            // Detection runs on the depth cadence, so without this the outlines
            // snap between positions several times a second.
            .animation(.easeOut(duration: 0.2), value: object.boundingBox)
    }

    /// Black on yellow — the same pairing as the outline, and the highest
    /// contrast ratio available against a feed whose brightness is unknown.
    private var caption: some View {
        Text(captionText)
            .font(.caption2.weight(.semibold))
            .foregroundStyle(.black)
            .padding(.horizontal, 4)
            .padding(.vertical, 2)
            .background(.yellow, in: RoundedRectangle(cornerRadius: 4))
            .fixedSize()
            .padding(3)
    }

    /// The label with its confidence attached. The percentage is not decoration:
    /// a box with no number beside it reads as certainty, and this app does not
    /// claim certainty about the physical world.
    private var captionText: String {
        let confidence = object.confidence.formatted(.percent.precision(.fractionLength(0)))
        return "\(object.label) · \(confidence)"
    }
}
