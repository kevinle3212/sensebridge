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

# The Council

An independent multi-perspective review of an architectural decision **before**
it is approved and built. The point is to catch a decision that is expensive to
reverse while it is still cheap to change — and to make disagreement visible
instead of averaging it away. The Council advises; it does not merge, and it does
not stand in for the [ci-green-gate](../../../.agents/skills/ci-green-gate/SKILL.md)
or the owner's decision.

## When to convene

Convene for decisions that are **important and hard to reverse**:

- A new protocol seam or module boundary, or a change to the
  `SensingSource → perception → Reasoning → RenderTarget` pipeline shape.
- A model, runtime, or inference-placement choice (on-device vs. anything else).
- A dependency, MCP server, or tool that shifts the trust, privacy, or
  supply-chain boundary.
- Anything touching the on-device / serverless / no-telemetry posture.
- A change with safety-framing consequences for physical-world output.

Do **not** convene for routine, reversible, or well-specified work — that is
over-process. A change you can delete tomorrow does not need a council.

## Members (independent perspectives)

Each member reviews **independently first** — form its own position from the
decision and the code before reading the others, so the verdict reflects genuine
agreement, not the loudest voice. Map each to the existing persona so the Council
reuses project doctrine rather than reinventing it:

| Seat | Owns the question | Source |
| --- | --- | --- |
| Architecture | Does this respect inward-pointing dependencies and stay replaceable/deletable? | [api-design](../../../.agents/skills/api-design/SKILL.md) |
| Safety-framing | Can this ever produce a confidently-wrong physical-world statement? | [safety-framing-reviewer](../../../.agents/agents/safety-framing-reviewer.md) |
| Accessibility | Does every resulting surface stay fully VoiceOver-navigable, zero unlabeled? | [accessibility-reviewer](../../../.agents/agents/accessibility-reviewer.md) |
| Privacy/Security | Does anything cross the device boundary; is the trust/supply-chain surface sound? | [security-reviewer](../../../.agents/agents/security-reviewer.md), [`docs/PRIVACY.md`](../../../docs/PRIVACY.md) |
| Performance | Main-thread cost, latency, battery, thermal — realistic on-device? | [performance-reviewer](../../../.agents/agents/performance-reviewer.md) |
| Licensing | Any AGPL / `apple-amlr` / unverifiable-provenance blocker? | [model-license-audit](../../../.agents/skills/model-license-audit/SKILL.md) |
| Simplicity | Is this the smallest change that solves the real problem, or speculative? | global engineering standard |

Not every seat applies to every decision — seat only the ones the decision
actually touches, and say which you skipped and why.

## Process

1. **Frame.** State the decision, the alternatives considered, and what makes it
   hard to reverse. If alternatives are missing, that is itself a finding.
2. **Independent review.** Each seated perspective forms a position: `approve` /
   `approve-with-conditions` / `block`, with a one-line reason grounded in
   evidence (file:line, doc, or measurement — not vibes). For a genuinely
   consequential or contested decision, run the seats as independent subagents so
   positions form without groupthink; for a smaller one, reason each seat
   yourself but keep them genuinely separate.
3. **Surface disagreement.** Report where seats conflict verbatim; do not resolve
   a `block` by outvoting it. A single Critical safety-framing, accessibility, or
   privacy-boundary objection blocks by itself — these are not majority votes.
4. **Verdict.** One of:
   - **Approved** — no seat blocks; list any minor conditions.
   - **Approved with conditions** — proceed only after the listed conditions are
     met; name each and who owns it.
   - **Blocked** — state the blocking objection(s) and the smallest change that
     would unblock.
5. **Record.** For a decision worth remembering, persist the verdict and its
   rationale via [audit-refresh](../audit-refresh/SKILL.md)
   (category `general`, or the most specific matching category) so the reasoning
   survives, and capture durable lessons via the `vault-capture` skill.

## Honesty rule

The Council verifies design intent and reviewer judgement. It cannot prove
on-device latency/battery/thermal or blind-tester validation — state which
conditions still require device and human validation before real approval.
