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

# Lessons Learned

Drives the `LEARNING.md` row of [`MEMORY.md`](../../../MEMORY.md)'s routing
table. `MEMORY.md` decides *where* durable knowledge lives; this skill decides
*when* to capture it and *how* to write the entry, so the two never drift.

## When to activate

- A bug, build failure, or design question took multiple failed attempts, a
  long debugging session, or `superpowers:systematic-debugging` to resolve, and
  the root cause or fix would not be obvious to someone reading the final
  diff alone.
- The user corrected your approach ("no, not that", "stop doing X") — record
  what to avoid and why.
- The user confirmed a non-obvious approach worked ("yes exactly", "keep doing
  that") after you made an unusual call — record what to repeat and why.
  Corrections are easy to notice; confirmations are quieter and just as
  valuable — don't only record failures.
- A cross-project pattern emerged that would help in a *different* repo, not
  just this one.

**Skip:** typos, routine fixes, anything already obvious from the code or
diff, one-line corrections. If in doubt, prefer skipping over noise — see the
"user memory" exclusions in the global `~/.claude/CLAUDE.md` for the same bar
applied to Claude's private memory.

## Decide the home first

Follow [`MEMORY.md`](../../../MEMORY.md)'s routing table exactly — don't
re-derive it here:

1. **Repo-durable, SenseBridge-specific** (changed how *this* project works) →
   append to `LEARNING.md`. Format below.
2. **Cross-project, durable** (would help in another repo) → run the
   `vault-capture` skill instead. Do not also write it to `LEARNING.md` — one
   fact, one home.
3. **Session-only, not yet provably durable** → Claude's private memory
   (`~/.claude/projects/<this>/memory/`), per the global CLAUDE.md memory
   rules. This tier is Claude-specific; other agentic tools reading this repo
   (Codex, Copilot, Continue, Gemini) never see it, which is why tier 1 is the
   default for anything that should reach them too.

If the lesson changes an actual rule (a convention, a gate, a doctrine), fix
the rule's real home first (`AGENTS.md`, a `docs/` file, a skill) — the
`LEARNING.md` entry then narrates *why* the rule changed and links to it. Never
let the `LEARNING.md` entry become the only place the rule lives.

## `LEARNING.md` entry format

- Newest entry at the top (reverse-chronological); the file itself is
  append-only in the git-history sense — never edit or delete a past entry.
- Heading: `## YYYY-MM-DD — short lesson title` (absolute date, lower-case
  title fragment, matches the file's existing entries).
- Body: 2-4 sentences — what happened, why it was non-obvious, and a link to
  wherever the actual rule/fix now lives if one changed.
- Before adding, skim the existing entries for a near-duplicate; extend or
  supersede rather than restate.

## Validation

Confirm the new entry doesn't duplicate an existing `LEARNING.md` lesson,
confirm any linked rule file actually exists at the path cited, and confirm
`vault-capture` (when used instead) actually wrote to `~/Vault` rather than
silently no-oping.
