---
name: lessons-learned
description:
    Use after a mistake gets corrected or a problem takes substantial
    debugging/back-and-forth to solve. Captures the lesson in its correct
    durable home so it doesn't get relearned by this agent or another one.
---

## Tool Fallback <!-- tool-fallback -->

- If a preferred tool, command, or skill is unavailable, failing, or a worse fit
  for the task, use the best available alternative rather than stopping or
  forcing it. Note which tool you used and why. Never fall back to a tool the
  repository or user has explicitly prohibited.

## Clarify Before Acting <!-- clarify-before-acting -->

If it is unclear whether something is durable enough to record, or which home
it belongs in, ask rather than skip it or over-record. Routine fixes don't need
a question — just skip them.

# Lessons Learned — SenseBridge

**When to capture, how to write the entry, and the skip bar all live in the
global `lessons-learned` skill** (`~/.claude/skills/lessons-learned/SKILL.md`).
Read it first. This file names only where the three tiers land in this
repository.

Drives the `LEARNING.md` row of [`MEMORY.md`](../../../MEMORY.md)'s routing
table. `MEMORY.md` decides *where* durable knowledge lives; the global skill
decides *when* to capture and *how* to write it, so the two never drift.

## The three homes, here

Follow [`MEMORY.md`](../../../MEMORY.md)'s routing table exactly — don't
re-derive it:

1. **Repo-durable, SenseBridge-specific** → append to
   [`LEARNING.md`](../../../LEARNING.md). This is the default: it is the only
   tier the other tools reading this repo (Codex, Copilot, Continue, Gemini)
   will ever see.
2. **Cross-project, durable** → the `vault-capture` skill instead. Not both.
3. **Session-only, not yet provably durable** → Claude's private memory
   (`~/.claude/projects/<this>/memory/`). Claude-specific; invisible to every
   other tool here, which is why tier 1 is the default.

## `LEARNING.md` conventions

The global format applies. What is specific here:

- Heading: `## YYYY-MM-DD — short lesson title` — lower-case title fragment, to
  match this file's existing entries.
- If the lesson changes an actual rule, fix the rule's real home first
  (`AGENTS.md`, a `docs/` file, a skill); the `LEARNING.md` entry then narrates
  *why* it changed and links to it.

## Validation

Confirm the entry doesn't duplicate an existing `LEARNING.md` lesson, that any
linked rule file exists at the cited path, and that `vault-capture` (when used
instead) actually wrote to `~/Vault` rather than silently no-oping.
