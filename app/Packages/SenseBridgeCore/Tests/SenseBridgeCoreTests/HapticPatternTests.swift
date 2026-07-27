import Testing
@testable import SenseBridgeCore

struct HapticPatternTests {
    @Test
    func everySignalYieldsANonEmptyPattern() {
        for signal in OutputSignal.allCases {
            #expect(!HapticPattern.pattern(for: signal).events.isEmpty)
        }
    }

    @Test
    func everySignalsPatternIsDistinguishableFromEveryOther() {
        let patterns = OutputSignal.allCases.map { HapticPattern.pattern(for: $0) }
        for firstIndex in patterns.indices {
            for secondIndex in patterns.indices where secondIndex > firstIndex {
                #expect(patterns[firstIndex] != patterns[secondIndex])
            }
        }
    }

    @Test
    func scaledMultipliesEveryEventsIntensity() {
        let pattern = HapticPattern(events: [HapticEvent(relativeTime: 0, intensity: 0.5, sharpness: 0.5)])
        let scaled = pattern.scaled(by: 0.5)
        #expect(scaled.events[0].intensity == 0.25)
    }

    @Test
    func scaledClampsAMultiplierBelowZeroToZero() {
        let pattern = HapticPattern(events: [HapticEvent(relativeTime: 0, intensity: 0.5, sharpness: 0.5)])
        let scaled = pattern.scaled(by: -1)
        #expect(scaled.events[0].intensity == 0)
    }

    @Test
    func scaledClampsAMultiplierAboveOneToOne() {
        let pattern = HapticPattern(events: [HapticEvent(relativeTime: 0, intensity: 0.5, sharpness: 0.5)])
        let scaled = pattern.scaled(by: 2)
        #expect(scaled.events[0].intensity == 0.5)
    }
}
