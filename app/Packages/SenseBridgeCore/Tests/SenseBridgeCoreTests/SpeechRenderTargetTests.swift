import Testing
@testable import SenseBridgeCore

// Exercises the voice fallback chain as a pure function over BCP-47 language
// tags, so it runs without installed voices or a device — see
// docs/superpowers/specs/2026-07-19-language-support-design.md
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
}
