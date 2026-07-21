import Foundation

/// Opt-in only, disabled by default — see docs/ARCHITECTURE.md "Optional
/// Cloud Reasoning Adapter" and docs/PRIVACY.md. Nothing in this package
/// invokes an adapter on its own; the App layer only constructs one when
/// `Settings.cloudReasoningEnabled` is true and the user has configured a
/// provider credential (stored in the Keychain, never here).
public protocol CloudReasoningAdapter: Sendable {
    /// Composes a message from perception records via a remote provider.
    /// Never called unless the user opted in and configured a credential.
    func compose(from records: [PerceptionRecord]) async throws -> String
}
