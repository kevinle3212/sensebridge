import Foundation

/// Why a user-supplied self-hosted endpoint URL was rejected.
public enum EndpointURLError: Error, Sendable, Equatable {
    case invalidURL
    case invalidScheme
    case embeddedCredentials
}

/// Validates and normalizes a self-hosted endpoint URL at the trust
/// boundary, before it is ever saved to `Settings.localEndpointURL` or used
/// in a request. See
/// docs/superpowers/specs/2026-08-11-awareness-ai-tiers-design.md
/// "Self-hosted endpoint — network-layer specifics".
public enum EndpointURLNormalizer {
    /// The OpenAI-compatible chat-completions route every supported
    /// self-hosted server (Ollama, LM Studio, vLLM) and NVIDIA NIM expose.
    private static let chatCompletionsPath = "/v1/chat/completions"

    /// Normalizes `raw` into a request-ready `URL`.
    ///
    /// Accepts either a bare host (`http://192.168.1.20:11434`) or an
    /// already-complete path — a user pasting either form must work. Rejects
    /// any scheme other than `http`/`https` and any URL carrying embedded
    /// `user`/`password` components: `Settings.localEndpointURL` is plain
    /// `UserDefaults`, not Keychain, so credentials must never be accepted
    /// into that field even if a user pastes them there.
    public static func normalize(_ raw: String) throws -> URL {
        guard let components = URLComponents(string: raw), let scheme = components.scheme?.lowercased()
        else {
            throw EndpointURLError.invalidURL
        }
        guard scheme == "http" || scheme == "https" else {
            throw EndpointURLError.invalidScheme
        }
        guard components.user == nil, components.password == nil else {
            throw EndpointURLError.embeddedCredentials
        }
        var normalized = components
        if normalized.path.isEmpty || normalized.path == "/" {
            normalized.path = chatCompletionsPath
        } else if !normalized.path.hasSuffix(chatCompletionsPath) {
            let base = normalized.path.hasSuffix("/") ? String(normalized.path.dropLast()) : normalized.path
            normalized.path = base + chatCompletionsPath
        }
        guard let url = normalized.url else { throw EndpointURLError.invalidURL }
        return url
    }
}
