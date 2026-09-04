---
title: Testing Strategy
---

# Testing Strategy

Coverage targets here are pragmatic for a solo developer, not enterprise
dogma. The aim is confidence where bugs hurt most — perception correctness,
accessibility, and awareness-not-safety phrasing (see
[`docs/SAFETY-FRAMING.md`](SAFETY-FRAMING.md)) — not a coverage percentage for
its own sake.

| Layer | What | How | Target |
| --- | --- | --- | --- |
| Unit | Pure logic: reading-order from OCR, phrasing/hedging rules, awareness thresholds, output-profile selection | Swift Testing, no device, fixture perception records | High coverage on the Reasoning layer specifically — this is where a subtle bug produces a confidently wrong statement |
| Integration | Perception services against fixed inputs (OCR, detection, sound classification) | Swift Testing with bundled fixtures | Happy path plus key failure modes (blurry image, no text found, ambiguous object) per service |
| Accessibility | Every screen is VoiceOver-navigable; labels/traits present; focus behaves | Xcode Accessibility Inspector + manual VoiceOver checklist per screen | Zero unlabeled interactive elements — a hard gate, not a percentage |
| AI evaluation | Quality of OCR/labels/scene descriptions — synthetic fixtures now, held-out real-world photos later | `npm run eval` (`eval-harness`, in-package Swift executable): renders fixtures, runs the real OCR/object services and `LabelListSceneComposer`, runs composed output through `ReasoningOutputValidator`; output is eyeballed periodically | No regressions in reading accuracy; no new over-confident or hallucinated claims — content-rule rejections print as OVERCLAIM lines |
| End-to-end | Full flows (open app → Read → capture → hear result; Awareness → fixture route → cautious alerts) | XCUITest where stable; scripted-manual where camera/depth resist automation | At least three E2E tests per feature — one happy path, one error path, one edge case — all passing before every beta build |
| Device | Real-device behavior: latency, battery, thermal, Neural Engine load | Instruments profiling on the actual iPhone target | Responsive; no thermal throttling in a normal session; acceptable battery drain |
| Field | Real blind users, real environments, real tasks | TestFlight beta with recruited testers, structured feedback | At least one or two testers completing real tasks unaided and willing to keep using it |
| Beta | Wider TestFlight group once MVP is stable | Public TestFlight, feedback channel, issue triage | Stable, crash-rare, generating real usage feedback before any App Store consideration |

## Frameworks

**Swift Testing** (`import Testing`, `@Test`, `#expect`) for unit and
integration. **XCTest** for end-to-end and performance — `XCUITest` and
`XCTMetric` have no Swift Testing equivalent, so that is a permanent split, not
a migration in progress. The two coexist in the same test target; neither
excludes the other.

Decided 2026-07-16, while the repo had **zero `.swift` files**. Three reasons,
all about what this costs as the suite grows:

- **Migration cost only goes up.** It is zero now and rises with every test
  written. Deciding later means paying to convert, or living with a split that
  isn't principled.
- **Parallelism is cheaper — measured, not assumed.** Swift Testing runs tests
  in parallel in-process by default; XCTest parallelises by cloning
  simulators. Measured 2026-08-06 on this repo's `SenseBridgeCoreTests`
  package (90 tests, 16 suites, M-series Mac, 8 logical / 4 performance
  cores): `swift test --disable-xctest` (default, in-process parallel) runs
  the suite in ~0.36s versus ~0.67s with `--no-parallel` forced — a ~1.8×
  speedup with zero extra setup, since it's just more concurrent tasks in the
  process already running. The cost XCTest pays instead is per-worker, not
  per-test: `xcrun simctl clone` plus `simctl boot` to bring up one additional
  parallel simulator took ~10.3s (4.5s clone + 5.8s boot) *before any test
  runs*, and that cost repeats for every worker XCTest fans out to. On a small
  suite that fixed cost already dwarfs the run itself; it scales with worker
  count, not test count, which is what "compounds into CI minutes" means in
  practice as the suite — and the CI matrix — grow.
- **Parameterisation fits the work.** Our tests are overwhelmingly "one
  assertion across N fixtures" — reading-order cases, hedging phrasings,
  perception fixtures. `@Test(arguments:)` expresses that as one test that
  names the failing input, instead of N copy-pasted methods.

Requires the Swift 6 toolchain, which [`ENVIRONMENT.md`](ENVIRONMENT.md)
already mandates. Nothing here weakens the priority order: correct hedging
first, then not crashing, then performance.

**`swift test` cannot validate String Catalog localization.** The bare
SwiftPM CLI (`swift build`/`swift test`) does not compile `.xcstrings` files —
it copies the raw catalog into a flat, uncompiled resource bundle, so
`Bundle.module.localizations` is always `["en"]` regardless of what the
catalog contains. Only `xcodebuild test` (Xcode's real build system, which
invokes `xcstringstool compile`) produces the per-locale `.lproj` bundles a
locale-dependent test needs. Any test that asserts on a non-default-locale
string (e.g. `SenseBridgeCoreTests/PhrasingTests`,
`SenseBridgeCoreTests/SceneComposerTests`) must be run via
`xcodebuild test -scheme SenseBridgeCore -destination 'platform=macOS'`, not
`swift test` — CI's package-test loop (`.github/workflows/ci.yml`) uses
`xcodebuild test` for this reason. Run it from
`app/Packages/SenseBridgeCore`, not `app/`: the umbrella Xcode project's
auto-generated `SenseBridgeCore` scheme has no shared Test action
(`TODO.md`'s 2026-08-11 entry), so the same command fails from `app/` with
"Scheme SenseBridgeCore is not currently configured for the test action" —
`ci.yml` avoids this by `cd`-ing into each package directory before running
it.

**On-device UI tests need `-allowProvisioningUpdates`.** The UI-test runner
gets its own bundle identifier (`<prefix>.SenseBridgeUITests.xctrunner`) that
no profile covers until Xcode generates one, and `xcodebuild` will not create
it unattended without that flag:

```sh
xcodebuild -project app/SenseBridge.xcodeproj -scheme SenseBridge \
  -destination "platform=iOS,id=$DEVICE" -allowProvisioningUpdates \
  build-for-testing
```

Without it the build fails with *"No profiles for
'…UITests.xctrunner' were found … Automatic signing is disabled"*, which reads
like a project misconfiguration but is not — signing style is already
automatic. Contributors signing with their own team should also set
`BUNDLE_ID_PREFIX` first; see
[ENVIRONMENT.md](ENVIRONMENT.md#configuration).

## Coverage philosophy

All code ships with tests — nothing merges untested. Depth scales with risk:
chase exhaustive coverage where wrongness is dangerous (reasoning, phrasing,
awareness logic) and where regressions are silent (perception); for glue code
and SwiftUI views a minimal covering test suffices. A test you'll actually
maintain beats one that looks good in a report.

**One deliberate exception: App-layer types that wrap an Xcode-generated or
system-provided type carry no package-level unit test.**
`FoundationModelsSceneComposer` (needs `SystemLanguageModel`) and
`CustomSoundClassifier` (needs the Create ML model's auto-generated Swift
wrapper, which only exists in the App target's compiled output — see
`docs/ARCHITECTURE.md`'s "Sound Alerts data flow") both live in the App
layer specifically because `SenseBridgeCore` cannot depend on either type.
Neither can be constructed from a `SenseBridgeCoreTests`-style unit test for
the same reason, so this is a structural limit of where the type can live,
not a gap to backfill.

That does not mean both are manual-only. `FoundationModelsSceneComposer` is
manual-only: no automated test touches it or `SystemLanguageModel`, so its
coverage is the manual/VoiceOver pass — this covers the `SpokenDetail`-scaled
word ceiling too: `xcodebuild build` proves the two `@Generable` guide structs
and the structural length check compile, never that a real model actually
respects the word-budget hint at `.detailed`, which needs a device listen (see
`TODO.md`'s device-validation entry). `CustomSoundClassifier` is not — after
an audit found
non-alert audio (room hiss, white noise, a pure tone, a frequency sweep)
scoring an alert class at 1.000 confidence and reaching spoken output (see
`audits/safety-framing/20260806-064241-custom-sound-classifier-out-of-distribution-false-positives-reach-spoken-output.md`),
`app/SenseBridgeTests/CustomSoundClassifierOODTests.swift` was added as an
App-target Swift Testing suite that runs the shipped `.mlmodel` through the
same model, request, and target-class filter `CustomSoundClassifier.process(_:)`
uses. It still does not construct `CustomSoundClassifier` itself — so the
package-level-unit-test limit above still holds — but it is real automated
regression coverage of the inference path the type wraps, not a manual check.

## The accessibility-audit gate

Every screen's audit runs through one shared helper,
`XCTestCase.performScopedAccessibilityAudit` in
[`app/SenseBridgeUITests/AccessibilityAuditSupport.swift`](../app/SenseBridgeUITests/AccessibilityAuditSupport.swift),
which also carries the evidence for every exemption. Two properties of it are
worth knowing before adding an audit:

- **Audit types are requested, not filtered.** Asking for `.all` and discarding
  categories in the handler still pays for them. `List`/`Form` screens request
  only the categories whose findings the project acts on.
- **A scrolled screen is audited without `.contrast`.** A lazy `List` keeps
  every row it has instantiated, and contrast has to screenshot each one:
  measured on Settings, 0.85 s at rest versus never finishing after a scroll
  (`Code=-56 "Audit failed to complete in time"`). Screens that need scrolling
  are therefore audited twice — fully at rest, then for the labelling
  categories once scrolled. Contrast findings on elements that are not fully
  visible are exempted by geometry, since the pixels being measured are the
  navigation bar's material rather than the app's.
- **The audit names its finding, since 2026-08-19.** `XCUIAccessibilityAudit`
  reports a contrast failure as the bare string `Contrast nearly passed` —
  naming neither the element, the screen, nor the ratio. The first device run
  produced four of them and identified none. The handler now logs the label,
  the appearance, the frame, and the audit's own detailed description for every
  issue it is about to fail on, which is what turned "four unexplained
  failures" into "the onboarding `Next` button and the Read screen's `Reading
  history` link" in a single run.

**A device-free gate catches the arithmetic half of this.**
`npm run check:contrast` (`tools/check-color-contrast.mjs`) computes the WCAG
2.1 ratio for every authored color asset against each system background it is
drawn on, in both appearances, and fails below 4.5:1. It does not replace the
device audit — a color can clear the arithmetic and still be composited over
something unexpected — but the contrast ratio of two known sRGB colors never
needed a phone, an unlocked screen, or six minutes to compute. It found the
defect behind all four device failures in milliseconds: `AccentColor`'s dark
variant was Apple's own systemBlue `#0A84FF`, which is 3.82:1 against iOS's
dark grouped-row background `#2C2C2E` and 3.50:1 against the `#323236` this app
was pixel-sampled rendering on hardware. Both sit in the 3.0-4.5 band whose
audit message is precisely "not high enough unless font size is larger".

## Which destination a UI test means something on

`npm run app:test` runs the UI suite in the Simulator. `npm run app:device-test`
runs the same suite on an attached iPhone, and is the only command that
exercises real ARKit, LiDAR, the camera, and arm64. **They are not
interchangeable, and a green Simulator run is not evidence for the device.**

The first device run of this suite (2026-08-19) failed eight tests, and not one
of them was a regression. They divided cleanly:

- **Tests that assumed the host has no camera.** Three of them asserted the
  no-camera *error* path, which they got for free from a Simulator that
  genuinely has none. A phone has a camera, so the path they assert is
  correctly never entered. They now pass `-uiTestNoCamera`, which
  `CameraController` honors in both `start(applying:)` and `capturePhoto()` and
  which is compiled out of release builds. **Force the state you are asserting
  on; never inherit it from the host** — a test that depends on the Simulator's
  hardware limitations is a Simulator test wearing a portable test's name.
- **A test that did not scroll.** `singleCheckSection` is the last section of a
  `List`, so on a LiDAR device the hands-free section above it renders in full
  and pushes it off screen — and a lazy `List` leaves an off-screen row out of
  the accessibility hierarchy entirely, not merely out of view. Reaching a
  control near the bottom of a screen requires `scrollUntilExists`, whatever the
  Simulator happens to fit on one page.
- **Contrast findings the Simulator cannot produce.** See the audit gate above:
  `.contrast` is measured off rendered pixels, and the device renders through a
  P3 display with True Tone that the Simulator does not model. This is the one
  audit category where the device is the authority and the Simulator's green is
  not evidence.

Everything else in the suite is destination-independent by design, and should
stay that way. If a test can only pass on one destination, that belongs in its
doc comment, in the words of what it actually depends on.

## What only a device can settle

Some claims are structurally beyond both `swift test` and the Simulator suite,
and this list exists so they are tracked rather than assumed:

- **Which third of the depth buffer is the user's left.**
  `AwarenessZoneGeometry` derives it from frames carrying
  `CGImagePropertyOrientation.right`, and `AwarenessZoneGeometryTests` pins the
  ordering — but a test can only prove the code matches the assumption, never
  that the assumption matches the hardware. Getting it backwards would
  confidently send someone the wrong way, so this needs a LiDAR-device check:
  hold something clearly to one side, confirm the spoken side matches, then
  repeat on the other side. Both sides, because the failure being ruled out is
  a transposition — and a transposition passes a single-sided test half the
  time, which is the one result that would look like validation without being
  any.
- **That no reading survives a stop/start.** `latestFrame(orientation:)` drops
  frames older than the current `run(_:options:)`, which is what stops a check
  taken in one room being answered with the frame captured in another. The whole
  mechanism sits behind `#if canImport(ARKit)`, so the check is: take a reading,
  walk to a clearly different distance, take another, and confirm the second
  answer is not the first.
- **How long "Check once" waits for depth.** `AmbientSensingSource.sampleOnce`
  now waits for a frame that actually carries a depth map rather than for the
  first frame ARKit vends, because `sceneDepth` is populated several frames
  after the camera opens. The ARKit path compiles only for iOS and the
  Simulator delivers no frames, so nothing but a device can show whether one tap
  now answers with a distance where it used to answer "couldn't take a
  measurement", or whether three seconds is the right ceiling.
- **Proximity-pulse cadence.** The band boundaries and repeat intervals are
  unit-tested; whether the resulting rhythm reads as "getting nearer" to a hand
  is a judgement only a person holding the phone can make.
- **Live reading's auto-torch.** `FrameLuminanceTests` covers every pixel
  format and the video-range rescale against synthetic buffers. What it cannot
  cover is whether `dimThreshold` sits in the right place for a real
  auto-exposed camera in a real dim room, or whether three frames is long
  enough to avoid a strobe as the user's hand moves.
- **Sentence-level playback timing.** `ReadingPlayback` is pure and fully
  tested, and `SpeechRenderTarget.speak(_:)`'s continuation bookkeeping is
  unit-tested — but "does 'next' actually land between sentences" is a listening
  test.

## Recruiting field testers

NFB or ACB local chapters, accessibility Discord/forum communities, and
GitHub's accessibility open-source initiatives (see
[`COMMUNITY_GUIDELINES.md`](https://github.com/kevinle3212/sensebridge/blob/main/COMMUNITY_GUIDELINES.md))
are the likely channels. This is on the critical path, not a nicety — resolve
it early.

## The one sentence that matters most

If a blind person has not used a feature eyes-free and found it useful, it is
not validated — no amount of green CI substitutes for that.

---

Need help? See
[`SUPPORT.md`](https://github.com/kevinle3212/sensebridge/blob/main/SUPPORT.md).
