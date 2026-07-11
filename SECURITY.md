# Security Policy

## Reporting a vulnerability

Report security issues privately to `kevinle3212@gmail.com`. Do not open a
public issue for a vulnerability report.

Please include:

- What you found and why it's a security issue.
- Steps to reproduce, if applicable.
- Affected version/commit.

You should get an acknowledgment within a few days. This is a solo-maintained
project, so response time depends on one person's availability — see
[`GOVERNANCE.md`](GOVERNANCE.md) for the bus-factor context.

## Scope

SenseBridge's MVP has **no backend and no server** — see
[`docs/architecture.md`](docs/architecture.md). That removes most classic
attack surfaces (nothing to breach, nothing to rate-limit, no database to
leak). What's actually in scope:

- **Camera, microphone, and photo-library handling** — the app's permission
  boundaries and how captured content is processed and discarded.
- **On-device biometric data** (facial-enrollment feature, deferred but
  designed now) — see [`docs/privacy.md`](docs/privacy.md) and
  [`security/THREAT-MODEL.md`](security/THREAT-MODEL.md) for the encrypted,
  on-device-only, consent-gated design.
- **Supply chain** — dependencies and any bundled on-device ML model. Model
  license and provenance issues (the AGPL/AMLR traps documented in
  [`docs/ai-models.md`](docs/ai-models.md)) are treated as security issues,
  not just legal ones, because an unvetted model is unvetted code.
- **Signing keys and CI secrets** for the eventual TestFlight/App Store
  pipeline — see [`docs/DISTRIBUTION.md`](docs/DISTRIBUTION.md). These never
  belong in the repository.
- **The optional, opt-in cloud-reasoning adapter** (not built yet) — user's
  own provider credentials, stored in Keychain, never shipped as project
  secrets.

## Out of scope (for now)

Account takeover, server-side issues, and anything requiring a backend the
MVP doesn't have. This will change if/when the optional cloud service is
built — this file will be updated at that point.
