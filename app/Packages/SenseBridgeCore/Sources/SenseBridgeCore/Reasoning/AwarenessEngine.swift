import Foundation

/// Turns a stream of depth readings into an alert/clear signal, with
/// hysteresis so the signal doesn't flap when a reading sits near the
/// boundary. This is awareness, not obstacle avoidance — see
/// docs/SAFETY-FRAMING.md; callers must render the alert through hedged
/// `Phrasing`, never as a bare "obstacle detected."
public struct AwarenessEngine: Sendable {
    public let alertThresholdMeters: Double
    public let clearThresholdMeters: Double

    private var isAlerting = false

    public init(alertThresholdMeters: Double = 1.5, clearThresholdMeters: Double = 2.5) {
        precondition(
            clearThresholdMeters > alertThresholdMeters,
            "clearThresholdMeters must exceed alertThresholdMeters to provide hysteresis"
        )
        self.alertThresholdMeters = alertThresholdMeters
        self.clearThresholdMeters = clearThresholdMeters
    }

    /// Feeds one depth reading and returns whether an awareness alert
    /// should be active now.
    public mutating func evaluate(depthMeters: Double) -> Bool {
        if depthMeters <= alertThresholdMeters {
            isAlerting = true
        } else if depthMeters >= clearThresholdMeters {
            isAlerting = false
        }
        return isAlerting
    }
}
