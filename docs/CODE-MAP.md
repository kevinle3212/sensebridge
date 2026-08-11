---
title: Code Map and Contributing
---

# Code Map and Contributing

What lives in which directory, where to look for a given kind of change,
the dependency rule that keeps the codebase testable, and how to get a
change reviewed and merged.

## The code map

51 Swift files across three areas, verified by walking the tree directly.

### `app/Packages/SenseBridgeCore/` — the device-agnostic package

A SwiftPM package (`swift-tools-version: 6.2`, `.iOS(.v26)` / `.macOS(.v15)`)
holding every piece of reasoning, output, sensing-protocol, perception, and
storage logic that doesn't need the app target or a simulator to test. This
is the seam the project's testability rests on: `swift test`/`xcodebuild
test` runs the whole reasoning core headless, off-device.

- **`Sources/SenseBridgeCore/Sensing/`** — `SensingSource` (the protocol),
  `CameraSource` (the one concrete implementation — an actor wrapping
  `AVCaptureSession`, lens/zoom/torch control, and rotation tracking),
  `CameraLens`, `CameraConfiguration` (pure lens/zoom math, testable without
  hardware), `CameraDeviceResolution`, `PhotoCaptureDelegate`,
  `AmbientSensingSource` (ARKit `sceneDepth` for hands-free awareness — iOS
  only, and deliberately *not* a `SensingSource`: it is pull-based, because a
  60 fps push stream feeding a consumer that wants two frames a second exists
  only to be discarded), `MicrophoneSensingSource` (one-shot `AVAudioEngine`
  capture as WAV `Data` for Sound Alerts — not a continuous stream, and not
  `SensingSource`-conformant for the same reason `AmbientSensingSource`
  isn't: its shape doesn't fit that protocol's streaming contract).
- **`Sources/SenseBridgeCore/Perception/`** — `PerceptionService` (the
  protocol), `PerceptionRecord` (the structured-fact type that crosses into
  Reasoning), `OCRService` (Vision-based OCR),
  `ObjectClassificationService` (Vision image classification — OS-bundled, so
  there is no model to license), `DepthStatistics` (pure percentile reduction
  of a depth frame, plus ground-plane rejection, testable with no LiDAR
  attached), `DepthGeometry` (pure projection of a depth sample onto gravity,
  so "is this the floor" is measured from `ARCamera.transform` rather than
  guessed from a fixed rectangle), `SoundService` (protocol),
  `SoundClassificationRunner` (shared `SNClassifySoundRequest`/
  `SNAudioFileAnalyzer` plumbing — `public` so the App-layer
  `CustomSoundClassifier` can use it too, not just this package's own
  `BuiltInSoundClassifier`), `BuiltInSoundClassifier` (Apple's on-device
  sound taxonomy, curated to a fixed class allowlist),
  `CombinedSoundClassifier` (runs two `SoundService`s concurrently, keeps the
  higher-confidence hit).
- **`Sources/SenseBridgeCore/Reasoning/`** — `SceneComposer` (protocol +
  `LabelListSceneComposer` fallback), `AwarenessEngine` (depth-threshold
  hysteresis, reporting alert/clear *transitions*), `NarrationThrottle`
  (suppresses repeated narration on a continuously-worn channel while letting
  transitions through), `Phrasing` (hedging — the enforcement point for
  awareness-not-safety), `OutputProfile`, `AppLanguage`,
  `LocalizedCatalog` (String Catalog lookup that works under both Xcode and
  bare SwiftPM).
- **`Sources/SenseBridgeCore/Output/`** — `RenderTarget` (protocol plus
  `OutputMessage`/`OutputSignal`), `SpeechRenderTarget`, `HapticRenderTarget`
  plus `HapticPattern`, `MultiRenderTarget` (fan-out per `OutputProfile`).
- **`Sources/SenseBridgeCore/Storage/`** — `Settings` (the persisted user
  preferences struct), `SettingsStore` (protocol) +
  `UserDefaultsSettingsStore` (the one implementation).
- **`Sources/SenseBridgeCore/CloudOptional/`** — `CloudReasoningAdapter`
  (protocol only; opt-in, disabled by default, no shipping implementation
  yet).
- **`Sources/SenseBridgeCore/Resources/`** — `Localizable.xcstrings`, the
  package's String Catalog (en/es/vi).
- **`Tests/SenseBridgeCoreTests/`** — mirrors the source layout; one test
  file per major type above.

A change here implies: it's testable without Xcode/a simulator, it must stay
free of `UIKit`/`SwiftUI`/App-layer imports (platform-conditional
`#if os(iOS)` blocks for `AVFoundation`/`CoreHaptics` are the accepted
exception, isolated to the actor that needs them), and it changes a
contract every consumer above it depends on.

### `app/SenseBridge/` — the app target

- **`App/`** — `SenseBridgeApp.swift` (entry point), `AppEnvironment.swift`
  (the root `@MainActor` DI container), `CameraController.swift`
  (`@Observable` bridge over the one shared `CameraSource`),
  `HomeView.swift` (the flat, VoiceOver-first main screen),
  `SettingsView.swift`.
- **`Accessibility/`** — `VoiceOverAnnouncement.swift`
  (`announceToVoiceOver`/`announceIfUnspoken`, the deliberate-focus-management
  entry point).
- **`Features/Camera/`** — `CameraPreviewView.swift`,
  `CameraControlsView.swift` (lens/zoom/torch controls), shared by every
  capture feature.
- **`Features/Reading/`** — `ReadingView.swift`: captures a photo and reads
  aloud recognized text. Real end-to-end perception path
  (`CameraSource` → `OCRService` → `Phrasing`).
- **`Features/Labeling/`** — `LabelingView.swift`: captures a photo and
  identifies the main object via `CameraSource` →
  `ObjectClassificationService.process(_:)` → `Phrasing`. Real end-to-end,
  matching `ReadingView`'s shape.
- **`Features/SceneDescription/`** — `SceneDescriptionView.swift`: captures a
  photo, runs `ObjectClassificationService.detect(_:)`, and composes a scene
  description via `FoundationModelsSceneComposer.swift` — the real
  `SceneComposer`, backed by `SystemLanguageModel`; it lives in the App layer
  because `SenseBridgeCore` deliberately does not depend on Foundation Models,
  and it falls back to `LabelListSceneComposer` whenever the model is
  unavailable. **The model returns a noun phrase, never a sentence** — the
  hedge is applied afterwards by `Phrasing`, so it cannot be lost to a model
  change.
- **`Features/ObstacleAwareness/`** — two modes on one screen.
  `AmbientAwarenessSession.swift` is the **hands-free** pipeline: a continuous
  loop over `AmbientSensingSource` (ARKit LiDAR) →
  `ObjectClassificationService` / `DepthStatistics` →
  `FoundationModelsSceneComposer` / `AwarenessEngine` → `MultiRenderTarget`,
  for a phone worn on the body with headphones in. It is the only loop in the
  app; every other feature is one capture per tap. `ObstacleAwarenessView.swift`
  hosts it, and still offers the original **one-reading** check, which feeds
  mock depth through the same `AwarenessEngine` + `Phrasing` + `RenderTarget`.
- **`Features/SoundAlerts/`** — `SoundAlertsView.swift`: one tap records a
  few seconds of audio via `MicrophoneSensingSource.record(duration:)`, run
  through `CombinedSoundClassifier` (`BuiltInSoundClassifier`'s Apple
  taxonomy + `CustomSoundClassifier`'s bundled Create ML model, whichever
  produces the higher-confidence hit), then `Phrasing`. Real end-to-end, the
  same one-capture-per-tap shape as every other feature except hands-free
  awareness — see `docs/ARCHITECTURE.md`'s "Sound Alerts data flow".
  `CustomSoundClassifier.swift` lives in the App layer, not the package, for
  the same `SenseBridgeCore`-can't-depend-on-it reason as
  `FoundationModelsSceneComposer` — its bundled `.mlmodel`'s Xcode-generated
  Swift wrapper only exists in the App target's compiled output.
- **`Features/Onboarding/`** — `OnboardingView.swift`: first-run walkthrough
  (welcome → camera/mic permission priming → crash-reporting opt-in, reusing
  `DiagnosticsSettingsSection` rather than duplicating its copy), gated by
  `Settings.hasCompletedOnboarding` and replayable from Settings.
- **`Resources/`** — `InfoPlist.xcstrings` (permission usage descriptions),
  `SenseBridgeSoundClassifier.mlmodel` (bundled Create ML sound classifier —
  see `models/sound-classifier/README.md`).

A change here implies: it's SwiftUI/UIKit-facing, it needs a VoiceOver pass
if it touches UI, and it should route through `AppEnvironment.output`
(`MultiRenderTarget`) rather than constructing its own render target.

### Tests and the Xcode project

- **`app/SenseBridgeTests/`** — app-target unit tests (`AppEnvironmentTests.swift`).
- **`app/SenseBridgeUITests/`** — `XCUITest` end-to-end tests
  (`SenseBridgeUITests.swift`, `LanguageSelectionUITests.swift`).
- **`app/SenseBridge.xcodeproj`** — the Xcode project that builds the app
  target and links `SenseBridgeCore` as a local package dependency.

## "I want to change X, where do I look"

| Intent | Directory | Protocol seam involved |
| --- | --- | --- |
| Add a new sensor (e.g. LiDAR depth, microphone) | `SenseBridgeCore/Sources/SenseBridgeCore/Sensing/` | Conform to `SensingSource` |
| Add a new output channel (e.g. captions) | `SenseBridgeCore/Sources/SenseBridgeCore/Output/` | Conform to `RenderTarget`; register it in `AppEnvironment.renderTargets` |
| Change what the app says | `SenseBridgeCore/Sources/SenseBridgeCore/Reasoning/Phrasing.swift` (hedge templates) and `Localizable.xcstrings` (translations) | None — `Phrasing` is the single enforcement point; do not compose prose at a call site |
| Add a screen | `app/SenseBridge/Features/<Feature>/` | Render results through `environment.output` (`MultiRenderTarget`), never a standalone `RenderTarget` |
| Add a setting | `SenseBridgeCore/Sources/SenseBridgeCore/Storage/Settings.swift` (add the field, extend the custom `Decodable` init with a default for back-compat) and `app/SenseBridge/App/SettingsView.swift` | `SettingsStore` |
| Add a test | Mirror the source file's location under the matching `Tests/` directory | Swift Testing (`import Testing`) for unit/integration; `XCUITest` for e2e — see [`docs/TESTING.md`](TESTING.md) |

## The dependency rule

Dependencies point inward: the App layer depends on `SenseBridgeCore`, never
the reverse. Within `SenseBridgeCore`, Reasoning stays pure and
framework-independent — it depends on `PerceptionRecord` values, never on
`AVFoundation`, `Vision`, `CoreHaptics`, or any capture/render framework
directly. A framework-specific implementation (an actor wrapping
`AVSpeechSynthesizer`, say) sits at the edge, behind the protocol the rest
of the pipeline depends on. See
[`docs/ARCHITECTURE.md`](ARCHITECTURE.md) for the full pipeline diagram and
the
[api-design](https://github.com/kevinle3212/sensebridge/blob/main/.agents/skills/api-design/SKILL.md)
skill for the reasoning behind it.

## How to contribute

Full walkthrough:
[`CONTRIBUTING.md`](https://github.com/kevinle3212/sensebridge/blob/main/CONTRIBUTING.md)
and
[`CODE_OF_CONDUCT.md`](https://github.com/kevinle3212/sensebridge/blob/main/CODE_OF_CONDUCT.md)
at the repository root. In short: branch as `feat/...`, `fix/...`, or
`chore/...`; conventional commit headers (`type(scope): subject`); open a
PR so CI runs — see [`docs/CI-CD.md`](CI-CD.md) for every gate a PR has to
clear.

**Which review is mandatory for which kind of change**, via the personas
under
[`.agents/agents/`](https://github.com/kevinle3212/sensebridge/tree/main/.agents/agents):

- **Any physical-world output** (spoken text, alerts, captions, haptics) —
  the
  [safety-framing-reviewer](https://github.com/kevinle3212/sensebridge/blob/main/.agents/agents/safety-framing-reviewer.md).
  This is the highest-severity review surface in the project.
- **Any UI change** — the
  [accessibility-reviewer](https://github.com/kevinle3212/sensebridge/blob/main/.agents/agents/accessibility-reviewer.md)
  (VoiceOver/Dynamic Type/focus/traits) and, for structure and HIG
  conformance, the
  [ui-reviewer](https://github.com/kevinle3212/sensebridge/blob/main/.agents/agents/ui-reviewer.md) —
  accessibility wins any conflict between the two.
- **Any new dependency or bundled model** — the
  [dependency-auditor](https://github.com/kevinle3212/sensebridge/blob/main/.agents/agents/dependency-auditor.md),
  which also gates model licensing.
- **Any Swift code change** — the
  [swift-reviewer](https://github.com/kevinle3212/sensebridge/blob/main/.agents/agents/swift-reviewer.md)
  for language-level correctness and concurrency; it reviews the language,
  never overrides the doctrinal reviewers above.
- **Camera, storage, or supply-chain-adjacent changes** — the
  [security-reviewer](https://github.com/kevinle3212/sensebridge/blob/main/.agents/agents/security-reviewer.md).
  See also [`docs/SECURITY-MODEL.md`](SECURITY-MODEL.md).

## Which reviews a machine can run, and which need a human or a device

Static/automated review (a machine, in CI or as an agent persona) can check:
code correctness, concurrency safety, whether spoken strings are hedged
per-pattern, whether every UI element has a label/hint/trait, dependency
licenses, and known-CVE dependency scanning.

**None of that substitutes for the two things that actually validate this
product:**

- **On-device latency, battery, and thermal behavior** — requires
  Instruments profiling on a real iPhone, not a simulator.
- **A blind person using a feature eyes-free and finding it useful** — no
  amount of green CI or automated accessibility scanning substitutes for
  this. See [`docs/TESTING.md`](TESTING.md#the-one-sentence-that-matters-most).

State plainly, in every PR or review, which of these a machine actually
verified and which still need device and human validation — never let a
green pipeline imply the app was validated by the people it's for.

---

Need help? See [`SUPPORT.md`](https://github.com/kevinle3212/sensebridge/blob/main/SUPPORT.md).
