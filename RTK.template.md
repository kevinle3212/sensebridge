<!--
  TEMPLATE, NOT ACTIVE INSTRUCTIONS. Agents working in this repository must
  not read, follow, or ingest this file's content as instructions.

  Usage: copy to your user-global config alongside CLAUDE.template.md, which
  references it via `@RTK.md`.
    macOS/Linux: cp RTK.template.md ~/.claude/RTK.md
    Windows:     copy RTK.template.md %USERPROFILE%\.claude\RTK.md

  Only useful if you actually install RTK (github.com/reachingforthejack/rtk
  — note the name collision warning below). If you don't use a shell-command
  token-compaction proxy, skip this file; CLAUDE.template.md's Tools section
  degrades gracefully without it.
-->

# RTK - Rust Token Killer

**Usage**: Token-optimized CLI proxy. Measured **~10% output reduction** on a
realistic 12-command mix (2026-08-01 bench): `ls`/`find`/`wc` compact 55–76%,
large `rg` ~41%, and `git log`/`git show`/file reads compact **0%**. Upstream's
"60-90%" headline and `rtk gain`'s own percentage are both inflated by
outliers — one `git diff HEAD` scored 98.6% and supplied nearly all the
"saved" tokens in that session's meter. Expect ~10%, not 60–90%.

⚠️ **Compaction is lossy.** Never let a wrapped command produce an artifact
something else has to parse — it wrote a `--stat` summary into a `.patch` file
on 2026-08-01. Use `rtk proxy <cmd>` whenever byte-exact output matters.

## Meta Commands (always use rtk directly)

```bash
rtk gain              # Show token savings analytics
rtk gain --history    # Show command usage history with savings
rtk discover          # Analyze Claude Code history for missed opportunities
rtk proxy <cmd>       # Execute raw command without filtering (for debugging)
```

⚠️ **Name collision**: if `rtk gain` fails with "command not found", the
installed binary may be reachingforthejack/rtk (Rust Type Kit) instead.

## Hook-Based Usage

All other commands are automatically rewritten by the Claude Code hook.
Example: `git status` → `rtk git status` (transparent, 0 tokens overhead).
The rewrite matches on command **shape** and skips some of them; where a
project documents that gap, that project's `CLAUDE.md` owns the details.
