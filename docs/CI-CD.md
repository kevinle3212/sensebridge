---
title: CI/CD and Release Engineering
---

# CI/CD and Release Engineering

Every automated check that runs against this repository, what each one
gates, and what a contributor should do when one fails. Source of truth:
the 17 workflow files in
[`.github/workflows/`](https://github.com/kevinle3212/sensebridge/tree/main/.github/workflows).

## Workflows

| Workflow | Trigger | What it gates | On failure |
| --- | --- | --- | --- |
| [`actionlint.yml`](https://github.com/kevinle3212/sensebridge/blob/main/.github/workflows/actionlint.yml) | Push/PR to `main` touching `.github/workflows/**` | YAML syntax, expression errors, and shellcheck on every workflow's `run:` blocks | Fix the flagged workflow file; `brew install actionlint` and run it locally, or let `.githooks/pre-commit` catch it first |
| [`ci.yml`](https://github.com/kevinle3212/sensebridge/blob/main/.github/workflows/ci.yml) | Push/PR to `main` | Three jobs: **build-test** (`xcodebuild test` for the `SenseBridgeCore` SwiftPM package, then app build+test), **lint** (SwiftFormat + SwiftLint via `scripts/lint.sh`), **docs-links** (markdownlint, mirrored-skill drift check, relative-Markdown-link check, and a `node --check` parse of `docs/assets/js/docs.js`), **docs-a11y** (builds `docs/` with the real Pages toolchain, then runs [`tools/docs-a11y.mjs`](https://github.com/kevinle3212/sensebridge/blob/main/tools/docs-a11y.mjs) — pa11y at WCAG2AA in **both** themes, zero unlabeled interactive elements, and no uncaught page errors) | Reproduce locally: `xcodebuild test` in `app/Packages/SenseBridgeCore`, `scripts/lint.sh`, `npx markdownlint-cli2 "**/*.md"`, `node --check docs/assets/js/docs.js`, or `npm run docs:a11y` (which builds `docs/` under the same `github-pages` bundle and installs the runner's dependencies itself — needs Docker; see [`ENVIRONMENT.md`](ENVIRONMENT.md#command-center)), depending on which job failed |
| [`claude-code-review.yml`](https://github.com/kevinle3212/sensebridge/blob/main/.github/workflows/claude-code-review.yml) | `workflow_dispatch` only (auto-PR trigger paused since 2026-07-17, pending API budget) | Automated first-pass PR review prioritizing safety-framing, accessibility, on-device privacy, and licensing | Not a merge gate while paused; run manually from the Actions tab if needed |
| [`claude.yml`](https://github.com/kevinle3212/sensebridge/blob/main/.github/workflows/claude.yml) | `workflow_dispatch` only (same pause as above) | Responds to `@claude` mentions in issues/PRs | Not a merge gate while paused |
| [`codeql.yml`](https://github.com/kevinle3212/sensebridge/blob/main/.github/workflows/codeql.yml) | Push/PR to `main`, weekly schedule, dispatch | Native GitHub code scanning: Swift (push/schedule/dispatch only — a full `xcodebuild build` already runs in `ci.yml` on every PR) and JavaScript/TypeScript (every PR) | Review the alert under the repo's Security tab → Code scanning; fix or, with justification, dismiss it |
| [`commitlint.yml`](https://github.com/kevinle3212/sensebridge/blob/main/.github/workflows/commitlint.yml) | PR to `main` | Every commit in the PR range and the PR title follow conventional commits (`type(scope): subject`) | Reword the offending commit message or PR title; this check cannot be bypassed with `git commit --no-verify` |
| [`copilot-setup-steps.yml`](https://github.com/kevinle3212/sensebridge/blob/main/.github/workflows/copilot-setup-steps.yml) | Dispatch/push/PR on itself | Bootstraps the GitHub Copilot coding agent's `website/` Node environment (`ubuntu`-only — it cannot build the iOS app) | Not a merge gate |
| [`dependabot-automerge.yml`](https://github.com/kevinle3212/sensebridge/blob/main/.github/workflows/dependabot-automerge.yml) | `pull_request_target`, Dependabot PRs only | Auto-approves and enables auto-merge for Dependabot **patch/minor** updates once required checks pass | Major-version bumps are left for manual review — nothing to do unless a patch/minor bump doesn't merge as expected |
| [`github-models.yml`](https://github.com/kevinle3212/sensebridge/blob/main/.github/workflows/github-models.yml) | PR/push touching `.github/prompts/**`, dispatch | Validates all four doctrine copy-review prompt files ([`docs/GITHUB_MODELS.md`](GITHUB_MODELS.md)); live inference is manual-only so an external provider outage can't block CI | Inspect the printed inference response; a 429 rate limit is tolerated and does not fail the job |
| [`graphify.yml`](https://github.com/kevinle3212/sensebridge/blob/main/.github/workflows/graphify.yml) | Push to `main` touching `app/`, `website/src/`, `tools/`, `scripts/`, `.graphifyignore`; dispatch | Rebuilds the AST-only knowledge-graph artifact for reviewers | Advisory (`continue-on-error: true`) — never blocks a merge |
| [`pages.yml`](https://github.com/kevinle3212/sensebridge/blob/main/.github/workflows/pages.yml) | Push to `main` touching `docs/**` | Builds and deploys `docs/` to GitHub Pages | See "Docs publishing" below; check the Jekyll build log for a Markdown or front-matter error |
| [`railway-deploy-check.yml`](https://github.com/kevinle3212/sensebridge/blob/main/.github/workflows/railway-deploy-check.yml) | Push/PR touching `docker/**`, `website/**`, `railway.toml` | Builds and smoke-tests `docker/Dockerfile` — the exact image Railway builds for the website | Fix the Dockerfile or the site build; this never deploys anything itself |
| [`railway-preview-deploy.yml`](https://github.com/kevinle3212/sensebridge/blob/main/.github/workflows/railway-preview-deploy.yml) | Push to any branch except `main` touching `docker/**`, `website/**`, `railway.toml` | Deploys `website/` to Railway's `preview` environment | Requires the `RAILWAY_TOKEN` repo secret (see [`docs/SECRETS.md`](SECRETS.md)); check the job logs if the deploy fails |
| [`react-doctor.yml`](https://github.com/kevinle3212/sensebridge/blob/main/.github/workflows/react-doctor.yml) | PR/push touching `website/**` | React Doctor code-quality scan of `website/`, blocking at `warning` severity | Fix the flagged file, or add a known-false-positive suppression to `website/doctor.config.jsonc` |
| [`security.yml`](https://github.com/kevinle3212/sensebridge/blob/main/.github/workflows/security.yml) | Push/PR to `main`, weekly schedule | Secret scanning (TruffleHog, GitGuardian), dependency vulnerability scan (OSV, recursive), a sensitive-file check, Semgrep static analysis, and PR-only dependency review | Rotate immediately if a secret was flagged (see [`docs/SECRETS.md`](SECRETS.md) § 5); update the vulnerable dependency; fix the flagged pattern |
| [`website-ci.yml`](https://github.com/kevinle3212/sensebridge/blob/main/.github/workflows/website-ci.yml) | Push/PR touching `website/**` | **lint** job: Stylelint/ESLint/Prettier/Astro typecheck/build, plus a verbatim-safety-disclaimer check, a zero-hydrated-JS budget check, and a narration-freshness check. **a11y** job: pa11y-ci against the built site (WCAG2AA, zero errors). **design-qa** job: Impeccable design detectors (advisory) | Run the matching `npm run <script>` inside `website/` locally; the automated a11y check is a floor — changed UI still needs a manual VoiceOver/keyboard pass |
| [`wiki-sync.yml`](https://github.com/kevinle3212/sensebridge/blob/main/.github/workflows/wiki-sync.yml) | Push to `main` touching `WIKI.md`, `docs/**`, `tools/generate-wiki-home.mjs` | Regenerates the GitHub Wiki's Home page from `WIKI.md` via `tools/generate-wiki-home.mjs` | Runs post-merge, not a PR gate; check the job log if the Wiki Home page doesn't update |

## Blocking quality gates

Beyond the workflows above, every PR must clear the gates defined in
[`CLAUDE.md`](https://github.com/kevinle3212/sensebridge/blob/main/CLAUDE.md)
and the
[ci-green-gate](https://github.com/kevinle3212/sensebridge/blob/main/.agents/skills/ci-green-gate/SKILL.md)
skill:

- **Build.** `xcodebuild build` for the app scheme, and `swift build` where a
  package target exists (`app/Packages/SenseBridgeCore`).
- **Tests.** The suites defined in [`docs/TESTING.md`](TESTING.md) —
  unit, integration, e2e (at least three per feature: happy path, error
  path, edge case), and any AI-evaluation checks wired into CI.
- **Accessibility.** Zero unlabeled elements on every screen, plus a
  VoiceOver pass on changed UI. This is a hard gate, not a coverage
  percentage.
- **Safety-framing review.** Any change to spoken output, alerts, captions,
  or physical-world language needs sign-off from the
  [safety-framing-reviewer](https://github.com/kevinle3212/sensebridge/blob/main/.agents/agents/safety-framing-reviewer.md).
- **Model-license clearance.** Any new or updated model or dependency clears
  the
  [model-license-audit](https://github.com/kevinle3212/sensebridge/blob/main/.agents/skills/model-license-audit/SKILL.md)
  skill — AGPL and Apple's `apple-amlr` are hard blockers.

## Docs publishing

Two workflows publish this documentation, and they read from different
sources:

- **`pages.yml`** builds `docs/` with `actions/jekyll-build-pages`
  (`source: docs`) and deploys it to GitHub Pages. GitHub Pages runs the
  build through the `github-pages` gem bundle, which pins a specific Jekyll
  version (3.10 as of this writing) — Pages does not run whatever Jekyll
  version is installed locally, so a page that builds locally can still fail
  on Pages if it uses a feature outside that pinned version.
  Plugins bundled with the `github-pages` gem are still inert until they are
  named in [`docs/_config.yml`](https://github.com/kevinle3212/sensebridge/blob/main/docs/_config.yml)'s
  `plugins:` list. The layout calls `{% raw %}{% seo %}{% endraw %}`, so
  `jekyll-seo-tag` is declared there; using another bundled plugin's tag
  without adding it to that list fails the build with
  `Liquid syntax error: Unknown tag`.
- **`wiki-sync.yml`** does **not** mirror doc bodies into the wiki. It runs
  `tools/generate-wiki-home.mjs`, which reads
  [`WIKI.md`](https://github.com/kevinle3212/sensebridge/blob/main/WIKI.md)
  only, and publishes the generated result as the Wiki's single Home page —
  a landing page that links out to the canonical docs on Pages, not a second
  copy of them.

## Pre-commit hooks and local gates

`scripts/setup.sh` enables this repo's git hooks
(`git config core.hooksPath .githooks`). Each one mirrors part of CI so
common breakage is caught before it ever reaches a PR:

- **`pre-commit`** — secret scan of staged changes (`gitleaks`, `ggshield`,
  each advisory if not installed locally), the sensitive-file check
  (`tools/check-sensitive-files.mjs`), the skill-lock drift check
  (`tools/skill-lock.mjs`), Markdown lint, `scripts/lint.sh`
  (SwiftFormat + SwiftLint, a no-op until `app/` exists on a given branch
  state), `actionlint` on staged workflow files, and — only when staged
  changes touch `website/` — `website/`'s `lint-staged` and React Doctor,
  both scoped to the staged files only.
- **`commit-msg`** — enforces the conventional-commit header, via
  `commitlint` when the root `npm ci` has been run, else a dependency-free
  bash-regex fallback. `commitlint.yml` in CI is authoritative and cannot be
  bypassed with `git commit --no-verify`.
- **`pre-push`** — refuses to push directly to `main`, runs a build-only
  check (`swift build` or `xcodebuild build`, same project-detection as
  `ci.yml`), an `osv-scanner` dependency check, and — when the push touches
  `website/` — a `react-doctor` scan at `--blocking warning`, mirroring
  `react-doctor.yml`.
- **`post-checkout` / `post-commit` / `post-merge`** — advisory checks that
  flag manifest/toolchain drift after a branch switch, commit, or merge.

Every hook can be bypassed in an emergency (`--no-verify`) — say so in the
PR when you do, since CI still runs the authoritative version of most of
these checks.

## Branch and commit conventions

Never commit directly to `main`. Branch as `feat/...`, `fix/...`, or
`chore/...`; use conventional commit headers (`type(scope): subject`); open
a PR so CI runs. Full detail in
[`CONTRIBUTING.md`](https://github.com/kevinle3212/sensebridge/blob/main/CONTRIBUTING.md).

## What CI cannot prove

CI validates code, not lived experience. Two things that matter most for
this project are **not** provable in an automated pipeline, and a green
pipeline must never be presented as evidence of either:

- **On-device latency, battery, and thermal behavior** — these require
  Instruments profiling on a real target iPhone, not a simulator run.
- **Real blind-tester validation** via TestFlight — the field signal that
  ultimately decides whether the app's output is trustworthy for the people
  it's built for.

When reporting gate status, state plainly which gates a machine verified
and which still require device and human validation.

## Release and distribution

There is no automated release pipeline yet, and the app is not
downloadable. See [`docs/DISTRIBUTION.md`](DISTRIBUTION.md) for the
TestFlight/App Store path and its one real cost — this page does not
duplicate it.

---

Need help? See [`SUPPORT.md`](https://github.com/kevinle3212/sensebridge/blob/main/SUPPORT.md).
