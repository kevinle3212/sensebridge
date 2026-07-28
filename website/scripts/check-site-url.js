// Verifies that the built output carries the *configured* deployment origin,
// and never a hardcoded one.
//
// `SITE_URL` (see .env.example and astro.config.mjs) is the single source of
// the absolute origin Astro stamps into canonical links, OG/Twitter meta,
// robots.txt, and the sitemap. It falls back to http://localhost:4321 so a
// fresh clone builds green with no configuration. That fallback is the part
// worth guarding: if the wiring ever breaks — a stray literal domain in a
// layout, a `public/robots.txt` reintroduced next to the route that generates
// it — the build still succeeds, and a fork silently starts advertising
// somebody else's deployment as its canonical home. This check fails instead.
//
// Usage:
//   npm run build            # required first — this script reads dist/
//   npm run check:site-url   # no network, no key; CI-safe
//
// It resolves `SITE_URL` exactly as astro.config.mjs does, so running it with
// a different `SITE_URL` than the build used is a failure, not a false alarm.
import "./load-env.js";
import { readFile } from "node:fs/promises";
import path from "node:path";
import { fileURLToPath } from "node:url";

const WEBSITE_ROOT = path.dirname(path.dirname(fileURLToPath(import.meta.url)));
const DIST_DIR = path.join(WEBSITE_ROOT, "dist");

/**
 * Mirrors astro.config.mjs's fallback and its empty-string handling — the
 * truthiness check is deliberate there and here, so `SITE_URL=` (which
 * .env.example ships) reaches the fallback instead of yielding an empty origin.
 */
const DEFAULT_SITE_URL = "http://localhost:4321";
const configuredSiteUrl = process.env.SITE_URL?.trim();
// eslint-disable-next-line @typescript-eslint/prefer-nullish-coalescing -- see above
const site = new URL(configuredSiteUrl ? configuredSiteUrl : DEFAULT_SITE_URL);

/**
 * Built files that must reference the configured origin, and the exact string
 * each one has to contain.
 */
const EXPECTATIONS = [
  { file: "robots.txt", needle: new URL("sitemap-index.xml", site).href },
  { file: "sitemap-index.xml", needle: site.origin },
  { file: "index.html", needle: `<link rel="canonical" href="${new URL("/", site).href}"` },
];

/**
 * Reads a built file, returning `null` when it is missing so the caller can
 * report a helpful "run npm run build first" message instead of a stack trace.
 *
 * @param {string} file Path to the file, relative to `dist/`.
 * @returns {Promise<string | null>} The file's contents, or `null` if absent.
 */
async function readBuiltFile(file) {
  try {
    // `file` always comes from the EXPECTATIONS literal above, never from user
    // input or the environment.
    // eslint-disable-next-line security/detect-non-literal-fs-filename
    return await readFile(path.join(DIST_DIR, file), "utf8");
  } catch (error) {
    if (error.code === "ENOENT") return null;
    throw error;
  }
}

/**
 * Checks every expectation against the built output.
 *
 * @returns {Promise<string[]>} One human-readable message per failure; empty
 *   when the whole build agrees on the configured origin.
 */
async function findFailures() {
  const failures = [];

  for (const { file, needle } of EXPECTATIONS) {
    const contents = await readBuiltFile(file);

    if (contents === null) {
      failures.push(`dist/${file} is missing — run \`npm run build\` first.`);
      continue;
    }

    if (!contents.includes(needle)) {
      failures.push(
        `dist/${file} does not reference the configured origin.\n    Expected: ${needle}`,
      );
    }
  }

  return failures;
}

const failures = await findFailures();

if (failures.length > 0) {
  console.error(`Site-URL check FAILED (SITE_URL resolved to ${site.origin}).\n`);
  for (const failure of failures) {
    console.error(`  - ${failure}`);
  }
  console.error(
    "\nEvery absolute URL in the build must come from `SITE_URL` (see " +
      ".env.example). If this failed after a config change, rebuild with the " +
      "same SITE_URL you are checking against. If it failed after an edit to " +
      "a layout or to public/, look for a hardcoded domain — that is the bug " +
      "this check exists to catch.",
  );
  process.exit(1);
}

// `console.warn` rather than `log`: the repo's ESLint config allows only
// `warn`/`error`, and the sibling check scripts report success the same way.
console.warn(`Site-URL check passed — the build consistently uses ${site.origin}.`);
