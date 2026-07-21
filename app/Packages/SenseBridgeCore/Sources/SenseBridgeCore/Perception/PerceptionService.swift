import Foundation

/// A service that turns one kind of raw sensor input into `PerceptionRecord`
/// values. Concrete implementations (Vision OCR, Vision object detection,
/// Sound Analysis, ARKit depth) live alongside the framework they wrap;
/// this protocol is what lets Reasoning depend on "some perception
/// service" instead of a specific Apple framework.
public protocol PerceptionService: Sendable {
    /// Extracts `PerceptionRecord` values from raw sensor `input`.
    func process(_ input: Data) async throws -> [PerceptionRecord]
}
