# SenseBridge Website

Static marketing site for SenseBridge, built with [Astro](https://astro.build)
(static output — every page is prerendered HTML, no backend, no accounts, no
telemetry). Styling is SCSS (design tokens in `src/styles/abstracts/`,
co-located `*.module.scss` per component). The only client-side JavaScript is:

- `src/scripts/read-aloud.ts` — two progressive-enhancement "listen to this
  page" controls; see [Read-aloud controls](#read-aloud-controls).
- `src/scripts/motion.ts` — the GSAP + Lenis scroll/hero motion layer. All of
  it is gated behind `matchMedia("(prefers-reduced-motion: no-preference)")`:
  under `prefers-reduced-motion: reduce` (or with JavaScript disabled) nothing
  instantiates and the page renders as a complete, static, fully-readable
  document. That completeness is a hard requirement, not a fallback.

`@astrojs/react` is wired in `astro.config.mjs` so a component can opt into a
React island with a `client:*` directive, but no component does today — a
`.tsx` component with no `client:*` directive still renders to static HTML
with zero shipped JS, so the list above stays accurate until a real
interactive island ships.

Copy must follow the awareness-not-safety framing in
[`../docs/SAFETY-FRAMING.md`](../docs/SAFETY-FRAMING.md); never claim a safety
or navigation guarantee. The safety disclaimer in
`src/components/Disclaimer.astro` is verbatim doctrine text — do not edit it
without a safety-framing review.

## Read-aloud controls

Two independent, mutually-exclusive controls, both hidden until confirmed
usable (neither ever renders as a dead button):

- **Listen (device voice)** — the browser's native Web Speech API
  (`speechSynthesis`). No network calls, no API key, no third-party service,
  no backend. Always available whenever the browser supports it.
- **Listen (natural voice)** — plays a pre-rendered ElevenLabs narration
  (`public/audio/main.mp3`, served at `/audio/main.mp3`). This is a
  **build-time** integration, not a live one: `scripts/generate-audio.js`
  calls the ElevenLabs API once, offline, on a developer machine, and writes
  the result as a static asset. The deployed site never holds the ElevenLabs
  API key, never makes a live call to ElevenLabs per page view, and has no
  server-side endpoint that could be abused to relay arbitrary text through
  the key — the production attack surface is unchanged from before this
  feature existed (a static file server with zero secrets). If
  `public/audio/main.mp3` hasn't been generated yet, the `<audio>` element's
  `error` event hides this button automatically and the page falls back to
  the device-voice control only.

### Regenerating the natural-voice narration

`generate-audio.js` reads the **built** page (`dist/index.html`), not the
source, so `npm run build` must run first. Run this whenever the page's
`<main id="main">` content changes:

```sh
cd website
cp .env.example .env   # first time only; fill in ELEVENLABS_API_KEY
npm run build
npm run generate:audio
```

This overwrites `public/audio/main.mp3` and `public/audio/manifest.json`
(which records a hash of the narrated text, the voice/model used, and the
timestamp) and both must be committed together. `npm run build && npm run
check:audio` re-derives that hash from the current build output and fails CI
if it no longer matches — a stale narration would mean the natural voice says
something different from what's on the page, which is a safety-framing risk
(see [`../docs/SAFETY-FRAMING.md`](../docs/SAFETY-FRAMING.md)), not just a
nice-to-have. `check:audio` does no network I/O and needs no key, so it's
safe to run in CI unattended (after the build step); before any narration has
ever been generated it prints an informational skip instead of failing.

`.env` is git-ignored; never commit a real `ELEVENLABS_API_KEY`. The key is
only ever read by `scripts/generate-audio.js`, on whichever machine runs
`generate:audio` — it is not referenced anywhere else in the codebase.

## Internationalization

The site ships in English, Spanish, and Vietnamese via Astro's built-in i18n
routing (no i18n library dependency): `/` (English, default/unprefixed),
`/es/`, `/vi/`. Copy lives in typed dictionaries under `src/i18n/`
(`en.ts`/`es.ts`/`vi.ts`, all implementing the `Translations` interface in
`src/i18n/types.ts` — a missing key in one locale is a compile error, not a
silent fallback); components read from them via `useTranslations()`, keyed
off `Astro.currentLocale` (or `document.documentElement.lang` in the two
client scripts that need it, `read-aloud.ts` and the theme toggle in
`Header.astro`). The header's language switcher is plain `<a>` links —
keyboard-operable natively, with `aria-current="true"` marking the active
locale. See
[`../docs/superpowers/specs/2026-07-19-language-support-design.md`](../docs/superpowers/specs/2026-07-19-language-support-design.md)
for the full design (this covers the website half only; the iOS app has its
own localization).

## Local development

```sh
cd website
npm install
npm run dev        # dev server with HMR
npm run build      # prerender to dist/
npm run preview    # serve the built dist/ locally
```

## Tooling

- `npm run typecheck` — `astro check` (TypeScript strict across `.astro` and
  `.ts` files).
- `npm run lint:css` — Stylelint (`stylelint-config-standard-scss` + strict
  repo overrides in `.stylelintrc.json`: kebab-case class pattern, no
  `!important`, `selector-max-id: 0`, `no-descending-specificity`).
- `npm run lint:js` — ESLint (`eslint.config.mjs`), strict flat config:
  `eslint-plugin-astro` (with its `jsx-a11y` strict preset — accessibility is
  a first-class requirement here, not an afterthought), `typescript-eslint`
  strict + stylistic with type-aware rules, `eslint-plugin-react-hooks`
  (Hooks correctness) + `eslint-plugin-jsx-a11y`'s strict preset directly on
  `.tsx`/`.jsx` files, and `eslint-plugin-security` (every rule raised from
  its default `warn` to `error` — a security finding never ships as a
  non-blocking warning), plus project hardening rules (`no-console`,
  `no-eval`, `eqeqeq`, `curly`, banned `any`, etc.).
- `npm run audit:react` (alias: `npm run doctor`) — [React Doctor](https://github.com/millionco/react-doctor)
  static audit (Hooks correctness, a11y, security, perf) for `.tsx`/`.jsx`
  code, run with `--no-telemetry`. Also runs automatically, staged-files-only,
  in `.githooks/pre-commit` whenever a commit touches `website/`, and on every
  pull request via `.github/workflows/react-doctor.yml` (`blocking: error` —
  fails only on new error-severity findings). Its Claude Code/Cursor agent
  skill and hooks live at the repo root (`.claude/skills/react-doctor/`,
  `.agents/`, `.continue/`, `.cursor/` — not under `website/`, since this
  repo's agent config is rooted at the repo root, not per-subdirectory).
- `npm run scan` — [React Scan](https://react-scan.million.dev) render
  profiler against a running `npm run dev`; also auto-attaches in the dev
  server itself (`src/layouts/BaseLayout.astro`, gated behind
  `import.meta.env.DEV` so it never ships to production).
- `npm run format` / `npm run format:fix` — Prettier, explicit strict
  options pinned in `.prettierrc` so formatting can't silently drift.
  (`.astro` files aren't Prettier-formatted — no `prettier-plugin-astro` —
  their style is enforced by ESLint's astro plugin instead.)
- `npm run test:a11y` — [pa11y-ci](https://github.com/pa11y/pa11y-ci) against
  the built `dist/` (zero errors required). Automated checks are a floor, not
  the gate: a manual VoiceOver + keyboard pass on changed UI is still
  required per the repo's quality gates.
- `lint-staged` runs on staged `website/**` files via the repo's
  `.githooks/pre-commit` (the repo uses `core.hooksPath .githooks`, not
  Husky).
- [Impeccable](https://impeccable.style/) design-QA detectors run in CI via
  `.github/workflows/website-ci.yml` — see
  [`docs/TOOLING.md`](../docs/TOOLING.md).

## Deployment

Deploys to [Railway](https://railway.app) via `docker/Dockerfile` +
`railway.toml` at the repo root — see [`docker/README.md`](../docker/README.md)
for the container setup itself. The image is multi-stage: stage 1 runs
`npm ci --omit=dev && npm run build` (Astro prerender), stage 2 serves the
resulting `dist/` with nginx (`nginxinc/nginx-unprivileged`, non-root, no npm
in the runtime image), listening on Railway's injected `$PORT`. No secrets
exist in the image (`docker/Dockerfile.dockerignore` allowlists only
`website/`).

CI, the Railway CLI (global + project-local), and available `npm run
railway:*` commands are documented in `docker/README.md`'s "Railway deploy"
section — that's the single source of truth, not repeated here.

### First-time setup

1. Create a Railway project at [railway.app](https://railway.app) (New
   Project → Empty Project, or Deploy from GitHub repo directly).
2. Connect this GitHub repo. **Leave the service's Root Directory as the
   repo root** (Settings → Source) — do not set it to `website`. The
   Dockerfile build context has to span both `docker/` and `website/`, and
   `railway.toml`/`docker/Dockerfile` are only discovered from the root.
3. Build/run is already specified by `railway.toml` (`dockerfilePath =
"docker/Dockerfile"`) — no manual build command needed.
4. No environment variables are required **on Railway**. This is a static
   site with no backend, accounts, or telemetry (see the repo's architecture
   invariants in `../CLAUDE.md`). `ELEVENLABS_API_KEY` (see
   [Read-aloud controls](#read-aloud-controls)) is a local-only,
   generation-time secret — it is never set on Railway and never deployed;
   only the `audio/main.mp3` it produces gets shipped. If a real runtime env
   var is ever needed, document it here and set it under Service →
   Variables — never commit it.
5. Deploy: push to `main` (Railway auto-redeploys on every push once the
   GitHub connection is live) or trigger a manual deploy from the Railway
   dashboard. Watch the build logs for the first deploy to confirm nginx
   starts and the healthcheck goes green.

### Local verification before pushing

```sh
docker build -f docker/Dockerfile -t sensebridge-website .   # from the repo root
docker run -p 8080:8080 sensebridge-website
```

Or `docker compose -f docker/docker-compose.yml up web`. Then open
`http://localhost:8080`.

---

Need help? See [`SUPPORT.md`](../SUPPORT.md).
