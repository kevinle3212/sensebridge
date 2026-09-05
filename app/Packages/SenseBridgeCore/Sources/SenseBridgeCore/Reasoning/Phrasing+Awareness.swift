import Foundation

/// Directional and thermal awareness copy.
///
/// A separate file from `Phrasing.swift` for the same reason
/// `AmbientAwarenessSession` is split across three: SwiftLint's `file_length`
/// and `type_body_length` gates. The doctrine is unchanged — this is still the
/// single place spoken output is composed, and every template here is a
/// String Catalog format string rather than concatenation, so `es` and `vi`
/// can reorder around the subject.
public extension Phrasing {
    /// The subject, qualified by which side of the user it was measured on.
    ///
    /// A **format string**, not `subject + " on your left"`. The side lands
    /// before the subject in Spanish and after it in Vietnamese, and English
    /// concatenation would pin all three to English word order — the exact
    /// failure the pinned-translation doctrine in
    /// docs/superpowers/specs/2026-07-19-LANGUAGE-SUPPORT-DESIGN.md exists to
    /// prevent.
    ///
    /// - Parameters:
    ///   - subject: A subject phrase, typically from
    ///     ``Phrasing/somethingAhead(atDistance:locale:)``. Still unhedged —
    ///     pass the result to ``Phrasing/describe(subject:certainty:locale:)``
    ///     exactly as you would the unqualified subject.
    ///   - zone: Which zone the measurement came from.
    ///   - locale: The user's chosen language.
    /// - Returns: A qualified subject, still carrying no hedge of its own.
    func subject(_ subject: String, in zone: AwarenessZone, locale: Locale = .current) -> String {
        let template = LocalizedCatalog.string(Self.zoneTemplateKey(for: zone), locale: locale)
        return String(format: template, subject)
    }

    /// The measured-distance subject **without** a direction in it, for the
    /// caller that is about to add one.
    ///
    /// ``Phrasing/somethingAhead(atDistance:locale:)`` ends in "ahead" in
    /// English, so qualifying it with a zone produced two directions in one
    /// sentence — "something about 1.2 meters ahead on your left", and for the
    /// centre zone the outright stutter "…ahead straight ahead". A listener
    /// cannot resolve which of the two to act on, and the stutter reads as a
    /// synthesizer fault, which teaches them to discount the channel.
    ///
    /// The Spanish and Vietnamese translations of that key had already dropped
    /// the direction, so English was the outlier rather than the translations.
    /// This key carries no direction in any of the three.
    ///
    /// - Returns: An unhedged subject, to be passed to
    ///   ``subject(_:in:locale:)`` and only then to
    ///   ``Phrasing/describe(subject:certainty:locale:)``.
    func somethingAway(atDistance distance: String, locale: Locale = .current) -> String {
        let template = LocalizedCatalog.string("something about %@ away", locale: locale)
        return String(format: template, distance)
    }

    /// What to say when a check measured something, but nothing nearer than the
    /// user's own alert distance.
    ///
    /// The sentence that used to cover this case was
    /// ``Phrasing/nothingRecognized(locale:)`` — "Nothing recognizable was
    /// found." — which is false twice over on this path: recognition never ran
    /// at all, and depth sensing *did* return a distance. A listener who hears
    /// "nothing was found" after a successful measurement learns that the app
    /// says "nothing" when it means "nothing close", which is precisely the
    /// habit that makes a real alert ignorable.
    ///
    /// Carries no hedge, for the same reason
    /// ``Phrasing/nearestMeasurementMovedAway(locale:)`` carries none: it
    /// reports a number this app produced rather than a claim about what is
    /// out there. "about" stays, because the number itself is a percentile of a
    /// noisy distribution — see ``Phrasing/somethingAhead(atDistance:locale:)``.
    ///
    /// - Parameters:
    ///   - distance: Already formatted for the listener's locale by the caller.
    ///   - locale: The user's chosen language.
    func nearestMeasurement(atDistance distance: String, locale: Locale = .current) -> String {
        let template = LocalizedCatalog.string("The nearest distance I could measure is about %@.", locale: locale)
        return String(format: template, distance)
    }

    /// What to say when a measurement moved from one proximity band to a nearer
    /// one while the alert was already active.
    ///
    /// Exists because the existing alert fires once, on the alerting
    /// transition, and then says nothing until the reading clears. A listener
    /// walking toward a wall hears one sentence at three metres and silence
    /// after that, which is indistinguishable from the session having stopped.
    ///
    /// Carries the new distance rather than a bare "closer": "closer" is a
    /// comparison the listener has to hold in their head against a number they
    /// heard several seconds ago.
    ///
    /// - Returns: A complete sentence, already hedged — it makes a claim about
    ///   the physical world and so must not be handed out unhedged the way a
    ///   subject is.
    func measurementCameNearer(
        toDistance distance: String,
        certainty: Certainty = .medium,
        locale: Locale = .current
    ) -> String {
        let template = LocalizedCatalog.string("something now about %@ ahead", locale: locale)
        return describe(subject: String(format: template, distance), certainty: certainty, locale: locale)
    }

    /// What to say when hands-free awareness ends, summarising the session.
    ///
    /// A statement about what the app did, not about what was out there: it
    /// counts alerts the app raised and minutes it ran, both of which are
    /// facts about this process. The tempting summary — "you passed four
    /// obstacles" — is a claim about the world built from readings that were
    /// never verified, and `audits/AGENT-GUIDE.md` names that archetype
    /// Critical.
    ///
    /// - Parameters:
    ///   - alerts: How many awareness alerts were raised.
    ///   - duration: How long the session ran, already formatted for the
    ///     listener's locale by the caller.
    ///   - locale: The user's chosen language.
    func sessionSummary(alerts: Int, duration: String, locale: Locale = .current) -> String {
        // Worded so no count agrees with a noun: "…and raised 1 alerts" was the
        // previous output for every single-alert session. A `variations.plural`
        // block would also fix the grammar, but `LocalizedCatalog`'s raw
        // `.xcstrings` path — the one SwiftPM builds and the whole test suite
        // use — models only flat `stringUnit`s, so every plural key would
        // silently fall back to English there. A sentence that needs no plural
        // is correct on both paths and in all three languages.
        let template = LocalizedCatalog.string(
            "Hands-free awareness ran for %1$@. Alerts raised: %2$@.",
            locale: locale
        )
        let count = Self.numberFormatter(for: locale).string(from: NSNumber(value: alerts)) ?? "\(alerts)"
        return String(format: template, duration, count)
    }

    /// The catalog key for one zone's qualifier template.
    ///
    /// `center` has a template of its own rather than returning the subject
    /// untouched: "straight ahead" is a real distinction from an unqualified
    /// subject once the other two zones exist, and a listener who never hears
    /// it cannot tell "in front of you" from "the app did not resolve a side".
    private static func zoneTemplateKey(for zone: AwarenessZone) -> String {
        switch zone {
        case .leading: "%@ on your left"
        case .center: "%@ straight ahead"
        case .trailing: "%@ on your right"
        }
    }

    /// A locale-aware number formatter, so a count is spoken with the digits and
    /// grouping the listener's language uses rather than this file's.
    static func numberFormatter(for locale: Locale) -> NumberFormatter {
        let formatter = NumberFormatter()
        formatter.locale = locale
        formatter.numberStyle = .decimal
        return formatter
    }
}
