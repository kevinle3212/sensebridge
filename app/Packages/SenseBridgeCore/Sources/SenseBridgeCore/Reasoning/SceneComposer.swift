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

    public init(phrasing: Phrasing = Phrasing(), locale: Locale = .current) {
        self.phrasing = phrasing
        self.locale = locale
    }

    // `throws` fulfills the SceneComposer protocol requirement, even though this implementation never throws.
    // swiftlint:disable:next unneeded_throws_rethrows
    public func compose(from records: [PerceptionRecord]) async throws -> String {
        let descriptions = records.compactMap { record -> String? in
            switch record.kind {
            case let .detectedObject(label, confidence):
                return phrasing.describe(
                    subject: label,
                    certainty: Phrasing.certainty(forConfidence: confidence),
                    locale: locale
                )
            case .detectedSound, .depthReading, .recognizedText:
                return nil
            }
        }
        guard !descriptions.isEmpty else {
            return LocalizedCatalog.string("Nothing recognizable was found.", locale: locale)
        }
        return descriptions.joined(separator: " ")
    }
}
