#!/usr/bin/env node
/**
 * check-npm-script-files.mjs — fail the build when `package.json` invokes a
 * local script file that is missing, or present but untracked by git.
 *
 * The bug this exists to prevent, found by review on 2026-08-17: a `check:*`
 * entry was added to `package.json` (tracked) pointing at a brand-new
 * `tools/*.mjs` (untracked). Committing the manifest without the script it calls
 * gives every fresh checkout a `npm run check` that dies on `Cannot find
 * module` — and nothing caught it, because on the authoring machine the file was
 * right there on disk.
 *
 * "Exists" is therefore not the interesting question; **tracked** is. A file
 * sitting in the working tree passes an existence check and still breaks
 * everyone else. This asserts both.
 *
 * Scope is deliberately narrow: paths under `tools/`, `scripts/`, `.claude/`, or
 * `.githooks/` ending in `.mjs`, `.js`, or `.sh`.
 *
 * Globs get the same treatment for a sharper reason. `tools/tests/*.test.mjs`
 * names a set, so a repository with zero matches is legitimate and passes. But a
 * glob matching files on disk while matching NOTHING tracked is the worst case
 * in this whole file: on a fresh checkout it expands to nothing, the loop body
 * never runs, and the script exits 0. A green line proving no test ran. That is
 * strictly more dangerous than the missing-module crash above, because it fails
 * silently. So every file a glob matches locally must be tracked too.
 *
 * Read-only. Runs `git ls-files` to answer the tracking question and degrades to
 * an existence-only check, with a note, outside a git work tree.
 *
 * Run: node tools/check-npm-script-files.mjs
 * Wired into `npm run check`.
 */
import { existsSync, readFileSync, globSync } from "node:fs";
import { spawnSync } from "node:child_process";

/** Directories whose script files are repository source that must be committed. */
const TRACKED_SCRIPT_DIRS = ["tools", "scripts", ".claude", ".githooks"];

// `*` is in the character class on purpose: globs are checked, not skipped.
const PATH_PATTERN = new RegExp(
  `(?:^|[\\s'"=])((?:${TRACKED_SCRIPT_DIRS.map((d) => d.replace(".", "\\.")).join("|")})/[A-Za-z0-9._/*-]+\\.(?:mjs|js|sh))`,
  "g",
);

const failures = [];
const notes = [];

const pkg = JSON.parse(readFileSync("package.json", "utf8"));
const scripts = pkg.scripts ?? {};

/**
 * Every distinct literal script path referenced by an npm script, mapped to the
 * script names that reference it, so a failure can name the caller.
 *
 * @returns {Map<string, Set<string>>} Path to the set of npm script names using it.
 */
function collectReferencedPaths() {
  const found = new Map();
  for (const [name, body] of Object.entries(scripts)) {
    if (typeof body !== "string") continue;
    for (const match of body.matchAll(PATH_PATTERN)) {
      const path = match[1];
      if (!found.has(path)) found.set(path, new Set());
      found.get(path).add(name);
    }
  }
  return found;
}

const referenced = collectReferencedPaths();

/**
 * Which binary to treat as `git`.
 *
 * `GIT_BIN` exists so the tracking layer is deterministic under test. The suite
 * pins it at stub scripts to exercise tracked / untracked / git-unavailable
 * without building throwaway repositories, and one case leaves it unset so the
 * real `git ls-files` path stays exercised. Sibling of `DSH_BIN` in
 * `check-deepseek-bridge.mjs`, and for the same reason: a test that reads
 * ambient state is not a test. Not intended for production use.
 */
const GIT_BIN = process.env.GIT_BIN || "git";

// Ask git once for the whole tracked set rather than per file: one process
// instead of N, and it answers "tracked" without touching the index.
let trackedFiles = null;
const ls = spawnSync(GIT_BIN, ["ls-files", "-z", "--", ...TRACKED_SCRIPT_DIRS], {
  encoding: "utf8",
  timeout: 30_000,
});
if (ls.error || ls.status !== 0) {
  notes.push(
    "git ls-files did not run (not a work tree, or git unavailable), so files were " +
      "checked for EXISTENCE only. The untracked-file case this check exists to " +
      "catch is NOT covered in this run.",
  );
} else {
  trackedFiles = new Set(ls.stdout.split("\0").filter(Boolean));
}

let literalCount = 0;
let globCount = 0;

for (const [path, callers] of [...referenced].sort(([a], [b]) => a.localeCompare(b))) {
  const via = [...callers].sort().map((n) => `\`${n}\``).join(", ");

  if (path.includes("*")) {
    globCount += 1;
    // Zero matches is legitimate — the pattern names a set, and a repository
    // with no such files yet is a valid state, not a defect.
    const matches = globSync(path).sort();
    if (matches.length === 0) {
      notes.push(`${path} (${via}) matches nothing here; that is a valid empty set.`);
      continue;
    }
    if (!trackedFiles) continue;
    const untracked = matches.filter((m) => !trackedFiles.has(m));
    if (untracked.length === matches.length) {
      failures.push(
        `${path} is referenced by ${via} and matches ${matches.length} file(s) here, ` +
          "but NONE of them are tracked by git. On a fresh checkout this expands to " +
          "nothing, the loop body never runs, and the script exits 0 — a green line " +
          `proving nothing ran. Untracked: ${untracked.join(", ")}.`,
      );
    } else if (untracked.length > 0) {
      failures.push(
        `${path} is referenced by ${via} but ${untracked.length} of its ` +
          `${matches.length} match(es) are NOT tracked by git, so they run here and ` +
          `nowhere else. Untracked: ${untracked.join(", ")}.`,
      );
    }
    continue;
  }

  literalCount += 1;
  if (!existsSync(path)) {
    failures.push(`${path} is referenced by ${via} but does not exist.`);
    continue;
  }
  if (trackedFiles && !trackedFiles.has(path)) {
    failures.push(
      `${path} is referenced by ${via} but is NOT tracked by git. ` +
        "It works here and breaks every fresh checkout — commit it in the same " +
        "change as package.json, or drop the script entry.",
    );
  }
}

if (failures.length > 0) {
  console.error(`check-npm-script-files: ${failures.length} problem(s)\n`);
  for (const failure of failures) console.error(`  - ${failure}`);
  for (const note of notes) console.error(`\n  note: ${note}`);
  process.exit(1);
}

console.log(
  `check-npm-script-files: ${literalCount} referenced script file(s) and ` +
    `${globCount} glob(s) present${trackedFiles ? " and tracked" : ""}.`,
);
for (const note of notes) console.log(`  note: ${note}`);
