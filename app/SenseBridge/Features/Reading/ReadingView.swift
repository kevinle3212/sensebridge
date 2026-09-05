import SenseBridgeCore
import SwiftUI
import UIKit
import UniformTypeIdentifiers

/// Reads text aloud, either from photos the user takes or continuously off the
/// live feed.
///
/// Two modes, named at the point of choice rather than hidden in Settings,
/// because they behave differently in ways a blind user would otherwise have to
/// infer from silence. **Capture** takes one photo per tap and can build a
/// multi-page document; **live** reads whatever the camera settles on, guiding
/// the user's aim as they move. Camera → Vision OCR → Speech, entirely
/// on-device — see docs/ARCHITECTURE.md "Data flow — read this document".
struct ReadingView: View {
    /// Shared app state — the camera session and output targets live here so
    /// every feature drives the same instances rather than each standing up
    /// its own.
    @Environment(AppEnvironment.self) private var environment

    /// Capture, playback, live reading, and history for this screen.
    @State private var session: ReadingSession = .init()

    /// The reader's text size, so the mode picker can drop a control style that
    /// truncates instead of reflowing.
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    /// Whether the app is foregrounded, so playback and live reading stop when
    /// it is not — see the `onChange` in `body`.
    @Environment(\.scenePhase) private var scenePhase

    /// How long copied text stays on the clipboard, in seconds.
    ///
    /// Ten minutes: long enough to paste into a message or a notes app, short
    /// enough that a bank letter is not still sitting in the clipboard that
    /// evening. iOS clears it on expiry without the app running.
    private static let pasteboardLifetime: TimeInterval = 600

    /// The language chosen in Settings, for casing the on-screen caption —
    /// not the process locale, which may differ from what the user picked.
    private var displayLocale: Locale {
        environment.settings.language.locale ?? .current
    }

    private let liveExplanation: LocalizedStringKey = """
    Live reading keeps looking and tells you how to aim. It reads a page out \
    once the text stops changing, and turns the light on if the view is dark.
    """

    var body: some View {
        @Bindable var environment = environment
        return ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                modePicker(settings: $environment.settings)
                CameraPreviewView(cameraSource: environment.camera.source)
                    .frame(height: 240)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    // A live camera feed has no accessible content of its own —
                    // the controls below are how a VoiceOver user drives this
                    // screen, not the preview.
                    .accessibilityHidden(true)
                CameraControlsView(camera: environment.camera)
                captureControls
                if let guidance = session.guidance {
                    // Live aiming guidance. Announced through VoiceOver as well
                    // as spoken, so it reaches a user whose profile has speech
                    // switched off.
                    Text(guidance)
                        .font(.callout)
                        .accessibilityAddTraits(.updatesFrequently)
                }
                if session.hasDocument {
                    ReadingPlaybackControls(session: session, environment: environment)
                    transcript
                }
                if let status = session.status {
                    // Capitalized for the screen only. The hedge templates are lowercase
                    // because they are built for speech and for mid-sentence embedding;
                    // rendering one verbatim as a caption reads as a typo, not caution.
                    Text(Phrasing.forDisplay(status, locale: displayLocale))
                        .font(.callout)
                        .foregroundStyle(Color("SecondaryText"))
                    if session.isSettingsFixable {
                        OpenSettingsButton()
                    }
                }
                NavigationLink("Reading history") {
                    ReadingHistoryView(session: session, environment: environment)
                }
                .accessibilityHint("Shows text you have read before, if history is switched on.")
            }
            .padding()
        }
        .navigationTitle("Read")
        // The transport row, the transcript, and the "Open Settings" button all
        // appear part-way down a screen the user has already been read out. A
        // VoiceOver user who does not hear that the layout changed has no way to
        // know five new controls now exist below them — the same reason
        // `startCameraIfNeeded()` posts this for the camera controls.
        .onChange(of: session.hasDocument) { _, _ in
            UIAccessibility.post(notification: .layoutChanged, argument: nil)
        }
        .onChange(of: session.isSettingsFixable) { _, _ in
            UIAccessibility.post(notification: .layoutChanged, argument: nil)
        }
        // `onDisappear` does not fire when the app is backgrounded or the screen
        // locks, and this target declares the `audio` background mode — so
        // without this, "Read it all" on a medical result keeps announcing it
        // from a locked phone in a pocket, and live reading keeps saying "no
        // text is being recognized" indefinitely. That is the same lock state
        // `.completeFileProtection` exists to defend.
        .onChange(of: scenePhase) { _, phase in
            guard phase != .active else { return }
            session.pause()
            Task { await session.stopLive(environment: environment) }
        }
        .task { await startCameraIfNeeded() }
        .onDisappear {
            Task {
                await session.stopLive(environment: environment)
                session.pause()
                await environment.camera.stop()
            }
        }
    }

    // MARK: - Mode

    /// Capture versus live, persisted so the user's choice survives leaving the
    /// screen.
    private func modePicker(settings: Binding<Settings>) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            // Segmented at ordinary sizes, a plain menu at accessibility ones.
            // `UISegmentedControl` does not reflow or wrap — at large Dynamic
            // Type it truncates "One photo at a time" to something ambiguous
            // rather than growing, and a low-vision user reading at those sizes
            // is precisely who cannot afford an ambiguous label.
            Group {
                if dynamicTypeSize.isAccessibilitySize {
                    modeOptions(settings: settings).pickerStyle(.menu)
                } else {
                    modeOptions(settings: settings).pickerStyle(.segmented)
                }
            }
            .onChange(of: settings.wrappedValue.readingMode) { _, mode in
                environment.save()
                Task { await applyMode(mode) }
            }
            Text(settings.wrappedValue.readingMode == .live
                ? liveExplanation
                : "Point the camera at text, then capture, to hear it read aloud.")
                .font(.footnote)
                .foregroundStyle(Color("SecondaryText"))
        }
    }

    /// The mode picker's options, styled by the caller.
    ///
    /// Split out so the two Dynamic Type branches above share one definition of
    /// the options — two copies would eventually disagree about a tag.
    private func modeOptions(settings: Binding<Settings>) -> some View {
        Picker("Reading mode", selection: settings.readingMode) {
            Text("One photo at a time").tag(ReadingMode.capture)
            Text("Keep reading").tag(ReadingMode.live)
        }
    }

    /// Starts or stops the live loop to match `mode`.
    private func applyMode(_ mode: ReadingMode) async {
        if mode == .live {
            await session.startLive(environment: environment)
        } else {
            await session.stopLive(environment: environment)
        }
    }

    // MARK: - Capture

    @ViewBuilder
    private var captureControls: some View {
        if environment.settings.readingMode == .capture {
            HStack(spacing: 12) {
                Button(session.pages.isEmpty ? "Capture" : "Add another page") {
                    Task { await session.capturePage(environment: environment) }
                }
                .disabled(environment.camera.isCapturing || session.isBusy)
                .accessibilityLabel(session.pages.isEmpty ? "Capture document" : "Add another page")
                // Capture is asynchronous and the button disables itself while it
                // runs. Without a value, a VoiceOver user gets a control that has
                // simply gone dim with no explanation of why or for how long.
                .accessibilityValue(session.isBusy ? "Capturing" : "")
                .accessibilityHint("Takes a photo and reads any text found aloud.")
                if session.hasDocument {
                    Button("Read it all") {
                        Task { await session.finishDocument(environment: environment) }
                    }
                    .accessibilityHint("Reads every page captured so far, and saves it if history is on.")
                    Button("Discard", role: .destructive) {
                        session.discardDocument()
                    }
                    .accessibilityHint("Throws away the pages captured so far without saving them.")
                }
            }
            .buttonStyle(.bordered)
        }
    }

    // MARK: - Transcript

    /// The recognized text in full, scrollable and selectable.
    ///
    /// Present for the people speech does not reach: a low-vision user
    /// magnifying the page, a Deaf-blind user on a braille display, and anyone
    /// who wants to copy a phone number out rather than hear it twice.
    private var transcript: some View {
        VStack(alignment: .leading, spacing: 8) {
            // `.font(.headline)` is styling only — the trait is what puts this
            // in VoiceOver's Headings rotor, which is how a user jumps straight
            // to the transcript instead of swiping past every transport button.
            Text("Recognized text")
                .font(.headline)
                .accessibilityAddTraits(.isHeader)
            ScrollView {
                Text(session.documentText)
                    .font(.body)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(maxHeight: 220)
            Button("Copy text") {
                // `.localOnly`, emphatically not `UIPasteboard.general.string`.
                // The general pasteboard is Handoff-synced by default, so a
                // prescription label copied here would land in the clipboard of
                // every Mac and iPad on the same Apple ID, by way of Apple's
                // servers — the exact boundary `ReadingHistoryStore` refuses to
                // cross for these same bytes. The expiry bounds how long it sits
                // there afterwards; the user asked to copy, not to broadcast.
                UIPasteboard.general.setItems(
                    [[UTType.utf8PlainText.identifier: session.documentText]],
                    options: [
                        .localOnly: true,
                        .expirationDate: Date().addingTimeInterval(Self.pasteboardLifetime)
                    ]
                )
            }
            .buttonStyle(.bordered)
            .accessibilityHint("Copies the recognized text to the clipboard.")
        }
    }

    // MARK: - Camera

    /// Starts the shared camera, reports a start failure out loud, and brings
    /// up whichever reading mode the user last chose.
    private func startCameraIfNeeded() async {
        await environment.camera.start(applying: environment.settings)
        // A start failure must reach the user, not just get swallowed —
        // `start(applying:)` records it rather than throwing.
        if let startError = environment.camera.startError {
            await session.announce(
                ReadingSession.message(for: startError), signal: .error, environment: environment
            )
        } else {
            // The lens/zoom/torch controls only exist once a device is
            // resolved, so they appear *after* this screen has already been
            // read out. Without this the new controls are simply absent from
            // the VoiceOver user's model of the screen until they swipe past
            // where they now are.
            UIAccessibility.post(notification: .layoutChanged, argument: nil)
            await applyMode(environment.settings.readingMode)
        }
        await session.refreshHistory(environment: environment)
    }
}

#Preview {
    NavigationStack {
        ReadingView()
            .environment(AppEnvironment())
    }
}
