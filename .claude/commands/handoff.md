---
description: The durable-state command. tmp/handoff.md holds the live plan — written before the first edit, updated as each item verifies, emptied when the work ships with anything deferred moved to TODO.md. Invoke this command to reconcile that file against reality and append a session record to NOTES.local.md before a context reset, or with `resume` to pick up inherited work.
argument-hint: "[resume | (nothing = reconcile the plan and record the session)]"
---

# handoff

One file owns everything that has to survive a `/clear`, a crash, or a usage
cutoff: **`tmp/handoff.md`, and it holds the plan itself.** Paths are relative to
the project root, or to `~/.claude/` on a global run — the global `CLAUDE.md`'s
"Plans and durable state" owns which.

| Artifact | What it is | Written | Scope |
| --- | --- | --- | --- |
| `tmp/handoff.md` | The live plan: checklist of intent vs. reality, plus the hard-won knowledge behind it | **Before the first edit**, then after every step as items **verify** | One per project; emptied when the work ships |
| `NOTES.local.md` | The append-only private trail of what each session actually did | Once, at the end of a session or before `/clear` | One per project |
| `TODO.md` | Deferred items only — work consciously postponed, with the owner's agreement | When the owner approves a deferral, and when a plan is retired | One per project |

`tmp/handoff.md` is auto-loaded by a `SessionStart` hook, which is exactly why it
must be emptied when the work ships — a finished plan left in place becomes
stale context injected into every future session.

**Writing the plan is not gated on this command.** `~/.claude/CLAUDE.md` §5
requires it before the first edit of any multi-step task, whether or not
`/handoff` is ever invoked. This file is the authority on the *format* and on
the reconciliation/retirement steps.

## Modes

Read the mode off `$ARGUMENTS`; default is reconcile-and-record.

- `resume` → **Resume mode.** Run at the start of a session that inherits work.
- *(nothing)* → **Reconcile-and-record.** Run before `/clear`, before stepping
  away, when usage is about to run out, or whenever the session is long enough
  that losing it would hurt.

---

## The plan file — `tmp/handoff.md`

1. Create `tmp/` if absent and confirm it is gitignored
   (`git check-ignore -v tmp/handoff.md`; add `tmp/*` to `.gitignore` if not).
2. **Never overwrite a plan whose items are still open.** If unrelated work
   arrives while a plan is live, fold it in as its own task block with a line
   saying why the two are in one file — or finish and retire the current plan
   first. One file, so this is a real decision, not a filing convenience.
3. Flip `- [ ]` to `- [x]` only when the item is **verified** — a passing
   command, not a landed edit.
4. **Write for a cold reader** — a future agent or the owner, with zero session
   context. Name the files, symbols, and exact commands; no pronouns pointing
   back at a conversation nobody can see.
5. **Retire it when the work ships:** move anything still outstanding to
   `TODO.md`, move anything with lasting value to its real home (`docs/`, a
   session log), then **empty the file** — zero bytes, keep it present.

```markdown
# PLAN — <task, one line>
Started <YYYY-MM-DD HH:MM TZ> · Branch `<name>` · Status: in progress | blocked | done

## Goal
<what "done" means, in verifiable terms>

## Decisions taken
<owner-approved choices and their rationale, so they are not re-litigated —
omit if none>

## Tasks
- [x] <action> — verify: <command or check> — **done <YYYY-MM-DD>**
- [ ] <action> — verify: <command or check>

## What worked
<approach, command, or API that succeeded, and why>

## What didn't
<dead end, failing command with its actual output, wrong assumption — so it
isn't retried>

## Context to reload
<files and symbols touched · decisions made and their rationale · open
questions · the exact next command to run>
```

## Resume mode — `/handoff resume`

**Read `tmp/handoff.md` before exploring the codebase.** Reconcile it against
`git status --porcelain` and `git diff --stat`: the working tree is the source
of truth, the plan is only the intent. Report any divergence — an item marked
`[x]` with no matching change, or a change no item claims — rather than trusting
the file. Then continue the plan, updating it per step.

If `tmp/handoff.md` is empty, there is no inherited work; check `TODO.md` for
deferred items instead.

---

## Reconcile-and-record — `/handoff`

**The record is private.** It goes to `NOTES.local.md` — **never** verbatim into
a tracked, public notes file, because it routinely carries absolute
`/Users/<name>/` paths, machine state, and half-formed reasoning. Many repos
also run a secret/PII scanner in pre-commit that would reject such a commit
outright.

### Steps

1. Ground the summary in what actually changed, not recollection: run
   `git status --porcelain` and `git diff --stat`. If this isn't a git repo,
   summarize from the session itself instead.
2. **Reconcile the plan first.** Flip every newly-verified item in
   `tmp/handoff.md` to `- [x]`, update its `Status:` line, and top up
   `What worked` / `What didn't` / `Context to reload`. If the work ran to more
   than one step and no plan exists, write one now — that is the step that was
   skipped, and writing it late is better than not at all.
3. **Verify the private files are ignored before writing to them.** Run
   `git check-ignore -v NOTES.local.md` and `git check-ignore -v tmp/handoff.md`.
   If either is *not* ignored, say so and stop — do not create a file that would
   land in a commit. Offer to add the entries to `.gitignore` first.
4. Get a timestamp: `date "+%Y-%m-%d %H:%M %Z"`.
5. **Append** one entry to `NOTES.local.md` (project root) — the durable,
   scrollable, private trail; never overwrite it:

   ```markdown
   ## Session — <timestamp>

   **Plan:** `tmp/handoff.md` — <n>/<m> done, status <…> · or "retired, work shipped"
   **Done:** <what was completed, with file paths>
   **Why:** <the decisions/reasoning behind it, if non-obvious>
   **Open:** <what's half-done, open questions, blockers — one line each; the
   plan file holds the detail>
   **Next steps:** <concrete next actions, in order>
   ```

6. **Retire the plan only if the work has shipped** and every item is `[x]`.
   Retiring means: move outstanding items to `TODO.md` (interviewing the owner
   first per `~/.claude/CLAUDE.md` §5 — deferral is their call, not yours), then
   empty `tmp/handoff.md` to zero bytes. A plan that is merely
   complete-but-uncommitted **stays** — it still holds needed state, and
   emptying it would destroy the ship commands. Say which you did and why.
7. **Only if** the session produced a durable finding a future contributor would
   otherwise rediscover the hard way, **and** the repo already has a tracked
   public notes digest (`NOTES.md` or the equivalent the project uses): append a
   short entry to it — what was learned, plus a link to the doc that owns the
   detail. Strip machine paths and session mechanics. Do not create that file if
   the project doesn't already have one. Skip this step by default; a routine
   session earns no public entry, and an empty digest beats a padded one.
8. Report the file paths written, emptied, and deleted. Do not stage or commit
   them.
