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

# Concurrency Safety — Race Conditions and Rate Limits

Cross-language checklist for `website/` and any product code (`app/` once
scaffolded, `scripts/`, `tools/`, CI workflows, git hooks). Swift-specific
concurrency *mechanics* (actor isolation, `@concurrent`, data-race compiler
errors) belong to the
[swift-concurrency-6-2](../swift-concurrency-6-2/SKILL.md) skill and the
[swift-reviewer](../../agents/swift-reviewer.md) agent's "HIGH - Concurrency"
section — this skill is the language-agnostic pass that runs *before* those,
and the only one that covers rate limiting at all. Pairs with the
[performance-reviewer](../../agents/performance-reviewer.md) (battery/thermal
cost of retries and polling) and
[security-reviewer](../../agents/security-reviewer.md) (any new network path
or public endpoint) agents.

## When to activate

- The change introduces or edits shared mutable state read or written from
  more than one execution context: async handlers, event listeners, actors,
  background tasks, concurrently-running git hooks, or parallel CI jobs.
- The change adds or edits a network call, a retry loop, or a call to a
  third-party/rate-limited API (`gh api`, package registries, an optional
  future cloud inference path).
- The change adds a user-triggered action that can fire again before the
  first run finishes (button taps, VoiceOver-triggered actions, form submits,
  search-as-you-type).
- The change touches `website/` JS/TS (today static HTML/CSS; the planned
  React/Next.js migration will add real client-side state and async fetches)
  or a Node script under `scripts/`/`tools/`.

## Race conditions checklist

- **Check-then-act (TOCTOU).** Does the code check a condition then act on it
  without atomicity — check-file-exists then write, check-permission then use?
  Collapse the check and the act into one atomic step, or re-check after
  acquiring whatever lock/exclusivity you need.
- **Double-fire.** Can the same event or user action invoke the handler twice
  before the first call finishes? Guard with an in-flight flag or
  `AbortController` set *before* the async work starts, not a boolean flipped
  after the fact — that still lets a second call through the same gap.
- **Stale async responses.** For any async fetch/response that updates UI,
  state, or a spoken/caption string: tag requests (a sequence number or
  `AbortController`) and discard responses that are no longer the latest.
  This is a hard requirement for VoiceOver output specifically — announcing a
  stale result is a silently-wrong statement about the physical world, which
  the "awareness, not safety" doctrine treats as the worst-case bug class.
- **Shared mutable state across tasks.** Any `var`, module-level, or global
  value written from more than one `Task`, actor, timer, or event handler
  needs explicit synchronization — actor isolation in Swift (see
  swift-concurrency-6-2), a mutex/queue or single-writer pattern elsewhere.
- **File/process races.** Scripts and git hooks (`.githooks/*`,
  `tools/*.mjs`) that read-modify-write a file, or that may run concurrently
  with another hook or CI job, must not assume exclusive access. Use
  write-tmp-then-rename for atomic writes, or a lock file, instead of a bare
  read-modify-write.
- **Ordering assumptions.** Don't assume `Promise.all`, concurrent async
  tasks, or a CI job matrix complete in submission order — code that depends
  on completion order without enforcing it is a latent race.

## Rate limiting checklist

- Any call to an external/third-party API must handle a rate-limit response
  (HTTP 429, or the API's documented equivalent) with backoff and jitter — not
  a tight retry loop that hammers the same limit again immediately.
- Respect documented rate limits proactively: batch or throttle calls instead
  of firing one request per item in a loop (the same N+1 pattern
  swift-reviewer flags for network calls, generalized to any external API).
- User-triggered repeatable actions (search-as-you-type, repeated capture
  requests, re-announcement) need client-side debounce/throttle so a user
  can't accidentally spam a downstream call or drain battery — ties to the
  [performance](../performance/SKILL.md) skill's battery/thermal budget.
- If `website/` ever grows a backend or public endpoint (the planned
  Next.js migration is the likely trigger), that endpoint must be rate-limited
  per the global CLAUDE.md security section. Treat adding any such endpoint as
  a change to the "serverless, no backend" posture — flag it to the
  [security](../security/SKILL.md) skill and security-reviewer, since it may
  need a `docs/PRIVACY.md` and threat-model update, not just a code change.
- **Idempotency.** A retried request (network retry, CI re-run, a user tapping
  a button twice) must be safe to repeat — no double-submit side effects.

## Validation

For a fix, write or extend a test that reproduces the race (fire the action
twice, simulate an out-of-order response, simulate a 429) and confirm it now
behaves correctly. If a race can't be reproduced deterministically in CI,
say so plainly and note what still needs manual or device verification —
same honesty rule as the rest of the [ci-green-gate](../ci-green-gate/SKILL.md)
skill.

Record findings via `audits/scripts/new-audit.sh performance "<title>"` or
`audits/scripts/new-audit.sh security "<title>"`, whichever invariant is at
risk.
