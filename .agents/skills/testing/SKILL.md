---
name: testing
description:
    Use when adding or changing tests, or before a beta build. Covers the
    unit / integration / e2e / accessibility / AI-eval / device / field test
    layers.
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

Full strategy: [`docs/TESTING.md`](../../../docs/TESTING.md). Chase coverage
where wrongness is dangerous, not for its own sake.

## Layers

- **Unit (Swift Testing).** Reasoning logic — reading-order, phrasing/hedging
  rules, awareness thresholds and hysteresis, output-profile selection. Aim high
  here; this is where a subtle bug produces a confidently-wrong statement.
- **Integration (Swift Testing).** Perception services against fixed image/audio
  fixtures; cover happy path and key failure modes (blurry image, no text,
  ambiguous object).
- **End-to-end (XCUITest).** Full user flows. Floor per feature: at least
  three E2E tests — one happy path, one error path, one edge case.
  Scripted-manual only where camera/depth resist automation.
- **Accessibility.** Every screen VoiceOver-navigable; zero unlabeled elements —
  a hard gate, not a percentage.
- **AI evaluation.** Held-out real-world images; check that composed scene
  sentences never assert more than the labels support. Eyeballed, not pass/fail.
- **Device.** Latency, battery, thermal on the real target iPhone via Instruments.
- **Field.** Real blind testers via TestFlight — the validation that matters most.

## Writing the tests

- **No untested code.** Every change lands with tests for the code it adds or
  alters — see the coverage philosophy in `docs/TESTING.md` for how deep.
- **Isolate every test.** Each gets a fresh instance — set up in `init`, tear
  down in `deinit`. No shared mutable state between tests: it is the usual
  source of order-dependence, and an order-dependent suite is a flaky suite.
- **Table-driven over copy-paste.** When the same assertion runs across a set of
  inputs (output profiles, hedging phrasings, fixture images), use
  `@Test(arguments:)` rather than duplicating the test body. One failure then
  names the input that broke. This is the shape most of our tests take — reach
  for it first.
- **Inject, don't touch the world.** Tests must not need a camera, a
  microphone, or a device. Mock the boundary — see the
  [swift-protocol-di-testing](../swift-protocol-di-testing/SKILL.md) skill.
- **Coverage on demand:** `swift test --enable-code-coverage`. A number, not a
  goal — read the coverage philosophy above before quoting it at anyone.

## Priority order

Correct hedging first, then not crashing, then performance. A test you will
maintain beats one that looks good in a report.
