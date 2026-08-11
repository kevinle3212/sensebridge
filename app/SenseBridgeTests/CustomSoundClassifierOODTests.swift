import AVFoundation
import CoreML
import Foundation
import SenseBridgeCore
import SoundAnalysis
import Testing
@testable import SenseBridge

/// Regression test for the defect in
/// `audits/safety-framing/20260806-064241-…-reach-spoken-output.md` (dated
/// prefix is unique under that directory):
/// before the `background` training class existed, non-alert audio (room
/// hiss, white noise, a pure tone, a frequency sweep) scored an alert class
/// at 1.000 confidence through this exact path, cleared the 0.7 floor, and
/// reached the app's most confident spoken phrasing in a quiet room. Runs
/// `SoundClassificationRunner.classify` against the *shipped* bundled
/// `.mlmodel`, not a stub, so a future retrain that drops the background
/// class — or otherwise reintroduces the defect — fails this test instead of
/// waiting to be rediscovered by a manual audit.
struct CustomSoundClassifierOODTests {
    /// Renders `seconds` of mono 44.1kHz audio from `sample` (elapsed
    /// seconds -> amplitude) to a temporary WAV file and returns its bytes,
    /// matching the `Data` shape `SoundClassificationRunner.classify` expects.
    private func wavData(seconds: Double = 5, sample: (Double) -> Float) throws -> Data {
        let sampleRate: Double = 44100
        let format = try #require(AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1))
        let frameCount = AVAudioFrameCount(sampleRate * seconds)
        let buffer = try #require(AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount))
        buffer.frameLength = frameCount
        let channel = try #require(buffer.floatChannelData)[0]
        for frame in 0 ..< Int(frameCount) {
            channel[frame] = sample(Double(frame) / sampleRate)
        }
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("wav")
        defer { try? FileManager.default.removeItem(at: url) }
        let file = try AVAudioFile(forWriting: url, settings: format.settings)
        try file.write(from: buffer)
        return try Data(contentsOf: url)
    }

    /// Mirrors `CustomSoundClassifier.process(_:)` exactly — same model, same
    /// request, same target-class filter — so this test exercises the
    /// production inference path rather than a proxy for it.
    private func classify(_ audio: Data) async throws -> [PerceptionRecord] {
        let model = try SenseBridgeSoundClassifier(configuration: MLModelConfiguration()).model
        let request = try SNClassifySoundRequest(mlModel: model)
        return try await SoundClassificationRunner.classify(
            audio, using: request, topClassNames: CustomSoundClassifier.targetClassNames
        )
    }

    @Test
    func quietRoomHissProducesNoAlertRecord() async throws {
        let audio = try wavData { _ in 0.01 * Float.random(in: -1 ... 1) }
        #expect(try await classify(audio).isEmpty)
    }

    @Test
    func whiteNoiseProducesNoAlertRecord() async throws {
        let audio = try wavData { _ in 0.05 * Float.random(in: -1 ... 1) }
        #expect(try await classify(audio).isEmpty)
    }

    @Test
    func pureToneProducesNoAlertRecord() async throws {
        let audio = try wavData { elapsed in 0.2 * Float(sin(2 * Double.pi * 1000 * elapsed)) }
        #expect(try await classify(audio).isEmpty)
    }

    @Test
    func frequencySweepProducesNoAlertRecord() async throws {
        let audio = try wavData { elapsed in
            let frequency = 200 + (4000 - 200) * (elapsed / 5)
            return 0.2 * Float(sin(2 * Double.pi * frequency * elapsed))
        }
        #expect(try await classify(audio).isEmpty)
    }

    @Test
    func lowFrequencyHumProducesNoAlertRecord() async throws {
        let audio = try wavData { elapsed in 0.2 * Float(sin(2 * Double.pi * 60 * elapsed)) }
        #expect(try await classify(audio).isEmpty)
    }
}
