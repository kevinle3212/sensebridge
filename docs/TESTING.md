# Testing Strategy

Coverage targets here are pragmatic for a solo developer, not enterprise
dogma. The aim is confidence where bugs hurt most — perception correctness,
accessibility, and awareness-not-safety phrasing (see
[`docs/safety-framing.md`](safety-framing.md)) — not a coverage percentage for
its own sake.

| Layer | What | How | Target |
|---|---|---|---|
| Unit | Pure logic: reading-order from OCR, phrasing/hedging rules, awareness thresholds, output-profile selection | XCTest, no device, fixture perception records | High coverage on the Reasoning layer specifically — this is where a subtle bug produces a confidently wrong statement |
| Integration | Perception services against fixed inputs (OCR, detection, sound classification) | XCTest with bundled fixtures | Happy path plus key failure modes (blurry image, no text found, ambiguous object) per service |
| Accessibility | Every screen is VoiceOver-navigable; labels/traits present; focus behaves | Xcode Accessibility Inspector + manual VoiceOver checklist per screen | Zero unlabeled interactive elements — a hard gate, not a percentage |
| AI evaluation | Quality of OCR/labels/scene descriptions on a held-out set of real-world images | Small eyeballed evaluation harness, run periodically | No regressions in reading accuracy; no new over-confident or hallucinated claims |
| End-to-end | Full flows (open app → Read → capture → hear result; Awareness → fixture route → cautious alerts) | XCUITest where stable; scripted-manual where camera/depth resist automation | Each core flow has at least one automated or scripted-manual pass before every beta build |
| Device | Real-device behavior: latency, battery, thermal, Neural Engine load | Instruments profiling on the actual iPhone target | Responsive; no thermal throttling in a normal session; acceptable battery drain |
| Field | Real blind users, real environments, real tasks | TestFlight beta with recruited testers, structured feedback | At least one or two testers completing real tasks unaided and willing to keep using it |
| Beta | Wider TestFlight group once MVP is stable | Public TestFlight, feedback channel, issue triage | Stable, crash-rare, generating real usage feedback before any App Store consideration |

## Coverage philosophy

Chase high coverage where wrongness is dangerous (reasoning, phrasing,
awareness logic) and where regressions are silent (perception). Don't chase
coverage on glue code and SwiftUI views the compiler and manual use already
give confidence in. A test you'll actually maintain beats one that looks good
in a report.

## Recruiting field testers

NFB or ACB local chapters, accessibility Discord/forum communities, and
GitHub's accessibility open-source initiatives (see
[`COMMUNITY_GUIDELINES.md`](../COMMUNITY_GUIDELINES.md)) are the likely
channels. This is on the critical path, not a nicety — resolve it early.

## The one sentence that matters most

If a blind person has not used a feature eyes-free and found it useful, it is
not validated — no amount of green CI substitutes for that.
