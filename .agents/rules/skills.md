---
trigger: always_on
description: Skill routing for Antigravity in SenseBridge
---

Treat `.agents/manifest.json` as the single registry and `.agents/skills/` as
the only canonical skill source. Load one matching skill, then only the
references it names. Do not copy, edit, or extend harness adapters with
policy — `.claude/skills/`, `.cursor/rules/sensebridge-skills.mdc`, and
`.gemini/skills/sensebridge-router/SKILL.md` route here, they do not restate
policy.

Use BMAD skills (`bmad-*`) for product planning; `council` before an
important or hard-to-reverse architectural decision; `impeccable` for
production-grade website design execution — it is vendor-managed by
`npx impeccable install`/`update` and excluded from the skill lock's hashed
file set for that reason.

## Antigravity MCP servers

Antigravity's MCP configuration is user-global (`~/.gemini/config/mcp_config.json`,
shared across Antigravity 2.0, IDE, and CLI), not per-project. This repository
ships no project-level Antigravity MCP file — there is nothing to add here.
