import Foundation
import Security
import SenseBridgeCore

/// Keychain-backed `APICredentialStore` — the only place BYOK API keys and
/// the self-hosted endpoint's optional token are ever written. See
/// docs/superpowers/specs/2026-08-11-awareness-ai-tiers-design.md
/// "Data model" for why every attribute below is spelled out explicitly,
/// matching `CrashReporting.start(dsn:)`'s "a reviewer should see the whole
/// surface without knowing any SDK defaults" convention.
final class KeychainCredentialStore: APICredentialStore, @unchecked Sendable {
    private let service = "com.sensebridge.reasoning-credentials"

    /// Looks the credential up fresh on every call; see the protocol's doc comment.
    func credential(for key: CredentialKey) -> String? {
        var query = baseQuery(for: key)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess, let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    /// Updates an existing entry rather than blindly adding, which would
    /// return `errSecDuplicateItem` on a second save and silently leave the
    /// old (possibly rotated-out) key in place — the single most common
    /// Keychain bug, and the direction it fails in matters here.
    func save(_ value: String, for key: CredentialKey) {
        let data = Data(value.utf8)
        let query = baseQuery(for: key)
        let checkStatus = SecItemCopyMatching(query as CFDictionary, nil)
        if checkStatus == errSecSuccess {
            SecItemUpdate(query as CFDictionary, [kSecValueData as String: data] as CFDictionary)
        } else {
            var addQuery = query
            addQuery[kSecValueData as String] = data
            SecItemAdd(addQuery as CFDictionary, nil)
        }
    }

    /// Switching `Settings.reasoningBackend` away from `.cloud` must never
    /// call this implicitly — retention is the user's explicit choice from
    /// the Settings UI's "Remove key" control (Task 15).
    func removeCredential(for key: CredentialKey) {
        SecItemDelete(baseQuery(for: key) as CFDictionary)
    }

    /// The Keychain query attributes shared by every operation on `key`'s entry.
    private func baseQuery(for key: CredentialKey) -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key.rawValue,
            // Rides neither an encrypted backup nor iCloud Keychain sync —
            // this is a billing credential, and `docs/ARCHITECTURE.md`
            // already plans optional CloudKit settings sync, so keeping it
            // out of both paths is deliberate, not an oversight.
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
            kSecAttrSynchronizable as String: false
        ]
    }
}
