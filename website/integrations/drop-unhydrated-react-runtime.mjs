// Every filesystem call here takes a path this module built itself by walking
// the build output directory Astro handed it — there is no user input anywhere
// in the chain. Disabled file-wide rather than per line, the same way
// scripts/load-env.js does, because every call in the file is the same case.
/* eslint-disable security/detect-non-literal-fs-filename */
import { readdir, readFile, stat, unlink } from "node:fs/promises";
import path from "node:path";

/**
 * Astro integration that removes the React DOM client runtime from the build
 * output when no island actually hydrates.
 *
 * `@astrojs/react` registers a client entrypoint for the whole site as soon as
 * the integration is installed. This site keeps the integration on purpose —
 * `StructuredData.tsx` is server-rendered with no `client:*` directive, and it
 * exists partly so `react-doctor` has real `.tsx` to analyse — but that means
 * Vite emits `_astro/client.<hash>.js` (~187kB) into every build with nothing
 * referencing it. It is never served to a visitor, so this is dead weight in
 * the deployed artifact rather than a performance bug; it still gets uploaded,
 * cached, and scanned on every deploy.
 *
 * ## Why this is safe
 *
 * Three conditions must all hold before anything is removed, and a failure of
 * any one leaves the build untouched:
 *
 * 1. No built HTML file contains `astro-island`. That element is how Astro
 *    marks a hydrating component, so its complete absence is proof that no
 *    renderer runtime can be reached at runtime.
 * 2. The candidate matches `client.<hash>.js` directly under `_astro/` — the
 *    renderer entrypoint's own naming, not a general sweep.
 * 3. No other emitted file names it. Deleting by "unreferenced in HTML" alone
 *    would be wrong here: `scenes/core` is dynamic-imported from JavaScript and
 *    appears in no HTML either, and removing it would break the 3D scenes.
 *
 * The moment a component gains a `client:*` directive, condition 1 fails and
 * this becomes a no-op — no one has to remember to disable it.
 *
 * @returns {import("astro").AstroIntegration} The integration to register.
 */
export default function dropUnhydratedReactRuntime() {
  return {
    name: "sensebridge:drop-unhydrated-react-runtime",
    hooks: {
      "astro:build:done": async ({ dir, logger }) => {
        const files = await collectFiles(dir.pathname);
        /** @type {string[]} */
        const html = files.filter((file) => file.endsWith(".html"));
        /** @type {string[]} */
        const assets = files.filter((file) => /\.(?:js|css|json|map)$/.test(file));

        const htmlContents = await Promise.all(html.map((file) => readFile(file, "utf8")));
        if (htmlContents.some((text) => text.includes("astro-island"))) {
          logger.info("an island hydrates — leaving the React client runtime in place");
          return;
        }

        const candidates = files.filter(
          (file) =>
            path.basename(path.dirname(file)) === "_astro" &&
            /^client\.[A-Za-z0-9_-]+\.js$/.test(path.basename(file)),
        );
        if (candidates.length === 0) {
          return;
        }

        // A Set, and a single pass: `assets` is every emitted asset in the
        // build, so an `includes()` scan per file made this quadratic in the
        // size of the output directory.
        const candidateSet = new Set(candidates);
        const otherReads = [];
        for (const file of assets) {
          if (!candidateSet.has(file)) {
            otherReads.push(readFile(file, "utf8"));
          }
        }
        const otherContents = await Promise.all(otherReads);
        const allText = [...htmlContents, ...otherContents];

        for (const candidate of candidates) {
          const name = path.basename(candidate);
          if (allText.some((text) => text.includes(name))) {
            logger.info(`${name} is referenced — keeping it`);
            continue;
          }
          const { size } = await stat(candidate);
          await unlink(candidate);
          logger.info(
            `removed unreferenced ${name} (${Math.round(size / 1024)}kB, no island hydrates)`,
          );
        }
      },
    },
  };
}

/**
 * Lists every file under a directory, recursively.
 *
 * @param {string} dir Absolute path to walk.
 * @returns {Promise<string[]>} Absolute paths of every file found, in no
 *   guaranteed order.
 */
async function collectFiles(dir) {
  const entries = await readdir(dir, { withFileTypes: true });
  const nested = await Promise.all(
    entries.map((entry) => {
      const full = path.join(dir, entry.name);
      return entry.isDirectory() ? collectFiles(full) : Promise.resolve([full]);
    }),
  );
  return nested.flat();
}
