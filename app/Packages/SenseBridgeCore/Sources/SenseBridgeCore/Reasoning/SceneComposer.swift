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

    /// Composes one hedged sentence per perception stream — sight, then
    /// sound, then text — each bucketed by its own detector certainty, so a
    /// scene with a chair, an alarm, and a sign is described as the one
    /// moment it was, not as three unrelated broadcasts. See `SceneComposer`.
    ///
    /// Depth records stay out on purpose: distance narration is
    /// `AwarenessEngine`'s job, and bolting a metre figure onto a scene list
    /// would restate a measurement this composer never took.
    public func compose(
        from records: [PerceptionRecord]
    ) async throws -> String { // swiftlint:disable:this unneeded_throws_rethrows
        let streams = bucketedStreams(from: records)

        guard !streams.objects.isEmpty || !streams.sounds.isEmpty || streams.firstTextLine != nil else {
            return phrasing.nothingRecognized(locale: locale)
        }

        // Most-confident bucket first within a stream, streams ordered
        // sight → sound → text: what the app is least unsure about arrives
        // before the channel is interrupted or the user walks on.
        let ordered: [Certainty] = [.high, .medium, .low]
        var sentences = ordered.compactMap { certainty -> String? in
            guard let labels = streams.objects[certainty], !labels.isEmpty else { return nil }
            return phrasing.describe(
                subject: subjectList(labels),
                certainty: certainty,
                locale: locale
            )
        }
        sentences += ordered.compactMap { certainty -> String? in
            guard let labels = streams.sounds[certainty], !labels.isEmpty else { return nil }
            return phrasing.describeSound(
                subject: subjectList(labels),
                certainty: certainty,
                locale: locale
            )
        }
        if let quote = streams.firstTextLine {
            sentences.append(phrasing.recognizedTextVisible(quote: quote, locale: locale))
        }
        return sentences.joined(separator: " ")
    }

    /// The three speakable streams from one frame's records: object labels and
    /// sound labels, each bucketed per its own detector's certainty, plus the
    /// first quotable text line. Bucketing is per modality — joining every
    /// label into one list under one hedge would speak a doubtful detection
    /// under a confident detection's certainty, and folding sounds into sight
    /// sentences would claim visual evidence for something only heard
    /// (docs/SAFETY-FRAMING.md).
    private struct Streams {
        var objects: [Certainty: [String]] = [:]
        var sounds: [Certainty: [String]] = [:]
        var firstTextLine: String?
    }

    /// Extracts ``Streams`` from one frame's records. Depth stays out — it is
    /// narrated by AwarenessEngine, not scene composition.
    private func bucketedStreams(from records: [PerceptionRecord]) -> Streams {
        var streams = Streams()
        for record in records {
            switch record.kind {
            case let .detectedObject(label, confidence):
                appendDeduplicated(
                    label,
                    to: &streams.objects,
                    bucketedBy: Phrasing.certainty(forConfidence: confidence)
                )
            case let .detectedSound(label, confidence):
                appendDeduplicated(
                    label,
                    to: &streams.sounds,
                    bucketedBy: Phrasing.certainty(forConfidence: confidence)
                )
            case let .recognizedText(text):
                // A blank recognition has nothing quotable — treating it as
                // present text would speak an empty quote.
                if streams.firstTextLine == nil {
                    let quote = Self.displayQuote(from: text)
                    if !quote.isEmpty {
                        streams.firstTextLine = quote
                    }
                }
            case .depthReading:
                break
            }
        }
        return streams
    }

    /// Adds `label` under `bucket` unless an earlier record already named it,
    /// so overlapping classifier passes read as one thing rather than two.
    private func appendDeduplicated(
        _ label: String,
        to buckets: inout [Certainty: [String]],
        bucketedBy bucket: Certainty
    ) {
        guard !buckets.values.flatMap(\.self).contains(label) else { return }
        buckets[bucket, default: []].append(label)
    }

    /// The spoken subject for up to ``SpokenDetail/maximumLabels`` labels —
    /// the same cap the pre-fusion implementation applied, now shared by both
    /// modalities so a busy room cannot outgrow a speakable sentence.
    private func subjectList(_ labels: [String]) -> String {
        Array(labels.prefix(detail.maximumLabels))
            .formatted(.list(type: .and).locale(locale))
    }

    /// Shortens recognized text to what fits inside one spoken sentence:
    /// first line only, newlines flattened, hard-capped at
    /// `Phrasing.maximumRecognizedTextQuoteLength` so even a garbage
    /// recognition stays a momentary interruption instead of a recital.
    static func displayQuote(from text: String) -> String {
        let firstLine = text.split(separator: "\n").first.map(String.init) ?? text
        let trimmed = firstLine.trimmingCharacters(in: .whitespaces)
        guard trimmed.count > Phrasing.maximumRecognizedTextQuoteLength else { return trimmed }
        return String(trimmed.prefix(Phrasing.maximumRecognizedTextQuoteLength)) + "…"
    }
}
