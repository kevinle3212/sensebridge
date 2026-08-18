import SenseBridgeCore
import SwiftUI

/// A high-contrast, Dynamic-Type-aware transcript of the current output.
///
/// `safeAreaInset` places this beneath the feature content instead of floating
/// over controls. It shows exactly when the active profile asks for the
/// `.caption` channel — the same condition `MultiRenderTarget` uses to decide
/// delivery, rather than a second hardcoded list of profiles that would drift
/// out of step with it and route text to a target nothing on screen displays.
struct CaptionOverlay: View {
    @Environment(AppEnvironment.self) private var environment

    /// How tall the caption may grow before it scrolls instead. Scaled with
    /// the body font so the cap rises with Dynamic Type rather than clipping
    /// large text sooner, and capped at all because an unbounded caption at an
    /// accessibility text size can squeeze the feature it captions off screen.
    @ScaledMetric(relativeTo: .body) private var maximumHeight: CGFloat = 160

    var body: some View {
        if environment.settings.outputProfile.preferredChannels.contains(.caption),
           let text = environment.captions.text {
            // Scrolls past the cap rather than truncating: on a profile whose
            // only channel is this one, a dropped tail is a dropped result.
            ViewThatFits(in: .vertical) {
                caption(text)
                ScrollView(.vertical) { caption(text) }
            }
            .frame(maxWidth: .infinity, maxHeight: maximumHeight, alignment: .leading)
            .padding()
            .background(.black, in: RoundedRectangle(cornerRadius: 12))
            .accessibilityElement(children: .combine)
            .accessibilityLabel(Text("Caption: \(Text(text))"))
        }
    }

    /// The caption body itself, built twice so `ViewThatFits` can choose
    /// between the unscrolled and scrolled arrangements of the same text.
    private func caption(_ text: String) -> some View {
        Text(text)
            .font(.body)
            .foregroundStyle(.yellow)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}
