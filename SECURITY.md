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
[`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md). That removes most classic
attack surfaces (nothing to breach, nothing to rate-limit, no database to
leak). What's actually in scope:

- **Camera, microphone, and photo-library handling** — the app's permission
  boundaries and how captured content is processed and discarded.
- **On-device biometric data** (facial-enrollment feature, deferred but
  designed now) — see [`docs/PRIVACY.md`](docs/PRIVACY.md) and
  [`security/THREAT-MODEL.md`](security/THREAT-MODEL.md) for the encrypted,
  on-device-only, consent-gated design.
- **Supply chain** — dependencies and any bundled on-device ML model. Model
  license and provenance issues (the AGPL/AMLR traps documented in
  [`docs/AI-MODELS.md`](docs/AI-MODELS.md)) are treated as security issues,
  not just legal ones, because an unvetted model is unvetted code.
- **Signing keys and CI secrets** for the eventual TestFlight/App Store
  pipeline — see [`docs/DISTRIBUTION.md`](docs/DISTRIBUTION.md). These never
  belong in the repository.
- **The optional, opt-in cloud-reasoning adapter** (not built yet) — user's
  own provider credentials, stored in Keychain, never shipped as project
  secrets.

## Automated scanning

GitHub's native code scanning (CodeQL, `.github/workflows/codeql.yml`),
secret scanning with push protection, and Dependabot are enabled on this
repository — see the [GitHub Platform](README.md#github-platform) table in
the README for the full list, and the
[Security tab](https://github.com/kevinle3212/sensebridge/security) for live
alerts. These catch classes of bugs before review; they don't replace a
private report for anything they miss.

## Accepted dependency risks

An advisory is only ever accepted when there is no fixed version to upgrade
to. Each acceptance is recorded next to the lockfile it applies to, states the
reachable attack path, and carries a date by which it must be argued again
rather than renewed silently. `osv-scanner` prints the reason on every run, so
an acceptance stays visible instead of disappearing into config.

| Advisory | Package | Where it is recorded | Re-argue by |
| --- | --- | --- | --- |
| [GHSA-jmr9-qjv8-65gv](https://osv.dev/GHSA-jmr9-qjv8-65gv) | `extract-zip` 2.0.1 (dev only, via `pa11y-ci` → `puppeteer`) | [`website/osv-scanner.toml`](website/osv-scanner.toml) | 2026-11-18 |

## Out of scope (for now)

Account takeover, server-side issues, and anything requiring a backend the
MVP doesn't have. This will change if/when the optional cloud service is
built — this file will be updated at that point.

---

Need help? See [`SUPPORT.md`](SUPPORT.md).
