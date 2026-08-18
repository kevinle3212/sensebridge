import Foundation
import Testing
@testable import SenseBridgeCore

struct ThermalBackoffTests {
    @Test
    func mapsEveryThermalStateToALevel() {
        #expect(ThermalBackoff.level(for: .nominal) == .normal)
        #expect(ThermalBackoff.level(for: .fair) == .normal)
        #expect(ThermalBackoff.level(for: .serious) == .reduced)
        #expect(ThermalBackoff.level(for: .critical) == .minimal)
    }

    @Test
    func slowsDownRatherThanSpeedingUp() {
        // The multiplier scales an *interval*, so every value must be >= 1.
        // A multiplier below 1 would sample more often on a hot device, which
        // is the exact opposite of the intent and would read as a plausible
        // off-by-one in review.
        for level in ThermalBackoff.Level.allCases {
            #expect(ThermalBackoff.intervalMultiplier(for: level) >= 1)
        }
        #expect(ThermalBackoff.intervalMultiplier(for: .normal) == 1)
        #expect(
            ThermalBackoff.intervalMultiplier(for: .minimal)
                > ThermalBackoff.intervalMultiplier(for: .reduced)
        )
    }

    @Test
    func saysNothingWhenTheLevelHasNotChanged() {
        for level in ThermalBackoff.Level.allCases {
            #expect(ThermalBackoff.notice(changingFrom: level, to: level) == nil)
        }
    }

    @Test
    func announcesEveryTransitionIncludingRecovery() {
        #expect(ThermalBackoff.notice(changingFrom: .normal, to: .reduced) != nil)
        #expect(ThermalBackoff.notice(changingFrom: .reduced, to: .minimal) != nil)
        // Recovery matters as much as degradation: a user told the app slowed
        // down keeps discounting what they hear until told it stopped.
        #expect(ThermalBackoff.notice(changingFrom: .minimal, to: .normal) != nil)
    }

    @Test
    func noticesAreTranslatedRatherThanEchoingTheEnglishKey() {
        let english = ThermalBackoff.notice(
            changingFrom: .normal, to: .reduced, locale: Locale(identifier: "en")
        )
        for code in ["es", "vi"] {
            let translated = ThermalBackoff.notice(
                changingFrom: .normal, to: .reduced, locale: Locale(identifier: code)
            )
            #expect(translated != nil)
            #expect(translated != english, "\(code) fell back to the English key")
        }
    }

    @Test
    func noticesClaimNothingAboutTheWorld() {
        // Doctrine check, not a wording check: these sentences describe the
        // app's own cadence. Any of these verbs would turn one into a claim
        // about what is or is not physically there.
        let banned = ["clear", "safe", "nothing there", "no obstacle", "path"]
        for previous in ThermalBackoff.Level.allCases {
            for current in ThermalBackoff.Level.allCases {
                guard let notice = ThermalBackoff.notice(
                    changingFrom: previous, to: current, locale: Locale(identifier: "en")
                ) else { continue }
                for term in banned {
                    #expect(!notice.lowercased().contains(term), "\(notice) contains \(term)")
                }
            }
        }
    }
}
