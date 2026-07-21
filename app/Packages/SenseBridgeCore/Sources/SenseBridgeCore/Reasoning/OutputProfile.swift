import Foundation

/// The set of channels a `RenderTarget` message should go out on.
public enum RenderChannel: String, Sendable, Codable {
    case speech, caption, haptic
}

/// Which senses a user relies on, selecting which `RenderChannel`s
/// Reasoning output should be delivered through (see docs/ARCHITECTURE.md
/// "Reasoning Layer"). A user may opt into more than one channel for
/// redundant output (see docs/ACCESSIBILITY.md).
public enum OutputProfile: String, Sendable, Codable, CaseIterable {
    case blind
    case deaf
    case deafBlind

    public var preferredChannels: Set<RenderChannel> {
        switch self {
        case .blind: [.speech]
        case .deaf: [.caption]
        case .deafBlind: [.haptic]
        }
    }
}
