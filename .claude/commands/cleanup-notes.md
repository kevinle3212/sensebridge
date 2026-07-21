---
description: Groom NOTES.local.md — collapse resolved handoff entries, consolidate duplicated reference material, and surface still-open items — with a backup in tmp/ and a before/after report. Never touches NOTES.md or git.
---

# cleanup-notes

Groom `NOTES.local.md` (repo root). It accumulates `/handoff` entries and
personal reference material until the signal drowns; this command compacts it
without losing anything that is still live.

**This file is private and gitignored.** Nothing here is ever committed,
staged, or copied into the public `NOTES.md` — promoting a finding to the
public digest is `/handoff` step 6's job, done deliberately, never as a side
effect of cleanup.

## Steps

1. **Safety checks.** Confirm `git check-ignore NOTES.local.md` succeeds and
   the file exists. If either fails, stop and report — do not create the file.
2. **Backup.** Copy it to `tmp/NOTES.local.backup-<YYYYMMDD-HHMM>.md`
   (`tmp/` is gitignored). Keep the two most recent backups; delete older
   ones.
3. **Read the whole file**, then classify every block:
   - **Header** (the privacy preamble) — keep verbatim.
   - **Reference material** (setup guides, machine config, local
     conventions) — keep, but merge duplicates and delete sections fully
     superseded by later ones; note in the report what was merged/dropped.
   - **Handoff entries** (`## Handoff — <timestamp>`) — keep the most recent
     3 verbatim. For each older entry: if its open items and next steps are
     all resolved or superseded (verify against the repo, `TODO.md`, and
     later entries — don't guess), collapse it to one line under a
     `## Handoff archive` section: `- <timestamp> — <one-line summary>`.
     If anything is still open, keep the entry intact.
4. **Surface open items.** Collect every still-unresolved item found during
   step 3 into a short `## Open items` section directly under the header
   (deduplicated, each pointing at its source entry). Do not move private
   items into tracked files; if one clearly belongs in `TODO.md`, list it in
   the report as a suggestion instead.
5. **Write the groomed file back** (same path), preserving section order:
   header → open items → reference → recent handoffs → handoff archive.
6. **Report:** before/after line counts, entries collapsed, sections
   merged/dropped, open items surfaced, backup path. Do not stage or commit
   anything.
