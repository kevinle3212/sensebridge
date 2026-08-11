import Foundation

/// Runs two `SoundService`s concurrently on one capture and keeps the
/// single highest-confidence hit — avoids an arbitrary primary/fallback
/// ordering between two independently-trained models (Apple's built-in
/// taxonomy and the bundled Create ML classifier), per
/// `docs/superpowers/specs/2026-08-04-alpha-scaffolding-design.md`.
public struct CombinedSoundClassifier: SoundService, Sendable {
    private let primary: any SoundService
    private let secondary: any SoundService

    public init(primary: any SoundService, secondary: any SoundService) {
        self.primary = primary
        self.secondary = secondary
    }

    public func process(_ input: Data) async throws -> [PerceptionRecord] {
        async let primaryRecords = primary.process(input)
        async let secondaryRecords = secondary.process(input)
        let all = try await primaryRecords + secondaryRecords

        guard let best = all.max(by: { confidence(of: $0) < confidence(of: $1) }) else {
            return []
        }
        return [best]
    }

    private func confidence(of record: PerceptionRecord) -> Double {
        guard case let .detectedSound(_, confidence) = record.kind else { return 0 }
        return confidence
    }
}
