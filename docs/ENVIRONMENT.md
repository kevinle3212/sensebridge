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

**None required for the MVP.** There is no backend, no API keys, and no
`.env` file: no server, no accounts, no analytics — see
[ARCHITECTURE.md](ARCHITECTURE.md#backend-architecture-there-is-none-and-that-is-correct).
If the optional, opt-in cloud reasoning adapter is ever enabled by a user,
their own provider credential is stored in the Keychain, never in a
committed file, an environment variable, or a log — see
[PRIVACY.md](PRIVACY.md).

## Local development

1. Clone the repository.
2. Open the Xcode project under `app/`.
3. Select your personal Apple ID as the signing team for local, on-device
   builds — free, no Apple Developer Program enrollment needed (App Store
   Connect / TestFlight distribution needs the paid program — see
   [DISTRIBUTION.md](DISTRIBUTION.md)). `app/project.yml` already sets
   `CODE_SIGN_STYLE: Automatic` with no `DEVELOPMENT_TEAM`, so this is purely
   an Xcode-side step:
   1. Xcode → Settings → Accounts → add your personal Apple ID (free — not
      the paid Developer Program).
   2. Open `app/SenseBridge.xcodeproj`, select the `SenseBridge` target →
      Signing & Capabilities → pick your personal team from the dropdown.
      Xcode fills in `DEVELOPMENT_TEAM` for you; no manual bundle ID change
      needed unless you want one different from `com.sensebridge.app`.
   3. Plug in your device, select it as the run destination, hit Run. First
      launch: on-device Settings → General → VPN & Device Management →
      trust your developer certificate.
   4. **The catch:** a free personal-team signature expires after 7 days —
      re-run from Xcode to re-sign. Fine for active development, annoying
      for a build you want to leave installed; it's the free tier's only
      real limitation. No API keys are involved in this path — see
      [DISTRIBUTION.md](DISTRIBUTION.md) for when one becomes relevant.
4. Build and run on a physical device for anything touching camera, LiDAR,
   microphone, or on-device model performance; the simulator is fine for
   pure UI/VoiceOver-label work but cannot validate the perception pipeline.
5. Run `scripts/setup.sh` once — it checks your toolchain and enables the
   repo's git hooks (`.githooks/`): a pre-commit secret/sensitive-file scan
   plus lint, a conventional-commit header check, a pre-push build gate that
   also refuses direct pushes to `main`, and a post-merge check that flags
   manifest/toolchain files just pulled in. `gitleaks`, `ggshield`, and Node
   are advisory for the hooks (`brew install gitleaks`; `brew install
   ggshield` then `ggshield auth login`; CI scans regardless).
   `scripts/lint.sh` can also be run directly before committing.

## Secret handling

There are no project secrets to handle for the MVP. If that changes (a
future opt-in cloud adapter, CI signing credentials for TestFlight), keep
them in the Keychain (on-device) or GitHub Actions repository secrets (CI) —
never in the repository, a log, or a committed `.env` file. Run
`tools/check-sensitive-files.mjs` before publishing changes that touch
signing or credentials.

---

Need help? See [`SUPPORT.md`](../SUPPORT.md).
