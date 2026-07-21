---
description: Write the mandatory per-session log entry under sessions/<date>/<HHMM>-PST.md and mirror substantive follow-ups into TODO.md, per the CLAUDE.md session-log rule.
---

# session-log

Write this session's log entry. The authoritative rule lives in
`CLAUDE.md` → "Session logs" — follow it exactly; this command only encodes
the mechanics so no session forgets a step.

## Steps

1. **Timestamp:** `TZ=America/Los_Angeles date "+%Y-%m-%d %H00"` → target
   file `sessions/<YYYY-MM-DD>/<HH00>-PST.md`. Create the directory if
   needed; if the file already exists, **append** a new entry — never
   overwrite.
2. **Ground the entry** in evidence: `git status --porcelain`,
   `git diff --stat`, and the actual conversation — not recollection.
3. **Compose the entry:** what happened, what got done (with file paths),
   and outstanding follow-ups as `- [ ]` TODO items. Do not pad with things
   that didn't happen.
4. **Mirror follow-ups into `TODO.md`** in the same change — every
   substantive follow-up, owner-gated or not, per the rule in `CLAUDE.md`
   and `AGENTS.md` → "When you can't do something". Use TODO.md's existing
   priority labels and grouping; skip items already tracked there.
5. **Report** both file paths. `sessions/` is gitignored — never try to
   commit it; `TODO.md` changes are left staged-ready for the owner.
