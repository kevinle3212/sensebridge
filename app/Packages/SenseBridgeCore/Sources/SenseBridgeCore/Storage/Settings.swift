import Foundation

/// User-configurable preferences persisted via `UserDefaults` (see
/// docs/ARCHITECTURE.md "Local Storage"). Never holds user content —
/// images, recognized text, or enrollment data are never stored here.
public struct Settings: Sendable, Equatable, Codable {
    public var outputProfile: OutputProfile
    public var speechRate: Double
    public var language: AppLanguage
    /// Voice pitch, `0` lowest to `1` highest — see `SpeechVoiceSettings`.
    public var speechPitch: Double
    /// Output volume, `0` silent to `1` loudest — see `SpeechVoiceSettings`.
    public var speechVolume: Double
    /// Whether haptic output is enabled at all.
    public var hapticsEnabled: Bool
    /// Intensity multiplier applied to every haptic pattern, `0...1`.
    public var hapticIntensity: Double
    /// The camera lens to select by default when capture starts.
    public var preferredLens: CameraLens
    /// Whether the torch defaults to on when capture starts.
    public var torchDefaultOn: Bool
    /// Shortest gap, in seconds, between two spoken descriptions in hands-free
    /// awareness. Awareness *alerts* ignore this — see `NarrationThrottle`,
    /// whose `isUrgent` path exists so a real change is never held back by a
    /// cadence the user chose for routine narration.
    public var narrationIntervalSeconds: Double
    /// How near, in metres, something has to be before hands-free awareness
    /// mentions it. User-configurable because the right value depends on how
    /// the phone is mounted and how fast the user walks, which no default can
    /// know — see `AmbientSensingSource.regionOfInterest` for the same problem
    /// on the other axis.
    public var awarenessAlertDistanceMeters: Double
    /// Whether the user has consented to sending crash and hang reports off
    /// the device. `false` until the user says otherwise, and the only thing
    /// in this struct that governs an outbound network path at all — see
    /// `CrashReporting` in the app target and docs/PRIVACY.md. Stored here
    /// rather than in the app target because this is the app's one persisted
    /// preferences type; a `Bool` is not a framework dependency, so the
    /// protocol-seams invariant is untouched.
    public var crashReportingEnabled: Bool
    /// Whether the user has completed (or explicitly skipped) the first-run
    /// onboarding flow. `false` for a brand-new install (`init()`'s
    /// default); a missing key on *decode* means a settings blob already
    /// existed before this field did, which only a pre-existing install
    /// upgrading into this build can be true of — see `SettingsTests
    /// .decodingSettingsPersistedBeforeOnboardingExistedYieldsCompleted`.
    public var hasCompletedOnboarding: Bool
    /// Which reasoning backend composes scene descriptions. `.onDevice`
    /// until the user explicitly opts into a network path.
    public var reasoningBackend: ReasoningBackend
    /// The BYOK provider when `reasoningBackend == .cloud`. `nil` means
    /// configured-but-no-provider-chosen, which the resolver treats as
    /// "not configured" and falls back to on-device silently.
    public var cloudProvider: CloudProvider?
    /// The user's self-hosted endpoint base URL when
    /// `reasoningBackend == .localEndpoint`. Not a secret — a destination —
    /// so it lives here rather than in `APICredentialStore`. Validated by
    /// `EndpointURLNormalizer` before use, not on decode.
    public var localEndpointURL: String?
    /// User-supplied model identifier. Required (enforced by the Settings
    /// UI, not this type) for `.nvidiaNIM` and `.localEndpoint`, since
    /// neither has a universal default model; optional override for
    /// `.anthropic`/`.openai`, which do.
    public var reasoningModelOverride: String?

    public init(
        outputProfile: OutputProfile = .blind,
        speechRate: Double = 0.5,
        language: AppLanguage = .system,
        speechPitch: Double = 0.5,
        speechVolume: Double = 1.0,
        hapticsEnabled: Bool = true,
        hapticIntensity: Double = 1.0,
        preferredLens: CameraLens = .wide,
        torchDefaultOn: Bool = false,
        narrationIntervalSeconds: Double = 6,
        awarenessAlertDistanceMeters: Double = 1.5,
        crashReportingEnabled: Bool = false,
        hasCompletedOnboarding: Bool = false,
        reasoningBackend: ReasoningBackend = .onDevice,
        cloudProvider: CloudProvider? = nil,
        localEndpointURL: String? = nil,
        reasoningModelOverride: String? = nil
    ) {
        self.outputProfile = outputProfile
        self.speechRate = speechRate
        self.language = language
        self.speechPitch = speechPitch
        self.speechVolume = speechVolume
        self.hapticsEnabled = hapticsEnabled
        self.hapticIntensity = hapticIntensity
        self.preferredLens = preferredLens
        self.torchDefaultOn = torchDefaultOn
        self.narrationIntervalSeconds = narrationIntervalSeconds
        self.awarenessAlertDistanceMeters = awarenessAlertDistanceMeters
        self.crashReportingEnabled = crashReportingEnabled
        self.hasCompletedOnboarding = hasCompletedOnboarding
        self.reasoningBackend = reasoningBackend
        self.cloudProvider = cloudProvider
        self.localEndpointURL = localEndpointURL
        self.reasoningModelOverride = reasoningModelOverride
    }

    private enum CodingKeys: String, CodingKey {
        case outputProfile, speechRate, language
        case speechPitch, speechVolume, hapticsEnabled, hapticIntensity, preferredLens, torchDefaultOn
        case narrationIntervalSeconds, awarenessAlertDistanceMeters
        case crashReportingEnabled, hasCompletedOnboarding
        case reasoningBackend, cloudProvider, localEndpointURL, reasoningModelOverride
    }

    /// Custom decode so settings persisted before each field below existed
    /// still decode instead of failing outright: a missing key falls back to
    /// its documented default above, matching the existing `language`
    /// back-compat handling.
    ///
    /// `reasoningBackend`'s decode is intentionally never a throwing decode
    /// of a required key — an unrecognized or absent value must degrade to
    /// `.onDevice`, never fail the whole settings blob. A prior version of
    /// this file decoded `cloudReasoningEnabled` as non-optional, which meant
    /// a single corrupted or future field could reset every other setting
    /// (speech rate, output profile, onboarding state) to its default. Never
    /// repeat that shape for a new field.
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        outputProfile = try container.decode(OutputProfile.self, forKey: .outputProfile)
        speechRate = try container.decode(Double.self, forKey: .speechRate)
        language = try container.decodeIfPresent(AppLanguage.self, forKey: .language) ?? .system
        speechPitch = try container.decodeIfPresent(Double.self, forKey: .speechPitch) ?? 0.5
        speechVolume = try container.decodeIfPresent(Double.self, forKey: .speechVolume) ?? 1.0
        hapticsEnabled = try container.decodeIfPresent(Bool.self, forKey: .hapticsEnabled) ?? true
        hapticIntensity = try container.decodeIfPresent(Double.self, forKey: .hapticIntensity) ?? 1.0
        preferredLens = try container.decodeIfPresent(CameraLens.self, forKey: .preferredLens) ?? .wide
        torchDefaultOn = try container.decodeIfPresent(Bool.self, forKey: .torchDefaultOn) ?? false
        narrationIntervalSeconds = try container.decodeIfPresent(
            Double.self, forKey: .narrationIntervalSeconds
        ) ?? 6
        awarenessAlertDistanceMeters = try container.decodeIfPresent(
            Double.self, forKey: .awarenessAlertDistanceMeters
        ) ?? 1.5
        crashReportingEnabled = try container.decodeIfPresent(
            Bool.self, forKey: .crashReportingEnabled
        ) ?? false
        hasCompletedOnboarding = try container.decodeIfPresent(
            Bool.self, forKey: .hasCompletedOnboarding
        ) ?? true

        if let backendRaw = try container.decodeIfPresent(String.self, forKey: .reasoningBackend),
           let backend = ReasoningBackend(rawValue: backendRaw) {
            reasoningBackend = backend
        } else if let legacyContainer = try? decoder.container(keyedBy: LegacyCodingKeys.self),
                  let legacyCloudEnabled = try? legacyContainer.decodeIfPresent(
                      Bool.self, forKey: .cloudReasoningEnabled
                  ),
                  legacyCloudEnabled == true {
            // Old installs that had turned the boolean on fall back to
            // on-device until they pick a provider and re-consent — see
            // `cloudProvider = nil` below and the resolver's
            // not-configured-falls-back-silently behavior.
            reasoningBackend = .cloud
        } else {
            reasoningBackend = .onDevice
        }
        cloudProvider = try container.decodeIfPresent(CloudProvider.self, forKey: .cloudProvider)
        localEndpointURL = try container.decodeIfPresent(String.self, forKey: .localEndpointURL)
        reasoningModelOverride = try container.decodeIfPresent(String.self, forKey: .reasoningModelOverride)
    }

    /// Only `cloudReasoningEnabled`, kept solely so old settings blobs still
    /// decode — see `init(from:)`. Never written; not in `CodingKeys`, so it
    /// never appears in an encoded settings blob again.
    private enum LegacyCodingKeys: String, CodingKey {
        case cloudReasoningEnabled
    }
}

public protocol SettingsStore: Sendable {
    func load() -> Settings
    func save(_ settings: Settings)
}

/// `UserDefaults`-backed store. iCloud sync of this same data (settings
/// only, opt-in) is a later addition behind the same `SettingsStore`
/// protocol — see docs/ARCHITECTURE.md "Sync".
public final class UserDefaultsSettingsStore: SettingsStore, @unchecked Sendable {
    private let defaults: UserDefaults
    private let key = "com.sensebridge.settings"

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    public func load() -> Settings {
        guard let data = defaults.data(forKey: key),
              let settings = try? JSONDecoder().decode(Settings.self, from: data)
        else {
            return Settings()
        }
        return settings
    }

    public func save(_ settings: Settings) {
        guard let data = try? JSONEncoder().encode(settings) else { return }
        defaults.set(data, forKey: key)
    }
}
