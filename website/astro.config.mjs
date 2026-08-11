// Astro config for the SenseBridge marketing site.
//
// output: "static" is Astro's default (no SSR adapter, no backend — see the
// repo's serverless/on-device architecture invariant in ../CLAUDE.md) but is
// spelled out explicitly so that invariant can't silently drift.
// Must come first: populates process.env from .env, which Astro does not do
// for this file (it runs before Vite's env handling). See scripts/load-env.js.
import "./scripts/load-env.js";
import { fileURLToPath } from "node:url";
import { paraglideVitePlugin } from "@inlang/paraglide-js";
import { defineConfig } from "astro/config";
import react from "@astrojs/react";
import sitemap from "@astrojs/sitemap";
import sentry from "@sentry/astro";

// Deployment origin. Astro needs an absolute one to emit canonical URLs,
// sitemap entries, robots.txt, and OG/Twitter meta — but which origin is a
// property of *your* deployment, not of this repository, so it is never
// hardcoded here. Set SITE_URL in an untracked .env locally, or as an
// environment variable in your own host's project settings. The fallback is
// the dev server's origin, so a fresh clone builds and tests green with no
// configuration at all; it just emits localhost URLs, which is correct for
// anything that is not a real deployment. See .env.example.
const DEFAULT_SITE_URL = "http://localhost:4321";
// Truthiness, not `??`: an unset variable and the empty `SITE_URL=` that
// .env.example ships both have to reach the fallback. `??` only catches the
// unset case and would hand Astro an empty origin. Do not "simplify" this —
// scripts/check-site-url.js is the regression test.
const configuredSiteUrl = process.env.SITE_URL?.trim();
// eslint-disable-next-line @typescript-eslint/prefer-nullish-coalescing -- see above
const site = configuredSiteUrl ? configuredSiteUrl : DEFAULT_SITE_URL;

// Error reporting is opt-in per deployment, and its absence is the default.
//
// Gating the *integration* on the DSN, rather than letting sentry.client.config.js
// no-op on an empty one, is what keeps this site's zero-JS-by-default posture
// intact for anyone who has not configured Sentry: with the variable unset, the
// SDK is never added to the bundle graph at all, so a fresh clone ships exactly
// as much JavaScript as it did before Sentry existed. Registering the
// integration unconditionally would inline ~35kB of disabled SDK into every
// page — code that runs on every visit to do nothing.
const sentryDsn = process.env.PUBLIC_SENTRY_DSN?.trim();

// Uploading source maps needs a write-scoped auth token, which most builds
// (a fork, CI, a local `npm run build`) neither have nor should have. Without
// one the build still succeeds and still reports errors — the stack traces are
// just minified. Never inline this token: it is the one piece of Sentry
// configuration here that is a real credential. See .env.example.
const sentryAuthToken = process.env.SENTRY_AUTH_TOKEN?.trim();

export default defineConfig({
  output: "static",
  site,
  // React only powers islands opted in via a client:* directive (see
  // https://docs.astro.build/en/guides/client-side-scripts/#client-directives).
  // A .tsx file with no client directive still renders to static HTML with
  // zero shipped JS, so the site's zero-JS-by-default posture is unchanged
  // until a component actually needs interactivity.
  integrations: [
    react(),
    sitemap({
      // The HTTP status pages (src/pages/[status].astro and the /not-found
      // alias) are reachable destinations but not discoverable ones — roughly
      // 190 of them across three locales. Listing them would bury the handful
      // of pages that actually want indexing. They also carry
      // `<meta name="robots" content="noindex">` via BaseLayout's `noindex`
      // prop, so this is the sitemap half of one decision.
      filter: (page) => !/\/(?:\d{3}|not-found)\/?$/.test(page),
    }),
    // Spread rather than a ternary yielding `false`: Astro's integration array
    // is typed as AstroIntegration[], so an empty spread is the way to say
    // "nothing here" without a cast. See sentryDsn above for why this is gated.
    ...(sentryDsn
      ? [
          sentry({
            sourceMapsUploadOptions: {
              enabled: Boolean(sentryAuthToken),
              authToken: sentryAuthToken,
              org: process.env.SENTRY_ORG,
              project: process.env.SENTRY_PROJECT,
              // Source maps are uploaded to Sentry, then deleted from dist/ so
              // they are never served publicly. Shipping them would hand any
              // visitor the site's unminified source — the readable stack trace
              // is for the maintainer, in Sentry, not for the open web.
              filesToDeleteAfterUpload: ["./dist/**/*.map"],
            },
          }),
        ]
      : []),
  ],
  // Built-in i18n routing: default locale "en" is unprefixed at "/" (Astro's
  // default routing.prefixDefaultLocale: false), "es"/"vi" are prefixed at
  // "/es/" and "/vi/". Translated strings live in Paraglide's message
  // catalogs (messages/*.json, compiled to src/paraglide/ by the vite
  // plugin below) — revisited 2026-08-07 from the hand-rolled
  // src/i18n/*.ts dictionaries this repo started with; see
  // docs/superpowers/specs/2026-07-19-LANGUAGE-SUPPORT-DESIGN.md Unit C for
  // why.
  i18n: {
    defaultLocale: "en",
    locales: ["en", "es", "vi"],
  },
  build: {
    // Astro's default ("auto") inlines any stylesheet under ~4kB into a
    // `<style>` tag. vercel.json's CSP sets `style-src 'self'` with no
    // `'unsafe-inline'`, so a browser blocks those inline blocks outright.
    // That silently deleted the error pages' entire stylesheet in production
    // — layout, fills, and every @keyframes — leaving an unstyled black-filled
    // SVG that never moved, while `astro dev` (which injects styles via JS and
    // sends no CSP) looked correct. Keeping every stylesheet an external file
    // keeps the whole site inside `'self'`. Do not relax this without also
    // adding `'unsafe-inline'`/a hash to the CSP, which is the worse trade.
    inlineStylesheets: "never",
  },
  vite: {
    // Sentry ships these as build-time flags precisely so an app that does not
    // use a feature does not pay for it. Setting `integrations: []` in
    // sentry.client.config.js stops the tracing code from *running*, but the
    // bundler still cannot prove it is unreachable, so it stays in the bundle —
    // measured on this site at 48.3kB gzipped before these and 26.9kB after. On
    // a site whose whole performance posture is zero-JS-by-default, 21kB of
    // provably dead code is worth one config block.
    //
    // Both must be string literals: Vite's `define` does a raw text
    // substitution, so a real boolean would be stringified anyway.
    //
    // If tracing is ever genuinely wanted here, flipping __SENTRY_TRACING__
    // back is required — a tracesSampleRate alone will do nothing once the code
    // has been compiled out.
    define: {
      __SENTRY_DEBUG__: "false",
      __SENTRY_TRACING__: "false",
    },
    plugins: [
      // Compiles messages/*.json into tree-shakable message functions at
      // src/paraglide/. `strategy` matches this site's own SSG routing above
      // rather than Paraglide's own URL-pattern config: src/middleware.ts sets
      // the locale explicitly per Astro's Static Site Generation guide, since
      // a static render has no request to read a locale from.
      paraglideVitePlugin({
        project: "./project.inlang",
        outdir: "./src/paraglide",
        emitTsDeclarations: true,
        strategy: ["url", "globalVariable", "baseLocale"],
      }),
    ],
    resolve: {
      alias: {
        "@styles": fileURLToPath(new URL("./src/styles", import.meta.url)),
      },
    },
    build: {
      // The one chunk over the 500kB default (three.js, ~715kB minified in
      // core.ts) is already dynamic-imported per-scene behind an
      // IntersectionObserver (see src/scripts/scenes/index.ts) — it's not
      // part of the initial page load, so the warning is noise, not a
      // regression to chase.
      chunkSizeWarningLimit: 800,
    },
  },
});
