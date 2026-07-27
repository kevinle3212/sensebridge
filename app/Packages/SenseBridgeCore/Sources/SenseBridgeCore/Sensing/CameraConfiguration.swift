import Foundation

/// Pure zoom-factor math for a virtual multi-lens camera, extracted out of
/// `CameraSource` so it unit-tests without a device — the same reason
/// `SpeechRenderTarget.selectVoiceLanguage(for:availableLanguages:)` is a
/// standalone function rather than inline logic. Every function here takes
/// plain values, never an `AVFoundation` type, so tests need no hardware.
public enum CameraConfiguration {
    /// Maps each constituent lens of a virtual multi-camera device to the
    /// `videoZoomFactor` that selects it.
    ///
    /// On a virtual device, `videoZoomFactor == 1.0` always selects the
    /// *widest* constituent lens, not a fixed physical lens — a
    /// `.builtInTripleCamera` and a `.builtInDualCamera` both report `1.0` for
    /// their first constituent, but that constituent is `.ultraWide` on one
    /// and `.wide` on the other. `switchOverFactors` (from
    /// `AVCaptureDevice.virtualDeviceSwitchOverVideoZoomFactors`) gives the
    /// zoom factor at which the device hands off from constituent `i` to
    /// constituent `i + 1`, so constituent `i + 1`'s factor is
    /// `switchOverFactors[i]`.
    ///
    /// `switchOverFactors` comes from the OS and is defensively treated as
    /// untrusted: a length mismatch against `constituents` (one shorter than
    /// expected, per Apple's documented invariant, or otherwise malformed)
    /// degrades to omitting the affected lenses from the result rather than
    /// crashing.
    public static func zoomFactors(
        constituents: [CameraLens],
        switchOverFactors: [Double]
    ) -> [CameraLens: Double] {
        guard let widest = constituents.first else { return [:] }
        var factors: [CameraLens: Double] = [widest: 1.0]
        for index in 1 ..< constituents.count {
            guard index - 1 < switchOverFactors.count else { break }
            factors[constituents[index]] = switchOverFactors[index - 1]
        }
        return factors
    }

    /// Clamps a requested zoom factor into the device's supported range.
    /// Defends against a malformed (inverted) range by returning `min`
    /// rather than crashing or returning an out-of-range value.
    public static func clampZoom(_ requested: Double, min: Double, max: Double) -> Double {
        guard min <= max else { return min }
        return Swift.min(Swift.max(requested, min), max)
    }
}
