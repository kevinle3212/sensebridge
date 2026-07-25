// Astro config for the SenseBridge marketing site.
//
// output: "static" is Astro's default (no SSR adapter, no backend — see the
// repo's serverless/on-device architecture invariant in ../CLAUDE.md) but is
// spelled out explicitly so that invariant can't silently drift.
import { fileURLToPath } from "node:url";
import { defineConfig } from "astro/config";
import react from "@astrojs/react";
import sitemap from "@astrojs/sitemap";

export default defineConfig({
  output: "static",
  // Vercel's assigned production domain (see vercel.json / the Vercel
  // project "sensebridge") — required for Astro to emit absolute canonical
  // URLs, sitemap.xml entries, and OG/Twitter meta. This is the renamed
  // project's alias (TODO.md: binds on the next production deploy); update
  // again if a custom domain is attached later.
  site: "https://sensebridge.vercel.app",
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
  ],
  // Built-in i18n routing (no new dependency, per the language-support
  // design spec): default locale "en" is unprefixed at "/" (Astro's default
  // routing.prefixDefaultLocale: false), "es"/"vi" are prefixed at "/es/"
  // and "/vi/". See src/i18n/ for the dictionaries this drives.
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
