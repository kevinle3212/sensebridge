import Foundation

/// Persists recently read documents so a listener can hear one again without
/// re-photographing it.
///
/// ## Why this is not in `Settings`
///
/// `Settings`'s own doc comment forbids it holding user content, and recognized
/// text is the most sensitive content this app ever produces: a prescription
/// label, a bank letter, a medical result. `UserDefaults` is the wrong home for
/// it twice over — the plist is readable whenever the device is unlocked-at-boot
/// rather than unlocked-now, and it is swept into every backup.
///
/// So this is a separate file with three properties `UserDefaults` cannot give
/// it:
///
/// 1. **Opt-in.** Nothing is written unless the user turned history on. The
///    default is off, and turning it off deletes what is already there rather
///    than merely hiding it — a user revoking consent means the data goes.
/// 2. **`.completeFileProtection`.** The file is unreadable while the device is
///    locked, including by this app. A phone taken from a table is a phone whose
///    reading history cannot be extracted.
/// 3. **Excluded from backup.** Recognized text stays on the device it was read
///    on, rather than travelling to iCloud or a desktop archive where this
///    app's guarantees do not reach.
///
/// ## Bounded on purpose
///
/// Capped at ``limit`` documents, oldest evicted first. An unbounded history is
/// an unbounded liability, and nobody re-reads the hundredth-most-recent thing
/// they photographed.
///
/// An actor because the app writes to it from a capture that is already off the
/// main thread and reads from a view that is on it — see docs/ARCHITECTURE.md
/// "Main thread stays free".
public actor ReadingHistoryStore {
    /// How many documents are kept. The oldest is dropped when a new one
    /// arrives at the cap.
    public static let limit = 25

    private let fileURL: URL
    /// Loaded documents, newest first — meaningful only once ``hasLoaded`` is
    /// `true`.
    private var cached: [ReadingDocument] = []
    /// Whether the file has been read yet.
    ///
    /// A separate flag rather than an optional array, which `discouraged_optional_collection`
    /// forbids and which reads badly anyway: "no documents" and "not yet loaded"
    /// are genuinely different states, and collapsing them into `nil` is what
    /// makes an empty history re-read the file on every access.
    private var hasLoaded = false
    /// Whether the last load actually saw the file's contents.
    ///
    /// `false` means a file exists that could not be read — the device was
    /// locked, most plausibly, since this file is protected precisely so that
    /// happens. Writing over it in that state would silently destroy everything
    /// stored, so ``persist(_:)`` refuses.
    private var isReadable = true

    /// Creates a store backed by a file.
    ///
    /// - Parameter fileURL: Where to persist. Defaults to
    ///   `Application Support/reading-history.json`; injectable so tests use a
    ///   temporary directory rather than the real one.
    public init(fileURL: URL? = nil) {
        self.fileURL = fileURL ?? Self.defaultFileURL()
    }

    /// Every stored document, newest first.
    ///
    /// Returns empty rather than throwing when the file is missing, unreadable,
    /// or corrupt. A history that fails to load is an inconvenience; an app that
    /// refuses to open the Read screen because of one is a failure, and the
    /// user's route back is to re-photograph the page either way.
    public func documents() -> [ReadingDocument] {
        if !hasLoaded {
            cached = load()
            hasLoaded = true
        }
        return cached
    }

    /// Stores `document` at the head of the history, evicting past ``limit``.
    ///
    /// - Parameter document: The document to keep. One that recognized nothing
    ///   is dropped rather than stored — a history row that reads as nothing is
    ///   noise a listener has to swipe past, and it is user content held for no
    ///   benefit.
    /// - Returns: The history after the write, newest first.
    @discardableResult
    public func add(_ document: ReadingDocument) -> [ReadingDocument] {
        guard !document.recognizedNothing else { return documents() }
        var updated = documents()
        updated.removeAll { $0.id == document.id }
        updated.insert(document, at: 0)
        if updated.count > Self.limit {
            updated.removeSubrange(Self.limit...)
        }
        persist(updated)
        // `cached`, not `updated`: `persist` refuses when the existing file
        // could not be read, and the caller must be told what is actually
        // stored rather than what it asked for.
        return cached
    }

    /// Removes one document.
    /// - Returns: The history after the removal, newest first.
    @discardableResult
    public func remove(id: UUID) -> [ReadingDocument] {
        var updated = documents()
        updated.removeAll { $0.id == id }
        persist(updated)
        return cached
    }

    /// Deletes every stored document and the file itself.
    ///
    /// Removes the file rather than writing an empty array over it. An empty
    /// JSON array still leaves the previous contents recoverable from unallocated
    /// blocks on some filesystems, and "clear my history" has to mean the thing
    /// the user thinks it means.
    public func clear() {
        cached = []
        hasLoaded = true
        try? FileManager.default.removeItem(at: fileURL)
        // Deleting always succeeds in leaving a readable (absent) state, so a
        // store that had refused to write is usable again afterwards.
        isReadable = true
    }

    /// Deletes the persisted file without loading it, for a caller that has no
    /// store yet.
    ///
    /// Exists for `-uiTestReset`, which resets `Settings` at launch and used to
    /// leave this file untouched — so a "clean" UI-test launch inherited the
    /// previous run's recognized text, and a history assertion could pass on
    /// data the test never created. `static` rather than an instance method
    /// because the reset runs in `AppEnvironment.init`, before any store or any
    /// `await` exists; deleting the file there is synchronous and cannot race
    /// the store that reads it later.
    ///
    /// - Parameter fileURL: Where to delete from. Defaults to the same location
    ///   ``init(fileURL:)`` defaults to.
    public static func removePersistedHistory(fileURL: URL? = nil) {
        try? FileManager.default.removeItem(at: fileURL ?? defaultFileURL())
    }

    // MARK: - Disk

    /// Reads and decodes the file, yielding empty on any failure — see
    /// ``documents()`` for why this never throws.
    ///
    /// Sets ``isReadable`` to `false` when the *read* failed while the file is
    /// still on disk, which is a different situation from a corrupt or absent
    /// file and must not be answered the same way. The realistic case is the one
    /// this whole type is built around: `.completeFileProtection` denying access
    /// because the device is locked. Treating that as "history is empty" and
    /// then writing would destroy every stored document — see ``persist(_:)``.
    private func load() -> [ReadingDocument] {
        guard let data = try? Data(contentsOf: fileURL) else {
            isReadable = !FileManager.default.fileExists(atPath: fileURL.path)
            return []
        }
        isReadable = true
        guard let decoded = try? JSONDecoder().decode([ReadingDocument].self, from: data) else {
            // Corrupt JSON, on the other hand, is unrecoverable, and the next
            // write is the only thing that can put the file back in a good
            // state. `recoversFromACorruptFileOnTheNextWrite` pins that.
            return []
        }
        return decoded
    }

    /// Writes `documents`, creating the directory and applying file protection.
    ///
    /// Protection is set in the write options **and** re-applied to the file
    /// afterwards: `Data.write(options:)` honours the attribute when it creates
    /// a file, and an atomic replace of an existing file can otherwise inherit
    /// the replacement's default protection instead of the original's.
    private func persist(_ documents: [ReadingDocument]) {
        // Refuses rather than overwriting when the existing file could not be
        // read. Otherwise one locked-device read turns a 24-document history
        // into a 1-document one, with no error anywhere and nothing to notice.
        guard isReadable else { return }
        cached = documents
        hasLoaded = true
        guard let data = try? JSONEncoder().encode(documents) else { return }
        let directory = fileURL.deletingLastPathComponent()
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        #if os(iOS)
            try? data.write(to: fileURL, options: [.atomic, .completeFileProtection])
            try? FileManager.default.setAttributes(
                [.protectionKey: FileProtectionType.complete],
                ofItemAtPath: fileURL.path
            )
        #else
            // macOS has no data-protection classes; the file is still excluded
            // from backup below. Tests run here, which is why this path exists
            // at all rather than the type being iOS-only.
            try? data.write(to: fileURL, options: .atomic)
        #endif
        excludeFromBackup()
    }

    /// Marks the file as not-for-backup, so recognized text never leaves the
    /// device it was read on.
    private func excludeFromBackup() {
        var url = fileURL
        var values = URLResourceValues()
        values.isExcludedFromBackup = true
        try? url.setResourceValues(values)
    }

    /// The default on-device location.
    ///
    /// Application Support rather than Documents: this is app-managed state the
    /// user never browses as files, and Documents is exposed through the Files
    /// app on a device with file sharing enabled.
    private static func defaultFileURL() -> URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSTemporaryDirectory())
        return base
            .appendingPathComponent("SenseBridge", isDirectory: true)
            .appendingPathComponent("reading-history.json")
    }
}
