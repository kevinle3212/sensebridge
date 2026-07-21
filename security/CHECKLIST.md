# Security Checklist

Run through this before a release or any change touching the areas below.

- [ ] No committed secrets, signing keys, or provisioning profiles.
- [ ] Secret scanning (`.gitleaks.toml`) passes.
- [ ] Any new or updated dependency's license is checked (MIT/Apache-2.0
      preferred) — see [`docs/AI-MODELS.md`](../docs/AI-MODELS.md) for the
      known license traps (AGPL, `apple-amlr`).
- [ ] Any new or updated on-device model has its provenance and license
      recorded in [`models/README.md`](../models/README.md).
- [ ] `security/THREAT-MODEL.md` updated if the change adds a new trust
      boundary (a new data path, a new opt-in cloud provider, a new
      persisted-data type).
- [ ] Nothing new writes user content (images, recognized text, audio) to
      logs — see [`docs/PRIVACY.md`](../docs/PRIVACY.md).
- [ ] Biometric-adjacent code (facial enrollment, when built) keeps data
      encrypted, on-device, consent-gated, and user-deletable.
- [ ] CI workflow permissions are least-privilege.
- [ ] Release-signing secrets are scoped to the release workflow only.

---

Need help? See [`SUPPORT.md`](../SUPPORT.md).
