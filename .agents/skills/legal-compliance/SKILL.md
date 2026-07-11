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

# Legal Compliance

Never edit the documents under [`legal/`](../../../legal) (privacy policy, terms,
disclaimer) without explicit owner approval. This skill flags when a change may
require legal review or a doc update — it does not authorise the edit.

## Triggers that need review

- **Privacy / data handling.** Any new data captured, stored, or transmitted;
  any change to the on-device-by-default guarantee — reconcile with
  `legal/PRIVACY_POLICY.md` and `docs/privacy.md`.
- **Permissions / biometric / camera capture.** New sensor or camera use, or
  anything touching biometric-adjacent data, has legal exposure across
  jurisdictions.
- **Safety-adjacent output.** Spoken descriptions of the physical world must
  stay within the awareness-not-safety framing and the disclaimer
  (`legal/DISCLAIMER.md`, `docs/safety-framing.md`).
- **App Store positioning.** Store copy must not claim a mobility- or
  navigation-safety device.
- **Model/data licensing.** Defer to the `model-license-audit` skill.

## Output

Surface the trigger and the affected document to the owner; do not silently
change `legal/`. Record any accepted follow-up as an audit item.
