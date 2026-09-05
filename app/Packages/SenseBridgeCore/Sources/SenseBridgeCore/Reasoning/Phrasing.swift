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

    /// The same hedge ladder, for what the microphone heard rather than what
    /// the camera saw. Modality is doctrine, not decoration: "it looks like
    /// there's a fire alarm" over a *heard* alarm claims visual evidence the
    /// app does not have, so sounds get their own reviewed templates instead
    /// of reusing the sight ones.
    ///
    /// - Parameters:
    ///   - subject: Article-first noun phrase for the heard thing, exactly as
    ///     ``describe(subject:certainty:locale:)`` expects ("a fire alarm").
    ///   - certainty: Bucket for the detector's own confidence — see
    ///     ``certainty(forConfidence:)``.
    public func describeSound(subject: String, certainty: Certainty, locale: Locale = .current) -> String {
        let template = Self.soundHedgeTemplate(for: certainty, locale: locale)
        return String(format: template, subject)
    }

    /// What to say when OCR found text in the scene.
    ///
    /// Fixed at the medium hedge on purpose: unlike objects and sounds, a
    /// recognized line arrives without a confidence value
    /// (`PerceptionRecord.Kind.recognizedText` carries none), so there is no
    /// evidence to scale a stronger or weaker hedge from — and quoting what
    /// the recognizer may have misread demands caution regardless. The quote
    /// itself is truncated by the caller to keep the sentence speakable.
    public func recognizedTextVisible(quote: String, locale: Locale = .current) -> String {
        let template = LocalizedCatalog.string("it looks like there's text that reads %@.", locale: locale)
        return String(format: template, quote)
    }

    /// Longest span of recognized text quoted inside one spoken sentence.
    /// Longer than any real sign line and short enough that even a garbage
    /// recognition stays a momentary interruption rather than a recital.
    static let maximumRecognizedTextQuoteLength = 48

    /// What to say when perception ran and recognized nothing.
    ///
    /// Deliberately a statement about *this app's perception*, never about the
    /// world: "the way ahead is clear" — or any hedged variant of it — asserts
    /// an absence the app cannot observe, which `audits/AGENT-GUIDE.md` names
    /// as the Critical archetype; hedging the verb does not rescue it, because
    /// the *claim* is still absence.
    ///
    /// The subjectless voice matches every other error phrase here ("Couldn't
    /// take a measurement. Try again."), and replaced the passive "Nothing
    /// recognizable was found.", which listeners read as "there was nothing
    /// there" even while depth sensing held an obstacle the classifier could
    /// not name (2026-08-25). Naming the failed act — the naming — keeps the
    /// perception scope without inviting the world-absence reading.
    ///
    /// Lives here rather than at a call site so it inherits what every other
    /// phrase here inherits: one reviewed es/vi translation from the String
    /// Catalog, and one place to change if the doctrine changes.
    public func nothingRecognized(locale: Locale = .current) -> String {
        LocalizedCatalog.string("Couldn't name anything.", locale: locale)
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

    /// The sound-modality counterpart of ``hedgeFragments(locale:)`` — the
    /// fragment form of ``describeSound(subject:certainty:locale:)``'s
    /// templates, kept beside them for the same never-drifts reason. Sounds
    /// never leave the device (the wire contract forbids it), so these do not
    /// feed `ReasoningOutputValidator`; they exist so a checker can ask
    /// "does this spoken output carry one of the app's own hedges?" about
    /// every modality alike.
    public static func soundHedgeFragments(locale: Locale) -> [String] {
        Certainty.allCases.map { certainty in
            soundHedgeTemplate(for: certainty, locale: locale)
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

    /// The same phrase, capitalized for the screen.
    ///
    /// The hedge templates are deliberately lowercase — they are composed into
    /// speech, where capitalization is meaningless, and they have to survive
    /// being embedded mid-sentence. On screen that same string renders as a
    /// sentence starting in lowercase, which reads as a typo rather than as
    /// caution.
    ///
    /// Applied at the **display** boundary only, so it changes nothing a
    /// synthesizer receives and requires no re-pinning of the doctrine strings
    /// in `en`/`es`/`vi` — which is what made this look expensive enough to
    /// defer. Uppercases exactly the first character with `locale`'s own
    /// casing rules; `localizedCapitalized` would title-case every word, which
    /// is wrong in all three shipped languages.
    public static func forDisplay(_ phrase: String, locale: Locale = .current) -> String {
        guard let first = phrase.first else { return phrase }
        return String(first).uppercased(with: locale) + phrase.dropFirst()
    }

    /// What to say when hands-free awareness stops because the app left the
    /// screen, and will start again on return.
    ///
    /// Carries no hedge, and correctly so: it is a statement about this app's
    /// own state, not a claim about the physical world, so there is nothing to
    /// be uncertain about. It lives here anyway because this type is the single
    /// place spoken output is composed — a reviewer auditing what the app can
    /// say should not have to find operational copy somewhere else.
    public func awarenessStoppedOffScreen(locale: Locale = .current) -> String {
        LocalizedCatalog.string(
            """
            Hands-free awareness stopped because SenseBridge is no longer on \
            screen. It will start again when you come back.
            """,
            locale: locale
        )
    }

    /// What to say when hands-free awareness has restarted by itself.
    ///
    /// The counterpart to `awarenessStoppedOffScreen(locale:)`: a user told the
    /// session would come back needs to hear that it did, or the promise is
    /// indistinguishable from a broken one.
    public func awarenessRunningAgain(locale: Locale = .current) -> String {
        LocalizedCatalog.string("Hands-free awareness is running again.", locale: locale)
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

    /// The sound-modality counterpart of `hedgeTemplate(for:locale:)` — same
    /// ladder shape, heard-not-seen verb, sourced from the same String Catalog
    /// so es/vi get reviewed translations rather than English leakage.
    private static func soundHedgeTemplate(for certainty: Certainty, locale: Locale) -> String {
        let key = switch certainty {
        case .low: "there might be the sound of %@."
        case .medium: "it sounds like there's %@."
        case .high: "it sounds like there's likely %@."
        }
        return LocalizedCatalog.string(key, locale: locale)
    }
}
