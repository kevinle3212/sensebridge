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
- **Parallelism is cheaper.** Swift Testing runs tests in parallel in-process
  by default; XCTest parallelises by cloning simulators. On the fixture-heavy
  suites below, that difference compounds into CI minutes.
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
`xcodebuild test` for this reason.

## Coverage philosophy

All code ships with tests — nothing merges untested. Depth scales with risk:
chase exhaustive coverage where wrongness is dangerous (reasoning, phrasing,
awareness logic) and where regressions are silent (perception); for glue code
and SwiftUI views a minimal covering test suffices. A test you'll actually
maintain beats one that looks good in a report.

## Recruiting field testers

NFB or ACB local chapters, accessibility Discord/forum communities, and
GitHub's accessibility open-source initiatives (see
[`COMMUNITY_GUIDELINES.md`](../COMMUNITY_GUIDELINES.md)) are the likely
channels. This is on the critical path, not a nicety — resolve it early.

## The one sentence that matters most

If a blind person has not used a feature eyes-free and found it useful, it is
not validated — no amount of green CI substitutes for that.

---

Need help? See [`SUPPORT.md`](../SUPPORT.md).
