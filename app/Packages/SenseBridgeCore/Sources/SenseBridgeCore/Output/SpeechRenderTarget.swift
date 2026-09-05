import AVFoundation

/// User-facing voice controls, normalized to `0...1` at the API boundary so
/// callers never need to know `AVSpeechUtterance`'s underlying ranges — see
/// `SpeechRenderTarget.mappedRate(from:)` and `mappedPitch(from:)` for the
/// mapping into AVFoundation's actual units.
public struct SpeechVoiceSettings: Sendable, Equatable {
    /// Speaking rate, `0` slowest to `1` fastest.
    public var rate: Double
    /// Voice pitch, `0` lowest to `1` highest.
    public var pitch: Double
    /// Output volume, `0` silent to `1` loudest.
    public var volume: Double

    /// Creates voice settings, defaulting to `AVSpeechUtterance`'s own
    /// defaults (mid rate, mid pitch, full volume).
    public init(rate: Double = 0.5, pitch: Double = 0.5, volume: Double = 1.0) {
        self.rate = rate
        self.pitch = pitch
        self.volume = volume
    }
}

/// Speaks a message via `AVSpeechSynthesizer`. An actor so speech dispatch
/// never runs on the main thread and calls serialize safely — see
/// docs/ARCHITECTURE.md "Main thread stays free". `RenderTarget` itself
/// stays free of AVFoundation types; this actor is the only place that
/// bridges to them.
public actor SpeechRenderTarget: RenderTarget {
    private let synthesizer: AVSpeechSynthesizer = .init()
    private var language: AppLanguage
    /// Rate/pitch/volume applied to every subsequent `render` call.
    private var voiceSettings: SpeechVoiceSettings

    /// Kept as a reference so `AVSpeechSynthesizer`'s delegate isn't
    /// deallocated (`delegate` is a weak reference).
    ///
    /// No longer iOS-only. The delegate now carries `speak(_:)`'s completion
    /// signal as well as the audio-session deactivation, and a platform without
    /// it would leave every `speak` caller awaiting a callback that never
    /// arrives. Only the audio-session work inside the callback is iOS-gated.
    private var sessionDeactivator: SpeechSessionDeactivator?
    /// Whether ``configureIfNeeded()`` has run yet.
    private var hasConfigured = false

    /// Callers waiting on ``speak(_:)``, keyed by the utterance they are
    /// waiting for.
    ///
    /// A dictionary rather than a single continuation because `render` and
    /// `speak` can interleave: a routine narration can supersede a playback
    /// segment mid-sentence, and the superseded caller must still be resumed or
    /// it waits forever. Every path that starts a new utterance drains this
    /// first — see ``resumePendingCompletions()``.
    private var pendingCompletions: [ObjectIdentifier: CheckedContinuation<Void, Never>] = [:]

    public init(language: AppLanguage = .system, voiceSettings: SpeechVoiceSettings = .init()) {
        self.language = language
        self.voiceSettings = voiceSettings
    }

    /// Configures the shared audio session and installs the delegate, once.
    ///
    /// Deliberately *not* done in `init`. A non-`async` actor initializer
    /// runs on the **caller's** context, not the actor's executor — there
    /// is no `await` to hop through — and this type is constructed by
    /// `AppEnvironment` on `@MainActor` at app launch. Doing AVAudioSession
    /// work there would block the main thread during startup, which is
    /// what docs/ARCHITECTURE.md "Main thread stays free" exists to
    /// prevent. Running it on first `render()` puts it on the actor.
    private func configureIfNeeded() {
        guard !hasConfigured else { return }
        hasConfigured = true

        #if os(iOS)
            // Default session category (.soloAmbient) is silenced by the
            // hardware ring/silent switch — wrong for an app whose entire
            // output is spoken word. .playback/.spokenAudio ignores that switch.
            // .duckOthers lowers rather than silences other audio (e.g. music)
            // while speaking, restored by `handleSpeechEnded()` below.
            try? AVAudioSession.sharedInstance().setCategory(
                .playback, mode: .spokenAudio, options: .duckOthers
            )
        #endif
        let deactivator = SpeechSessionDeactivator { [weak self] utterance in
            Task { await self?.handleSpeechEnded(utterance) }
        }
        sessionDeactivator = deactivator
        synthesizer.delegate = deactivator
    }

    /// Resumes the caller waiting on this utterance, and deactivates the
    /// ducking session once nothing is speaking, so the user's music isn't
    /// left ducked forever.
    ///
    /// Runs **on the actor**, which is the whole point: the delegate
    /// callback arrives on an arbitrary AVFoundation thread at an
    /// arbitrary time, and previously raced `render()`'s own
    /// `setActive(true)`. If the deactivation landed after the
    /// reactivation, the next utterance could play un-ducked or
    /// inaudible — a spoken announcement silently not reaching the user,
    /// which for this app is a real failure, not a cosmetic one. Hopping
    /// back here lets the actor serialize the two, and the `isSpeaking`
    /// re-check covers a newer utterance having started in the meantime.
    private func handleSpeechEnded(_ utterance: ObjectIdentifier) {
        completeUtterance(utterance)
        guard !synthesizer.isSpeaking else { return }
        #if os(iOS)
            try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        #endif
    }

    /// Resumes the caller waiting on `utterance`, if there is one.
    ///
    /// Runs on the actor, hopped to from the delegate's arbitrary AVFoundation
    /// thread for the same reason `handleSpeechEnded()` does: `pendingCompletions`
    /// is actor state, and resuming a continuation twice is a crash rather than a
    /// warning.
    private func completeUtterance(_ identifier: ObjectIdentifier) {
        pendingCompletions.removeValue(forKey: identifier)?.resume()
    }

    /// Resumes every waiting caller, for a new utterance about to supersede
    /// theirs.
    ///
    /// Without this, `stopSpeaking(at: .immediate)` on an utterance that had not
    /// yet started producing audio can retire it without a `didCancel`, and the
    /// caller awaiting it never returns — playback would stall silently, which
    /// on this app's primary channel is indistinguishable from the app having
    /// crashed.
    private func resumePendingCompletions() {
        let waiting = pendingCompletions
        pendingCompletions.removeAll()
        for continuation in waiting.values {
            continuation.resume()
        }
    }

    /// Speaks `message` and returns when it has finished or been superseded.
    ///
    /// The difference from ``render(_:)`` is only that this waits. That is
    /// exactly what sentence-by-sentence playback needs: a loop that speaks a
    /// segment, waits, advances, and speaks the next one — cancellable at any
    /// point by cancelling the task around it, with no timer guessing at how
    /// long a sentence takes.
    ///
    /// Returns immediately for text that is empty or all whitespace.
    /// `AVSpeechSynthesizer` is not documented to deliver a delegate callback
    /// for an utterance with nothing to say, and a caller awaiting one that
    /// never arrives would hang the whole document.
    ///
    /// - Note: Returning does **not** promise the text was heard — a superseding
    ///   utterance resumes the waiter too. A caller that must not be interrupted
    ///   should not be racing another one for the same synthesizer.
    public func speak(_ message: OutputMessage) async {
        guard !message.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        let utterance = prepare(message)
        await withCheckedContinuation { continuation in
            pendingCompletions[ObjectIdentifier(utterance)] = continuation
            synthesizer.speak(utterance)
        }
    }

    /// Whether an utterance is currently being spoken.
    ///
    /// Exists for continuous narration. `render` interrupts whatever is
    /// speaking — correct for the single-capture screens, where a new result
    /// supersedes a stale one, and wrong for hands-free awareness, which would
    /// otherwise cut its own sentence in half every cycle. The caller checks
    /// this to skip a routine update, and deliberately does *not* check it for
    /// an awareness alert, where interrupting is the point.
    public var isSpeaking: Bool {
        synthesizer.isSpeaking
    }

    /// Updates the spoken language for subsequent `render` calls.
    public func setLanguage(_ language: AppLanguage) {
        self.language = language
    }

    /// Updates rate/pitch/volume for subsequent `render` calls.
    public func setVoiceSettings(_ voiceSettings: SpeechVoiceSettings) {
        self.voiceSettings = voiceSettings
    }

    /// Speaks `message`, superseding anything already speaking, and returns
    /// without waiting for it to finish.
    ///
    /// Fire-and-forget is right for a one-shot result: the caller has nothing
    /// left to do, and a capture screen that blocked until the last word would
    /// leave its button disabled for the length of a page. Playback that has to
    /// know when a sentence ended uses ``speak(_:)`` instead.
    public func render(_ message: OutputMessage) async {
        synthesizer.speak(prepare(message))
    }

    /// Stops whatever is speaking, readies the audio session, and builds the
    /// utterance for `message` — everything both ``render(_:)`` and
    /// ``speak(_:)`` do before handing it to the synthesizer.
    ///
    /// Shared rather than duplicated because the ordering in here is load-bearing
    /// and non-obvious in three places at once (stop before activate, drain
    /// waiters before starting, apply voice settings after resolving the voice);
    /// two copies would drift on the first change to any of them.
    private func prepare(_ message: OutputMessage) -> AVSpeechUtterance {
        configureIfNeeded()
        // AVSpeechSynthesizer queues rather than replaces — without this, a
        // second capture taken before the first finishes speaking just gets
        // appended behind the stale result instead of superseding it.
        synthesizer.stopSpeaking(at: .immediate)
        // Any waiter whose utterance was just retired is resumed here rather
        // than left for a `didCancel` that an unstarted utterance may never
        // produce — see `resumePendingCompletions()`.
        resumePendingCompletions()
        #if os(iOS)
            // stopSpeaking(at:) above may fire didCancel, whose deactivation
            // now hops back onto this actor (`handleSpeechEnded`) rather than
            // racing this line, so activating here can't be undone underneath
            // the utterance below.
            try? AVAudioSession.sharedInstance().setActive(true)
        #endif
        let utterance = AVSpeechUtterance(string: message.text)
        utterance.voice = Self.voice(for: language)
        utterance.rate = Self.mappedRate(from: voiceSettings.rate)
        utterance.pitchMultiplier = Self.mappedPitch(from: voiceSettings.pitch)
        utterance.volume = Float(Self.clampedUnit(voiceSettings.volume))
        return utterance
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

    /// Maps a normalized `0...1` rate onto `AVSpeechUtterance`'s own rate
    /// range, factored out as a pure function so it is unit-testable without
    /// a synthesizer — same reasoning as `selectVoiceLanguage(for:)` above.
    /// Out-of-range input clamps rather than trapping.
    static func mappedRate(from normalized: Double) -> Float {
        let clamped = clampedUnit(normalized)
        let minimum = Double(AVSpeechUtteranceMinimumSpeechRate)
        let maximum = Double(AVSpeechUtteranceMaximumSpeechRate)
        return Float(minimum + clamped * (maximum - minimum))
    }

    /// Maps a normalized `0...1` pitch onto `AVSpeechUtterance.pitchMultiplier`'s
    /// valid range (`0.5...2.0`). Out-of-range input clamps rather than trapping.
    static func mappedPitch(from normalized: Double) -> Float {
        let clamped = clampedUnit(normalized)
        return Float(0.5 + clamped * 1.5)
    }

    /// Clamps a normalized value to `0...1`, guarding every mapping above
    /// against out-of-range settings rather than trapping or misbehaving.
    private static func clampedUnit(_ value: Double) -> Double {
        min(max(value, 0), 1)
    }
}

/// Bridges `AVSpeechSynthesizerDelegate`'s Objective-C callbacks into a
/// single closure, so the actor that owns the synthesizer can decide what
/// to do with them on its own executor. It deliberately performs no
/// audio-session work itself — doing that here is what previously raced
/// `SpeechRenderTarget.render()`. The delegate protocol requires an
/// `NSObject` subclass, matching the bridging pattern established by
/// `PhotoCaptureDelegate`.
///
/// Compiled on every platform, not just iOS: `SpeechRenderTarget.speak(_:)`
/// waits on this callback, and a build without it would hang every caller
/// rather than merely skipping an audio-session tidy-up.
///
/// The `Sendable` conformance is sound only because the single stored
/// property is an immutable `let`. If you need mutable state here, remove
/// the state — don't reach for `@unchecked Sendable`.
private final class SpeechSessionDeactivator: NSObject, AVSpeechSynthesizerDelegate, Sendable {
    private let onSpeechEnded: @Sendable (ObjectIdentifier) -> Void

    /// Creates a delegate forwarding both finish and cancel to
    /// `onSpeechEnded` — the caller cannot distinguish them, and doesn't
    /// need to: both mean "this utterance is over".
    ///
    /// The utterance's identity is passed rather than the utterance itself.
    /// `AVSpeechUtterance` is not `Sendable`, and the receiver only needs to
    /// match it against a waiting continuation, never to read it.
    init(onSpeechEnded: @escaping @Sendable (ObjectIdentifier) -> Void) {
        self.onSpeechEnded = onSpeechEnded
    }

    /// Reports an utterance that finished speaking on its own.
    func speechSynthesizer(_: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        onSpeechEnded(ObjectIdentifier(utterance))
    }

    /// Reports an utterance cut short, typically by a newer one superseding it.
    func speechSynthesizer(_: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        onSpeechEnded(ObjectIdentifier(utterance))
    }
}
