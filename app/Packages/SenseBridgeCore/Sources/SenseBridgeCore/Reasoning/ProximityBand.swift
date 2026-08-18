import Foundation

/// How near a measurement is, bucketed coarsely enough to be honest.
///
/// Distance already reaches the user as prose ("something about two feet
/// ahead"). This exists for the channel that cannot carry prose: haptics. A
/// deaf-blind user, or anyone with headphones out, receives `OutputSignal`
/// alone, and a single `.awarenessAlert` buzz says "something is near" whether
/// the something is at arm's length or across the room. Bucketing the distance
/// lets the *cadence* carry what the words carry — faster as the measurement
/// gets nearer, which is the one tactile idiom people already read without
/// being taught.
///
/// ## Four bands, and no fifth
///
/// The boundaries are round numbers in metres chosen for what they mean to a
/// walking person, not for even spacing: within reach, within a stride, within
/// a few steps, further. A finer scale would encode precision the sensing chain
/// has not earned — see ``AwarenessZone`` for the same argument about direction.
///
/// ## This is not a vocabulary
///
/// `HapticPattern`'s doc comment says its cues are a small fixed set, not a
/// haptic language, and that holds here: this varies the *repeat rate* of one
/// existing cue. It does not add a new pattern for a user to learn, and it must
/// not grow into one — a real deaf-blind haptic vocabulary needs co-design with
/// deaf-blind collaborators.
public enum ProximityBand: String, Sendable, Equatable, CaseIterable, Comparable {
    /// Within reach — roughly 0.6 m or nearer.
    case immediate
    /// Within a stride — roughly 1.2 m or nearer.
    case near
    /// Within a few steps — roughly 2.5 m or nearer.
    case moderate
    /// Further than a few steps.
    case distant

    /// Orders bands nearest-first, so `min()` over a set of readings is the
    /// nearest one rather than whichever happened to be declared first.
    public static func < (lhs: Self, rhs: Self) -> Bool {
        guard let left = allCases.firstIndex(of: lhs), let right = allCases.firstIndex(of: rhs) else {
            return false
        }
        return left < right
    }

    /// The band a distance falls in.
    ///
    /// - Parameter meters: A measured distance. Non-finite and non-positive
    ///   input yields ``distant`` rather than trapping: those values reach here
    ///   only from a frame something already went wrong in, and the failure that
    ///   matters is a bogus reading buzzing as if something were against the
    ///   user's face.
    public static func band(forMeters meters: Double) -> Self {
        guard meters.isFinite, meters > 0 else { return .distant }
        return switch meters {
        case ..<0.6: .immediate
        case ..<1.2: .near
        case ..<2.5: .moderate
        default: .distant
        }
    }

    /// How long to wait between repeats of the awareness cue at this band, or
    /// `nil` when the band should not repeat at all.
    ///
    /// ``distant`` returns `nil` deliberately. A cue that never stops is a cue
    /// that stops being noticed, and a slow background pulse for "something is
    /// three metres away" would mean the phone buzzes continuously indoors —
    /// where there is always a wall three metres away. Silence here is not a
    /// claim that nothing is there; the app is simply not alerting, which is
    /// what it does at every distance beyond the user's own threshold.
    public var repeatInterval: Duration? {
        switch self {
        case .immediate: .milliseconds(400)
        case .near: .milliseconds(900)
        case .moderate: .milliseconds(1800)
        case .distant: nil
        }
    }
}
