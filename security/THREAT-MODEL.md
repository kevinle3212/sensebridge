# Threat Model

## Scope

SenseBridge's MVP: a native iOS app with **no backend and no server**. This
removes most classic attack surfaces — see
[`docs/architecture.md`](../docs/architecture.md).

## Assets

- Source code and release-signing credentials.
- User content (camera images, recognized text, audio) — transient, on-device
  only.
- Future: on-device biometric (facial-enrollment) data.
- Any bundled on-device ML model and its license/provenance record.
- Maintainer's development and signing machines.

## Trust boundaries

- Camera/microphone/photo-library → app (OS-mediated, standard iOS
  permission prompts).
- App → on-device ML models (Apple frameworks first; any bundled third-party
  model is a supply-chain trust boundary).
- App → optional, user-enabled cloud-reasoning provider (off by default; the
  user's own credential, in their own Keychain).
- Maintainer machine → GitHub repository → CI → release signing.

## Threats

| Threat | Impact | Mitigation |
|---|---|---|
| Backend breach | None — there is no backend | Architectural; keep it that way (see [`docs/architecture.md`](../docs/architecture.md)) |
| User content leak | Low — content is transient and on-device | Never persist or log recognized text, images, or audio |
| Biometric data mishandled (future) | High if it happens | Encrypted, on-device-only, consent-gated, user-viewable and deletable — see [`docs/privacy.md`](../docs/privacy.md) |
| Unvetted or mislicensed on-device model | Legal exposure (AGPL virality) and unvetted code running against camera input | License and provenance check before bundling any model — see [`docs/ai-models.md`](../docs/ai-models.md) |
| Dependency compromise | Supply-chain risk | Minimize dependencies (Apple-frameworks-first), Dependabot alerts, review before adding |
| Signing-key exposure | Attacker could sign malicious builds | Keys never in the repo; CI secrets only, scoped to the release workflow |
| Opt-in cloud adapter misuse | User's own credential exposure | Off by default, isolated, credential stays in the user's own Keychain, never a project secret |

## Review cadence

Update this file when adding a new data path, a new opt-in provider, the
facial-enrollment feature, or any new privileged CI automation.
