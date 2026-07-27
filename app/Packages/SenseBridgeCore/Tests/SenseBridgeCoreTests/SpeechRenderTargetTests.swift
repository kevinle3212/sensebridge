import AVFoundation
import Testing
@testable import SenseBridgeCore

// Exercises the voice fallback chain as a pure function over BCP-47 language
// tags, so it runs without installed voices or a device — see
// docs/superpowers/specs/2026-07-19-LANGUAGE-SUPPORT-DESIGN.md
// "SpeechRenderTarget: voice selection by BCP-47 fallback chain".
struct SpeechRenderTargetTests {
    @Test
    func exactLocaleMatchWins() {
        let selected = SpeechRenderTarget.selectVoiceLanguage(
            for: "es-MX",
            availableLanguages: ["en-US", "es-MX", "es-ES"]
        )
        #expect(selected == "es-MX")
    }

    @Test
    func fallsBackToAnyVoiceSharingTheLanguageCode() {
        let selected = SpeechRenderTarget.selectVoiceLanguage(
            for: "es-MX",
            availableLanguages: ["en-US", "es-ES"]
        )
        #expect(selected == "es-ES")
    }

    @Test
    func returnsNilWhenNoVoiceSharesTheLanguageCode() {
        let selected = SpeechRenderTarget.selectVoiceLanguage(
            for: "vi-VN",
            availableLanguages: ["en-US", "es-ES"]
        )
        #expect(selected == nil)
    }

    @Test
    func returnsNilWhenNoVoicesAreInstalled() {
        let selected = SpeechRenderTarget.selectVoiceLanguage(for: "en-US", availableLanguages: [])
        #expect(selected == nil)
    }

    @Test
    func mappedRateAtZeroIsTheMinimumRate() {
        #expect(SpeechRenderTarget.mappedRate(from: 0) == AVSpeechUtteranceMinimumSpeechRate)
    }

    @Test
    func mappedRateAtOneIsTheMaximumRate() {
        #expect(SpeechRenderTarget.mappedRate(from: 1) == AVSpeechUtteranceMaximumSpeechRate)
    }

    @Test
    func mappedRateAtHalfIsTheMidpoint() {
        let expected = (AVSpeechUtteranceMinimumSpeechRate + AVSpeechUtteranceMaximumSpeechRate) / 2
        #expect(SpeechRenderTarget.mappedRate(from: 0.5) == expected)
    }

    @Test
    func mappedRateClampsBelowZeroToTheMinimumRate() {
        #expect(SpeechRenderTarget.mappedRate(from: -1) == AVSpeechUtteranceMinimumSpeechRate)
    }

    @Test
    func mappedRateClampsAboveOneToTheMaximumRate() {
        #expect(SpeechRenderTarget.mappedRate(from: 2) == AVSpeechUtteranceMaximumSpeechRate)
    }

    @Test
    func mappedPitchAtZeroIsPointFive() {
        #expect(SpeechRenderTarget.mappedPitch(from: 0) == 0.5)
    }

    @Test
    func mappedPitchAtOneIsTwo() {
        #expect(SpeechRenderTarget.mappedPitch(from: 1) == 2.0)
    }

    @Test
    func mappedPitchAtHalfIsTheMidpoint() {
        #expect(SpeechRenderTarget.mappedPitch(from: 0.5) == 1.25)
    }

    @Test
    func mappedPitchClampsBelowZeroToPointFive() {
        #expect(SpeechRenderTarget.mappedPitch(from: -1) == 0.5)
    }

    @Test
    func mappedPitchClampsAboveOneToTwo() {
        #expect(SpeechRenderTarget.mappedPitch(from: 2) == 2.0)
    }
}
