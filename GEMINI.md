# GEMINI.md — SenseBridge

All agent conventions live in [`AGENTS.md`](AGENTS.md) — read it first, then
[`AGENT-CONTEXT.md`](AGENT-CONTEXT.md) for the current state of the ground.
Claude-specific rules in [`CLAUDE.md`](CLAUDE.md) apply to any agent where
relevant. Do not duplicate instructions here; this file exists only so Gemini
tooling finds its entry point.

Highlights that must never be violated: awareness-not-safety wording for any
physical-world output, on-device by default (no backend, no telemetry), zero
unlabeled UI elements, conventional commit headers, never commit to `main`,
never edit `legal/` without owner approval. Serena MCP is wired via
[`.gemini/settings.json`](.gemini/settings.json); skills live under
[`.gemini/skills/`](.gemini/skills).
