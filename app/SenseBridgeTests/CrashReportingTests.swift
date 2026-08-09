import Foundation
import SenseBridgeCore
import Sentry
import Testing
@testable import SenseBridge

/// Covers the two halves of the crash-reporting guarantee: that consent
/// defaults to withheld and survives an upgrade that way, and that a report
/// which does get sent carries nothing personal.
///
/// Deliberately never calls `CrashReporting.apply(isEnabled:)`. Doing so would
/// start the real SDK on a machine that happens to have a DSN configured, which
/// is a test suite transmitting to a live project — the exact accident this
/// whole module is built to prevent.
struct CrashReportingTests {
    @Test
    func consentIsWithheldOnAFreshInstall() {
        #expect(Settings().crashReportingEnabled == false)
    }

    @Test
    func consentIsWithheldWhenUpgradingFromABuildWithoutTheSetting() throws {
        // Exactly what an existing install has persisted: the settings blob as
        // it was written before this field existed. A missing key is silence,
        // and silence is not agreement.
        let legacy = Data(
            """
            {"outputProfile":"blind","speechRate":0.5,"cloudReasoningEnabled":false}
            """.utf8
        )
        let decoded = try JSONDecoder().decode(Settings.self, from: legacy)
        #expect(decoded.crashReportingEnabled == false)
    }

    @Test
    func consentSurvivesAnEncodeDecodeRoundTrip() throws {
        var settings = Settings()
        settings.crashReportingEnabled = true
        let restored = try JSONDecoder().decode(
            Settings.self, from: JSONEncoder().encode(settings)
        )
        #expect(restored.crashReportingEnabled == true)
    }

    @MainActor
    @Test
    func scrubbingRemovesEveryFieldThatCouldIdentifyTheUser() {
        let event = Event()
        event.user = User(userId: "someone")
        // `SentryRequest`, not `Request`: this is one of the few Sentry types
        // without an `NS_SWIFT_NAME` alias, unlike `User` and `Breadcrumb`.
        event.request = SentryRequest()
        event.serverName = "Kevins-iPhone.local"
        event.breadcrumbs = [Breadcrumb(level: .info, category: "ui.tap")]
        event.context = [
            "device": ["name": "Kevin's iPhone", "model": "iPhone17,1"],
            "culture": ["locale": "en_US", "timezone": "America/Los_Angeles"]
        ]

        let scrubbed = CrashReporting.scrub(event)

        #expect(scrubbed.user == nil)
        #expect(scrubbed.request == nil)
        #expect(scrubbed.serverName == nil)
        #expect(scrubbed.breadcrumbs == nil)
        #expect(scrubbed.context?["device"]?["name"] == nil)
        #expect(scrubbed.context?["culture"] == nil)
    }

    @MainActor
    @Test
    func scrubbingKeepsWhatMakesACrashDiagnosable() {
        let event = Event()
        event.context = ["device": ["name": "Kevin's iPhone", "model": "iPhone17,1"]]

        let scrubbed = CrashReporting.scrub(event)

        // The model is what makes a crash reproducible and identifies nobody.
        // Stripping the whole `device` context instead of just the name would
        // be a scrubber that costs the report its usefulness for no gain.
        #expect(scrubbed.context?["device"]?["model"] as? String == "iPhone17,1")
    }
}
