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
| AI evaluation | Quality of OCR/labels/scene descriptions on a held-out set of real-world images | Small eyeballed evaluation harness, run periodically | No regressions in reading accuracy; no new over-confident or hallucinated claims |
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
coverage is the manual/VoiceOver pass. `CustomSoundClassifier` is not — after
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
