# Task Completion Checklist

- Build: `xcodebuild build` for `app/`; `swift build` for
  `app/Packages/SenseBridgeCore`.
- Tests: Swift Testing/XCTest (unit/integration) + XCUITest (E2E — floor of
  3 per feature: happy path / error path / edge case). See
  `docs/TESTING.md`.
- Lint: `npm run lint` (SwiftLint/SwiftFormat + markdownlint).
- Checks: `npm run check` (sensitive-file scan, skill-mirror sync check,
  docs JS syntax, link check, env-loader check).
- **After any change to `app/` code**: rebuild for a physical device and
  install it (`npm run app:install`) before reporting the task done — do
  this unprompted, as the last step. Doc-only/comment-only changes are
  exempt. A simulator build never counts as testable here (see
  `mem:suggested_commands`).
- Safety-framing review is required for any change touching spoken output,
  alerts, captions, haptics, or language describing the physical world (see
  `mem:conventions`).
