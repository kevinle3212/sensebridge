---
name: concurrency-safety
description:
    Use when a change touches shared mutable state accessed from more than one
    execution context, a retry loop, or a call to a rate-limited API — in
    website/ or any product code. Catches race conditions and missing
    rate-limit handling before they ship.
---

## Tool Fallback <!-- tool-fallback -->

- If a preferred tool, command, or skill is unavailable, failing, or a worse fit
  for the task, use the best available alternative rather than stopping or
  forcing it. Note which tool you used and why. Never fall back to a tool the
  repository or user has explicitly prohibited.

## Clarify Before Acting <!-- clarify-before-acting -->

If it's unclear whether two execution paths can actually run concurrently, or
what a third-party API's real rate limit is, verify it (read the code, check
the API docs) before deciding the risk is real or ruling it out.

# Concurrency Safety — SenseBridge

**Both checklists — race conditions and rate limits — live in the global
`concurrency-safety` skill** (`~/.claude/skills/concurrency-safety/SKILL.md`).
Read it first. This file carries only this project's scope and its one
additional hard requirement.

## Where it applies here

`website/` and any product code (`app/` once scaffolded, `scripts/`, `tools/`,
CI workflows, git hooks). `website/` is static HTML/CSS today; the planned
React/Next.js migration will add real client-side state and async fetches, which
is the point at which this skill starts mattering there.

## Ordering against the Swift-specific reviews

This is the language-agnostic pass and runs **first**. Swift concurrency
*mechanics* — actor isolation, `@concurrent`, data-race compiler errors — belong
to the global `swift` skill's `swift-concurrency-6-2` reference and the
[swift-reviewer](../../agents/swift-reviewer.md) agent's "HIGH - Concurrency"
section. Rate limiting is covered here and nowhere else.

Pairs with [performance-reviewer](../../agents/performance-reviewer.md) (battery
and thermal cost of retries and polling) and
[security-reviewer](../../agents/security-reviewer.md) (any new network path or
public endpoint).

## The project-specific hard requirement

**A stale async response must never reach spoken or caption output.** The global
skill treats discarding out-of-order responses as good practice; here it is a
doctrine-level requirement. Announcing a stale result is a silently-wrong
statement about the physical world, which the awareness-not-safety doctrine
treats as the worst-case bug class. Tag every request and discard anything that
is no longer the latest before it reaches VoiceOver.

Adding a backend or public endpoint under `website/` is also a change to the
"serverless, no backend" posture — flag it to the [security](../security/SKILL.md)
skill and security-reviewer, since it may need a `docs/PRIVACY.md` and
threat-model update rather than just a code change.

## Recording findings

`audits/scripts/new-audit.sh performance "<title>"` or
`audits/scripts/new-audit.sh security "<title>"`, whichever invariant is at
risk. Honesty rule per [ci-green-gate](../ci-green-gate/SKILL.md): if a race
can't be reproduced deterministically in CI, say so and name what still needs
device verification.
