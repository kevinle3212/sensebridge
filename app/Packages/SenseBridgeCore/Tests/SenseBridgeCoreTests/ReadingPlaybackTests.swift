import Testing
@testable import SenseBridgeCore

struct ReadingPlaybackTests {
    @Test
    func startsOnTheFirstSegment() {
        let playback = ReadingPlayback(segments: ["one.", "two.", "three."])

        #expect(playback.current == "one.")
        #expect(playback.position == 1)
        #expect(playback.count == 3)
        #expect(!playback.isFinished)
    }

    @Test
    func dropsBlankSegmentsSoPlaybackNeverGoesSilentMidDocument() {
        // A segment that speaks as nothing is indistinguishable, to a listener,
        // from the app having stopped.
        let playback = ReadingPlayback(segments: ["one.", "   ", "", "two."])

        #expect(playback.count == 2)
        #expect(playback.current == "one.")
    }

    @Test
    func advancesThroughEverySegmentThenFinishes() {
        var playback = ReadingPlayback(segments: ["one.", "two."])

        #expect(playback.advance() == "two.")
        #expect(playback.advance() == nil)
        #expect(playback.isFinished)
        #expect(playback.current == nil)
        #expect(playback.position == nil)
    }

    @Test
    func retreatingFromPastTheEndLandsOnTheLastSegment() {
        // What a listener means by "back" after hearing a document finish.
        var playback = ReadingPlayback(segments: ["one.", "two.", "three."])
        playback.advance()
        playback.advance()
        playback.advance()
        #expect(playback.isFinished)

        #expect(playback.retreat() == "three.")
        #expect(!playback.isFinished)
    }

    @Test
    func retreatingFromTheFirstSegmentRereadsItRatherThanGoingSilent() {
        // A no-op would be silence, which on a channel a blind user cannot see
        // is indistinguishable from a broken control.
        var playback = ReadingPlayback(segments: ["one.", "two."])

        #expect(playback.retreat() == "one.")
        #expect(playback.position == 1)
    }

    @Test
    func restartReturnsToTheBeginningFromPastTheEnd() {
        var playback = ReadingPlayback(segments: ["one.", "two."])
        playback.advance()
        playback.advance()

        #expect(playback.restart() == "one.")
        #expect(playback.position == 1)
        #expect(!playback.isFinished)
    }

    @Test
    func anEmptyDocumentIsNeverFinishedBecauseItNeverPlayed() {
        // "Nothing was played" and "everything was played" need different
        // things offered to the listener — read again versus carry on.
        var playback = ReadingPlayback(segments: [])

        #expect(playback.current == nil)
        #expect(!playback.isFinished)
        #expect(playback.advance() == nil)
        #expect(playback.retreat() == nil)
        #expect(playback.restart() == nil)
        #expect(playback.move(to: 3) == nil)
    }

    @Test
    func movingOutOfRangeClampsRatherThanTrapping() {
        // The argument originates in a list selection, and a list reloaded
        // underneath a stale selection is an ordinary race, not a reason to
        // crash a blind user's app.
        var playback = ReadingPlayback(segments: ["one.", "two.", "three."])

        #expect(playback.move(to: 99) == "three.")
        #expect(playback.move(to: -5) == "one.")
    }
}
