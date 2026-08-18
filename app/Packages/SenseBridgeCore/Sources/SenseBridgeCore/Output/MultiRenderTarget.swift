import Foundation

/// Fans one `OutputMessage` out to every `RenderChannel` an `OutputProfile`
/// prefers, concurrently — haptic delivery must not wait on speech, or vice
/// versa. Holds only `Sendable` references to other `RenderTarget`s, so a
/// plain `Sendable` struct is enough; there's no framework state of its own
/// to protect with an actor.
public struct MultiRenderTarget: RenderTarget, Sendable {
    private let profile: OutputProfile
    private let targets: [RenderChannel: any RenderTarget]

    /// Channels `profile` prefers but that have no registered target here —
    /// what a caller sees when it registers fewer targets than the profiles it
    /// offers, and what every profile looked like before speech, caption, and
    /// haptic targets all existed. Rendering silently skips these channels;
    /// this property makes that gap observable so the App layer can refuse to
    /// offer a profile that would otherwise degrade to nothing on some of its
    /// channels.
    public let unsupportedChannels: Set<RenderChannel>

    /// Creates a fan-out target for `profile`, delivering through whichever
    /// of `targets` match its `preferredChannels`. Channels in `targets` that
    /// `profile` doesn't prefer are simply unused, not an error.
    public init(profile: OutputProfile, targets: [RenderChannel: any RenderTarget]) {
        self.profile = profile
        self.targets = targets
        unsupportedChannels = profile.preferredChannels.subtracting(targets.keys)
    }

    /// Delivers `message` to every registered target for `profile`'s
    /// preferred channels, concurrently via a task group.
    public func render(_ message: OutputMessage) async {
        await withTaskGroup(of: Void.self) { group in
            for channel in profile.preferredChannels {
                guard let target = targets[channel] else { continue }
                group.addTask { await target.render(message) }
            }
        }
    }
}
