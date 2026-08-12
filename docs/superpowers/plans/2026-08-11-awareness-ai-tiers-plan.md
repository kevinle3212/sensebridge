# Awareness feature + on-device/local/cloud reasoning tiers Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Finish the Awareness feature to investor-demo/production quality and
add a three-way reasoning backend (On-Device / Local self-hosted endpoint /
Cloud BYOK) behind the existing `SceneComposer` protocol, with a bundled
local model surfaced only as a disclosure row (not built this pass).

**Architecture:** Retire the unused `CloudReasoningAdapter` stub; every
backend — on-device, self-hosted, cloud — conforms to `SceneComposer`. New
network composers (`AnthropicSceneComposer`, `OpenAICompatibleSceneComposer`)
live in `SenseBridgeCore/Reasoning/` with injected `URLSession` so they're
`swift test`-able with no simulator. A `ReasoningOutputValidator` — not the
prompt — is the actual safety enforcement point between an HTTP response and
`Phrasing`. A `ReasoningComposerResolver` picks the active backend, runs a
circuit breaker, and falls back to on-device on any failure or absence of
configuration. `AmbientAwarenessSession` runs composition as a
cancellable, single-flight child task so a slow network call never stalls
the 750ms depth-sampling loop.

**Tech Stack:** Swift 6.2, SwiftUI, `SenseBridgeCore` SwiftPM package,
`URLSession` (no third-party networking library), Keychain (`Security`
framework), `NaturalLanguage` (Apple SDK, on-device language check), Swift
Testing (`import Testing`, matching existing test files).

## Global Constraints

- **Never let an unhedged/unvalidated string reach `Phrasing.describe` or any
  output target.** Every network composer's raw response passes through
  `ReasoningOutputValidator` first; a rejection throws and the caller falls
  back to on-device. This is the single most important constraint in this
  plan — see spec "The output validator."
- **Wire contract:** network composers serialize `.detectedObject` labels
  only. `.recognizedText`, `.detectedSound`, `.depthReading` never leave the
  device. Confidence values stay local.
- **No automatic retries anywhere** in the network composer / resolver stack.
- **API keys never enter `Settings`/`UserDefaults`.** Keychain only, via
  `APICredentialStore`, with `kSecAttrAccessibleWhenUnlockedThisDeviceOnly`
  and `kSecAttrSynchronizable: false`.
- **No TLS bypass.** No custom `URLSessionDelegate` certificate handling,
  ever.
- **Composition never blocks the depth-sampling cadence** in
  `AmbientAwarenessSession`.
- Every new/changed UI string ships in `en`, `es`, and `vi` in the same
  commit — no English-only consent copy.
- `legal/` is never edited directly — draft only, in a scratch file, for
  Kevin's explicit review (`AGENTS.md`).
- Test file naming/location matches the existing convention:
  `app/Packages/SenseBridgeCore/Tests/SenseBridgeCoreTests/<Type>Tests.swift`
  for package code, `swift test --filter <TestName>` for fast iteration from
  `app/Packages/SenseBridgeCore/`; any test touching `LocalizedCatalog`
  (translated strings) must also pass under
  `xcodebuild test -scheme SenseBridgeCore -destination 'platform=macOS'`
  from `app/`, per `docs/TESTING.md` — `swift test` alone does not compile
  `.xcstrings`.
- Full spec: `docs/superpowers/specs/2026-08-11-awareness-ai-tiers-design.md`
  — read it before Task 1. Every task below implements a section of it.

---

### Task 1: `ReasoningBackend`/`CloudProvider` enums + `Settings` migration

**Files:**

- Create: `app/Packages/SenseBridgeCore/Sources/SenseBridgeCore/Reasoning/ReasoningBackend.swift`
- Modify: `app/Packages/SenseBridgeCore/Sources/SenseBridgeCore/Storage/Settings.swift`
- Modify: `app/Packages/SenseBridgeCore/Tests/SenseBridgeCoreTests/SettingsTests.swift:11,25,32,41,64`
- Modify: `app/SenseBridgeTests/CrashReportingTests.swift:28`
- Delete: `app/Packages/SenseBridgeCore/Sources/SenseBridgeCore/CloudOptional/CloudReasoningAdapter.swift` and the now-empty `CloudOptional/` directory

**Interfaces:**

- Produces: `ReasoningBackend` (`.onDevice`, `.localEndpoint`, `.cloud`) with
  `var usesNetwork: Bool`; `CloudProvider` (`.anthropic`, `.openai`,
  `.nvidiaNIM`); `Settings.reasoningBackend: ReasoningBackend`,
  `Settings.cloudProvider: CloudProvider?`,
  `Settings.localEndpointURL: String?`,
  `Settings.reasoningModelOverride: String?` (required for `.nvidiaNIM` and
  `.localEndpoint`, optional override elsewhere — no universal default model
  exists for either). All four consumed by every later task.

- [ ] **Step 1: Write the new enum file**

```swift
// app/Packages/SenseBridgeCore/Sources/SenseBridgeCore/Reasoning/ReasoningBackend.swift
import Foundation

/// Which reasoning path composes scene descriptions. `.onDevice` is the
/// default and the only one active until the user explicitly opts into a
/// network path — see docs/superpowers/specs/2026-08-11-awareness-ai-tiers-design.md.
public enum ReasoningBackend: String, Sendable, Codable, CaseIterable {
    case onDevice, localEndpoint, cloud

    /// Whether this backend sends anything off the device. Drives the
    /// in-flight/cost-control UI and the resolver's circuit breaker — see
    /// `ReasoningComposerResolver`. Data, not a second protocol: see the
    /// spec's "Unify on SceneComposer" section for why.
    public var usesNetwork: Bool {
        self == .localEndpoint || self == .cloud
    }
}

/// A BYOK cloud provider. `.nvidiaNIM` covers both NVIDIA's hosted endpoint
/// and a self-hosted NIM container — see `OpenAICompatibleSceneComposer`.
public enum CloudProvider: String, Sendable, Codable, CaseIterable {
    case anthropic, openai, nvidiaNIM
}
```

- [ ] **Step 2: Update `Settings.swift` — replace `cloudReasoningEnabled`**

Modify `app/Packages/SenseBridgeCore/Sources/SenseBridgeCore/Storage/Settings.swift`.
Remove the `cloudReasoningEnabled: Bool` stored property (currently line 9)
and add four new properties after `hasCompletedOnboarding` (currently line
48):

```swift
    /// Which reasoning backend composes scene descriptions. `.onDevice`
    /// until the user explicitly opts into a network path.
    public var reasoningBackend: ReasoningBackend
    /// The BYOK provider when `reasoningBackend == .cloud`. `nil` means
    /// configured-but-no-provider-chosen, which the resolver treats as
    /// "not configured" and falls back to on-device silently.
    public var cloudProvider: CloudProvider?
    /// The user's self-hosted endpoint base URL when
    /// `reasoningBackend == .localEndpoint`. Not a secret — a destination —
    /// so it lives here rather than in `APICredentialStore`. Validated by
    /// `EndpointURLNormalizer` before use, not on decode.
    public var localEndpointURL: String?
    /// User-supplied model identifier. Required (enforced by the Settings
    /// UI, not this type) for `.nvidiaNIM` and `.localEndpoint`, since
    /// neither has a universal default model; optional override for
    /// `.anthropic`/`.openai`, which do.
    public var reasoningModelOverride: String?
```

Update the memberwise `init` (currently lines 50-65): remove the
`cloudReasoningEnabled: Bool = false` parameter, add after
`hasCompletedOnboarding: Bool = false`:

```swift
        reasoningBackend: ReasoningBackend = .onDevice,
        cloudProvider: CloudProvider? = nil,
        localEndpointURL: String? = nil,
        reasoningModelOverride: String? = nil
```

and in the initializer body, remove `self.cloudReasoningEnabled =
cloudReasoningEnabled` and add:

```swift
        self.reasoningBackend = reasoningBackend
        self.cloudProvider = cloudProvider
        self.localEndpointURL = localEndpointURL
        self.reasoningModelOverride = reasoningModelOverride
```

Update `CodingKeys` (currently lines 82-87): remove `cloudReasoningEnabled`,
add `reasoningBackend, cloudProvider, localEndpointURL,
reasoningModelOverride`.

Replace the custom `init(from decoder:)` (currently lines 93-121). The old
`cloudReasoningEnabled = try container.decode(Bool.self, forKey:
.cloudReasoningEnabled)` was a throwing, non-optional decode — the bug the
design review caught. New version, decoding both the new key and the legacy
one:

```swift
    /// Custom decode so settings persisted before each field below existed
    /// still decode instead of failing outright: a missing key falls back to
    /// its documented default above, matching the existing `language`
    /// back-compat handling.
    ///
    /// `reasoningBackend`'s decode is intentionally never a throwing decode
    /// of a required key — an unrecognized or absent value must degrade to
    /// `.onDevice`, never fail the whole settings blob. A prior version of
    /// this file decoded `cloudReasoningEnabled` as non-optional, which meant
    /// a single corrupted or future field could reset every other setting
    /// (speech rate, output profile, onboarding state) to its default. Never
    /// repeat that shape for a new field.
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        outputProfile = try container.decode(OutputProfile.self, forKey: .outputProfile)
        speechRate = try container.decode(Double.self, forKey: .speechRate)
        language = try container.decodeIfPresent(AppLanguage.self, forKey: .language) ?? .system
        speechPitch = try container.decodeIfPresent(Double.self, forKey: .speechPitch) ?? 0.5
        speechVolume = try container.decodeIfPresent(Double.self, forKey: .speechVolume) ?? 1.0
        hapticsEnabled = try container.decodeIfPresent(Bool.self, forKey: .hapticsEnabled) ?? true
        hapticIntensity = try container.decodeIfPresent(Double.self, forKey: .hapticIntensity) ?? 1.0
        preferredLens = try container.decodeIfPresent(CameraLens.self, forKey: .preferredLens) ?? .wide
        torchDefaultOn = try container.decodeIfPresent(Bool.self, forKey: .torchDefaultOn) ?? false
        narrationIntervalSeconds = try container.decodeIfPresent(
            Double.self, forKey: .narrationIntervalSeconds
        ) ?? 6
        awarenessAlertDistanceMeters = try container.decodeIfPresent(
            Double.self, forKey: .awarenessAlertDistanceMeters
        ) ?? 1.5
        crashReportingEnabled = try container.decodeIfPresent(
            Bool.self, forKey: .crashReportingEnabled
        ) ?? false
        hasCompletedOnboarding = try container.decodeIfPresent(
            Bool.self, forKey: .hasCompletedOnboarding
        ) ?? true

        if let backendRaw = try container.decodeIfPresent(String.self, forKey: .reasoningBackend),
           let backend = ReasoningBackend(rawValue: backendRaw) {
            reasoningBackend = backend
        } else if let legacyContainer = try? decoder.container(keyedBy: LegacyCodingKeys.self),
                  let legacyCloudEnabled = try? legacyContainer.decodeIfPresent(
                      Bool.self, forKey: .cloudReasoningEnabled
                  ),
                  legacyCloudEnabled == true {
            // Old installs that had turned the boolean on fall back to
            // on-device until they pick a provider and re-consent — see
            // `cloudProvider = nil` below and the resolver's
            // not-configured-falls-back-silently behavior.
            reasoningBackend = .cloud
        } else {
            reasoningBackend = .onDevice
        }
        cloudProvider = try container.decodeIfPresent(CloudProvider.self, forKey: .cloudProvider)
        localEndpointURL = try container.decodeIfPresent(String.self, forKey: .localEndpointURL)
        reasoningModelOverride = try container.decodeIfPresent(String.self, forKey: .reasoningModelOverride)
    }

    /// Only `cloudReasoningEnabled`, kept solely so old settings blobs still
    /// decode — see `init(from:)`. Never written; not in `CodingKeys`, so it
    /// never appears in an encoded settings blob again.
    private enum LegacyCodingKeys: String, CodingKey {
        case cloudReasoningEnabled
    }
```

- [ ] **Step 2b: Delete the unused `CloudReasoningAdapter`**

```bash
git rm app/Packages/SenseBridgeCore/Sources/SenseBridgeCore/CloudOptional/CloudReasoningAdapter.swift
rmdir app/Packages/SenseBridgeCore/Sources/SenseBridgeCore/CloudOptional
```

- [ ] **Step 3: Update the existing tests that reference the old field**

`app/Packages/SenseBridgeCore/Tests/SenseBridgeCoreTests/SettingsTests.swift:11`
— change the initializer call from `cloudReasoningEnabled: true,` to
`reasoningBackend: .cloud,`.

`SettingsTests.swift:25,41,64` — these are JSON fixture literals
`{"outputProfile":"blind","speechRate":0.5,"cloudReasoningEnabled":false}` (and
a variant with `,"language":"system"` appended). Leave these fixtures
**as-is** — they are the legacy-decode regression tests and must keep using
the old key name to prove the migration path works.

`SettingsTests.swift:32` — `#expect(decoded.cloudReasoningEnabled ==
false)` becomes `#expect(decoded.reasoningBackend == .onDevice)` (the fixture
at line 25 has `cloudReasoningEnabled: false`, which now must decode to
`.onDevice`, not `.cloud`).

Add two new test cases in the same file, next to the existing decode tests:

```swift
@Test func decodingLegacyCloudReasoningEnabledTrueFallsBackToOnDeviceUntilProviderChosen() throws {
    let json = """
    {"outputProfile":"blind","speechRate":0.5,"cloudReasoningEnabled":true,"language":"system"}
    """.data(using: .utf8)!
    let decoded = try JSONDecoder().decode(Settings.self, from: json)
    #expect(decoded.reasoningBackend == .cloud)
    #expect(decoded.cloudProvider == nil)
}

@Test func decodingUnrecognizedReasoningBackendFallsBackToOnDevice() throws {
    let json = """
    {"outputProfile":"blind","speechRate":0.5,"reasoningBackend":"somethingFutureBuildsAdded"}
    """.data(using: .utf8)!
    let decoded = try JSONDecoder().decode(Settings.self, from: json)
    #expect(decoded.reasoningBackend == .onDevice)
}
```

`app/SenseBridgeTests/CrashReportingTests.swift:28` — this is a JSON fixture
containing `"cloudReasoningEnabled":false` used to test `Settings` decoding
in a crash-reporting context. Leave it unchanged; it exercises the same
legacy-decode path and must keep working.

- [ ] **Step 4: Run the package tests**

```bash
cd app/Packages/SenseBridgeCore && swift test --filter SettingsTests
```

Expected: all `SettingsTests` cases PASS, including the two new ones.

- [ ] **Step 5: Commit**

```bash
git add app/Packages/SenseBridgeCore/Sources/SenseBridgeCore/Reasoning/ReasoningBackend.swift \
  app/Packages/SenseBridgeCore/Sources/SenseBridgeCore/Storage/Settings.swift \
  app/Packages/SenseBridgeCore/Tests/SenseBridgeCoreTests/SettingsTests.swift
git commit -m "feat(settings): replace cloudReasoningEnabled with a three-way reasoning backend"
```

---

### Task 2: Wire-contract helper on `PerceptionRecord`

**Files:**

- Modify: `app/Packages/SenseBridgeCore/Sources/SenseBridgeCore/Perception/PerceptionRecord.swift`
- Test: `app/Packages/SenseBridgeCore/Tests/SenseBridgeCoreTests/PerceptionRecordNetworkPayloadTests.swift` (new)

**Interfaces:**

- Consumes: `PerceptionRecord`, `PerceptionRecord.Kind` (existing).
- Produces: `[PerceptionRecord].detectedObjectLabelsForNetwork() -> [String]`,
  `[PerceptionRecord].weakestDetectedObjectConfidence() -> Double?` — used by
  every network composer in Tasks 5-6 to enforce data minimization.

- [ ] **Step 1: Write the failing test**

```swift
// app/Packages/SenseBridgeCore/Tests/SenseBridgeCoreTests/PerceptionRecordNetworkPayloadTests.swift
import Testing
@testable import SenseBridgeCore
import Foundation

@Suite struct PerceptionRecordNetworkPayloadTests {
    @Test func onlyDetectedObjectLabelsAreIncluded() {
        let records: [PerceptionRecord] = [
            PerceptionRecord(kind: .detectedObject(label: "chair", confidence: 0.9), capturedAt: .now),
            PerceptionRecord(kind: .recognizedText("bank statement, account 12345"), capturedAt: .now),
            PerceptionRecord(kind: .detectedSound(label: "dog_bark", confidence: 0.8), capturedAt: .now),
            PerceptionRecord(kind: .depthReading(meters: 1.2), capturedAt: .now),
            PerceptionRecord(kind: .detectedObject(label: "doorway", confidence: 0.4), capturedAt: .now)
        ]
        #expect(records.detectedObjectLabelsForNetwork() == ["chair", "doorway"])
    }

    @Test func weakestConfidenceIsTheMinimumAcrossDetectedObjectsOnly() {
        let records: [PerceptionRecord] = [
            PerceptionRecord(kind: .detectedObject(label: "chair", confidence: 0.9), capturedAt: .now),
            PerceptionRecord(kind: .detectedSound(label: "siren", confidence: 0.1), capturedAt: .now),
            PerceptionRecord(kind: .detectedObject(label: "doorway", confidence: 0.4), capturedAt: .now)
        ]
        #expect(records.weakestDetectedObjectConfidence() == 0.4)
    }

    @Test func emptyRecordsProduceEmptyLabelsAndNilConfidence() {
        let records: [PerceptionRecord] = []
        #expect(records.detectedObjectLabelsForNetwork().isEmpty)
        #expect(records.weakestDetectedObjectConfidence() == nil)
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

```bash
cd app/Packages/SenseBridgeCore && swift test --filter PerceptionRecordNetworkPayloadTests
```

Expected: FAIL — `value of type '[PerceptionRecord]' has no member 'detectedObjectLabelsForNetwork'`

- [ ] **Step 3: Implement**

Append to `app/Packages/SenseBridgeCore/Sources/SenseBridgeCore/Perception/PerceptionRecord.swift`:

```swift
/// The wire contract for every network reasoning composer — see
/// docs/superpowers/specs/2026-08-11-awareness-ai-tiers-design.md "The wire
/// contract". `.recognizedText`, `.detectedSound`, and `.depthReading` never
/// leave the device; only object labels do, and confidence values are never
/// serialized (the hedge is computed from them locally).
public extension Array where Element == PerceptionRecord {
    /// Object labels only, in order, for building a network composer's
    /// request body.
    func detectedObjectLabelsForNetwork() -> [String] {
        compactMap { record in
            guard case let .detectedObject(label, _) = record.kind else { return nil }
            return label
        }
    }

    /// The lowest detector confidence among `.detectedObject` records, or
    /// `nil` when there are none. A composed phrase naming several objects is
    /// only as trustworthy as its weakest member — see
    /// `FoundationModelsSceneComposer`'s identical reasoning for the
    /// on-device path.
    func weakestDetectedObjectConfidence() -> Double? {
        compactMap { record in
            guard case let .detectedObject(_, confidence) = record.kind else { return nil }
            return confidence
        }.min()
    }
}
```

- [ ] **Step 4: Run test to verify it passes**

```bash
cd app/Packages/SenseBridgeCore && swift test --filter PerceptionRecordNetworkPayloadTests
```

Expected: PASS, 3 tests.

- [ ] **Step 5: Commit**

```bash
git add app/Packages/SenseBridgeCore/Sources/SenseBridgeCore/Perception/PerceptionRecord.swift \
  app/Packages/SenseBridgeCore/Tests/SenseBridgeCoreTests/PerceptionRecordNetworkPayloadTests.swift
git commit -m "feat(perception): add data-minimized network payload helpers to PerceptionRecord"
```

---

### Task 3: `Phrasing` additions — hedge-fragment introspection + "couldn't measure"

**Files:**

- Modify: `app/Packages/SenseBridgeCore/Sources/SenseBridgeCore/Reasoning/Phrasing.swift`
- Modify: `app/Packages/SenseBridgeCore/Sources/SenseBridgeCore/Resources/Localizable.xcstrings`
- Modify: `app/Packages/SenseBridgeCore/Tests/SenseBridgeCoreTests/PhrasingTests.swift`

**Interfaces:**

- Produces: `Phrasing.hedgeFragments(locale:) -> [String]` (static, used by
  `ReasoningOutputValidator` in Task 5 to reject a double-hedged remote
  response); `Phrasing.couldNotMeasure(locale:) -> String` (used by Task 8's
  "Check once" fix — `nil` depth must never map to `nothingRecognized()`).

- [ ] **Step 1: Write the failing tests**

Add to `app/Packages/SenseBridgeCore/Tests/SenseBridgeCoreTests/PhrasingTests.swift`:

```swift
@Test func hedgeFragmentsCoversAllThreeCertaintyTemplatesInEnglish() {
    let fragments = Phrasing.hedgeFragments(locale: Locale(identifier: "en"))
    #expect(fragments.contains("there might be"))
    #expect(fragments.contains("it looks like there's"))
}

@Test func couldNotMeasureIsDistinctFromNothingRecognized() {
    let phrasing = Phrasing()
    let couldNotMeasure = phrasing.couldNotMeasure(locale: Locale(identifier: "en"))
    let nothingRecognized = phrasing.nothingRecognized(locale: Locale(identifier: "en"))
    #expect(couldNotMeasure != nothingRecognized)
    #expect(couldNotMeasure.lowercased().contains("measure"))
}
```

- [ ] **Step 2: Run to verify failure**

```bash
cd app/Packages/SenseBridgeCore && swift test --filter PhrasingTests
```

Expected: FAIL — `type 'Phrasing' has no member 'hedgeFragments'` / `no member 'couldNotMeasure'`

- [ ] **Step 3: Implement**

In `Phrasing.swift`, change `hedgeTemplate(for:locale:)` (currently
`private static`, lines 99-106) to build off a shared source so fragments and
full templates can't drift, and add the two new members:

```swift
    /// The three hedge templates, keyed by the certainty they apply to,
    /// **without** the `%@` placeholder — the fragment form
    /// `ReasoningOutputValidator` matches against a remote response to catch
    /// a model that hedged on its own (which would otherwise get
    /// double-hedged by `describe(subject:certainty:)`). Kept alongside
    /// `hedgeTemplate(for:locale:)` rather than duplicated, so the two can
    /// never drift — see docs/superpowers/specs/2026-08-11-awareness-ai-tiers-design.md
    /// "The output validator".
    public static func hedgeFragments(locale: Locale) -> [String] {
        Certainty.allCases.map { certainty in
            hedgeTemplate(for: certainty, locale: locale)
                .replacingOccurrences(of: " %@.", with: "")
                .replacingOccurrences(of: "%@.", with: "")
        }
    }

    /// What to say when depth sensing ran and produced no usable reading —
    /// distinct from `nothingRecognized(locale:)`, which is about
    /// perception finding nothing. `DepthStatistics` treats `nil` as "could
    /// not measure", never "the way is clear"; this string is the spoken
    /// form of that distinction, for `ObstacleAwarenessView`'s one-shot
    /// check.
    public func couldNotMeasure(locale: Locale = .current) -> String {
        LocalizedCatalog.string("Couldn't take a measurement. Try again.", locale: locale)
    }
```

`Certainty` needs `CaseIterable` for `Certainty.allCases` above — add it to
the existing declaration (currently `public enum Certainty: Sendable,
Equatable { case low, medium, high }`):

```swift
public enum Certainty: Sendable, Equatable, CaseIterable {
```

Add the new catalog entry to
`app/Packages/SenseBridgeCore/Sources/SenseBridgeCore/Resources/Localizable.xcstrings`,
matching the existing entry shape exactly (insert as a new key in the
`strings` object, alongside `"Nothing recognizable was found."`):

```json
    "Couldn't take a measurement. Try again.": {
      "localizations": {
        "en": {
          "stringUnit": {
            "state": "translated",
            "value": "Couldn't take a measurement. Try again."
          }
        },
        "es": {
          "stringUnit": {
            "state": "translated",
            "value": "No se pudo tomar una medición. Inténtalo de nuevo."
          }
        },
        "vi": {
          "stringUnit": {
            "state": "translated",
            "value": "Không thể đo được. Hãy thử lại."
          }
        }
      }
    },
```

- [ ] **Step 4: Run tests to verify pass**

```bash
cd app/Packages/SenseBridgeCore && swift test --filter PhrasingTests
```

Expected: PASS. Then also run the catalog-dependent check from
`app/Packages/SenseBridgeCore` (not `app/` — the umbrella Xcode project's
auto-generated `SenseBridgeCore` scheme has no shared Test action; this is
also the working directory `.github/workflows/ci.yml` uses):

```bash
cd app/Packages/SenseBridgeCore && xcodebuild test -scheme SenseBridgeCore -destination 'platform=macOS' -only-testing:SenseBridgeCoreTests/PhrasingTests 2>&1 | tail -30
```

Expected: PASS (proves the new `.xcstrings` entry actually resolves through
the compiled-bundle path, not just the raw-catalog fallback).

- [ ] **Step 5: Commit**

```bash
git add app/Packages/SenseBridgeCore/Sources/SenseBridgeCore/Reasoning/Phrasing.swift \
  app/Packages/SenseBridgeCore/Sources/SenseBridgeCore/Resources/Localizable.xcstrings \
  app/Packages/SenseBridgeCore/Tests/SenseBridgeCoreTests/PhrasingTests.swift
git commit -m "feat(phrasing): add hedge-fragment introspection and a distinct couldNotMeasure string"
```

---

### Task 4: `ReasoningOutputValidator` — the safety enforcement point

**Files:**

- Create: `app/Packages/SenseBridgeCore/Sources/SenseBridgeCore/Reasoning/ReasoningOutputValidator.swift`
- Test: `app/Packages/SenseBridgeCore/Tests/SenseBridgeCoreTests/ReasoningOutputValidatorTests.swift`

**Interfaces:**

- Consumes: `Phrasing.hedgeFragments(locale:)` (Task 3).
- Produces: `ReasoningOutputValidator.validate(_:locale:) throws -> String`,
  `ReasoningOutputValidationError` (enum) — called by every network composer
  (Tasks 5-6) before the result reaches `Phrasing.describe`.

- [ ] **Step 1: Write the failing tests — including the project's most important regression test**

```swift
// app/Packages/SenseBridgeCore/Tests/SenseBridgeCoreTests/ReasoningOutputValidatorTests.swift
import Testing
@testable import SenseBridgeCore
import Foundation

@Suite struct ReasoningOutputValidatorTests {
    let validator = ReasoningOutputValidator()
    let en = Locale(identifier: "en")

    /// The regression test for the worst bug this project can ship: a
    /// network model returning an unhedged, confident, distance-and-danger
    /// sentence must never reach `Phrasing.describe` unvalidated. See
    /// docs/superpowers/specs/2026-08-11-awareness-ai-tiers-design.md
    /// "The output validator".
    @Test func unhedgedDistanceAndDangerSentenceIsRejected() {
        #expect(throws: (any Error).self) {
            try validator.validate(
                "There is a car about 2 feet ahead — dangerous",
                locale: en
            )
        }
    }

    @Test func plainNounPhraseIsAccepted() throws {
        let result = try validator.validate("a chair and a doorway", locale: en)
        #expect(result == "a chair and a doorway")
    }

    @Test func sentencePunctuationIsRejected() {
        #expect(throws: (any Error).self) {
            try validator.validate("a chair.", locale: en)
        }
    }

    @Test func newlineIsRejected() {
        #expect(throws: (any Error).self) {
            try validator.validate("a chair\nand a doorway", locale: en)
        }
    }

    @Test func overTwelveWordsIsRejected() {
        let long = (1...13).map { "word\($0)" }.joined(separator: " ")
        #expect(throws: (any Error).self) {
            try validator.validate(long, locale: en)
        }
    }

    @Test func emptyAfterTrimmingIsRejected() {
        #expect(throws: (any Error).self) {
            try validator.validate("   ", locale: en)
        }
    }

    @Test func distanceAndDangerTokensAreRejectedInEnglish() {
        for phrase in ["a chair 2 meters away", "a dangerous doorway", "something on your left"] {
            #expect(throws: (any Error).self, "\(phrase) should be rejected") {
                try validator.validate(phrase, locale: en)
            }
        }
    }

    @Test func distanceAndDangerTokensAreRejectedInSpanish() {
        let es = Locale(identifier: "es")
        #expect(throws: (any Error).self) {
            try validator.validate("una silla peligrosa", locale: es)
        }
    }

    @Test func distanceAndDangerTokensAreRejectedInVietnamese() {
        let vi = Locale(identifier: "vi")
        #expect(throws: (any Error).self) {
            try validator.validate("một cái ghế nguy hiểm", locale: vi)
        }
    }

    @Test func hedgeFragmentDoubleWrapIsRejected() {
        #expect(throws: (any Error).self) {
            try validator.validate("it looks like there's a chair", locale: en)
        }
    }

    @Test func numeralsAreRejected() {
        #expect(throws: (any Error).self) {
            try validator.validate("2 chairs", locale: en)
        }
    }
}
```

- [ ] **Step 2: Run to verify failure**

```bash
cd app/Packages/SenseBridgeCore && swift test --filter ReasoningOutputValidatorTests
```

Expected: FAIL — `cannot find type 'ReasoningOutputValidator' in scope`

- [ ] **Step 3: Implement**

```swift
// app/Packages/SenseBridgeCore/Sources/SenseBridgeCore/Reasoning/ReasoningOutputValidator.swift
import Foundation
import NaturalLanguage

/// Why a network reasoning composer's raw response was rejected.
public enum ReasoningOutputValidationError: Error, Sendable, Equatable {
    case empty
    case tooLong(wordCount: Int)
    case containsSentencePunctuationOrNewline
    case containsDisallowedTerm
    case containsNumeral
    case containsHedgeFragment
    case wrongLanguage
}

/// The actual safety enforcement point for every network reasoning composer.
///
/// `FoundationModelsSceneComposer` is safe because `@Generable` constrains
/// its model's reply *structurally, at the decoding layer* — Apple's
/// runtime, not a request the app sent. Over HTTP there is no decoding layer
/// the app controls: `response_format`/tool-use are requests to a server the
/// app doesn't run, and for a self-hosted endpoint that server is arbitrary.
/// This type is what stands between an HTTP response and `Phrasing`, and it
/// is deterministic and local — never trust a remote's own claim to have
/// followed instructions. See
/// docs/superpowers/specs/2026-08-11-awareness-ai-tiers-design.md
/// "The output validator".
public struct ReasoningOutputValidator: Sendable {
    private static let maximumWords = 12

    /// Distance/direction/safety/danger tokens a bare noun phrase
    /// ("a chair and a doorway") should never legitimately contain — if the
    /// model volunteered one, it stopped compressing labels and started
    /// making a claim about the physical world, which only `Phrasing` is
    /// allowed to do. Lowercased comparison; keys are `AppLanguage` raw
    /// values so this stays in step with the app's supported languages.
    private static let disallowedTerms: [String: [String]] = [
        "en": [
            "danger", "dangerous", "safe", "safety", "meter", "meters", "metre", "metres",
            "feet", "foot", "inch", "inches", "left", "right", "ahead", "behind",
            "close", "near", "far", "step", "careful", "watch out", "collision", "hazard"
        ],
        "es": [
            "peligro", "peligroso", "peligrosa", "seguro", "segura", "seguridad",
            "metro", "metros", "pie", "pies", "izquierda", "derecha", "adelante",
            "detrás", "cerca", "lejos", "cuidado", "colisión"
        ],
        "vi": [
            "nguy hiểm", "an toàn", "mét", "trái", "phải", "phía trước", "phía sau",
            "gần", "xa", "cẩn thận", "va chạm"
        ]
    ]

    public init() {}

    /// Validates and trims `phrase`, throwing on the first rule it fails.
    /// The caller (a network `SceneComposer`) must treat any throw exactly
    /// like `FoundationModelsSceneComposer.modelPhrase(for:)` returning
    /// `nil`: fall back, never surface the raw text.
    public func validate(_ phrase: String, locale: Locale) throws -> String {
        let trimmed = phrase.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw ReasoningOutputValidationError.empty }
        guard trimmed.rangeOfCharacter(from: .newlines) == nil,
              !trimmed.contains(where: { ".!?".contains($0) })
        else {
            throw ReasoningOutputValidationError.containsSentencePunctuationOrNewline
        }
        let wordCount = trimmed.split(separator: " ").count
        guard wordCount <= Self.maximumWords else {
            throw ReasoningOutputValidationError.tooLong(wordCount: wordCount)
        }
        guard trimmed.rangeOfCharacter(from: .decimalDigits) == nil else {
            throw ReasoningOutputValidationError.containsNumeral
        }
        let lowered = trimmed.lowercased()
        let languageCode = locale.language.languageCode?.identifier ?? "en"
        for term in Self.disallowedTerms[languageCode] ?? Self.disallowedTerms["en"] ?? [] {
            if lowered.contains(term) {
                throw ReasoningOutputValidationError.containsDisallowedTerm
            }
        }
        for fragment in Phrasing.hedgeFragments(locale: locale) where !fragment.isEmpty {
            if lowered.contains(fragment.lowercased()) {
                throw ReasoningOutputValidationError.containsHedgeFragment
            }
        }
        try Self.checkLanguage(trimmed, locale: locale)
        return trimmed
    }

    /// Best-effort: rejects only when the recognizer is confident *and* the
    /// phrase is long enough to detect reliably. Short noun phrases
    /// ("a chair") are frequently ambiguous across languages and must not
    /// false-positive-reject a correct response.
    private static func checkLanguage(_ phrase: String, locale: Locale) throws {
        guard phrase.split(separator: " ").count >= 3 else { return }
        guard let expected = locale.language.languageCode?.identifier else { return }
        let recognizer = NLLanguageRecognizer()
        recognizer.processString(phrase)
        guard let dominant = recognizer.dominantLanguage else { return }
        let confidence = recognizer.languageHypotheses(withMaximum: 1)[dominant] ?? 0
        if confidence > 0.7, dominant.rawValue != expected {
            throw ReasoningOutputValidationError.wrongLanguage
        }
    }
}
```

- [ ] **Step 4: Run to verify pass**

```bash
cd app/Packages/SenseBridgeCore && swift test --filter ReasoningOutputValidatorTests
```

Expected: PASS, all 11 cases — especially
`unhedgedDistanceAndDangerSentenceIsRejected`.

- [ ] **Step 5: Commit**

```bash
git add app/Packages/SenseBridgeCore/Sources/SenseBridgeCore/Reasoning/ReasoningOutputValidator.swift \
  app/Packages/SenseBridgeCore/Tests/SenseBridgeCoreTests/ReasoningOutputValidatorTests.swift
git commit -m "feat(reasoning): add ReasoningOutputValidator, the safety enforcement point for network composers"
```

---

### Task 5: `EndpointURLNormalizer` — URL validation at the trust boundary

**Files:**

- Create: `app/Packages/SenseBridgeCore/Sources/SenseBridgeCore/Reasoning/EndpointURLNormalizer.swift`
- Test: `app/Packages/SenseBridgeCore/Tests/SenseBridgeCoreTests/EndpointURLNormalizerTests.swift`

**Interfaces:**

- Produces: `EndpointURLNormalizer.normalize(_:) throws -> URL`,
  `EndpointURLError` — used by `OpenAICompatibleSceneComposer` (Task 6) and
  `ReasoningBackendSettingsView` (Task 15) before a self-hosted URL is ever
  saved or requested against.

- [ ] **Step 1: Write the failing tests**

```swift
// app/Packages/SenseBridgeCore/Tests/SenseBridgeCoreTests/EndpointURLNormalizerTests.swift
import Testing
@testable import SenseBridgeCore
import Foundation

@Suite struct EndpointURLNormalizerTests {
    @Test func bareHostGetsTheChatCompletionsPathAppended() throws {
        let url = try EndpointURLNormalizer.normalize("http://192.168.1.20:11434")
        #expect(url.absoluteString == "http://192.168.1.20:11434/v1/chat/completions")
    }

    @Test func fullPathIsLeftAlone() throws {
        let url = try EndpointURLNormalizer.normalize("http://192.168.1.20:11434/v1/chat/completions")
        #expect(url.absoluteString == "http://192.168.1.20:11434/v1/chat/completions")
    }

    @Test func httpsSchemeIsAccepted() throws {
        let url = try EndpointURLNormalizer.normalize("https://my-server.example.com")
        #expect(url.scheme == "https")
    }

    @Test func nonHttpSchemeIsRejected() {
        #expect(throws: EndpointURLError.invalidScheme) {
            try EndpointURLNormalizer.normalize("ftp://192.168.1.20")
        }
    }

    @Test func embeddedCredentialsAreRejected() {
        #expect(throws: EndpointURLError.embeddedCredentials) {
            try EndpointURLNormalizer.normalize("http://user:pass@192.168.1.20:11434")
        }
    }

    @Test func malformedStringIsRejected() {
        #expect(throws: EndpointURLError.invalidURL) {
            try EndpointURLNormalizer.normalize("not a url at all")
        }
    }

    @Test func trailingSlashHostGetsPathAppendedCleanly() throws {
        let url = try EndpointURLNormalizer.normalize("http://localhost:11434/")
        #expect(url.absoluteString == "http://localhost:11434/v1/chat/completions")
    }
}
```

- [ ] **Step 2: Run to verify failure**

```bash
cd app/Packages/SenseBridgeCore && swift test --filter EndpointURLNormalizerTests
```

Expected: FAIL — `cannot find 'EndpointURLNormalizer' in scope`

- [ ] **Step 3: Implement**

```swift
// app/Packages/SenseBridgeCore/Sources/SenseBridgeCore/Reasoning/EndpointURLNormalizer.swift
import Foundation

/// Why a user-supplied self-hosted endpoint URL was rejected.
public enum EndpointURLError: Error, Sendable, Equatable {
    case invalidURL
    case invalidScheme
    case embeddedCredentials
}

/// Validates and normalizes a self-hosted endpoint URL at the trust
/// boundary, before it is ever saved to `Settings.localEndpointURL` or used
/// in a request. See
/// docs/superpowers/specs/2026-08-11-awareness-ai-tiers-design.md
/// "Self-hosted endpoint — network-layer specifics".
public enum EndpointURLNormalizer {
    /// The OpenAI-compatible chat-completions route every supported
    /// self-hosted server (Ollama, LM Studio, vLLM) and NVIDIA NIM expose.
    private static let chatCompletionsPath = "/v1/chat/completions"

    /// Normalizes `raw` into a request-ready `URL`.
    ///
    /// Accepts either a bare host (`http://192.168.1.20:11434`) or an
    /// already-complete path — a user pasting either form must work. Rejects
    /// any scheme other than `http`/`https` and any URL carrying embedded
    /// `user`/`password` components: `Settings.localEndpointURL` is plain
    /// `UserDefaults`, not Keychain, so credentials must never be accepted
    /// into that field even if a user pastes them there.
    public static func normalize(_ raw: String) throws -> URL {
        guard let components = URLComponents(string: raw), let scheme = components.scheme?.lowercased()
        else {
            throw EndpointURLError.invalidURL
        }
        guard scheme == "http" || scheme == "https" else {
            throw EndpointURLError.invalidScheme
        }
        guard components.user == nil, components.password == nil else {
            throw EndpointURLError.embeddedCredentials
        }
        var normalized = components
        if normalized.path.isEmpty || normalized.path == "/" {
            normalized.path = chatCompletionsPath
        } else if !normalized.path.hasSuffix(chatCompletionsPath) {
            let base = normalized.path.hasSuffix("/") ? String(normalized.path.dropLast()) : normalized.path
            normalized.path = base + chatCompletionsPath
        }
        guard let url = normalized.url else { throw EndpointURLError.invalidURL }
        return url
    }
}
```

- [ ] **Step 4: Run to verify pass**

```bash
cd app/Packages/SenseBridgeCore && swift test --filter EndpointURLNormalizerTests
```

Expected: PASS, 7 cases.

- [ ] **Step 5: Commit**

```bash
git add app/Packages/SenseBridgeCore/Sources/SenseBridgeCore/Reasoning/EndpointURLNormalizer.swift \
  app/Packages/SenseBridgeCore/Tests/SenseBridgeCoreTests/EndpointURLNormalizerTests.swift
git commit -m "feat(reasoning): add EndpointURLNormalizer for self-hosted endpoint validation"
```

---

### Task 6: `APICredentialStore` protocol + `CredentialKey`

**Files:**

- Create: `app/Packages/SenseBridgeCore/Sources/SenseBridgeCore/Storage/APICredentialStore.swift`

**Interfaces:**

- Produces: `CredentialKey` (`.anthropic`, `.openai`, `.nvidiaNIM`,
  `.localEndpoint`), `APICredentialStore` protocol (`credential(for:) ->
  String?`, `save(_:for:)`, `removeCredential(for:)`) — implemented by
  `InMemoryCredentialStore` (test-only, Task 7/8/9) and `KeychainCredentialStore`
  (Task 11, App layer).

No test file for this task — it's a protocol plus a plain enum, and its only
behavior is exercised through the implementations built in later tasks. This
mirrors `SettingsStore`, which also ships with no test of its own (see
`app/Packages/SenseBridgeCore/Sources/SenseBridgeCore/Storage/Settings.swift:124-127`).

- [ ] **Step 1: Implement**

```swift
// app/Packages/SenseBridgeCore/Sources/SenseBridgeCore/Storage/APICredentialStore.swift
import Foundation

/// Which credential slot a stored secret belongs to. Mirrors `CloudProvider`
/// plus one slot for the self-hosted endpoint's optional bearer token.
public enum CredentialKey: String, Sendable, Equatable, CaseIterable {
    case anthropic, openai, nvidiaNIM, localEndpoint
}

/// Where BYOK API keys and the self-hosted endpoint's optional token live.
/// **Never** `Settings`/`UserDefaults` — see the plan's global constraints.
/// The real implementation (`KeychainCredentialStore`, App layer) uses the
/// Keychain; this protocol exists so `ReasoningComposerResolver` and its
/// tests never depend on `Security` directly, matching the
/// `SettingsStore`/`UserDefaultsSettingsStore` split.
public protocol APICredentialStore: Sendable {
    /// Looks the credential up fresh on every call — callers must not cache
    /// it, per the plan's "load the key just-in-time per request" rule.
    func credential(for key: CredentialKey) -> String?
    /// Saves or replaces the credential for `key`. Implementations must
    /// update an existing entry rather than silently failing on a duplicate
    /// — see `KeychainCredentialStore`.
    func save(_ value: String, for key: CredentialKey)
    /// Removes the credential for `key`. Switching `Settings.reasoningBackend`
    /// away from `.cloud` must **not** call this automatically — retention
    /// is the user's explicit choice, made from the Settings UI (Task 15).
    func removeCredential(for key: CredentialKey)
}
```

- [ ] **Step 2: Commit**

```bash
git add app/Packages/SenseBridgeCore/Sources/SenseBridgeCore/Storage/APICredentialStore.swift
git commit -m "feat(storage): add APICredentialStore protocol for BYOK credentials"
```

---

### Task 7: `AnthropicSceneComposer`

**Files:**

- Create: `app/Packages/SenseBridgeCore/Sources/SenseBridgeCore/Reasoning/AnthropicSceneComposer.swift`
- Test: `app/Packages/SenseBridgeCore/Tests/SenseBridgeCoreTests/AnthropicSceneComposerTests.swift`

**Interfaces:**

- Consumes: `SceneComposer` protocol, `ReasoningOutputValidator` (Task 4),
  `[PerceptionRecord].detectedObjectLabelsForNetwork()`/
  `.weakestDetectedObjectConfidence()` (Task 2), `Phrasing`.
- Produces: `AnthropicSceneComposer: SceneComposer`,
  `AnthropicSceneComposer.ComposerError` — consumed by
  `ReasoningComposerResolver` (Task 9).

- [ ] **Step 1: Write the failing tests**

```swift
// app/Packages/SenseBridgeCore/Tests/SenseBridgeCoreTests/AnthropicSceneComposerTests.swift
import Testing
@testable import SenseBridgeCore
import Foundation

/// Intercepts every request instead of hitting the network — registered
/// per-test via a dedicated `URLSessionConfiguration`, never
/// `URLProtocol.registerClass` globally, so tests stay isolated from each
/// other.
final class StubURLProtocol: URLProtocol, @unchecked Sendable {
    nonisolated(unsafe) static var handler: (@Sendable (URLRequest) -> (Int, Data, String))?

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        guard let handler = Self.handler else {
            client?.urlProtocol(self, didFailWithError: URLError(.badServerResponse))
            return
        }
        let (status, data, contentType) = handler(request)
        let response = HTTPURLResponse(
            url: request.url!, statusCode: status,
            httpVersion: "HTTP/1.1", headerFields: ["Content-Type": contentType]
        )!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: data)
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}

    static func makeSession() -> URLSession {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [StubURLProtocol.self]
        return URLSession(configuration: configuration)
    }
}

@Suite struct AnthropicSceneComposerTests {
    let records: [PerceptionRecord] = [
        PerceptionRecord(kind: .detectedObject(label: "chair", confidence: 0.6), capturedAt: .now)
    ]

    @Test func successfulResponseIsHedgedAndReturned() async throws {
        StubURLProtocol.handler = { _ in
            let body = #"{"content":[{"type":"text","text":"a chair"}]}"#.data(using: .utf8)!
            return (200, body, "application/json")
        }
        let composer = AnthropicSceneComposer(
            apiKey: "sk-ant-test", session: StubURLProtocol.makeSession()
        )
        let result = try await composer.compose(from: records)
        #expect(result.contains("a chair"))
        #expect(result != "a chair") // must be hedged, not the bare phrase
    }

    @Test func malformedJSONThrows() async {
        StubURLProtocol.handler = { _ in (200, Data("not json".utf8), "application/json") }
        let composer = AnthropicSceneComposer(apiKey: "sk-ant-test", session: StubURLProtocol.makeSession())
        await #expect(throws: (any Error).self) {
            try await composer.compose(from: records)
        }
    }

    @Test func httpErrorThrows() async {
        StubURLProtocol.handler = { _ in (401, Data(), "application/json") }
        let composer = AnthropicSceneComposer(apiKey: "sk-ant-test", session: StubURLProtocol.makeSession())
        await #expect(throws: (any Error).self) {
            try await composer.compose(from: records)
        }
    }

    /// The regression test that matters most for this type: even if the
    /// remote ignores every instruction and returns a full unhedged
    /// sentence, `compose` must throw — the validator, not the prompt, is
    /// what stands between this response and `Phrasing`.
    @Test func unhedgedDangerousSentenceIsRejectedNotSpoken() async {
        StubURLProtocol.handler = { _ in
            let body = #"{"content":[{"type":"text","text":"There is a car about 2 feet ahead — dangerous"}]}"#
                .data(using: .utf8)!
            return (200, body, "application/json")
        }
        let composer = AnthropicSceneComposer(apiKey: "sk-ant-test", session: StubURLProtocol.makeSession())
        await #expect(throws: (any Error).self) {
            try await composer.compose(from: records)
        }
    }

    @Test func emptyRecordsReturnsNothingRecognizedWithoutMakingARequest() async throws {
        StubURLProtocol.handler = { _ in
            Issue.record("should not make a request for empty records")
            return (200, Data(), "application/json")
        }
        let composer = AnthropicSceneComposer(apiKey: "sk-ant-test", session: StubURLProtocol.makeSession())
        let result = try await composer.compose(from: [])
        #expect(!result.isEmpty)
    }
}
```

- [ ] **Step 2: Run to verify failure**

```bash
cd app/Packages/SenseBridgeCore && swift test --filter AnthropicSceneComposerTests
```

Expected: FAIL — `cannot find 'AnthropicSceneComposer' in scope`

- [ ] **Step 3: Implement**

```swift
// app/Packages/SenseBridgeCore/Sources/SenseBridgeCore/Reasoning/AnthropicSceneComposer.swift
import Foundation

/// Composes a scene description via Anthropic's Messages API (BYOK). Safety
/// comes from `ReasoningOutputValidator`, not from the request — see that
/// type's doc comment and
/// docs/superpowers/specs/2026-08-11-awareness-ai-tiers-design.md "The output
/// validator".
public struct AnthropicSceneComposer: SceneComposer {
    public enum ComposerError: Error, Sendable, Equatable {
        case httpError(status: Int)
        case malformedResponse
    }

    private struct Request: Encodable {
        let model: String
        let maxTokens: Int
        let system: String
        let messages: [Message]
        struct Message: Encodable { let role: String; let content: String }
    }

    private struct Response: Decodable {
        let content: [ContentBlock]
        struct ContentBlock: Decodable { let type: String; let text: String? }
    }

    private static let endpoint = URL(string: "https://api.anthropic.com/v1/messages")!
    private static let apiVersion = "2023-06-01"
    private static let defaultModel = "claude-haiku-4-5-20251001"

    private let apiKey: String
    private let model: String
    private let session: URLSession
    private let validator: ReasoningOutputValidator
    private let phrasing: Phrasing
    private let locale: Locale

    public init(
        apiKey: String,
        model: String? = nil,
        session: URLSession,
        validator: ReasoningOutputValidator = .init(),
        phrasing: Phrasing = .init(),
        locale: Locale = .current
    ) {
        self.apiKey = apiKey
        self.model = model ?? Self.defaultModel
        self.session = session
        self.validator = validator
        self.phrasing = phrasing
        self.locale = locale
    }

    public func compose(from records: [PerceptionRecord]) async throws -> String {
        let labels = records.detectedObjectLabelsForNetwork()
        guard !labels.isEmpty else { return phrasing.nothingRecognized(locale: locale) }

        var request = URLRequest(url: Self.endpoint)
        request.httpMethod = "POST"
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue(Self.apiVersion, forHTTPHeaderField: "anthropic-version")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let body = Request(
            model: model,
            maxTokens: 40,
            system: Self.instructions(locale: locale),
            messages: [.init(role: "user", content: "Labels: \(labels.joined(separator: ", "))")]
        )
        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        request.httpBody = try encoder.encode(body)

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw ComposerError.httpError(status: (response as? HTTPURLResponse)?.statusCode ?? -1)
        }
        guard let decoded = try? JSONDecoder().decode(Response.self, from: data),
              let text = decoded.content.first(where: { $0.type == "text" })?.text
        else {
            throw ComposerError.malformedResponse
        }
        let validated = try validator.validate(text, locale: locale)
        let weakest = records.weakestDetectedObjectConfidence() ?? 0
        return phrasing.describe(
            subject: validated, certainty: Phrasing.certainty(forConfidence: weakest), locale: locale
        )
    }

    /// Near-identical to `FoundationModelsSceneComposer.instructions` on
    /// purpose — same constraint, same reason: compression only, never a
    /// claim about distance, direction, danger, or safety. Also pins the
    /// response language, closing the same latent gap
    /// `FoundationModelsSceneComposer` had (see Task 13).
    private static func instructions(locale: Locale) -> String {
        """
        You compress a list of detected object labels into one short noun phrase \
        for a blind user's screen reader. Name only objects present in the list. \
        Never add objects, never guess what the place is, never describe distance, \
        direction, movement, or safety, and never write a full sentence. Respond \
        only with the noun phrase, in the language identified by locale \
        "\(locale.identifier)". Another part of the app adds the wording around \
        your phrase.
        """
    }
}
```

- [ ] **Step 4: Run to verify pass**

```bash
cd app/Packages/SenseBridgeCore && swift test --filter AnthropicSceneComposerTests
```

Expected: PASS, 5 cases — especially
`unhedgedDangerousSentenceIsRejectedNotSpoken`.

- [ ] **Step 5: Commit**

```bash
git add app/Packages/SenseBridgeCore/Sources/SenseBridgeCore/Reasoning/AnthropicSceneComposer.swift \
  app/Packages/SenseBridgeCore/Tests/SenseBridgeCoreTests/AnthropicSceneComposerTests.swift
git commit -m "feat(reasoning): add AnthropicSceneComposer, validated through ReasoningOutputValidator"
```

---

### Task 8: `OpenAICompatibleSceneComposer` — covers OpenAI, NVIDIA NIM, and self-hosted

**Files:**

- Create: `app/Packages/SenseBridgeCore/Sources/SenseBridgeCore/Reasoning/OpenAICompatibleSceneComposer.swift`
- Test: `app/Packages/SenseBridgeCore/Tests/SenseBridgeCoreTests/OpenAICompatibleSceneComposerTests.swift`

**Interfaces:**

- Consumes: `SceneComposer`, `ReasoningOutputValidator`, `EndpointURLNormalizer`
  (Task 5), `[PerceptionRecord]` helpers, `Phrasing`, `StubURLProtocol` (reuse
  from Task 7's test file — same target, no import needed).
- Produces: `OpenAICompatibleSceneComposer: SceneComposer` — consumed by
  `ReasoningComposerResolver` (Task 9) for all three network-backend cases
  except Anthropic.

- [ ] **Step 1: Write the failing tests**

```swift
// app/Packages/SenseBridgeCore/Tests/SenseBridgeCoreTests/OpenAICompatibleSceneComposerTests.swift
import Testing
@testable import SenseBridgeCore
import Foundation

@Suite struct OpenAICompatibleSceneComposerTests {
    let records: [PerceptionRecord] = [
        PerceptionRecord(kind: .detectedObject(label: "doorway", confidence: 0.7), capturedAt: .now)
    ]

    @Test func successfulResponseIsHedgedAndReturned() async throws {
        StubURLProtocol.handler = { _ in
            let body = #"{"choices":[{"message":{"content":"a doorway"}}]}"#.data(using: .utf8)!
            return (200, body, "application/json")
        }
        let composer = try OpenAICompatibleSceneComposer(
            endpointURL: "https://api.openai.com/v1/chat/completions",
            apiKey: "sk-test", model: "gpt-4o-mini",
            session: StubURLProtocol.makeSession()
        )
        let result = try await composer.compose(from: records)
        #expect(result.contains("a doorway"))
    }

    @Test func selfHostedEndpointWithNoKeyWorks() async throws {
        StubURLProtocol.handler = { request in
            #expect(request.value(forHTTPHeaderField: "Authorization") == nil)
            let body = #"{"choices":[{"message":{"content":"a doorway"}}]}"#.data(using: .utf8)!
            return (200, body, "application/json")
        }
        let composer = try OpenAICompatibleSceneComposer(
            endpointURL: "http://192.168.1.20:11434", apiKey: nil, model: "llama3.2",
            session: StubURLProtocol.makeSession()
        )
        let result = try await composer.compose(from: records)
        #expect(!result.isEmpty)
    }

    @Test func rejectsEmbeddedCredentialsAtConstruction() {
        #expect(throws: EndpointURLError.embeddedCredentials) {
            _ = try OpenAICompatibleSceneComposer(
                endpointURL: "http://user:pass@192.168.1.20:11434", apiKey: nil, model: "llama3.2",
                session: StubURLProtocol.makeSession()
            )
        }
    }

    @Test func malformedJSONThrows() async throws {
        StubURLProtocol.handler = { _ in (200, Data("<html>wrong host</html>".utf8), "text/html") }
        let composer = try OpenAICompatibleSceneComposer(
            endpointURL: "http://192.168.1.20:11434", apiKey: nil, model: "llama3.2",
            session: StubURLProtocol.makeSession()
        )
        await #expect(throws: (any Error).self) {
            try await composer.compose(from: records)
        }
    }

    @Test func unhedgedDangerousSentenceIsRejectedNotSpoken() async {
        StubURLProtocol.handler = { _ in
            let body = #"{"choices":[{"message":{"content":"There is a car about 2 feet ahead — dangerous"}}]}"#
                .data(using: .utf8)!
            return (200, body, "application/json")
        }
        let composer = try! OpenAICompatibleSceneComposer(
            endpointURL: "https://integrate.api.nvidia.com/v1/chat/completions",
            apiKey: "nvapi-test", model: "meta/llama-3.1-8b-instruct",
            session: StubURLProtocol.makeSession()
        )
        await #expect(throws: (any Error).self) {
            try await composer.compose(from: records)
        }
    }

    @Test func oversizedOrNonJSONResponseIsRejected() async throws {
        StubURLProtocol.handler = { _ in
            (200, Data(repeating: 0x41, count: 2_000_000), "text/html")
        }
        let composer = try OpenAICompatibleSceneComposer(
            endpointURL: "http://192.168.1.20:11434", apiKey: nil, model: "llama3.2",
            session: StubURLProtocol.makeSession()
        )
        await #expect(throws: (any Error).self) {
            try await composer.compose(from: records)
        }
    }
}
```

- [ ] **Step 2: Run to verify failure**

```bash
cd app/Packages/SenseBridgeCore && swift test --filter OpenAICompatibleSceneComposerTests
```

Expected: FAIL — `cannot find 'OpenAICompatibleSceneComposer' in scope`

- [ ] **Step 3: Implement**

```swift
// app/Packages/SenseBridgeCore/Sources/SenseBridgeCore/Reasoning/OpenAICompatibleSceneComposer.swift
import Foundation

/// Composes a scene description against any OpenAI-compatible
/// `/v1/chat/completions` endpoint. One implementation serves OpenAI cloud,
/// NVIDIA NIM (hosted or self-hosted), and a user's self-hosted server
/// (Ollama, LM Studio, vLLM) — base URL, key, and model are the whole delta.
/// The key is optional: a self-hosted NIM container commonly needs none.
/// Safety comes from `ReasoningOutputValidator`, never from
/// `response_format` — see that type's doc comment.
public struct OpenAICompatibleSceneComposer: SceneComposer {
    public enum ComposerError: Error, Sendable, Equatable {
        case httpError(status: Int)
        case malformedResponse
        case responseTooLarge
    }

    private struct Request: Encodable {
        let model: String
        let messages: [Message]
        let maxTokens: Int
        struct Message: Encodable { let role: String; let content: String }
    }

    private struct Response: Decodable {
        let choices: [Choice]
        struct Choice: Decodable { let message: Message }
        struct Message: Decodable { let content: String }
    }

    /// A misconfigured host returning an HTML error page must fail fast
    /// rather than be parsed as JSON. This is a post-hoc size check on the
    /// fully-downloaded response, not a streaming abort.
    /// # ponytail: not streaming-capped — add true mid-download truncation
    /// only if a misbehaving self-hosted endpoint's bandwidth use becomes a
    /// real problem; the safety-critical path is the validator, not this.
    private static let maximumResponseBytes = 1_048_576

    private let endpoint: URL
    private let apiKey: String?
    private let model: String
    private let session: URLSession
    private let validator: ReasoningOutputValidator
    private let phrasing: Phrasing
    private let locale: Locale

    /// Throws at construction, not at request time, if `endpointURL` fails
    /// `EndpointURLNormalizer` — a bad or credential-embedding URL must never
    /// reach a network call.
    public init(
        endpointURL: String,
        apiKey: String?,
        model: String,
        session: URLSession,
        validator: ReasoningOutputValidator = .init(),
        phrasing: Phrasing = .init(),
        locale: Locale = .current
    ) throws {
        endpoint = try EndpointURLNormalizer.normalize(endpointURL)
        self.apiKey = apiKey
        self.model = model
        self.session = session
        self.validator = validator
        self.phrasing = phrasing
        self.locale = locale
    }

    public func compose(from records: [PerceptionRecord]) async throws -> String {
        let labels = records.detectedObjectLabelsForNetwork()
        guard !labels.isEmpty else { return phrasing.nothingRecognized(locale: locale) }

        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        if let apiKey {
            request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        }
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let body = Request(
            model: model,
            messages: [
                .init(role: "system", content: Self.instructions(locale: locale)),
                .init(role: "user", content: "Labels: \(labels.joined(separator: ", "))")
            ],
            maxTokens: 40
        )
        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        request.httpBody = try encoder.encode(body)

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw ComposerError.httpError(status: (response as? HTTPURLResponse)?.statusCode ?? -1)
        }
        guard data.count <= Self.maximumResponseBytes else { throw ComposerError.responseTooLarge }
        guard http.mimeType?.contains("json") == true,
              let decoded = try? JSONDecoder().decode(Response.self, from: data),
              let text = decoded.choices.first?.message.content
        else {
            throw ComposerError.malformedResponse
        }
        let validated = try validator.validate(text, locale: locale)
        let weakest = records.weakestDetectedObjectConfidence() ?? 0
        return phrasing.describe(
            subject: validated, certainty: Phrasing.certainty(forConfidence: weakest), locale: locale
        )
    }

    /// Same constraint as `AnthropicSceneComposer.instructions` — see its
    /// doc comment. `response_format: json_schema` is deliberately not sent
    /// here: providers and self-hosted servers vary on whether they honor
    /// forced structured output, and with the validator as the real
    /// enforcement point, a provider ignoring this prompt degrades to
    /// "rejected and falls back," not "speaks an unhedged claim."
    private static func instructions(locale: Locale) -> String {
        """
        You compress a list of detected object labels into one short noun phrase \
        for a blind user's screen reader. Name only objects present in the list. \
        Never add objects, never guess what the place is, never describe distance, \
        direction, movement, or safety, and never write a full sentence. Respond \
        only with the noun phrase, in the language identified by locale \
        "\(locale.identifier)".
        """
    }
}
```

- [ ] **Step 4: Run to verify pass**

```bash
cd app/Packages/SenseBridgeCore && swift test --filter OpenAICompatibleSceneComposerTests
```

Expected: PASS, 6 cases.

- [ ] **Step 5: Commit**

```bash
git add app/Packages/SenseBridgeCore/Sources/SenseBridgeCore/Reasoning/OpenAICompatibleSceneComposer.swift \
  app/Packages/SenseBridgeCore/Tests/SenseBridgeCoreTests/OpenAICompatibleSceneComposerTests.swift
git commit -m "feat(reasoning): add OpenAICompatibleSceneComposer for OpenAI, NVIDIA NIM, and self-hosted endpoints"
```

---

### Task 9: `ReasoningComposerResolver` — backend selection, circuit breaker, fallback

**Files:**

- Create: `app/Packages/SenseBridgeCore/Sources/SenseBridgeCore/Reasoning/ReasoningComposerResolver.swift`
- Test: `app/Packages/SenseBridgeCore/Tests/SenseBridgeCoreTests/ReasoningComposerResolverTests.swift`

**Interfaces:**

- Consumes: `SceneComposer`, `ReasoningBackend`, `CloudProvider`, `Settings`,
  `APICredentialStore` (Task 6), `StubURLProtocol` (Task 7's test file, same
  target — reused here for `LiveNetworkComposerFactoryTests`, no import
  needed).
- Produces: `ReasoningComposeResult` (`text: String`, `backendUsed:
  ReasoningBackend`, `announcement: String?`),
  `NetworkComposerFactory` protocol (now with `modelOverride: String?` as a
  call-time parameter, not baked into the factory at construction — see the
  protocol's doc comment), `LiveNetworkComposerFactory`,
  `ReasoningComposerResolver` (`@MainActor final class`, `compose(from:
  settings:locale:requestTimeout:) async -> ReasoningComposeResult?`,
  `resetSession()`) — consumed by `AmbientAwarenessSession` (Task 10) and
  `SceneDescriptionView` (Task 12).

- [ ] **Step 1: Write the failing tests**

```swift
// app/Packages/SenseBridgeCore/Tests/SenseBridgeCoreTests/ReasoningComposerResolverTests.swift
import Testing
@testable import SenseBridgeCore
import Foundation

/// Never throws, never uses the network — stands in for
/// `FoundationModelsSceneComposer` in resolver tests.
private struct StubOnDeviceComposer: SceneComposer {
    func compose(from records: [PerceptionRecord]) async throws -> String { "on-device: stub" }
}

private struct FailingComposer: SceneComposer {
    func compose(from records: [PerceptionRecord]) async throws -> String {
        struct Failure: Error {}
        throw Failure()
    }
}

private struct SucceedingComposer: SceneComposer {
    func compose(from records: [PerceptionRecord]) async throws -> String { "network: ok" }
}

private final class StubFactory: NetworkComposerFactory, @unchecked Sendable {
    var next: SceneComposer?
    func composer(
        backend: ReasoningBackend, provider: CloudProvider?, endpointURL: String?,
        modelOverride: String?, credential: String?
    ) -> SceneComposer? { next }
}

private final class StubCredentialStore: APICredentialStore, @unchecked Sendable {
    var stored: [CredentialKey: String] = [:]
    func credential(for key: CredentialKey) -> String? { stored[key] }
    func save(_ value: String, for key: CredentialKey) { stored[key] = value }
    func removeCredential(for key: CredentialKey) { stored[key] = nil }
}

@MainActor
@Suite struct ReasoningComposerResolverTests {
    func makeResolver(factory: StubFactory, store: StubCredentialStore = .init()) -> ReasoningComposerResolver {
        ReasoningComposerResolver(onDeviceComposer: StubOnDeviceComposer(), credentialStore: store, factory: factory)
    }

    @Test func onDeviceBackendNeverConsultsTheFactory() async {
        let factory = StubFactory()
        let resolver = makeResolver(factory: factory)
        var settings = Settings()
        settings.reasoningBackend = .onDevice
        let result = await resolver.compose(from: [], settings: settings, locale: .current, requestTimeout: 4)
        #expect(result?.backendUsed == .onDevice)
        #expect(result?.announcement == nil)
    }

    @Test func cloudWithNoProviderConfiguredFallsBackSilently() async {
        let factory = StubFactory()
        let resolver = makeResolver(factory: factory)
        var settings = Settings()
        settings.reasoningBackend = .cloud
        settings.cloudProvider = nil
        let result = await resolver.compose(from: [], settings: settings, locale: .current, requestTimeout: 4)
        #expect(result?.backendUsed == .onDevice)
        #expect(result?.announcement == nil)
    }

    @Test func workingNetworkComposerIsUsedDirectly() async {
        let factory = StubFactory()
        factory.next = SucceedingComposer()
        let store = StubCredentialStore()
        store.save("sk-test", for: .anthropic)
        let resolver = makeResolver(factory: factory, store: store)
        var settings = Settings()
        settings.reasoningBackend = .cloud
        settings.cloudProvider = .anthropic
        let result = await resolver.compose(from: [], settings: settings, locale: .current, requestTimeout: 4)
        #expect(result?.backendUsed == .cloud)
        #expect(result?.text == "network: ok")
        #expect(result?.announcement == nil)
    }

    @Test func singleFailureFallsBackWithoutAnnouncing() async {
        let factory = StubFactory()
        factory.next = FailingComposer()
        let store = StubCredentialStore()
        store.save("sk-test", for: .anthropic)
        let resolver = makeResolver(factory: factory, store: store)
        var settings = Settings()
        settings.reasoningBackend = .cloud
        settings.cloudProvider = .anthropic
        let result = await resolver.compose(from: [], settings: settings, locale: .current, requestTimeout: 4)
        #expect(result?.backendUsed == .onDevice)
        #expect(result?.announcement == nil, "one failure must not announce yet")
    }

    @Test func secondConsecutiveFailureTripsTheBreakerAndAnnouncesOnce() async {
        let factory = StubFactory()
        factory.next = FailingComposer()
        let store = StubCredentialStore()
        store.save("sk-test", for: .anthropic)
        let resolver = makeResolver(factory: factory, store: store)
        var settings = Settings()
        settings.reasoningBackend = .cloud
        settings.cloudProvider = .anthropic
        _ = await resolver.compose(from: [], settings: settings, locale: .current, requestTimeout: 4)
        let second = await resolver.compose(from: [], settings: settings, locale: .current, requestTimeout: 4)
        #expect(second?.announcement != nil, "the second consecutive failure must announce once")
        let third = await resolver.compose(from: [], settings: settings, locale: .current, requestTimeout: 4)
        #expect(third?.announcement == nil, "must not repeat the announcement every tick")
    }

    @Test func recoveryAfterBreakerTripAnnouncesOnce() async {
        let factory = StubFactory()
        factory.next = FailingComposer()
        let store = StubCredentialStore()
        store.save("sk-test", for: .anthropic)
        let resolver = makeResolver(factory: factory, store: store)
        var settings = Settings()
        settings.reasoningBackend = .cloud
        settings.cloudProvider = .anthropic
        _ = await resolver.compose(from: [], settings: settings, locale: .current, requestTimeout: 4) // 1st failure
        _ = await resolver.compose(from: [], settings: settings, locale: .current, requestTimeout: 4) // trips breaker
        // Breaker probes again every 5th tick; drive it there, then recover.
        for _ in 0..<3 {
            _ = await resolver.compose(from: [], settings: settings, locale: .current, requestTimeout: 4)
        }
        factory.next = SucceedingComposer()
        let recovered = await resolver.compose(from: [], settings: settings, locale: .current, requestTimeout: 4)
        #expect(recovered?.backendUsed == .cloud)
        #expect(recovered?.announcement != nil, "recovery must be announced once")
    }

    @Test func resetSessionClearsBreakerState() async {
        let factory = StubFactory()
        factory.next = FailingComposer()
        let store = StubCredentialStore()
        store.save("sk-test", for: .anthropic)
        let resolver = makeResolver(factory: factory, store: store)
        var settings = Settings()
        settings.reasoningBackend = .cloud
        settings.cloudProvider = .anthropic
        _ = await resolver.compose(from: [], settings: settings, locale: .current, requestTimeout: 4)
        _ = await resolver.compose(from: [], settings: settings, locale: .current, requestTimeout: 4) // breaker tripped
        resolver.resetSession()
        factory.next = SucceedingComposer()
        let afterReset = await resolver.compose(from: [], settings: settings, locale: .current, requestTimeout: 4)
        #expect(afterReset?.announcement == nil, "a fresh session must not carry over the previous session's breaker trip/recovery state")
    }
}

/// `ReasoningComposerResolverTests` above tests the resolver against a
/// `StubFactory` and never exercises `LiveNetworkComposerFactory`'s own
/// per-backend routing — these tests close that gap directly.
@Suite struct LiveNetworkComposerFactoryTests {
    let factory = LiveNetworkComposerFactory(session: StubURLProtocol.makeSession(), requestTimeout: 4, locale: .current)

    @Test func onDeviceAlwaysReturnsNil() {
        let result = factory.composer(backend: .onDevice, provider: nil, endpointURL: nil, modelOverride: nil, credential: nil)
        #expect(result == nil)
    }

    @Test func cloudAnthropicWithNoCredentialReturnsNil() {
        let result = factory.composer(backend: .cloud, provider: .anthropic, endpointURL: nil, modelOverride: nil, credential: nil)
        #expect(result == nil)
    }

    @Test func cloudAnthropicWithCredentialReturnsAComposer() {
        let result = factory.composer(backend: .cloud, provider: .anthropic, endpointURL: nil, modelOverride: nil, credential: "sk-ant-test")
        #expect(result != nil)
    }

    @Test func cloudOpenAIWithCredentialReturnsAComposer() {
        let result = factory.composer(backend: .cloud, provider: .openai, endpointURL: nil, modelOverride: nil, credential: "sk-test")
        #expect(result != nil)
    }

    @Test func cloudNIMWithNoModelReturnsNilEvenWithACredential() {
        let result = factory.composer(backend: .cloud, provider: .nvidiaNIM, endpointURL: nil, modelOverride: nil, credential: "nvapi-test")
        #expect(result == nil)
    }

    @Test func cloudNIMWithModelReturnsAComposer() {
        let result = factory.composer(
            backend: .cloud, provider: .nvidiaNIM, endpointURL: nil,
            modelOverride: "meta/llama-3.1-8b-instruct", credential: "nvapi-test"
        )
        #expect(result != nil)
    }

    @Test func localEndpointWithNoModelReturnsNil() {
        let result = factory.composer(
            backend: .localEndpoint, provider: nil, endpointURL: "http://192.168.1.20:11434",
            modelOverride: nil, credential: nil
        )
        #expect(result == nil)
    }

    @Test func localEndpointWithUrlAndModelReturnsAComposerEvenWithNoCredential() {
        let result = factory.composer(
            backend: .localEndpoint, provider: nil, endpointURL: "http://192.168.1.20:11434",
            modelOverride: "llama3.2", credential: nil
        )
        #expect(result != nil)
    }

    @Test func localEndpointWithEmbeddedCredentialsURLReturnsNilRatherThanThrowing() {
        let result = factory.composer(
            backend: .localEndpoint, provider: nil, endpointURL: "http://user:pass@192.168.1.20:11434",
            modelOverride: "llama3.2", credential: nil
        )
        #expect(result == nil, "an invalid endpoint must degrade to not-configured, never propagate a throw")
    }
}
```

- [ ] **Step 2: Run to verify failure**

```bash
cd app/Packages/SenseBridgeCore && swift test --filter ReasoningComposerResolverTests
```

Expected: FAIL — `cannot find type 'ReasoningComposerResolver' in scope`

- [ ] **Step 3: Implement**

```swift
// app/Packages/SenseBridgeCore/Sources/SenseBridgeCore/Reasoning/ReasoningComposerResolver.swift
import Foundation

/// The outcome of one `ReasoningComposerResolver.compose` call.
public struct ReasoningComposeResult: Sendable, Equatable {
    public let text: String
    public let backendUsed: ReasoningBackend
    /// Non-nil only for the two events the disclosure model actually
    /// speaks: a network backend just failed twice in a row (breaker
    /// tripped), or it just recovered after being tripped. Every other case
    /// — never configured, working normally — is `nil`. See
    /// docs/superpowers/specs/2026-08-11-awareness-ai-tiers-design.md
    /// "Resolution, concurrency, and fallback".
    public let announcement: String?
}

/// Builds a network `SceneComposer` for the given configuration, or `nil`
/// when required configuration (a credential, a URL, a model name) is
/// missing — which the resolver treats as "not configured," not "failing."
/// `modelOverride` is a call-time parameter rather than something baked into
/// the factory at construction, so one long-lived factory instance (built
/// once per session/view) always sees the user's current `Settings` value
/// instead of whatever was true when the factory was built.
public protocol NetworkComposerFactory: Sendable {
    func composer(
        backend: ReasoningBackend, provider: CloudProvider?, endpointURL: String?,
        modelOverride: String?, credential: String?
    ) -> SceneComposer?
}

/// The real factory, used everywhere outside tests. Builds a fresh composer
/// per call rather than caching one, so a credential or model rotated
/// mid-session takes effect on the next request.
public struct LiveNetworkComposerFactory: NetworkComposerFactory {
    private let session: URLSession
    private let requestTimeout: TimeInterval
    private let locale: Locale

    public init(session: URLSession, requestTimeout: TimeInterval, locale: Locale) {
        self.session = session
        self.requestTimeout = requestTimeout
        self.locale = locale
    }

    public func composer(
        backend: ReasoningBackend, provider: CloudProvider?, endpointURL: String?,
        modelOverride: String?, credential: String?
    ) -> SceneComposer? {
        switch backend {
        case .onDevice:
            return nil
        case .cloud:
            switch provider {
            case .anthropic:
                guard let credential else { return nil }
                return AnthropicSceneComposer(apiKey: credential, model: modelOverride, session: session, locale: locale)
            case .openai:
                guard let credential else { return nil }
                return try? OpenAICompatibleSceneComposer(
                    endpointURL: "https://api.openai.com/v1/chat/completions",
                    apiKey: credential, model: modelOverride ?? "gpt-4o-mini", session: session, locale: locale
                )
            case .nvidiaNIM:
                // No universal default model exists for NIM — the Settings
                // UI (Task 17) requires `reasoningModelOverride` before this
                // backend can be enabled; treat a missing model as
                // not-configured here too.
                guard let modelOverride, !modelOverride.isEmpty else { return nil }
                return try? OpenAICompatibleSceneComposer(
                    endpointURL: "https://integrate.api.nvidia.com/v1/chat/completions",
                    apiKey: credential, model: modelOverride, session: session, locale: locale
                )
            case nil:
                return nil
            }
        case .localEndpoint:
            guard let endpointURL, !endpointURL.isEmpty,
                  let modelOverride, !modelOverride.isEmpty
            else { return nil }
            return try? OpenAICompatibleSceneComposer(
                endpointURL: endpointURL, apiKey: credential, model: modelOverride, session: session, locale: locale
            )
        }
    }
}

/// Picks the active reasoning backend from `Settings`, falls back to
/// on-device on any missing configuration or failure, and runs the
/// disclosure/circuit-breaker model described in the spec. One instance is
/// owned per session (`AmbientAwarenessSession`, `SceneDescriptionView`),
/// matching the existing per-session-instantiated-and-reset pattern
/// `AwarenessEngine`/`NarrationThrottle` already use.
@MainActor
public final class ReasoningComposerResolver {
    private let onDeviceComposer: SceneComposer
    private let credentialStore: APICredentialStore
    private let factory: NetworkComposerFactory

    private var consecutiveFailures = 0
    private var breakerTripped = false
    private var probeTickCounter = 0
    /// Every 5th tick while tripped, per the spec's circuit-breaker cadence
    /// — bounds cost against a still-down endpoint without abandoning
    /// recovery detection entirely.
    private static let probeCadence = 5

    public init(onDeviceComposer: SceneComposer, credentialStore: APICredentialStore, factory: NetworkComposerFactory) {
        self.onDeviceComposer = onDeviceComposer
        self.credentialStore = credentialStore
        self.factory = factory
    }

    /// Resets breaker/failure state for a new session — must be called
    /// alongside `AwarenessEngine.reset()`/`NarrationThrottle.reset()` when
    /// hands-free awareness restarts, so a previous session's trip/recovery
    /// state never leaks into a new one.
    public func resetSession() {
        consecutiveFailures = 0
        breakerTripped = false
        probeTickCounter = 0
    }

    public func compose(
        from records: [PerceptionRecord],
        settings: Settings,
        locale: Locale,
        requestTimeout: TimeInterval
    ) async -> ReasoningComposeResult? {
        if settings.reasoningBackend.usesNetwork, shouldAttemptNetwork() {
            let credential = credential(for: settings)
            if let composer = factory.composer(
                backend: settings.reasoningBackend,
                provider: settings.cloudProvider,
                endpointURL: settings.localEndpointURL,
                modelOverride: settings.reasoningModelOverride,
                credential: credential
            ) {
                do {
                    let text = try await composer.compose(from: records)
                    let announcement = recoveryAnnouncementIfNeeded(locale: locale)
                    return ReasoningComposeResult(text: text, backendUsed: settings.reasoningBackend, announcement: announcement)
                } catch {
                    recordFailure()
                }
            }
            // `factory.composer` returning `nil` means "not configured" —
            // falls through to on-device below without counting as a
            // failure and without an announcement (disclosure case 1).
        }
        guard let text = try? await onDeviceComposer.compose(from: records) else { return nil }
        let announcement = settings.reasoningBackend.usesNetwork ? failureAnnouncementIfNeeded(locale: locale) : nil
        return ReasoningComposeResult(text: text, backendUsed: .onDevice, announcement: announcement)
    }

    private func credential(for settings: Settings) -> String? {
        switch settings.reasoningBackend {
        case .onDevice: nil
        case .cloud:
            switch settings.cloudProvider {
            case .anthropic: credentialStore.credential(for: .anthropic)
            case .openai: credentialStore.credential(for: .openai)
            case .nvidiaNIM: credentialStore.credential(for: .nvidiaNIM)
            case nil: nil
            }
        case .localEndpoint: credentialStore.credential(for: .localEndpoint)
        }
    }

    /// While the breaker is tripped, only every `probeCadence`th tick
    /// actually attempts the network — every other tick goes straight to
    /// on-device, bounding cost against a still-down endpoint.
    private func shouldAttemptNetwork() -> Bool {
        guard breakerTripped else { return true }
        probeTickCounter += 1
        return probeTickCounter % Self.probeCadence == 0
    }

    private func recordFailure() {
        consecutiveFailures += 1
    }

    private func failureAnnouncementIfNeeded(locale: Locale) -> String? {
        guard consecutiveFailures >= 2, !breakerTripped else { return nil }
        breakerTripped = true
        probeTickCounter = 0
        return LocalizedCatalog.string(
            "Cloud descriptions aren't responding, so SenseBridge is continuing with on-device descriptions.",
            locale: locale
        )
    }

    private func recoveryAnnouncementIfNeeded(locale: Locale) -> String? {
        guard breakerTripped else { return nil }
        breakerTripped = false
        consecutiveFailures = 0
        probeTickCounter = 0
        return LocalizedCatalog.string(
            "Cloud descriptions are working again.", locale: locale
        )
    }
}
```

- [ ] **Step 4: Run to verify pass**

```bash
cd app/Packages/SenseBridgeCore && swift test --filter ReasoningComposerResolverTests
```

Expected: PASS, 7 cases.

- [ ] **Step 5: Commit**

```bash
git add app/Packages/SenseBridgeCore/Sources/SenseBridgeCore/Reasoning/ReasoningComposerResolver.swift \
  app/Packages/SenseBridgeCore/Tests/SenseBridgeCoreTests/ReasoningComposerResolverTests.swift
git commit -m "feat(reasoning): add ReasoningComposerResolver with circuit-breaker fallback disclosure"
```

---

### Task 10: Wire the resolver into `AmbientAwarenessSession` — non-blocking composition + disclosure

**Files:**

- Modify: `app/SenseBridge/Features/ObstacleAwareness/AmbientAwarenessSession.swift`
- Test: `app/Packages/SenseBridgeCore/Tests/SenseBridgeCoreTests/` — resolver
  logic is already covered by Task 9; this task's own correctness (single-
  flight, cancellation, staleness) is covered by an XCUITest-adjacent manual
  smoke path noted in Task 19, since `AmbientAwarenessSession` depends on
  `UIKit`/`ARKit` and lives in the App layer, outside `swift test`'s reach —
  flag this explicitly rather than skip verification silently.

**Interfaces:**

- Consumes: `ReasoningComposerResolver`, `ReasoningComposeResult` (Task 9),
  `NarrationThrottle.shouldSpeak(_:at:isUrgent:)` (existing).
- Produces: updated `AmbientAwarenessSession.start(environment:)`/`stop()`/
  `describeIfDue(_:environment:)` behavior — this is the load-bearing fix for
  the "composition must not block depth sampling" blocker from the design
  review.

- [ ] **Step 1: Replace the hardcoded composer with the resolver**

Modify `app/SenseBridge/Features/ObstacleAwareness/AmbientAwarenessSession.swift`.

Change the stored property (currently line 88):

```swift
    private var composer: FoundationModelsSceneComposer = .init()
```

to:

```swift
    private var resolver: ReasoningComposerResolver?
```

In `start(environment:)`, replace the composer construction (currently line
128, `composer = FoundationModelsSceneComposer(phrasing: phrasing, locale: locale)`)
with:

```swift
        let onDevice = FoundationModelsSceneComposer(phrasing: phrasing, locale: locale)
        let urlSession = Self.makeURLSession(requestTimeout: Self.networkRequestTimeout)
        resolver = ReasoningComposerResolver(
            onDeviceComposer: onDevice,
            credentialStore: KeychainCredentialStore(),
            factory: LiveNetworkComposerFactory(session: urlSession, requestTimeout: Self.networkRequestTimeout, locale: locale)
        )
        resolver?.resetSession()
```

`LiveNetworkComposerFactory` takes `modelOverride` as a call-time parameter
on `composer(...)` (Task 9), not at construction — the resolver already
passes `settings.reasoningModelOverride` through on every call, so no
per-view wrapper type is needed here. (An earlier draft of this task
introduced a `ModelAwareNetworkComposerFactory` wrapper; that's gone —
`LiveNetworkComposerFactory` alone now handles every backend, including
NVIDIA NIM and the self-hosted endpoint, directly.)

Add the supporting piece near the bottom of the file, in the existing
private `extension AmbientAwarenessSession` (currently lines 353-378):

```swift
    /// Shared `URLSession` config for every network reasoning request —
    /// never the platform default, which would queue a request until
    /// connectivity returns (`waitsForConnectivity`) and allow a 60s
    /// timeout, both wrong for a real-time spoken-output app. No automatic
    /// retries anywhere in this stack — see the plan's global constraints.
    static func makeURLSession(requestTimeout: TimeInterval) -> URLSession {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.waitsForConnectivity = false
        configuration.timeoutIntervalForRequest = requestTimeout
        configuration.allowsConstrainedNetworkAccess = false
        return URLSession(configuration: configuration)
    }

    /// Hands-free awareness narrates on a comfort-driven cadence, not an
    /// emergency one — a short timeout keeps a slow endpoint from holding up
    /// the session, matching the spec's "~4s for hands-free composition"
    /// figure.
    static let networkRequestTimeout: TimeInterval = 4
```

In `stop()`, add breaker reset alongside the existing `engine.reset()`/
`throttle.reset()` calls (currently lines 163-165):

```swift
        resolver?.resetSession()
```

- [ ] **Step 2: Make composition non-blocking, single-flight, cancellable, staleness-guarded**

Add a new stored property near `loopTask` (currently line 91):

```swift
    private var compositionTask: Task<Void, Never>?
```

Replace `describeIfDue(_:environment:)` (currently lines 255-301):

```swift
    /// Classifies and narrates the scene, if enough time has passed, the
    /// channel is free, and no composition is already in flight.
    ///
    /// Composition runs as a **tracked, single-flight, cancellable child
    /// task** rather than being awaited inline — a network composer's
    /// round-trip must never stall the 750ms depth-sampling tick this method
    /// is called from, or hands-free awareness would stop noticing something
    /// stepping in front of the user for however long the request takes. See
    /// docs/superpowers/specs/2026-08-11-awareness-ai-tiers-design.md
    /// "Resolution, concurrency, and fallback".
    private func describeIfDue(_ frame: AmbientFrame, environment: AppEnvironment) {
        guard compositionTask == nil else { return } // single-flight: skip, don't queue
        let now = Date.now
        if let lastDescribedAt,
           now.timeIntervalSince(lastDescribedAt) < environment.settings.narrationIntervalSeconds {
            return
        }
        lastDescribedAt = now
        let capturedAt = frame.capturedAt
        let staleAfter = max(environment.settings.narrationIntervalSeconds * 2, 12)
        let currentDetections = detectedObjects

        compositionTask = Task { [weak self] in
            defer { self?.compositionTask = nil }
            guard let self else { return }
            guard let records = await self.records(for: frame, detections: currentDetections) else { return }
            guard let resolver = self.resolver else { return }
            guard let result = await resolver.compose(
                from: records,
                settings: environment.settings,
                locale: self.locale,
                requestTimeout: Self.networkRequestTimeout
            ) else { return }
            guard !Task.isCancelled, self.status == .running else { return }
            // Staleness guard: a description of a frame captured this long
            // ago is a statement about somewhere the user may have already
            // walked away from — see the spec's non-blocking-composition
            // section.
            guard Date.now.timeIntervalSince(capturedAt) <= staleAfter else { return }
            if let announcement = result.announcement {
                await self.deliver(announcement, signal: .error, isUrgent: true, to: environment)
            }
            guard self.throttle.shouldSpeak(result.text, at: Date.now) else { return }
            await self.deliver(
                result.text,
                signal: records.isEmpty ? .nothingFound : .resultReady,
                isUrgent: false,
                to: environment
            )
        }
    }

    /// Builds the records to compose from — detections if the last pass
    /// found any discrete objects, otherwise a whole-frame classification
    /// pass. Split out of `describeIfDue` so that method reads as the
    /// scheduling/cancellation logic it is, not classification plumbing.
    private func records(for frame: AmbientFrame, detections: [DetectedObject]) async -> [PerceptionRecord]? {
        if detections.isEmpty {
            do {
                return try await classifier.classify(frame.image, orientation: frame.orientation)
            } catch {
                return nil
            }
        }
        return detections.map {
            PerceptionRecord(kind: .detectedObject(label: $0.label, confidence: $0.confidence), capturedAt: .now)
        }
    }
```

`describeIfDue` is called from `tick(environment:)` (currently line 193,
`await describeIfDue(frame, environment: environment)`) — since it's no
longer `async` itself (the work moved into the tracked `Task`), update that
call site to drop `await`:

```swift
        describeIfDue(frame, environment: environment)
```

In `stop()`, cancel the composition task alongside `loopTask` (currently
lines 153-154):

```swift
        compositionTask?.cancel()
        compositionTask = nil
```

- [ ] **Step 3: Extend the backend-visibility footnote to name the network backends**

`isUsingLanguageModel` (currently lines 75-77) only ever distinguishes
Foundation-Models-available vs not. Replace it with a richer status the view
(Task 14) can render for all backends:

```swift
    /// Which backend is actually composing descriptions right now, for the
    /// view to name — see AGENTS.md doctrine 4: a user who doesn't know
    /// which backend they're hearing can't tell a degraded mode from a bug.
    /// Read from `Settings` plus on-device model availability, not cached,
    /// so it stays accurate if the user changes it mid-session via Settings.
    func activeBackendDescription(settings: Settings) -> String {
        switch settings.reasoningBackend {
        case .onDevice:
            FoundationModelsSceneComposer.isModelAvailable
                ? "Descriptions are composed on-device by Apple Intelligence."
                : "Apple Intelligence is unavailable, so descriptions are read out as a plain list of what was recognized."
        case .localEndpoint:
            "Descriptions are composed by your self-hosted endpoint, with on-device as a fallback."
        case .cloud:
            switch settings.cloudProvider {
            case .anthropic: "Descriptions are composed by Anthropic, with on-device as a fallback."
            case .openai: "Descriptions are composed by OpenAI, with on-device as a fallback."
            case .nvidiaNIM: "Descriptions are composed by NVIDIA NIM, with on-device as a fallback."
            case nil: "Descriptions are composed on-device — no cloud provider is selected yet."
            }
        }
    }
```

Remove the now-superseded `isUsingLanguageModel` computed property (lines
75-77) — Task 14 updates the one call site.

- [ ] **Step 4: Build and manually verify (no simulator/CI path exercises ARKit)**

```bash
cd app && xcodebuild build -scheme SenseBridge -destination 'generic/platform=iOS' 2>&1 | tail -40
```

Expected: `** BUILD SUCCEEDED **`. Full behavioral verification (does the
depth tick actually keep running during a slow network call) is device-only
— flag this explicitly in the PR/session log rather than claiming it's
proven by the build.

- [ ] **Step 5: Commit**

```bash
git add app/SenseBridge/Features/ObstacleAwareness/AmbientAwarenessSession.swift
git commit -m "feat(awareness): wire the reasoning resolver with non-blocking, single-flight composition"
```

---

### Task 11: `KeychainCredentialStore` (App layer)

**Files:**

- Create: `app/SenseBridge/App/KeychainCredentialStore.swift`

**Interfaces:**

- Consumes: `APICredentialStore` (Task 6).
- Produces: `KeychainCredentialStore: APICredentialStore` — consumed by
  `AmbientAwarenessSession` (Task 10), `SceneDescriptionView` (Task 12),
  `ReasoningBackendSettingsView` (Task 15).

No automated test — Keychain access is not reliably testable under `swift
test`/`xcodebuild test` without a signed, entitled test target (the existing
codebase has no precedent for this; `CrashReporting`'s equivalent
side-effecting code is also untested directly, only `scrub(_:)`'s pure logic
is). Flagged device-only in the plan's global constraints and in Task 21.

- [ ] **Step 1: Implement**

```swift
// app/SenseBridge/App/KeychainCredentialStore.swift
import Foundation
import Security
import SenseBridgeCore

/// Keychain-backed `APICredentialStore` — the only place BYOK API keys and
/// the self-hosted endpoint's optional token are ever written. See
/// docs/superpowers/specs/2026-08-11-awareness-ai-tiers-design.md
/// "Data model" for why every attribute below is spelled out explicitly,
/// matching `CrashReporting.start(dsn:)`'s "a reviewer should see the whole
/// surface without knowing any SDK defaults" convention.
final class KeychainCredentialStore: APICredentialStore, @unchecked Sendable {
    private let service = "com.sensebridge.reasoning-credentials"

    func credential(for key: CredentialKey) -> String? {
        var query = baseQuery(for: key)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess, let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    /// Updates an existing entry rather than blindly adding, which would
    /// return `errSecDuplicateItem` on a second save and silently leave the
    /// old (possibly rotated-out) key in place — the single most common
    /// Keychain bug, and the direction it fails in matters here.
    func save(_ value: String, for key: CredentialKey) {
        guard let data = value.data(using: .utf8) else { return }
        let query = baseQuery(for: key)
        var checkStatus: OSStatus = errSecItemNotFound
        checkStatus = SecItemCopyMatching(query as CFDictionary, nil)
        if checkStatus == errSecSuccess {
            SecItemUpdate(query as CFDictionary, [kSecValueData as String: data] as CFDictionary)
        } else {
            var addQuery = query
            addQuery[kSecValueData as String] = data
            SecItemAdd(addQuery as CFDictionary, nil)
        }
    }

    /// Switching `Settings.reasoningBackend` away from `.cloud` must never
    /// call this implicitly — retention is the user's explicit choice from
    /// the Settings UI's "Remove key" control (Task 15).
    func removeCredential(for key: CredentialKey) {
        SecItemDelete(baseQuery(for: key) as CFDictionary)
    }

    private func baseQuery(for key: CredentialKey) -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key.rawValue,
            // Rides neither an encrypted backup nor iCloud Keychain sync —
            // this is a billing credential, and `docs/ARCHITECTURE.md`
            // already plans optional CloudKit settings sync, so keeping it
            // out of both paths is deliberate, not an oversight.
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
            kSecAttrSynchronizable as String: false
        ]
    }
}
```

- [ ] **Step 2: Build**

```bash
cd app && xcodebuild build -scheme SenseBridge -destination 'generic/platform=iOS' 2>&1 | tail -40
```

Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 3: Commit**

```bash
git add app/SenseBridge/App/KeychainCredentialStore.swift
git commit -m "feat(app): add KeychainCredentialStore for BYOK reasoning credentials"
```

---

### Task 12: Wire the resolver into `SceneDescriptionView`

**Files:**

- Modify: `app/SenseBridge/Features/SceneDescription/SceneDescriptionView.swift`

**Interfaces:**

- Consumes: `ReasoningComposerResolver`, `LiveNetworkComposerFactory`,
  `KeychainCredentialStore` (same construction pattern as Task 10, but
  one-shot rather than session-scoped).

- [ ] **Step 1: Replace the hardcoded composer**

Modify `app/SenseBridge/Features/SceneDescription/SceneDescriptionView.swift`.

Change the stored property (currently line 12):

```swift
    private let composer: FoundationModelsSceneComposer = .init()
```

to:

```swift
    private let resolver: ReasoningComposerResolver
```

Since this view has no `init` today (it relies on default property
initializers and `@Environment`), add an explicit one that builds the
resolver the same way `AmbientAwarenessSession.start` does, but without a
session-scoped `URLSession`/breaker lifetime (one capture is one request; a
tripped breaker would never get the chance to matter within a single call,
so a fresh resolver per view instance is correct and simpler than trying to
share `AmbientAwarenessSession`'s):

```swift
    init() {
        let session = URLSessionConfiguration.ephemeral
        session.waitsForConnectivity = false
        session.timeoutIntervalForRequest = Self.networkRequestTimeout
        session.allowsConstrainedNetworkAccess = false
        let urlSession = URLSession(configuration: session)
        resolver = ReasoningComposerResolver(
            onDeviceComposer: FoundationModelsSceneComposer(),
            credentialStore: KeychainCredentialStore(),
            factory: LiveNetworkComposerFactory(session: urlSession, requestTimeout: Self.networkRequestTimeout, locale: .current)
        )
    }

    /// A single capture can afford a longer timeout than the hands-free
    /// narration cadence — see `AmbientAwarenessSession.networkRequestTimeout`
    /// for the shorter hands-free figure and why it differs.
    private static let networkRequestTimeout: TimeInterval = 8
```

Replace the composition call in `captureAndDescribe()` (currently lines
60-77):

```swift
    private func captureAndDescribe() async {
        do {
            let photo = try await environment.camera.capturePhoto()
            let objects = try await detector.detect(photo)
            let records = objects.map {
                PerceptionRecord(kind: .detectedObject(label: $0.label, confidence: $0.confidence), capturedAt: .now)
            }
            guard let result = await resolver.compose(
                from: records, settings: environment.settings, locale: .current,
                requestTimeout: Self.networkRequestTimeout
            ) else {
                lastResult = message(for: CameraSource.CameraError.noCameraAvailable) // unreachable in practice; see note below
                return
            }
            if let announcement = result.announcement {
                announceIfUnspoken(announcement, profile: environment.settings.outputProfile)
                await environment.output.render(OutputMessage(text: announcement, signal: .error))
            }
            lastResult = result.text
            announceIfUnspoken(result.text, profile: environment.settings.outputProfile)
            await environment.output.render(OutputMessage(text: result.text, signal: .resultReady))
        } catch {
            let spoken = message(for: error)
            lastResult = spoken
            announceIfUnspoken(spoken, profile: environment.settings.outputProfile)
            await environment.output.render(OutputMessage(text: spoken, signal: .error))
        }
    }
```

Note left for the implementer, not shipped as a code comment (it references
"in practice" reasoning that belongs in review, not in the file): the
`nil`-from-resolver branch above is unreachable in normal operation since
`FoundationModelsSceneComposer`'s on-device fallback chain never throws —
it's handled anyway because the resolver's return type is optional and a
silent skip (matching `AmbientAwarenessSession`'s own `guard let text =
try? ... else { return }` pattern) would leave `SceneDescriptionView`
showing a stale `lastResult` from a previous capture with no explanation;
speaking *some* error is better than silence here since this is a one-shot
action the user is waiting on, not a continuous channel.

- [ ] **Step 2: Build**

```bash
cd app && xcodebuild build -scheme SenseBridge -destination 'generic/platform=iOS' 2>&1 | tail -40
```

Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 3: Commit**

```bash
git add app/SenseBridge/Features/SceneDescription/SceneDescriptionView.swift
git commit -m "feat(scene-description): wire the reasoning resolver into Describe"
```

---

### Task 13: Pin output language in `FoundationModelsSceneComposer` (opportunistic fix)

**Files:**

- Modify: `app/SenseBridge/Features/SceneDescription/FoundationModelsSceneComposer.swift:55-61`

**Interfaces:** No signature change — `instructions` stays `private static`,
now takes `locale` as a parameter.

- [ ] **Step 1: Fix the pre-existing language gap**

The design review flagged this while the sibling network-composer files were
already being written: `instructions` (currently a `static let`, lines
55-61) never tells the model which language to answer in, while `Phrasing`
wraps the result in a localized template — an `es`/`vi` user can get
`"có vẻ như có a chair and a doorway."` today. Change:

```swift
    private static let instructions = """
    You compress a list of detected object labels into one short noun phrase \
    for a blind user's screen reader. Name only objects present in the list. \
    Never add objects, never guess what the place is, never describe distance, \
    direction, movement, or safety, and never write a full sentence. \
    Another part of the app adds the wording around your phrase.
    """
```

to:

```swift
    /// Pins the reply language to `locale` — without this, `es`/`vi` users
    /// could get an English noun phrase wrapped in a translated hedge
    /// template. Caught during the 2026-08-11 reasoning-tier design review
    /// while adding the same instruction to the new network composers.
    private static func instructions(locale: Locale) -> String {
        """
        You compress a list of detected object labels into one short noun phrase \
        for a blind user's screen reader. Name only objects present in the list. \
        Never add objects, never guess what the place is, never describe distance, \
        direction, movement, or safety, and never write a full sentence. Respond \
        only with the noun phrase, in the language identified by locale \
        "\(locale.identifier)". Another part of the app adds the wording around \
        your phrase.
        """
    }
```

Update the one call site inside `modelPhrase(for:)` (currently line 116,
`let session = LanguageModelSession(instructions: Self.instructions)`):

```swift
            let session = LanguageModelSession(instructions: Self.instructions(locale: locale))
```

- [ ] **Step 2: Build and run existing composer tests**

```bash
cd app/Packages/SenseBridgeCore && swift test --filter SceneComposerTests
cd app && xcodebuild build -scheme SenseBridge -destination 'generic/platform=iOS' 2>&1 | tail -40
```

Expected: PASS / `** BUILD SUCCEEDED **`. (This composer needs a real Apple
Intelligence-capable device to exercise the model path at all — the build
proves it compiles, not that the language pin works; note that plainly.)

- [ ] **Step 3: Commit**

```bash
git add app/SenseBridge/Features/SceneDescription/FoundationModelsSceneComposer.swift
git commit -m "fix(scene-description): pin FoundationModelsSceneComposer's reply language to the request locale"
```

---

### Task 14: `AmbientSensingSource.sampleOnce()` — real one-shot depth reading

**Files:**

- Modify: `app/Packages/SenseBridgeCore/Sources/SenseBridgeCore/Sensing/AmbientSensingSource.swift`
- Test: `app/Packages/SenseBridgeCore/Tests/SenseBridgeCoreTests/DepthStatisticsTests.swift` (extend — the reduction math `sampleOnce` calls is already covered there; no new fixture-level test needed for the reduction itself)

**Interfaces:**

- Produces: `AmbientSensingSource.sampleOnce(timeout: Duration) async throws
  -> Double?` — consumed by `ObstacleAwarenessView`'s "Check once" fix
  (Task 15). Returns `nil` when a frame arrived but carried no usable depth
  (matches `depthMeters(in:)`'s existing "could not measure" contract), and
  throws `SensingError` when the session itself can't start.

- [ ] **Step 1: Implement**

The ARKit session start/first-frame-arrival path is device-only — there is
no fixture-based unit test possible for this method itself (matching
`start()`/`latestFrame()` above it in the same file, which are also
untested directly; only the pure reduction functions they call,
`DepthStatistics`/`DepthGeometry`, have fixture tests). Implement directly,
then verify via Task 15's manual device check.

Add to `app/Packages/SenseBridgeCore/Sources/SenseBridgeCore/Sensing/AmbientSensingSource.swift`,
after `stop()` (currently lines 176-180):

```swift
        /// Takes exactly one depth reading: starts the session, waits for the
        /// first usable frame (or `timeout`), reads it, and stops — for
        /// `ObstacleAwarenessView`'s one-shot "Check once" control, which
        /// must not hold the camera or the display-awake assertion the way
        /// the continuous hands-free session does.
        ///
        /// Returns `nil` when a frame arrived but the depth reduction found
        /// nothing measurable — the same "could not measure" contract as
        /// `depthMeters(in:)`, never "nothing is there". Throws when the
        /// session itself can't start (missing LiDAR, unsupported device),
        /// exactly like `start()`.
        public func sampleOnce(timeout: Duration = .seconds(3)) async throws -> Double? {
            try start()
            defer { stop() }
            let deadline = ContinuousClock.now.advanced(by: timeout)
            while latestFrame() == nil {
                guard ContinuousClock.now < deadline else { return nil }
                try await Task.sleep(for: .milliseconds(50))
            }
            guard let frame = latestFrame() else { return nil }
            return await depthMeters(in: frame)
        }
```

- [ ] **Step 2: Build the package**

```bash
cd app/Packages/SenseBridgeCore && swift build
```

Expected: builds clean. (`AmbientSensingSource` is behind `#if
canImport(ARKit) && os(iOS)` — this compiles for iOS targets; macOS package
tests skip the whole file, matching existing behavior for this type.)

- [ ] **Step 3: Commit**

```bash
git add app/Packages/SenseBridgeCore/Sources/SenseBridgeCore/Sensing/AmbientSensingSource.swift
git commit -m "feat(sensing): add AmbientSensingSource.sampleOnce() for a real one-shot depth reading"
```

---

### Task 15: Fix `ObstacleAwarenessView`'s "Check once" — real depth, fresh engine, measuring state, 3-backend footnote

**Files:**

- Modify: `app/SenseBridge/Features/ObstacleAwareness/ObstacleAwarenessView.swift`

**Interfaces:**

- Consumes: `AmbientSensingSource.sampleOnce()` (Task 14),
  `Phrasing.couldNotMeasure(locale:)` (Task 3),
  `AmbientAwarenessSession.activeBackendDescription(settings:)` (Task 10).

- [ ] **Step 1: Fix the mock data, fresh-engine-per-tap, and add a measuring state**

The current button (lines 172-196) toggles a hardcoded `1.0`/`3.0` and
reuses one `@State private var engine: AwarenessEngine` across taps
(line 65), so a stale hysteresis band from a previous tap in a previous room
can misreport a fresh reading. Replace the `@State` engine declaration
(line 65):

```swift
    @State private var isTakingReading = false
```

(removes `@State private var engine: AwarenessEngine = .init()` and
`@State private var isNearReading = true` — both were only ever serving the
mock toggle.)

Add a session source, matching the pattern `AmbientAwarenessSession` itself
uses:

```swift
    @State private var oneShotSource: AmbientSensingSource = .init()
```

Replace the whole `Button("Check once for what may be ahead")` block
(lines 172-196):

```swift
            Button(isTakingReading ? "Measuring…" : "Check once for what may be ahead") {
                Task { await takeOneShotReading() }
            }
            .disabled(session.status == .running || isTakingReading)
            .accessibilityValue(
                session.status == .running ? "Unavailable while hands-free awareness is running"
                    : isTakingReading ? "Measuring" : ""
            )
            .accessibilityHint("""
            Takes one cautious reading of what may be nearby. It does not keep \
            watching, and it is not a safety feature.
            """)
```

Add the implementation as a new method on the view, near
`startCameraIfNeeded`/`captureAndDescribe`-style helpers other feature views
use (place it in a private extension at the bottom of the file, following
this file's existing `// MARK: -` sectioning):

```swift
    /// Takes one real depth reading — replaces the previous mock toggle
    /// between hardcoded 1.0/3.0 values. A **fresh** `AwarenessEngine` per
    /// call, deliberately: the continuous session's hysteresis band is right
    /// for a loop and wrong for a one-shot check, where reusing state across
    /// taps could report "something ahead" from a reading taken in a
    /// different room minutes earlier.
    private func takeOneShotReading() async {
        isTakingReading = true
        defer { isTakingReading = false }
        let depthMeters: Double?
        do {
            depthMeters = try await oneShotSource.sampleOnce()
        } catch {
            let spoken = phrasing.couldNotMeasure()
            lastResult = spoken
            announceIfUnspoken(spoken, profile: environment.settings.outputProfile)
            await environment.output.render(OutputMessage(text: spoken, signal: .error))
            return
        }
        guard let depthMeters else {
            // A frame arrived but nothing was measurable — distinct from
            // "nothing recognized" and never `.awarenessClear`, matching
            // `DepthStatistics`'s own "could not measure" contract.
            let spoken = phrasing.couldNotMeasure()
            lastResult = spoken
            announceIfUnspoken(spoken, profile: environment.settings.outputProfile)
            await environment.output.render(OutputMessage(text: spoken, signal: .error))
            return
        }
        var freshEngine = AwarenessEngine(
            alertThresholdMeters: environment.settings.awarenessAlertDistanceMeters
        )
        _ = freshEngine.evaluate(depthMeters: depthMeters)
        let isAlerting = freshEngine.isAlerting
        let message = isAlerting
            ? phrasing.describe(subject: phrasing.somethingAhead(), certainty: .medium)
            : phrasing.nothingRecognized()
        lastResult = message
        let signal: OutputSignal = isAlerting ? .awarenessAlert : .nothingFound
        announceIfUnspoken(message, profile: environment.settings.outputProfile)
        await environment.output.render(OutputMessage(text: message, signal: signal))
    }
```

`AwarenessEngine`'s designated initializer takes `alertThresholdMeters` and
`clearThresholdMeters` (default `2.5`) — passing only
`alertThresholdMeters:` uses the existing default for the other, which is
fine for a one-shot evaluation since hysteresis never gets a second reading
to matter for.

- [ ] **Step 2: Extend the backend-visibility footnote to all three backends**

Replace the on-device-only footnote (lines 129-136):

```swift
                Text(session.isUsingLanguageModel
                    ? "Descriptions are composed on-device by Apple Intelligence."
                    : """
                    Apple Intelligence is unavailable, so descriptions are read \
                    out as a plain list of what was recognized.
                    """)
                    .font(.footnote)
                    .foregroundStyle(Color("SecondaryText"))
```

with:

```swift
                Text(session.activeBackendDescription(settings: environment.settings))
                    .font(.footnote)
                    .foregroundStyle(Color("SecondaryText"))
```

- [ ] **Step 3: Build**

```bash
cd app && xcodebuild build -scheme SenseBridge -destination 'generic/platform=iOS' 2>&1 | tail -40
```

Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 4: Manual device verification (flag, don't skip)**

No CI/simulator substitute exists for ARKit depth capture — note in the
session log that "Check once" needs a real-device tap-through: a near
object reports "something ahead," a clear area reports "nothing
recognizable," and covering the camera or a cold start within the 3s
timeout reports "couldn't take a measurement."

- [ ] **Step 5: Commit**

```bash
git add app/SenseBridge/Features/ObstacleAwareness/ObstacleAwarenessView.swift
git commit -m "fix(awareness): replace mock Check-once depth data with a real one-shot reading"
```

---

### Task 16: `tools/check-linguist-vendored.mjs`-style catalog coverage guardrail

**Files:**

- Create: `tools/check-catalog-coverage.mjs`
- Modify: `package.json` (add to the `check` script chain)

**Interfaces:** CLI script, no Swift interface. Exits non-zero and prints
every key missing an `es` or `vi` translation across all three `.xcstrings`
files in the repo.

- [ ] **Step 1: Write the script**

```javascript
// tools/check-catalog-coverage.mjs
// Guardrail for docs/superpowers/specs/2026-08-11-awareness-ai-tiers-design.md
// "Guardrails for the new tooling" — fails the build if any String Catalog
// key is missing an es or vi translation. Read-only: never writes or
// auto-translates anything.
import { readFileSync } from "node:fs";
import { globSync } from "node:fs";

const REQUIRED_LOCALES = ["es", "vi"];

const catalogPaths = [
  "app/Packages/SenseBridgeCore/Sources/SenseBridgeCore/Resources/Localizable.xcstrings",
  "app/SenseBridge/Resources/Localizable.xcstrings",
  "app/SenseBridge/Resources/InfoPlist.xcstrings",
];

let failures = [];

for (const path of catalogPaths) {
  const catalog = JSON.parse(readFileSync(path, "utf8"));
  for (const [key, entry] of Object.entries(catalog.strings ?? {})) {
    const localizations = entry.localizations ?? {};
    // A key with no localizations at all is source-language-only metadata
    // (e.g. CFBundleName) — only check keys that carry at least one
    // translation, since those are the ones a reviewer intended to localize.
    if (Object.keys(localizations).length <= 1) continue;
    for (const locale of REQUIRED_LOCALES) {
      const value = localizations[locale]?.stringUnit?.value;
      if (!value || value.trim() === "") {
        failures.push(`${path}: "${key}" is missing a ${locale} translation`);
      }
    }
  }
}

if (failures.length > 0) {
  console.error(`check-catalog-coverage: ${failures.length} missing translation(s)\n`);
  for (const failure of failures) console.error(`  - ${failure}`);
  process.exit(1);
}
console.log("check-catalog-coverage: every key with translations carries es and vi.");
```

- [ ] **Step 2: Run it against the current repo state**

```bash
node tools/check-catalog-coverage.mjs
```

Expected: PASS (`every key with translations carries es and vi`) — Tasks 3,
19, and 20 must all land their new copy in `es`/`vi` in the same commit as
the `en` source, or this step fails and catches it.

- [ ] **Step 3: Wire into `npm run check`**

Modify `package.json`'s `check` script (find the existing chain, e.g. `"check":
"npm run check:skills && ... "`) — append `&& node tools/check-catalog-coverage.mjs`.

- [ ] **Step 4: Run the full check**

```bash
npm run check
```

Expected: PASS (or, if it fails on something unrelated to this plan, confirm
the failure predates this change before proceeding).

- [ ] **Step 5: Commit**

```bash
git add tools/check-catalog-coverage.mjs package.json
git commit -m "chore(tooling): add check-catalog-coverage guardrail for es/vi String Catalog completeness"
```

---

### Task 17: Settings UI — `ReasoningBackendSettingsView`

**Files:**

- Create: `app/SenseBridge/App/ReasoningBackendSettingsView.swift`
- Modify: `app/SenseBridge/App/SettingsView.swift:181` (insert the new
  section)
- Modify: `app/SenseBridge/Resources/Localizable.xcstrings` (new copy,
  en/es/vi)

**Interfaces:**

- Consumes: `Settings.reasoningBackend`/`cloudProvider`/`localEndpointURL`/
  `reasoningModelOverride` (Task 1), `EndpointURLNormalizer` (Task 5),
  `KeychainCredentialStore` (Task 11), `LiveNetworkComposerFactory` (Task 9,
  for the "test connection" round trip).
- Produces: `ReasoningBackendSettingsView: View` — inserted into
  `SettingsView.swift`.

This is the largest single UI surface in the plan; per the spec it must
cover: backend picker, self-hosted URL + optional token + model fields,
cloud provider + key entry (paste-from-clipboard primary, `SecureField`
fallback, write-only — never re-reads a saved key back into the field),
"Test connection" round trip before enabling, per-provider ToS
acknowledgment (unchecked, re-shown on provider switch), persistent
Remove-key control, per-session request counter, and the interval-floor
notice. Building it as one file matches this file's own justification for
`AwarenessSettingsSection`/`DiagnosticsSettingsSection` being split out —
one section per subsystem, kept out of `SettingsView.swift`'s own body.

- [ ] **Step 1: Implement**

```swift
// app/SenseBridge/App/ReasoningBackendSettingsView.swift
import SenseBridgeCore
import SwiftUI

/// The Cloud/Local/On-Device reasoning backend picker and its consent flow.
/// A separate `View` for the same reason `AwarenessSettingsSection` and
/// `DiagnosticsSettingsSection` are — see either's doc comment.
///
/// Per docs/superpowers/specs/2026-08-11-awareness-ai-tiers-design.md
/// "Consent UX": default off, one-time explicit disclosure before any
/// network backend can be turned on, a real `Toggle` (never a bare tap
/// target) for third-party ToS acknowledgment re-shown on every provider
/// switch, a write-only key field with a paste-from-clipboard primary path
/// (a blind user cannot proofread a `SecureField`), and a persistent
/// Remove-key control since switching away from `.cloud` must not silently
/// discard a saved key.
struct ReasoningBackendSettingsView: View {
    @Binding var reasoningBackend: ReasoningBackend
    @Binding var cloudProvider: CloudProvider?
    @Binding var localEndpointURL: String?
    @Binding var reasoningModelOverride: String?
    /// Clamps `narrationIntervalSeconds` while a network backend is active —
    /// read-only display here; the actual floor is enforced where the value
    /// is used (`AmbientAwarenessSession`/`AwarenessSettingsSection`'s
    /// slider `in:` range), not duplicated here.
    let narrationIntervalSeconds: Double

    private let credentialStore = KeychainCredentialStore()

    @State private var pastedKey = ""
    @State private var hasStoredKey = false
    @State private var tosAcknowledged = false
    @State private var connectionTestResult: String?
    @State private var isTestingConnection = false
    @State private var requestCount = 0 // local-only, reset each app launch — not analytics

    var body: some View {
        Section {
            Picker("Reasoning backend", selection: $reasoningBackend) {
                Text("On-Device").tag(ReasoningBackend.onDevice)
                Text("Local").tag(ReasoningBackend.localEndpoint)
                Text("Cloud").tag(ReasoningBackend.cloud)
            }
            .accessibilityHint("Chooses which backend composes scene descriptions. On-device is free and private.")
            .onChange(of: reasoningBackend) { _, _ in
                tosAcknowledged = false
                connectionTestResult = nil
            }

            switch reasoningBackend {
            case .onDevice:
                EmptyView()
            case .localEndpoint:
                localEndpointFields
                bundledModelDisclosureRow
            case .cloud:
                cloudFields
            }
        } header: {
            Text("Reasoning")
                .foregroundStyle(Color("SecondaryText"))
        } footer: {
            Text(footerText)
                .foregroundStyle(Color("SecondaryText"))
        }
        .task { hasStoredKey = credentialStore.credential(for: currentCredentialKey) != nil }
    }

    // MARK: - Local

    private var localEndpointFields: some View {
        Group {
            TextField(
                "Endpoint URL", text: Binding(get: { localEndpointURL ?? "" }, set: { localEndpointURL = $0 }),
                prompt: Text("http://192.168.1.20:11434")
            )
            .keyboardType(.URL)
            .textInputAutocapitalization(.never)
            .accessibilityHint("""
                Your own self-hosted server's address. Labels leave your device to \
                whatever this address reaches — SenseBridge has no visibility past that point.
                """)
            TextField(
                "Model name", text: Binding(get: { reasoningModelOverride ?? "" }, set: { reasoningModelOverride = $0 }),
                prompt: Text("llama3.2")
            )
            .textInputAutocapitalization(.never)
            .accessibilityHint("Required — your server's model identifier.")
            tosAcknowledgmentToggle(
                label: "I understand this sends labels to the address I entered",
                linkLabel: nil
            )
            testConnectionRow
        }
    }

    private var bundledModelDisclosureRow: some View {
        Label {
            Text("Bundled on-device model — not yet available. Needs a benchmarked model; tracked as a follow-up.")
                .font(.callout)
        } icon: {
            Image(systemName: "info.circle")
                .foregroundStyle(Color("SecondaryText"))
                .accessibilityHidden(true)
        }
        .accessibilityElement(children: .combine)
    }

    // MARK: - Cloud

    private var cloudFields: some View {
        Group {
            Picker("Provider", selection: $cloudProvider) {
                Text("Choose a provider").tag(CloudProvider?.none)
                Text("Anthropic").tag(CloudProvider?.some(.anthropic))
                Text("OpenAI").tag(CloudProvider?.some(.openai))
                Text("NVIDIA NIM").tag(CloudProvider?.some(.nvidiaNIM))
            }
            .onChange(of: cloudProvider) { _, _ in
                tosAcknowledged = false
                connectionTestResult = nil
                hasStoredKey = credentialStore.credential(for: currentCredentialKey) != nil
            }
            if cloudProvider == .nvidiaNIM {
                TextField(
                    "Model name", text: Binding(get: { reasoningModelOverride ?? "" }, set: { reasoningModelOverride = $0 }),
                    prompt: Text("meta/llama-3.1-8b-instruct")
                )
                .accessibilityHint("Required — NVIDIA NIM has no default model.")
            }
            if hasStoredKey {
                HStack {
                    Text("A key is saved")
                    Spacer()
                    Button("Remove", role: .destructive) {
                        credentialStore.removeCredential(for: currentCredentialKey)
                        hasStoredKey = false
                        connectionTestResult = nil
                    }
                }
            } else {
                Button("Paste key from clipboard") {
                    if let clipboardText = UIPasteboard.general.string, !clipboardText.isEmpty {
                        pastedKey = clipboardText
                    }
                }
                .accessibilityHint("Primary way to enter your API key — avoids typing it character by character.")
                SecureField("API key", text: $pastedKey)
                    .accessibilityHint("Fallback if you can't paste. This field never shows a previously saved key.")
                if !pastedKey.isEmpty {
                    Button("Save key") {
                        credentialStore.save(pastedKey, for: currentCredentialKey)
                        pastedKey = ""
                        hasStoredKey = true
                    }
                }
            }
            if let provider = cloudProvider, provider != .nvidiaNIM || hasStoredKey {
                tosAcknowledgmentToggle(
                    label: "I have read and agree to \(providerName(provider))'s terms of service",
                    linkLabel: providerTermsLabel(provider)
                )
            }
            testConnectionRow
            Text("Requests this session: \(requestCount)")
                .font(.caption)
                .foregroundStyle(Color("SecondaryText"))
        }
    }

    // MARK: - Shared

    private func tosAcknowledgmentToggle(label: LocalizedStringKey, linkLabel: String?) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Toggle(isOn: $tosAcknowledged) {
                Text(label)
            }
            .accessibilityHint("Required before this backend can be turned on.")
            if let linkLabel {
                Text(linkLabel)
                    .font(.caption)
                    .foregroundStyle(Color("SecondaryText"))
            }
        }
    }

    private var testConnectionRow: some View {
        Group {
            Button(isTestingConnection ? "Testing…" : "Test connection") {
                Task { await testConnection() }
            }
            .disabled(isTestingConnection || !canTestConnection)
            .accessibilityHint("Sends one real request to confirm this backend works before you rely on it.")
            if let connectionTestResult {
                Text(connectionTestResult)
                    .font(.caption)
                    .foregroundStyle(Color("SecondaryText"))
            }
        }
    }

    private var canTestConnection: Bool {
        switch reasoningBackend {
        case .onDevice: false
        case .localEndpoint: !(localEndpointURL ?? "").isEmpty && !(reasoningModelOverride ?? "").isEmpty
        case .cloud:
            switch cloudProvider {
            case .anthropic, .openai: hasStoredKey
            case .nvidiaNIM: !(reasoningModelOverride ?? "").isEmpty
            case nil: false
            }
        }
    }

    private func testConnection() async {
        isTestingConnection = true
        defer { isTestingConnection = false }
        let session = URLSession(configuration: .ephemeral)
        let factory = LiveNetworkComposerFactory(session: session, requestTimeout: 8, locale: .current)
        let credential = credentialStore.credential(for: currentCredentialKey)
        guard let composer = factory.composer(
            backend: reasoningBackend, provider: cloudProvider, endpointURL: localEndpointURL,
            modelOverride: reasoningModelOverride, credential: credential
        ) else {
            connectionTestResult = "Couldn't build a request — check the fields above."
            return
        }
        do {
            _ = try await composer.compose(from: [
                PerceptionRecord(kind: .detectedObject(label: "chair", confidence: 0.9), capturedAt: .now)
            ])
            requestCount += 1
            connectionTestResult = "Connection works."
        } catch {
            connectionTestResult = "Couldn't connect. Check the address, model, and key, then try again."
        }
    }

    private var currentCredentialKey: CredentialKey {
        switch reasoningBackend {
        case .onDevice: .anthropic // unused; onDevice never reads a credential
        case .localEndpoint: .localEndpoint
        case .cloud:
            switch cloudProvider {
            case .anthropic: .anthropic
            case .openai: .openai
            case .nvidiaNIM: .nvidiaNIM
            case nil: .anthropic
            }
        }
    }

    private func providerName(_ provider: CloudProvider) -> String {
        switch provider {
        case .anthropic: "Anthropic"
        case .openai: "OpenAI"
        case .nvidiaNIM: "NVIDIA"
        }
    }

    private func providerTermsLabel(_ provider: CloudProvider) -> String {
        switch provider {
        case .anthropic: "Anthropic's Consumer Terms of Service, anthropic.com/legal/consumer-terms"
        case .openai: "OpenAI's Terms of Use, openai.com/policies/terms-of-use"
        case .nvidiaNIM: "NVIDIA's API Terms of Use, nvidia.com/en-us/agreements/cloud-services/product-terms"
        }
    }

    private var footerText: LocalizedStringKey {
        switch reasoningBackend {
        case .onDevice:
            "Free, private, and the default. Nothing about your surroundings leaves your device."
        case .localEndpoint:
            """
            Sends recognized labels to a server you control. Off by default. Turn it off any \
            time from this screen. While a network backend is active, the time between hands-free \
            descriptions is held to at least 10 seconds to bound request volume.
            """
        case .cloud:
            """
            Sends recognized labels — never camera images, audio, or your location — to the \
            provider you choose, only after you agree to their terms. Off by default. Turn it \
            off any time from this screen. If it stops responding, SenseBridge continues with \
            on-device descriptions and tells you once. While a network backend is active, the \
            time between hands-free descriptions is held to at least 10 seconds to bound request volume.
            """
        }
    }
}
```

- [ ] **Step 2: Wire into `SettingsView.swift`**

Insert after `AwarenessSettingsSection` (currently lines 98-101) and before
the Output section (currently line 102):

```swift
            ReasoningBackendSettingsView(
                reasoningBackend: binding(\.reasoningBackend),
                cloudProvider: binding(\.cloudProvider),
                localEndpointURL: binding(\.localEndpointURL),
                reasoningModelOverride: binding(\.reasoningModelOverride),
                narrationIntervalSeconds: environment.settings.narrationIntervalSeconds
            )
```

- [ ] **Step 3: Add the new consent/UI copy to `app/SenseBridge/Resources/Localizable.xcstrings`**

Add es/vi entries for every new `LocalizedStringKey`/`Text` literal
introduced above ("Reasoning backend", "On-Device", "Local", "Cloud",
"Endpoint URL", "Model name", "A key is saved", "Remove", "Paste key from
clipboard", "API key", "Save key", "Test connection", "Testing…",
"Requests this session: %@", footer strings, ToS acknowledgment labels,
"Bundled on-device model — not yet available…"), following the exact JSON
shape from Task 3 Step 3. Translate each to `es`/`vi` (native-quality
best-effort — join the existing outstanding P1 native-speaker ES/VI review
item in TODO.md rather than treating this as a separate review task).

- [ ] **Step 4: Run the catalog coverage guardrail from Task 16**

```bash
node tools/check-catalog-coverage.mjs
```

Expected: PASS.

- [ ] **Step 5: Build**

```bash
cd app && xcodebuild build -scheme SenseBridge -destination 'generic/platform=iOS' 2>&1 | tail -40
```

Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 6: Commit**

```bash
git add app/SenseBridge/App/ReasoningBackendSettingsView.swift app/SenseBridge/App/SettingsView.swift \
  app/SenseBridge/Resources/Localizable.xcstrings
git commit -m "feat(settings): add the Cloud/Local/On-Device reasoning backend consent UI"
```

---

### Task 18: ATS / local-network permission for the self-hosted endpoint

**Files:**

- Create: `app/SenseBridge/Resources/InfoPlist-Additions.plist`
- Modify: `app/SenseBridge.xcodeproj/project.pbxproj:505-511,692-698`
- Modify: `app/SenseBridge/Resources/InfoPlist.xcstrings`

**This task's outcome must be device-verified before it's trusted — see
Step 3.** No doc can confirm whether `NSAllowsLocalNetworking` covers a bare
RFC1918 literal (`192.168.1.20`) versus only qualified/`.local` addresses,
or exactly when the local-network permission prompt fires for a direct
`URLSession` connection. Ship the standard, documented approach; verify;
fall back per the spec if it doesn't hold.

- [ ] **Step 1: Add the ATS exception via a merged Info.plist**

`GENERATE_INFOPLIST_FILE = YES` (used throughout this project, confirmed at
`project.pbxproj:505,530,669,692,717,737`) doesn't expose
`NSAppTransportSecurity` through the simple `INFOPLIST_KEY_*` mechanism —
that's Apple's documented curated list of flat keys, and ATS's exceptions
dictionary isn't on it. The supported way to add a nested key while still
using `GENERATE_INFOPLIST_FILE` is `INFOPLIST_FILE` pointing at a small
plist Xcode merges in.

```xml
<!-- app/SenseBridge/Resources/InfoPlist-Additions.plist -->
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>NSAppTransportSecurity</key>
    <dict>
        <!-- Scoped to local networking only — never NSAllowsArbitraryLoads,
             which would disable ATS app-wide. Covers the self-hosted
             reasoning endpoint (Ollama/LM Studio default to plain HTTP).
             See docs/superpowers/specs/2026-08-11-awareness-ai-tiers-design.md
             "Self-hosted endpoint — network-layer specifics" for the
             device-verification requirement and https-only fallback. -->
        <key>NSAllowsLocalNetworking</key>
        <true/>
    </dict>
</dict>
</plist>
```

Modify `app/SenseBridge.xcodeproj/project.pbxproj` — add
`INFOPLIST_FILE = SenseBridge/Resources/InfoPlist-Additions.plist;`
immediately after each `GENERATE_INFOPLIST_FILE = YES;` line in the two
`SenseBridge` app-target build configurations (currently line 505 and line
692 — **not** the other `GENERATE_INFOPLIST_FILE` occurrences at lines 530,
669, 717, 737, which belong to other targets/schemes; confirm by reading the
surrounding `buildSettings` block's `PRODUCT_NAME`/`PRODUCT_BUNDLE_IDENTIFIER`
before editing, since line numbers shift once earlier tasks' file additions
land).

Also add, in the same two blocks, next to the existing
`INFOPLIST_KEY_NSMicrophoneUsageDescription` lines (currently 507/694):

```text
    INFOPLIST_KEY_NSLocalNetworkUsageDescription = "SenseBridge connects to your self-hosted reasoning server, if you set one up. Nothing else on your network is contacted.";
```

- [ ] **Step 2: Add the matching `InfoPlist.xcstrings` entry**

Insert a new key alongside `NSMicrophoneUsageDescription`, matching the
existing shape exactly:

```json
    "NSLocalNetworkUsageDescription": {
      "comment": "Privacy - Local Network Usage Description",
      "localizations": {
        "en": {
          "stringUnit": {
            "state": "translated",
            "value": "SenseBridge connects to your self-hosted reasoning server, if you set one up. Nothing else on your network is contacted."
          }
        },
        "es": {
          "stringUnit": {
            "state": "translated",
            "value": "SenseBridge se conecta a tu servidor de razonamiento autoalojado, si configuraste uno. No se contacta nada más en tu red."
          }
        },
        "vi": {
          "stringUnit": {
            "state": "translated",
            "value": "SenseBridge kết nối với máy chủ suy luận tự lưu trữ của bạn, nếu bạn đã thiết lập một máy chủ. Không có gì khác trên mạng của bạn bị liên hệ."
          }
        }
      }
    },
```

- [ ] **Step 3: Build, then flag the device-only verification**

```bash
cd app && xcodebuild build -scheme SenseBridge -destination 'generic/platform=iOS' 2>&1 | tail -40
```

Expected: `** BUILD SUCCEEDED **` and no ATS-related build warnings about the
merged plist.

**Cannot be verified without a device.** After `npm run app:install` (final
task), manually confirm on Kevin's iPhone: configure the self-hosted
endpoint with a bare LAN IP (e.g. a Mac running `ollama serve` on the same
Wi-Fi), tap "Test connection" in the new Settings screen, and confirm (a)
the local-network permission prompt appears and (b) the connection succeeds
after granting it. **If it fails with an ATS error**, do not reach for
`NSAllowsArbitraryLoads` — instead restrict the self-hosted tier to
`https://` only: change `EndpointURLNormalizer.normalize` (Task 5) to throw
`.invalidScheme` for `http`, update the placeholder/hint text in
`ReasoningBackendSettingsView` (Task 17), and record the outcome in
`TODO.md`.

- [ ] **Step 4: Commit**

```bash
git add app/SenseBridge/Resources/InfoPlist-Additions.plist app/SenseBridge.xcodeproj/project.pbxproj \
  app/SenseBridge/Resources/InfoPlist.xcstrings
git commit -m "feat(app): add local-network ATS exception and usage description for self-hosted reasoning"
```

---

### Task 19: `GAPS.md` + `TODO.md` closure

**Files:**

- Modify: `GAPS.md` (mock-depth entry, around lines 42-49 — confirm exact
  current location before editing, since earlier sessions may have shifted
  it)
- Modify: `TODO.md` (close the 2026-08-04 reasoning-backend item at line 478
  and the 2026-08-11 design item at line ~207, adding a new device-validation
  item per the spec's "What stays explicitly unverified" section)

- [ ] **Step 1: Move the `GAPS.md` mock-depth entry to `## Resolved`**

Find the entry (search for "mock" or "Check once" in `GAPS.md`), move it
into `## Resolved` with a dated evidence note: what was checked (Task 14's
`sampleOnce()` + Task 15's real-reading wiring), not "fixed" — per
`AGENTS.md`'s "what you checked" convention.

- [ ] **Step 2: Close the TODO.md items and add the device-validation follow-up**

Tick the 2026-08-04 "Reasoning backend: on-device tiers + opt-in cloud AI"
item and the 2026-08-11 design item per `TODO.md`'s **Item Completion**
convention: `**Done/Fixed <today's date>**` plus what shipped and how it was
verified (build green, package tests green, which parts are device-only —
list Task 10 Step 4, Task 15 Step 4, and Task 18 Step 3's flagged items
explicitly, don't claim them proven).

Add one new `- [ ] **[P1]** **[Needs owner]**` item covering everything the
spec's "What stays explicitly unverified" section names that a machine
cannot close: `NSAllowsLocalNetworking` behavior, local-network permission
prompt timing, which providers/self-hosted servers honor forced structured
output in practice, real cloud/self-hosted round-trip latency, VoiceOver
*experience* (not just labels) on the new Settings screens, thermal/battery
of hands-free awareness against a network composer.

- [ ] **Step 3: Run the TODO sweep**

```bash
npm run todo:sweep
```

Expected: reports the ticked items moved toward `## Completed`.

- [ ] **Step 4: Commit**

```bash
git add GAPS.md TODO.md
git commit -m "docs: close the reasoning-backend and Check-once TODO items, resolve the mock-depth gap"
```

---

### Task 20: Docs sync — `docs/ARCHITECTURE.md`, `docs/AI-MODELS.md`, `docs/PRIVACY.md`, `docs/SECURITY-MODEL.md`, `docs/PRODUCT.md`, marketing copy

**Files:**

- Modify: `docs/ARCHITECTURE.md` (replace the "Optional Cloud Reasoning
  Adapter" paragraph)
- Modify: `docs/AI-MODELS.md` (add the BYOK provider ledger category)
- Modify: `docs/PRIVACY.md` (extend the crash-reporting-opt-in precedent)
- Modify: `docs/SECURITY-MODEL.md:137` (the on-device-only camera claim)
- Modify: `docs/PRODUCT.md:86` ("100% of MVP features run with no network
  call")
- Modify: `docs/_includes/hero.html:30` ("Nothing leaves the device.")
- Modify: `website/src/paraglide/messages/phone_annotation_2_body.js`
  (source message, all locales it defines — edit the message source, not any
  generated/compiled output)

This task is documentation-only; there is no test to write. Each edit is a
direct, factual correction — replace an absolute "never/100%/nothing"
network claim with the accurate opt-in-exception version, matching how the
Sentry crash-reporting exception is already worded elsewhere in the same
files (search each file for "Sentry" or "crash reporting" to match the
existing precedent's phrasing pattern before writing new prose).

- [ ] **Step 1: `docs/ARCHITECTURE.md`** — replace the "Optional Cloud
  Reasoning Adapter" bullet (in "Component responsibilities") and the
  ASCII-diagram line `Cloud Reasoning Adapter (disabled by default)` with a
  description of the real four-part design: `ReasoningComposerResolver`
  picking On-Device/Local/Cloud from `Settings`, the circuit-breaker
  fallback-disclosure model, and the non-blocking-composition invariant in
  `AmbientAwarenessSession`. Reference this plan's spec file rather than
  re-deriving the whole design inline.

- [ ] **Step 2: `docs/AI-MODELS.md`** — add a new ledger row/category:
  "Anthropic / OpenAI / NVIDIA NIM (BYOK cloud reasoning)" — Third-party
  service, not a bundled model, no license-bundling question applies; note
  the per-provider ToS-acceptance requirement lives in the app's consent UI,
  not in this file's licensing checklist.

- [ ] **Step 3: `docs/PRIVACY.md`** — add a section (matching the existing
  "Crash reporting (opt-in, off by default)" section's structure) covering:
  what leaves the device on the Local/Cloud paths (`.detectedObject` labels
  only — never images, audio, location), when (only after the explicit
  per-provider consent screen), the self-hosted destination being entirely
  the user's own choice, and the Keychain retention/removal policy from
  Task 11.

- [ ] **Step 4: `docs/SECURITY-MODEL.md:137`** — add the network-reasoning
  exception the same way the crash-reporting exception is already stated
  nearby in this file.

- [ ] **Step 5: `docs/PRODUCT.md:86`** — change "100% of MVP features run
  with no network call" to name the exception (opt-in reasoning backends)
  the same way this file already names the opt-in crash-reporting exception
  elsewhere.

- [ ] **Step 6: `docs/_includes/hero.html:30`** and
  `website/src/paraglide/messages/phone_annotation_2_body.js`** — soften
  "Nothing leaves the device"/"nothing is uploaded, nothing leaves your
  hand" to name the opt-in exception, in every locale the message file
  defines. Do not touch any generated/compiled paraglide output — only the
  source message file.

- [ ] **Step 7: Build the website to confirm no compile break**

```bash
cd website && npm run build 2>&1 | tail -30
```

Expected: builds clean.

- [ ] **Step 8: Commit**

```bash
git add docs/ARCHITECTURE.md docs/AI-MODELS.md docs/PRIVACY.md docs/SECURITY-MODEL.md docs/PRODUCT.md \
  docs/_includes/hero.html website/src/paraglide/messages/phone_annotation_2_body.js
git commit -m "docs: sync architecture/privacy/security/product docs and marketing copy with the reasoning tiers"
```

---

### Task 21: Legal draft (not applied) — `legal/SUBPROCESSORS.md`, `legal/PRIVACY_POLICY.md`, `NSCameraUsageDescription`

**Files:**

- Create: `tmp/legal-and-camera-string-draft.md` (scratch, gitignored — for
  Kevin's review, not committed)

**`legal/` is never edited directly per `AGENTS.md` — draft only, explicit
owner approval required before either file changes. The `NSCameraUsageDescription`
wording is App-Store-facing and load-bearing enough to need the same
treatment, per the design review, rather than a mechanical edit.**

- [ ] **Step 1: Write the draft**

```markdown
<!-- tmp/legal-and-camera-string-draft.md -->
# Draft: legal + camera-string updates for the reasoning-tier feature

For Kevin's review before either file is touched — AGENTS.md requires
explicit owner approval for anything under `legal/`, and this session has
none yet.

## `legal/PRIVACY_POLICY.md:34,181`

Current claim (paraphrased): nothing leaves the device without explicit,
revocable consent, and the app has no network dependency for perception or
reasoning.

Proposed addition: name the opt-in Local (self-hosted endpoint) and Cloud
(BYOK: Anthropic, OpenAI, NVIDIA NIM) reasoning backends as the second
sanctioned exception alongside crash reporting — off by default, only
recognized object labels (never images, audio, or location) leave the
device, only after an explicit per-provider consent screen naming the
destination, reversible at any time from Settings.

## `legal/SUBPROCESSORS.md`

Current claim: nobody receives camera frames, photos, recognized text,
audio, depth data, or location; no path in the software allows it.

Proposed addition: when the user opts into a Cloud backend, the selected
provider (Anthropic / OpenAI / NVIDIA) receives recognized object labels
only, under that provider's own terms — the user, not SenseBridge, is the
data controller for that path (BYOK: the user's own account and key). The
self-hosted Local path sends the same limited data to a destination the
user themselves configured; SenseBridge has no relationship with it at all.

## `NSCameraUsageDescription` (`project.pbxproj:506,693`,
`app/SenseBridge/Resources/InfoPlist.xcstrings`)

Current (en): "SenseBridge uses the camera to read text and describe scenes
for you. Nothing leaves your device."

This string is unaffected by the camera pipeline itself — perception still
never leaves the device. The claim only needs revisiting if Kevin wants the
App Store-facing copy to preemptively acknowledge the opt-in reasoning
exception; recommend leaving it as-is, since the sentence is scoped to what
the *camera* does, and the network exception is reasoning over
already-extracted labels, not camera data. Flagging rather than deciding
unilaterally, since the design review specifically called this
"load-bearing enough to need explicit sign-off on new wording."
```

- [ ] **Step 2: Do not commit this file to the app's tracked history** — it
lives in `tmp/`, which is gitignored per `AGENTS.md`'s "project state stays
in the project" convention; surface it to Kevin directly (session log entry
- a direct mention) rather than via a commit.

- [ ] **Step 3: No commit step for this task** — nothing under `legal/`
changes until Kevin reviews the draft and explicitly approves specific
wording.

---

### Task 22: Full build, package tests, e2e floor, device install

**Files:** none new — this is the plan's verification gate.

- [ ] **Step 1: Full package test suite**

```bash
cd app/Packages/SenseBridgeCore && swift test 2>&1 | tail -60
```

Expected: all suites PASS, including every new one from Tasks 1-9.

- [ ] **Step 2: Catalog-dependent tests under `xcodebuild`**

Run from `app/Packages/SenseBridgeCore`, not `app/` — see Task 3's note and
`TODO.md`'s 2026-08-11 entry on the missing `SenseBridgeCore.xcscheme` Test
action; this also matches `.github/workflows/ci.yml`'s own working directory.

```bash
cd app/Packages/SenseBridgeCore && xcodebuild test -scheme SenseBridgeCore -destination 'platform=macOS' 2>&1 | tail -60
```

Expected: PASS — confirms `Phrasing`/`ReasoningOutputValidator`'s catalog
lookups resolve through the compiled bundle, not just the raw-JSON fallback.

- [ ] **Step 3: Full app build for device**

```bash
cd app && xcodebuild build -scheme SenseBridge -destination 'generic/platform=iOS' 2>&1 | tail -60
```

Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 4: App-level and UI tests**

```bash
cd app && xcodebuild test -scheme SenseBridge -destination 'platform=iOS Simulator,name=iPhone 17 Pro' 2>&1 | tail -80
```

Expected: PASS, including the existing accessibility/VoiceOver-label XCUITest
audit — confirms no unlabeled element was introduced by
`ReasoningBackendSettingsView` or the "Check once" changes (`AGENTS.md`'s
zero-unlabeled-elements hard gate).

- [ ] **Step 5: `npm run check`**

```bash
npm run check
```

Expected: PASS, including Task 16's new catalog-coverage guardrail.

- [ ] **Step 6: Install to Kevin's device — required, unprompted, per this
repo's `CLAUDE.md`**

```bash
npm run app:install
```

Expected: installs successfully. If the phone is locked, say so plainly
rather than reporting a bare failure — the developer disk image won't mount
otherwise.

- [ ] **Step 7: Manual device smoke checklist** (cannot be scripted — say so,
don't skip silently)

- Awareness screen, handheld: wave the phone around a room, confirm the
  preview/outlines track normally (no code change was needed here, but this
  is the first real confirmation).
- Awareness screen, "Check once": near object → alert; open area → nothing
  recognized; cover the camera → "couldn't take a measurement" within ~3s.
- Settings → Reasoning: configure a self-hosted endpoint against a real
  Ollama instance on the LAN (see Task 18 Step 3's specific check), then a
  real Anthropic key; "Test connection" succeeds for both.
- Force a cloud failure (revoke the key mid-session, or turn off Wi-Fi):
  confirm the once-only fallback announcement, then confirm it doesn't
  repeat, then confirm recovery is announced once when connectivity returns.
- VoiceOver pass on the new Settings screens, especially the paste-key +
  test-connection flow.

- [ ] **Step 8: No commit** — this task is verification only.

---

### Task 23: Reviewer sign-off

**Files:** none — this task dispatches review agents and applies their
findings, then reports.

- [ ] **Step 1: Dispatch `safety-framing-reviewer`**, scoped to every file
this plan touched that produces or gates spoken/haptic output: `Phrasing.swift`,
`ReasoningOutputValidator.swift`, `AnthropicSceneComposer.swift`,
`OpenAICompatibleSceneComposer.swift`, `ReasoningComposerResolver.swift`,
`AmbientAwarenessSession.swift`, `ObstacleAwarenessView.swift`,
`FoundationModelsSceneComposer.swift`. This is the highest-severity review
surface per `AGENTS.md` — do not skip it because the composition moved
off-device.

- [ ] **Step 2: Dispatch `security-reviewer`**, scoped to
`KeychainCredentialStore.swift`, `EndpointURLNormalizer.swift`, the two
network composer files, and `ReasoningBackendSettingsView.swift` (the
write-only key UI, the paste/test-connection flow).

- [ ] **Step 3: Dispatch `accessibility-reviewer`**, scoped to
`ReasoningBackendSettingsView.swift` and the changed sections of
`ObstacleAwarenessView.swift`.

- [ ] **Step 4: Apply any blocking findings from all three**, re-run the
relevant task's tests, and commit the fixes as new commits (never amend a
task's original commit — this repo's git conventions require a new commit
per fix).

- [ ] **Step 5: Report to Kevin** what each reviewer found, what was fixed,
and what (if anything) is a judgment call for him — per this plan's
Global Constraints and `AGENTS.md`'s quality gates, a green pipeline must
never imply device/human validation it did not do.
