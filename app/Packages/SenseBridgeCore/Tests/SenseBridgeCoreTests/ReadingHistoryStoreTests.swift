import Foundation
import Testing
@testable import SenseBridgeCore

struct ReadingHistoryStoreTests {
    /// A file URL in a fresh temporary directory, so no test sees another's
    /// history and none touches the real Application Support location.
    private func temporaryFileURL() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("sensebridge-history-tests", isDirectory: true)
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
            .appendingPathComponent("reading-history.json")
    }

    @Test
    func startsEmptyWhenNoFileHasBeenWritten() async {
        let store = ReadingHistoryStore(fileURL: temporaryFileURL())

        #expect(await store.documents().isEmpty)
    }

    @Test
    func keepsTheNewestDocumentFirst() async {
        let store = ReadingHistoryStore(fileURL: temporaryFileURL())

        await store.add(ReadingDocument(pages: ["first"]))
        let history = await store.add(ReadingDocument(pages: ["second"]))

        #expect(history.map(\.text) == ["second", "first"])
    }

    @Test
    func dropsADocumentThatRecognizedNothingRatherThanStoringIt() async {
        // Storing it would be user content held for no benefit, and a history
        // row that reads as nothing is noise a listener has to swipe past.
        let store = ReadingHistoryStore(fileURL: temporaryFileURL())

        let history = await store.add(ReadingDocument(pages: ["", "   "]))

        #expect(history.isEmpty)
    }

    @Test
    func evictsTheOldestOnceTheCapIsReached() async {
        let store = ReadingHistoryStore(fileURL: temporaryFileURL())

        for index in 0 ... ReadingHistoryStore.limit {
            await store.add(ReadingDocument(pages: ["page \(index)"]))
        }
        let history = await store.documents()

        #expect(history.count == ReadingHistoryStore.limit)
        #expect(history.first?.text == "page \(ReadingHistoryStore.limit)")
        #expect(!history.contains { $0.text == "page 0" })
    }

    @Test
    func reAddingTheSameDocumentMovesItToTheFrontRatherThanDuplicatingIt() async {
        let store = ReadingHistoryStore(fileURL: temporaryFileURL())
        let document = ReadingDocument(pages: ["prescription"])

        await store.add(document)
        await store.add(ReadingDocument(pages: ["receipt"]))
        let history = await store.add(document)

        #expect(history.count == 2)
        #expect(history.first?.id == document.id)
    }

    @Test
    func removesOneDocumentAndLeavesTheRest() async {
        let store = ReadingHistoryStore(fileURL: temporaryFileURL())
        let doomed = ReadingDocument(pages: ["delete me"])
        await store.add(ReadingDocument(pages: ["keep me"]))
        await store.add(doomed)

        let history = await store.remove(id: doomed.id)

        #expect(history.map(\.text) == ["keep me"])
    }

    @Test
    func removingAnUnknownIdentityChangesNothing() async {
        // The identity comes from a list selection, and a list reloaded under a
        // stale selection is an ordinary race rather than a reason to misbehave.
        let store = ReadingHistoryStore(fileURL: temporaryFileURL())
        await store.add(ReadingDocument(pages: ["keep me"]))

        let history = await store.remove(id: UUID())

        #expect(history.map(\.text) == ["keep me"])
    }

    @Test
    func clearingDeletesTheFileRatherThanWritingAnEmptyArrayOverIt() async {
        // "Clear my history" has to mean the thing the user thinks it means.
        let url = temporaryFileURL()
        let store = ReadingHistoryStore(fileURL: url)
        await store.add(ReadingDocument(pages: ["bank letter"]))
        #expect(FileManager.default.fileExists(atPath: url.path))

        await store.clear()

        #expect(await store.documents().isEmpty)
        #expect(!FileManager.default.fileExists(atPath: url.path))
    }

    @Test
    func survivesARestartByReadingBackWhatWasWritten() async {
        let url = temporaryFileURL()
        let first = ReadingHistoryStore(fileURL: url)
        await first.add(ReadingDocument(pages: ["Ngày mai 👋🏽"]))

        let second = ReadingHistoryStore(fileURL: url)

        #expect(await second.documents().map(\.text) == ["Ngày mai 👋🏽"])
    }

    @Test
    func readsACorruptFileAsAnEmptyHistoryRatherThanRefusingToOpen() async throws {
        // An unreadable history is an inconvenience; a Read screen that will not
        // open because of one is a failure, and the user's route back — take the
        // photo again — is the same either way.
        let url = temporaryFileURL()
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(), withIntermediateDirectories: true
        )
        try Data("not json at all".utf8).write(to: url)

        let store = ReadingHistoryStore(fileURL: url)

        #expect(await store.documents().isEmpty)
    }

    @Test
    func recoversFromACorruptFileOnTheNextWrite() async throws {
        let url = temporaryFileURL()
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(), withIntermediateDirectories: true
        )
        try Data("{".utf8).write(to: url)
        let store = ReadingHistoryStore(fileURL: url)

        await store.add(ReadingDocument(pages: ["Gate 12."]))

        #expect(await ReadingHistoryStore(fileURL: url).documents().map(\.text) == ["Gate 12."])
    }

    @Test
    func removesThePersistedFileWithoutNeedingAStore() async {
        // What `-uiTestReset` calls at launch, before any store exists: a UI
        // test that inherits the previous run's recognized text is not starting
        // from the known state it claims to.
        let url = temporaryFileURL()
        await ReadingHistoryStore(fileURL: url).add(ReadingDocument(pages: ["prescription label"]))
        #expect(FileManager.default.fileExists(atPath: url.path))

        ReadingHistoryStore.removePersistedHistory(fileURL: url)

        #expect(!FileManager.default.fileExists(atPath: url.path))
        #expect(await ReadingHistoryStore(fileURL: url).documents().isEmpty)
    }

    @Test
    func removingAnAbsentHistoryFileIsNotAnError() {
        // Every launch under `-uiTestReset` hits this, and all but the first
        // find nothing to delete.
        ReadingHistoryStore.removePersistedHistory(fileURL: temporaryFileURL())
    }

    @Test
    func writesTheFileOutsideTheBackupSet() async throws {
        // Recognized text stays on the device it was read on rather than
        // travelling to iCloud or a desktop archive.
        let url = temporaryFileURL()
        let store = ReadingHistoryStore(fileURL: url)
        await store.add(ReadingDocument(pages: ["medical result"]))

        let values = try url.resourceValues(forKeys: [.isExcludedFromBackupKey])

        #expect(values.isExcludedFromBackup == true)
    }
}
