import Foundation
import SenseBridgeCore
import SwiftUI

/// Drives the Read screen: capture, multi-page documents, sentence-level
/// playback, and the recently-read history.
///
/// Owned by the view rather than by `AppEnvironment` because everything here
/// dies with the screen — the camera, the playback cursor, and the torch this
/// screen switched on all have to be released when the user leaves, and a blind
/// user has no way to notice any of the three still running.
///
/// ## Why playback is a cursor and not a queue
///
/// The whole document is segmented up front (`TextSegmenter`) and spoken one
/// segment at a time, awaiting each utterance before starting the next. That is
/// what makes "back", "next", and "pause" land between sentences instead of
/// cutting one off mid-word, and it is why `SpeechRenderTarget.speak(_:)`
/// exists: a timer-driven approximation would drift out of step with the
/// synthesizer on the first long sentence.
///
/// The live-reading loop lives in `ReadingSession+Live.swift`, split out for
/// SwiftLint's length gates.
@MainActor
@Observable
final class ReadingSession {
    /// Recognized text, one entry per captured page, in capture order.
    private(set) var pages: [String] = []
    /// Where playback is in the current document.
    private(set) var playback: ReadingPlayback = .init(segments: [])
    /// Whether segments are being spoken one after another right now.
    private(set) var isPlaying = false
    /// Whether a capture or recognition pass is in flight, so the view can
    /// disable the controls that would collide with it.
    private(set) var isBusy = false
    /// The last thing said, mirrored on screen for a sighted helper, a
    /// screenshot, or a braille display. Speech is the channel; this is not.
    private(set) var status: String?
    /// Whether the last failure was a denied permission — the only error on
    /// this screen the Settings app can fix.
    private(set) var isSettingsFixable = false
    /// Recently read documents, newest first. Empty while history is switched
    /// off, which is the default.
    private(set) var history: [ReadingDocument] = []

    /// Live-reading state, written by `ReadingSession+Live.swift`.
    ///
    /// Internal rather than `private` so that same-type extension — a different
    /// file only because of SwiftLint's `file_length` gate — can reach it.
    var isLive = false
    /// The current aiming instruction, or `nil` when the frame is fine. Only
    /// ever set while live reading runs.
    var guidance: String?
    /// The live-reading loop, cancelled by `stopLive`.
    var liveTask: Task<Void, Never>?
    /// Whether this screen switched the torch on, so it can switch it back off
    /// rather than leaving a light burning on someone else's next capture.
    var didEnableTorch = false
    /// Whether the live loop should start again once playback finishes.
    ///
    /// Set by `ReadingSession+Live.readSettledPage`, which stops the loop to
    /// read a page out. Without this, "keep reading" read exactly one page and
    /// then went quiet for good while the screen still said it was looking.
    var shouldResumeLiveAfterPlayback = false
    /// The playback loop, cancelled by `pause` and by every transport control.
    private var playbackTask: Task<Void, Never>?

    let phrasing: Phrasing = .init()
    /// The user's chosen language, refreshed on every entry point rather than
    /// captured once — Settings can change underneath this screen.
    var locale: Locale = .current
    /// Internal so `ReadingSession+Live.swift` reuses this instance rather than
    /// standing up a recognizer per live frame.
    let ocr: OCRService = .init()
    private let scanner: DocumentScanner = .init()
    private let historyStore: ReadingHistoryStore

    /// Creates a session.
    ///
    /// - Parameter historyStore: Where read documents are persisted.
    ///   Injectable so tests and previews never touch the real file.
    init(historyStore: ReadingHistoryStore = ReadingHistoryStore()) {
        self.historyStore = historyStore
    }

    /// Whether there is a document to play, step through, or save.
    var hasDocument: Bool {
        !playback.segments.isEmpty
    }

    /// The document as one block of text, for the scrollable transcript.
    var documentText: String {
        TextSegmenter.joined(pages)
    }

    // MARK: - Capture

    /// Captures one page, recognizes it, and adds it to the document.
    ///
    /// Every page goes through `DocumentScanner` first. A page photographed at
    /// an angle recognizes badly, and the correction is a no-op on the frames
    /// that are not pages, so there is nothing to gate it on.
    func capturePage(environment: AppEnvironment) async {
        guard !isBusy else { return }
        isBusy = true
        isSettingsFixable = false
        defer { isBusy = false }
        locale = environment.settings.language.locale ?? .current
        await environment.output.render(OutputMessage(text: "", signal: .captureTaken))
        do {
            let photo = try await environment.camera.capturePhoto()
            let flattened = try await scanner.flattened(photo)
            let lines = try await ocr.recognize(flattened)
            addPage(lines.map(\.text), environment: environment)
        } catch {
            await report(error, environment: environment)
        }
    }

    /// Adds one recognized page and says where the document now stands.
    private func addPage(_ lines: [String], environment: AppEnvironment) {
        pages.append(TextSegmenter.joined(lines))
        playback = ReadingPlayback(segments: TextSegmenter.segments(from: documentText, locale: locale))
        let spoken = lines.isEmpty
            ? phrasing.nothingRecognized(locale: locale)
            : phrasing.pageAdded(pages.count, locale: locale)
        Task { await announce(spoken, signal: lines.isEmpty ? .nothingFound : .resultReady, environment: environment) }
    }

    /// Ends the multi-page capture, stores the document if history is on, and
    /// starts reading it aloud.
    func finishDocument(environment: AppEnvironment) async {
        guard hasDocument else { return }
        let document = ReadingDocument(pages: pages)
        if environment.settings.readingHistoryEnabled {
            history = await historyStore.add(document)
        }
        await play(environment: environment)
    }

    /// Replaces the document with a page read off the live feed.
    ///
    /// Internal so `ReadingSession+Live.swift` can hand its settled page over —
    /// the transport controls then work on it exactly as they do on a captured
    /// one, so a live read is re-readable rather than a one-shot the user has
    /// to re-aim for.
    func adoptLiveText(_ text: String) {
        pages = [text]
        playback = ReadingPlayback(segments: TextSegmenter.segments(from: text, locale: locale))
    }

    /// Throws the current document away without storing it.
    ///
    /// Offered as its own control rather than only as "start another capture":
    /// a user who photographed the wrong thing needs a way to be sure the text
    /// is gone, and on this screen the text may be a prescription label.
    func discardDocument() {
        pause()
        pages = []
        playback = ReadingPlayback(segments: [])
        status = nil
    }

    // MARK: - Playback

    /// Speaks from the current segment onward, advancing as each finishes.
    func play(environment: AppEnvironment) async {
        guard hasDocument else { return }
        pause()
        locale = environment.settings.language.locale ?? .current
        isPlaying = true
        playbackTask = Task { [weak self] in
            await self?.runPlayback(environment: environment)
        }
    }

    /// Stops after the current segment rather than mid-word.
    func pause() {
        playbackTask?.cancel()
        playbackTask = nil
        isPlaying = false
    }

    /// Moves to the next segment and speaks it.
    func next(environment: AppEnvironment) async {
        pause()
        if playback.advance() == nil {
            await announce(phrasing.endOfDocument(locale: locale), signal: .nothingFound, environment: environment)
        } else {
            await speakCurrent(environment: environment)
        }
    }

    /// Moves to the previous segment and speaks it.
    func previous(environment: AppEnvironment) async {
        pause()
        playback.retreat()
        await speakCurrent(environment: environment)
    }

    /// Returns to the first segment and says so.
    func restart(environment: AppEnvironment) async {
        pause()
        playback.restart()
        await announce(
            phrasing.restartedFromBeginning(locale: locale), signal: .resultReady, environment: environment
        )
        await speakCurrent(environment: environment)
    }

    /// Jumps to a segment chosen from the transcript.
    func move(to position: Int, environment: AppEnvironment) async {
        pause()
        playback.move(to: position)
        await speakCurrent(environment: environment)
    }

    /// Says where playback is, on demand.
    ///
    /// On demand rather than before every segment: prefixing "sentence 4 of 30"
    /// to each utterance is how a two-minute page becomes a four-minute one.
    func announcePosition(environment: AppEnvironment) async {
        guard let position = playback.position else {
            await announce(phrasing.endOfDocument(locale: locale), signal: .nothingFound, environment: environment)
            return
        }
        await announce(
            phrasing.playbackPosition(position, of: playback.count, locale: locale),
            signal: .resultReady,
            environment: environment
        )
    }

    /// Speaks the segment under the cursor, without advancing.
    private func speakCurrent(environment: AppEnvironment) async {
        guard let segment = playback.current else { return }
        await announce(segment, signal: .resultReady, environment: environment)
    }

    /// How long to hold each segment when the profile carries no speech
    /// channel and there is therefore no utterance to wait on.
    private static let silentSegmentInterval: Duration = .seconds(3)

    /// The playback loop: deliver, wait for the segment to land, advance.
    private func runPlayback(environment: AppEnvironment) async {
        defer { isPlaying = false }
        while !Task.isCancelled, let segment = playback.current {
            status = segment
            await deliverSegment(segment, environment: environment)
            guard !Task.isCancelled else { return }
            if playback.advance() == nil {
                await announce(phrasing.endOfDocument(locale: locale), signal: .nothingFound, environment: environment)
                await resumeLiveIfArmed(environment: environment)
                return
            }
        }
    }

    /// Delivers one segment through the channels the user's profile actually
    /// wants, and does not return until it has landed.
    ///
    /// The speech target is addressed directly **only** when the profile asks
    /// for speech. Going straight to it unconditionally read a bank letter out
    /// loud to someone on the haptic-only `.deafBlind` profile, who cannot hear
    /// that it is happening — and, on `.blind`, dispatched every sentence twice
    /// because `render` had already started the utterance that `speak` then
    /// cancelled and restarted.
    private func deliverSegment(_ segment: String, environment: AppEnvironment) async {
        let message = OutputMessage(text: segment, signal: .resultReady)
        guard environment.settings.outputProfile.preferredChannels.contains(.speech) else {
            announceIfUnspoken(segment, profile: environment.settings.outputProfile)
            await environment.output.render(message)
            // No utterance to await off the speech channel, so the cadence is
            // fixed rather than derived from how long the segment takes to
            // speak — a caption reader sets their own pace within it, and a
            // haptic-only profile has no prose to pace at all. Cancellable, so
            // pause still takes effect within one segment.
            try? await Task.sleep(for: Self.silentSegmentInterval)
            return
        }
        // Awaited so the next segment starts when this one *ends*, rather than
        // on a timer that drifts out of step on the first long sentence and
        // cuts it in half.
        await environment.speech.speak(message)
    }

    /// Restarts continuous reading after a page has finished playing, if that is
    /// what the user is still in the middle of.
    ///
    /// Checks the persisted mode rather than trusting the flag alone: the user
    /// may have switched to capture, or left playback running and walked away,
    /// while the page was being read out.
    private func resumeLiveIfArmed(environment: AppEnvironment) async {
        guard shouldResumeLiveAfterPlayback else { return }
        shouldResumeLiveAfterPlayback = false
        guard environment.settings.readingMode == .live else { return }
        await startLive(environment: environment)
    }

    // MARK: - History

    /// Loads stored documents, or clears the in-memory list when history is off.
    func refreshHistory(environment: AppEnvironment) async {
        guard environment.settings.readingHistoryEnabled else {
            history = []
            return
        }
        history = await historyStore.documents()
    }

    /// Loads a stored document into playback and starts reading it.
    func open(_ document: ReadingDocument, environment: AppEnvironment) async {
        pause()
        pages = document.pages
        playback = ReadingPlayback(segments: TextSegmenter.segments(from: documentText, locale: locale))
        await play(environment: environment)
    }

    /// Deletes one stored document.
    func delete(_ document: ReadingDocument) async {
        history = await historyStore.remove(id: document.id)
    }

    /// Deletes every stored document and the file behind them.
    func clearHistory() async {
        await historyStore.clear()
        history = []
    }

    // MARK: - Output

    /// Mirrors `text` on screen and sends it to every channel the profile wants.
    ///
    /// Internal rather than `private` so `ReadingSession+Live.swift` can use it.
    func announce(_ text: String, signal: OutputSignal, environment: AppEnvironment) async {
        status = text
        announceIfUnspoken(text, profile: environment.settings.outputProfile)
        await environment.output.render(OutputMessage(text: text, signal: signal))
    }

    /// Turns a failure into prose that says what to do next, and records
    /// whether the Settings app is where to do it.
    private func report(_ error: Error, environment: AppEnvironment) async {
        isSettingsFixable = OpenSettingsButton.canResolve(error)
        await announce(Self.message(for: error), signal: .error, environment: environment)
    }

    /// User-facing prose for a capture or recognition failure.
    static func message(for error: Error) -> String {
        switch error {
        case CameraSource.CameraError.authorizationDenied:
            String(localized: "Camera access is needed to read text. Enable it in Settings.")
        case CameraSource.CameraError.noCameraAvailable:
            String(localized: "No camera is available on this device.")
        default:
            String(localized: "Couldn't read the photo. Try again.")
        }
    }
}
