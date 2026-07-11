# Copilot CLI instructions — SenseBridge

Follow root `AGENTS.md` first, then `AGENT-CONTEXT.md` for current state (the
Swift app is not scaffolded yet — never assume code exists). The GitHub-web
Copilot variant reads `.github/copilot-instructions.md`; both defer to
`AGENTS.md`.

## Strict defaults

- Awareness-not-safety wording for any physical-world output
  (`docs/safety-framing.md`); confidently-wrong spoken output is the
  worst-case bug in this project.
- On-device by default: no backend, telemetry, or network round-trip for
  perception/reasoning (`docs/privacy.md`).
- Zero unlabeled UI elements; VoiceOver pass on changed UI.
- Never commit to `main`; conventional commit headers; never edit `legal/`.
- AGPL and Apple `apple-amlr` licenses are hard blockers.
- No secrets, tokens, or signing material in instructions, logs, or prompts.
- Invoke the matching skill in `.agents/skills/` before hand-rolling a
  workflow; audits are append-only via `audits/scripts/new-audit.sh`.
