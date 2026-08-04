# Suggested Commands

Everything routes through the root `npm run <script>` command center
(`npm run` with no args lists them all — the discoverable index).

- `npm run setup` — bootstrap (`scripts/setup.sh`).
- `npm run app:build` / `app:test` / `app:device` / `app:install` /
  `app:clean` — wrap `scripts/app.sh` (xcodebuild). `app:install` resolves
  the attached device at run time — no hardcoded UDID. Requires the phone
  unlocked or the dev disk image won't mount. A simulator build does not
  substitute for a device install (ARKit/LiDAR/Apple
  Intelligence/haptics/camera produce nothing in the simulator).
- `swift build` / `swift test` also work directly from
  `app/Packages/SenseBridgeCore`.
- `npm run lint` — `lint:swift` (SwiftLint + SwiftFormat via
  `scripts/lint.sh`) + `lint:md` (markdownlint-cli2).
- `npm run check` — sensitive-file scan, skill-mirror-sync check, docs JS
  syntax check, link check, env-loader check (all bundled).
- `npm run docs:build` / `docs:a11y` — `scripts/docs.sh`, Dockerized Jekyll
  build + pa11y accessibility pass over the built docs site.
- `npm run website:*` — proxies into `website/`'s own `package.json`
  scripts (`website:install`, `website:dev`, `website:build`,
  `website:check`).

**Never run `npm run dev`, `astro preview`, or anything else that holds a
port unless explicitly asked** — this is a standing project convention, not
a one-off preference; it applies in `website/` and everywhere else.
