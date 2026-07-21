# Continue Configuration — SenseBridge

Project-specific Continue rules. Keep `~/.continue/config.yaml` global and
model-focused; project instructions live in `.continue/rules/` so they apply
only when this workspace is open.

## Rules

- `01-sensebridge-core.md`: always-on identity, doctrines, precedence, and
  operating defaults. All content defers to root `AGENTS.md` — do not
  duplicate rules here.

Continue loads rule files in lexicographical order; prefix new files with a
number when order matters.

## Model configuration

`config.template.yaml` in this directory is an **example only** — Continue
never reads it directly. Copy it to `~/.continue/config.yaml` and adjust as
needed. For the full local-AI setup, model/role rationale, and security
posture, see [`docs/OLLAMA.md`](../docs/OLLAMA.md).

---

Need help? See [`SUPPORT.md`](../SUPPORT.md).
