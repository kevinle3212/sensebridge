# CLAUDE.md — SenseBridge

The Claude Code layer only. Project doctrine, quality gates, coding conventions,
session logs, and docs sync are cross-harness and live in
[`AGENTS.md`](AGENTS.md) — **read it first**. Personal preferences live in
`~/.claude/CLAUDE.md`. Nothing is restated here that either file already owns.

Rules a machine can check are enforced by hooks, not prose. The rule ↔ hook map
is [`docs/TOOLING.md`](docs/TOOLING.md#rules-enforced-mechanically--the-claudemd--hook-map);
`tools/check-settings-hooks.mjs` fails the build if a hook goes missing.

## Orientation

- Doctrine and gates: [`AGENTS.md`](AGENTS.md).
- Product: [`docs/PRODUCT.md`](docs/PRODUCT.md) · Architecture:
  [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md).
- Setup: [`docs/ENVIRONMENT.md`](docs/ENVIRONMENT.md) · Testing:
  [`docs/TESTING.md`](docs/TESTING.md).
- `website/CLAUDE.md` carries the site's design doctrine and loads itself
  whenever a session touches `website/`.

## Hand it back testable

A change the owner cannot try is not finished. Green gates prove the code
compiles; they prove nothing about the thing they actually asked for.

- After any change to `app/` code, rebuild for the device and install it with
  `npm run app:install`, unprompted, as the last step before reporting. A Stop
  hook blocks the turn until that happens. Doc-only and comment-only changes are
  exempt and clear it with `touch tmp/.last-app-install`.
- **A simulator build does not count.** ARKit, LiDAR depth, Apple Intelligence,
  haptics, and the camera produce nothing there, and only the device destination
  exercises signing and arm64 — build for the device even when the simulator
  build already passed.
- The phone must be unlocked or the developer disk image will not mount. Say
  that rather than reporting a bare failure.
- Installing to the owner's own device is **not** owner-gated — unlike every
  `git`/`gh` command, which still is.
- `npm run` lists the rest of the suite; see
  [`docs/ENVIRONMENT.md`](docs/ENVIRONMENT.md#command-center).

## Tool priority — Serena, then RTK, then defaults

Hooks route the first two tiers (`prefer-serena.sh`, `prefer-rtk-shape.mjs`).
What you must apply by hand is the judgment they cannot:

1. **Serena's symbol tools** for anything touching a code file.
2. **RTK** for shell operations. Its compaction is lossy and fails *silently* —
   write `rtk proxy <cmd>` whenever a call needs raw fidelity (a patch file, a
   value captured into a variable, a search that must see every line).
3. **Defaults** for the rest, narrowest first: `Grep`/`Glob` before `Read`,
   before raw `Bash`.

**Say which tier served a non-trivial action.** Serena calls surface as their own
tool name; RTK's rewrite is silent by design, so name it or it is invisible.
Mechanism and shape matrix: [`docs/TOOLING.md`](docs/TOOLING.md).

## Skills and agents

`.agents/skills/*` is one canonical tree shared by every harness.
`.agents/manifest.json` registers each skill, `.agents/skill-lock.json` hash-locks
the bodies, and `node tools/skill-lock.mjs` (`check:skills` / `sync:skills`)
verifies or regenerates the lock. After repo changes, run
[update-context](.agents/skills/update-context/SKILL.md).

`impeccable` is the one vendor-managed skill, excluded from the lock hash because
`npx impeccable update` owns its churn — never hand-edit it, your changes will be
overwritten.

## Harness parity — what is specific here

`.codex/hooks/dispatch.sh` `exec`s the same `.claude/hooks/*` scripts Claude Code
runs. Codex's `Stop` hook expects `{"continue": true|false}`, not Claude's
`decision: block` schema, so those three gates run as a passthrough there — see
the comment block atop `dispatch.sh`. `limit-agent-fanout.sh` is the one
Claude-only hook. DeepSeek Harness needs no shim at all —
[`.deepseek/cordis.yml`](.deepseek/cordis.yml) points its first-party
`dsh-hooks-claude-code` bridge straight at `.claude/settings.json`, but only
`PreToolUse`/`PostToolUse`/`UserPromptSubmit`/`Stop` are documented, so
`SessionStart` and `PostToolBatch` stay unverified there. MCP servers are
declared per-harness in each one's native
config (`.cursor/mcp.json`, `.gemini/settings.json`, `.vscode/mcp.json`);
Antigravity has no per-project MCP surface, noted in
[`.agents/rules/skills.md`](.agents/rules/skills.md) rather than faked here.

## Branching

Branch names and commit headers are hook-checked. What is not: keep `main`
deployable, prefer a PR so CI runs, and **use no worktrees unless explicitly
requested** — work in the actual checkout on a branch, and say so if the harness
mandates isolation (e.g. background jobs).
