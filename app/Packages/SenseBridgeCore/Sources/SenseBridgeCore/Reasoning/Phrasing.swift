import Foundation

/// Confidence bucket for a single perception, mapped to a hedge strength.
/// There is no "certain" case — see docs/SAFETY-FRAMING.md: SenseBridge
/// never asserts unearned certainty about the physical world.
public enum Certainty: Sendable, Equatable {
    case low, medium, high
}

/// Turns a raw detection into hedged natural language. This is the single
/// place that composes spoken/caption output, so it is the enforcement
/// point for the "awareness, not safety" doctrine: every phrase this type
/// produces carries a hedge, regardless of how confident the underlying
/// detector was. Hedge templates are format strings (never concatenation)
/// loaded from the package's String Catalog, so es/vi grammars can reorder
/// around the subject — see the pinned translations in
/// docs/superpowers/specs/2026-07-19-LANGUAGE-SUPPORT-DESIGN.md
/// "Doctrine-pinned strings".
public struct Phrasing: Sendable {
    // Empty but required: a public init is needed for cross-module init; nothing to initialize.
    // swiftlint:disable:next no_empty_block
    public init() {}

    /// Buckets a raw detector confidence score (0...1) into a `Certainty`.
    public static func certainty(forConfidence confidence: Double) -> Certainty {
        switch confidence {
        case ..<0.5: .low
        case ..<0.8: .medium
        default: .high
        }
    }

    /// Composes a hedged description of a detected subject in `locale`.
    /// Never returns an unhedged assertion — "high" certainty still says
    /// "likely" (or the target language's equivalent hedge), never a bare
    /// statement of fact.
    public func describe(subject: String, certainty: Certainty, locale: Locale = .current) -> String {
        let template = Self.hedgeTemplate(for: certainty, locale: locale)
        return String(format: template, subject)
    }

    private static func hedgeTemplate(for certainty: Certainty, locale: Locale) -> String {
        let key = switch certainty {
        case .low: "there might be %@."
        case .medium: "it looks like there's %@."
        case .high: "it looks like there's likely %@."
        }
        return LocalizedCatalog.string(key, locale: locale)
    }
}
