import Foundation
import SoundAnalysis

/// Classifies captured audio using Apple's built-in on-device sound
/// taxonomy — no training, no bundled model. Filtered to a curated alpha
/// subset of high-value sounds rather than surfacing all ~300 classes Apple
/// ships, so "there might be a smoke alarm" never shares a screen with
/// "there might be a wind chime".
///
/// **Known limitation, deliberately not papered over:** the exact
/// identifier strings below must match Apple's published `SNClassifySoundRequest`
/// taxonomy for the SDK this ships against — verify them against the current
/// Xcode SDK's documentation before relying on this in a build, the same way
/// `ObjectClassificationService` already documents a taxonomy-matching
/// caveat for Vision's classifier.
public struct BuiltInSoundClassifier: SoundService, Sendable {
    /// The curated alpha subset, matching
    /// `docs/superpowers/specs/2026-08-04-alpha-scaffolding-design.md`'s
    /// target class list.
    static let targetClassNames: Set<String> = [
        "fire_alarm", "smoke_detector", "doorbell", "knock",
        "dog_bark", "baby_cry", "car_horn", "siren",
        "glass_shatter", "telephone_bell_ringing"
    ]

    /// Language the reported labels are phrased in. Wording only — which
    /// sounds are recognized and the confidence floor they must clear are
    /// identical in every language.
    public let locale: Locale

    /// Creates a classifier over Apple's built-in sound taxonomy.
    ///
    /// Cheap and side-effect free — no model is loaded until `process` runs.
    public init(locale: Locale = .current) {
        self.locale = locale
    }

    /// Classifies a WAV buffer and returns records only for the curated
    /// `targetClassNames` subset that clears the runner's confidence floor.
    /// - Parameter input: WAV-encoded audio; an empty buffer yields no records.
    /// - Returns: One `.detectedSound` record per surviving match, phrased in `locale`.
    /// - Throws: Whatever building the request or running the analysis throws.
    public func process(_ input: Data) async throws -> [PerceptionRecord] {
        let request = try SNClassifySoundRequest(classifierIdentifier: .version1)
        return try await SoundClassificationRunner.classify(
            input, using: request, topClassNames: Self.targetClassNames, locale: locale
        )
    }
}
