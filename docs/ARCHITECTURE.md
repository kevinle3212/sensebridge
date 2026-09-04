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
  - Microphone                          - Visual captions
                                         - Haptics
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
  ReasoningComposerResolver: On-Device (default) | Local | Cloud (BYOK)
  circuit-breaker fallback to on-device, disclosed once per trip/recovery
```

**Data flow — "read this document":**
`Camera → Perception (document segmentation + perspective correction → Vision
OCR + structure) → Reasoning (reading-order → sentence segmentation → playback
cursor) → Output (Speech RenderTarget) → User`. No network, no server.

The Read screen runs this two ways. **Capture** takes one photo per tap and can
build a multi-page document; **live** polls `CameraSource`'s video-data output,
recognizes each frame, and reads a page aloud once its recognized text stops
changing. Both end in the same `ReadingPlayback` cursor, so the transport
controls work identically on either. See "Reading — playback, live, and
history" below.

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
[SAFETY-FRAMING.md](SAFETY-FRAMING.md)). Between the raw passes and that shared
list sits `DetectionStabilizer`, which filters per-tick noise: labels confirm
over consecutive ticks before they are shown or spoken, survive brief absences,
and drop once persistence runs out — while a thrown pass holds the last stable
set rather than counting a sensor failure as "nothing there".

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
  VoiceOver, visual captions, and haptics are built. `CaptionRenderTarget`
  keeps the current already-hedged text in observable app state, and
  `CaptionOverlay` renders it as a high-contrast, Dynamic-Type-aware safe-area
  inset whenever the active profile asks for the `.caption` channel — the same
  condition `MultiRenderTarget` delivers on, so the two can't drift apart. Past
  a Dynamic-Type-scaled height cap the caption scrolls rather than truncating,
  since on a caption-only profile a dropped tail is a dropped result. Every
  camera-capture screen emits an empty `.captureTaken` message before it
  shoots, which clears the previous caption, so a result describing an old
  frame never remains visible as if it described the new one. Watch and glasses
  later. `RenderTarget` is the extensibility
  stub that absorbs future-sense ideas without building them now — write the
  stub, note the idea, move on.
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
- **`ReasoningComposerResolver`** — picks the active reasoning backend from
  `Settings`: on-device (Foundation Models, default, free, private), a
  self-hosted local endpoint, or opt-in Cloud BYOK (Anthropic, OpenAI, NVIDIA
  NIM), all disabled by default and user-configured. Network composers'
  output passes through `ReasoningOutputValidator` — a deterministic, local
  gate, not a system-prompt request — before it ever reaches `Phrasing`,
  since only Foundation Models' `@Generable` guided generation can enforce
  hedged phrasing structurally. Two consecutive network failures trip a
  circuit breaker that falls back to on-device and announces the fallback
  once; a later success announces recovery once. Composition runs as a
  tracked, cancellable child task so a slow network round-trip never blocks
  the depth-sampling tick in `AmbientAwarenessSession`. See
  [`docs/superpowers/specs/2026-08-11-awareness-ai-tiers-design.md`](superpowers/specs/2026-08-11-awareness-ai-tiers-design.md).

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

### Description detail — `SpokenDetail`

`Settings.spokenDetail` (`Brief`/`Standard`/`Detailed`) scales two numbers and
nothing else: `ObjectClassificationService.maximumLabels` (how many objects a
detection pass names) and `SpokenDetail.maximumPhraseWords(labelCount:)` (the
composed phrase's word ceiling, enforced structurally in
`FoundationModelsSceneComposer` and by `ReasoningOutputValidator` on every
network composer). The detector's precision floor, `Phrasing`'s hedge
templates, and `Phrasing.certainty(forConfidence:)`'s buckets are the same at
every level — more detail means more of what was recognized gets named, never
more certainty about any one of it. `LabelListSceneComposer` (the composer
that runs whenever Apple Intelligence is unavailable — "the on-device default"
at its worst) groups its output by certainty bucket rather than repeating one
full hedged sentence per object, so the no-Apple-Intelligence path reads as
prose rather than a stutter of identical templates — and since the fusion
work, it composes one hedged sentence per perception stream, sight → sound → text,
each stream carrying its own modality's hedge ("it looks like…" vs "it sounds
like…"), so a scene with a chair, an alarm, and a sign is described as the one
moment it was rather than three unrelated broadcasts.

### Object and sound names in Spanish and Vietnamese

Vision and Sound Analysis return English identifiers. `SpokenVocabulary` holds
hand-written article-first phrases for the identifiers a real walk produces —
roughly 75, including the complete `BuiltInSoundClassifier.targetClassNames`
set — and `SpokenPhrase.subject(for:locale:)` resolves the most specific locale
first, falling back to the **English phrase** when there is no reviewed entry.

Two decisions are load-bearing. **Whole phrases, not article plus noun:**
Spanish agrees the article with gender and Vietnamese picks a classifier by the
kind of thing being counted (`cái`, `con`, `chiếc`, `quyển`), neither of which
is derivable from an English identifier, so composing one at runtime would be
the guess the table exists to avoid. **A partial table, not a translated
vocabulary:** machine-translating ~1,600 identifiers would name the long tail
confidently and wrongly, and [SAFETY-FRAMING.md](SAFETY-FRAMING.md) ranks
mis-naming a physical object above a crash. Falling back to English degrades the
*language* and never the accuracy, which is the safe direction to fail in.

`locale` is a property of the classifier, not a global: it affects wording only,
never which identifiers are considered or what confidence they carry, so no
locale can make the app report something another locale would not.

### Reading — playback, live, and history

`ReadingSession` (App layer) owns the Read screen: capture, the playback
cursor, the live loop, and the history store. It dies with the screen, because
everything it holds — the camera, the cursor, and any torch it switched on —
has to be released when the user leaves, and a blind user has no way to notice
any of the three still running.

**Playback is a cursor, not a queue.** `TextSegmenter` splits the whole
document into sentence-level segments up front, and `ReadingPlayback` walks
them one at a time, awaiting each utterance through
`SpeechRenderTarget.speak(_:)` before starting the next. That is what makes
"back", "next", and "pause" land *between* sentences rather than cutting one
off mid-word. A timer-driven approximation would drift out of step with the
synthesizer on the first long sentence. `ReadingPlayback` itself is pure —
clamping, blank-segment dropping, and the "past the end" state are all
verifiable without a camera or a synthesizer.

**Aiming guidance is about recognition, never about the page.**
`ReadingFraming` reduces the OCR bounding boxes to one instruction: nothing
recognized, text running past named edges, text too small, or well framed. The
copy says "no text is being recognized", never "the page is blank" — an
absence inferred from one frame is not an absence the app observed. Well-framed
returns *no* string at all: live reading evaluates several frames a second, and
a channel that says "looks good" every time it has nothing to report is a
channel the listener turns off. Multiple edges collapse to one instruction,
because a listener follows one instruction at a time.

**The torch is decided from the frame, not from failure.** `FrameLuminance`
measures the mean relative luminance of the live buffer and reports `dim`,
`adequate`, or `unmeasured`. Three cases rather than an optional boolean:
treating an unreadable pixel format as darkness would leave the torch on
permanently on any device whose capture format changes. Three consecutive dark
frames are required before it switches on, so a hand passing over the lens does
not produce a strobe — and switching it on is *announced*, because a torch is a
change to the world around the user, including for anyone facing them.

**Reading history is opt-in, capped, protected, and unbacked-up.**
`ReadingHistoryStore` is a separate file rather than anything in `Settings`,
whose own doc comment forbids it holding user content — and recognized text is
the most sensitive content this app produces. The file carries
`.completeFileProtection` (unreadable while the device is locked, including by
this app), is excluded from backup, holds at most 25 documents, and defaults to
off. Turning history off deletes what is already stored rather than hiding it.
See [PRIVACY.md](PRIVACY.md).

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

**Direction is a detail on a sentence, never a second decision.** The distance
is still measured over `regionOfInterest` exactly as it was before zones
existed, so the number the alert threshold acts on is untouched. Zones are cut
from a **wider** strip — `AwarenessZoneGeometry.zoneRegion(measuring:)` — for a
reason worth stating plainly: the region of interest keeps only the middle half
of the across-axis, so thirds of *it* spanned roughly 8° of the sensor's ~48°
across-FOV. A chest strap re-tightened each morning yaws by more than that, so
"on your left" could have meant a door frame genuinely straight ahead. Cutting
zones from the full width makes each about 16°, with the sides beginning 8°
off-centre — inside what the geometry earns.

Naming a side then takes three things, all in
`AwarenessDepthReading.namedZone`:

1. One zone nearer than every other *measured* zone by at least 0.4 m
   (`AwarenessZoneReading.significantZone`). A single resolved zone never
   qualifies — that would be inferred from the other two being unreadable — and
   a wall across the frame qualifies none either.
2. **A measured centre.** A listener told "on your left" reasonably concludes
   the way in front is comparatively free, and a glass door straight ahead is
   exactly what returns no confident depth.
3. **Agreement with the spoken distance**, within 0.5 m. Because the zone strip
   now reaches into periphery the distance never looked at, the nearest zone is
   not automatically what triggered the alert; a bollard off to one side must
   not lend its direction to a sentence about a wall.

Which third is the user's left follows from frames carrying
`CGImagePropertyOrientation.right`. That, and the residual mount yaw, are the
assumptions arithmetic cannot self-check — both are on the device-validation
list in [TESTING.md](TESTING.md).

The on-screen per-zone summary is finer-grained than any of this: it publishes
what each zone last measured, including differences too small for the spoken
path to name a side from. It carries a legend saying so, because three numbers
laid out left-to-right otherwise read as the directional judgment the app is
deliberately refusing to make out loud.

**No reading is ever composed from a frame older than the run it belongs to.**
`ARSession` is kept for the lifetime of `AmbientSensingSource` so a stop/start
pair resumes tracking rather than rebuilding it — and `currentFrame` survives
that pair too, still vending the previous run's last frame until the new run
produces one. `latestFrame(orientation:)` therefore refuses any frame whose
`timestamp` predates the current `run(_:options:)`, and it does so there rather
than in each caller, because both callers are exposed: the one-shot check reads
immediately after starting, and hands-free awareness restarts whenever the app
returns to the foreground. A stale frame is the hardest kind of wrong reading to
notice, since nothing about the sentence looks stale.

**"Check once" reports its measurement, even when nothing is close.** A single
check that measures something past the user's alert distance now says how far
the nearest measurable thing was (`Phrasing.nearestMeasurement(atDistance:)`),
where it used to fall back to "Nothing recognizable was found." That sentence
was wrong on both halves — recognition never runs on this path, and depth
sensing had just succeeded — and it taught a listener that the app says
"nothing" when it means "nothing close", which is the habit that makes a real
alert ignorable.

**Proximity drives cadence on the channel that carries no prose.**
`ProximityBand` buckets a distance into four bands and gives each a repeat
interval; `AmbientAwarenessSession` pulses the existing `.awarenessAlert` cue at
that rate while an alert is active. This adds no new haptic pattern to learn —
it varies the rate of one existing cue — and it must not grow into a
vocabulary, which would need co-design with deaf-blind collaborators. The
furthest band deliberately does not repeat: indoors there is always a wall three
metres away, and a cue that never stops is a cue that stops being noticed.
Crossing into a nearer band re-speaks the distance once per band, because a
listener walking toward a wall who hears one sentence and then silence cannot
tell that from the session having died.

**Every session ends with a summary.** Alerts raised and minutes run — facts
about this app, not about the world. "You passed four obstacles" would be a
claim built from readings that were never verified.

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
who cannot see the screen. It then **restarts itself** when the app next becomes
active, announcing that too. `AmbientAwarenessSession+Lifecycle.swift` owns both
edges. The resume is armed only by the backgrounding path and disarmed by any
other `stop()`, so a session the user ended by hand never comes back on its own;
`didBecomeActive` rather than `willEnterForeground`, because ARKit will not start
a session for an app that is not yet active.

**Thermal backoff.** This loop holds the camera, a LiDAR session, the neural
engine, and a full-brightness screen for as long as someone is willing to walk,
and iOS will throttle all four on a warm device. `ThermalBackoff` (Core) maps
`ProcessInfo.thermalState` to an interval multiplier — 1× while nominal or fair,
2× at `.serious`, 4× at `.critical` — applied to both cadences, so the expensive
half backs off proportionally rather than the cheap half backing off alone. A
multiplier rather than fixed intervals, so it composes with the user's own
narration cadence instead of overriding it. Every level change is spoken once,
recovery included; being throttled into silence unannounced is the failure mode
this exists to avoid. It never stops the session — someone mid-walk is worse off
with silence than with a slower cadence they were told about.

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

## Logging

Added 2026-08-18. Before that the app had no logging at all, which made the
only report a user can actually give — "it went quiet" — undiagnosable: that
sentence fits a crashed session, a thermal throttle, a denied permission, and a
genuinely silent room equally well. `AppLog`
(`Sources/SenseBridgeCore/Diagnostics/AppLog.swift`) exists to separate those
four in a sysdiagnose, and for nothing else.

Four `Logger` categories under the app's bundle identifier — `sensing`,
`perception`, `reasoning`, `output` — one per pipeline stage. They are declared
in `AppLog` and nowhere else; a stray `Logger(subsystem:category:)` elsewhere
would sit outside the rule below and file its output under a category nothing
knows to read, so `AppLogPrivacyTests` fails the build on one.

**What is logged:** events and state transitions only — a session starting or
stopping, a permission granted or denied, a thermal level changing, the
reasoning circuit breaker tripping or recovering. Never a per-frame or
per-observation record; that would be both a privacy surface and a battery cost
on a loop that runs for as long as someone walks.

**What is never logged:** recognized text, image content, or audio content. Not
at any privacy level — not `.private`, not redacted, not hashed. It does not
reach a log statement. This is the rule
[`docs/PRIVACY.md`](PRIVACY.md#what-happens-to-user-content) points at, and the
one `CrashReporting.scrub` depends on when it declines to scrub an exception
message.

### The privacy default is backwards from the obvious one

The intuitive worry is that logged **strings** leak. They are the safe case: a
`Logger` string interpolation defaults to `.private` and renders as `<private>`
in a sysdiagnose from a release build.

The real exposure is the reverse. **Numerics, booleans, and raw enum values
default to `.public`**, on the assumption that a number identifies nobody. Here
that assumption is wrong — an OCR confidence score, a detected-object class
index, a proximity band, and a recognized-text character count are all numeric
and all derived from what the camera saw.

So the enforced rule is: **every interpolated value carries an explicit
`privacy:` label**, including values that look harmless, and anything derived
from perception output is `.private` or is bucketed before it is logged.
Requiring the label even where `.public` is correct is deliberate — an explicit
`.public` is a decision a reviewer can see and argue with, while a missing one
is invisible and means the same thing.

`AppLogPrivacyTests` enforces this structurally, by scanning the package
sources for log call sites and failing on any interpolation without a
`privacy:` label. **What that test proves, and what it does not:** `OSLog`
output cannot be read back in-process, so it cannot assert that a value was
redacted at runtime. It asserts a property of the source text instead. That is
the invariant that actually fails in practice, it fails closed, and it errs
toward false positives a human immediately understands rather than false
negatives that ship. It was verified against a deliberately introduced
violation, not merely observed passing.

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
                     languages), LocalizedCatalog (String Catalog loader),
                     ReasoningComposerResolver + LiveNetworkComposerFactory
                     (backend selection, circuit-breaker fallback),
                     AnthropicSceneComposer + OpenAICompatibleSceneComposer
                     (OpenAI/NIM/self-hosted), ReasoningOutputValidator,
                     EndpointURLNormalizer — all opt-in, disabled by default
      Output/        RenderTarget protocol (OutputMessage + OutputSignal),
                     SpeechRenderTarget (AVSpeech + VoiceOver),
                     HapticRenderTarget (Core Haptics, UIFeedbackGenerator
                     fallback) + HapticPattern (pure, engine-free),
                     MultiRenderTarget (fan-out per OutputProfile).
                     App layer: CaptionRenderTarget + CaptionOverlay
      Storage/       Settings + SettingsStore protocol +
                     UserDefaultsSettingsStore. CloudSyncService (optional
                     CloudKit sync) and EnrollmentStore (encrypted,
                     on-device) are planned, not built yet
      Resources/     Localizable.xcstrings
    Tests/SenseBridgeCoreTests/   mirrors Sources/ — see docs/TESTING.md
  SenseBridge/                    the app target
    App/            SenseBridgeApp.swift, AppEnvironment.swift (DI
                     container), CameraController.swift (@Observable bridge
                     over the one shared CameraSource), CaptionRenderTarget +
                     CaptionOverlay (the .caption channel — an app-layer
                     RenderTarget because it owns SwiftUI state),
                     HomeView.swift, SettingsView.swift
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

**Offline-first** — every feature must work with the network off; on-device
composition is always the default and the fallback. The only network-touching
code is the opt-in Local/Cloud reasoning backends, isolated behind
`NetworkComposerFactory`/`SceneComposer` so the rest of the app never assumes
connectivity, and a circuit breaker returns every session to on-device after
two consecutive failures.

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
