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
  integrations: [react(), sitemap()],
  // Built-in i18n routing (no new dependency, per the language-support
  // design spec): default locale "en" is unprefixed at "/" (Astro's default
  // routing.prefixDefaultLocale: false), "es"/"vi" are prefixed at "/es/"
  // and "/vi/". See src/i18n/ for the dictionaries this drives.
  i18n: {
    defaultLocale: "en",
    locales: ["en", "es", "vi"],
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
