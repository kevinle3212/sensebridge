import Foundation
import Testing
@testable import SenseBridgeCore

// Serialized: Swift Testing parallelizes @Test functions within a suite by
// default, and both tests here open a real AVAudioEngine capture on the same
// input hardware. Two concurrent engine.start() calls contend for exclusive
// audio device access -- observed as a ~325s stall on both tests rather than
// a fast pass/fail, not a cancellation regression. Recording is exclusive
// hardware, not parallelizable state.
@Suite(.serialized)
struct MicrophoneSensingSourceTests {
    @Test
    func recordingProducesNonEmptyWAVData() async throws {
        let source = MicrophoneSensingSource()
        // Simulator/CI has no real microphone input, but the engine still
        // renders silence through the tap for the requested duration — this
        // asserts the capture pipeline itself works, not that it heard
        // anything.
        let data = try await source.record(duration: 0.2)
        #expect(!data.isEmpty)
        // A WAV file's first four bytes are the "RIFF" chunk ID.
        #expect(data.prefix(4) == Data("RIFF".utf8))
    }

    @Test
    func cancellingStopsTheRecordingPromptly() async throws {
        // The regression: the sleep used to run inside an unstructured `Task`
        // created from a `withCheckedThrowingContinuation` closure. That closure
        // is not an async context, so the task had no parent and inherited no
        // cancellation — cancelling ran the recording to full term, holding the
        // engine open and the microphone indicator lit long after the wearer had
        // moved on. For a privacy-critical mic that delay is the whole bug.
        let source = MicrophoneSensingSource()
        let started = Date()

        let recording = Task { try await source.record(duration: 30) }
        // Long enough for the engine to start and the tap to be installed, so
        // this cancels a capture genuinely in flight rather than one not begun.
        try await Task.sleep(for: .milliseconds(300))
        recording.cancel()

        await #expect(throws: CancellationError.self) { try await recording.value }

        // Generous relative to the 300ms setup, tiny relative to the 30s
        // duration: only propagated cancellation can land in this window, and
        // the pre-fix code could not have.
        #expect(Date().timeIntervalSince(started) < 5)
    }
}
