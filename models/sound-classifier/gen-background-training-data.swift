#!/usr/bin/swift
import AVFoundation
import Foundation

// Generates the `background` training class: synthetic, license-free audio
// covering the out-of-distribution failure modes measured in
// audits/safety-framing/20260806-064241-custom-sound-classifier-out-of-distribution-false-positives-reach-spoken-output.md
// (room hiss, white noise, pure tones, frequency sweeps, hums each scored an
// alert class at 1.000 confidence on the shipped model, because it had no
// class to put non-alert audio in). Synthetic rather than sourced: this
// content has no license to verify — nothing here comes from ESC-50 or
// Freesound, so it needs no MANIFEST.csv row. See README.md.
//
// Deliberately broader than the six probe signals from the audit: several
// noise colors, several tone/hum frequencies, and two transient/harmonic
// shapes, so the class generalizes past the exact clips it was scored
// against rather than memorizing them.

let arguments: [String] = CommandLine.arguments
guard arguments.count == 2 else {
    print("Usage: gen-background-training-data.swift <output-class-dir>")
    exit(1)
}

let outputDir: URL = .init(fileURLWithPath: arguments[1])
try FileManager.default.createDirectory(at: outputDir, withIntermediateDirectories: true)

let sampleRate: Double = 44100
let duration: Double = 5
let frameCount: AVAudioFrameCount = .init(sampleRate * duration)

/// Renders `duration` seconds of mono 44.1kHz audio from `samples` (frame
/// index, elapsed seconds) -> amplitude and writes it as `name` under
/// `outputDir`.
func writeWAV(name: String, samples: (Int, Double) -> Float) throws {
    let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1)!
    let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount)!
    buffer.frameLength = frameCount
    let channel = buffer.floatChannelData![0]
    for frame in 0 ..< Int(frameCount) {
        let t = Double(frame) / sampleRate
        channel[frame] = samples(frame, t)
    }
    let url = outputDir.appendingPathComponent(name)
    let file = try AVAudioFile(forWriting: url, settings: format.settings)
    try file.write(from: buffer)
}

/// A sample generator producing uniform random noise at `amplitude`.
func whiteNoise(amplitude: Float) -> (Int, Double) -> Float {
    { _, _ in amplitude * Float.random(in: -1 ... 1) }
}

/// A sample generator approximating colored noise (pink/brown, depending on
/// `poleCount`) by cascading one-pole low-passes over white noise — close
/// enough for a training clip without pulling in a DSP dependency.
func filteredNoise(amplitude: Float, poleCount: Int) -> (Int, Double) -> Float {
    var state = [Float](repeating: 0, count: poleCount)
    return { _, _ in
        var sample = Float.random(in: -1 ... 1)
        for i in 0 ..< poleCount {
            state[i] = state[i] * 0.97 + sample * 0.03
            sample = state[i]
        }
        return amplitude * sample * 6 // compensate for low-pass energy loss
    }
}

/// A sample generator producing a pure sine tone at `frequency`.
func tone(frequency: Double, amplitude: Float) -> (Int, Double) -> Float {
    { _, t in amplitude * Float(sin(2 * Double.pi * frequency * t)) }
}

/// A sample generator sweeping linearly from `startHz` to `endHz` over the
/// clip's duration.
func sweep(startHz: Double, endHz: Double, amplitude: Float) -> (Int, Double) -> Float {
    { _, t in
        let frac = t / duration
        let freq = startHz + (endHz - startHz) * frac
        return amplitude * Float(sin(2 * Double.pi * freq * t))
    }
}

/// A sample generator summing sine tones at `frequencies` into a simple
/// harmonic chord, approximating ambient music/tonal background.
func chord(frequencies: [Double], amplitude: Float) -> (Int, Double) -> Float {
    { _, t in
        var sample: Float = 0
        for f in frequencies {
            sample += Float(sin(2 * Double.pi * f * t))
        }
        return amplitude * sample / Float(frequencies.count)
    }
}

/// A sample generator producing a short pulse every `intervalSeconds`,
/// approximating transient impact noise (footsteps, typing) distinct from
/// `knock`'s single-impact training clips.
func clickTrain(intervalSeconds: Double, amplitude: Float) -> (Int, Double) -> Float {
    { _, t in
        let phase = t.truncatingRemainder(dividingBy: intervalSeconds)
        return phase < 0.004 ? amplitude : 0
    }
}

let clips: [(String, (Int, Double) -> Float)] = [
    ("silence.wav", { _, _ in 0 }),
    ("hiss_low.wav", whiteNoise(amplitude: 0.005)),
    ("hiss_room.wav", whiteNoise(amplitude: 0.01)),
    ("noise_white_moderate.wav", whiteNoise(amplitude: 0.05)),
    ("noise_white_loud.wav", whiteNoise(amplitude: 0.15)),
    ("noise_pink.wav", filteredNoise(amplitude: 0.08, poleCount: 1)),
    ("noise_brown.wav", filteredNoise(amplitude: 0.06, poleCount: 3)),
    ("tone_440hz.wav", tone(frequency: 440, amplitude: 0.2)),
    ("tone_1khz.wav", tone(frequency: 1000, amplitude: 0.2)),
    ("tone_2khz.wav", tone(frequency: 2000, amplitude: 0.15)),
    ("hum_60hz.wav", tone(frequency: 60, amplitude: 0.2)),
    ("hum_120hz.wav", tone(frequency: 120, amplitude: 0.15)),
    ("sweep_up_200_4000.wav", sweep(startHz: 200, endHz: 4000, amplitude: 0.2)),
    ("sweep_down_4000_200.wav", sweep(startHz: 4000, endHz: 200, amplitude: 0.2)),
    ("chord_ambient.wav", chord(frequencies: [220, 277.18, 329.63], amplitude: 0.12)),
    ("clicks_transient.wav", clickTrain(intervalSeconds: 0.4, amplitude: 0.3))
]

var written = 0
for (name, generator) in clips {
    try writeWAV(name: name, samples: generator)
    written += 1
}

print("Wrote \(written) synthetic background clips to \(outputDir.path)")
