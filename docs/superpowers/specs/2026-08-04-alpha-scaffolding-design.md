# Alpha-scaffolding design

Status: approved 2026-08-04. Source session:
[`sessions/2026-08-04/1600-PST.md`](../../../sessions/2026-08-04/1600-PST.md).

## Goal

Close the gaps between the current `app/` build and an alpha a tester could
actually use, per the owner's scoping interview. Four independent
workstreams, decided by owner interview on 2026-08-04:

1. Wire Scene Description and Identify to the real Vision/Apple Intelligence
   services that already exist and are already tested.
2. Build Sound Alerts from scratch — a real Phase 2 roadmap item with no
   code behind it yet.
3. Add a first-run onboarding/permission-priming flow.
4. Cross-cutting docs sync and quality gates that make the above
   alpha-ready rather than merely building.

## Current-state findings (why this scope, not more or less)

- **Already real, wired, on-device:** Reading (Camera → Vision OCR →
  Speech) and Obstacle Awareness (Camera+LiDAR → depth/haptic — the most
  mature feature in the app).
- **Services exist and are tested; the view ignores them and shows canned
  output instead:** Scene Description
  (`ObjectClassificationService.detect()` + a real, tested
  `FoundationModelsSceneComposer` both exist; `SceneDescriptionView`
  hardcodes two fake `PerceptionRecord`s) and Identify
  (`ObjectClassificationService.process()` exists; `LabelingView` hardcodes
  "a coffee mug"). Both stubs carry `ponytail:` comments naming exactly
  this gap.
- **Not built at all:** Sound Alerts has no `SoundService` and no
  microphone `SensingSource`. `PerceptionRecord.Kind
  .detectedSound(label:confidence:)` already exists, unused — the seam was
  anticipated but never filled.
- **No onboarding/permission-priming flow exists** — the app currently
  lands cold on `HomeView`.
- Facial recognition/enrollment is explicitly out of scope for alpha per
  `docs/planning/SENSEBRIDGE-02-FEATURES-AND-SCOPE.md` ("What is
  intentionally excluded") — not part of this design.

## 1. Wire Scene Description & Identify to real Vision

Mechanical; copies `ReadingView`'s existing pattern exactly.

- Add `CameraPreviewView(cameraSource: environment.camera.source)` +
  `CameraControlsView(camera: environment.camera)` + a capture button,
  `.task { await startCameraIfNeeded() }`, `.onDisappear { stop() }`, and
  the same `message(for:)` camera-error mapping `ReadingView` already has.
- **Identify:** `ObjectClassificationService().process(photo)` →
  `[PerceptionRecord]` → take the first `.detectedObject` record →
  `Phrasing.describe(subject:certainty:)`. Same shape as `ReadingView`,
  `OCRService` swapped for `ObjectClassificationService`.
- **Describe:** `ObjectClassificationService().detect(photo)` →
  `[DetectedObject]` → map to `[PerceptionRecord]`
  (`.detectedObject(label:confidence:)`, `capturedAt: .now`) →
  `FoundationModelsSceneComposer().compose(from:)`. The composer already
  falls back to `LabelListSceneComposer` internally when Apple Intelligence
  is unavailable — no new fallback logic needed.
- Delete the `ponytail:` comments in both views once wired; they name this
  exact swap.

## 2. Sound Alerts

New subsystem — the largest piece of this design.

- **`MicrophoneSensingSource`** (new, `Packages/SenseBridgeCore/Sources/
  SenseBridgeCore/Sensing/`) — AVAudioEngine-based one-shot buffer capture,
  mirroring `CameraSource`'s shape and error cases
  (`authorizationDenied`, `noMicrophoneAvailable`). One tap = one short
  recording, never continuous — matches the "Listen once, not Start
  listening" copy already written into `SoundAlertsView`'s stub, and the
  privacy posture the rest of the app follows (nothing recorded to disk).
- **`SoundService` protocol** — a `PerceptionService` conformance
  (`process(_ input: Data) async throws -> [PerceptionRecord]`), alongside
  `OCRService`/`ObjectClassificationService`, producing
  `.detectedSound(label:confidence:)` records.
- **Two implementations, run together, higher confidence wins:**
  - `BuiltInSoundClassifier` — `SNClassifySoundRequest` (Apple's on-device
    taxonomy), filtered to a curated alpha subset: smoke/fire alarm,
    doorbell, knocking, dog barking, baby crying, car horn/siren, glass
    breaking, phone ringing. Exact identifier strings get verified against
    Apple's published taxonomy during implementation — the list above is
    the target concept set, not a guaranteed-correct set of API constants.
  - `CustomSoundClassifier` — a Create ML `MLSoundClassifier` trained
    offline on ESC-50 (CC-BY 4.0), filtered to the same class list,
    bundled as a `.mlmodel`. Training pipeline (folder structure + a
    training script, not part of the Swift app build) lives under
    `models/`. **Hard gate, not optional:** the bundled model and its
    ESC-50 provenance need a `model-license-audit` /
    `dependency-auditor` pass and a `CREDITS.md` attribution entry before
    this counts as alpha-ready.
  - `CombinedSoundClassifier: SoundService` runs both concurrently on one
    capture and returns the single highest-confidence hit, or the "nothing
    recognized" hedge if both come up empty — avoids an arbitrary
    primary/fallback ordering between two independently-trained models.
- `SoundAlertsView` wiring mirrors the existing "Listen once" button shape
  once `MicrophoneSensingSource` + `CombinedSoundClassifier` exist.
- `docs/PRIVACY.md` gets a line on the one-shot, in-memory, never-persisted
  microphone capture.

## 3. Onboarding

- New `OnboardingView`, shown once, gated by a new
  `Settings.hasCompletedOnboarding: Bool`.
  - `Settings()`'s in-code default is `false` (fresh install → show
    onboarding).
  - The *decode* path's missing-key default is `true` — an existing
    install that predates this field already knows the app. Same reasoning
    `Settings.crashReportingEnabled` already applies, inverted: a missing
    key on decode means "a settings blob already existed before this field
    did," which only fresh installs never do.
- Steps, flat back/next navigation, VoiceOver-first, no swipe-only
  gestures:
  1. One-sentence welcome, awareness-not-safety framing.
  2. Camera + microphone permission priming — explain why before
     triggering the system prompts.
  3. Crash-reporting opt-in — **reuses `DiagnosticsSettingsSection` as-is**
     rather than duplicating its copy, bound to the same
     `environment.settings.crashReportingEnabled`.
  4. Done → flips `hasCompletedOnboarding`, saves, routes to `HomeView`.
- `SenseBridgeApp.swift`'s root view branches on `hasCompletedOnboarding`.
- A "Replay walkthrough" row in Settings, so onboarding isn't a one-way
  door.

## 4. Cross-cutting (part of "alpha ready," not follow-up polish)

- Docs sync in the same change as the code that needs it:
  `docs/PRODUCT.md`, `docs/ARCHITECTURE.md` (data flow for the two
  newly-wired features + sound), `docs/PRIVACY.md`, `docs/TESTING.md`,
  `CREDITS.md`, relevant `TODO.md` closures.
- Gates: build + tests green; VoiceOver zero-unlabeled-elements pass on
  every new/changed screen; `safety-framing-reviewer` on all new
  spoken/haptic strings (sound-alert phrasing, onboarding copy);
  `model-license-audit` + `dependency-auditor` on the bundled Create ML
  model and ESC-50 provenance; `accessibility-reviewer` on onboarding.
- Device build + install at the end, per this repo's "hand it back
  testable" rule — not simulator-only, since camera/mic/LiDAR produce
  nothing there.

## Testing approach

Follows existing repo convention rather than introducing a new layer:
business logic lives in services (`SoundService` implementations,
`MicrophoneSensingSource`) and gets unit tests there, matching
`ObjectClassificationServiceTests`/`OCRServiceTests`. Views stay
logic-light, same as `ReadingView` today, and are covered by the VoiceOver/
accessibility pass rather than unit tests — no new MVVM layer is introduced
since the codebase doesn't use one elsewhere.

## Explicitly out of scope

- Facial recognition/enrollment (deferred post-MVP per the plan docs).
- Live speech captioning, wearables, cloud reasoning — later roadmap
  phases, untouched by this design.
- Extending Sound Alerts' curated class list beyond the alpha set, or
  retraining the custom classifier on anything beyond ESC-50, is a later
  iteration once real usage data exists.
