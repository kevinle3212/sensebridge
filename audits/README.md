# Audits

Timestamped, append-only audit reports for SenseBridge. Read
[`AGENT-GUIDE.md`](AGENT-GUIDE.md) for the procedure and severity rubric, and
[`GOVERNANCE.md`](GOVERNANCE.md) for why reports are never rewritten in place.

Reports themselves (everything under the category subdirectories below) are
**gitignored, local-only** — a filed report can name a specific unpatched
gap in enough detail to double as an attacker checklist, so they're kept off
of a repo that may go public one day. This page, `AGENT-GUIDE.md`,
`GOVERNANCE.md`, `scripts/`, and `templates/` stay tracked — they describe the
*process*, not project-specific findings.

## Generate a report

```bash
audits/scripts/new-audit.sh <type> "<short title>"
```

Reports land in `audits/<type>/<UTC-timestamp>-<slug>.md` with git metadata
prefilled from the template in [`templates/`](templates).

## Categories

| Category        | Focus                                                                       |
| --------------- | --------------------------------------------------------------------------- |
| `general`       | Cross-cutting work that spans several categories                            |
| `accessibility` | VoiceOver, Dynamic Type, contrast, focus management, rotor — the core bar   |
| `safety-framing`| Awareness-not-safety doctrine: hedged phrasing, no confidently-wrong output |
| `privacy`       | On-device processing, no telemetry by default, no user content in logs      |
| `security`      | Threat model, permissions, data-at-rest, supply chain                       |
| `performance`   | On-device latency, battery, thermal budgets, model inference time           |
| `model-license` | Bundled-model and dependency licenses (AGPL / `apple-amlr` are hard blocks) |
| `documentation` | Doc accuracy and sync with behaviour, env, and workflows                    |
| `testing`       | Unit / integration / e2e / accessibility / AI-eval / device / field coverage |
| `dependencies`  | SwiftPM package freshness, vulnerabilities, provenance                      |

Append new categories here and in `audits/scripts/new-audit.sh` (`VALID_TYPES`)
together — they must stay in sync.

---

Need help? See [`SUPPORT.md`](../SUPPORT.md).
