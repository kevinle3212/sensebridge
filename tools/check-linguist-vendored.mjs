#!/usr/bin/env node
/**
 * check-linguist-vendored.mjs — assert GitHub's language bar reflects the code
 * this repo actually writes.
 *
 * Why a gate rather than a one-off `.gitattributes` edit: harness parity checks
 * the vendor-managed `impeccable` skill tree into the repo five times over
 * (`.agents`, `.claude`, `.github`, `.gemini`, `.cursor`) — ~13.5 MB of `.mjs`
 * against ~390 KB of Swift. `.gitattributes` once listed those roots one per line and
 * three of the five were missed, so JavaScript read as ~95% of the repo. A
 * sixth harness would have repeated the mistake silently — nothing fails, the
 * language bar is just wrong until someone looks at it.
 *
 * Two directions are checked, because both regressions are real:
 *   1. A vendored tree that is *not* marked — the bar re-inflates.
 *   2. Genuine source that *is* marked — an over-broad glob (say `**\/*.mjs`)
 *      would hide `tools/`, `.claude/hooks/`, and `website/` from the bar.
 *
 * Run: node tools/check-linguist-vendored.mjs
 * Wired into `npm run check`.
 */

import { execFileSync } from "node:child_process";

/**
 * Extensions Linguist counts toward the language bar that this repo carries in
 * volume. Prose (`.md`) and data (`.json`) are excluded by Linguist already, so
 * they need no attribute and are not worth asserting on.
 */
const COUNTED_EXTENSIONS = [".mjs", ".cjs", ".js", ".ts", ".tsx", ".jsx"];

/**
 * Path fragments identifying vendor-managed trees that must stay out of the
 * language bar. Matched as substrings against forward-slash repo paths.
 */
const VENDORED_FRAGMENTS = ["/skills/impeccable/"];

/**
 * Runs a git command and returns its stdout, trimmed.
 *
 * @param {string[]} args Arguments passed to `git`.
 * @param {string} [input] Optional stdin payload, for `--stdin` subcommands.
 * @returns {string} Trimmed stdout.
 */
function git(args, input) {
  return execFileSync("git", args, { encoding: "utf8", input, maxBuffer: 64 * 1024 * 1024 }).trim();
}

/**
 * Whether a repo-relative path lives inside a vendor-managed tree.
 *
 * @param {string} path Repo-relative, forward-slash path.
 * @returns {boolean} True when the path must carry a Linguist exclusion.
 */
function isVendored(path) {
  return VENDORED_FRAGMENTS.some((fragment) => `/${path}`.includes(fragment));
}

const tracked = git(["ls-files"])
  .split("\n")
  .filter((path) => COUNTED_EXTENSIONS.some((extension) => path.endsWith(extension)));

if (tracked.length === 0) {
  console.error(
    "check-linguist-vendored: FAILED\n\n  - no tracked JS/TS files found; is this a git checkout?",
  );
  process.exit(1);
}

/**
 * Paths whose Linguist attributes exclude them from the language bar, resolved
 * in one batched `git check-attr` rather than one process per file.
 *
 * `-z` makes `check-attr` both read NUL-separated paths and emit NUL-separated
 * `path, attribute, value` triples — the separator applies to input too, so
 * newline-joined input is read as one absurdly long filename.
 */
const excluded = new Set();
const fields = git(
  ["check-attr", "--stdin", "-z", "linguist-vendored", "linguist-generated"],
  `${tracked.join("\0")}\0`,
).split("\0");

for (let i = 0; i + 2 < fields.length; i += 3) {
  if (fields[i + 2] === "set") excluded.add(fields[i]);
}

const problems = [];

for (const path of tracked) {
  const vendored = isVendored(path);
  if (vendored && !excluded.has(path)) {
    problems.push(
      `${path} is vendor-managed but counts toward the language bar — add a \`linguist-vendored\` glob covering it.`,
    );
  } else if (!vendored && excluded.has(path)) {
    problems.push(
      `${path} is first-party source but is excluded from the language bar — a \`.gitattributes\` glob is too broad.`,
    );
  }
}

if (problems.length > 0) {
  console.error("check-linguist-vendored: FAILED\n");
  // Five harness copies of one bad path would print 530 identical-shaped lines.
  for (const problem of problems.slice(0, 10)) console.error(`  - ${problem}`);
  if (problems.length > 10) console.error(`  - …and ${problems.length - 10} more.`);
  console.error("\nFix the globs in .gitattributes, then re-run.");
  process.exit(1);
}

const vendoredCount = tracked.filter(isVendored).length;
console.log(
  `check-linguist-vendored: clean (${vendoredCount} vendored, ${tracked.length - vendoredCount} counted, ${tracked.length} tracked JS/TS files).`,
);
