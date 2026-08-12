import Foundation
import SoundAnalysis

/// Runs one `SNClassifySoundRequest` against WAV `Data` and returns the
/// matching `.detectedSound` records. Shared by `BuiltInSoundClassifier` and
/// `CustomSoundClassifier` — the two differ only in which request they
/// construct (Apple's built-in taxonomy vs. a bundled `MLModel`), not in how
/// the analysis is run or the results are collected.
public enum SoundClassificationRunner {
    /// `SNAudioFileAnalyzer` requires a file URL, not `Data` — `audio` is
    /// written to a temporary file and deleted before this returns, exactly
    /// as `MicrophoneSensingSource` does for the recording that produced it.
    /// Only classifications in `topClassNames` are returned; everything else
    /// in the request's (much larger) taxonomy is discarded before it ever
    /// becomes a spoken claim.
    ///
    /// `public`, not `internal`: `BuiltInSoundClassifier` (same module) uses
    /// this, but so does `CustomSoundClassifier`, which lives in the App
    /// target rather than this package — its bundled `.mlmodel`'s
    /// Xcode-generated Swift class only exists in the App module's compiled
    /// output, the same reason `FoundationModelsSceneComposer` lives outside
    /// this package. See `docs/superpowers/specs/2026-08-04-alpha-scaffolding-design.md`.
    /// Below this confidence a hit is dropped rather than spoken, matching
    /// `ObjectClassificationService.minimumPrecision`'s default — every other
    /// perception service in this app gates on evidence before a detection
    /// becomes a spoken claim, and Sound Alerts had no floor at all until an
    /// audit caught it: a near-zero-confidence match was being announced with
    /// the same hedge template as a confident one, which makes the hedge
    /// itself misleading rather than protective.
    public static let defaultMinimumConfidence: Double = 0.7

    /// Classifies a WAV buffer and returns only the matches worth acting on.
    ///
    /// - Parameters:
    ///   - audio: WAV-encoded audio. An empty buffer yields no records rather
    ///     than an error — silence is a valid observation, not a failure.
    ///   - request: The configured Sound Analysis request to run.
    ///   - topClassNames: Identifiers the caller cares about; everything else is
    ///     discarded before it can reach output.
    ///   - minimumConfidence: Floor a match must clear to be returned. Defaults
    ///     to ``defaultMinimumConfidence`` — see that property for why a floor
    ///     exists at all rather than relying on hedged phrasing.
    /// - Returns: Records for surviving matches, in the order produced.
    /// - Throws: Whatever writing the temporary file or running the analysis
    ///   throws.
    public static func classify(
        _ audio: Data,
        using request: SNClassifySoundRequest,
        topClassNames: Set<String>,
        minimumConfidence: Double = defaultMinimumConfidence
    ) async throws -> [PerceptionRecord] {
        guard !audio.isEmpty else { return [] }

        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("wav")
        try audio.write(to: tempURL)
        defer { try? FileManager.default.removeItem(at: tempURL) }

        let analyzer = try SNAudioFileAnalyzer(url: tempURL)
        let collector = ResultCollector()
        try analyzer.add(request, withObserver: collector)
        // The SDK's Objective-C `analyzeWithCompletionHandler:` is imported
        // as this async overload directly — no manual continuation needed.
        // `analyze()` (no arguments) still exists as the older synchronous,
        // blocking entry point; the async one is used here so this never
        // blocks the actor calling `classify(_:using:topClassNames:)`.
        _ = await analyzer.analyze()

        return collector.results.compactMap { result -> PerceptionRecord? in
            guard let best = result.classifications.first,
                  topClassNames.contains(best.identifier),
                  best.confidence >= minimumConfidence else { return nil }
            return PerceptionRecord(
                kind: .detectedSound(label: subjectPhrase(for: best.identifier), confidence: best.confidence),
                capturedAt: .now
            )
        }
    }

    /// Turns a bare, underscore-joined Sound Analysis identifier
    /// ("fire_alarm") into the article-first noun phrase
    /// `Phrasing.describe(subject:certainty:)` expects ("a fire alarm") —
    /// without it, a VoiceOver user hears the raw identifier read
    /// character-by-character, and the missing article breaks the es/vi hedge
    /// templates, which assume this shape. Forwards to `SpokenPhrase`, the
    /// single implementation this and
    /// `ObjectClassificationService.subjectPhrase(for:)` both use.
    static func subjectPhrase(for identifier: String) -> String {
        SpokenPhrase.subject(for: identifier)
    }

    /// Collects `SNClassificationResult`s off `SNAudioFileAnalyzer`'s
    /// delegate callbacks into an array `classify(_:using:topClassNames:)`
    /// can read once analysis completes.
    private final class ResultCollector: NSObject, SNResultsObserving, @unchecked Sendable {
        private(set) var results: [SNClassificationResult] = []

        func request(_: any SNRequest, didProduce result: any SNResult) {
            guard let classification = result as? SNClassificationResult else { return }
            results.append(classification)
        }

        /// Absorbs an analysis failure, leaving `results` empty.
        ///
        /// Required by `SNResultsObserving`; the error is intentionally not
        /// propagated. See the body for why.
        func request(_: any SNRequest, didFailWithError _: Error) {
            // Deliberately empty. A failed analysis yields no results, and
            // `classify` already reports that as an empty record set. Surfacing
            // the error here would mean announcing a guess about the physical
            // world on the strength of an analysis that did not complete.
        }
    }
}
