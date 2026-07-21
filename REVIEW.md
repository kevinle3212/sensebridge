# REVIEW.md — SenseBridge Review Guidance

Highest-priority, review-only instructions for Claude Code's built-in
`/code-review` (and the managed GitHub-App review). This file **extends**, never
replaces, the built-in review: it sets severity thresholds, skip paths, and the
project-specific checks the stock reviewer cannot know. General project context
lives in [`CLAUDE.md`](CLAUDE.md) and [`AGENTS.md`](AGENTS.md) — do not restate it
here. Manual review, the [reviewer personas](.agents/agents), and the
[ci-green-gate](.agents/skills/ci-green-gate/SKILL.md) remain the authority; an
automated pass complements them, it does not sign off for them.

## Severity — project overrides

- **Safety-framing defects are Critical, not nits.** Any spoken, caption, or
  haptic string that asserts unearned certainty about the physical world (drops
  the hedge — "looks like", "appears to be" — or claims a safety/navigation
  guarantee) is the worst-case bug in this project, worse than a crash. Flag it
  Critical and route to the
  [safety-framing-reviewer](.agents/agents/safety-framing-reviewer.md). See
  [`docs/SAFETY-FRAMING.md`](docs/SAFETY-FRAMING.md).
- **Unlabeled UI elements are blocking, not stylistic.** A control, image, or
  interactive element reachable by VoiceOver with no accessibility label is a
  hard-gate failure (zero unlabeled elements), not a suggestion. See
  [`docs/ACCESSIBILITY.md`](docs/ACCESSIBILITY.md).
- **Privacy-boundary violations are Critical.** Any new network round-trip that
  carries perception/surroundings data off-device without explicit, revocable
  consent plus a [`docs/PRIVACY.md`](docs/PRIVACY.md) update breaks the on-device
  doctrine. Flag Critical even if the code "works".
- **Main-thread perception/inference is High.** Model or perception work on the
  main thread regresses VoiceOver responsiveness.

## Required project checks (add to the default set)

- Reasoning logic stays pure and framework-independent; dependencies point inward
  along `SensingSource → perception → Reasoning → RenderTarget`. Flag any coupling
  of reasoning to a capture or render framework. See
  [api-design](.agents/skills/api-design/SKILL.md).
- New model or dependency → must clear
  [model-license-audit](.agents/skills/model-license-audit/SKILL.md); **AGPL and
  Apple `apple-amlr` are hard blockers**. Flag an unaudited license addition High.
- `website/` copy obeys honesty-over-hype: never imply the app is available
  (no CTA implies a download exists), never break safety-framing. See
  [`.agents/context/DESIGN.md`](.agents/context/DESIGN.md).
- Docs sync: a behaviour/model/permission/dependency change with no matching
  `docs/` + `README.md`/`SECURITY.md` update is an incomplete change — flag it.

## Skip paths (do not spend review budget here)

- Generated / vendored: `graphify-out/`, `.nexus/`, `tmp/`, `logs/`,
  `website/node_modules/`, any lockfile (`website/package-lock.json`).
- Append-only governance artifacts under `audits/` — never "fix" a past report.
- `legal/**` — owner-gated; never propose edits (also denied in
  `.claude/settings.json`).
- Pre-existing dead code: mention once, do not file per-occurrence findings.

## Verification bar & volume

- Prefer few high-confidence findings over breadth. Do not report a correctness
  bug you cannot tie to a concrete failing input/state.
- Cap nits: at most the few most valuable; never drown a Critical safety-framing
  or accessibility finding under style noise.

## What CI and this review cannot prove

State it plainly in the summary: on-device latency/battery/thermal and
blind-tester (VoiceOver, eyes-free) validation are **not** verifiable by any
automated pass. A green review never implies the app was validated by the people
it is for. See [ci-green-gate](.agents/skills/ci-green-gate/SKILL.md).
