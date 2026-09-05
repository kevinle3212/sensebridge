#!/usr/bin/env node
// Installs the Chrome build Puppeteer expects, without using Puppeteer's own
// installer.
//
// Why this exists: `npx puppeteer browsers install chrome` silently produces a
// truncated install on this machine — 41 of the archive's 651 entries, 448kB
// instead of ~340MB, with `Google Chrome for Testing Framework.framework` never
// unpacked, so the binary dies in `dlopen`. It exits 0 and prints the usual
// success line, which is why four checks (`check:csp`, `check:consent`,
// `check:scene-drag`, `check:bfcache`) sat unrunnable without an obvious cause.
//
// The download is not the problem: fetching the same archive directly returns
// HTTP 200, a complete 169MB zip that passes `unzip -t`. The extractor is. So
// this fetches the archive and unpacks it with `ditto`, which is macOS's own
// tool and handles the `.app` bundle's symlinks correctly, then verifies the
// result by running the binary rather than trusting an exit code.
//
// Previously blamed on Node 26. That diagnosis was wrong: Node 22 reproduces it
// identically.
//
// Run: npm --prefix website run chrome:install

import { execFileSync } from "node:child_process";
import { createWriteStream } from "node:fs";
import { mkdir, mkdtemp, rm, stat } from "node:fs/promises";
import { tmpdir, homedir } from "node:os";
import path from "node:path";
import { Readable } from "node:stream";
import { pipeline } from "node:stream/promises";
import process from "node:process";

/* eslint-disable security/detect-non-literal-fs-filename -- every path is built from homedir()/tmpdir() and a version string validated below */

/**
 * True for a 1-5 character run of ASCII digits — one component of a version.
 *
 * Character-by-character rather than a regex or a spread: every regex form
 * tripped eslint-plugin-security's backtracking detector, and spreading a
 * string trips the Unicode-decomposition rule. Version components are ASCII.
 *
 * @param {string} part One dot-separated component.
 * @returns {boolean} Whether it is a plausible version component.
 */
function isDigits(part) {
  if (part.length === 0 || part.length > 5) {
    return false;
  }
  for (let index = 0; index < part.length; index += 1) {
    const code = part.charCodeAt(index);
    if (code < 48 || code > 57) {
      return false;
    }
  }
  return true;
}

/** A complete mac-arm64 Chrome install is ~340MB; anything far under it is the truncation bug. */
const MINIMUM_BYTES = 250 * 1024 * 1024;

/**
 * The Chrome version Puppeteer resolves, read from its own revisions table so
 * this script can never drift from the build `puppeteer.launch()` looks for.
 *
 * @returns {Promise<string>} A validated dotted version number.
 */
async function expectedVersion() {
  const { PUPPETEER_REVISIONS } = await import("puppeteer-core/internal/revisions.js");
  /** @type {unknown} */
  const version = PUPPETEER_REVISIONS.chrome;
  // Guards the URL and path interpolation below against anything but a version
  // number. Split-and-check rather than a regex: every nested-quantifier form
  // of this pattern reads as a backtracking risk to eslint-plugin-security, and
  // the loop is clearer than the regex it replaces.
  const parts = typeof version === "string" ? version.split(".") : [];
  const wellFormed = parts.length > 0 && parts.length <= 4 && parts.every(isDigits);
  if (!wellFormed) {
    throw new Error(`unexpected Chrome version from puppeteer-core: ${String(version)}`);
  }
  return /** @type {string} */ (version);
}

/**
 * Total size of a directory tree, in bytes.
 *
 * @param {string} dir Directory to measure.
 * @returns {number} Size in bytes.
 */
function treeBytes(dir) {
  const output = execFileSync("/usr/bin/du", ["-sk", dir], { encoding: "utf8" });
  return Number.parseInt(output.trim().split(/\s+/)[0], 10) * 1024;
}

/**
 * Installs, repairs, or confirms the Chrome build Puppeteer expects.
 *
 * Idempotent: a healthy install is left alone, a truncated one is replaced, and
 * a missing one is downloaded. No-ops off macOS, where Puppeteer's own
 * installer works.
 *
 * @returns {Promise<void>} Resolves once a verified install is in place.
 */
async function main() {
  if (process.platform !== "darwin") {
    console.warn("install-chrome: not macOS — use `npx puppeteer browsers install chrome`.");
    return;
  }

  const version = await expectedVersion();
  const cacheDir = path.join(homedir(), ".cache", "puppeteer", "chrome", `mac_arm-${version}`);
  const binary = path.join(
    cacheDir,
    "chrome-mac-arm64",
    "Google Chrome for Testing.app",
    "Contents",
    "MacOS",
    "Google Chrome for Testing",
  );

  if (await stat(binary).catch(() => null)) {
    const bytes = treeBytes(cacheDir);
    if (bytes >= MINIMUM_BYTES) {
      console.warn(`install-chrome: ${version} already installed (${Math.round(bytes / 1e6)}MB).`);
      verify(binary, version);
      return;
    }
    console.warn(`install-chrome: existing ${version} install is truncated — replacing it.`);
    await rm(cacheDir, { recursive: true, force: true });
  }

  const url = `https://storage.googleapis.com/chrome-for-testing-public/${version}/mac-arm64/chrome-mac-arm64.zip`;
  const scratch = await mkdtemp(path.join(tmpdir(), "sensebridge-chrome-"));
  const archive = path.join(scratch, "chrome.zip");

  try {
    console.warn(`install-chrome: downloading Chrome ${version}…`);
    const response = await fetch(url);
    if (!response.ok || !response.body) {
      throw new Error(`download failed: HTTP ${response.status}`);
    }
    await pipeline(Readable.fromWeb(response.body), createWriteStream(archive));

    console.warn("install-chrome: extracting with ditto…");
    await mkdir(cacheDir, { recursive: true });
    execFileSync("/usr/bin/ditto", ["-x", "-k", archive, cacheDir], { stdio: "inherit" });
  } finally {
    await rm(scratch, { recursive: true, force: true });
  }

  const bytes = treeBytes(cacheDir);
  if (bytes < MINIMUM_BYTES) {
    throw new Error(
      `extraction produced only ${Math.round(bytes / 1e6)}MB — expected at least ` +
        `${Math.round(MINIMUM_BYTES / 1e6)}MB. The truncation bug is not fixed.`,
    );
  }
  verify(binary, version);
  console.warn(`install-chrome: Chrome ${version} installed (${Math.round(bytes / 1e6)}MB).`);
}

/**
 * Runs the binary and checks it reports the version asked for.
 *
 * A file-count or byte check alone would not have caught the original failure
 * the way it actually presented — an executable that exists and is the right
 * size but cannot load its framework.
 *
 * @param {string} binary Absolute path to the Chrome executable.
 * @param {string} version Version it must report.
 * @returns {void}
 */
function verify(binary, version) {
  const reported = execFileSync(binary, ["--version"], { encoding: "utf8" }).trim();
  if (!reported.includes(version)) {
    throw new Error(`installed binary reports "${reported}", expected ${version}`);
  }
  console.warn(`install-chrome: verified — ${reported}`);
}

await main();
