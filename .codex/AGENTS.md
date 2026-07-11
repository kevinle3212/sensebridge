# Codex Agent Notes — SenseBridge

Read root `AGENTS.md` first (doctrines, conventions, quality gates), then
`AGENT-CONTEXT.md` (current state — the Swift app is not scaffolded yet; never
assume code exists). This file adds Codex-specific mechanics only; global
Codex defaults live in `~/.codex/`.

## MCP and navigation

- Serena (`.codex/config.toml`) provides symbolic navigation and focused
  repository inspection; prefer it over raw text search.
- `graphify query "<question>"` answers codebase/architecture questions when
  `graphify-out/graph.json` exists (generated output is gitignored); run
  `graphify update .` after modifying code.

## Non-negotiables

- Awareness-not-safety wording for any physical-world output
  (`docs/safety-framing.md`) — route through the safety-framing-reviewer
  persona in `.agents/agents/`.
- On-device by default: no backend, no telemetry, no network round-trip for
  perception or reasoning (`docs/privacy.md`).
- Zero unlabeled UI elements; VoiceOver pass on changed UI.
- Never commit to `main`; conventional commit headers (enforced by
  `.githooks/commit-msg`). Never edit `legal/` without owner approval.
- AGPL and Apple `apple-amlr` licenses are hard blockers for models and
  dependencies.
- No secrets, tokens, or signing material in config files, prompts, or logs.

## Routing

- Invoke the matching skill in `.agents/skills/` before hand-rolling a
  workflow; persist review findings via `audits/scripts/new-audit.sh`
  (append-only).
- After repository changes, run the `update-context` skill so docs and agent
  instructions stay synchronized.
