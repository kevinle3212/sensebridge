import Foundation

/// A hardware or virtual source of raw sensor data (camera frame, depth map,
/// audio buffer). Concrete sources (camera, LiDAR, microphone, a future
/// glasses feed) each conform to this protocol; nothing above the Perception
/// layer knows which concrete source produced the data.
public protocol SensingSource: Sendable {
    associatedtype Output: Sendable

    /// Starts producing values. Implementations must not block the caller;
    /// long-running capture happens off the main actor.
    func start() async throws -> AsyncThrowingStream<Output, Error>

    /// Stops production and releases any capture resources.
    func stop() async
}
