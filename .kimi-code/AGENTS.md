# Kimi Agent Notes — SenseBridge

Read root `AGENTS.md` first (doctrines, conventions, quality gates), then
`AGENT-CONTEXT.md` (current state — `app/` has an early scaffold but no
distributable build; never assume more exists than that file describes). This
file adds Kimi-specific mechanics only; global Kimi defaults live in
`~/.kimi-code/`.

## What Kimi picks up automatically

Kimi Code discovers most of this repository's existing agent configuration
without any Kimi-specific copy of it. Do not duplicate these into
`.kimi-code/`; a second copy only drifts:

- **Context** — root `AGENTS.md` and `CLAUDE.md`, merged from the project root
  down to the working directory, plus this file.
- **Skills** — `.agents/skills/` and `.claude/skills/`. Both are merged because
  `merge_all_available_skills = true` is set in `~/.kimi-code/config.toml`;
  without it Kimi would load only the first directory it found and silently
  ignore the other. (`.codex/` ships mechanics and MCP config only — it has no
  skills tree for Kimi to merge.)
- **Agents** — `.agents/agents/`, so the review personas
  (`safety-framing-reviewer`, `accessibility-reviewer`, `security-reviewer`,
  `dependency-auditor`, …) are selectable with `kimi --agent <name>`.
- **MCP** — this repository's `.mcp.json`, which is where Serena is declared.
  `~/.kimi-code/mcp.json` adds only machine-wide servers on top.

## MCP and navigation

- Serena (repo `.mcp.json`) provides symbolic navigation and focused
  repository inspection; prefer it over raw text search.
- `codegraph explore "<question>"` answers codebase/architecture questions
  against `.codegraph/` (generated output is gitignored). The `post-commit`
  hook runs `codegraph sync` for you; run it by hand after changing code
  outside a commit.

## Permissions live in the user config, not here

Kimi Code 0.32.0 has **no project-scoped permission override**. A repository's
`.kimi-code/local.toml` accepts only `[workspace] additional_dir`, so every
approval rule — including the ones this repository cares about, such as never
editing `legal/` and treating `git`/`gh` as owner-gated — is enforced from
`~/.kimi-code/config.toml`.

Consequence worth stating plainly: **a fresh machine that has not had that
user-level config installed gets none of those guardrails.** Do not assume
checking out this repository is sufficient to inherit them. Validate any
machine with `kimi doctor` before trusting the policy.

## Non-negotiables

- Awareness-not-safety wording for any physical-world output
  (`docs/SAFETY-FRAMING.md`) — route through the safety-framing-reviewer
  persona in `.agents/agents/`.
- On-device by default: no backend, no telemetry, no network round-trip for
  perception or reasoning (`docs/PRIVACY.md`). Opt-in crash reporting is the
  single sanctioned exception.
- Zero unlabeled UI elements; VoiceOver pass on changed UI.
- Never commit to `main`; conventional commit headers (enforced by
  `.githooks/commit-msg`). Never edit `legal/` without owner approval.
- AGPL and Apple `apple-amlr` licenses are hard blockers for models and
  dependencies.
- No secrets, tokens, or signing material in config files, prompts, or logs.
- Never start a long-running local server (`npm run dev`, `astro preview`)
  unless explicitly asked; build to verify, then hand over the command.

## Routing

- Invoke the matching skill in `.agents/skills/` before hand-rolling a
  workflow; persist review findings via `audits/scripts/new-audit.sh`
  (append-only).
- After repository changes, run the `update-context` skill so docs and agent
  instructions stay synchronized.
