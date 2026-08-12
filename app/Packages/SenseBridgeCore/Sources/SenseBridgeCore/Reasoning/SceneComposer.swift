import Foundation

/// Composes a hedged natural-language scene description from structured
/// perception records. A Foundation-Models-backed implementation lives at
/// the App layer (it needs `SystemLanguageModel`, which this
/// device-agnostic package does not depend on) — see docs/ARCHITECTURE.md
/// "On-device AI pipeline". Implementations only ever see the labels/text
/// Perception already extracted, never raw pixels.
public protocol SceneComposer: Sendable {
    func compose(from records: [PerceptionRecord]) async throws -> String
}

/// Fallback composer for devices without Apple Intelligence support: reads
/// back the perceived labels directly instead of a composed sentence.
/// Still hedged — see docs/SAFETY-FRAMING.md.
public struct LabelListSceneComposer: SceneComposer {
    private let phrasing: Phrasing
    private let locale: Locale
    private let detail: SpokenDetail

    /// - Parameter detail: How many objects a composed sentence names and how
    ///   long its label list may run — see `SpokenDetail`.
    public init(phrasing: Phrasing = Phrasing(), locale: Locale = .current, detail: SpokenDetail = .standard) {
        self.phrasing = phrasing
        self.locale = locale
        self.detail = detail
    }

    /// Groups `records`' detected objects by certainty bucket and speaks one
    /// hedged sentence per bucket, most-confident first — see `SceneComposer`.
    /// `throws` fulfills that protocol's requirement even though this
    /// implementation never throws.
    public func compose(
        from records: [PerceptionRecord]
    ) async throws -> String { // swiftlint:disable:this unneeded_throws_rethrows
        // Bucket, don't flatten. Joining every label into one list and
        // applying a single certainty to the sentence would speak a doubtful
        // detection under a confident detection's hedge. Grouping keeps each
        // object at the certainty its own detector confidence earned.
        var byCertainty = [Certainty: [String]]()
        for record in records {
            guard case let .detectedObject(label, confidence) = record.kind else { continue }
            byCertainty[Phrasing.certainty(forConfidence: confidence), default: []].append(label)
        }
        guard !byCertainty.isEmpty else { return phrasing.nothingRecognized(locale: locale) }

        // Most-confident bucket first: the thing the app is least unsure about
        // arrives before the channel is interrupted or the user walks on.
        let ordered: [Certainty] = [.high, .medium, .low]
        return ordered.compactMap { certainty -> String? in
            guard let labels = byCertainty[certainty], !labels.isEmpty else { return nil }
            let subject = Array(labels.prefix(detail.maximumLabels))
                .formatted(.list(type: .and).locale(locale))
            return phrasing.describe(subject: subject, certainty: certainty, locale: locale)
        }.joined(separator: " ")
    }
}
