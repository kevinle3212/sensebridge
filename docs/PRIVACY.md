# Privacy (Engineering Doctrine)

This is the engineering-facing description of SenseBridge's data handling. For
the legal-facing version, see [`legal/PRIVACY_POLICY.md`](../legal/PRIVACY_POLICY.md)
(informational, requires attorney review before public launch).

## The core guarantee: no server, nothing to breach

SenseBridge's MVP has no backend and no central data store. This is an
architectural fact, not a policy promise — see
[`docs/ARCHITECTURE.md`](ARCHITECTURE.md#backend-architecture-there-is-none-and-that-is-correct). Most classic
privacy attack surfaces (server breach, cross-user data leakage, third-party
data brokering) simply do not exist because there is no server for them to
exist on.

## What happens to user content

- Images and recognized text are **processed and discarded**, not persisted
  without a specific reason the user can see.
- **Never logged.** See the logging rules in
  [`docs/ARCHITECTURE.md`](ARCHITECTURE.md) — no recognized text, images, or
  audio ever goes into application logs, only events and states.
- **Optional settings sync** (iCloud) carries only preferences — never
  content — and rides on Apple's iCloud security model rather than a
  project-run service.

## Biometric data (facial enrollment — deferred, designed now)

Facial recognition is not in the MVP, but because getting this wrong later is
expensive, the storage model is designed now:

- Face embeddings live **only on the device**, in an encrypted store
  (Keychain-protected keys, data-protection classes requiring device unlock).
- Embeddings **never leave the device** and are **explicitly excluded from
  any sync** by default.
- The user can **view and delete** enrolled data at any time.
- Only **consent-enrolled** people are matched; everyone else is rendered as
  "person." No public or open-ended recognition, ever.

This design is deliberately both the ethical choice and the legally safest
one — biometric law (Illinois BIPA, Texas CUBI, GDPR Article 9, CCPA/CPRA
among others) is a real, fast-moving exposure. See
[`legal/PRIVACY_POLICY.md`](../legal/PRIVACY_POLICY.md) for the full legal
notes. **None of this is legal advice — get counsel before shipping any
facial-enrollment feature.**

## The optional cloud adapter (not built, opt-in when it exists)

If a user ever enables an optional cloud-reasoning provider: explicit opt-in,
clear disclosure of what's sent where, off by default, and any credential the
user supplies is stored in their own Keychain — the project ships no cloud
secrets of its own.

## Secrets

The MVP has essentially no secrets: no backend, no API keys. CI (GitHub
Actions) uses repository secrets only for release-signing credentials, never
committed to the repository.

---

Need help? See [`SUPPORT.md`](../SUPPORT.md).
