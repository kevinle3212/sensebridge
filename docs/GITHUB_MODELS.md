---
title: GitHub Models Prompts (Engineering Doctrine)
---

# GitHub Models Prompts

`.github/prompts/*.prompt.yml` are text-in/text-out review aids that run
against a hosted model via [GitHub Models](https://github.com/marketplace/models).
Each one maps to a specific piece of SenseBridge's review surface — see the
table in [`.github/prompts/README.md`](../.github/prompts/README.md).

## Why these exist

The project's four non-negotiable doctrines
([`AGENTS.md`](../AGENTS.md#the-four-doctrines-non-negotiable)) are mostly
about *copy* — spoken output, captions, consent prompts, settings labels,
VoiceOver strings. A prompt file is a cheap, fast, deterministic-enough first
pass over a single string of candidate copy, runnable locally or in CI,
without spinning up the full app. It is not a substitute for the matching
review agent (`safety-framing-reviewer`, `security-reviewer`,
`accessibility-reviewer`) or a human pass — those own the actual gate.

## How they run

- **CI** ([`.github/workflows/github-models.yml`](../.github/workflows/github-models.yml)):
  two jobs.
  - `prompt-files` — live inference via `actions/ai-inference`, one matrix
    leg per prompt file. **Manual-dispatch only** (`workflow_dispatch`), so a
    third-party model provider's rate limits or outages never block
    application/security CI. Tolerant of HTTP 429 (warns, doesn't fail); a
    genuinely empty response still fails the leg.
  - `evaluate-prompts` — runs `gh models eval` over every `*.prompt.yml` file
    (best-effort; skips cleanly if the runner's `gh` doesn't have the
    `models` extension).
- **Locally**: `gh models eval .github/prompts/<file>.prompt.yml` (requires
  the GitHub CLI with `models: read` access — see
  `github.com/marketplace/models` to confirm account/org access, since the
  toggle doesn't always surface in repo Settings).
- **Playground**: open any `.prompt.yml` file directly in the
  [GitHub Models playground](https://github.com/marketplace/models) via the
  GitHub UI's "Open in Models" affordance.

## Why evaluators only check verdict-presence

Every prompt's `testData` rows have mixed `expected: "PASS"` /
`expected: "FAIL"` outcomes by design — a prompt worth having must correctly
distinguish both. `gh models eval` and the `evaluate-prompts` CI job can't
express "PASS on some rows, FAIL on others" as a single fixed-string
assertion, so each prompt's `evaluators:` block only checks that a real
verdict line was produced (`minLength: 4`), not which verdict. Reading the
actual response (CI logs, or `gh models eval --json`) is still required to
judge accuracy — this only guards against the model going silent or erroring.

## Adding a new prompt

1. Copy the structure of an existing `.prompt.yml`: a header comment stating
   what it guards and why, `name`/`description`/`model`/`modelParameters`,
   a `messages` block with `{{template}}` variables, `testData` with mixed
   PASS/FAIL rows, and the same verdict-presence `evaluators` block.
2. Add a row to [`.github/prompts/README.md`](../.github/prompts/README.md)'s
   table, including which doctrine it maps to.
3. Add a matrix leg (`prompt` + `include.input`) to
   [`.github/workflows/github-models.yml`](../.github/workflows/github-models.yml).
4. If it reviews copy touching the safety-framing or accessibility surfaces
   specifically, route the underlying change through the matching reviewer
   agent too — this doc's prompts are an aid, not the gate.
