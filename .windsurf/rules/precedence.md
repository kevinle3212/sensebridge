---
trigger: always_on
description: Guidance precedence for Cascade in SenseBridge
---

1. User instructions in the active task.
2. Root `AGENTS.md` — authoritative conventions, doctrines, quality gates.
3. This `.windsurf/rules/` directory.
4. `CLAUDE.md` / `GEMINI.md` — the same rules restated for other assistants;
   useful precedent, not binding on Cascade.
5. General repository documentation (`docs/`, `README.md`).

Current state (`AGENT-CONTEXT.md`): the Swift app under `app/` is not
scaffolded yet — never assume code exists. Non-negotiables: hedged
awareness-not-safety wording for physical-world output, on-device by default,
zero unlabeled UI elements, no commits to `main`, no edits under `legal/`,
AGPL / `apple-amlr` licenses blocked.
