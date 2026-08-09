# Tech Stack

**App** (`app/`): Swift 6.2 (swift-tools-version 6.2), SwiftUI, platform
minimums iOS 26 / macOS 15 (set on the SPM package). No external framework
dependencies for the MVP. `app/Packages/SenseBridgeCore/Package.swift`: one
library target `SenseBridgeCore` + one test target, `defaultLocalization:
"en"`, resources via `Localizable.xcstrings`. Xcode project:
`app/SenseBridge.xcodeproj`.

**Website** (`website/`): Astro, `output: "static"`, TypeScript. `@astrojs/react`
is wired in `astro.config.mjs` but no component currently opts into a
`client:*` hydration directive — zero JS ships by default, framework-ready
only. ESLint flat config (`eslint.config.mjs`: TypeScript + React Hooks +
`jsx-a11y` strict + security rules), Stylelint, Prettier, pa11y-ci, React
Doctor.

**Repo root**: Node stack is deliberately minimal — `package.json`
devDependencies are commitlint-only; the `scripts` block is a wrapper/command
center over `scripts/*.sh`, `tools/*.mjs`, and `xcodebuild`, not a build
stack. Node `>=22`, `npm@11.16.0` pinned via `packageManager`.

No Python, no backend/server, no database anywhere in this repo.
