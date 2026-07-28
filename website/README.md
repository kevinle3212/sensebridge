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
React island with a `client:*` directive. **No component does today, and the
list above is complete.** There is exactly one React component —
`src/components/StructuredData.tsx`, which emits the site's schema.org JSON-LD
— and it is deliberately server-rendered with no `client:*` directive, so
Astro prerenders it to static HTML and it ships zero JavaScript. Verified
against the built output: all 195 pages carry valid JSON-LD, and **zero** pages
reference React's client runtime.

That component is the answer to "why is React installed at all". Keeping a
server-only `.tsx` in the tree means the React toolchain (`react-doctor`, and
ESLint's `react-hooks` + `jsx-a11y` presets) has something real to check, so
the integration is exercised rather than sitting inert until an island lands.
If you add a genuine island later, note that `client:*` **does** ship the
~187kB React runtime — budget for it deliberately.

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
`generate:audio` — it is not referenced anywhere else in the codebase. Scope
the key to text-to-speech when you create it; the script needs no other
permission, and a narrower key cannot read account or billing data.

### The voice

The narration voice is **"Janet"** (`eLDc7xhWxG2FElT3kUTj`), a professional
voice from ElevenLabs' Voice Library. The owner listened to the generated
narration on 2026-07-25 and approved it as the site's canonical voice.
**Changing `ELEVENLABS_VOICE_ID` needs a fresh listen-through, not just an
edit** — this is the voice a blind visitor hears, and consistency across
regenerations matters more here than on a typical marketing site.

The script used to default to `21m00Tcm4TlvDq8ikWAM`, documented throughout as
ElevenLabs' standard "Rachel". On this account that ID resolves to Janet:

```sh
curl -H "xi-api-key: $ELEVENLABS_API_KEY" \
  https://api.elevenlabs.io/v1/voices/21m00Tcm4TlvDq8ikWAM
# -> {"voice_id":"eLDc7xhWxG2FElT3kUTj","name":"Janet","category":"professional", ...}
```

So every narration generated through that alias was already Janet, and the
alias could remap again and silently change the site's voice on the next
regeneration. The real ID is now pinned instead. If a future regeneration
sounds different, check this first.

The committed `manifest.json` still records `"voiceId": "21m00Tcm4TlvDq8ikWAM"`
because it was written before the pin. That is cosmetic — the audio it
describes is the same Janet recording — and it corrects itself on the next
regeneration. It was not re-run just to update the field, because a
regeneration costs ~4,400 of the free plan's 10,000 monthly credits.

### Cost, quota, and licensing

The integration is build-time only, so cost scales with **how often you
regenerate**, not with traffic. A full regeneration of the English page is
roughly **4,400 characters**.

| Limit                           | Value                    | Where it binds                     |
| ------------------------------- | ------------------------ | ---------------------------------- |
| Free plan quota                 | 10,000 credits/month     | ~2 full regenerations per month    |
| Starter plan                    | $6/month, 30,000 credits | Only if regenerations get frequent |
| `eleven_turbo_v2_5` request cap | 40,000 characters        | Never — quota binds first          |
| `MAX_CHARACTERS` in the script  | 5,000 characters         | Local guard against a runaway page |

The script's own 5,000-character cap is deliberately far below the model's
40,000 limit: it exists to fail loudly if the page grows unexpectedly, before
a single request eats half a month of free quota.

Budget **two** generations whenever the narration changes, not one. The
natural-voice button's own label sits inside `<main id="main">`, which is
exactly the text `generate-audio.js` hashes — so the first run makes the
button appear, which changes the extracted text, which makes `check:audio`
report stale. The second run converges. This is stable unless that control's
markup or label changes.

**Licensing — read before the site goes public.** ElevenLabs' free plan
[does not include a commercial license](https://elevenlabs.io/pricing) and
[requires attribution](https://help.elevenlabs.io/hc/en-us/articles/13313564601361-Can-I-publish-the-content-I-generate-on-the-platform):
content generated on a free plan may be used for non-commercial purposes only,
and published content must credit ElevenLabs by including `elevenlabs.io` in
the title. Paid plans grant commercial rights to whatever was generated while
subscribed, and those rights survive cancellation — but audio generated
outside a subscription always requires attribution.

**This account is on the free plan** (owner-confirmed 2026-07-25), so both
conditions apply to `public/audio/main.mp3` and are handled as follows.

_Attribution._ `Footer.astro` renders "Natural voice narration generated with
elevenlabs.io." on every route that ships the audio, gated by the same
`hasNaturalVoice()` helper the player uses so the credit and the audio can
never disagree. It sits in the footer rather than beside the player on
purpose: the player is inside `<main id="main">`, the exact text
`generate-audio.js` hashes, so a credit there would invalidate the narration
and cost a regeneration every time the wording changed. The obligation
attaches to the audio itself and survives a later upgrade — **do not remove
this credit when the plan changes**; remove it only if the audio is
regenerated under a paid plan.

_Non-commercial use._ SenseBridge is free, open source, and sells nothing, so
the site is non-commercial today. If that ever changes — paid tier, sponsored
placement, anything transactional — this audio must be regenerated under a
paid plan before the change ships. That is a `legal/` matter, owner-gated per
[`../CLAUDE.md`](../CLAUDE.md); see [`../TODO.md`](../TODO.md).

Note that plan status is **not verifiable from this repo**: the API key is
scoped to text-to-speech, so `/v1/user/subscription` returns
`missing_permissions`. Re-check on the
[ElevenLabs dashboard](https://elevenlabs.io/app/settings) rather than
inferring it from anything here.

## Internationalization

The site ships in English, Spanish, and Vietnamese via Astro's built-in i18n
routing (no i18n library dependency): `/` (English, default/unprefixed),
`/es/`, `/vi/`. Copy lives in typed dictionaries under `src/i18n/`
(`en.ts`/`es.ts`/`vi.ts`, all implementing the `Translations` interface in
`src/i18n/types.ts` — a missing key in one locale is a compile error, not a
silent fallback); components read from them via `useTranslations()`, keyed
off `Astro.currentLocale` (or `document.documentElement.lang` in the two
client scripts that need it, `read-aloud.ts` and the theme toggle in
`Header.astro`). The header's language switcher is a native
`<details>`/`<summary>` dropdown — keyboard-operable and screen-reader
labeled without any ARIA state management (the browser exposes
`aria-expanded` on `<summary>` for free), with `aria-current="page"` marking
the active locale in the menu. See
[`../docs/superpowers/specs/2026-07-19-LANGUAGE-SUPPORT-DESIGN.md`](../docs/superpowers/specs/2026-07-19-LANGUAGE-SUPPORT-DESIGN.md)
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

### Verbose logging

The client scripts log their decision points to the browser console through
`src/scripts/debug.ts` — the reduced-motion branch, the WebGL quality gate and
each 3D scene mount, read-aloud availability, and the resolved theme. This is
always on under `npm run dev`.

On a built or deployed site it is off until you opt in:

```js
localStorage.setItem("sb-debug", "1"); // then reload
localStorage.removeItem("sb-debug"); // back off
```

The flag is read once at load, so a reload is required either way. Filter the
console by `[sb:` for everything, or `[sb:motion` / `[sb:scenes` /
`[sb:read-aloud` / `[sb:theme` / `[sb:page-loader` for one subsystem.

Vercel has no equivalent browser-side switch — this is a static deployment, so
its own verbosity is build-log only (`vercel build --debug` locally, or the
full build log in the dashboard). Nothing on the Vercel side reaches the
visitor's console.

### Working on the page-load sequence

The "Span the gap" overlay (`src/components/PageLoader.astro`) is over in well
under two seconds, which makes it awkward to inspect. Freeze it at any point
from the console:

```js
const loader = document.querySelector("[data-page-loader]");
document.documentElement.dataset.pageLoad = "building"; // or "open" / "closing"
loader.style.setProperty("--page-build", "0.62"); // 0 → 1; drives everything
document.getAnimations().forEach((a) => {
  a.pause();
  a.currentTime = 420;
}); // hold the unlock mid-flight
```

Removing the `data-page-load` attribute returns the overlay to `display: none`,
which is its resting state.

Two things do not reproduce locally, so check them deliberately:

- **The overlay never appears under reduced motion.** Neither `npm run dev` nor
  a normal browser session exercises that branch. Launch Chrome with
  `--force-prefers-reduced-motion`, or toggle the OS setting, and confirm the
  `data-page-load` attribute is never set at all.
- **CSP.** Neither `astro dev` nor `astro preview` sends the
  `Content-Security-Policy` header from `vercel.json`, so anything it would
  block still works locally. That header is `script-src 'self'` and
  `style-src 'self'` with no `'unsafe-inline'`: bootstrap scripts must be
  external files (hence `public/page-load.js` alongside `public/theme-init.js`),
  and an inline `style="..."` attribute in markup is discarded outright.
  Setting a property from JS (`element.style.setProperty(...)`) is CSSOM and is
  unaffected.

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
  pull request via `.github/workflows/react-doctor.yml` (`blocking: warning` —
  **any** finding fails the check, so the scan stays at zero). Its Claude
  Code/Cursor agent skill and hooks live at the repo root
  (`.claude/skills/react-doctor/`, `.agents/`, `.continue/`, `.cursor/` — not
  under `website/`, since this repo's agent config is rooted at the repo root,
  not per-subdirectory).

  The gate is "zero findings", not a numeric score, and that is deliberate:
  React Doctor's score is computed by a **remote score API**, and the
  `--no-telemetry` flag this repo runs with is documented upstream as an alias
  for `--no-score`. Printing a score would mean sending repository diagnostics
  off-device, which this project does not do (see [`docs/PRIVACY.md`](../docs/PRIVACY.md)).
  A run with zero findings is exactly what a perfect score reports, without the
  egress.

  Known false positives are suppressed — with rationale, per file, per rule —
  in [`doctor.config.jsonc`](doctor.config.jsonc). React Doctor's dead-code
  pass does not follow imports out of `src/layouts/**`, so components reachable
  only through `BaseLayout.astro` read as orphaned. No lint rule is weakened by
  that config; every security, bug, performance, and accessibility rule runs at
  its default severity.

- **React Scan** — [React Scan](https://react-scan.million.dev) render profiler.
  There is no `npm run scan` script: react-scan 0.5.x's CLI exposes only
  `init` (a project scaffolder that installs packages and rewrites config), so
  the old `react-scan http://localhost:4321` script failed with
  `error: unknown command` and was removed. The profiler instead auto-attaches
  in the dev server (`src/layouts/BaseLayout.astro`, gated behind
  `import.meta.env.DEV` so it never ships to production) — just run
  `npm run dev`. React Scan is an interactive, browser-driven profiler that
  emits no pass/fail and no score, so it **cannot** be a CI gate. It also has
  nothing to profile today: the site currently has zero `.tsx`/`.jsx`
  components, and React is present only so an island can opt in later.
- `npm run format` / `npm run format:fix` — Prettier, explicit strict
  options pinned in `.prettierrc` so formatting can't silently drift.
  (`.astro` files are covered via `prettier-plugin-astro`, added 2026-07-21.
  One exception: `src/layouts/BaseLayout.astro` is listed in `.prettierignore`
  because the plugin cannot parse a `<script>` nested inside a JSX expression,
  which is how the dev-only React Scan block is gated. It is still covered by
  ESLint, `astro check`, and the build.)
- `npm run test:a11y` — [pa11y-ci](https://github.com/pa11y/pa11y-ci) against
  the built `dist/` (zero errors required). Automated checks are a floor, not
  the gate: a manual VoiceOver + keyboard pass on changed UI is still
  required per the repo's quality gates.
- `npm run check:zero-js` — asserts the built `dist/` ships **no hydrated
  island**, guarding the zero-JS-by-default posture. Requires `npm run build`
  first; no network, no key. It asserts on `<astro-island>`, the element Astro
  emits for every `client:*` component, so it is framework-agnostic and immune
  to content-hash churn. This exists because the failure it catches is
  invisible to everything else: adding one `client:*` directive pulls React's
  ~187kB runtime into every page that renders the component while the build,
  types, lint, and Prettier all still pass. Measured, not estimated — a
  throwaway island was added to confirm both that the runtime ships and that
  this check fails. Adding an island later is fine; raise `EXPECTED_ISLANDS`
  in `scripts/check-zero-js.js` in the same change so the budget stays
  explicit.
- `npm run check:scene-drag` — drives a real pointer over the built `dist/` and
  asserts the Spatial Future stage mounts its WebGL scene, marks itself
  `.scene-dragging` while a drag is in flight, clears that class on release,
  and logs no page errors. Requires `npm run build` first; serves `dist/` on an
  ephemeral port for the run and closes it again. This exists because the
  drag-to-orbit gesture (`createDragOrbit` in `src/scripts/scenes/core.ts`) is
  the one part of the scene system a typecheck, lint, and build all pass
  without ever exercising — the alternative was asking a human to drag the
  glasses and report back. Runs in CI's `a11y` job, which already downloads the
  Chrome this needs.
- `npm run check:site-url` — asserts every absolute URL in the built `dist/`
  (canonical link, sitemap, `robots.txt`) comes from the configured `SITE_URL`
  rather than a domain baked into tracked source. Requires `npm run build`
  first, with the same `SITE_URL`; no network, no key. This exists because the
  failure it catches is silent: a hardcoded origin builds, lints, and type-
  checks perfectly, and only shows up as a fork advertising somebody else's
  deployment as its canonical home. See [Deployment](#deployment).
- `npm run check:csp` — serves the built `dist/` **with the real production
  Content-Security-Policy header** and asserts the pages still work under it.
  Requires `npm run build` first; no network beyond localhost.

  This exists because the two servers you actually look at lie: neither
  `astro dev` nor `astro preview` sends a CSP header, so anything
  `style-src 'self'` forbids looks perfect locally and breaks only once
  deployed. Two bugs shipped that way — Astro's default `inlineStylesheets:
"auto"` silently deleting the error pages' entire stylesheet, and
  `SpineNode.astro` positioning every Signal Spine marker with an inline
  `style` attribute the browser then discarded. Neither was visible to the
  build, `astro check`, Stylelint, ESLint, or pa11y.

  The script reads the policy out of `vercel.json` rather than restating it,
  so the header under test cannot drift from the header that ships, and it
  fails on any `securitypolicyviolation` the browser reports, not just on its
  hand-written assertions. Add a route to `ROUTES` in `scripts/check-csp.js`
  when a page starts depending on something the CSP could take away.

  **Rule of thumb it encodes:** an inline `style="..."` attribute in any
  `.astro` file is dead code in production. Use a `data-*` attribute matched
  from a stylesheet, or a class toggle. `element.style.setProperty()` from
  JavaScript is fine — `style-src` governs markup and stylesheet loads, not
  the CSSOM — and the script asserts that rather than assuming it.

  Both pa11y and this check drive Chrome through Puppeteer, which uses its own
  browser in `~/.cache/puppeteer`. Neither needs any environment variable —
  install that browser once and both gates just run:

  ```sh
  npx puppeteer browsers install chrome
  ```

  **Run that install under Node 22 LTS** (the version CI and `engines` pin),
  not a newer major. On Node 26 the command exits `0` having written only
  ~450 kB of the ~350 MB archive: the download is complete, but Puppeteer's
  unpack step silently truncates, so the `.app` bundle is missing its
  `Frameworks/` directory entirely and every launch dies with
  `dlopen … Google Chrome for Testing Framework … (no such file)`. Nothing
  reports an error, which is what makes it read as "Puppeteer's Chrome is
  broken on this machine" rather than as a bad extraction.

  To repair an existing truncated install without re-downloading, unpack the
  cached archive with the system `unzip`, which handles it correctly:

  ```sh
  unzip -q -o ~/.cache/puppeteer/chrome/*-chrome-mac-arm64.zip \
    -d ~/.cache/puppeteer/chrome/mac_arm-<version>
  ```

  Verify with `npx puppeteer browsers list` plus a launch, or just run
  `npm run test:a11y`.

  Fallback, only if the bundled browser genuinely cannot be fixed on a given
  machine: point Puppeteer at a local Chrome install. This stays out of
  `.pa11yci.json` on purpose, since a hardcoded macOS path would break Linux
  CI, which supplies its own Chrome:

  ```sh
  PUPPETEER_EXECUTABLE_PATH="/Applications/Google Chrome.app/Contents/MacOS/Google Chrome" \
    npm run test:a11y
  ```

  `npm run test:a11y` needs a server on `127.0.0.1:4321`, so run
  `npm run preview` first. That script passes `--host 127.0.0.1` for this
  reason — bare `astro preview` binds `::1`, which those URLs do not reach,
  and pa11y then fails against a server that is demonstrably up.

- `lint-staged` runs on staged `website/**` files via the repo's
  `.githooks/pre-commit` (the repo uses `core.hooksPath .githooks`, not
  Husky).
- [Impeccable](https://impeccable.style/) design-QA detectors run in CI via
  `.github/workflows/website-ci.yml` — see
  [`docs/TOOLING.md`](../docs/TOOLING.md).

## Deployment

The **official SenseBridge site is <https://sensebridge.vercel.app>**. That is
the canonical, published deployment; anything else built from this repository
is a fork or a preview and should say so via its own `SITE_URL`.

**Nothing in this repository points at a particular hosting account.** The one
value that is specific to a deployment — its absolute origin — is read from
`SITE_URL` and falls back to `http://localhost:4321`, so a fresh clone builds
and passes every check with no configuration and never advertises somebody
else's domain as its canonical home. Set `SITE_URL` in an untracked `.env`
(copy `.env.example`) or, better, as an environment variable in your own
host's project settings, so the value never lands in the repository:

```sh
SITE_URL=https://your-site.example.com npm run build
npm run check:site-url   # asserts the build agrees with the configured origin
```

Every npm script here reads `.env` on its own — `build`, `dev`, `preview`, the
`check:*` gates, `generate:audio`, and the `railway:*` / `vercel:*` wrappers —
so once a value is in the file there is nothing to pass on the command line.
The repo root's `.env` is read first for values shared with the shell scripts
and git hooks, then this directory's, and anything already exported in your
shell or in CI beats both. Mechanism:
[`scripts/load-env.js`](scripts/load-env.js) and
[`../docs/ENVIRONMENT.md`](../docs/ENVIRONMENT.md#env-is-loaded-automatically).

`railway.toml`, `vercel.json`, and `docker/` carry no account identifiers, and
`.vercel/` (which holds the Vercel CLI's `projectId`/`orgId`) is git-ignored —
so `npm run railway:*` and `npm run vercel:*` below act on whatever project
_you_ are logged into, never on this project's. Deploy the fork anywhere; the
sections below describe how the upstream repository happens to be hosted, not
a requirement.

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

Vercel (see `TODO.md`'s "Vercel production hosting" entries for current
status) auto-deploys from its GitHub App integration, so no manual deploy step
is normally needed. For ad hoc inspection or a manual production deploy, `npm
run vercel:*` invokes the Vercel CLI on demand via `npx --yes vercel` (not a
pinned dependency, same tradeoff as `railway:*` above):

```sh
npm run vercel:deploy    # deploy the current checkout straight to production
npm run vercel:preview   # deploy a preview (no --prod)
npm run vercel:logs      # stream/query logs for the linked project
npm run vercel:ls        # list recent deployments
npm run vercel:inspect   # inspect the latest deployment, including its logs
```

### First-time setup

1. Create a Railway project at [railway.app](https://railway.app) (New
   Project → Empty Project, or Deploy from GitHub repo directly).
2. Connect this GitHub repo. **Leave the service's Root Directory as the
   repo root** (Settings → Source) — do not set it to `website`. The
   Dockerfile build context has to span both `docker/` and `website/`, and
   `railway.toml`/`docker/Dockerfile` are only discovered from the root.
3. Build/run is already specified by `railway.toml` (`dockerfilePath =
"docker/Dockerfile"`) — no manual build command needed.
4. Set `SITE_URL` under Service → Variables to the origin the service will
   actually serve from (no trailing slash). It is read at **build** time, not
   run time — a static site has no runtime environment — so changing it needs
   a redeploy, not a restart. Leaving it unset is safe but wrong for a real
   deployment: canonical links, the sitemap, `robots.txt`, and the OG/Twitter
   meta will all point at `localhost`.

   Nothing else is required. This is a static site with no backend, accounts,
   or telemetry (see the repo's architecture invariants in `../CLAUDE.md`).
   `ELEVENLABS_API_KEY` (see [Read-aloud controls](#read-aloud-controls)) is a
   local-only, generation-time secret — it is never set on Railway and never
   deployed; only the `audio/main.mp3` it produces gets shipped. If another
   real build- or runtime env var is ever needed, document it here and in
   `.env.example`, and set it under Service → Variables — never commit it.

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
