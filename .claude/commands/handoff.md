---
description: Write a session handoff summary to NOTES.local.md (private durable trail) and tmp/handoff.md (auto-loaded on next /clear), so work survives context resets or running out of usage. Distills a public digest entry into NOTES.md only when the session produced a durable finding.
---

# handoff

Run this before `/clear`, or whenever the session is getting long and you want
a safety net. Both output files are gitignored — never commit them.

**The full handoff is private.** It goes to `NOTES.local.md` and
`tmp/handoff.md` — **never** verbatim into the public, committed
[`NOTES.md`](../../NOTES.md), because a handoff routinely carries absolute job
paths, machine state, and half-formed reasoning. Absolute `/Users/<name>/` paths
would also fail the pre-commit secret scanner and block the commit outright.

When a session produces a durable, contributor-facing finding, distill a short
entry into `NOTES.md`'s Digest as a separate step (5) — a pointer to the
canonical doc, never a copy of it. Most sessions produce nothing that qualifies.

## What to capture

Review the actual session — git status/diff, tasks completed, decisions made
and why, what's still in progress, open questions or blockers, and concrete
next steps. Be specific: file paths, not vague descriptions. Do not pad with
things that didn't happen.

## Steps

1. Run `git status --porcelain` and `git diff --stat` to ground the summary in
   what actually changed, not recollection.
2. Get a timestamp: `date "+%Y-%m-%d %H:%M %Z"`.
3. Compose one entry:

   ```markdown
   ## Handoff — <timestamp>

   **Done:** <what was completed, with file paths>
   **Why:** <the decisions/reasoning behind it, if non-obvious>
   **In progress / open:** <what's half-done, open questions, blockers>
   **Next steps:** <concrete next actions, in order>
   ```

4. **Append** that entry to `NOTES.local.md` (repo root) — the durable,
   scrollable, **private** trail; never overwrite it.
5. **Overwrite** `tmp/handoff.md` with that same entry only (not the whole
   history) — this is what the `SessionStart` hook auto-loads on the next
   `/clear` or fresh session, so keep it to just the latest handoff.
   **Auto-purge exception:** if this entry's `In progress / open` and
   `Next steps` sections are both empty — nothing outstanding, because the
   prior handoff's items are now all resolved and this session raised no new
   open item — do not write an entry at all. Instead **empty** `tmp/handoff.md`
   (zero-byte the file, keep it present) so the next `/clear` has nothing
   stale to auto-load. The full `Done`/`Why` record still goes to
   `NOTES.local.md` per step 4 regardless — only the auto-loaded pointer file
   gets purged, never the durable private trail.
6. **Only if** the session produced a durable finding a future contributor would
   otherwise rediscover the hard way: append a short entry to `NOTES.md`'s
   Digest — what was learned, plus a link to the doc that owns the detail. Strip
   machine paths and session mechanics. Skip this step by default; a routine
   session earns no public entry, and an empty digest beats a padded one.
7. Report the file paths written. Do not stage or commit them.
