---
title: Environment
---

# Environment

## Required tooling

- **A Mac** running a current version of **Xcode** (Swift 6 toolchain, iOS 26
  SDK or later — Foundation Models and the other frameworks this project
  depends on require it). This is the entire toolchain for the MVP.
- **Git.**
- **A personal Apple ID** for building and running on your own device — this
  is free. See [DISTRIBUTION.md](DISTRIBUTION.md) for the one place a paid
  account is actually required (TestFlight/App Store).
- **A capable physical iPhone** (iPhone 15 Pro or later — Foundation Models
  requires Apple Intelligence support) for on-device testing. The simulator
  cannot exercise the camera, LiDAR, or on-device model performance that this
  app is built around; published latency figures for on-device models
  shouldn't be trusted, so benchmark on your own hardware before making
  architecture decisions that depend on them (see
  [AI-MODELS.md](AI-MODELS.md)).

## Platform support

- **`app/`** — the iOS app itself — is macOS-only by design: it depends on
  Xcode, `xcodebuild`, and a physical iPhone, and there is no cross-platform
  path planned (see [AGENTS.md](../AGENTS.md)'s doctrines).
- **Everything else** — `website/`, `docs/`, and this repo's own scripts and
  git hooks — works on Windows and Linux. `scripts/*.sh` and `.githooks/*`
  are bash/POSIX `sh`; on Windows, run them from Git Bash (bundled with
  [Git for Windows](https://gitforwindows.org/), which you need anyway to
  clone the repo) or WSL2 — native `cmd`/PowerShell can't execute a `.sh`
  file directly. Linux has bash natively. `scripts/setup.sh` and the git
  hooks (`.githooks/pre-commit`'s `scripts/lint.sh` call,
  `.githooks/pre-push`'s build gate) skip the Xcode/Swift checks outside
  macOS instead of failing, so a website/docs-only contributor on Windows or
  Linux isn't blocked by a toolchain this repo can't run for them there.

## Configuration

**None required for the MVP.** The app has no backend and no API keys: no
server, no accounts, no analytics — see
[ARCHITECTURE.md](ARCHITECTURE.md#backend-architecture-there-is-none-and-that-is-correct).
If the optional, opt-in cloud reasoning adapter is ever enabled by a user,
their own provider credential is stored in the Keychain, never in a
committed file, an environment variable, or a log — see
[PRIVACY.md](PRIVACY.md).

**The marketing site (`website/`) is also zero-config to build**, but it does
take optional environment variables, documented in
[`website/.env.example`](../website/.env.example) and read from an untracked
`website/.env`. Every one has a local fallback, so `npm run build` and every
`npm run check:*` pass on a fresh clone with no `.env` at all:

| Variable | Fallback | What it controls |
| --- | --- | --- |
| `SITE_URL` | `http://localhost:4321` | Absolute origin of *your* deployment — canonical links, sitemap, `robots.txt`, OG/Twitter meta. Set it in your own host's project settings rather than in a file. |
| `ELEVENLABS_API_KEY` | none (script exits) | Local-only, generation-time key for `npm run generate:audio`. Never deployed. |
| `ELEVENLABS_VOICE_ID`, `ELEVENLABS_MODEL_ID` | the script's defaults | Narration voice and model. |
| `PUBLIC_SENTRY_DSN` | unset — the SDK is never added to the bundle | Offers the error-monitoring opt-in on `/privacy`. Not a credential (write-only ingest), but it names one deployment's Sentry project. Setting it collects nothing on its own; a visitor still has to consent. |
| `PUBLIC_SENTRY_ENVIRONMENT` | `development` | Tag separating a deployment's errors from a developer's. |
| `SENTRY_AUTH_TOKEN`, `SENTRY_ORG`, `SENTRY_PROJECT` | unset — source maps are not uploaded | Build-time source-map upload, so traces are readable rather than minified. The token **is** a credential: env or CI secret store only, never `PUBLIC_`-prefixed, never committed. |

Where to obtain each Sentry value, and the separate `app/` setting (which is an
xcconfig, not an environment variable), are documented together in
[`TODO.md`](../TODO.md) under "Sentry — environment variables and how to get
each one".

No deployment target is hardcoded in tracked source; `npm run check:site-url`
is the gate that keeps it that way. See
[`website/README.md`](../website/README.md#deployment).

### `.env` is loaded automatically

There is nothing to remember at a call site — no `--env-file` flag, no
`FOO=bar npm run ...`. Two small loaders read `.env` for you:

| Loader | Covers |
| --- | --- |
| [`scripts/env.sh`](../scripts/env.sh) | Shell scripts (`scripts/*.sh`) and every git hook in `.githooks/`. Sourced, not run. |
| [`website/scripts/load-env.js`](../website/scripts/load-env.js) | `astro.config.mjs` and every script under `website/scripts/`, so all of `npm run build` / `dev` / `preview` / `check:*` / `generate:audio`. |

Both read the repo root's `.env` first (see
[`.env.example`](../.env.example) — shared values and git-hook tuning), then
`website/.env` (see [`website/.env.example`](../website/.env.example) — site
values), so site-specific settings win. Both leave an **already-exported
variable alone**, so a CI secret, a hosting provider's project setting, or a
one-off `SITE_URL=... npm run build` always beats the file. Both files are
git-ignored and both are optional.

The external-CLI npm scripts (`railway:*`, `vercel:*`) go through
[`website/scripts/with-env.js`](../website/scripts/with-env.js), which loads
`.env` and then execs the CLI unchanged — those tools read `RAILWAY_TOKEN` /
`VERCEL_TOKEN` from the environment and have no `.env` support of their own.

`env.sh` **parses** `.env` rather than sourcing it: sourcing would execute the
file's contents inside your git hooks. Only `KEY=value` lines with a valid
shell identifier are honored. `scripts/check-env-loader.sh` is the regression
test for that property and runs in CI.

## Local development

1. Clone the repository.
2. Open the Xcode project under `app/` (or run `scripts/open-xcode.sh`).
3. Select your personal Apple ID as the signing team for local, on-device
   builds — free, no Apple Developer Program enrollment needed (App Store
   Connect / TestFlight distribution needs the paid program — see
   [DISTRIBUTION.md](DISTRIBUTION.md)). `app/project.yml` sets
   `CODE_SIGN_STYLE: Automatic` and points both configurations at
   `app/Config/Signing.xcconfig`, which is committed and deliberately names no
   team — a team ID identifies one person's Apple Developer account, so it
   stays out of tracked files:
   1. Xcode → Settings → Accounts → add your personal Apple ID (free — not
      the paid Developer Program).
   2. Create `app/Config/Signing.local.xcconfig` (gitignored) containing
      `DEVELOPMENT_TEAM = YOURTEAMID`. Find the ID with
      `security find-identity -v -p codesigning`, or in Xcode under Settings →
      Accounts → Manage Certificates — it is **not** the identifier printed in
      parentheses after the certificate name, which belongs to the certificate
      rather than the team. Picking your team in the target's Signing &
      Capabilities tab works too, but writes the ID into `project.pbxproj`;
      move it to the local file rather than committing it.
   3. Add `BUNDLE_ID_PREFIX = com.yourname` to that same local file if signing
      fails with *"the app identifier cannot be registered to your development
      team"*. `com.sensebridge` is registered to this project's team, so it
      cannot be re-registered to yours; one line re-prefixes the app and both
      test bundles. An unconfigured clone keeps the original IDs — the default
      lives in `project.pbxproj` as `$(BUNDLE_ID_PREFIX:default=com.sensebridge)`
      — so this is only needed when you sign against your own team. Per
      command: `xcodebuild BUNDLE_ID_PREFIX=com.yourname ...`.
   4. Enable Developer Mode on the device: Settings → Privacy & Security →
      Developer Mode → toggle on → restart → confirm "Turn On" in the
      lock-screen prompt. Required since iOS 16 for any developer-signed
      build (Xcode Run, `xcodebuild`, an ad-hoc IPA via AltStore/Sideloadly,
      etc.) — the only installs that skip it are App Store and TestFlight,
      both of which need the paid Developer Program (see
      [DISTRIBUTION.md](DISTRIBUTION.md)). Without it, `xcodebuild` reaches
      the device but times out waiting for the destination instead of
      building. One-time per device — it stays on until manually disabled,
      independent of the 7-day signing expiry below.
   5. Plug in your device, select it as the run destination, hit Run. First
      launch: on-device Settings → General → VPN & Device Management →
      trust your developer certificate.
   6. **The catch:** a free personal-team signature expires after 7 days —
      re-run from Xcode to re-sign. Fine for active development, annoying
      for a build you want to leave installed; it's the free tier's only
      real limitation. No API keys are involved in this path — see
      [DISTRIBUTION.md](DISTRIBUTION.md) for when one becomes relevant.
4. Build and run on a physical device for anything touching camera, LiDAR,
   microphone, or on-device model performance; the simulator is fine for
   pure UI/VoiceOver-label work but cannot validate the perception pipeline.
5. Run `scripts/setup.sh` once — it checks your toolchain and enables the
   repo's git hooks (`.githooks/`): a pre-commit secret/sensitive-file scan
   plus lint plus actionlint on staged workflow files, a conventional-commit
   header check (commitlint when the root `npm ci` has run, else a
   dependency-free bash-regex fallback), a pre-push build gate that also
   refuses direct pushes to `main`, and a post-merge check that flags
   manifest/toolchain files just pulled in — the same post-merge hook also
   refreshes `website/tsconfig.debug.json`'s diagnostics output
   (`.tsbuildinfo.debug`, `trace/`) whenever a merge into `main` touches
   `website/`, advisory-only and deliberately outside the test suite/pre-push
   gate (see the "Command center" section below and `tsconfig.debug.json`'s
   own header comment). `gitleaks`, `ggshield`, `actionlint`, `shellcheck`,
   `osv-scanner`, and Node are advisory for the hooks (`brew install
   gitleaks`; `brew install ggshield` then `ggshield auth login`; `brew
   install actionlint`; `brew install shellcheck`; `brew install
   osv-scanner`; CI enforces commitlint and actionlint regardless via
   `.github/workflows/commitlint.yml` and `.github/workflows/actionlint.yml`).
   `scripts/setup.sh` offers to install any missing advisory tool via
   Homebrew, prompting per tool when run interactively; `-y`/`--yes` installs
   everything missing without asking (scripted/CI use), `-n`/`--no-install`
   reports only and never prompts (the default when stdin isn't a terminal),
   and `-h`/`--help` prints the full flag list. `npm run lint` (or
   `scripts/lint.sh`) can also be run directly before committing — see the
   command center below.

## Command center

Every routine command is an `npm run` script, so `npm run` with no arguments
is the discoverable index of what this repo can do — for a person and for an
agent alike. Nothing here is npm-specific work: the scripts wrap the same
`scripts/*.sh`, `tools/*.mjs`, and `xcodebuild` invocations CI and the git
hooks run, so a local run and a CI run are the same code path rather than two
copies that drift.

Run `npm install` once at the root (commitlint, eslint, prettier,
markdownlint-cli2 — no heavy dependencies).

### Root — `npm run <script>`

| Script | What it does |
| --- | --- |
| `setup` | `scripts/setup.sh` — toolchain check, offers to install missing tools, enables `.githooks/` |
| `verify` | `lint` + `format` + `check` — the local mirror of CI's non-Swift gates |
| `test` / `app:test` | Simulator build + test of the `SenseBridge` scheme |
| `app:build` | Simulator build, no code signing (what `pre-push` runs) |
| `app:package-test` | `xcodebuild test` for every package under `app/Packages/*` |
| `app:device` | Signed build for the attached iPhone |
| `app:install` | Device build, then install onto the attached iPhone |
| `app:clean` / `app:open` | Clean build products / open the Xcode project |
| `lint` | `lint:swift` + `lint:md` + `lint:mjs` |
| `lint:swift` | SwiftFormat + SwiftLint (`scripts/lint.sh`) |
| `lint:md` / `lint:md:fix` | markdownlint-cli2 over all Markdown + `COMPLETED.todo` |
| `lint:mjs` / `lint:mjs:fix` | ESLint over the hand-authored `.mjs` tooling (`.claude/hooks`, `.cursor/hooks`, `tools/`) |
| `lint:actions` | `actionlint` over `.github/workflows/` (needs `brew install actionlint`) |
| `lint:shell` | ShellCheck over `scripts/` and `.githooks/` (needs `brew install shellcheck`) |
| `format` / `format:fix` | `format:mjs` / `format:mjs:fix` |
| `format:mjs` / `format:mjs:fix` | Prettier (check / write) over the same `.mjs` files `lint:mjs` covers |
| `check` | Every non-Swift gate below, in order |
| `check:sensitive` / `:all` | `tools/check-sensitive-files.mjs` — staged, or the whole tree |
| `check:skills` | Canonical skill tree, personas, and harness adapters match the hash-lock (`tools/skill-lock.mjs`) |
| `check:hooks` | `.claude/settings.json` carries no owner-personal or double-registered hook (`tools/check-settings-hooks.mjs`) |
| `check:bmad` | BMAD's `user_skill_level` still reads `expert` in both config files (`tools/check-bmad-config.mjs`) |
| `check:links` | Relative Markdown links resolve (`scripts/check-links.sh`) |
| `check:docs-js` | `docs/assets/js/docs.js` parses — it ships unbundled |
| `check:env-loader` | `scripts/env.sh` parses `.env` rather than executing it |
| `check:secrets` | `gitleaks detect` (needs `brew install gitleaks`) |
| `check:deps` | `osv-scanner` over both lockfiles (needs `brew install osv-scanner`) |
| `docs:build` | Render `docs/` to `tmp/_site` with the `github-pages` gem bundle, containerized (needs Docker) |
| `docs:a11y` | `docs:build`, then the accessibility gate over the result — installs `pa11y`/`puppeteer` on demand, deliberately not devDependencies, see [`TOOLING.md`](TOOLING.md) |
| `design:detect` | Impeccable design detectors over `website/` |
| `sync:skills` | Regenerate the mirrored skill copies from canonical |
| `todo:sweep` / `:check` | Cut ticked items out of `TODO.md`'s To-Do sections into `## Completed` (`--check` reports without writing) |
| `todo:archive` / `logs:condense` / `wiki:home` | The `tools/*.mjs` maintenance jobs |
| `website:*` | `install`, `dev`, `build`, `check` delegated into `website/` |
| `website -- <script>` | Any other `website/` script, e.g. `npm run website -- typecheck:debug` |

### `website/` — `npm --prefix website run <script>`

| Script | What it does |
| --- | --- |
| `dev` / `preview` | Astro dev server / preview of `dist/` |
| `build` / `sync` / `clean` | Astro build / generate `.astro` types / delete build output |
| `check` | Everything CI's website lint job runs, plus the built-output checks |
| `typecheck` | `astro check` — the `.astro` components |
| `typecheck:tsc` | `tsc -p tsconfig.json --noEmit` — the `.ts`/`.tsx` sources |
| `typecheck:watch` | The same, watching |
| `typecheck:debug` | `tsc -p tsconfig.debug.json` — deep diagnostics, see below |
| `typecheck:all` | `typecheck` + `typecheck:tsc`; this is the blocking pair |
| `trace` | `typecheck:debug`, then `trace:analyze` — the whole "why is tsc slow" loop |
| `trace:analyze` / `:analyze:types` | `@typescript/analyze-trace` over `trace/`, compact or with types expanded |
| `trace:types` | `simplify-trace-types` — `trace/types.json` boiled down to readable JSON |
| `lint` / `lint:fix` | Stylelint + ESLint, check or autofix |
| `format` / `format:fix` | Prettier |
| `check:*` | Disclaimer verbatim, zero-JS posture, `SITE_URL`, audio freshness, drag-to-orbit, bfcache restore |
| `check:consent` | Drives a real browser over `dist/` and asserts the Sentry chunk is never fetched before consent, that opting in fetches it, and that Global Privacy Control overrides a stored consent. Skips loudly on a build with no `PUBLIC_SENTRY_DSN`. |
| `test:a11y` | pa11y-ci at WCAG2AA — serves `dist/` itself, building it first if absent |
| `railway:*` / `vercel:*` | Deployment status, logs, and deploys |

`typecheck:debug` is a diagnostics pass, not a gate. Its `skipLibCheck: false`
surfaces conflicts inside generated `.astro/*.d.ts` and vendored `node_modules`
typings, so it exits non-zero even when `website/src` is clean; read its output,
don't chain it. `typecheck:all` is the pair that gates.

It also writes a compiler perf trace to `website/trace/` (`generateTrace` in
`tsconfig.debug.json`). `npm run website -- trace` runs both halves: the
diagnostics pass, then `@typescript/analyze-trace` over what it wrote, which
reports the hot spots as a tree of files, declarations, and type comparisons
with the milliseconds each cost. Use it to answer "which `.d.ts` is making
`tsc` slow" — today that's `@typescript-eslint/utils` and `immutable`, both
vendored, neither ours. Two limits worth knowing before reaching for it:

- It measures **type-checking**, nothing else. It cannot see bundle size,
  runtime performance, or anything the browser does. For a jank or freeze in
  the shipped site, record a Chrome DevTools performance profile instead, or
  add a probe to a puppeteer check the way `website/scripts/check-bfcache.js`
  measures long tasks after a bfcache restore.
- `trace/types.json` runs to hundreds of megabytes. It is gitignored, and
  `npm run website -- clean` deletes `trace/` along with the rest of the build
  output — do that rather than leaving it on disk.

Both accessibility gates are self-contained: each produces whatever it needs
and cleans up after itself, so neither is CI-only any more.

`test:a11y` runs Astro's preview server **inside its own process**
([`website/scripts/a11y.js`](../website/scripts/a11y.js)) rather than starting
`astro preview` as a child. That distinction is the whole design. A start/stop
wrapper that dies between the two leaves an orphaned process holding port 4321
— which is exactly what this repo forbids — whereas an in-process listener is
owned by that PID, so the kernel closes it however the run ends, `SIGKILL`
included. If you already have `npm run preview` up, the script detects it and
tests against yours instead of clashing.

`docs:a11y` builds `docs/` first, via [`scripts/docs.sh`](../scripts/docs.sh),
under the same `github-pages` gem bundle GitHub Pages itself runs — pinned to
Jekyll 3.10 — in a `ruby:3.3-slim` container, so nothing lands on the host and
a local run matches [`ci.yml`](../.github/workflows/ci.yml)'s `docs-a11y` job.
The first run compiles the bundle's native extensions and takes a few minutes;
the gems persist in `tmp/docs-jekyll/`, so later runs are seconds. Do **not**
substitute the `jekyll/jekyll` image — it lacks `jekyll-relative-links` and
renders every in-docs link unrewritten. See [`CI-CD.md`](CI-CD.md).

## Secret handling

The app itself needs no secrets — it is serverless and on-device, so nothing
ships with a key. CI, deployment, and some local tooling do need credentials:
every one of them is inventoried in [`SECRETS.md`](SECRETS.md), along with
where it is configured and what breaks when it is missing.

Keep secrets in the Keychain (on-device), GitHub Actions repository secrets
(CI), or an untracked `.env` (local tooling) — never in the repository, a log,
or a committed `.env` file. Run `tools/check-sensitive-files.mjs` before
publishing changes that touch signing or credentials.

---

Need help? See
[`SUPPORT.md`](https://github.com/kevinle3212/sensebridge/blob/main/SUPPORT.md).
