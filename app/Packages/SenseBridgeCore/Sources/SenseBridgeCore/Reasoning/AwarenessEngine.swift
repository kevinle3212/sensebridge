import Foundation

/// How the alert state changed across one `AwarenessEngine.evaluate` call.
///
/// The distinction between a *transition* and a steady state is what makes
/// `OutputSignal.awarenessClear` honest: it is only ever truthful on a real
/// alerting → not-alerting change, because that is a change the app actually
/// observed, rather than an absence it inferred from one sample. See the doc
/// comment on that case in `RenderTarget.swift`.
public enum AwarenessTransition: Sendable, Equatable {
    /// Was not alerting, is alerting now.
    case becameAlerting
    /// Was alerting, is not alerting now.
    case becameClear
    /// The alert state is the same as it was on the previous reading.
    case unchanged
}

/// Turns a stream of depth readings into an alert/clear signal, with
/// hysteresis so the signal doesn't flap when a reading sits near the
/// boundary. This is awareness, not obstacle avoidance — see
/// docs/SAFETY-FRAMING.md; callers must render the alert through hedged
/// `Phrasing`, never as a bare "obstacle detected."
public struct AwarenessEngine: Sendable {
    public let alertThresholdMeters: Double
    public let clearThresholdMeters: Double

    /// Whether an awareness alert is active as of the most recent
    /// `evaluate(depthMeters:)`. `false` before any reading has been fed —
    /// which means "nothing has been evaluated", not "nothing is there".
    public private(set) var isAlerting = false

    /// Creates an engine with the given hysteresis band.
    ///
    /// `clearThresholdMeters` deliberately sits above `alertThresholdMeters`:
    /// a single band would flap alert/clear/alert several times a second on a
    /// reading hovering at the boundary, which on a continuously-narrating
    /// channel is both useless and alarming.
    public init(alertThresholdMeters: Double = 1.5, clearThresholdMeters: Double = 2.5) {
        precondition(
            clearThresholdMeters > alertThresholdMeters,
            "clearThresholdMeters must exceed alertThresholdMeters to provide hysteresis"
        )
        self.alertThresholdMeters = alertThresholdMeters
        self.clearThresholdMeters = clearThresholdMeters
    }

    /// Creates an engine alerting within `meters`, deriving the clear
    /// threshold from it.
    ///
    /// Exists because the alert distance is a single user-facing setting
    /// (`Settings.awarenessAlertDistanceMeters`) while the engine needs two
    /// thresholds. Deriving the second here means no call site can configure
    /// one distance and accidentally invert the band into the precondition
    /// above. A factory rather than a second initializer: two initializers
    /// both defaulting their trailing parameter are ambiguous at
    /// `AwarenessEngine(alertThresholdMeters:)`.
    public static func alerting(withinMeters meters: Double, hysteresisMeters: Double = 1.0) -> Self {
        Self(
            alertThresholdMeters: meters,
            clearThresholdMeters: meters + max(hysteresisMeters, 0.1)
        )
    }

    /// Feeds one depth reading and reports how the alert state changed.
    ///
    /// Readings between the two thresholds leave the state untouched — that
    /// is the hysteresis band, not an omission.
    public mutating func evaluate(depthMeters: Double) -> AwarenessTransition {
        let wasAlerting = isAlerting
        if depthMeters <= alertThresholdMeters {
            isAlerting = true
        } else if depthMeters >= clearThresholdMeters {
            isAlerting = false
        }
        return switch (wasAlerting, isAlerting) {
        case (false, true): .becameAlerting
        case (true, false): .becameClear
        default: .unchanged
        }
    }

    /// Resets to the not-alerting state, for a new session.
    ///
    /// Without this, restarting hands-free awareness while the previous run
    /// had ended mid-alert would swallow the first `becameAlerting` of the new
    /// run — the engine would already believe it was alerting about a scene
    /// the user has since walked away from.
    public mutating func reset() {
        isAlerting = false
    }
}
