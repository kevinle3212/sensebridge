import Foundation

/// Which credential slot a stored secret belongs to. Mirrors `CloudProvider`
/// plus one slot for the self-hosted endpoint's optional bearer token.
public enum CredentialKey: String, Sendable, Equatable, CaseIterable {
    case anthropic, openai, nvidiaNIM, localEndpoint
}

/// Where BYOK API keys and the self-hosted endpoint's optional token live.
/// **Never** `Settings`/`UserDefaults` — see the plan's global constraints.
/// The real implementation (`KeychainCredentialStore`, App layer) uses the
/// Keychain; this protocol exists so `ReasoningComposerResolver` and its
/// tests never depend on `Security` directly, matching the
/// `SettingsStore`/`UserDefaultsSettingsStore` split.
public protocol APICredentialStore: Sendable {
    /// Looks the credential up fresh on every call — callers must not cache
    /// it, per the plan's "load the key just-in-time per request" rule.
    func credential(for key: CredentialKey) -> String?
    /// Saves or replaces the credential for `key`. Implementations must
    /// update an existing entry rather than silently failing on a duplicate
    /// — see `KeychainCredentialStore`.
    func save(_ value: String, for key: CredentialKey)
    /// Removes the credential for `key`. Switching `Settings.reasoningBackend`
    /// away from `.cloud` must **not** call this automatically — retention
    /// is the user's explicit choice, made from the Settings UI (Task 15).
    func removeCredential(for key: CredentialKey)
}
