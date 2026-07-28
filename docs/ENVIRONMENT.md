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
   manifest/toolchain files just pulled in. `gitleaks`, `ggshield`,
   `actionlint`, and Node are advisory for the hooks (`brew install
   gitleaks`; `brew install ggshield` then `ggshield auth login`; `brew
   install actionlint`; CI enforces commitlint and actionlint regardless via
   `.github/workflows/commitlint.yml` and `.github/workflows/actionlint.yml`).
   `scripts/lint.sh` can also be run directly before committing.

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
