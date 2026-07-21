import Foundation

/// Delivers a composed message to the user through one sense. Speech is the
/// MVP target; caption and haptic targets arrive later without Reasoning
/// changing at all — see docs/ARCHITECTURE.md "Output Layer".
public protocol RenderTarget: Sendable {
    /// Delivers `message` to the user through this target's sense.
    func render(_ message: String) async
}
