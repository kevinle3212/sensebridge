---
name: monthly-log-archive
description:
    Use at the start of any session where today's local date is the 1st of
    the month — condenses last month's sessions/ logs into one file and
    builds an audits/ index for that month, without touching append-only
    audit reports.
---

## Tool Fallback <!-- tool-fallback -->

- If a preferred tool, command, or skill is unavailable, failing, or a worse fit
  for the task, use the best available alternative rather than stopping or
  forcing it. Note which tool you used and why. Never fall back to a tool the
  repository or user has explicitly prohibited.

## Clarify Before Acting <!-- clarify-before-acting -->

Before running this skill or producing output, if the request is ambiguous or the
desired outcome is unclear, interview the user with focused questions until intent
is unambiguous. State assumptions and confirm them before proceeding.

# Monthly Log Archive

Run this once per month, on or after the 1st, to keep `sessions/` (gitignored,
per [`AGENTS.md`](../../../AGENTS.md#session-logs)) from accumulating one file
per hour bucket indefinitely.

## Workflow

1. Check whether `sessions/<last-month>/SESSIONS.md` already exists — if so,
   the month is already condensed; stop.
2. Run:

   ```bash
   node tools/condense-monthly-logs.mjs
   ```

   This condenses last calendar month's `sessions/<YYYY-MM-DD>/*.md` files
   (each already a self-contained dated entry) into one
   `sessions/<YYYY-MM>/SESSIONS.md`, chronologically concatenated, then
   removes the now-redundant per-day directories. `sessions/` is entirely
   gitignored local scratch, so this is a plain merge, not a history rewrite.
3. The same run also builds `audits/<YYYY-MM>/INDEX.md` — a table linking to
   that month's append-only audit reports (`audits/<category>/YYYYMMDD-*.md`)
   in place. **It never moves, edits, or deletes an audit report** — audits
   are append-only (`audits/AGENT-GUIDE.md`, root `CLAUDE.md`'s Skills and
   agents section), so condensing them the way sessions are condensed would
   violate that. The index file itself is derived and safe to regenerate on
   a rerun.
4. To condense a specific month (e.g. backfilling), pass
   `--month=YYYY-MM`: `node tools/condense-monthly-logs.mjs --month=2026-06`.

## Notes

- This skill only fires reliably if a session actually starts on the 1st and
  the model notices the date and this description. For a guaranteed trigger
  regardless of whether a session happens to start that day, wire a
  scheduled check instead (a monthly cron via the `schedule` skill, or a
  `SessionStart` hook in `.claude/settings.json` that runs
  `tools/condense-monthly-logs.mjs` when `date +%d` is `01`) — ask before
  adding either, since both touch shared harness config.
- If `sessions/<month>/` has nothing for the target month, the script is a
  no-op (prints "nothing to condense") — safe to run speculatively.
