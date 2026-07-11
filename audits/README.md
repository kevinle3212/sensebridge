# Audits

Timestamped, append-only audit reports for SenseBridge. Read
[`AGENT-GUIDE.md`](AGENT-GUIDE.md) for the procedure and severity rubric, and
[`GOVERNANCE.md`](GOVERNANCE.md) for why reports are never rewritten in place.

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
| `testing`       | Unit / integration / accessibility / AI-eval / device / field coverage      |
| `dependencies`  | SwiftPM package freshness, vulnerabilities, provenance                      |

Append new categories here and in `audits/scripts/new-audit.sh` (`VALID_TYPES`)
together — they must stay in sync.
