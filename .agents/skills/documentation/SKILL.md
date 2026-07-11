---
name: documentation
description:
    Use when behaviour, build steps, models, permissions, or workflows change and
    the docs must stay accurate. Pairs with the update-context skill.
---

## Tool Fallback <!-- tool-fallback -->

- If a preferred tool, command, or skill is unavailable, failing, or a worse fit
  for the task, use the best available alternative rather than stopping or
  forcing it. Note which tool you used and why. Never fall back to a tool the
  repository or user has explicitly prohibited.

## Clarify Before Acting <!-- clarify-before-acting -->

If the intended doc audience or scope is unclear, ask before rewriting.

# Documentation

Pairs with the [documentation-reviewer](../../agents/documentation-reviewer.md)
agent. SenseBridge is docs-rich; stale docs mislead contributors and users.

## Rules

- Update the **nearest authoritative doc** in the same change; do not duplicate
  long guidance across files.
- Keep links live — `CONTRIBUTING.md` references `app/`, `.github/` templates,
  `docs/ENVIRONMENT.md`, and `docs/TESTING.md`; verify targets exist.
- Follow `AGENTS.md` copy conventions (Title Case labels; sentence case prose;
  preserve acronyms like `VoiceOver`, `OCR`, `HIG`, `ANE`).
- Anything about spoken output honours the awareness-not-safety doctrine.
- Purge stale references when code, screens, models, or workflows move.

## Validation

Confirm links resolve and any documented command still runs. Record a doc audit
with `audits/scripts/new-audit.sh documentation "<title>"` when the pass is
substantial.
