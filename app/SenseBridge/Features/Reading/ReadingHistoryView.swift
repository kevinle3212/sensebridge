import SenseBridgeCore
import SwiftUI

/// Recently read documents, so a listener can hear one again without
/// re-photographing it.
///
/// The privacy posture is stated on the screen rather than only in Settings.
/// What is stored here is the most sensitive text this app ever produces — a
/// prescription label, a bank letter, a medical result — and a user deciding
/// whether to leave history on needs to know where it lives while they decide.
struct ReadingHistoryView: View {
    /// The session that owns the store and the playback cursor.
    let session: ReadingSession
    /// Shared app state.
    let environment: AppEnvironment

    private let storageNote: LocalizedStringKey = """
    Kept on this device only, locked while the device is locked, never included \
    in a backup, and limited to the most recent 25 documents. Turning history \
    off deletes what is already here.
    """

    var body: some View {
        @Bindable var environment = environment
        return List {
            Section {
                // The consent control lives here, next to the note explaining
                // what consenting means, rather than in Settings — this is where
                // the user is actually deciding.
                Toggle("Save what I read", isOn: $environment.settings.readingHistoryEnabled)
                    .onChange(of: environment.settings.readingHistoryEnabled) { _, isEnabled in
                        environment.save()
                        // Switching it off is a revocation, so the stored text
                        // goes. Anything less would make the note above a lie.
                        if !isEnabled {
                            Task { await session.clearHistory() }
                        }
                    }
                    .accessibilityHint("""
                    Keeps the text you read on this device so you can hear it \
                    again. Turning this off deletes everything already saved.
                    """)
                Text(storageNote)
                    .font(.footnote)
                    .foregroundStyle(Color("SecondaryText"))
            }
            if session.history.isEmpty {
                // Named rather than left as an empty list. An empty screen is
                // indistinguishable from a screen that failed to load, and a
                // VoiceOver user swiping into nothing gets no explanation at all.
                Text(environment.settings.readingHistoryEnabled
                    ? "Nothing has been saved yet."
                    : "History is off, so nothing is being saved.")
                    .font(.callout)
                    .foregroundStyle(Color("SecondaryText"))
            } else {
                Section {
                    ForEach(session.history) { document in
                        Button {
                            Task { await session.open(document, environment: environment) }
                        } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(document.summary())
                                    .font(.body)
                                Text(document.capturedAt, format: .dateTime)
                                    .font(.footnote)
                                    .foregroundStyle(Color("SecondaryText"))
                            }
                        }
                        .accessibilityLabel(document.summary())
                        .accessibilityValue(document.capturedAt.formatted(date: .abbreviated, time: .shortened))
                        .accessibilityHint("Reads this text aloud again.")
                    }
                    .onDelete { offsets in
                        Task { await delete(at: offsets) }
                    }
                } header: {
                    Text("Recently read")
                        .foregroundStyle(Color("SecondaryText"))
                }
                Section {
                    Button("Delete everything saved here", role: .destructive) {
                        Task { await session.clearHistory() }
                    }
                    .accessibilityHint("Deletes every saved document and the file holding them.")
                }
            }
        }
        .navigationTitle("Reading history")
        .task { await session.refreshHistory(environment: environment) }
    }

    /// Deletes the rows at `offsets`, resolving them against the list the user
    /// was actually looking at.
    private func delete(at offsets: IndexSet) async {
        for document in offsets.compactMap({ session.history.indices.contains($0) ? session.history[$0] : nil }) {
            await session.delete(document)
        }
    }
}

#Preview {
    NavigationStack {
        ReadingHistoryView(session: ReadingSession(), environment: AppEnvironment())
    }
}
