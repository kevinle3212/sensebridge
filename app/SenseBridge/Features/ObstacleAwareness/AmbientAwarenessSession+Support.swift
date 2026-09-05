import Foundation
import SenseBridgeCore
import UIKit

/// Turning machine facts — an error, a distance in metres, the active
/// reasoning backend — into the words the user actually hears, plus
/// `configureReasoning(environment:)`, which rebuilds `classifier`/`resolver`.
///
/// Split into its own file because `AmbientAwarenessSession.swift` is long
/// enough without it (SwiftLint's `file_length`/`type_body_length` gates, not
/// merely style) — `classifier`/`resolver`/`phrasing`/`locale` are internal
/// rather than `private` specifically so this same-type extension, in a
/// different file, can still read and mutate them.
extension AmbientAwarenessSession {
    /// Rebuilds `classifier`/`resolver` from `settings.spokenDetail` — called
    /// once per `start(environment:)`, so a detail change made in Settings
    /// takes effect on the next session start, matching `engine`/`throttle`'s
    /// existing per-session-rebuilt lifetime.
    func configureReasoning(environment: AppEnvironment) {
        classifier = ObjectClassificationService(
            maximumLabels: environment.settings.spokenDetail.maximumLabels,
            locale: locale
        )
        resolver = ReasoningComposerResolver(
            onDeviceComposer: FoundationModelsSceneComposer(
                phrasing: phrasing, locale: locale, detail: environment.settings.spokenDetail
            ),
            credentialStore: KeychainCredentialStore(),
            factory: LiveNetworkComposerFactory(
                session: Self.makeURLSession(requestTimeout: Self.networkRequestTimeout),
                requestTimeout: Self.networkRequestTimeout, locale: locale
            )
        )
    }

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

    /// How hot and how charged the phone is, in the terms that matter to
    /// someone relying on this session — or `nil` when there is nothing worth
    /// saying.
    ///
    /// Surfaced rather than left to the backoff to handle silently. Hands-free
    /// awareness holds the screen on and the camera running, and `ThermalBackoff`
    /// answers heat by slowing the sampling rate — from the outside that is a
    /// session that has quietly become less responsive, with no way to tell it
    /// from one that is working. AGENTS.md doctrine 4: a limitation the user
    /// cannot see is a limitation stated nowhere.
    func deviceConditionDescription() -> String? {
        var notes = [String]()
        switch thermalLevel {
        case .normal:
            break
        case .reduced:
            notes.append(String(localized: "The phone is warm, so readings are being taken less often."))
        case .minimal:
            notes.append(String(localized: "The phone is hot, so readings are much less frequent."))
        }
        if let battery = Self.batteryPercentage() {
            notes.append(String(
                localized: "Battery \(battery) percent. This mode uses it quickly.",
                comment: "Battery level shown while hands-free awareness runs."
            ))
        }
        return notes.isEmpty ? nil : notes.joined(separator: " ")
    }

    /// The battery level as a whole percentage, or `nil` when iOS will not
    /// report it — the simulator, and any device where monitoring was refused.
    ///
    /// `nil` rather than a guess: an invented figure on this screen would be a
    /// claim about how long the session can run, which is exactly the kind of
    /// unearned certainty the rest of this app avoids.
    static func batteryPercentage() -> Int? {
        UIDevice.current.isBatteryMonitoringEnabled = true
        let level = UIDevice.current.batteryLevel
        guard level >= 0 else { return nil }
        return Int((level * 100).rounded())
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
    ///
    /// `unitStyle = .long` spells the unit out ("inches", "feet", "meters")
    /// instead of `.medium`'s abbreviation ("in", "ft") — the abbreviation
    /// reaches `SpeechRenderTarget` as literal text, so a synthesizer reads
    /// "in" as the word "in", not the unit, at close range.
    static func formattedDistance(meters: Double, locale: Locale) -> String {
        let formatter = MeasurementFormatter()
        formatter.locale = locale
        formatter.unitOptions = .naturalScale
        formatter.unitStyle = .long
        formatter.numberFormatter.maximumFractionDigits = 1
        return formatter.string(from: Measurement(value: meters, unit: UnitLength.meters))
    }
}
