# `.claude/hooks/global/` — hooks for *your* config, not this project's

Everything in this directory is a **template**. Nothing here is registered in
[`.claude/settings.json`](../../settings.json), and nothing here runs when you
work on SenseBridge unless you install it yourself. That is deliberate: these
four guards enforce project-agnostic rules from the global engineering
standard, so they belong in one place — your user config — where every
repository inherits them instead of only this one.

The companion file is [`.claude/settings.global.json`](../../settings.global.json),
which already registers all four. Install both together or neither; a
registration whose script is missing fails silently, which is strictly worse
than no guard at all.

```bash
cp .claude/hooks/global/*.sh .claude/hooks/global/*.mjs ~/.claude/hooks/
cp .claude/hooks/global/tests/* ~/.claude/hooks/tests/
chmod +x ~/.claude/hooks/*.sh
# then merge .claude/settings.global.json into ~/.claude/settings.json
```

## What each guard does

| Script | Blocks |
| --- | --- |
| `guard-attribution.sh` | Assistant attribution (`Co-Authored-By`, `Generated with [Claude]`, session URLs, 🤖) in any command that writes git or GitHub history. The harness prompt asks for these trailers; this guard is what makes the standing rule against them stick. |
| `guard-commit-shape.sh` | Commit headers that are not `type(scope): subject`, and branch names that are not `<type>/<subject>`. Skips commands that take the message from a file or reuse an existing one, since it cannot see that text. |
| `guard-long-running-server.sh` | Unasked dev/preview servers (`npm run dev`, `astro preview`, `vite`, `python -m http.server`, …), which outlive the turn and hold a port. Owner hatch: append `--force-server`. |

Self-checks live in [`tests/`](tests) and run under `npm run check:hook-tests`
from this checkout, so a change here is verified here before it is copied out.

## Keeping the two copies honest

`tools/check-settings-hooks.mjs` compares each script against the installed
copy at `~/.claude/hooks/` **when that copy exists**, and fails on a mismatch.
A machine that has never installed them sees nothing — the check is a
drift detector for people who did install, not a setup requirement for people
who did not.
