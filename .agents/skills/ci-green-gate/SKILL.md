---
name: ci-green-gate
description:
    Use before merging, releasing, or cutting a beta build. Defines the blocking
    quality gates and the honesty rules about what CI can and cannot prove.
---

## Tool Fallback <!-- tool-fallback -->

- If a preferred tool, command, or skill is unavailable, failing, or a worse fit
  for the task, use the best available alternative rather than stopping or
  forcing it. Note which tool you used and why. Never fall back to a tool the
  repository or user has explicitly prohibited.

## Clarify Before Acting <!-- clarify-before-acting -->

If it is unclear whether a change targets a merge, a release, or a beta build,
ask before asserting the gates are satisfied. State assumptions first.

# CI Green Gate

The bar a change must clear before merge, release, or a TestFlight beta. Pairs
with `.github/workflows/` and the reviewer personas under `.agents/agents/`.

## Blocking gates

- **Build.** `xcodebuild build` (app scheme) and, where a package target
  exists, `swift build` complete with no errors.
- **Tests.** The suites in `docs/TESTING.md` pass — unit (reasoning, hedging,
  thresholds), integration (perception against fixtures), e2e (at least three
  per feature: happy path, error path, edge case), and any AI-evaluation
  checks wired into CI.
- **Accessibility.** Zero unlabeled elements on every screen; a VoiceOver pass
  on changed UI. This is a hard gate, not a coverage percentage — see the
  [accessibility](../accessibility/SKILL.md) skill.
- **Safety-framing.** Any change to spoken output, alerts, captions, or physical-
  world language clears the
  [safety-framing-reviewer](../../agents/safety-framing-reviewer.md): hedged
  language, no composed claims beyond the evidence, fail-safe-and-quiet.
- **Model-license clearance.** Any new or updated model or dependency clears the
  [model-license-audit](../model-license-audit/SKILL.md) skill; AGPL and Apple's
  `apple-amlr` research-only license are hard blockers.

## What CI cannot prove — state this honestly

CI validates code, not lived experience. Two things that matter most here are
**not** provable in an automated pipeline and must never be reported as green by
CI alone:

- **On-device latency, battery, and thermal** behaviour — measured on a real
  target iPhone via Instruments, not in a simulator run.
- **Real blind-tester validation** via TestFlight — the field signal that
  ultimately decides whether output is trustworthy.

When reporting gate status, say which gates a machine verified and which still
require device and human validation. Do not let a green pipeline imply the app
was validated by the people it is for.
