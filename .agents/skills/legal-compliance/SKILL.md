---
name: legal-compliance
description:
    Use when a change touches privacy, data handling, permissions, biometric or
    camera capture, spoken safety-adjacent output, App Store positioning, or the
    legal/ documents.
---

## Tool Fallback <!-- tool-fallback -->

- If a preferred tool, command, or skill is unavailable, failing, or a worse fit
  for the task, use the best available alternative rather than stopping or
  forcing it. Note which tool you used and why. Never fall back to a tool the
  repository or user has explicitly prohibited.

## Clarify Before Acting <!-- clarify-before-acting -->

Legal-adjacent changes are high-stakes. If scope or intent is unclear, interview
the user before editing anything under `legal/`.

# Legal Compliance — SenseBridge

**The regimes, the triage table, and the "when to get counsel" line live in the
global `legal-compliance` skill**
(`~/.claude/skills/legal-compliance/SKILL.md`) — accessibility law, privacy law,
US and Oregon consumer protection, international regimes, and liability. Read
it first. This file carries only this project's triggers and its own documents.

**Never edit the documents under [`legal/`](../../../legal)** — privacy policy,
terms, disclaimer — without explicit owner approval. This skill flags when a
change may require legal review or a doc update; it does not authorise the edit.

## Triggers specific to this project

- **The on-device guarantee.** Any new data captured, stored, or transmitted, or
  any change to on-device-by-default, must be reconciled against
  `legal/PRIVACY_POLICY.md` **and** `docs/PRIVACY.md`. Divergence between what
  the code does and what those documents promise is the finding, not a nitpick.
- **Permissions, biometric, and camera capture.** New sensor or camera use, or
  anything touching biometric-adjacent data, carries exposure that varies
  sharply by jurisdiction — see the global skill's privacy reference on
  biometric statutes before assuming a design is safe.
- **Safety-adjacent output.** Spoken descriptions of the physical world must
  stay inside the awareness-not-safety framing and the disclaimer
  (`legal/DISCLAIMER.md`, `docs/SAFETY-FRAMING.md`). A framing change is a
  legal change here, not a copy change.
- **App Store positioning.** Store copy must not claim a mobility- or
  navigation-safety device. Apply the same bar to the marketing site.
- **Model and data licensing.** Defer to the
  [model-license-audit](../model-license-audit/SKILL.md) skill, which knows this
  project's `apple-amlr` and provenance constraints.

## Output

Surface the trigger and the affected document to the owner; never silently
change `legal/`. Record any accepted follow-up as an audit item.
