---
name: council
description:
    Use before approving an important or hard-to-reverse architectural decision —
    a new protocol seam or module boundary, a model/runtime choice, a
    dependency or MCP that changes the trust or privacy boundary, a change to
    the on-device/serverless posture, a safety-framing-relevant pipeline change,
    or any decision the author cannot cleanly undo later. Convenes independent
    reviewer perspectives, surfaces disagreement, and returns a verdict with
    conditions. Advisory — it informs approval, it does not replace the human
    owner's sign-off or the blocking CI gates.
user-invocable: true
argument-hint: "<the decision to review, or a path/doc describing it>"
---

## Tool Fallback <!-- tool-fallback -->

- If a preferred tool, command, or skill is unavailable, failing, or a worse fit
  for the task, use the best available alternative rather than stopping or forcing
  it. Note which tool you used and why. Never fall back to a tool the repository
  or user has explicitly prohibited.

## Clarify Before Acting <!-- clarify-before-acting -->

If the decision, its alternatives, or what "approval" means here is ambiguous,
ask one round of high-signal questions first. State assumptions before convening.

# The Council — SenseBridge

**The process lives in the global `council` skill**
(`~/.claude/skills/council/SKILL.md`): when to convene, the independent-review
rule, how disagreement is surfaced, the verdict forms, and the honesty rule.
Read it first. This file carries only this project's seats and triggers.

The Council advises. It does not merge, and it does not stand in for
[ci-green-gate](../ci-green-gate/SKILL.md) or the owner's decision.

## Additional triggers specific to this project

Beyond the global list, convene for:

- A change to the `SensingSource → perception → Reasoning → RenderTarget`
  pipeline shape.
- An inference-placement choice — on-device versus anything else.
- Anything touching the on-device / serverless / no-telemetry posture.
- A change with safety-framing consequences for physical-world output.

## Seats, mapped to this project's personas

Seat only what the decision touches, and say which you skipped and why.

| Seat | Owns the question | Source |
| --- | --- | --- |
| Architecture | Does this respect inward-pointing dependencies and stay replaceable/deletable? | [api-design](../api-design/SKILL.md) |
| Safety-framing | Can this ever produce a confidently-wrong physical-world statement? | [safety-framing-reviewer](../../agents/safety-framing-reviewer.md) |
| Accessibility | Does every resulting surface stay fully VoiceOver-navigable, zero unlabeled? | [accessibility-reviewer](../../agents/accessibility-reviewer.md) |
| Privacy/Security | Does anything cross the device boundary; is the trust/supply-chain surface sound? | [security-reviewer](../../agents/security-reviewer.md), [`docs/PRIVACY.md`](../../../docs/PRIVACY.md) |
| Performance | Main-thread cost, latency, battery, thermal — realistic on-device? | [performance-reviewer](../../agents/performance-reviewer.md) |
| Licensing | Any AGPL / `apple-amlr` / unverifiable-provenance blocker? | [model-license-audit](../model-license-audit/SKILL.md) |
| Simplicity | Is this the smallest change that solves the real problem, or speculative? | global engineering standard |

A Critical objection from the safety-framing, accessibility, or
privacy-boundary seat blocks by itself. These are not majority votes.

## Recording a verdict here

Persist the verdict and its rationale via
[audit-refresh](../audit-refresh/SKILL.md) (category `general`, or the most
specific matching one) so the reasoning survives, and capture durable
cross-project lessons via `vault-capture`.

## Honesty rule, applied here

The Council cannot prove on-device latency, battery, or thermal behaviour, and
cannot stand in for blind-tester validation. Name which conditions still require
device and human verification before the decision is genuinely approved.
