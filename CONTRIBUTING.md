# Contributing to SenseBridge

Thank you for considering a contribution to a free, open-source accessibility
tool. Read [`COMMUNITY_GUIDELINES.md`](COMMUNITY_GUIDELINES.md) first — it
explains how this community prioritizes lived disability expertise over
sighted intuition, which shapes how contributions get reviewed.

## Setup, build, and test

Full environment setup (Xcode version, Swift toolchain, device/simulator
requirements) lives in [`docs/ENVIRONMENT.md`](docs/ENVIRONMENT.md) — read it
before opening the Xcode project in [`app/`](app). Testing strategy and how to
run each test layer is in [`docs/TESTING.md`](docs/TESTING.md).

## Running and deploying your own copy

You never need access to this project's hosting to build, run, or test
anything here — and you cannot accidentally deploy to it.

- **The app** (`app/`) is serverless and on-device: no backend, no accounts,
  no API keys. Signing uses your own free personal Apple ID; both the team ID
  (`DEVELOPMENT_TEAM`) and the bundle-identifier prefix (`BUNDLE_ID_PREFIX`,
  defaulting to `com.sensebridge`) live in an untracked
  `app/Config/Signing.local.xcconfig`. Set the prefix if signing reports *"the
  app identifier cannot be registered to your development team"* — the
  original IDs belong to this project's team.
- **The site** (`website/`) builds with zero configuration. Every value that
  belongs to a specific deployment is an environment variable with a local
  fallback — `SITE_URL` defaults to `http://localhost:4321`, so a fresh clone
  builds green and never points at anyone else's domain. `cp .env.example
  .env` and edit only what you need; `.env` is git-ignored.
- **`.env` is read automatically, everywhere.** No flag to pass and no
  `FOO=bar npm run ...`: `scripts/env.sh` covers the shell scripts and git
  hooks, `website/scripts/load-env.js` covers everything in `website/` that
  runs on Node. The repo root's `.env` holds shared values, `website/.env` the
  site's, and anything already exported (a CI secret, a one-off override) wins
  over both. See [`docs/ENVIRONMENT.md`](docs/ENVIRONMENT.md#env-is-loaded-automatically).
- **Deploy the fork wherever you like.** `railway.toml`, `website/vercel.json`,
  and `docker/` carry no account identifiers, and the `railway:*` / `vercel:*`
  npm scripts act on whichever project *you* are logged into. Building the
  container takes the origin as a build arg:
  `docker build -f docker/Dockerfile --build-arg SITE_URL=https://you.example .`
- **A fork's CI is never red for a credential it doesn't have.** The Railway
  preview-deploy job and `security.yml`'s GitGuardian scan each report and
  exit green when their secret is absent; TruffleHog, the build, the
  accessibility gate, and every `check:*` need no secrets and still run.

The official SenseBridge site is <https://sensebridge.vercel.app>. It is
deliberately not the built-in default for `SITE_URL`, so a fork never
advertises the official site as its own.

Full detail: [`docs/ENVIRONMENT.md`](docs/ENVIRONMENT.md#configuration) and
[`website/README.md`](website/README.md#deployment). If you find a hardcoded
deployment target anywhere in tracked source, that is a bug worth filing —
`npm run check:site-url` exists to catch the site half of it.

## Branches, commits, and hooks

Never commit to `main`. Branch as `feat/...`, `fix/...`, or `chore/...`, use
conventional commit headers (`type(scope): subject`), and open a PR so CI
runs. `scripts/setup.sh` enables the repo git hooks (`.githooks/`), which
enforce the commit format (via [commitlint](commitlint.config.js) when the
root `npm ci` has been run, else a dependency-free bash-regex fallback), lint
any changed `.github/workflows/*.yml` with actionlint, run a
secret/sensitive-file scan plus lint before every commit, mirror the CI build
gate and block direct pushes to `main` before every push, and flag
manifest/toolchain changes after every merge or pull. Commit messages and
workflow files are also linted in CI ([`commitlint.yml`](.github/workflows/commitlint.yml),
[`actionlint.yml`](.github/workflows/actionlint.yml)) — that check is not
skippable with `git commit --no-verify`.

## Before you open a PR

- **Accessibility is not optional.** Every screen must be fully VoiceOver-
  navigable before it merges — see [`docs/ACCESSIBILITY.md`](docs/ACCESSIBILITY.md).
  If you changed any UI, manually test it with VoiceOver on, eyes closed or
  screen-curtained, not just by reading the code.
- **Respect the awareness-not-safety doctrine.** If your change touches
  spoken output, alerts, or any language describing the physical world, read
  [`docs/SAFETY-FRAMING.md`](docs/SAFETY-FRAMING.md) first. Confidently wrong
  output is the single worst-case bug in this project.
- **Check model licenses before adding any model or dependency.** See
  [`docs/AI-MODELS.md`](docs/AI-MODELS.md) — AGPL and Apple's `apple-amlr`
  research-only license are hard blockers.
- Use the [pull request template](.github/PULL_REQUEST_TEMPLATE.md), which
  includes a required accessibility-impact statement.

## Filing issues

Use the templates in
[`.github/ISSUE_TEMPLATE/`](.github/ISSUE_TEMPLATE) — there's a dedicated
accessibility-issue template. Accessibility bugs are treated as high-priority
regardless of how the reporter is otherwise labeled (severity, component,
etc.).

## Good first issues

Issues labeled `good first issue` are curated to be approachable, especially
for accessibility-minded newcomers who may not think of themselves as
"engineers who contribute to open source" — you don't need prior Swift
experience to file a sharp accessibility bug report, and that's a real
contribution.

## Decision-making

See [`GOVERNANCE.md`](GOVERNANCE.md) for how decisions get made and by whom.

---

Need help? See [`SUPPORT.md`](SUPPORT.md).
