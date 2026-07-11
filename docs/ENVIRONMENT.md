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
  [ai-models.md](ai-models.md)).

## Configuration

**None required for the MVP.** There is no backend, no API keys, and no
`.env` file: no server, no accounts, no analytics — see
[architecture.md](architecture.md#backend-architecture-there-is-none-and-that-is-correct).
If the optional, opt-in cloud reasoning adapter is ever enabled by a user,
their own provider credential is stored in the Keychain, never in a
committed file, an environment variable, or a log — see
[privacy.md](privacy.md).

## Local development

1. Clone the repository.
2. Open the Xcode project under `app/`.
3. Select your personal Apple ID as the signing team for local, on-device
   builds (App Store Connect / TestFlight distribution needs the paid Apple
   Developer Program — see [DISTRIBUTION.md](DISTRIBUTION.md)).
4. Build and run on a physical device for anything touching camera, LiDAR,
   microphone, or on-device model performance; the simulator is fine for
   pure UI/VoiceOver-label work but cannot validate the perception pipeline.
5. Run `scripts/setup.sh` to check your toolchain, and `scripts/lint.sh`
   before committing.

## Secret handling

There are no project secrets to handle for the MVP. If that changes (a
future opt-in cloud adapter, CI signing credentials for TestFlight), keep
them in the Keychain (on-device) or GitHub Actions repository secrets (CI) —
never in the repository, a log, or a committed `.env` file. Run
`tools/check-sensitive-files.mjs` before publishing changes that touch
signing or credentials.
