import Foundation

/// User-configurable preferences persisted via `UserDefaults` (see
/// docs/ARCHITECTURE.md "Local Storage"). Never holds user content —
/// images, recognized text, or enrollment data are never stored here.
public struct Settings: Sendable, Equatable, Codable {
    public var outputProfile: OutputProfile
    public var speechRate: Double
    public var cloudReasoningEnabled: Bool
    public var language: AppLanguage

    public init(
        outputProfile: OutputProfile = .blind,
        speechRate: Double = 0.5,
        cloudReasoningEnabled: Bool = false,
        language: AppLanguage = .system
    ) {
        self.outputProfile = outputProfile
        self.speechRate = speechRate
        self.cloudReasoningEnabled = cloudReasoningEnabled
        self.language = language
    }

    private enum CodingKeys: String, CodingKey {
        case outputProfile, speechRate, cloudReasoningEnabled, language
    }

    /// Custom decode so settings persisted before `language` existed still
    /// decode instead of failing outright: a missing key falls back to
    /// `.system`, matching the default above.
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        outputProfile = try container.decode(OutputProfile.self, forKey: .outputProfile)
        speechRate = try container.decode(Double.self, forKey: .speechRate)
        cloudReasoningEnabled = try container.decode(Bool.self, forKey: .cloudReasoningEnabled)
        language = try container.decodeIfPresent(AppLanguage.self, forKey: .language) ?? .system
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
