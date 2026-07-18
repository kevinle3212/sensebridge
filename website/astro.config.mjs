// Astro config for the SenseBridge marketing site.
//
// output: "static" is Astro's default (no SSR adapter, no backend — see the
// repo's serverless/on-device architecture invariant in ../CLAUDE.md) but is
// spelled out explicitly so that invariant can't silently drift.
import { fileURLToPath } from "node:url";
import { defineConfig } from "astro/config";

export default defineConfig({
  output: "static",
  vite: {
    resolve: {
      alias: {
        "@styles": fileURLToPath(new URL("./src/styles", import.meta.url)),
      },
    },
  },
});
