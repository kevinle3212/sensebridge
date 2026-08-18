import Foundation
import Testing
@testable import SenseBridgeCore

/// Guards the one logging rule that cannot be enforced by the type system.
///
/// **What this test actually proves, and what it does not.** `OSLog` output is
/// not readable back in-process — a `Logger` writes to the unified logging
/// system, not to anything the test can capture — so this cannot assert that a
/// given value was redacted at runtime. What it can do is assert a *structural*
/// property of the source: that no logging call site interpolates a value
/// without an explicit `privacy:` label. That is a real invariant, it is the
/// one that actually fails in practice, and it fails closed.
///
/// It matters because `OSLog`'s defaults are asymmetric in the direction that
/// hurts here. A string interpolation defaults to `.private`; a numeric,
/// boolean, or raw enum interpolation defaults to **`.public`**. Every value in
/// this app that is derived from perception output and worth logging — a
/// confidence score, a class index, a proximity band, a character count — is
/// numeric. A test that only checked strings would pass while the real leak
/// shipped, which is why this checks every interpolation regardless of type.
///
/// Requiring an explicit label even where `.public` is correct is deliberate.
/// An explicit `.public` is a decision a reviewer can see and challenge; a
/// missing label is invisible and silently means the same thing.
struct AppLogPrivacyTests {
    /// Every `AppLog` call site in the package interpolates nothing, or labels
    /// every interpolation with an explicit `privacy:`.
    @Test
    func loggingCallSitesDeclarePrivacyExplicitly() throws {
        let offenders = try Self.logCallSites().filter { site in
            site.interpolationCount > 0 && site.privacyLabelCount < site.interpolationCount
        }

        #expect(
            offenders.isEmpty,
            """
            These log statements interpolate a value without an explicit `privacy:` label. \
            OSLog defaults numerics, booleans, and enums to `.public`, so an unlabelled \
            value derived from perception output is written to the log in the clear. \
            Add `privacy: .private` (or `.public`, if the value genuinely describes the \
            app rather than what it perceived):
            \(offenders.map { "  \($0.file):\($0.line) — \($0.text)" }.joined(separator: "\n"))
            """
        )
    }

    /// The package defines its loggers in exactly one place.
    ///
    /// A second `Logger(subsystem:category:)` built somewhere else would not be
    /// covered by `AppLog`'s documented rule and would file its output under a
    /// category nothing knows to read.
    @Test
    func loggersAreConstructedOnlyInAppLog() throws {
        let strays = try Self.swiftSources()
            .filter { $0.lastPathComponent != "AppLog.swift" }
            .filter { (try? String(contentsOf: $0, encoding: .utf8))?.contains("Logger(subsystem:") == true }
            .map(\.lastPathComponent)

        #expect(strays.isEmpty, "Loggers must be declared in AppLog.swift, not in: \(strays)")
    }

    // MARK: - Source scanning

    /// One logging statement found in the sources.
    private struct LogCallSite {
        let file: String
        let line: Int
        let text: String
        let interpolationCount: Int
        let privacyLabelCount: Int
    }

    /// The package's `Sources` directory, resolved from this file's own path so
    /// the test does not depend on the working directory a runner happens to use.
    private static var sourcesDirectory: URL {
        URL(fileURLWithPath: #filePath) // .../Tests/SenseBridgeCoreTests/AppLogPrivacyTests.swift
            .deletingLastPathComponent() // .../Tests/SenseBridgeCoreTests
            .deletingLastPathComponent() // .../Tests
            .deletingLastPathComponent() // .../SenseBridgeCore
            .appendingPathComponent("Sources")
    }

    /// Every Swift file in the package's sources.
    private static func swiftSources() throws -> [URL] {
        guard let walker = FileManager.default.enumerator(
            at: sourcesDirectory,
            includingPropertiesForKeys: nil
        ) else {
            throw SourceScanError.sourcesDirectoryUnreadable(sourcesDirectory.path)
        }
        let files = walker.compactMap { $0 as? URL }.filter { $0.pathExtension == "swift" }
        // Fail loudly rather than passing on an empty set: a scan that finds no
        // files would otherwise report "no offenders" and prove nothing at all.
        guard !files.isEmpty else {
            throw SourceScanError.noSwiftFilesFound(sourcesDirectory.path)
        }
        return files
    }

    /// Every line in the package that calls a logger.
    ///
    /// Line-based rather than a real parse: a logging statement that spans
    /// several lines is rare here, and the failure mode of this simplification
    /// is a false positive a human immediately understands, never a false
    /// negative that lets an unlabelled value through.
    private static func logCallSites() throws -> [LogCallSite] {
        let levels = ["debug", "info", "notice", "warning", "error", "critical", "fault", "log"]
        var sites = [LogCallSite]()

        for file in try swiftSources() {
            let contents = try String(contentsOf: file, encoding: .utf8)
            for (index, rawLine) in contents.components(separatedBy: .newlines).enumerated() {
                let line = rawLine.trimmingCharacters(in: .whitespaces)
                guard line.contains("AppLog."), levels.contains(where: { line.contains(".\($0)(") }) else { continue }
                sites.append(
                    LogCallSite(
                        file: file.lastPathComponent,
                        line: index + 1,
                        text: line,
                        interpolationCount: line.components(separatedBy: "\\(").count - 1,
                        privacyLabelCount: line.components(separatedBy: "privacy:").count - 1
                    )
                )
            }
        }
        return sites
    }

    /// Why a source scan could not produce a trustworthy answer.
    private enum SourceScanError: Error, CustomStringConvertible {
        /// The `Sources` directory could not be enumerated at all.
        case sourcesDirectoryUnreadable(String)
        /// The scan ran but matched nothing, so a pass would be meaningless.
        case noSwiftFilesFound(String)

        var description: String {
            switch self {
            case let .sourcesDirectoryUnreadable(path):
                "Could not enumerate the package sources at \(path)."
            case let .noSwiftFilesFound(path):
                "Found no Swift files under \(path); this test would pass without checking anything."
            }
        }
    }
}
