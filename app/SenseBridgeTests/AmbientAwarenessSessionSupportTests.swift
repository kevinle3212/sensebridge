import Foundation
import SenseBridgeCore
import Testing
@testable import SenseBridge

/// Regression coverage for `AmbientAwarenessSession.formattedDistance` —
/// this is the string a synthesizer speaks aloud, so an abbreviated unit
/// ("in", "ft") that reads as a different word entirely is a correctness
/// bug, not a style nit.
struct AmbientAwarenessSessionSupportTests {
    @MainActor
    @Test
    func spellsInchesOutRatherThanAbbreviating() {
        let described = AmbientAwarenessSession.formattedDistance(
            meters: 0.2,
            locale: Locale(identifier: "en_US")
        )
        #expect(described.contains("inch"))
        #expect(!Self.hasAbbreviatedUnitToken(described))
    }

    @MainActor
    @Test
    func spellsFeetOutRatherThanAbbreviating() {
        let described = AmbientAwarenessSession.formattedDistance(
            meters: 3,
            locale: Locale(identifier: "en_US")
        )
        #expect(described.contains("feet") || described.contains("foot"))
        #expect(!Self.hasAbbreviatedUnitToken(described))
    }

    /// True if `text` contains a bare abbreviated unit token ("in", "ft",
    /// "m", "yd") as its own word — the exact shape that reads aloud as an
    /// unrelated word rather than the intended unit. Word-boundary matching
    /// so this doesn't false-positive on "inches"/"feet" containing "in"/
    /// "ft" as a substring.
    private static func hasAbbreviatedUnitToken(_ text: String) -> Bool {
        text.range(of: #"\b(in|ft|yd)\b"#, options: .regularExpression) != nil
    }

    @MainActor
    @Test
    func spellsMetersOutRatherThanAbbreviating() {
        let described = AmbientAwarenessSession.formattedDistance(
            meters: 2,
            locale: Locale(identifier: "fr_FR")
        )
        #expect(described.lowercased().contains("m\u{00E8}tre") || described.lowercased().contains("metre"))
    }
}
