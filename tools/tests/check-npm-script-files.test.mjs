#!/usr/bin/env node
// Regression test for check-npm-script-files.mjs.
//
// The finding this answers: `package.json` (tracked) gained a `check:*` entry
// pointing at a brand-new `tools/*.mjs` that was never committed. It ran fine on
// the authoring machine and would have died with `Cannot find module` on every
// fresh checkout. The checker exists to make that state red; this proves the
// checker actually goes red, in each of the ways it claims to.
//
// Why GIT_BIN is pinned in almost every case: the interesting assertion is
// "present but untracked", and building a real fixture repository per case would
// make each test depend on git's ambient behaviour — the same trap the DSH_BIN
// seam was added to `check-deepseek-bridge.mjs` to remove. Stubs answer
// deterministically. One case deliberately leaves GIT_BIN unset so the real
// `git ls-files` invocation stays exercised, but asserts only that tracking was
// consulted, never on WHICH files are tracked — that set changes the moment
// anyone commits, and a test that flips on commit is a test that will be
// deleted rather than fixed.
//
// Run: node tools/tests/check-npm-script-files.test.mjs

import assert from "node:assert/strict";
import { spawnSync } from "node:child_process";
import { mkdtempSync, mkdirSync, writeFileSync, rmSync } from "node:fs";
import { tmpdir } from "node:os";
import { join, resolve, dirname } from "node:path";
import { fileURLToPath } from "node:url";

const HERE = dirname(fileURLToPath(import.meta.url));
const CHECKER = resolve(HERE, "../check-npm-script-files.mjs");
const REPO_ROOT = resolve(HERE, "../..");

let passed = 0;

/** Runs one named assertion block, tallying it for the summary line. */
function test(name, fn) {
  fn();
  passed += 1;
  console.log(`  ok — ${name}`);
}

/**
 * Writes an executable stand-in for `git` that answers `ls-files -z`.
 *
 * @param {string} dir Directory to write the stub into.
 * @param {object} behaviour How the stub should answer.
 * @param {string[]} behaviour.tracked Paths to report as tracked.
 * @param {number} behaviour.exit Exit status; non-zero drives the degraded branch.
 * @returns {string} Absolute path to the stub, suitable for GIT_BIN.
 */
function writeGitStub(dir, { tracked = [], exit = 0 } = {}) {
  const path = join(dir, "git-stub");
  // NUL-separated, matching `git ls-files -z`. printf renders \0 in /bin/sh.
  const payload = tracked.map((p) => `${p}\\0`).join("");
  writeFileSync(path, ["#!/bin/sh", `printf '%b' '${payload}'`, `exit ${exit}`, ""].join("\n"), {
    mode: 0o755,
  });
  return path;
}

/** An absolute path guaranteed not to exist, forcing the ENOENT branch. */
function absentBin(dir) {
  return join(dir, "definitely-not-installed-git");
}

/**
 * Builds a throwaway package tree and runs the checker inside it.
 *
 * @param {object} tree Fixture description.
 * @param {Record<string, string>} tree.scripts The `scripts` block for package.json.
 * @param {string[]} tree.files Repo-relative paths to create on disk.
 * @param {((dir: string) => string)|null} tree.git Resolves GIT_BIN from the fixture
 *   dir. Defaults to a stub reporting every created file as tracked.
 * @returns {{status: number, out: string}} Exit code and combined output.
 */
function run({ scripts = {}, files = [], git = null } = {}) {
  const dir = mkdtempSync(join(tmpdir(), "npmscripts-"));
  try {
    writeFileSync(join(dir, "package.json"), JSON.stringify({ scripts }, null, 2));
    for (const file of files) {
      mkdirSync(dirname(join(dir, file)), { recursive: true });
      writeFileSync(join(dir, file), "#!/usr/bin/env node\n");
    }
    const bin = git ?? ((d) => writeGitStub(d, { tracked: files }));
    const r = spawnSync(process.execPath, [CHECKER], {
      cwd: dir,
      encoding: "utf8",
      env: { ...process.env, GIT_BIN: bin(dir) },
    });
    return { status: r.status, out: `${r.stdout ?? ""}${r.stderr ?? ""}` };
  } finally {
    rmSync(dir, { recursive: true, force: true });
  }
}

// --- The happy path --------------------------------------------------------

test("a referenced file that exists and is tracked passes", () => {
  const r = run({
    scripts: { "check:thing": "node tools/thing.mjs" },
    files: ["tools/thing.mjs"],
  });
  assert.equal(r.status, 0, r.out);
  assert.match(r.out, /present and tracked/);
});

test("every guarded directory is covered, not just tools/", () => {
  const files = [
    "tools/a.mjs",
    "scripts/b.sh",
    ".claude/hooks/c.sh",
    ".githooks/d.sh",
  ];
  const r = run({
    scripts: {
      a: "node tools/a.mjs",
      b: "scripts/b.sh",
      c: "bash .claude/hooks/c.sh",
      d: ".githooks/d.sh",
    },
    files,
  });
  assert.equal(r.status, 0, r.out);
  assert.match(r.out, /4 referenced script file\(s\)/);
});

// --- The two failure modes -------------------------------------------------

test("a referenced file that does not exist fails", () => {
  const r = run({ scripts: { "check:gone": "node tools/gone.mjs" } });
  assert.equal(r.status, 1, r.out);
  assert.match(r.out, /tools\/gone\.mjs/);
  assert.match(r.out, /does not exist/);
});

test("a file present on disk but untracked fails — the actual bug", () => {
  // This is the whole point. Existence alone passes here and still breaks every
  // fresh checkout, so the tracking assertion has to be the one that fires.
  const r = run({
    scripts: { "check:new": "node tools/new.mjs" },
    files: ["tools/new.mjs"],
    git: (dir) => writeGitStub(dir, { tracked: [] }),
  });
  assert.equal(r.status, 1, r.out);
  assert.match(r.out, /NOT tracked by git/);
  assert.match(r.out, /breaks every fresh checkout/);
});

test("a failure names every npm script that would break", () => {
  const r = run({
    scripts: {
      "check:codegraph": "node tools/perms.mjs",
      codegraph: "codegraph index && node tools/perms.mjs --fix",
    },
    files: ["tools/perms.mjs"],
    git: (dir) => writeGitStub(dir, { tracked: [] }),
  });
  assert.equal(r.status, 1, r.out);
  assert.match(r.out, /`check:codegraph`, `codegraph`/);
});

// --- What must NOT fail ----------------------------------------------------

test("a glob matching nothing passes, because it names a set", () => {
  const r = run({ scripts: { "check:tests": "for f in tools/tests/*.test.mjs; do node $f; done" } });
  assert.equal(r.status, 0, r.out);
  assert.match(r.out, /valid empty set/);
});

test("a glob whose matches are all tracked passes", () => {
  const r = run({
    scripts: { "check:tests": "for f in tools/tests/*.test.mjs; do node $f; done" },
    files: ["tools/tests/a.test.mjs", "tools/tests/b.test.mjs"],
  });
  assert.equal(r.status, 0, r.out);
  assert.match(r.out, /1 glob\(s\)/);
});

test("paths outside the guarded directories are ignored", () => {
  // `website/` has its own package.json and lifecycle; this check is not it.
  const r = run({ scripts: { site: "node website/build.mjs" } });
  assert.equal(r.status, 0, r.out);
  assert.match(r.out, /0 referenced script file\(s\) and 0 glob\(s\)/);
});

// --- The vacuous pass: a glob that expands to nothing on a fresh checkout ---

test("a glob matching only untracked files fails — the silent green line", () => {
  // Strictly worse than a missing module, which at least crashes loudly. Here
  // `for f in tools/tests/*.test.mjs` expands to nothing on a clone, the body
  // never runs, and the script exits 0 while proving nothing.
  const r = run({
    scripts: { "check:tools-tests": "for f in tools/tests/*.test.mjs; do node $f; done" },
    files: ["tools/tests/a.test.mjs", "tools/tests/b.test.mjs"],
    git: (dir) => writeGitStub(dir, { tracked: [] }),
  });
  assert.equal(r.status, 1, r.out);
  assert.match(r.out, /NONE of them are tracked/);
  assert.match(r.out, /proving nothing ran/);
  assert.match(r.out, /tools\/tests\/a\.test\.mjs, tools\/tests\/b\.test\.mjs/);
});

test("a partially tracked glob fails too, naming only the untracked matches", () => {
  const r = run({
    scripts: { "lint:mjs": "prettier --check tools/*.mjs" },
    files: ["tools/kept.mjs", "tools/stray.mjs"],
    git: (dir) => writeGitStub(dir, { tracked: ["tools/kept.mjs"] }),
  });
  assert.equal(r.status, 1, r.out);
  assert.match(r.out, /1 of its 2 match\(es\)/);
  assert.match(r.out, /Untracked: tools\/stray\.mjs/);
  assert.doesNotMatch(r.out, /kept\.mjs is referenced/);
});

test("globs are not judged when git is unavailable, and the gap is announced", () => {
  const r = run({
    scripts: { "check:tools-tests": "for f in tools/tests/*.test.mjs; do node $f; done" },
    files: ["tools/tests/a.test.mjs"],
    git: absentBin,
  });
  assert.equal(r.status, 0, r.out);
  assert.match(r.out, /EXISTENCE only/);
});

test("a non-string script body does not crash the checker", () => {
  const r = run({ scripts: { weird: null, ok: "node tools/x.mjs" }, files: ["tools/x.mjs"] });
  assert.equal(r.status, 0, r.out);
});

test("the same file referenced twice is counted once", () => {
  const r = run({
    scripts: { one: "node tools/x.mjs", two: "node tools/x.mjs --fix" },
    files: ["tools/x.mjs"],
  });
  assert.equal(r.status, 0, r.out);
  assert.match(r.out, /1 referenced script file\(s\)/);
});

// --- Degrading without git -------------------------------------------------

test("no git means the skipped coverage is announced, never silent", () => {
  const r = run({
    scripts: { "check:new": "node tools/new.mjs" },
    files: ["tools/new.mjs"],
    git: absentBin,
  });
  assert.equal(r.status, 0, r.out);
  assert.match(r.out, /EXISTENCE only/);
  assert.match(r.out, /is NOT covered in this run/);
  assert.doesNotMatch(r.out, /present and tracked/);
});

test("a git that exits non-zero degrades rather than passing silently", () => {
  const r = run({
    scripts: { "check:new": "node tools/new.mjs" },
    files: ["tools/new.mjs"],
    git: (dir) => writeGitStub(dir, { tracked: [], exit: 128 }),
  });
  assert.equal(r.status, 0, r.out);
  assert.match(r.out, /EXISTENCE only/);
});

test("the existence check still fails when git is unavailable", () => {
  // Degrading must lose the tracking assertion only, not the whole check.
  const r = run({ scripts: { "check:gone": "node tools/gone.mjs" }, git: absentBin });
  assert.equal(r.status, 1, r.out);
  assert.match(r.out, /does not exist/);
  assert.match(r.out, /note: /);
});

// --- The real repository, with the real git --------------------------------

test("the real git is exercised and tracking is genuinely consulted", () => {
  // GIT_BIN deliberately unset: this is the only case proving the real
  // `git ls-files` call works. It asserts the degraded note is ABSENT, never
  // which files came back — that set changes the moment anything is committed,
  // and an assertion that flips on commit is worse than no assertion.
  const r = spawnSync(process.execPath, [CHECKER], {
    cwd: REPO_ROOT,
    encoding: "utf8",
  });
  const out = `${r.stdout ?? ""}${r.stderr ?? ""}`;
  assert.doesNotMatch(out, /EXISTENCE only/, out);
  assert.equal(typeof r.status, "number", out);
});

console.log(`check-npm-script-files: ${passed} passed, 0 failed`);
