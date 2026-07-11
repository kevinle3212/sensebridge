---
name: api-design
description:
    Use when designing internal module boundaries — SensingSource, perception
    services, the Reasoning layer, and RenderTarget output abstractions.
---

## Tool Fallback <!-- tool-fallback -->

- If a preferred tool, command, or skill is unavailable, failing, or a worse fit
  for the task, use the best available alternative rather than stopping or
  forcing it. Note which tool you used and why. Never fall back to a tool the
  repository or user has explicitly prohibited.

## Clarify Before Acting <!-- clarify-before-acting -->

If the boundary or contract is ambiguous, interview the user before committing to
an interface. State assumptions first.

# API Design

"API" here means **internal Swift module boundaries**, not a network API —
SenseBridge is serverless. See
`docs/planning/SenseBridge-03-Technical-Architecture.md`.

## Principles

- **Protocol-oriented seams.** Model the pipeline as protocols —
  `SensingSource` (camera, mic, depth inputs), perception services, the Reasoning
  layer, and `RenderTarget` (speech, caption, haptic outputs) — so each stage is
  replaceable and testable with fixtures.
- **Depend on protocols at boundaries**, isolate side effects (capture, model
  inference) at the edges, keep reasoning logic pure and unit-testable.
- **Multi-sense extensibility.** The `RenderTarget` abstraction reserves a clean
  place for future haptic/caption channels without reworking reasoning.
- **Stable contracts.** Perception records feeding Reasoning are versioned and
  documented; a change to that record type is a reviewed contract change.
- **Deletable modules.** Any new module should be removable; no hidden coupling
  across layers.

Keep the layering strict: dependencies point inward, domain logic independent of
capture and rendering frameworks.
