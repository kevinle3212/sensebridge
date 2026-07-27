import Foundation

/// A camera on the device, named by field of view rather than by
/// `AVCaptureDevice.DeviceType`, so the Reasoning and App layers can talk
/// about lenses without importing AVFoundation — see docs/ARCHITECTURE.md
/// "Sensing Layer".
///
/// Case order is widest to narrowest field of view, and UI that lists lenses
/// relies on it. Raw values are a persisted storage format (`Settings`
/// carries a preferred lens), so renaming a case silently discards a user's
/// saved preference; add cases, never rename them.
///
/// Display names deliberately live in the App layer, not here: this package's
/// String Catalog holds only the doctrine-pinned spoken strings governed by
/// docs/SAFETY-FRAMING.md, and lens names are UI chrome rather than
/// physical-world claims.
public enum CameraLens: String, Sendable, Equatable, Codable, CaseIterable {
    /// The widest field of view — more of the scene, less detail per subject.
    case ultraWide

    /// The default lens, and the only one on single-camera iPhones.
    case wide

    /// The narrowest field of view — more detail on a distant subject.
    case telephoto
}
