---
title: Architecture
---

# Architecture

Product framing: [`docs/PRODUCT.md`](PRODUCT.md). Roadmap: [`docs/ROADMAP.md`](ROADMAP.md).

## The framework decision

Native Swift / SwiftUI, not React Native. The hardest, most valuable code here
is on-device perception and output — Vision OCR, object detection, ARKit
depth, Sound Analysis, Foundation Models, AVSpeechSynthesizer, VoiceOver, Core
Haptics — and all of it is native Apple-framework code. React Native cannot
reach those frameworks except through native modules you'd have to write
anyway, so it would add a JavaScript layer and a bridge on top of the real
work for no benefit: the MVP is iPhone-only by design, and the on-device ML
quality, VoiceOver depth, and tooling are all better in native.

Lock-in risk is handled architecturally, not by framework choice: device
specific perception and output are isolated behind protocols (`SensingSource`,
`RenderTarget`), keeping the reasoning core device-agnostic. visionOS and
watchOS already share frameworks with iOS, so those are natural extensions.
Android or Meta-glasses would need new platform integrations regardless of
starting language, because their ML stacks are entirely different — revisit a
shared Rust/C++ core only if Android becomes a funded, near-term requirement
(a Phase 5 question; see [roadmap](ROADMAP.md)).

## System architecture

```text
SenseBridge App (native Swift / SwiftUI)

  Sensing Layer (SensingSource)         Output Layer (RenderTarget)
  - Camera                              - Speech (AVSpeech)
  - Depth (LiDAR)                       - VoiceOver announce
  - Microphone                          - Visual captions (later)
                                         - Haptics (later)
         |                                        ^
         v                                        |
  Perception Layer
  Vision OCR | Vision detect | Sound Analysis | depth
  -> structured "perception records"
         |
         v
  Reasoning Layer (device-agnostic)
  - phrasing / hedging rules
  - scene composition via Foundation Models (2-stage)
  - awareness logic (thresholds, hysteresis)
  - output-profile selection (blind / deaf / deaf-blind)
         |
         v
  Local Storage (no server required)
  UserDefaults (settings) | optional CloudKit sync
  encrypted enrollment store (later, on-device only)

  (Optional, opt-in only) ---------------------------------
  Cloud Reasoning Adapter (disabled by default)
  user-configured provider, explicit consent required
```

**Data flow — "read this document":**
`Camera → Perception (Vision OCR + structure) → Reasoning (reading-order) →
Output (Speech RenderTarget) → User`. No network, no server.

**Data flow — "describe this scene":**
`Camera → Perception (Vision detect + OCR) → structured perception record →
Reasoning (Foundation Models composes a hedged sentence) → Output (Speech
RenderTarget) → User`. The Foundation Models step is local and text-only — it
never sees the image, only the labels and text Vision extracted. That's a
hard constraint of the framework, not a design choice (see
[AI-MODELS.md](AI-MODELS.md)).

**Data flow — "hands-free awareness":**
`ARKit (camera + LiDAR) → Perception (depth reduction; objectness saliency →
per-region classification) → Reasoning (AwarenessEngine thresholds, Foundation
Models composes) → Output (Speech/Haptic RenderTarget) → User`, with the same
detections branching to the on-screen preview as yellow outlines. One
detection pass feeds both channels deliberately: an outline drawn from one
source and a sentence spoken from another would eventually disagree, and a box
around something the app never names is a claim it cannot back (see
[SAFETY-FRAMING.md](SAFETY-FRAMING.md)).

### Component responsibilities

- **Sensing Layer** — owns hardware (camera, ARKit depth, microphone). Each
  concrete source conforms to `SensingSource`; a future glasses camera is
  just a new `SensingSource`. One exception, documented on the type itself:
  `AmbientSensingSource` (ARKit `sceneDepth`) is **pull-based** and does not
  conform, because `SensingSource` pushes a stream of everything captured and
  ARKit produces 60 frames a second for a consumer that wants fewer than two.
  ARKit and `CameraSource` are mutually exclusive — iOS grants the rear camera
  to one session — so hands-free awareness stops the shared camera before it
  starts.
- **Perception Layer** — turns raw sensor data into structured facts (text,
  labels, sound events, depth readings). Pure transformation, no UI.
- **Reasoning Layer** — device-agnostic. Hedging rules, language composition,
  awareness thresholds, output-profile selection (blind = speech, deaf =
  captions, deaf-blind = haptics). Protected from device specifics so it
  survives expansion into future senses/devices.
- **Output Layer** — delivers via `RenderTarget`, which carries an
  `OutputMessage` (hedged prose plus an `OutputSignal`) so a haptic-only
  channel has something to react to when there is no prose to speak. Speech +
  VoiceOver and haptics are built; captions are not, so the deaf output
  profile is not offered yet — `MultiRenderTarget.unsupportedChannels`
  reports that gap rather than rendering a silent no-op. Watch and glasses
  later. `RenderTarget` is the extensibility stub that absorbs future-sense
  ideas without building them now — write the stub, note the idea, move on.
  **The signal is not a decoration on the prose — on a haptic-only channel it
  is the entire message**, because `HapticRenderTarget` renders
  `OutputMessage.signal` and discards `text`. Pick the signal from the branch
  the code is in, never from which screen it is on: a "nothing was
  recognized" branch that ships `.awarenessAlert` buzzes rising attention at
  a deaf-blind user while the prose says the opposite, and there is no hedge
  in a vibration to soften it.
- **Local Storage** — settings in UserDefaults, optional iCloud/CloudKit sync
  (free, preferences only), and later an encrypted on-device enrollment
  store. No server.
- **Optional Cloud Reasoning Adapter** — disabled by default, opt-in only,
  user-configured, so the "configurable provider" promise is real without
  ever being required.

## On-device AI pipeline

Foundation Models (`SystemLanguageModel`, `LanguageModelSession`) is the
reasoning engine: free, on-device, license-clean — but it is **text-only**
(cannot see an image) and has a **small context window** (~4,096 tokens,
manageable via `contextSize`/`tokenCount(for:)` since iOS 26.4). Scene
understanding is therefore two-stage: Apple Vision extracts labels/objects/
text, then Foundation Models composes a hedged natural-language sentence via
guided generation (`@Generable`) into a typed Swift struct. This is weaker
than a true vision-language model reasoning over pixels directly — it can
miss spatial relationships and sound confident while wrong — which is the
honest on-device quality gap versus cloud competitors. The answer is hedged
language plus an optional opt-in cloud path, never a default cloud
dependency. Full model choice and license ledger: [AI-MODELS.md](AI-MODELS.md).

### The model never writes the sentence

`FoundationModelsSceneComposer` constrains the model to return a **noun
phrase** ("a chair and a doorway") via `@Generable`, and
`Phrasing.describe(subject:certainty:)` supplies the hedge afterwards. The
obvious alternative — let the model write "There's a chair and a doorway ahead
of you" — would make the hedge a property of a prompt, and therefore something
a model update can quietly drop. Routing generation through `Phrasing` keeps
one enforcement point for every spoken string in the app, and keeps the hedge
strength tied to the *detector's* confidence rather than the model's fluency:
the lowest confidence in the frame picks the `Certainty`, because a composed
phrase naming several objects is only as good as its weakest member. A model
regression can make the wording clumsy; it cannot make the app sound certain.

### Hands-free awareness — the one continuous pipeline

`AmbientAwarenessSession` (App layer) is the only loop in the app; every other
feature is one capture per tap. It runs two cadences from one loop: depth every
750 ms, so something stepping in front of the user does not wait on a narration
interval chosen for comfort; classification and composition only every
`Settings.narrationIntervalSeconds`, because those are far more expensive.
`NarrationThrottle` then suppresses unchanged narration — a channel that
repeats regardless of whether anything changed teaches the user to stop
listening — while letting a real `AwarenessTransition` through immediately.

This is also where `OutputSignal.awarenessClear` finally has an honest emitter.
It is truthful only on an alerting → not-alerting *transition*, which is a
change the app observed, rather than an absence inferred from one sample.

**The floor is rejected by measurement, not by rectangle.** A phone on a chest
strap tilts down by whatever angle the strap happens to hold that morning, so
the floor — always the nearest large surface in view — would otherwise drive a
continuous alert everywhere, forever. Excluding a fixed region of the frame
would only work for one strap position. Instead `DepthGeometry` projects each
sample onto gravity using `ARCamera.transform`, and `DepthStatistics` discards
whatever lies within `floorClearanceMeters` of the lowest surface in view. The
ground plane is therefore found per frame, at any mount angle, and it follows
the user onto ramps and stairs. Objects *resting* on the floor stand proud of
that plane and survive, which is the point: a box in the walkway is exactly what
must not be filtered out along with the floor under it. When every sample in
view is ground, the reduction returns `nil` — "could not measure", never "the
way is clear".

**iOS does not permit camera capture while an app is backgrounded or the screen
is locked.** Hands-free awareness therefore requires SenseBridge foregrounded
with the display on, and holds `isIdleTimerDisabled` while running. When the app
is backgrounded anyway the session stops and *says so* — the target carries the
`audio` background mode for that one announcement and nothing else — because
silence on this channel is indistinguishable from "nothing to report" to someone
who cannot see the screen.

Foundation Models requires Apple Intelligence (iPhone 15 Pro+); implement
availability checks and a graceful fallback (label lists instead of composed
sentences) for unsupported devices.

### Sound Alerts data flow

One capture per tap, like Reading/Identify/Describe, not a continuous loop
like hands-free awareness: `MicrophoneSensingSource.record(duration:)`
captures a few seconds of audio as WAV `Data`, held in memory and deleted
from its temporary file before the call returns — nothing is ever persisted.
That `Data` feeds two independent `SoundService` implementations at once —
`BuiltInSoundClassifier` (Apple's on-device `SNClassifySoundRequest`
taxonomy) and `CustomSoundClassifier` (a bundled Create ML model trained on
a filtered ESC-50 subset, see [AI-MODELS.md](AI-MODELS.md) and
[`models/sound-classifier/README.md`](../models/sound-classifier/README.md))
— run concurrently, both filtered to the same curated class list.
`CombinedSoundClassifier` keeps whichever produced the single
highest-confidence `.detectedSound` record, rather than treating one model
as primary and the other as fallback: they were trained independently, so
neither is inherently more trustworthy. `Phrasing` then hedges the result
the same way every other feature's output is hedged.

## Mobile project shape

The reasoning core lives in a separate SwiftPM package, not inside the app
target — that seam is what makes it testable off-device, with no app target
or simulator required (`swift test` or `xcodebuild test -scheme
SenseBridgeCore`). 51 Swift files total across the repo as of this writing.

```text
app/
  Packages/SenseBridgeCore/       SwiftPM package — the device-agnostic core
    Sources/SenseBridgeCore/
      Sensing/      SensingSource protocol, CameraSource (concrete camera
                     implementation), CameraLens + CameraConfiguration (pure
                     lens/zoom math, testable without hardware),
                     CameraDeviceResolution, PhotoCaptureDelegate (bridges
                     AVCapturePhotoCaptureDelegate's callback API to Swift
                     concurrency). Depth and audio sensing sources are not
                     built yet
      Perception/    PerceptionService protocol ("some perception service"
                     seam so Reasoning never depends on a specific Apple
                     framework), OCRService (concrete Vision OCR
                     implementation), ObjectClassificationService (whole-frame
                     classify, plus region-based detect: objectness saliency
                     proposes regions, each is classified on its own),
                     PerceptionRecord (structured output type), DetectedObject
                     (a label with a bounding box, for the awareness preview's
                     outlines), DepthStatistics + DepthGeometry (pure depth
                     reduction), SoundClassificationRunner (shared Sound
                     Analysis plumbing), BuiltInSoundClassifier (Apple
                     taxonomy), CombinedSoundClassifier (concurrent, keeps
                     the highest-confidence hit)
      Reasoning/     SceneComposer (Foundation Models, 2-stage),
                     AwarenessEngine (thresholds/hysteresis), Phrasing
                     (hedging, awareness-not-safety), OutputProfile (blind/
                     deaf/deaf-blind selection), AppLanguage (supported UI
                     languages), LocalizedCatalog (String Catalog loader)
      Output/        RenderTarget protocol (OutputMessage + OutputSignal),
                     SpeechRenderTarget (AVSpeech + VoiceOver),
                     HapticRenderTarget (Core Haptics, UIFeedbackGenerator
                     fallback) + HapticPattern (pure, engine-free),
                     MultiRenderTarget (fan-out per OutputProfile).
                     CaptionRenderTarget is not built yet
      Storage/       Settings + SettingsStore protocol +
                     UserDefaultsSettingsStore. CloudSyncService (optional
                     CloudKit sync) and EnrollmentStore (encrypted,
                     on-device) are planned, not built yet
      CloudOptional/ CloudReasoningAdapter (opt-in only, disabled by default)
      Resources/     Localizable.xcstrings
    Tests/SenseBridgeCoreTests/   mirrors Sources/ — see docs/TESTING.md
  SenseBridge/                    the app target
    App/            SenseBridgeApp.swift, AppEnvironment.swift (DI
                     container), CameraController.swift (@Observable bridge
                     over the one shared CameraSource), HomeView.swift,
                     SettingsView.swift
    Accessibility/   VoiceOverAnnouncement.swift — the
                     announceIfUnspoken(_:profile:) entry point (see
                     docs/ACCESSIBILITY.md). HapticPattern lives in
                     Packages/SenseBridgeCore/Sources/.../Output/, not here:
                     it is an output-channel concern, and keeping it beside
                     HapticRenderTarget is what lets it stay engine-free and
                     unit-testable off-device
    Features/        Camera/ (preview + lens/zoom/torch controls, shared by
                     every capture feature), Reading/, Labeling/,
                     SceneDescription/, ObstacleAwareness/ (the continuous
                     session, plus AwarenessPreviewFeed + AwarenessPreviewView —
                     ARKit camera frames converted and drawn directly, with
                     yellow outlines. Camera/CameraPreviewView cannot serve it
                     (that one renders an AVCaptureSession) and neither does
                     ARSCNView: nothing here draws 3D content, so SceneKit would
                     add implicit requirements for no gain), SoundAlerts/
    Resources/       Localizable.xcstrings, InfoPlist.xcstrings,
                     Assets.xcassets/ (AppIcon, AccentColor)
  SenseBridgeTests/                app-level unit tests (AppEnvironmentTests)
  SenseBridgeUITests/              XCUITest target (LanguageSelectionUITests,
                                    SenseBridgeUITests)
  SenseBridge.xcodeproj/           the Xcode project
```

**State management** — boring and native: the Observation framework
(`@Observable`) or `ObservableObject` view models, with a small `AppEnvironment`
dependency container injected at the root. No heavy third-party state
library; app state is mostly transient perception data plus a small settings
object, and simplicity is a feature for a solo maintainer.

**Navigation** — SwiftUI `NavigationStack`, flat hierarchy. Blind users
navigate by VoiceOver, not visual layout: a main screen with clearly labeled
mode buttons (Read, Identify, Describe, Awareness, Sounds, Settings), each
leading to a focused single-purpose screen. Avoid deep nesting and
gesture-only navigation that conflicts with VoiceOver gestures.

**Accessibility layer is not optional — it is the product.** Every control
has a meaningful `accessibilityLabel`, a `hint` where the action isn't
obvious, and correct `traits`. Manage VoiceOver focus deliberately after
actions. Support Dynamic Type — never hardcode font sizes. Respect Reduce
Motion / Reduce Transparency. Announce asynchronous results. Build the empty
shell to this standard before adding any feature: if the empty app isn't
cleanly VoiceOver-navigable, nothing built on top of it will be either. Full
standard: [ACCESSIBILITY.md](ACCESSIBILITY.md).

**Offline-first** — every feature must work with the network off; the only
network-touching code is the optional cloud adapter, isolated behind a
protocol so the rest of the app never assumes connectivity.

**Caching** — minimal by design. Perception results are transient, not
persisted without reason. The one thing worth caching is the last in-session
result the user may want to revisit, held in memory, cleared on exit. Less
caching means less to leak.

**Sync** — MVP syncs settings only (voice speed, enabled features, output
profile) via optional iCloud, opt-in, free, no server. User content (images,
recognized text) is never synced. Enrollment data (later) stays local and is
explicitly excluded from sync by default.

## Backend architecture: there is none, and that is correct

A privacy-first, offline-first app has nothing to put on a server. Settings
live on the device; sync uses iCloud at no cost; there is no user content to
store, no auth to manage, no analytics collected. Nothing to breach, nothing
to fund, nothing to maintain.

Crash reporting (Sentry, since 2026-07-31) is the one exception, and it does
not change this: Sentry is a third-party service, so there is still no server
of ours. It is off until the user turns it on, it is linked only into the App
layer so `SenseBridgeCore` stays framework-independent under the
protocol-seams invariant, and it carries diagnostics rather than user content.
See `app/SenseBridge/App/CrashReporting.swift` and
[`docs/PRIVACY.md`](PRIVACY.md#crash-reporting-opt-in-off-by-default).

A backend becomes worth considering only if a
concrete need appears (opt-in cloud-reasoning endpoint, opt-in anonymized
telemetry, shared model distribution) — and if that day comes: opt-in only,
minimal data, self-hostable, free/free-tier infrastructure first, Sign in
with Apple over a custom credential store. None of this is MVP work.

## Infrastructure

No Docker, no Docker Compose, no Kubernetes — there is no server to
orchestrate, and building that infrastructure now would be cargo-culting for
a system that doesn't have one. What the MVP actually needs:

- **Local development** — Xcode on a Mac, a capable iPhone for on-device
  testing. See [ENVIRONMENT.md](ENVIRONMENT.md).
- **CI/CD** — GitHub Actions (free tier for public repos): build, test, lint
  on each push/PR. The only "infrastructure" the MVP needs.
- **Distribution** — TestFlight/App Store. See [DISTRIBUTION.md](DISTRIBUTION.md)
  for the one real cost here (the Apple Developer Program).
- **Self-hosting/Docker/cloud** — relevant only to a far-future optional
  cloud-reasoning service, not the app itself; not built now.

```text
MVP:        Xcode + iPhone + GitHub Actions  (no server)
                     |
                     v  (only if optional cloud reasoning is ever added)
Optional:   single Docker container on a free-tier host, self-hostable
                     |
                     v  (only if opt-in cloud users somehow reach large scale)
Scale:      container orchestration, revisited then with real numbers
```

Do not build infrastructure for problems you do not have.

---

Need help? See
[`SUPPORT.md`](https://github.com/kevinle3212/sensebridge/blob/main/SUPPORT.md).
