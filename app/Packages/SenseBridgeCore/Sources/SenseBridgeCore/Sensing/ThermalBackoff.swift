import Foundation

/// How much to slow sustained capture when the device is heating up, and what
/// to say about it.
///
/// Hands-free awareness is the only thing in this app that holds the camera, a
/// LiDAR session, the neural engine, and a full-brightness screen for as long
/// as someone is willing to walk. On a warm device iOS will throttle all four,
/// and the visible symptom — frames arriving late — is indistinguishable to a
/// blind user from a quiet room. Backing off deliberately is both kinder to the
/// battery and more honest than being throttled into the same silence.
///
/// ## Why the user is told
///
/// A degraded cadence is a change in what the app can notice, and
/// `docs/SAFETY-FRAMING.md` treats an unexplained silence as the failure that
/// matters most. So every change of level is announced once — not each tick,
/// and not only on the way down. Thermal state changes on the order of minutes,
/// so "once per change" is at most a handful of sentences across a long walk.
///
/// ## What it deliberately does not do
///
/// It never stops the session. Someone relying on awareness mid-walk is worse
/// off with silence than with a slower cadence they were told about, and iOS
/// throttles or terminates the process on its own if the device genuinely
/// cannot continue.
public enum ThermalBackoff {
    /// How far capture has been slowed, derived from `ProcessInfo.ThermalState`.
    ///
    /// Three levels rather than four: `.nominal` and `.fair` both mean "the
    /// device is fine", and splitting them would announce a change the user
    /// would not be able to perceive.
    public enum Level: Equatable, Sendable, CaseIterable {
        /// Full cadence — the device is nominal or merely fair.
        case normal
        /// Halved cadence, at `.serious`.
        case reduced
        /// Quarter cadence, at `.critical`.
        case minimal
    }

    /// The backoff level `state` calls for.
    public static func level(for state: ProcessInfo.ThermalState) -> Level {
        switch state {
        case .nominal, .fair: .normal
        case .serious: .reduced
        case .critical: .minimal
        // A future state this build has never seen is treated as no worse than
        // nominal on purpose: guessing that an unknown value means "critical"
        // would quarter the cadence of a safety-adjacent feature on nothing
        // more than an OS upgrade.
        @unknown default: .normal
        }
    }

    /// What to multiply a sampling or narration interval by at `level`.
    ///
    /// A multiplier rather than fixed intervals so this composes with the
    /// user's own narration cadence from Settings — someone who has already
    /// chosen a slow cadence should not be sped up by a thermal event, and
    /// someone on a fast one should still be slowed proportionally.
    public static func intervalMultiplier(for level: Level) -> Double {
        switch level {
        case .normal: 1
        case .reduced: 2
        case .minimal: 4
        }
    }

    /// The one sentence to speak when the level changes from `previous` to
    /// `current`, or `nil` when nothing changed.
    ///
    /// A statement about this app's behaviour, never about the world: "checking
    /// less often" is falsifiable and is what actually happened. Recovery is
    /// announced too — a user told the app slowed down needs to hear that it
    /// stopped being slowed, or they will keep discounting what they hear for
    /// the rest of the walk.
    public static func notice(changingFrom previous: Level, to current: Level, locale: Locale = .current) -> String? {
        guard previous != current else { return nil }
        let key = switch current {
        case .normal: "SenseBridge is back to checking at its normal pace."
        case .reduced: "The phone is warm, so SenseBridge is checking less often."
        case .minimal: "The phone is hot, so SenseBridge is checking much less often."
        }
        return LocalizedCatalog.string(key, locale: locale)
    }
}
