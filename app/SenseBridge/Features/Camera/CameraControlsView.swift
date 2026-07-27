import SenseBridgeCore
import SwiftUI

/// Lens, zoom, and torch controls for the shared camera session. Each
/// control is shown only when the hardware actually supports it — a dead
/// control (a picker with one option, a slider with no range, a toggle that
/// does nothing) is worse than an absent one for a VoiceOver user, who has
/// no visual cue that it's inert.
struct CameraControlsView: View {
    /// The shared camera controller this view drives — see `CameraController`.
    let camera: CameraController

    /// Drives the lens picker's style. A segmented control divides its fixed
    /// width by the number of options, so at accessibility text sizes the
    /// labels truncate to a letter or two and the tap targets fall below the
    /// 44pt minimum — see docs/ACCESSIBILITY.md.
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        VStack(spacing: 16) {
            if camera.availableLenses.count > 1 {
                // Branched rather than a ternary on the style: `pickerStyle`
                // is generic over a concrete style type, so the two arms have
                // no common type to unify on.
                if dynamicTypeSize.isAccessibilitySize {
                    lensPicker.pickerStyle(.menu)
                } else {
                    lensPicker.pickerStyle(.segmented)
                }
            }
            if camera.zoomRange.lowerBound < camera.zoomRange.upperBound {
                Slider(value: zoomBinding, in: camera.zoomRange)
                    .accessibilityLabel("Zoom")
                    // Spelled out, not "×". VoiceOver reads the multiplication
                    // sign as "x" — or, on some voices, skips it entirely — so
                    // "2.0×" comes out as "two point oh ex".
                    .accessibilityValue("\(String(format: "%.1f", camera.zoomFactor)) times")
            }
            if camera.isTorchAvailable {
                Toggle("Torch", isOn: torchBinding)
                    .accessibilityLabel("Torch")
                    .accessibilityHint("Turns the camera's flashlight on or off.")
            }
        }
    }

    /// The lens picker without a style applied, so the two Dynamic Type
    /// branches above share one definition instead of duplicating the options.
    private var lensPicker: some View {
        Picker("Lens", selection: lensBinding) {
            ForEach(camera.availableLenses, id: \.self) { lens in
                Text(displayName(for: lens))
                    .tag(lens)
            }
        }
        .accessibilityLabel("Lens")
        .accessibilityHint("Chooses which camera lens to capture with.")
    }

    /// Reflects `camera.currentLens`; setting it drives a `select(lens:)`
    /// call, since `CameraController`'s state is `private(set)`.
    private var lensBinding: Binding<CameraLens> {
        Binding(
            get: { camera.currentLens },
            set: { newValue in
                Task { await camera.select(lens: newValue) }
            }
        )
    }

    /// Reflects `camera.zoomFactor`; setting it drives a `setZoom(_:)` call.
    /// No `Task` here — `setZoom` is synchronous and coalesces the drag
    /// itself, precisely so this setter doesn't spawn one task per tick.
    private var zoomBinding: Binding<Double> {
        Binding(
            get: { camera.zoomFactor },
            set: { newValue in
                camera.setZoom(newValue)
            }
        )
    }

    /// Reflects `camera.isTorchOn`; setting it drives a `setTorch(_:)` call.
    private var torchBinding: Binding<Bool> {
        Binding(
            get: { camera.isTorchOn },
            set: { newValue in
                Task { await camera.setTorch(newValue) }
            }
        )
    }

    /// Display name for `lens`, shown in the segmented picker. Lives in the
    /// App layer, not `CameraLens` itself — see that type's doc comment.
    private func displayName(for lens: CameraLens) -> LocalizedStringKey {
        switch lens {
        case .ultraWide: "Ultra-wide"
        case .wide: "Wide"
        case .telephoto: "Telephoto"
        }
    }
}
