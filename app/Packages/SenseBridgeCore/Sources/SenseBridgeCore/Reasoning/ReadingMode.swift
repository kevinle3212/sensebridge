import Foundation

/// How the Read screen gets text: one deliberate capture, or continuously.
///
/// Persisted rather than reset per visit. The two modes suit different tasks —
/// a pill bottle wants one careful capture, a menu wants sweeping the camera
/// across it — and which one a given person mostly does is stable. Making a
/// blind user re-select their usual mode on every launch is a swipe and a tap
/// they pay for every single time, to save storing one string.
public enum ReadingMode: String, Sendable, Codable, CaseIterable {
    /// One photo, flattened if it is a page, then read end to end. The higher
    /// quality read: the recognizer runs with language correction on a still the
    /// user framed and held.
    case capture
    /// Text read continuously from the live feed, with aiming guidance. Lower
    /// per-frame quality by design — see `OCRService.recognize(_:orientation:)`
    /// on why language correction is off — and far better for finding text in
    /// the first place.
    case live
}
