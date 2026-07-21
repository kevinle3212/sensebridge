import AVFoundation

/// Speaks a message via `AVSpeechSynthesizer`. An actor so speech dispatch
/// never runs on the main thread and calls serialize safely — see
/// docs/ARCHITECTURE.md "Main thread stays free". `RenderTarget` itself
/// stays free of AVFoundation types; this actor is the only place that
/// bridges to them.
public actor SpeechRenderTarget: RenderTarget {
    private let synthesizer: AVSpeechSynthesizer = .init()
    private var language: AppLanguage

    public init(language: AppLanguage = .system) {
        self.language = language
    }

    /// Updates the spoken language for subsequent `render` calls.
    public func setLanguage(_ language: AppLanguage) {
        self.language = language
    }

    public func render(_ message: String) async {
        let utterance = AVSpeechUtterance(string: message)
        utterance.voice = Self.voice(for: language)
        synthesizer.speak(utterance)
    }

    /// Resolves the language to speak with by picking an installed voice:
    /// exact BCP-47 match → any installed voice sharing the language code →
    /// `nil` (AVSpeechUtterance then falls back to the system default
    /// voice). `.system` always defers to the device default.
    private static func voice(for language: AppLanguage) -> AVSpeechSynthesisVoice? {
        guard let locale = language.locale else { return nil }
        let voices = AVSpeechSynthesisVoice.speechVoices()
        guard let selected = selectVoiceLanguage(
            for: locale.identifier(.bcp47),
            availableLanguages: voices.map(\.language)
        ) else { return nil }
        return voices.first { $0.language == selected }
    }

    /// The fallback chain itself, factored out as a pure function over BCP-47
    /// language tags so it is unit-testable without installed voices/devices.
    static func selectVoiceLanguage(for requested: String, availableLanguages: [String]) -> String? {
        if availableLanguages.contains(requested) {
            return requested
        }
        let requestedLanguageCode = Locale.Language(identifier: requested).languageCode
        return availableLanguages.first {
            Locale.Language(identifier: $0).languageCode == requestedLanguageCode
        }
    }
}
