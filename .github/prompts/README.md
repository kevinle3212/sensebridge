# GitHub Models prompts

`.prompt.yml` files for [GitHub Models](https://github.com/marketplace/models).
Open in the Models playground or run via CI
([`.github/workflows/github-models.yml`](../workflows/github-models.yml),
manual-dispatch only — see the workflow's header comment for why).

| Prompt file | Capability tested | Doctrine |
| --- | --- | --- |
| `safety-framing-check.prompt.yml` | Flags physical-world copy that breaks the awareness-not-safety doctrine ([`docs/SAFETY-FRAMING.md`](../../docs/SAFETY-FRAMING.md)) | 1 — Awareness, not safety |
| `privacy-consent-copy-review.prompt.yml` | Flags consent/settings copy that overstates on-device processing or hides a network round-trip ([`docs/PRIVACY.md`](../../docs/PRIVACY.md)) | 2 — On-device by default |
| `accessibility-label-review.prompt.yml` | Flags vague or redundant VoiceOver labels/hints ([`docs/ACCESSIBILITY.md`](../../docs/ACCESSIBILITY.md)) | 3 — Accessibility is the product |
| `user-agency-copy-review.prompt.yml` | Flags option/channel copy that hides a limitation or offers a choice that delivers nothing ([`AGENTS.md`](../../AGENTS.md#the-four-doctrines-non-negotiable)) | 4 — User agency over gatekeeping |

Each prompt maps to one of the four non-negotiable doctrines in
[`AGENTS.md`](../../AGENTS.md#the-four-doctrines-non-negotiable). All four are
manual/CI aids that complement the matching review agent
(`safety-framing-reviewer`, `security-reviewer`, `accessibility-reviewer`) and
human review — none replaces the project's hard gates. See
[`docs/GITHUB_MODELS.md`](../../docs/GITHUB_MODELS.md) for how these prompts
run in CI, why evaluation is verdict-presence rather than exact-match, and how
to add another one.

Local eval: `gh models eval .github/prompts/safety-framing-check.prompt.yml`.
