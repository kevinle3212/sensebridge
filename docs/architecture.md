# Architecture

Full rationale: [`docs/planning/SenseBridge-03-Technical-Architecture.md`](planning/SenseBridge-03-Technical-Architecture.md).
Product framing: [`docs/PRODUCT.md`](PRODUCT.md). Roadmap: [`docs/roadmap.md`](roadmap.md).

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
(a Phase 5 question; see [roadmap](roadmap.md)).

## System architecture

```
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
[ai-models.md](ai-models.md)).

### Component responsibilities

- **Sensing Layer** — owns hardware (camera, ARKit depth, microphone). Each
  concrete source conforms to `SensingSource`; a future glasses camera is
  just a new `SensingSource`.
- **Perception Layer** — turns raw sensor data into structured facts (text,
  labels, sound events, depth readings). Pure transformation, no UI.
- **Reasoning Layer** — device-agnostic. Hedging rules, language composition,
  awareness thresholds, output-profile selection (blind = speech, deaf =
  captions, deaf-blind = haptics). Protected from device specifics so it
  survives expansion into future senses/devices.
- **Output Layer** — delivers via `RenderTarget`. Speech + VoiceOver for the
  MVP; captions and haptics later; watch and glasses later. `RenderTarget` is
  the extensibility stub that absorbs future-sense ideas without building
  them now — write the stub, note the idea, move on.
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
dependency. Full model choice and license ledger: [ai-models.md](ai-models.md).

Foundation Models requires Apple Intelligence (iPhone 15 Pro+); implement
availability checks and a graceful fallback (label lists instead of composed
sentences) for unsupported devices.

## Mobile project shape

```
SenseBridge/
  App/            SenseBridgeApp.swift, AppEnvironment.swift (DI container)
  Core/
    Sensing/       SensingSource protocol, Camera/Depth/AudioSource
    Perception/    OCRService, DetectionService, SoundService, DepthService,
                    PerceptionRecord (structured output type)
    Reasoning/      SceneComposer (Foundation Models, 2-stage), AwarenessEngine
                    (thresholds/hysteresis), Phrasing (hedging, awareness-not-
                    safety), OutputProfile (blind/deaf/deaf-blind selection)
    Output/         RenderTarget protocol, SpeechTarget (AVSpeech + VoiceOver),
                    CaptionTarget (later), HapticTarget (later)
    Storage/        Settings (UserDefaults), CloudSyncService (optional
                    CloudKit), EnrollmentStore (later, encrypted, on-device)
    CloudOptional/  CloudReasoningAdapter (opt-in only, disabled by default)
  Features/         Reading/ Labeling/ SceneDescription/ ObstacleAwareness/
                    SoundAlerts/
  Accessibility/    VoiceOver+Helpers, DynamicType+Helpers, HapticPatterns
  Resources/        Localizable.strings, SoundModels/ (Create ML, permissive)
  Tests/            mirrors structure — see docs/TESTING.md
```

**State management** — boring and native: the Observation framework
(`@Observable`) or `ObservableObject` view models, with a small `AppEnvironment`
dependency container injected at the root. No heavy third-party state
library; app state is mostly transient perception data plus a small settings
object, and simplicity is a feature for a solo maintainer.

**Navigation** — SwiftUI `NavigationStack`, flat hierarchy. Blind users
navigate by VoiceOver, not visual layout: a main screen with clearly labeled
mode buttons (Read, Identify, Describe, Awareness, Sounds), each leading to a
focused single-purpose screen. Avoid deep nesting and gesture-only navigation
that conflicts with VoiceOver gestures.

**Accessibility layer is not optional — it is the product.** Every control
has a meaningful `accessibilityLabel`, a `hint` where the action isn't
obvious, and correct `traits`. Manage VoiceOver focus deliberately after
actions. Support Dynamic Type — never hardcode font sizes. Respect Reduce
Motion / Reduce Transparency. Announce asynchronous results. Build the empty
shell to this standard before adding any feature: if the empty app isn't
cleanly VoiceOver-navigable, nothing built on top of it will be either. Full
standard: [accessibility.md](accessibility.md).

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
to fund, nothing to maintain. A backend becomes worth considering only if a
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

```
MVP:        Xcode + iPhone + GitHub Actions  (no server)
                     |
                     v  (only if optional cloud reasoning is ever added)
Optional:   single Docker container on a free-tier host, self-hostable
                     |
                     v  (only if opt-in cloud users somehow reach large scale)
Scale:      container orchestration, revisited then with real numbers
```

Do not build infrastructure for problems you do not have.
