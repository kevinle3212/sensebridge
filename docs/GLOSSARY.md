---
title: Glossary and Reading Paths
---

# Glossary and Reading Paths

Two things live here: ordered routes through this documentation for four
kinds of reader, and an alphabetized glossary of the project's vocabulary.

## Reading paths

Each path is ordered — read top to bottom the first time through.

### Curious user

You want to know what SenseBridge is and whether it can help you, without
reading engineering detail.

1. [Product](PRODUCT.md) — the mission, who the MVP is for, and the wedge.
2. [FAQ](FAQ.md) — the questions people actually ask.
3. [Safety framing](SAFETY-FRAMING.md) — read this before assuming what the
   app can do: it is an awareness aid, never a safety or navigation device.
4. [Roadmap](ROADMAP.md) — what's built, what's deferred, and when.

### New contributor

You want to get a change merged.

1. [Code map](CODE-MAP.md) — what lives in which directory and how to
   contribute.
2. [Environment](ENVIRONMENT.md) — toolchain and local setup before you open
   the Xcode project.
3. [Architecture](ARCHITECTURE.md) — the `SensingSource` → Perception →
   Reasoning → `RenderTarget` pipeline your change fits into.
4. [Testing strategy](TESTING.md) — what test coverage your change needs
   before it merges.
5. [CI/CD and release engineering](CI-CD.md) — the gates your PR has to
   clear.

### Reviewer / auditor

You're evaluating the project's engineering or security posture.

1. [Security model](SECURITY-MODEL.md) — trust boundaries, threat model,
   supply chain, and the permission surface.
2. [Privacy](PRIVACY.md) — the on-device guarantee and what happens to user
   content.
3. [AI models](AI-MODELS.md) — model choices and the license ledger; AGPL
   and Apple's `apple-amlr` are hard blockers.
4. [CI/CD and release engineering](CI-CD.md) — what CI actually verifies,
   and the honest account of what it cannot prove.
5. [Testing strategy](TESTING.md) — coverage philosophy and the e2e floor.

### Accessibility specialist

You're evaluating whether this app is actually usable eyes-free.

1. [Safety framing](SAFETY-FRAMING.md) — the doctrine that governs every
   spoken, captioned, and haptic string, read first because it constrains
   everything else.
2. [Accessibility standards](ACCESSIBILITY.md) — the VoiceOver, Dynamic
   Type, and labeling standard every screen is held to.
3. [Product](PRODUCT.md) — who the MVP is for and what "done" means for
   this audience.
4. [Quick start](QUICK-START.md) — the living usage guide for what each
   feature does today, if you want to try it on your own device.

## Glossary

**Accessibility label vs. hint vs. trait** — three distinct pieces of
VoiceOver metadata a control carries: the **label** names it ("Read
document," never "button"), the **hint** explains a non-obvious action and
is used sparingly, and the **trait** tells the rotor what kind of element it
is (button, header, and so on) so rotor navigation works. See
[`docs/ACCESSIBILITY.md`](ACCESSIBILITY.md).

**AppEnvironment** — the app's root `@MainActor` dependency container,
injected once at launch. Owns the persisted `Settings`, the shared
`CameraController`, and the shared `SpeechRenderTarget`/`HapticRenderTarget`
instances every feature renders through. Defined in
`app/SenseBridge/App/AppEnvironment.swift`.

**ARKit depth / LiDAR** — the depth-sensing input for obstacle awareness,
named in [`docs/ARCHITECTURE.md`](ARCHITECTURE.md) as a `SensingSource` and
implemented by `AmbientSensingSource` (compiled only where
`canImport(ARKit) && os(iOS)` holds). Frames reduce through the pure
`DepthGeometry`/`DepthStatistics` helpers, which are deliberately free of
ARKit so the arithmetic is testable without a LiDAR device attached. The
continuous path in `AmbientAwarenessSession` is live; the one-shot "check
once" button in `ObstacleAwarenessView` still evaluates an alternating
hard-coded depth value — see [`GAPS.md`](../GAPS.md) → "Application".

**Awareness-not-safety** — the project's highest-priority doctrine:
SenseBridge raises awareness of the environment and never claims to be a
mobility- or navigation-safety device. See
[`docs/SAFETY-FRAMING.md`](SAFETY-FRAMING.md).

**AwarenessEngine** — a pure `Sendable` struct that turns a stream of depth
readings into an alert/clear boolean, with hysteresis (separate alert and
clear thresholds) so the signal doesn't flap near the boundary. Defined in
`app/Packages/SenseBridgeCore/Sources/SenseBridgeCore/Reasoning/AwarenessEngine.swift`.

**The blind, deaf, and deaf-blind output profiles** — `OutputProfile`'s
three cases, each selecting which `RenderChannel`s (`speech`, `caption`,
`haptic`) a user's output should go through: `.blind` prefers speech,
`.deaf` prefers captions, `.deafBlind` prefers haptics. All three channels
now have a registered target, so all three profiles are selectable — but
availability is still derived from what is actually registered rather than a
hardcoded list (see `AppEnvironment.selectableProfiles`), so a channel added
without a target names itself instead of failing silently.

**Dynamic Type** — Apple's user-controlled text-size system. SenseBridge
never hardcodes font sizes so text scales with the user's chosen size,
including accessibility sizes. See
[`docs/ACCESSIBILITY.md`](ACCESSIBILITY.md).

**Foundation Models** — Apple's on-device large language model framework
(`SystemLanguageModel`, `LanguageModelSession`), the planned reasoning
engine for scene composition via guided generation. Documented in
[`docs/AI-MODELS.md`](AI-MODELS.md) and
[`docs/ARCHITECTURE.md`](ARCHITECTURE.md); not yet wired into the app —
`SceneComposer`'s Foundation-Models-backed implementation is described in
`SceneComposer.swift`'s doc comment as living at the App layer, but the only
concrete implementation in the codebase today is the fallback,
`LabelListSceneComposer`.

**Guided generation / `@Generable`** — the Foundation Models mechanism for
composing a hedged sentence into a typed Swift struct rather than free-form
text. Documented in [`docs/ARCHITECTURE.md`](ARCHITECTURE.md#on-device-ai-pipeline);
no `@Generable` type exists in the codebase yet.

**HapticPattern** — a pure, engine-free description of a haptic cue (a
sequence of `HapticEvent`s), testable off-device without `CHHapticEngine`.
Each `OutputSignal` maps to one fixed, memorable rhythm — a small set of
awareness cues, explicitly not a haptic vocabulary. Defined in
`app/Packages/SenseBridgeCore/Sources/SenseBridgeCore/Output/HapticPattern.swift`.

**HapticRenderTarget** — the `RenderTarget` actor that plays `HapticPattern`
cues via `CHHapticEngine` where supported and `UIFeedbackGenerator`
otherwise, honoring a user-set intensity multiplier. Defined in
`app/Packages/SenseBridgeCore/Sources/SenseBridgeCore/Output/HapticRenderTarget.swift`.

**Hedging** — the requirement that every spoken/caption/haptic string
qualify its certainty ("looks like," "possible," "might be") rather than
assert a fact the underlying model didn't earn. Enforced centrally by
`Phrasing`. See [`docs/SAFETY-FRAMING.md`](SAFETY-FRAMING.md).

**MultiRenderTarget** — fans one `OutputMessage` out to every `RenderTarget`
an `OutputProfile` prefers, concurrently. Its `unsupportedChannels` property
reports which of a profile's preferred channels have no registered target,
so the app can refuse to silently degrade a profile to nothing. Defined in
`app/Packages/SenseBridgeCore/Sources/SenseBridgeCore/Output/MultiRenderTarget.swift`.

**On-device** — perception and reasoning run on the phone; nothing about
the user's surroundings leaves the device without explicit, revocable
consent. See [`docs/PRIVACY.md`](PRIVACY.md).

**OutputMessage** — the value delivered to a `RenderTarget`: hedged prose
(`text`) paired with the semantic meaning behind it (`signal`), so a
haptic-only channel has something to react to when there's no prose to
speak. Defined in
`app/Packages/SenseBridgeCore/Sources/SenseBridgeCore/Output/RenderTarget.swift`.

**OutputProfile** — which senses a user relies on (`blind`, `deaf`,
`deafBlind`), selecting which `RenderChannel`s Reasoning output should be
delivered through. Defined in
`app/Packages/SenseBridgeCore/Sources/SenseBridgeCore/Reasoning/OutputProfile.swift`.

**OutputSignal** — the semantic meaning behind an `OutputMessage`,
independent of its prose: `captureTaken`, `resultReady`, `nothingFound`,
`error`, `awarenessAlert`, `awarenessClear`. What a haptic-only channel
actually reacts to. Defined alongside `OutputMessage` in `RenderTarget.swift`.

**PerceptionRecord** — the structured-fact boundary type between Perception
and Reasoning: recognized text, a detected object/sound with confidence, or
a depth reading. Reasoning only ever sees these, never raw pixels, audio, or
depth buffers. Defined in
`app/Packages/SenseBridgeCore/Sources/SenseBridgeCore/Perception/PerceptionRecord.swift`.

**Phrasing** — the single type that composes hedged natural-language output
from a raw detection and confidence bucket (`Certainty`). The enforcement
point for the awareness-not-safety doctrine: every phrase it produces
carries a hedge regardless of how confident the underlying detector was.
Defined in
`app/Packages/SenseBridgeCore/Sources/SenseBridgeCore/Reasoning/Phrasing.swift`.

**RenderTarget** — the protocol every output channel conforms to: delivers
an `OutputMessage` through one sense. Speech, caption, and haptic targets are
all implemented — the caption one lives in the app layer
(`app/SenseBridge/App/CaptionRenderTarget.swift`) because it owns SwiftUI
state. Defined in
`app/Packages/SenseBridgeCore/Sources/SenseBridgeCore/Output/RenderTarget.swift`.

**Rotor** — VoiceOver's mechanism for jumping between elements of a kind
(headings, links, and so on), which depends on controls carrying correct
accessibility traits. See [`docs/ACCESSIBILITY.md`](ACCESSIBILITY.md).

**SceneComposer** — the protocol for composing a hedged natural-language
scene description from `PerceptionRecord`s. `LabelListSceneComposer`, the
only implementation in the codebase today, is an explicit fallback that
reads back perceived labels directly rather than a Foundation-Models-composed
sentence. Defined in
`app/Packages/SenseBridgeCore/Sources/SenseBridgeCore/Reasoning/SceneComposer.swift`.

**SenseBridgeCore** — the SwiftPM package holding all device-agnostic
reasoning, output, sensing-protocol, perception, and storage code, so it is
testable via `swift test`/`xcodebuild test` off-device, without the app
target or a simulator. See `app/Packages/SenseBridgeCore/Package.swift` and
[`docs/CODE-MAP.md`](CODE-MAP.md).

**SensingSource** — the protocol for a hardware or virtual source of raw
sensor data (camera frame, depth map, audio buffer). `CameraSource` is the
one concrete implementation today. Defined in
`app/Packages/SenseBridgeCore/Sources/SenseBridgeCore/Sensing/SensingSource.swift`.

**Sound Analysis** — Apple's on-device sound-classification framework, and
the perception source for sound alerts. One tap in `SoundAlertsView` records a
few seconds through `MicrophoneSensingSource.record(duration:)`, then
`CombinedSoundClassifier` runs `CustomSoundClassifier` (the bundled in-house
Create ML model) and `BuiltInSoundClassifier` (Apple's taxonomy) concurrently
on that one capture and keeps the single highest-confidence hit — deliberately
not a primary/fallback ordering, since the two models are independently
trained. Both reach the framework through the shared
`SoundClassificationRunner` enum.

**SpeechRenderTarget** — the `RenderTarget` actor that speaks a message via
`AVSpeechSynthesizer`, configuring the shared audio session so speech isn't
silenced by the hardware mute switch. Defined in
`app/Packages/SenseBridgeCore/Sources/SenseBridgeCore/Output/SpeechRenderTarget.swift`.

**Apple Vision** — Apple's on-device computer-vision framework. `OCRService`
uses `VNRecognizeTextRequest` for the Reading feature;
`ObjectClassificationService` covers the Identify and Describe features
(whole-frame classification plus region-based detection, where objectness
saliency proposes regions and each is classified on its own), feeding
`LabelingView` and `SceneDescriptionView`. See
`app/Packages/SenseBridgeCore/Sources/SenseBridgeCore/Perception/OCRService.swift`
and `.../Perception/ObjectClassificationService.swift`.

**Two-stage scene pipeline** — Vision extracts structured labels/text from
an image, then a `SceneComposer` composes a hedged sentence from those
labels — never from the raw image itself. Described in
[`docs/ARCHITECTURE.md`](ARCHITECTURE.md#on-device-ai-pipeline).

**VoiceOver** — Apple's built-in screen reader and the primary way blind
users operate SenseBridge; the app is built VoiceOver-first, not
VoiceOver-compatible. See [`docs/ACCESSIBILITY.md`](ACCESSIBILITY.md).

---

Need help? See [`SUPPORT.md`](https://github.com/kevinle3212/sensebridge/blob/main/SUPPORT.md).
