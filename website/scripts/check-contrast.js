// Asserts that every text-carrying colour token clears WCAG 2.2 **1.4.6
// Contrast (Enhanced), 7:1** — the Level AAA ratio, not the 4.5:1 Level AA one.
//
// This exists because that ratio is a published claim, not an internal
// preference: `legal/ACCESSIBILITY_STATEMENT.md` and the `/accessibility` page
// both state it under "Where we exceed Level AA". A claim in a legal document
// that nothing re-checks is a claim that quietly stops being true the first
// time someone nudges a hex value.
//
// It is not covered by the pa11y gate. Both engines there decline to compute a
// ratio wherever this site's animated link underline or a reveal animation puts
// a gradient behind text — axe returns `messageKey: "bgGradient"` and htmlcs
// returns `NaN:1`. Those are honest "cannot determine" results rather than
// failures, but they mean the rendered page cannot prove the palette. So the
// palette is proved at its source instead: parse the tokens, compute every
// foreground against every background of its own theme, and fail on the worst
// pairing rather than the flattering one.
//
// Usage:
//   npm run check:contrast
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const WEBSITE_ROOT = path.dirname(path.dirname(fileURLToPath(import.meta.url)));
const TOKENS = path.join(WEBSITE_ROOT, "src/styles/abstracts/_tokens.scss");

/** WCAG 2.2 success criterion 1.4.6 Contrast (Enhanced) for body-size text. */
const REQUIRED_RATIO = 7;

/**
 * Token keys that carry text and are therefore held to the ratio above.
 *
 * `accent-warm` is deliberately absent: it is decorative only (the hero glow
 * and light sweep) and never renders text, so holding it to a text contrast
 * floor would force a colour change for no reader's benefit.
 */
const FOREGROUND_KEYS = ["text-primary", "text-secondary", "accent-primary"];

/**
 * Token keys text is ever placed on. Each foreground is checked against all of
 * them, because a ratio that only holds against the page background is not the
 * ratio a reader gets inside a card.
 */
const BACKGROUND_KEYS = ["bg", "bg-elevated", "surface"];

/**
 * Themes to check, each with the literal pattern that isolates its Sass map.
 *
 * The patterns are literals rather than built from a theme name at run time so
 * no user-controllable string ever reaches the `RegExp` constructor — the same
 * reason the other scripts in this directory avoid dynamic patterns.
 */
const THEMES = [
  { name: "dark", pattern: /\$color-dark:\s*\(([\s\S]*?)\n\);/ },
  { name: "light", pattern: /\$color-light:\s*\(([\s\S]*?)\n\);/ },
];

/**
 * Extracts one SCSS palette map from `_tokens.scss` as token/hex pairs.
 *
 * Parsed rather than imported because the maps are Sass source, and shelling
 * out to the Sass compiler to read six colours would be a heavier dependency
 * than the regex it replaces. Entries whose value is not a plain hex literal
 * (`surface-glass` is `rgb(... / 60%)`) are skipped — none of them carries text.
 *
 * Returns a `Map` rather than an object so a token name read from the file is
 * never used as a property key on a prototype-bearing object.
 *
 * @param {string} source Contents of `_tokens.scss`.
 * @param {RegExp} pattern Pattern isolating one palette's map body.
 * @param {string} themeName Theme the pattern belongs to, for error messages.
 * @returns {Map<string, string>} Token key to `#rrggbb`.
 */
function parsePalette(source, pattern, themeName) {
  const block = pattern.exec(source);
  if (!block) {
    throw new Error(`check:contrast: could not find the ${themeName} palette in ${TOKENS}`);
  }

  /** @type {Map<string, string>} */
  const palette = new Map();
  for (const [, key, hex] of block[1].matchAll(/"([\w-]+)":\s*(#[0-9a-fA-F]{6})/g)) {
    palette.set(key, hex.toLowerCase());
  }
  return palette;
}

/**
 * Relative luminance of an `#rrggbb` colour, per the WCAG 2.2 definition.
 *
 * @param {string} hex Colour as `#rrggbb`.
 * @returns {number} Relative luminance in the range 0 to 1.
 */
function relativeLuminance(hex) {
  const channels = [1, 3, 5].map((offset) => {
    const value = parseInt(hex.slice(offset, offset + 2), 16) / 255;
    return value <= 0.03928 ? value / 12.92 : ((value + 0.055) / 1.055) ** 2.4;
  });
  return 0.2126 * channels[0] + 0.7152 * channels[1] + 0.0722 * channels[2];
}

/**
 * Contrast ratio between two colours, per WCAG 2.2. Order does not matter.
 *
 * @param {string} foreground Colour as `#rrggbb`.
 * @param {string} background Colour as `#rrggbb`.
 * @returns {number} Ratio between 1 and 21.
 */
function contrastRatio(foreground, background) {
  const a = relativeLuminance(foreground);
  const b = relativeLuminance(background);
  return (Math.max(a, b) + 0.05) / (Math.min(a, b) + 0.05);
}

/**
 * Checks every foreground/background pairing in both themes and reports the
 * failures.
 *
 * Exits non-zero if any pairing falls below the required ratio, so this works
 * as a CI gate.
 */
function main() {
  const source = fs.readFileSync(TOKENS, "utf8");

  const failures = [];
  let checked = 0;

  for (const { name: themeName, pattern } of THEMES) {
    const palette = parsePalette(source, pattern, themeName);
    for (const foregroundKey of FOREGROUND_KEYS) {
      for (const backgroundKey of BACKGROUND_KEYS) {
        const foreground = palette.get(foregroundKey);
        const background = palette.get(backgroundKey);
        if (!foreground || !background) {
          failures.push(
            `${themeName}: missing token — ${!foreground ? foregroundKey : backgroundKey}`,
          );
          continue;
        }

        checked += 1;
        const ratio = contrastRatio(foreground, background);
        if (ratio < REQUIRED_RATIO) {
          failures.push(
            `${themeName}: ${foregroundKey} (${foreground}) on ${backgroundKey} ` +
              `(${background}) is ${ratio.toFixed(2)}:1, below ${REQUIRED_RATIO}:1`,
          );
        }
      }
    }
  }

  if (failures.length > 0) {
    console.error("check:contrast: WCAG 1.4.6 (7:1) not met — the accessibility");
    console.error("statement claims this ratio, so fix the token or drop the claim:\n");
    for (const failure of failures) {
      console.error(`  • ${failure}`);
    }
    process.exitCode = 1;
    return;
  }

  // `console.warn` rather than `log`: the repo's ESLint config allows only
  // warn and error, matching check-site-url.js and check-zero-js.js.
  console.warn(
    `check:contrast: ${checked} token pairings all clear WCAG 1.4.6 (${REQUIRED_RATIO}:1).`,
  );
}

main();
