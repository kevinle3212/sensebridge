import Foundation
import SenseBridgeCore

/// Turning machine facts — an error, a distance in metres, the active
/// reasoning backend — into the words the user actually hears.
///
/// Split into its own file because none of it touches session state: these
/// are pure functions of their arguments, and `AmbientAwarenessSession.swift`
/// is long enough without them (SwiftLint's `file_length`/`type_body_length`
/// gates, not merely style).
extension AmbientAwarenessSession {
    /// Which backend is actually composing descriptions right now, for the
    /// view to name — see AGENTS.md doctrine 4: a user who doesn't know
    /// which backend they're hearing can't tell a degraded mode from a bug.
    /// Read from `Settings` plus on-device model availability, not cached,
    /// so it stays accurate if the user changes it mid-session via Settings.
    func activeBackendDescription(settings: Settings) -> String {
        switch settings.reasoningBackend {
        case .onDevice:
            FoundationModelsSceneComposer.isModelAvailable
                ? "Descriptions are composed on-device by Apple Intelligence."
                : """
                Apple Intelligence is unavailable, so descriptions are read out \
                as a plain list of what was recognized.
                """
        case .localEndpoint:
            "Descriptions are composed by your self-hosted endpoint, with on-device as a fallback."
        case .cloud:
            switch settings.cloudProvider {
            case .anthropic: "Descriptions are composed by Anthropic, with on-device as a fallback."
            case .openai: "Descriptions are composed by OpenAI, with on-device as a fallback."
            case .nvidiaNIM: "Descriptions are composed by NVIDIA NIM, with on-device as a fallback."
            case nil: "Descriptions are composed on-device — no cloud provider is selected yet."
            }
        }
    }

    /// Shared `URLSession` config for every network reasoning request —
    /// never the platform default, which would queue a request until
    /// connectivity returns (`waitsForConnectivity`) and allow a 60s
    /// timeout, both wrong for a real-time spoken-output app. No automatic
    /// retries anywhere in this stack — see the plan's global constraints.
    static func makeURLSession(requestTimeout: TimeInterval) -> URLSession {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.waitsForConnectivity = false
        configuration.timeoutIntervalForRequest = requestTimeout
        configuration.allowsConstrainedNetworkAccess = false
        return URLSession(configuration: configuration)
    }

    /// Hands-free awareness narrates on a comfort-driven cadence, not an
    /// emergency one — a short timeout keeps a slow endpoint from holding up
    /// the session, matching the spec's "~4s for hands-free composition"
    /// figure.
    static let networkRequestTimeout: TimeInterval = 4

    /// Turns a sensing failure into prose that tells the user what to do next.
    static func message(for error: Error) -> String {
        switch error {
        case AmbientSensingSource.SensingError.depthUnavailable:
            """
            Hands-free awareness needs a LiDAR depth sensor, which this device \
            does not have.
            """
        case AmbientSensingSource.SensingError.unsupportedDevice:
            "This device cannot run hands-free awareness."
        default:
            "Hands-free awareness couldn't start. Check camera access in Settings, then try again."
        }
    }

    /// Formats a distance in the reader's own units — metres in most of the
    /// world, feet in the US — rather than hardcoding this file's.
    static func formattedDistance(meters: Double, locale: Locale) -> String {
        let formatter = MeasurementFormatter()
        formatter.locale = locale
        formatter.unitOptions = .naturalScale
        formatter.numberFormatter.maximumFractionDigits = 1
        return formatter.string(from: Measurement(value: meters, unit: UnitLength.meters))
    }
}
