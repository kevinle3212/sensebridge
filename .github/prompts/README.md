# GitHub Models prompts

`.prompt.yml` files for [GitHub Models](https://github.com/marketplace/models).
Open in the Models playground or run via CI
([`.github/workflows/github-models.yml`](../workflows/github-models.yml),
manual-dispatch only — see the workflow's header comment for why).

| Prompt file | Capability tested |
| --- | --- |
| `safety-framing-check.prompt.yml` | Flags physical-world copy that breaks the awareness-not-safety doctrine ([`docs/SAFETY-FRAMING.md`](../../docs/SAFETY-FRAMING.md)) |
| `accessibility-label-review.prompt.yml` | Flags vague or redundant VoiceOver labels/hints ([`docs/ACCESSIBILITY.md`](../../docs/ACCESSIBILITY.md)) |

Both are manual/CI aids that complement the `safety-framing-reviewer` and
`accessibility-reviewer` agents and a real VoiceOver pass — neither replaces
human review or the project's hard accessibility/safety gates.

Local eval: `gh models eval .github/prompts/safety-framing-check.prompt.yml`.
