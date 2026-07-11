---
name: performance
description:
    Use when changing the perception, reasoning, or output pipeline, or when
    latency, battery, or thermal behaviour could regress.
---

## Tool Fallback <!-- tool-fallback -->

- If a preferred tool, command, or skill is unavailable, failing, or a worse fit
  for the task, use the best available alternative rather than stopping or
  forcing it. Note which tool you used and why. Never fall back to a tool the
  repository or user has explicitly prohibited.

## Clarify Before Acting <!-- clarify-before-acting -->

If the performance target is unstated, ask for it before optimising. Measure
before tuning.

# Performance

Pairs with the [performance-reviewer](../../agents/performance-reviewer.md)
agent. The demanding path is continuous camera + depth + on-device inference.

## Budget and method

- **Measure first** with `OSSignposter` / Instruments; optimise the proven
  bottleneck, not a guess.
- **Thermal.** Watch `ProcessInfo.thermalState` and back off before throttling.
- **Battery.** Acceptable drain for the session pattern; no busy loops or stray
  wake-locks.
- **Neural Engine.** Run models on the ANE where possible; benchmark real
  on-device latency rather than trusting published numbers.
- **Main thread.** No perception/model work on it; UI stays responsive to
  VoiceOver during processing.
- **Memory.** Bound frame/audio buffers; release perception buffers promptly.

Record findings via `audits/scripts/new-audit.sh performance "<title>"`.
