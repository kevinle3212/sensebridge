import Foundation
import Testing
@testable import SenseBridge

/// Coverage for `DevWatermarkFooter`'s two helpers — the reading and the
/// rendering of the install date. The view itself is cosmetic and dev-only;
/// these are the parts with logic that can quietly go wrong.
struct DevWatermarkTests {
    @Test
    func readsACreationDateFromARealDirectory() throws {
        let directory = try Self.makeTempDirectory()

        let installed = try #require(
            DevWatermarkFooter.lastDownloadedDate(at: directory.path),
            "a freshly created directory must carry a creation attribute"
        )

        // A freshly created temp directory cannot predate today by much; the
        // point is that the attribute exists and parses as a `Date` at all.
        #expect(installed.timeIntervalSinceNow > -60 * 60 * 24)
    }

    /// An unreadable path hides the footer (`nil`) rather than crashing —
    /// cosmetic metadata must never become a launch failure.
    @Test
    func returnsNilForAnUnreadablePath() {
        #expect(DevWatermarkFooter.lastDownloadedDate(at: "/nonexistent/bundle.app") == nil)
    }

    /// The format is pinned because its whole job is being comparable against
    /// Xcode logs at a glance: fixed numeric fields, `en_US_POSIX`, no locale
    /// drift from the device's 12/24-hour setting.
    @Test
    func formatsAsFixedNumericTimestamp() throws {
        let reference = DateFormatter()
        reference.locale = Locale(identifier: "en_US_POSIX")
        reference.dateFormat = "yyyy-MM-dd HH:mm"

        let date = try #require(reference.date(from: "2026-08-25 13:20"))

        #expect(DevWatermarkFooter.formatted(date) == "2026-08-25 13:20")
        let rendered = DevWatermarkFooter.formatted(.now)
        #expect(rendered.range(of: #"^\d{4}-\d{2}-\d{2} \d{2}:\d{2}$"#, options: .regularExpression) != nil)
    }

    private static func makeTempDirectory() throws -> URL {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }
}
