import Foundation
import Testing
@testable import SenseBridgeCore

struct BuiltInSoundClassifierTests {
    @Test
    func emptyAudioProducesNoRecords() async throws {
        let classifier = BuiltInSoundClassifier()
        // A zero-length WAV can't classify to anything; this exercises the
        // "nothing recognized" path without needing a real recording.
        let records = try await classifier.process(Data())
        #expect(records.isEmpty)
    }

    @Test
    func targetClassNamesAreNonEmptyAndLowercase() {
        // The curated alpha subset — asserted as data, not behavior, so a
        // future edit to the list can't silently reintroduce an
        // uppercase/typo'd identifier that would never match Apple's taxonomy.
        for name in BuiltInSoundClassifier.targetClassNames {
            #expect(!name.isEmpty)
            #expect(name == name.lowercased())
        }
    }
}
