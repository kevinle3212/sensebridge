import Foundation
import os

/// The app's `Logger` instances, one per pipeline stage.
///
/// SenseBridge shipped with no logging at all until 2026-08-18, which meant a
/// failure in the field left nothing behind: the one thing a blind user can
/// report is "it went quiet", and that sentence is equally consistent with a
/// crashed session, a thermal throttle, a denied permission, and a genuinely
/// silent room. These loggers exist to make those four distinguishable in a
/// sysdiagnose, and for nothing else.
///
/// ## The privacy rule, and why it is stated backwards from the obvious
///
/// `docs/PRIVACY.md` forbids recognized content — OCR text, image content,
/// audio content — from leaving the device. `OSLog` is a sink like any other,
/// so the rule applies here in full.
///
/// The intuitive worry is that logged *strings* leak. They are in fact the safe
/// case: a `Logger` string interpolation defaults to `.private` and renders as
/// `<private>` in a sysdiagnose collected from a release build.
///
/// The real exposure is the opposite. **Numerics, booleans, and raw enum values
/// default to `.public`**, on the assumption that a number cannot identify
/// anyone. In this app that assumption is wrong: an OCR confidence score, a
/// detected-object class index, a proximity band, or a recognized-text
/// character count are all numeric, all derived from what the camera saw, and
/// all would be written to the log in the clear by default.
///
/// So the rule this package enforces is:
///
/// - **Every interpolated value carries an explicit `privacy:` label.** No
///   exceptions, including for values that look obviously harmless. The
///   `loggingCallSitesDeclarePrivacyExplicitly` test in
///   `AppLogPrivacyTests` fails the build otherwise, and it is deliberately
///   blunt: an explicit `.public` on a value that genuinely is public is a
///   decision a reviewer can see, whereas a missing label is invisible.
/// - **Anything derived from perception output is `.private`**, or is bucketed
///   into a category with no per-observation detail before it is logged.
/// - **Recognized content itself is never logged at any privacy level.** Not
///   `.private`, not redacted, not hashed. It does not reach a log statement.
///
/// The precedent for this shape of rule is `CrashReporting.scrub(_:)`, which
/// strips user-identifying fields before a crash report leaves the device —
/// same doctrine, different sink.
///
/// ## What is logged
///
/// Events and state transitions only: a session starting or stopping, a
/// permission granted or denied, a thermal level changing, a circuit breaker
/// tripping or recovering. Never a per-frame or per-observation record — a
/// log line per frame would be both a privacy surface and a battery cost, and
/// the questions worth answering after the fact are all about transitions.
public enum AppLog {
    /// The logging subsystem, matching the app's bundle identifier.
    ///
    /// Read from the bundle rather than hard-coded so a rename cannot leave the
    /// logs filed under a subsystem that no longer exists, with a literal
    /// fallback for the package's own test bundle, which has no app identifier.
    public static let subsystem: String = Bundle.main.bundleIdentifier ?? "com.sensebridge.app"

    /// Camera, microphone, and depth capture: session lifecycle, permission
    /// outcomes, and thermal transitions.
    public static let sensing: Logger = .init(subsystem: subsystem, category: "sensing")

    /// Vision and sound classification: which services ran, and whether they
    /// produced a usable result. Never what they recognized.
    public static let perception: Logger = .init(subsystem: subsystem, category: "perception")

    /// Scene composition and the reasoning backend: which composer served a
    /// request, and every circuit-breaker transition.
    public static let reasoning: Logger = .init(subsystem: subsystem, category: "reasoning")

    /// Speech, haptics, and captions: which render targets accepted an event
    /// and which declined it.
    public static let output: Logger = .init(subsystem: subsystem, category: "output")
}
