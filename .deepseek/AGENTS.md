# DeepSeek Harness Notes — SenseBridge

Read root [`AGENTS.md`](../AGENTS.md) first (doctrine, conventions, quality
gates), then [`AGENT-CONTEXT.md`](../AGENT-CONTEXT.md) for current state. This
file adds `dsh`-specific mechanics only and deliberately restates no policy —
the canonical tree is [`.agents/`](../.agents/), and a rule written twice
becomes two rules that drift.

## What this harness is

`dsh` is [DeepSeek Harness](https://github.com/deepseek-ai/deepseek-harness), a
plugin-based agent harness from DeepSeek AI. Relevant mechanics:

- Binary `dsh`, published as `@deepseek-ai/dsh` (MIT).
- Profiles rather than a single mode: `tui`, `web`, `headless`.
  `dsh --profile headless "<task>"` answers one task and exits.
- Config is `cordis.yml`, composed from overlays via `--patch`.
- `dsh --dump-default-config` prints the installed version's real schema. Author
  against that, never against remembered syntax.
- The web profile serves a local UI on `127.0.0.1:3080`. That is a
  long-running local server, so the repository rule applies: do not start it
  unless explicitly asked.

## Booting it here

```sh
dsh --profile tui --patch ./.deepseek/cordis.yml
```

The overlay exists so repository guards apply. Booting a bare profile skips
them, which is the one thing not to do in this repository.

## Guard reuse, and where it stops

[`cordis.yml`](cordis.yml) wires `@deepseek-ai/dsh-hooks-claude-code`
(BSD-3-Clause) at [`../.claude/settings.json`](../.claude/settings.json), so the
guards under `.claude/hooks/` run unmodified. Same intent as
`.codex/hooks/dispatch.sh`, but the bridge is first-party, so there is no shim
to maintain and no Stop-schema incompatibility to work around.

**Coverage is partial.** The project config declares `SessionStart`,
`PreToolUse`, `PostToolUse`, `Stop`, and `PostToolBatch`; the bridge documents
`PreToolUse`, `PostToolUse`, `UserPromptSubmit`, and `Stop`. `SessionStart` and
`PostToolBatch` are **not carried** under `dsh`, so do not read a green `dsh` run
as evidence the repository gates passed.

That gap is asserted, not merely documented.
[`tools/check-deepseek-bridge.mjs`](../tools/check-deepseek-bridge.mjs) runs in
`npm run check` and fails the build in **both** directions: if
`.claude/settings.json` gains an event the bridge cannot carry, and if the
recorded gap ever overstates reality. Its own regression suite is
[`tools/tests/check-deepseek-bridge.test.mjs`](../tools/tests/check-deepseek-bridge.test.mjs).

The checker has three layers. The first two are static and always run. The third
resolves this overlay with the real binary via `dsh --dump-config` — offline, no
API key, no network, no agent boot — and is **skipped with an explicit note**
while `dsh` is absent, never silently. Installing the harness is what closes
that last layer; nothing else needs doing by hand.

## Status

Not yet usable. Two things are outstanding, both owner actions:

1. `@deepseek-ai/dsh` is not installed.
2. No `DEEPSEEK_API_KEY` exists anywhere on this machine — every occurrence
   found in the 2026-08-17 `.env` audit was blank. See
   [`sessions/2026-08-17/1500-PST.md`](../sessions/2026-08-17/1500-PST.md).

Both packages are pre-1.0 release candidates and moved versions mid-session, so
pin exact versions when installing, per the dependency rules in root
`AGENTS.md`.
