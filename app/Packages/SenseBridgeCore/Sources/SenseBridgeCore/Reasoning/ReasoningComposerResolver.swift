import Foundation

/// The outcome of one `ReasoningComposerResolver.compose` call.
public struct ReasoningComposeResult: Sendable, Equatable {
    public let text: String
    public let backendUsed: ReasoningBackend
    /// Non-nil only for the two events the disclosure model actually
    /// speaks: a network backend just failed twice in a row (breaker
    /// tripped), or it just recovered after being tripped. Every other case
    /// — never configured, working normally — is `nil`. See
    /// docs/superpowers/specs/2026-08-11-awareness-ai-tiers-design.md
    /// "Resolution, concurrency, and fallback".
    public let announcement: String?
}

/// Builds a network `SceneComposer` for the given configuration, or `nil`
/// when required configuration (a credential, a URL, a model name) is
/// missing — which the resolver treats as "not configured," not "failing."
/// `modelOverride` is a call-time parameter rather than something baked into
/// the factory at construction, so one long-lived factory instance (built
/// once per session/view) always sees the user's current `Settings` value
/// instead of whatever was true when the factory was built.
public protocol NetworkComposerFactory: Sendable {
    /// Builds a composer for `backend`, or `nil` if the given configuration
    /// isn't enough to construct one (missing credential, URL, or model).
    func composer(
        backend: ReasoningBackend, provider: CloudProvider?, endpointURL: String?,
        modelOverride: String?, credential: String?
    ) -> SceneComposer?
}

/// The real factory, used everywhere outside tests. Builds a fresh composer
/// per call rather than caching one, so a credential or model rotated
/// mid-session takes effect on the next request.
public struct LiveNetworkComposerFactory: NetworkComposerFactory {
    private let session: URLSession
    private let requestTimeout: TimeInterval
    private let locale: Locale

    /// - Parameters:
    ///   - session: Shared across every composer this factory builds; tests inject `StubURLProtocol`'s session.
    ///   - requestTimeout: Carried through unused today — reserved for a per-request `URLRequest.timeoutInterval`.
    ///   - locale: Passed to every composer this factory builds.
    public init(session: URLSession, requestTimeout: TimeInterval, locale: Locale) {
        self.session = session
        self.requestTimeout = requestTimeout
        self.locale = locale
    }

    /// Routes to the composer type matching `backend`, or `nil` when the
    /// backend-specific required configuration (credential, URL, model) is
    /// absent. See `NetworkComposerFactory`'s doc comment for the contract.
    public func composer(
        backend: ReasoningBackend, provider: CloudProvider?, endpointURL: String?,
        modelOverride: String?, credential: String?
    ) -> SceneComposer? {
        switch backend {
        case .onDevice:
            return nil
        case .cloud:
            return cloudComposer(provider: provider, modelOverride: modelOverride, credential: credential)
        case .localEndpoint:
            guard let endpointURL, !endpointURL.isEmpty,
                  let modelOverride, !modelOverride.isEmpty
            else { return nil }
            return try? OpenAICompatibleSceneComposer(
                endpointURL: endpointURL, apiKey: credential, model: modelOverride, session: session, locale: locale
            )
        }
    }

    /// Routes a `.cloud` request to the provider-specific composer. Split
    /// out of `composer(backend:...)` to keep that switch's cases at one
    /// nesting level (SwiftLint's `nesting` rule).
    private func cloudComposer(
        provider: CloudProvider?, modelOverride: String?, credential: String?
    ) -> SceneComposer? {
        switch provider {
        case .anthropic:
            guard let credential else { return nil }
            return AnthropicSceneComposer(apiKey: credential, model: modelOverride, session: session, locale: locale)
        case .openai:
            guard let credential else { return nil }
            return try? OpenAICompatibleSceneComposer(
                endpointURL: "https://api.openai.com/v1/chat/completions",
                apiKey: credential, model: modelOverride ?? "gpt-4o-mini", session: session, locale: locale
            )
        case .nvidiaNIM:
            // No universal default model exists for NIM — the Settings UI
            // (Task 17) requires `reasoningModelOverride` before this
            // backend can be enabled; treat a missing model as
            // not-configured here too.
            guard let modelOverride, !modelOverride.isEmpty else { return nil }
            return try? OpenAICompatibleSceneComposer(
                endpointURL: "https://integrate.api.nvidia.com/v1/chat/completions",
                apiKey: credential, model: modelOverride, session: session, locale: locale
            )
        case nil:
            return nil
        }
    }
}

/// Picks the active reasoning backend from `Settings`, falls back to
/// on-device on any missing configuration or failure, and runs the
/// disclosure/circuit-breaker model described in the spec. One instance is
/// owned per session (`AmbientAwarenessSession`, `SceneDescriptionView`),
/// matching the existing per-session-instantiated-and-reset pattern
/// `AwarenessEngine`/`NarrationThrottle` already use.
@MainActor
public final class ReasoningComposerResolver {
    private let onDeviceComposer: SceneComposer
    private let credentialStore: APICredentialStore
    private let factory: NetworkComposerFactory

    private var consecutiveFailures = 0
    private var breakerTripped = false
    private var probeTickCounter = 0
    /// Every 5th tick while tripped, per the spec's circuit-breaker cadence
    /// — bounds cost against a still-down endpoint without abandoning
    /// recovery detection entirely.
    private static let probeCadence = 5

    /// - Parameters:
    ///   - onDeviceComposer: The last-resort composer; must never itself depend on the network.
    ///   - credentialStore: Looked up fresh per `compose(from:settings:locale:requestTimeout:)` call.
    ///   - factory: Builds the backend-specific network composer, or `nil` when not configured.
    public init(onDeviceComposer: SceneComposer, credentialStore: APICredentialStore, factory: NetworkComposerFactory) {
        self.onDeviceComposer = onDeviceComposer
        self.credentialStore = credentialStore
        self.factory = factory
    }

    /// Resets breaker/failure state for a new session — must be called
    /// alongside `AwarenessEngine.reset()`/`NarrationThrottle.reset()` when
    /// hands-free awareness restarts, so a previous session's trip/recovery
    /// state never leaks into a new one.
    public func resetSession() {
        consecutiveFailures = 0
        breakerTripped = false
        probeTickCounter = 0
    }

    /// Composes a scene description for `records`, preferring
    /// `settings.reasoningBackend` when it's configured and the circuit
    /// breaker permits an attempt, otherwise falling back to on-device.
    /// Returns `nil` only if on-device composition itself throws — the last
    /// resort has no further fallback.
    ///
    /// - Parameters:
    ///   - records: The perceived scene to describe.
    ///   - settings: Carries the active backend, provider, endpoint, and model override.
    ///   - locale: Drives both the request language and any announcement text.
    ///   - requestTimeout: Unused by the resolver itself; carried for callers building a matching factory.
    public func compose(
        from records: [PerceptionRecord],
        settings: Settings,
        locale: Locale,
        requestTimeout _: TimeInterval
    ) async -> ReasoningComposeResult? {
        if settings.reasoningBackend.usesNetwork, shouldAttemptNetwork() {
            let credential = credential(for: settings)
            if let composer = factory.composer(
                backend: settings.reasoningBackend,
                provider: settings.cloudProvider,
                endpointURL: settings.localEndpointURL,
                modelOverride: settings.reasoningModelOverride,
                credential: credential
            ) {
                do {
                    let text = try await composer.compose(from: records)
                    let announcement = recoveryAnnouncementIfNeeded(locale: locale)
                    return ReasoningComposeResult(
                        text: text, backendUsed: settings.reasoningBackend, announcement: announcement
                    )
                } catch {
                    recordFailure()
                }
            }
            // `factory.composer` returning `nil` means "not configured" —
            // falls through to on-device below without counting as a
            // failure and without an announcement (disclosure case 1).
        }
        guard let text = try? await onDeviceComposer.compose(from: records) else { return nil }
        let announcement = settings.reasoningBackend.usesNetwork ? failureAnnouncementIfNeeded(locale: locale) : nil
        return ReasoningComposeResult(text: text, backendUsed: .onDevice, announcement: announcement)
    }

    /// Looks up the credential slot matching `settings`'s active backend/provider.
    private func credential(for settings: Settings) -> String? {
        switch settings.reasoningBackend {
        case .onDevice: nil
        case .cloud:
            switch settings.cloudProvider {
            case .anthropic: credentialStore.credential(for: .anthropic)
            case .openai: credentialStore.credential(for: .openai)
            case .nvidiaNIM: credentialStore.credential(for: .nvidiaNIM)
            case nil: nil
            }
        case .localEndpoint: credentialStore.credential(for: .localEndpoint)
        }
    }

    /// While the breaker is tripped, only every `probeCadence`th tick
    /// actually attempts the network — every other tick goes straight to
    /// on-device, bounding cost against a still-down endpoint.
    private func shouldAttemptNetwork() -> Bool {
        guard breakerTripped else { return true }
        probeTickCounter += 1
        return probeTickCounter % Self.probeCadence == 0
    }

    /// Counts one network composer failure toward the breaker-trip threshold.
    private func recordFailure() {
        consecutiveFailures += 1
    }

    /// Trips the breaker and returns the disclosure string exactly once,
    /// on the failure that crosses the threshold — every failure after that
    /// returns `nil` until a recovery resets the count.
    private func failureAnnouncementIfNeeded(locale: Locale) -> String? {
        guard consecutiveFailures >= 2, !breakerTripped else { return nil }
        breakerTripped = true
        probeTickCounter = 0
        return LocalizedCatalog.string(
            "Cloud descriptions aren't responding, so SenseBridge is continuing with on-device descriptions.",
            locale: locale
        )
    }

    /// Clears the breaker and returns the recovery string exactly once, on
    /// the probe tick that first succeeds again.
    private func recoveryAnnouncementIfNeeded(locale: Locale) -> String? {
        guard breakerTripped else { return nil }
        breakerTripped = false
        consecutiveFailures = 0
        probeTickCounter = 0
        return LocalizedCatalog.string(
            "Cloud descriptions are working again.", locale: locale
        )
    }
}
