import Foundation

/// Which reasoning path composes scene descriptions. `.onDevice` is the
/// default and the only one active until the user explicitly opts into a
/// network path — see docs/superpowers/specs/2026-08-11-awareness-ai-tiers-design.md.
public enum ReasoningBackend: String, Sendable, Codable, CaseIterable {
    case onDevice, localEndpoint, cloud

    /// Whether this backend sends anything off the device. Drives the
    /// in-flight/cost-control UI and the resolver's circuit breaker — see
    /// `ReasoningComposerResolver`. Data, not a second protocol: see the
    /// spec's "Unify on SceneComposer" section for why.
    public var usesNetwork: Bool {
        self == .localEndpoint || self == .cloud
    }
}

/// A BYOK cloud provider. `.nvidiaNIM` covers both NVIDIA's hosted endpoint
/// and a self-hosted NIM container — see `OpenAICompatibleSceneComposer`.
public enum CloudProvider: String, Sendable, Codable, CaseIterable {
    case anthropic, openai, nvidiaNIM
}
