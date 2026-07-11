---
name: testing
description:
    Use when adding or changing tests, or before a beta build. Covers the
    unit / integration / accessibility / AI-eval / device / field test layers.
---

## Tool Fallback <!-- tool-fallback -->

- If a preferred tool, command, or skill is unavailable, failing, or a worse fit
  for the task, use the best available alternative rather than stopping or
  forcing it. Note which tool you used and why. Never fall back to a tool the
  repository or user has explicitly prohibited.

## Clarify Before Acting <!-- clarify-before-acting -->

If the test scope or acceptance bar is unclear, interview the user before
writing tests. State assumptions first.

# Testing

Full strategy: [`docs/TESTING.md`](../../../docs/TESTING.md) and
`docs/planning/SenseBridge-04-Engineering-Quality.md`. Chase coverage where
wrongness is dangerous, not for its own sake.

## Layers

- **Unit (XCTest).** Reasoning logic — reading-order, phrasing/hedging rules,
  awareness thresholds and hysteresis, output-profile selection. Aim high here;
  this is where a subtle bug produces a confidently-wrong statement.
- **Integration.** Perception services against fixed image/audio fixtures; cover
  happy path and key failure modes (blurry image, no text, ambiguous object).
- **Accessibility.** Every screen VoiceOver-navigable; zero unlabeled elements —
  a hard gate, not a percentage.
- **AI evaluation.** Held-out real-world images; check that composed scene
  sentences never assert more than the labels support. Eyeballed, not pass/fail.
- **Device.** Latency, battery, thermal on the real target iPhone via Instruments.
- **Field.** Real blind testers via TestFlight — the validation that matters most.

## Priority order

Correct hedging first, then not crashing, then performance. A test you will
maintain beats one that looks good in a report.
