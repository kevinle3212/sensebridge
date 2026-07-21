---
name: swift-protocol-di-testing
description:
    Use when making Swift code testable — abstract external dependencies behind
    small, focused protocols and inject mocks, so tests are deterministic and
    run without I/O or hardware.
metadata:
    origin: ECC (MIT) — see CREDITS.md
---

## Tool Fallback <!-- tool-fallback -->

- If a preferred tool, command, or skill is unavailable, failing, or a worse fit
  for the task, use the best available alternative rather than stopping or
  forcing it. Note which tool you used and why. Never fall back to a tool the
  repository or user has explicitly prohibited.

## Clarify Before Acting <!-- clarify-before-acting -->

If the boundary being mocked is ambiguous, agree the protocol before writing the
mock. See the [api-design](../api-design/SKILL.md) skill — it owns where the
seams go; this skill only covers how to test across them.

# Swift Protocol-Based Dependency Injection for Testing

**Why this matters here:** the seams this technique injects at are the ones
`CLAUDE.md` already names — `SensingSource` → perception services → Reasoning →
`RenderTarget`. Mocking them is what lets reasoning logic be tested as pure
logic, with no camera, no microphone, and no device.

**Read the generic examples with care.** The source examples mock a network and
iCloud; SenseBridge is serverless and on-device, so there is no network seam to
inject here. Apply the pattern to capture, perception, and render boundaries
instead — a new network dependency would violate an architecture invariant, not
just need a mock.

Patterns for making Swift code testable by abstracting external dependencies (file system, network, iCloud) behind small, focused protocols. Enables deterministic tests without I/O.

## When to Activate

- Writing Swift code that accesses file system, network, or external APIs
- Need to test error handling paths without triggering real failures
- Building modules that work across environments (app, test, SwiftUI preview)
- Designing testable architecture with Swift concurrency (actors, Sendable)

## Core Pattern

### 1. Define Small, Focused Protocols

Each protocol handles exactly one external concern.

```swift
// File system access
public protocol FileSystemProviding: Sendable {
    func containerURL(for purpose: Purpose) -> URL?
}

// File read/write operations
public protocol FileAccessorProviding: Sendable {
    func read(from url: URL) throws -> Data
    func write(_ data: Data, to url: URL) throws
    func fileExists(at url: URL) -> Bool
}

// Bookmark storage (e.g., for sandboxed apps)
public protocol BookmarkStorageProviding: Sendable {
    func saveBookmark(_ data: Data, for key: String) throws
    func loadBookmark(for key: String) throws -> Data?
}
```

### 2. Create Default (Production) Implementations

```swift
public struct DefaultFileSystemProvider: FileSystemProviding {
    public init() {}

    public func containerURL(for purpose: Purpose) -> URL? {
        FileManager.default.url(forUbiquityContainerIdentifier: nil)
    }
}

public struct DefaultFileAccessor: FileAccessorProviding {
    public init() {}

    public func read(from url: URL) throws -> Data {
        try Data(contentsOf: url)
    }

    public func write(_ data: Data, to url: URL) throws {
        try data.write(to: url, options: .atomic)
    }

    public func fileExists(at url: URL) -> Bool {
        FileManager.default.fileExists(atPath: url.path)
    }
}
```

### 3. Create Mock Implementations for Testing

```swift
public final class MockFileAccessor: FileAccessorProviding, @unchecked Sendable {
    public var files: [URL: Data] = [:]
    public var readError: Error?
    public var writeError: Error?

    public init() {}

    public func read(from url: URL) throws -> Data {
        if let error = readError { throw error }
        guard let data = files[url] else {
            throw CocoaError(.fileReadNoSuchFile)
        }
        return data
    }

    public func write(_ data: Data, to url: URL) throws {
        if let error = writeError { throw error }
        files[url] = data
    }

    public func fileExists(at url: URL) -> Bool {
        files[url] != nil
    }
}
```

### 4. Inject Dependencies with Default Parameters

Production code uses defaults; tests inject mocks.

```swift
public actor SyncManager {
    private let fileSystem: FileSystemProviding
    private let fileAccessor: FileAccessorProviding

    public init(
        fileSystem: FileSystemProviding = DefaultFileSystemProvider(),
        fileAccessor: FileAccessorProviding = DefaultFileAccessor()
    ) {
        self.fileSystem = fileSystem
        self.fileAccessor = fileAccessor
    }

    public func sync() async throws {
        guard let containerURL = fileSystem.containerURL(for: .sync) else {
            throw SyncError.containerNotAvailable
        }
        let data = try fileAccessor.read(
            from: containerURL.appendingPathComponent("data.json")
        )
        // Process data...
    }
}
```

### 5. Write Tests Against the Mocks

**Framework:** **Swift Testing** for unit and integration, which is what the
examples below use. XCTest is retained for end-to-end (`XCUITest`) and
performance (`XCTMetric`) only. [`docs/TESTING.md`](../../../docs/TESTING.md)
is the authority and explains the split; the [testing](../testing/SKILL.md)
skill covers how to write them.

Note that the seams above are framework-independent — the protocol, the mock,
and the error-path coverage would be identical under XCTest. That is the point:
if the E2E layer ever needs one of these mocks, it moves across unchanged.

```swift
import Testing

@Test("Sync manager handles missing container")
func testMissingContainer() async {
    let mockFileSystem = MockFileSystemProvider(containerURL: nil)
    let manager = SyncManager(fileSystem: mockFileSystem)

    await #expect(throws: SyncError.containerNotAvailable) {
        try await manager.sync()
    }
}

@Test("Sync manager reads data correctly")
func testReadData() async throws {
    let mockFileAccessor = MockFileAccessor()
    mockFileAccessor.files[testURL] = testData

    let manager = SyncManager(fileAccessor: mockFileAccessor)
    let result = try await manager.loadData()

    #expect(result == expectedData)
}

@Test("Sync manager handles read errors gracefully")
func testReadError() async {
    let mockFileAccessor = MockFileAccessor()
    mockFileAccessor.readError = CocoaError(.fileReadCorruptFile)

    let manager = SyncManager(fileAccessor: mockFileAccessor)

    await #expect(throws: SyncError.self) {
        try await manager.sync()
    }
}
```

## Best Practices

- **Single Responsibility**: Each protocol should handle one concern — don't create "god protocols" with many methods
- **Sendable conformance**: Required when protocols are used across actor boundaries
- **Default parameters**: Let production code use real implementations by default; only tests need to specify mocks
- **Error simulation**: Design mocks with configurable error properties for testing failure paths
- **Only mock boundaries**: Mock external dependencies (file system, network, APIs), not internal types

## Anti-Patterns to Avoid

- Creating a single large protocol that covers all external access
- Mocking internal types that have no external dependencies
- Using `#if DEBUG` conditionals instead of proper dependency injection
- Forgetting `Sendable` conformance when used with actors
- Over-engineering: if a type has no external dependencies, it doesn't need a protocol

## When to Use

- Any Swift code that touches file system, network, or external APIs
- Testing error handling paths that are hard to trigger in real environments
- Building modules that need to work in app, test, and SwiftUI preview contexts
- Apps using Swift concurrency (actors, structured concurrency) that need testable architecture
