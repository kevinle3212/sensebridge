import Foundation

/// The language the user wants SenseBridge's output in. `.system` defers to
/// the device's active locale instead of pinning one — see
/// docs/superpowers/specs/2026-07-19-language-support-design.md.
public enum AppLanguage: String, Sendable, Equatable, Codable, CaseIterable {
    case system, en, es, vi

    /// The concrete locale to render output in, or `nil` for `.system`,
    /// meaning "defer to the device's current locale".
    public var locale: Locale? {
        switch self {
        case .system: nil
        case .en: Locale(identifier: "en")
        case .es: Locale(identifier: "es")
        case .vi: Locale(identifier: "vi")
        }
    }
}
