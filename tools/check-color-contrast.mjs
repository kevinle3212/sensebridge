#!/usr/bin/env node
// check-color-contrast.mjs — every authored color asset clears WCAG AA against
// the system backgrounds this app actually renders on, in both appearances.
//
// Why this exists as a repo gate rather than only as an XCUITest assertion.
// `XCUIAccessibilityAudit`'s `.contrast` check is the real authority, because it
// measures rendered pixels — but it only runs on a device (the Simulator does
// not model the P3 display), it needs an unlocked phone, and it reports its
// findings as the bare string "Contrast nearly passed", naming neither the
// element nor the ratio. The first device run of the UI suite (2026-08-19)
// failed four audits and identified nothing.
//
// The arithmetic underneath it is not device-dependent at all. WCAG 2.1's
// contrast ratio is a pure function of two sRGB colors, so an authored color
// that cannot clear 4.5:1 against a background it will certainly be drawn on is
// a defect provable at rest, in milliseconds, in CI, with no hardware. That is
// what this checks. It does not replace the device audit — a color can pass
// here and still be composited over something unexpected — it removes the class
// of failure that never needed a phone to find.
//
// What it found on its first run: `AccentColor`'s dark variant `#0A84FF`
// (Apple's own systemBlue for dark mode) measures 3.82:1 against
// `#2C2C2E` — iOS's dark grouped-row background — which is inside the
// 3.0-4.5 band whose audit message is "Contrast is not high enough for element
// unless font size is larger". That is exactly what the device reported for the
// onboarding "Next" button and the Read screen's "Reading history" link, both
// default-styled accent-colored labels at body size.
//
// Usage: node tools/check-color-contrast.mjs
// Exits non-zero, naming every failing pair, if any ratio falls below the floor.

import { readdirSync, readFileSync } from "node:fs";
import { join } from "node:path";

/**
 * Directory holding the app's authored color assets.
 *
 * `COLOR_ASSET_DIR` overrides it, which exists for the regression test in
 * `tools/tests/`: a checker whose only input is one hardcoded path can be run
 * but not *tested*, and a gate nobody can prove goes red is a gate nobody
 * should trust. Same seam as `GIT_BIN` in `check-npm-script-files.mjs`.
 */
const ASSET_DIR =
  process.env.COLOR_ASSET_DIR ?? "app/SenseBridge/Resources/Assets.xcassets";

/**
 * WCAG AA for normal-size text. Deliberately not the 3:1 large-text figure:
 * these assets are used for body-size labels, and "make the font bigger" is a
 * different fix that has to be chosen per-view rather than assumed here.
 */
const FLOOR = 4.5;

/**
 * The backgrounds an authored color is drawn on, per appearance.
 *
 * Not a guess at iOS internals — the dark grouped values are what a real device
 * was measured rendering. `#323236` is the value pixel-sampled off this app on
 * hardware and recorded in `AccessibilityAuditSupport.swift`; `#1C1C1E` and
 * `#2C2C2E` are the documented system grouped backgrounds a `List` row sits on.
 * A color has to clear the floor against *every* one of them, because which it
 * lands on depends on the view, not on the color.
 */
const BACKGROUNDS = {
  light: {
    systemBackground: "#FFFFFF",
    systemGroupedBackground: "#F2F2F7",
  },
  dark: {
    systemBackground: "#000000",
    secondarySystemGroupedBackground: "#1C1C1E",
    tertiarySystemGroupedBackground: "#2C2C2E",
    measuredOnDevice: "#323236",
  },
};

/**
 * Converts one sRGB channel (0-255) to its linear-light value.
 *
 * @param {number} channel Channel value, 0-255.
 * @returns {number} Linearized channel, 0-1.
 */
function linearize(channel) {
  const normalized = channel / 255;
  return normalized <= 0.04045
    ? normalized / 12.92
    : ((normalized + 0.055) / 1.055) ** 2.4;
}

/**
 * WCAG relative luminance of an sRGB color.
 *
 * @param {{r: number, g: number, b: number}} color Channel values, 0-255.
 * @returns {number} Relative luminance, 0-1.
 */
function luminance({ r, g, b }) {
  return 0.2126 * linearize(r) + 0.7152 * linearize(g) + 0.0722 * linearize(b);
}

/**
 * WCAG 2.1 contrast ratio between two colors. Order-independent.
 *
 * @param {{r: number, g: number, b: number}} a One color.
 * @param {{r: number, g: number, b: number}} b The other.
 * @returns {number} Ratio between 1 and 21.
 */
function contrastRatio(a, b) {
  const [lighter, darker] = [luminance(a), luminance(b)].sort((x, y) => y - x);
  return (lighter + 0.05) / (darker + 0.05);
}

/**
 * Parses `#RRGGBB` into channel values.
 *
 * @param {string} hex Six-digit hex string with a leading `#`.
 * @returns {{r: number, g: number, b: number}} Channel values, 0-255.
 */
function parseHex(hex) {
  return {
    r: Number.parseInt(hex.slice(1, 3), 16),
    g: Number.parseInt(hex.slice(3, 5), 16),
    b: Number.parseInt(hex.slice(5, 7), 16),
  };
}

/**
 * Reads one channel out of an asset catalog color entry.
 *
 * Xcode writes these as `"0xB3"`, but a hand-edited catalog may carry a decimal
 * `"179"` or a float `"0.702"` instead, and all three are valid. Guessing wrong
 * would silently check a color nobody authored, so each form is handled rather
 * than assumed away.
 *
 * @param {string} raw Component string from the catalog.
 * @returns {number} Channel value, 0-255.
 * @throws {Error} If the value is not one of the three known forms.
 */
function parseComponent(raw) {
  const value = String(raw).trim();
  if (value.startsWith("0x") || value.startsWith("0X")) {
    return Number.parseInt(value, 16);
  }
  const numeric = Number.parseFloat(value);
  if (Number.isNaN(numeric)) {
    throw new Error(`unrecognized color component: ${raw}`);
  }
  // A float in 0-1 is a fraction; anything else is already 0-255. `1` is
  // ambiguous between the two and means white either way, so it needs no
  // special case.
  return value.includes(".") && numeric <= 1 ? Math.round(numeric * 255) : numeric;
}

/**
 * Extracts what a `.colorset` renders as in each appearance.
 *
 * The universal entry — the one with no `appearances` block — is not the light
 * variant. It is the color used in **every** appearance the catalog does not
 * override, so a colorset carrying only a universal entry renders that same
 * color in dark mode too, and has to clear the dark backgrounds as well.
 * Filing it under "light" and checking it only against white was this
 * checker's own first bug: a color could be too pale for a dark grouped row
 * and pass, which is the exact defect class the checker was written for.
 *
 * @param {string} dir Path to the `.colorset` directory.
 * @returns {{light: ?{r: number, g: number, b: number}, dark: ?{r: number, g: number, b: number}}}
 *   What each appearance renders, resolving the universal entry into both.
 *   Null only where the catalog declares no usable color for that appearance.
 */
function readColorSet(dir) {
  const parsed = JSON.parse(readFileSync(join(dir, "Contents.json"), "utf8"));
  let universal = null;
  let dark = null;
  for (const entry of parsed.colors ?? []) {
    if (!entry.color?.components) {
      continue;
    }
    const { red, green, blue } = entry.color.components;
    const color = {
      r: parseComponent(red),
      g: parseComponent(green),
      b: parseComponent(blue),
    };
    const isDark = (entry.appearances ?? []).some(
      (appearance) =>
        appearance.appearance === "luminosity" && appearance.value === "dark",
    );
    if (isDark) {
      dark = color;
    } else {
      universal = color;
    }
  }
  // An explicit dark entry overrides the universal one; without it, dark mode
  // renders the universal color.
  return { light: universal, dark: dark ?? universal };
}

const failures = [];
let checked = 0;

let colorSets;
try {
  colorSets = readdirSync(ASSET_DIR).filter((name) => name.endsWith(".colorset"));
} catch (error) {
  // A missing directory is a failure, never a pass. The app was renamed or
  // moved and this gate silently stopped checking anything is precisely the
  // outcome worth refusing.
  console.error(`check-color-contrast: cannot read ${ASSET_DIR} — ${error.message}`);
  process.exit(1);
}
if (colorSets.length === 0) {
  console.error(
    `check-color-contrast: no .colorset found under ${ASSET_DIR} — ` +
      "refusing to report a pass on an empty scan.",
  );
  process.exit(1);
}

for (const name of colorSets) {
  const variants = readColorSet(join(ASSET_DIR, name));
  for (const [appearance, color] of Object.entries(variants)) {
    if (!color) {
      continue;
    }
    for (const [bgName, bgHex] of Object.entries(BACKGROUNDS[appearance])) {
      checked += 1;
      const ratio = contrastRatio(color, parseHex(bgHex));
      if (ratio < FLOOR) {
        failures.push(
          `${name} (${appearance}) on ${bgName} ${bgHex}: ` +
            `${ratio.toFixed(2)}:1 — below the ${FLOOR}:1 floor`,
        );
      }
    }
  }
}

if (failures.length > 0) {
  console.error("check-color-contrast: FAILED");
  for (const failure of failures) {
    console.error(`  ${failure}`);
  }
  process.exit(1);
}

console.log(
  `check-color-contrast: ${checked} color/background pair(s) clear ${FLOOR}:1.`,
);
