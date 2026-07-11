---
name: model-license-audit
description:
    Use before adding, updating, or shipping any AI model or dependency.
    Verifies the license permits App Store distribution — AGPL and Apple's
    apple-amlr research-only license are hard blockers.
---

## Tool Fallback <!-- tool-fallback -->

- If a preferred tool, command, or skill is unavailable, failing, or a worse fit
  for the task, use the best available alternative rather than stopping or
  forcing it. Note which tool you used and why. Never fall back to a tool the
  repository or user has explicitly prohibited.

## Clarify Before Acting <!-- clarify-before-acting -->

If the model source, intended use, or license is unclear, do not assume it is
permissive. Interview the user or flag the ambiguity before proceeding.

# Model License Audit

License review is a **merge blocker**, not a formality. A model with the wrong
license cannot ship, no matter how good its output. See
[`docs/ai-models.md`](../../../docs/ai-models.md).

## Hard blockers (do not ship)

- **AGPL** (and other copyleft licenses incompatible with App Store
  distribution).
- **Apple `apple-amlr`** (research-only) and any "research use only" /
  "non-commercial" model license.
- Any model whose license terms are unknown or unverifiable.

## Checklist for any new model or model-bearing dependency

1. Identify the exact model, version, and upstream source.
2. Record its license verbatim and link the source.
3. Confirm the license permits **commercial, redistributed, App-Store**
   distribution of a bundled binary.
4. Confirm any dataset or base-model license does not impose downstream terms.
5. Record source, version, size, license, and Neural-Engine compatibility in
   [`models/README.md`](../../../models/README.md).
6. If anything is a blocker or unclear — stop and escalate; do not add it.

## Validation

Cross-check the recorded license against the blocker list above and note the
verification in the `dependencies` or `model-license` audit report
(`audits/scripts/new-audit.sh model-license "<short title>"`).
