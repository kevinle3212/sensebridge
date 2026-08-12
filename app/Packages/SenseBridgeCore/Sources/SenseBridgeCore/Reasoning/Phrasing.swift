import Foundation

/// Confidence bucket for a single perception, mapped to a hedge strength.
/// There is no "certain" case — see docs/SAFETY-FRAMING.md: SenseBridge
/// never asserts unearned certainty about the physical world.
public enum Certainty: Sendable, Equatable, CaseIterable {
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

    /// What to say when perception ran and recognized nothing.
    ///
    /// Deliberately a statement about *this app's perception*, never about the
    /// world: "nothing was recognized" is falsifiable and honest, whereas
    /// "the way ahead is clear" — or any hedged variant of it — asserts an
    /// absence the app cannot observe. `audits/AGENT-GUIDE.md` names that
    /// second form as the Critical archetype, and hedging the verb does not
    /// rescue it, because the *claim* is still absence.
    ///
    /// Lives here rather than at a call site so it inherits what every other
    /// phrase here inherits: one reviewed es/vi translation from the String
    /// Catalog, and one place to change if the doctrine changes.
    public func nothingRecognized(locale: Locale = .current) -> String {
        LocalizedCatalog.string("Nothing recognizable was found.", locale: locale)
    }

    /// The subject to use when depth sensing measured something but
    /// perception could not name it — which is the normal case, since LiDAR
    /// resolves distance and says nothing about identity.
    ///
    /// A subject, not a sentence: it is meant to be passed to
    /// `describe(subject:certainty:)` so it inherits the hedge like any other.
    /// Lives here rather than as a literal at the call site for the same
    /// reason as `nothingRecognized(locale:)` — one reviewed es/vi translation
    /// instead of an English string leaking into a translated sentence.
    public func somethingAhead(locale: Locale = .current) -> String {
        LocalizedCatalog.string("something ahead", locale: locale)
    }

    /// The same subject, carrying the measured distance.
    ///
    /// "about" is load-bearing and is not padding: LiDAR returns a
    /// distribution, this app reports a percentile of it, and the mount angle
    /// is uncalibrated. Stating a bare figure would claim a precision that
    /// none of those three steps earned — see docs/SAFETY-FRAMING.md.
    /// `distance` is formatted by the caller's `MeasurementFormatter` so the
    /// unit follows the reader's locale rather than this file's.
    public func somethingAhead(atDistance distance: String, locale: Locale = .current) -> String {
        let template = LocalizedCatalog.string("something about %@ ahead", locale: locale)
        return String(format: template, distance)
    }

    /// What to say when a previously reported near reading has moved away.
    ///
    /// Deliberately a statement about **the measurement**, not the world. The
    /// tempting phrasing — "the way ahead is clear now" — asserts an absence
    /// the app cannot observe, which `audits/AGENT-GUIDE.md` names as its
    /// Critical archetype and which hedging the verb does not rescue. This
    /// sentence is falsifiable: a number the app itself produced got larger.
    ///
    /// Unlike the phrases above, this is a whole sentence rather than a
    /// subject: there is no hedge to apply, because it makes no claim about
    /// what is or is not there.
    public func nearestMeasurementMovedAway(locale: Locale = .current) -> String {
        LocalizedCatalog.string("The nearest measured distance is further away now.", locale: locale)
    }

    /// The three hedge templates, keyed by the certainty they apply to,
    /// **without** the `%@` placeholder — the fragment form
    /// `ReasoningOutputValidator` matches against a remote response to catch
    /// a model that hedged on its own (which would otherwise get
    /// double-hedged by `describe(subject:certainty:)`). Kept alongside
    /// `hedgeTemplate(for:locale:)` rather than duplicated, so the two can
    /// never drift — see docs/superpowers/specs/2026-08-11-awareness-ai-tiers-design.md
    /// "The output validator".
    public static func hedgeFragments(locale: Locale) -> [String] {
        Certainty.allCases.map { certainty in
            hedgeTemplate(for: certainty, locale: locale)
                .replacing(" %@.", with: "")
                .replacing("%@.", with: "")
        }
    }

    /// What to say when depth sensing ran and produced no usable reading —
    /// distinct from `nothingRecognized(locale:)`, which is about
    /// perception finding nothing. `DepthStatistics` treats `nil` as "could
    /// not measure", never "the way is clear"; this string is the spoken
    /// form of that distinction, for `ObstacleAwarenessView`'s one-shot
    /// check.
    public func couldNotMeasure(locale: Locale = .current) -> String {
        LocalizedCatalog.string("Couldn't take a measurement. Try again.", locale: locale)
    }

    /// The localized format-string template for one certainty bucket, still
    /// carrying its `%@` placeholder. The single source both
    /// `describe(subject:certainty:)` and `hedgeFragments(locale:)` build
    /// from, so the sentence form and the fragment form can never drift
    /// apart.
    private static func hedgeTemplate(for certainty: Certainty, locale: Locale) -> String {
        let key = switch certainty {
        case .low: "there might be %@."
        case .medium: "it looks like there's %@."
        case .high: "it looks like there's likely %@."
        }
        return LocalizedCatalog.string(key, locale: locale)
    }
}
