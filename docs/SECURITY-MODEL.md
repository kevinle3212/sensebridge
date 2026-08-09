---
title: Security Model
---

# Security Model

This describes SenseBridge's security posture and threat model — what could
go wrong and what mitigates it — not a list of live findings. Specific,
unresolved security findings are tracked privately rather than published
here; see [`SECURITY.md`](https://github.com/kevinle3212/sensebridge/blob/main/SECURITY.md)
for how to report one.

## Why the attack surface is small by construction

SenseBridge's MVP has no backend, no accounts, and no telemetry by default —
see
[`docs/ARCHITECTURE.md`](ARCHITECTURE.md#backend-architecture-there-is-none-and-that-is-correct).
That is an architectural fact, not a policy promise, and it removes most of
the classic attack surface before any code is written: no server to breach,
no database to leak, no session or auth system to attack, and no cross-user
data to leak between accounts, because there are no accounts. What remains
in scope is what's on the device itself, and what's used to build and ship
it — both covered below.

**The one outbound path.** Since 2026-07-31 the app links Sentry for crash
reporting. It is off by default and starts only when the user switches on
Settings → Diagnostics, so an install that has not been touched has exactly
the surface described above. When it *is* on, the addition to the threat
model is: a third-party SDK with signal and exception handlers installed, and
an HTTPS egress to Sentry's ingest endpoint carrying stack traces, device
model, and OS/app version. Breadcrumbs, screenshots, view hierarchies,
network tracking, and method swizzling are all disabled in code, and
`CrashReporting.scrub` strips user, request, server-name, and device-name
fields before transmission. See
[`docs/PRIVACY.md`](PRIVACY.md#crash-reporting-opt-in-off-by-default) and
`app/SenseBridge/App/CrashReporting.swift`.

## Trust boundaries

```text
Device sensors (camera, microphone) → Perception → Reasoning → Output
                                                        |
                                          On-device storage (UserDefaults)
                                                        |
                              (opt-in, disabled by default) Cloud Reasoning
                                  Adapter — user's own provider credential
```

- **Sensors → Perception → Reasoning → Output.** Raw sensor data (camera
  frames) is processed on-device and discarded; only structured
  `PerceptionRecord` values — never raw pixels, audio, or depth buffers —
  cross from Perception into Reasoning. See
  [`docs/GLOSSARY.md`](GLOSSARY.md) for these types and
  [`docs/ARCHITECTURE.md`](ARCHITECTURE.md) for the full pipeline.
- **On-device storage.** User preferences (output profile, speech/haptic
  settings, camera defaults) persist via `UserDefaults`
  (`UserDefaultsSettingsStore`), never user content. `docs/ARCHITECTURE.md`
  and `Settings.swift`'s own doc comments describe an optional,
  settings-only iCloud/CloudKit sync as a later addition behind the same
  `SettingsStore` protocol — as of this writing, no CloudKit code exists in
  the codebase and no sync is wired up; the current build is UserDefaults
  only.
- **The optional cloud reasoning adapter.** `CloudReasoningAdapter` is a
  protocol with no shipping implementation yet. Per its own doc comment and
  [`docs/PRIVACY.md`](PRIVACY.md), it is opt-in only, disabled by default,
  and nothing in the `SenseBridgeCore` package invokes it on its own — the
  App layer would only construct one once `Settings.cloudReasoningEnabled`
  is true and the user has configured a provider credential, stored in the
  Keychain, never shipped as a project secret.

## Threat model

### Assets worth protecting

- Camera imagery captured for OCR/scene description — processed and
  discarded, not persisted without a specific, user-visible reason.
- Recognized text — potentially sensitive (mail, medical documents,
  prescriptions) even though it is never logged or stored beyond the
  in-session result.
- Future face-enrollment data (designed, not yet built — see
  [`docs/PRIVACY.md`](PRIVACY.md#biometric-data-facial-enrollment--deferred-designed-now)):
  the design commits this to an encrypted, on-device-only store, excluded
  from sync by default, before any code exists to populate it.

### Plausible adversaries and what mitigates each

| Adversary | What they'd want | Mitigation |
| --- | --- | --- |
| A device thief / someone with physical access | Anything cached on the device | No persisted user content by design (images/text are processed and discarded); any future enrollment store is encrypted with Keychain-protected keys behind device unlock |
| A malicious or compromised dependency | Code execution, data exfiltration via a bundled package or model | Minimal SwiftPM dependency tree, Dependabot + OSV scanning, pinned versions, and the `dependency-auditor` review path (see "Supply chain" below) |
| A future misconfigured opt-in cloud provider | Camera imagery or recognized text sent off-device | The adapter is disabled by default and requires explicit opt-in; per doctrine 2 in [`AGENTS.md`](https://github.com/kevinle3212/sensebridge/blob/main/AGENTS.md), nothing about the user's surroundings leaves the phone without consent and a privacy-doc update |
| A committer accidentally exposing a credential | CI or signing secrets in the repo, a log, or a built artifact | Three independent scanners (`gitleaks` pre-commit, TruffleHog + GitGuardian in CI) plus `tools/check-sensitive-files.mjs`; see "Secrets posture" below |

## Supply chain

- **SwiftPM dependencies** are tracked by Dependabot
  (`.github/dependabot.yml`, weekly, with a supply-chain cooldown before a
  freshly published version is adopted) and scanned for known
  vulnerabilities by OSV Scanner (`security.yml`'s `osv-scan` job, plus a
  PR-scoped `dependency-review` job).
- **The license gate.** AGPL and Apple's `apple-amlr` research-only license
  are hard blockers for anything shipped in the app or as a bundled model —
  see [`docs/AI-MODELS.md`](AI-MODELS.md) and the
  [model-license-audit](https://github.com/kevinle3212/sensebridge/blob/main/.agents/skills/model-license-audit/SKILL.md)
  skill. An unvetted model license is treated as a security issue, not just
  a legal one, because an unvetted model is unvetted code.
- **Review path.** New dependencies and bundled models go through the
  [dependency-auditor](https://github.com/kevinle3212/sensebridge/blob/main/.agents/agents/dependency-auditor.md)
  persona, which checks SwiftPM hygiene (pinned versions, minimal tree),
  provenance (trusted source, verified maintainer/release history), and
  known advisories before a new package or model is added.

## Secrets posture

The app itself ships no secrets — it is serverless and holds no API keys or
credentials of its own. What secrets exist live entirely in CI and local
developer tooling:

- **CI secrets** (`ANTHROPIC_API_KEY`, `RAILWAY_TOKEN`, `GITGUARDIAN_API_KEY`,
  the auto-injected `GITHUB_TOKEN`) live in GitHub Actions repository
  secrets, never in the repository itself.
- **Enforcement** is automated, not just documented: `gitleaks` and
  `tools/check-sensitive-files.mjs` run pre-commit; TruffleHog and
  GitGuardian run in CI on every push and PR (`security.yml`).
- The full table of every secret, what uses it, and what breaks if it's
  unset lives in [`docs/SECRETS.md`](SECRETS.md) — this page doesn't
  duplicate it.

## Permissions

Verified against
[`app/SenseBridge/Resources/InfoPlist.xcstrings`](https://github.com/kevinle3212/sensebridge/blob/main/app/SenseBridge/Resources/InfoPlist.xcstrings)
and the capture code that requests each one:

| Permission | Usage description | Justification |
| --- | --- | --- |
| `NSCameraUsageDescription` | "SenseBridge uses the camera to read text and describe scenes for you. Nothing leaves your device." | Actively used: `CameraSource` (`app/Packages/SenseBridgeCore/.../Sensing/CameraSource.swift`) requests camera authorization and drives the Read/Identify/Describe capture flows. |
| `NSMicrophoneUsageDescription` | "SenseBridge uses the microphone to recognize nearby sounds and announce them. Nothing leaves your device." | Declared for the planned Sound Alerts feature, but not yet exercised: `SoundAlertsView` currently renders a canned detection through the real `Phrasing`/`RenderTarget` pipeline rather than capturing live audio (see `docs/CODE-MAP.md`). No microphone-capture code exists yet to request this permission at runtime. |

No other `NS*UsageDescription` keys exist in the current build — no photo
library, location, Bluetooth, or biometric-hardware access is requested.

## Reporting a vulnerability

Report security issues privately — see
[`SECURITY.md`](https://github.com/kevinle3212/sensebridge/blob/main/SECURITY.md)
at the repository root for what's in scope and how to report. Do not open a
public issue for a vulnerability.

## Data handling

The guarantees around what happens to user content — what's processed and
discarded, what's never logged, what optional sync does and doesn't carry —
live in [`docs/PRIVACY.md`](PRIVACY.md). This page describes the security
posture that backs those guarantees; it does not restate them.

---

Need help? See [`SUPPORT.md`](https://github.com/kevinle3212/sensebridge/blob/main/SUPPORT.md).
