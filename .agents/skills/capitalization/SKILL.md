---
name: capitalization
description:
    Use when writing or reviewing any heading, title, label, button, status
    chip, or full-sentence copy — determines whether it takes Title Case or
    sentence case, and how to apply each correctly.
---

## Tool Fallback <!-- tool-fallback -->

- If a preferred tool, command, or skill is unavailable, failing, or a worse fit
  for the task, use the best available alternative rather than stopping or
  forcing it. Note which tool you used and why. Never fall back to a tool the
  repository or user has explicitly prohibited.

## Clarify Before Acting <!-- clarify-before-acting -->

If a string's role is ambiguous (heading vs. prose, label vs. sentence), infer
it from context (surrounding Markdown structure, UI element type) and state the
assumption rather than blocking. Only ask when the same string is genuinely used
both ways and the two rules would produce different output.

# Capitalization — SenseBridge

**The algorithm lives in the global `capitalization` skill**
(`~/.claude/skills/capitalization/SKILL.md`): which style applies where, the
Title Case and sentence case rules, strict identifier headers, and the
worked examples. Read it first. This file carries only what is specific to
this repository.

Canonical rule source for `AGENTS.md` → "UI and copy conventions". The
convention here is the global default, confirmed by audit across this repo's
~700 existing headings rather than newly imposed: one Title Case H1 per file,
sentence case for everything under it.

## This repository's named exceptions

- **Fixed boilerplate section labels.** `Tool Fallback`, `Clarify Before
  Acting`, and `Audit Output` are reused verbatim across every skill and agent
  file here. They are labels, not prose headings — leave them Title Case, and
  don't invent new ones. If a genuinely new cross-cutting boilerplate section
  is needed, ask before deciding its case.
- **Numbered top-level chapters.** In `CLAUDE.md`, `CLAUDE.template.md`, and
  `deprecated/planning/*` (the former planning series), a plain-numbered `##`
  (`## 1. Executive Review`, `## 19. Open Source Strategy`) is a chapter title
  — Title Case. This does **not** extend to letter-prefixed sub-items in the
  same documents (`### B1. Getting the app onto devices`, `### C1. Why Apache
  2.0 …`, GAPS.md's `### M2 — …`), which stay sentence case.
- **Audit and report templates.** `audits/templates/audit-template.md` uses
  Title Case for its section labels (`## Files Inspected`, `## Issues Found`)
  — fixed form fields instantiated into every generated report, not prose.
  Its `# {{TITLE}}` is a template placeholder; leave it alone.
- **Filename-as-title headers** here include `# GAPS.md` and
  `# PROJECT_OVERVIEW.md` — bare filenames, nothing to case.
- **Command-name H1s** under `.claude/commands/`, `.codex/`, and `.github/`
  (`# cleanup-commit`, `# docker-clean`, `# handoff`) are identifiers. A
  command file with a genuinely descriptive title — `# Security Review —
  SenseBridge` — is ordinary prose and follows the normal H1 rule.

## This repository's acronyms and proper nouns

Preserve exactly, in any position. Extend this list rather than guessing casing
for a new term — `rg` for it first to see how the repo already spells it.

`VoiceOver`, `OCR`, `HIG`, `ANE`, `TestFlight`, `SenseBridge`, `Swift`,
`SwiftUI`, `Xcode`, `iOS`, `macOS`, `API`, `CI`, `CI/CD`, `PR`, `URL`, `FAQ`,
`SDK`, `MIT`, `AGPL`, `WCAG`.

## Interaction with this repo's doctrines

- Spoken, caption, and haptic strings follow sentence case **and** the
  awareness-not-safety hedging rule in `docs/SAFETY-FRAMING.md`. That framing
  constraint is independent of casing and is never relaxed to improve a
  heading — a casing pass must not weaken a required hedge.
- The [log-markdown](../log-markdown/SKILL.md) skill's "sentence-case headings"
  rule for `logs/` is the global default restated for emphasis, not a special
  case; it exists there to rule out ALL-CAPS or ad hoc casing in run notes.
