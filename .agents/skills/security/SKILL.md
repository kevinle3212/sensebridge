---
name: security
description:
    Use when changing permissions, sensors, network paths, logging, or data at
    rest. Protects the on-device privacy guarantee that is SenseBridge's core
    promise.
---

## Tool Fallback <!-- tool-fallback -->

- If a preferred tool, command, or skill is unavailable, failing, or a worse fit
  for the task, use the best available alternative rather than stopping or
  forcing it. Note which tool you used and why. Never fall back to a tool the
  repository or user has explicitly prohibited.

## Clarify Before Acting <!-- clarify-before-acting -->

If scope or intent is ambiguous, interview the user or surface assumptions before
changing anything.

# Security

Pairs with the [security-reviewer](../../agents/security-reviewer.md) agent and
[`security/THREAT-MODEL.md`](../../../security/THREAT-MODEL.md).

## Non-negotiables

- **On-device by default.** No user content (images, recognised text, audio,
  depth) leaves the device without explicit opt-in. Flag any new network call on
  a perception path.
- **No user content in logs.** Mark values private in `OSLog`/`Logger`; log
  events and states, not content.
- **Least-privilege permissions.** Request camera/mic/sensor access only when
  needed; usage-description strings must match real use.
- **Data at rest** uses Keychain / Data Protection, never plaintext.
- **Optional cloud path** (if any) is opt-in, encrypted in transit, and
  self-hostable.

## When to re-check the threat model

Any new sensor, permission, network path, or persisted data type. Complete
[`security/CHECKLIST.md`](../../../security/CHECKLIST.md) before merging such a
change. Report vulnerabilities privately per repo-root `SECURITY.md` — never in a
public issue.
