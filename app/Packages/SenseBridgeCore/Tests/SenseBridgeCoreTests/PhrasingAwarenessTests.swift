import Foundation
import Testing
@testable import SenseBridgeCore

/// Whole-sentence coverage of the directional and session copy.
///
/// `PhrasingTests` checks that a hedge *prefixes* every phrase, which is why it
/// did not catch the defect these tests exist for: the alert composed from
/// `somethingAhead(atDistance:)` plus a zone qualifier read "…about 1.2 meters
/// ahead straight ahead" — correctly hedged, and nonsense. A prefix assertion
/// cannot see that. These assert the finished sentence.
struct PhrasingAwarenessTests {
    private let phrasing: Phrasing = .init()
    private let english: Locale = .init(identifier: "en")

    @Test
    func aZonedAlertNamesExactlyOneDirection() {
        // The composition `AmbientAwarenessSession` actually performs.
        for zone in AwarenessZone.allCases {
            let subject = phrasing.subject(
                phrasing.somethingAway(atDistance: "1.2 meters", locale: english),
                in: zone,
                locale: english
            )
            let sentence = phrasing.describe(subject: subject, certainty: .medium, locale: english)

            #expect(!sentence.contains("ahead on your"))
            #expect(!sentence.contains("ahead straight ahead"))
            #expect(sentence.contains("1.2 meters"))
        }
    }

    @Test
    func theDirectionlessSubjectCarriesNoDirectionInAnyLanguage() {
        // If this string ever regains a direction, qualifying it with a zone
        // silently produces two directions again.
        for identifier in ["en", "es", "vi"] {
            let subject = phrasing.somethingAway(atDistance: "1 meter", locale: Locale(identifier: identifier))

            for direction in ["ahead", "delante", "phía trước", "left", "right"] {
                #expect(
                    !subject.localizedCaseInsensitiveContains(direction),
                    "\"\(subject)\" must carry no direction of its own"
                )
            }
        }
    }

    @Test
    func theUnqualifiedAlertStillSaysAhead() {
        // The no-zone-resolved path is unchanged: it is the sentence this app
        // has always spoken, and it is the only one allowed to say "ahead".
        let subject = phrasing.somethingAhead(atDistance: "2 meters", locale: english)

        #expect(subject.contains("ahead"))
    }

    @Test
    func eachZoneMapsToADistinctSpokenSide() {
        let subjects = AwarenessZone.allCases.map {
            phrasing.subject("something", in: $0, locale: english)
        }

        #expect(Set(subjects).count == AwarenessZone.allCases.count)
        #expect(subjects.allSatisfy { $0.contains("something") })
    }

    @Test
    func aSingleAlertSessionSummaryIsGrammatical() {
        // "…and raised 1 alerts." shipped in all three languages before the
        // sentence was reworded to need no plural agreement.
        let summary = phrasing.sessionSummary(alerts: 1, duration: "2 minutes", locale: english)

        #expect(!summary.contains("1 alerts"))
        #expect(summary.contains("1"))
        #expect(summary.contains("2 minutes"))
    }

    @Test
    func aZeroAlertSessionStillReportsWhatTheAppDidRatherThanWhatWasOutThere() {
        let summary = phrasing.sessionSummary(alerts: 0, duration: "5 minutes", locale: english)

        #expect(!summary.isEmpty)
        // Never a claim about the world — see docs/SAFETY-FRAMING.md.
        for forbidden in ["clear", "nothing was there", "safe"] {
            #expect(!summary.localizedCaseInsensitiveContains(forbidden))
        }
    }

    @Test
    func theSessionSummaryIsTranslatedRatherThanFallingBackToEnglish() {
        // The plural-variation form of this key would have degraded to English
        // on the raw-catalog path every build of the test suite uses.
        let spanish = phrasing.sessionSummary(alerts: 3, duration: "2 minutos", locale: Locale(identifier: "es"))
        let vietnamese = phrasing.sessionSummary(alerts: 3, duration: "2 phút", locale: Locale(identifier: "vi"))

        #expect(!spanish.contains("Hands-free"))
        #expect(!vietnamese.contains("Hands-free"))
    }

    @Test
    func aMeasurementComingNearerIsHedgedAndCarriesTheNewDistance() {
        let sentence = phrasing.measurementCameNearer(toDistance: "1 meter", locale: english)

        #expect(sentence.contains("1 meter"))
        #expect(Phrasing.hedgeFragments(locale: english).contains { sentence.hasPrefix($0) })
    }

    @Test
    func aSuccessfulButDistantMeasurementIsReportedRatherThanCalledNothing() {
        // The one-shot check used to answer this case with
        // `nothingRecognized()`, which claimed both that recognition ran and
        // that it found nothing — neither true when depth sensing returned a
        // distance that simply sat past the user's alert threshold.
        let sentence = phrasing.nearestMeasurement(atDistance: "4 meters", locale: english)

        #expect(sentence.contains("4 meters"))
        #expect(!sentence.localizedCaseInsensitiveContains("nothing"))
        // A statement about this app's own measurement, never about the world.
        for forbidden in ["clear", "safe", "empty"] {
            #expect(!sentence.localizedCaseInsensitiveContains(forbidden))
        }
    }

    @Test
    func theNearestMeasurementSentenceIsTranslatedInEveryShippedLanguage() {
        for identifier in ["es", "vi"] {
            let sentence = phrasing.nearestMeasurement(
                atDistance: "4 m", locale: Locale(identifier: identifier)
            )

            #expect(!sentence.contains("The nearest distance"))
            #expect(sentence.contains("4 m"))
        }
    }
}
