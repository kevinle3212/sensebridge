---
description: Groom TODO.md — verify each open item against the current repo state, annotate completed ones per the file's completion rule, flag stale or superseded items, and report. Never silently deletes.
---

# todo-groom

Groom `TODO.md` (repo root). Items go stale silently: work lands without the
box being ticked, priorities shift, and blocked items unblock. This command
re-grounds the list in the actual repo state.

## Steps

1. **Read `TODO.md` fully**, including its own conventions (legend, grouping,
   and the **Item Completion** rule — completed items keep their text and
   gain a bold `**Done/Fixed YYYY-MM-DD** — <what/how verified>` annotation;
   never just flip the checkbox).
2. **Verify every open item against evidence** — the files, docs, scripts,
   or workflows it names; `GAPS.md`; recent entries in `NOTES.md`. For each:
   - **Actually done** → apply the completion annotation, citing what you
     verified (file paths, not vibes), and move it to **Completed** if the
     file's structure calls for that.
   - **Superseded / no longer applicable** → don't delete; propose it in the
     report with the evidence, and only annotate after the owner confirms.
   - **Blocked or owner-gated** → check the blocker still exists; if it
     cleared, say so and restore the item to actionable.
   - **Still open** → leave untouched. Do not rewrite item text or reshuffle
     priorities on your own judgment.
3. **Check for gaps in the other direction:** unresolved `- [ ]` items in
   recent `sessions/` logs or handoffs that the follow-up rule says should be
   in `TODO.md` but aren't. Add them under the appropriate group.
4. **Report:** items completed (with evidence), items proposed for
   retirement, items added, items left open. Do not stage or commit —
   hand the diff to the owner.
