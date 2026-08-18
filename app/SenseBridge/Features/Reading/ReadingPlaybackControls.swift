import SenseBridgeCore
import SwiftUI

/// The transport row for sentence-level playback.
///
/// Five plain buttons rather than a scrubber. A scrubber is a continuous
/// gesture over a value a blind user cannot see, whereas "back one sentence" is
/// a discrete step they can count — and every control here has a text label, so
/// VoiceOver reads an instruction rather than a glyph name.
struct ReadingPlaybackControls: View {
    /// The session driving playback.
    let session: ReadingSession
    /// Shared app state, needed by every transport action.
    let environment: AppEnvironment

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Stated as text as well as spoken, so a sighted helper and a
            // braille display both see where playback is without triggering
            // the spoken announcement.
            Text(positionLabel)
                .font(.footnote)
                .foregroundStyle(Color("SecondaryText"))
                // Exposed, not hidden. Hiding it would take away information a
                // sighted user has continuously and leave "Where am I?" as the
                // only route to it — an extra tap, every time. The trait stops
                // VoiceOver announcing it on every sentence change while still
                // letting a user swipe to it whenever they want the position.
                .accessibilityAddTraits(.updatesFrequently)
            HStack(spacing: 12) {
                Button("Previous") {
                    Task { await session.previous(environment: environment) }
                }
                .accessibilityValue(unavailableReason)
                .accessibilityHint("Reads the previous sentence again.")
                Button(session.isPlaying ? "Pause" : "Play") {
                    Task {
                        if session.isPlaying {
                            session.pause()
                        } else {
                            await session.play(environment: environment)
                        }
                    }
                }
                .accessibilityValue(unavailableReason)
                .accessibilityHint(session.isPlaying
                    ? "Stops after the current sentence."
                    : "Reads the rest of the text aloud, one sentence at a time.")
                Button("Next") {
                    Task { await session.next(environment: environment) }
                }
                .accessibilityValue(unavailableReason)
                .accessibilityHint("Skips to the next sentence.")
            }
            HStack(spacing: 12) {
                Button("Read from the beginning") {
                    Task { await session.restart(environment: environment) }
                }
                .accessibilityValue(unavailableReason)
                Button("Where am I?") {
                    Task { await session.announcePosition(environment: environment) }
                }
                .accessibilityValue(unavailableReason)
                .accessibilityHint("Says which sentence is being read, and how many there are.")
            }
        }
        .buttonStyle(.bordered)
        .disabled(!session.hasDocument)
    }

    /// Why every control here is dim, or empty when they are not.
    ///
    /// Without it VoiceOver says "button, dimmed" and stops — a control that
    /// has silently gone unavailable, with no account of why or of what would
    /// bring it back. The same contract the Capture button in `ReadingView` and
    /// "Check once" in `ObstacleAwarenessView` already honour.
    private var unavailableReason: String {
        session.hasDocument
            ? ""
            : String(localized: "Unavailable until something has been read")
    }

    /// "Sentence 4 of 30", or the end-of-document state.
    ///
    /// Built here rather than read from `Phrasing` because this string is
    /// rendered, not spoken — `Phrasing`'s copy is written for a synthesizer and
    /// reads as a fragment on screen.
    private var positionLabel: String {
        guard session.hasDocument else {
            return String(localized: "Nothing has been read yet.")
        }
        guard let position = session.playback.position else {
            return String(localized: "End of the text.")
        }
        return String(
            localized: "Sentence \(position) of \(session.playback.count)",
            comment: "On-screen playback position for the Read screen."
        )
    }
}
