// Verifies that the built site ships no hydrated UI-framework island.
//
// The site's defining performance posture is zero-JS-by-default: every page is
// prerendered HTML, and the only JavaScript that reaches a visitor is the
// hand-written progressive-enhancement layer (read-aloud, theme, motion,
// scenes), all of it gated and lazily loaded. React is installed and genuinely
// used — src/components/StructuredData.tsx emits the site's schema.org JSON-LD
// — but it is deliberately server-rendered with no `client:*` directive, so it
// costs a visitor nothing.
//
// That distinction is one directive wide. Adding `client:load` (or any other
// `client:*`) to a single component silently pulls React's ~187kB client
// runtime into every page that renders it. Nothing else in CI would notice:
// the build succeeds, types pass, lint passes, and the page still looks right.
// This check is the tripwire.
//
// It asserts on `<astro-island>`, the custom element Astro emits for every
// hydrated component, rather than on a bundle filename. That signal is
// framework-agnostic (React, Preact, Vue, Svelte) and survives content-hash
// changes, so it keeps working without maintenance.
//
// This is a guard, not a ban. If a future feature genuinely needs an island,
// that is a deliberate decision: add the island, then update EXPECTED_ISLANDS
// below in the same change so the budget stays explicit and reviewed.
//
// Usage:
//   npm run build          # required first — this script reads dist/
//   npm run check:zero-js  # no network, no key; CI-safe
import { readdir, readFile } from "node:fs/promises";
import path from "node:path";
import { fileURLToPath } from "node:url";

const WEBSITE_ROOT = path.dirname(path.dirname(fileURLToPath(import.meta.url)));
const DIST_DIR = path.join(WEBSITE_ROOT, "dist");

/**
 * How many pages are allowed to ship a hydrated island.
 *
 * Deliberately zero. Raising this is a performance-budget decision: say which
 * component hydrates and why in the same change that raises the number.
 */
const EXPECTED_ISLANDS = 0;

/** Marker Astro emits into the HTML for each hydrated component. */
const ISLAND_MARKER = "<astro-island";

/**
 * Collects every `.html` file under a directory.
 *
 * Iterative rather than recursive: a self-referential async function has no
 * inferable return type under the repo's type-aware ESLint config, which turns
 * every downstream use into an `any` violation.
 *
 * @param {string} root - Absolute path to search.
 * @returns {Promise<string[]>} Absolute paths of all HTML files found.
 */
async function collectHtmlFiles(root) {
  /** @type {string[]} */
  const found = [];
  /** @type {string[]} */
  const pending = [root];

  while (pending.length > 0) {
    const current = pending.pop();
    if (current === undefined) {
      break;
    }
    // Path is derived from DIST_DIR, this repo's own build output, never input.
    // eslint-disable-next-line security/detect-non-literal-fs-filename
    const entries = await readdir(current, { withFileTypes: true });
    for (const entry of entries) {
      const entryPath = path.join(current, entry.name);
      if (entry.isDirectory()) {
        pending.push(entryPath);
      } else if (entry.name.endsWith(".html")) {
        found.push(entryPath);
      }
    }
  }

  return found;
}

/**
 * Fails the process when the built output ships more islands than budgeted.
 *
 * Exits 1 with the offending routes listed, or 0 with a one-line summary.
 */
async function main() {
  let pages;
  try {
    pages = await collectHtmlFiles(DIST_DIR);
  } catch {
    console.error("check-zero-js: dist/ not found — run `npm run build` first.");
    process.exit(1);
  }

  if (pages.length === 0) {
    console.error("check-zero-js: dist/ contains no HTML — run `npm run build` first.");
    process.exit(1);
  }

  /** @type {string[]} */
  const hydrated = [];
  for (const page of pages) {
    // Page comes from collectHtmlFiles(DIST_DIR), this repo's own build output.
    // eslint-disable-next-line security/detect-non-literal-fs-filename
    const html = await readFile(page, "utf8");
    if (html.includes(ISLAND_MARKER)) {
      hydrated.push(path.relative(DIST_DIR, page));
    }
  }

  if (hydrated.length > EXPECTED_ISLANDS) {
    console.error(
      `check-zero-js: ${hydrated.length} page(s) ship a hydrated island, budget is ${EXPECTED_ISLANDS}.\n` +
        "A `client:*` directive pulls its framework runtime into every page below.\n" +
        "If this is intended, raise EXPECTED_ISLANDS in scripts/check-zero-js.js and say why.\n",
    );
    for (const route of hydrated.slice(0, 20)) {
      console.error(`  - ${route}`);
    }
    if (hydrated.length > 20) {
      console.error(`  ...and ${hydrated.length - 20} more`);
    }
    process.exit(1);
  }

  // `console.warn` rather than `log`: the repo's ESLint config allows only
  // `warn` and `error`, matching scripts/check-disclaimer.js.
  console.warn(
    `check-zero-js: ${pages.length} page(s) checked, ${hydrated.length} hydrated island(s) — zero-JS posture intact.`,
  );
}

await main();
