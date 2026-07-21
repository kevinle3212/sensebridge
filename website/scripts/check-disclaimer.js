// Verifies that the safety disclaimer reaches the built HTML verbatim, in
// every shipped locale.
//
// The disclaimer is the site's expression of the "awareness, not safety"
// doctrine (docs/SAFETY-FRAMING.md): SenseBridge raises awareness, it is not a
// mobility or navigation safety device, and its descriptions can be wrong.
// docs/SAFETY-FRAMING.md classifies a change that weakens this framing as a
// release-blocking defect — "above crashes, above performance regressions" —
// and legal/DISCLAIMER.md plus legal/TERMS_AND_CONDITIONS.md rest on the same
// wording.
//
// The strings below are pinned deliberately, and are *not* imported from
// src/i18n/. Importing them would make this check tautological: it would pass
// no matter how the copy was edited. Pinning means any edit to the disclaimer
// text fails CI until someone updates this file too, which is exactly the
// review checkpoint the doctrine asks for. Changing a pinned string is a
// safety-framing review, not a copy tweak — route it through the
// safety-framing-reviewer agent.
//
// Usage:
//   npm run build             # required first — this script reads dist/
//   npm run check:disclaimer  # no network, no key; CI-safe
import { readFile } from "node:fs/promises";
import path from "node:path";
import { fileURLToPath } from "node:url";

const WEBSITE_ROOT = path.dirname(path.dirname(fileURLToPath(import.meta.url)));
const DIST_DIR = path.join(WEBSITE_ROOT, "dist");

/**
 * The disclaimer text each locale's built page must contain verbatim, keyed by
 * the route it is served from. Mirrors `disclaimer.text` in src/i18n/<locale>.ts.
 */
const PINNED_DISCLAIMERS = [
  {
    locale: "en",
    route: "/",
    page: "index.html",
    text:
      "SenseBridge raises awareness of your surroundings. It is not a mobility " +
      "or navigation safety device, and its descriptions can be wrong — always " +
      "use it alongside your own judgment, a cane, or a guide dog.",
  },
  {
    locale: "es",
    route: "/es/",
    page: path.join("es", "index.html"),
    text:
      "SenseBridge te ayuda a tomar conciencia de tu entorno. No es un " +
      "dispositivo de seguridad para movilidad o navegación, y sus " +
      "descripciones pueden ser incorrectas — úsalo siempre junto con tu " +
      "propio juicio, un bastón o un perro guía.",
  },
  {
    locale: "vi",
    route: "/vi/",
    page: path.join("vi", "index.html"),
    text:
      "SenseBridge giúp bạn nhận thức rõ hơn về môi trường xung quanh. Đây " +
      "không phải là thiết bị an toàn hỗ trợ di chuyển hay định hướng, và các " +
      "mô tả của nó có thể sai — hãy luôn sử dụng cùng với phán đoán của chính " +
      "bạn, gậy dò đường, hoặc chó dẫn đường.",
  },
];

/**
 * Reads a built page, returning `null` when it is missing so the caller can
 * report a helpful "run npm run build first" message instead of a stack trace.
 *
 * @param {string} page Path to the page, relative to `dist/`.
 * @returns {Promise<string | null>} The page's HTML, or `null` if absent.
 */
async function readBuiltPage(page) {
  try {
    // `page` always comes from the PINNED_DISCLAIMERS literal below, never
    // from user input or the environment.
    // eslint-disable-next-line security/detect-non-literal-fs-filename
    return await readFile(path.join(DIST_DIR, page), "utf8");
  } catch (error) {
    if (error.code === "ENOENT") return null;
    throw error;
  }
}

/**
 * Checks every pinned disclaimer against its built page.
 *
 * @returns {Promise<string[]>} One human-readable message per failure; empty
 *   when every locale passes.
 */
async function findFailures() {
  const failures = [];

  for (const { locale, route, page, text } of PINNED_DISCLAIMERS) {
    const html = await readBuiltPage(page);

    if (html === null) {
      failures.push(`${locale} (${route}): dist/${page} is missing — run \`npm run build\` first.`);
      continue;
    }

    if (!html.includes(text)) {
      failures.push(
        `${locale} (${route}): the pinned safety disclaimer is not present verbatim in ` +
          `dist/${page}.\n    Expected to find: ${text}`,
      );
    }
  }

  return failures;
}

const failures = await findFailures();

if (failures.length > 0) {
  console.error("Safety-disclaimer check FAILED.\n");
  for (const failure of failures) {
    console.error(`  - ${failure}`);
  }
  console.error(
    "\nThe disclaimer is a release-blocking safety surface, not copy — see " +
      "docs/SAFETY-FRAMING.md.\nIf the wording changed intentionally, update " +
      "both src/i18n/<locale>.ts and the pinned strings in this script, and " +
      "route the change through the safety-framing-reviewer agent.",
  );
  process.exit(1);
}

// `console.warn` rather than `log`: the repo's ESLint config allows only
// `warn`/`error`, and scripts/generate-audio.js reports success the same way.
console.warn(`Safety-disclaimer check passed for ${PINNED_DISCLAIMERS.length} locales.`);
