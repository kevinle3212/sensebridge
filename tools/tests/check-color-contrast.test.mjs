#!/usr/bin/env node
// Regression test for check-color-contrast.mjs.
//
// The finding this answers: the app's dark-mode `AccentColor` was Apple's own
// systemBlue `#0A84FF`, which measures 3.82:1 against iOS's dark grouped-row
// background `#2C2C2E` — under WCAG AA for body text. Four accessibility audits
// failed on a device because of it, and reported only "Contrast nearly passed",
// naming neither the element nor the ratio. The checker turns that into
// arithmetic that runs in CI with no hardware; this proves the checker actually
// goes red, in each of the ways it claims to.
//
// Every case drives the real script through `COLOR_ASSET_DIR` over a fixture
// catalog, rather than importing its internals: the exit code is the contract
// `npm run check` depends on, and asserting on a private function would let the
// script's actual behaviour drift away from the thing under test. The known
// WCAG ratios below are checked against published reference values, so a
// refactor of the luminance math cannot quietly change what "4.5:1" means.

import assert from "node:assert/strict";
import { spawnSync } from "node:child_process";
import { mkdtempSync, mkdirSync, writeFileSync, rmSync } from "node:fs";
import { tmpdir } from "node:os";
import { join, resolve, dirname } from "node:path";
import { fileURLToPath } from "node:url";

const HERE = dirname(fileURLToPath(import.meta.url));
const SCRIPT = resolve(HERE, "..", "check-color-contrast.mjs");

let failures = 0;

/**
 * Runs one named assertion, reporting rather than throwing so every case runs.
 *
 * @param {string} name What the case proves.
 * @param {() => void} fn The case body.
 */
function test(name, fn) {
  try {
    fn();
    console.log(`  ok — ${name}`);
  } catch (error) {
    failures += 1;
    console.error(`  FAIL — ${name}`);
    console.error(`        ${error.message}`);
  }
}

/**
 * Writes a `.colorset` fixture and runs the checker over its catalog.
 *
 * @param {Array<{name: string, light: ?string, dark: ?string}>} sets Color sets
 *   to author, each variant as `#RRGGBB` or null to omit it.
 * @returns {{status: number, stdout: string, stderr: string}} The run's result.
 */
function run(sets) {
  const dir = mkdtempSync(join(tmpdir(), "contrast-"));
  try {
    for (const set of sets) {
      const setDir = join(dir, `${set.name}.colorset`);
      mkdirSync(setDir);
      const colors = [];
      if (set.light) {
        colors.push({ color: components(set.light), idiom: "universal" });
      }
      if (set.dark) {
        colors.push({
          appearances: [{ appearance: "luminosity", value: "dark" }],
          color: components(set.dark),
          idiom: "universal",
        });
      }
      writeFileSync(
        join(setDir, "Contents.json"),
        JSON.stringify({ colors, info: { author: "xcode", version: 1 } }),
      );
    }
    const result = spawnSync(process.execPath, [SCRIPT], {
      encoding: "utf8",
      env: { ...process.env, COLOR_ASSET_DIR: dir },
    });
    return {
      status: result.status,
      stdout: result.stdout ?? "",
      stderr: result.stderr ?? "",
    };
  } finally {
    rmSync(dir, { recursive: true, force: true });
  }
}

/**
 * Builds an asset catalog color component block from a hex string.
 *
 * @param {string} hex Six-digit hex with a leading `#`.
 * @returns {object} The catalog's `color` object.
 */
function components(hex) {
  return {
    "color-space": "srgb",
    components: {
      alpha: "1.000",
      red: `0x${hex.slice(1, 3)}`,
      green: `0x${hex.slice(3, 5)}`,
      blue: `0x${hex.slice(5, 7)}`,
    },
  };
}

console.log("check-color-contrast.test.mjs");

test("the exact regression it was written for goes red", () => {
  // #0A84FF dark on #2C2C2E is 3.82:1 — the real defect, found on device.
  const result = run([{ name: "AccentColor", light: "#0056B3", dark: "#0A84FF" }]);
  assert.equal(result.status, 1, "a failing color must exit non-zero");
  assert.match(result.stderr, /AccentColor.*dark.*tertiarySystemGroupedBackground/s);
  assert.match(result.stderr, /3\.82:1/, "the measured ratio must be reported");
});

test("the shipped replacement passes", () => {
  const result = run([{ name: "AccentColor", light: "#0056B3", dark: "#4DA6FF" }]);
  assert.equal(result.status, 0, result.stderr);
});

test("a light variant too pale for white is caught", () => {
  // #7FB2E5 on white is ~2.2:1. The light side must be gated as hard as the
  // dark one — the first device run only happened to expose the dark variant.
  const result = run([{ name: "AccentColor", light: "#7FB2E5", dark: "#4DA6FF" }]);
  assert.equal(result.status, 1);
  assert.match(result.stderr, /light.*systemBackground/s);
});

test("every failing pair is named, not just the first", () => {
  const result = run([{ name: "AccentColor", light: "#0056B3", dark: "#0A84FF" }]);
  const lines = result.stderr.split("\n").filter((l) => l.includes(":1 —"));
  assert.equal(lines.length, 2, `expected both dark failures, got:\n${result.stderr}`);
});

test("an empty catalog fails rather than reporting a clean scan", () => {
  // The silent-green case: a gate that passes when it checked nothing is worse
  // than no gate, because it reads as evidence.
  const result = run([]);
  assert.equal(result.status, 1, "an empty scan must not pass");
  assert.match(result.stderr, /refusing to report a pass on an empty scan/);
});

test("a missing catalog directory fails rather than passing", () => {
  const result = spawnSync(process.execPath, [SCRIPT], {
    encoding: "utf8",
    env: { ...process.env, COLOR_ASSET_DIR: join(tmpdir(), "definitely-not-here") },
  });
  assert.equal(result.status, 1);
  assert.match(result.stderr, /cannot read/);
});

test("a colorset with only a universal variant is checked, not skipped", () => {
  // No `appearances` block means one color for every appearance, and it still
  // has to clear the light backgrounds it will be drawn on.
  const result = run([{ name: "OnlyUniversal", light: "#7FB2E5", dark: null }]);
  assert.equal(result.status, 1);
  assert.match(result.stderr, /OnlyUniversal/);
});

test("a universal-only color is checked against the DARK backgrounds too", () => {
  // The checker's own first bug, caught in review: a universal entry was filed
  // as the light variant and only ever measured against white. But a colorset
  // with no dark override renders that same color in dark mode, so one too
  // dark to read on a dark grouped row passed the gate — the exact defect
  // class this checker exists to catch.
  //
  // #0056B3 is the app's light accent: 7.04:1 on white, and 1.99:1 on the dark
  // grouped row. Passing on light alone is what the bug looked like.
  const result = run([{ name: "UniversalOnly", light: "#0056B3", dark: null }]);
  assert.equal(
    result.status,
    1,
    `a universal color unreadable in dark mode must fail:\n${result.stdout}${result.stderr}`,
  );
  assert.match(
    result.stderr,
    /UniversalOnly.*dark\) on/s,
    `the dark failure must be reported:\n${result.stderr}`,
  );
});

test("an explicit dark entry overrides the universal one", () => {
  // The complement of the case above: once a dark variant exists, the
  // universal color must not be measured against dark backgrounds, or every
  // correctly-authored two-variant asset would report phantom failures.
  const result = run([{ name: "BothVariants", light: "#0056B3", dark: "#4DA6FF" }]);
  assert.equal(
    result.status,
    0,
    `the dark variant should be measured, not the light one:\n${result.stderr}`,
  );
});

test("decimal and fractional components parse as well as hex", () => {
  // Xcode writes hex, but a hand-edited catalog may carry either other form,
  // and silently mis-parsing one would check a color nobody authored.
  const dir = mkdtempSync(join(tmpdir(), "contrast-forms-"));
  try {
    const setDir = join(dir, "Decimal.colorset");
    mkdirSync(setDir);
    writeFileSync(
      join(setDir, "Contents.json"),
      JSON.stringify({
        colors: [
          {
            // 0x00 / 0x56 / 0xB3 written as decimals — the passing light accent.
            color: {
              "color-space": "srgb",
              components: { alpha: "1.000", red: "0", green: "86", blue: "179" },
            },
            idiom: "universal",
          },
          {
            // 0x4D / 0xA6 / 0xFF as decimals. A dark variant is required, not
            // decoration: without one the universal color above is what dark
            // mode renders, and a navy blue on a dark grouped row is 1.98:1.
            // This case is about parsing, so it must not fail on contrast.
            appearances: [{ appearance: "luminosity", value: "dark" }],
            color: {
              "color-space": "srgb",
              components: { alpha: "1.000", red: "77", green: "166", blue: "255" },
            },
            idiom: "universal",
          },
        ],
        info: { author: "hand", version: 1 },
      }),
    );
    const result = spawnSync(process.execPath, [SCRIPT], {
      encoding: "utf8",
      env: { ...process.env, COLOR_ASSET_DIR: dir },
    });
    assert.equal(result.status, 0, result.stderr);
  } finally {
    rmSync(dir, { recursive: true, force: true });
  }
});

test("the luminance math matches published WCAG reference ratios", () => {
  // Guards the arithmetic itself, against the canonical boundary case: #767676
  // on white is 4.54:1 in WCAG's own materials, and #777777 — one step lighter
  // — is 4.48:1, straddling the 4.5 floor. Asserted on the white pair
  // specifically rather than on the exit code, because both of these also fail
  // the grouped background #F2F2F7 and that would mask a regression in
  // `linearize` behind an unrelated red.
  const passesWhite = run([{ name: "Boundary", light: "#767676", dark: "#4DA6FF" }]);
  assert.doesNotMatch(
    passesWhite.stderr,
    /light\) on systemBackground/,
    `#767676 on white is 4.54:1 and must clear AA:\n${passesWhite.stderr}`,
  );
  const failsWhite = run([{ name: "Boundary", light: "#777777", dark: "#4DA6FF" }]);
  assert.match(
    failsWhite.stderr,
    /light\) on systemBackground #FFFFFF: 4\.48:1/,
    `#777777 on white is 4.48:1 and must fall under AA:\n${failsWhite.stderr}`,
  );
});

if (failures > 0) {
  console.error(`check-color-contrast.test.mjs: ${failures} failed`);
  process.exit(1);
}
console.log("check-color-contrast.test.mjs: all passed");
