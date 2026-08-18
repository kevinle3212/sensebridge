#!/usr/bin/env node
// Regression test for check-deepseek-bridge.mjs.
//
// The finding this answers: the DeepSeek guard bridge was "verified" by a manual
// probe a human was told to run by hand, which is not verification at all. The
// checker replaced that; this proves the checker itself actually fails when the
// bridge breaks. A guard that cannot fail is decoration.
//
// The SECOND finding this answers, and the reason every case below pins DSH_BIN:
// the first version of this suite asserted the checker's "dsh is not installed"
// branch without controlling for it. Installing the harness — the documented
// next step — would have flipped three cases and turned `npm run check` red on
// the intended happy path. Environment-dependent tests are not tests. Pinning
// DSH_BIN also buys real coverage of layer 3, which previously had none: stub
// binaries exercise resolve-succeeds, resolve-fails, and plugin-missing without
// installing anything.
//
// Run: node tools/tests/check-deepseek-bridge.test.mjs

import assert from "node:assert/strict";
import { spawnSync } from "node:child_process";
import { mkdtempSync, mkdirSync, writeFileSync, rmSync } from "node:fs";
import { tmpdir } from "node:os";
import { join, resolve, dirname } from "node:path";
import { fileURLToPath } from "node:url";

const HERE = dirname(fileURLToPath(import.meta.url));
const CHECKER = resolve(HERE, "../check-deepseek-bridge.mjs");
const REPO_ROOT = resolve(HERE, "../..");

let passed = 0;

/** Runs one named assertion block, tallying it for the summary line. */
function test(name, fn) {
  fn();
  passed += 1;
  console.log(`  ok — ${name}`);
}

const VALID_OVERLAY = [
  "- dsh-hooks-claude-code:",
  "    configPath: ./.claude/settings.json",
  "    projectDir: .",
  "    defaultTimeoutMs: 600000",
  "",
].join("\n");

/** The five hook events the real `.claude/settings.json` declares today. */
const REAL_EVENTS = ["SessionStart", "PostToolUse", "PreToolUse", "Stop", "PostToolBatch"];

/**
 * Writes an executable stand-in for the `dsh` binary.
 *
 * @param {string} dir Directory to write the stub into.
 * @param {object} behaviour How the stub should answer `--dump-config`.
 * @param {number} behaviour.exit Exit status for the dump call.
 * @param {string} behaviour.stdout Text the dump call prints.
 * @returns {string} Absolute path to the stub, suitable for DSH_BIN.
 */
function writeDshStub(dir, { exit = 0, stdout = "plugins:\n  - dsh-hooks-claude-code: {}\n" }) {
  const path = join(dir, "dsh-stub");
  writeFileSync(
    path,
    [
      "#!/bin/sh",
      // --version must always succeed: the checker uses it only to decide that
      // the binary exists at all.
      'if [ "$1" = "--version" ]; then echo "dsh 0.0.0-stub"; exit 0; fi',
      `cat <<'STUB_EOF'`,
      stdout.replace(/\n$/, ""),
      "STUB_EOF",
      `exit ${exit}`,
      "",
    ].join("\n"),
    { mode: 0o755 },
  );
  return path;
}

/** An absolute path guaranteed not to exist, forcing the ENOENT branch. */
function absentBin(dir) {
  return join(dir, "definitely-not-installed-dsh");
}

/**
 * Builds a throwaway repository tree and runs the checker inside it.
 *
 * @param {object} tree Fixture description.
 * @param {string|null} tree.overlay `.deepseek/cordis.yml` body, or null to omit the file.
 * @param {string[]|null} tree.events Hook event names for `.claude/settings.json`,
 *   or null to omit that file entirely.
 * @param {((dir: string) => string)|null} tree.bin Resolves the DSH_BIN value from
 *   the fixture dir. Defaults to a nonexistent path.
 * @returns {{status: number, out: string}} Exit code and combined output.
 */
function run({ overlay = VALID_OVERLAY, events = REAL_EVENTS, bin = absentBin } = {}) {
  const dir = mkdtempSync(join(tmpdir(), "dsbridge-"));
  try {
    if (overlay !== null) {
      mkdirSync(join(dir, ".deepseek"), { recursive: true });
      writeFileSync(join(dir, ".deepseek/cordis.yml"), overlay);
    }
    if (events !== null) {
      mkdirSync(join(dir, ".claude"), { recursive: true });
      const hooks = Object.fromEntries(events.map((e) => [e, []]));
      writeFileSync(join(dir, ".claude/settings.json"), JSON.stringify({ hooks }, null, 2));
    }
    const r = spawnSync(process.execPath, [CHECKER], {
      cwd: dir,
      encoding: "utf8",
      env: { ...process.env, DSH_BIN: bin(dir) },
    });
    return { status: r.status, out: `${r.stdout ?? ""}${r.stderr ?? ""}` };
  } finally {
    rmSync(dir, { recursive: true, force: true });
  }
}

/**
 * Runs the checker against the real repository with a pinned DSH_BIN, so the
 * result does not depend on whether the harness happens to be installed.
 *
 * @param {(dir: string) => string} bin Resolves the DSH_BIN value.
 * @returns {{status: number, out: string}} Exit code and combined output.
 */
function runRepo(bin) {
  const scratch = mkdtempSync(join(tmpdir(), "dsbridge-bin-"));
  try {
    const r = spawnSync(process.execPath, [CHECKER], {
      cwd: REPO_ROOT,
      encoding: "utf8",
      env: { ...process.env, DSH_BIN: bin(scratch) },
    });
    return { status: r.status, out: `${r.stdout ?? ""}${r.stderr ?? ""}` };
  } finally {
    rmSync(scratch, { recursive: true, force: true });
  }
}

// --- Static layers (1 and 2), with layer 3 pinned off ----------------------

test("the real repository passes with dsh absent", () => {
  const r = runRepo(absentBin);
  assert.equal(r.status, 0, r.out);
});

test("the real repository passes with a dsh that resolves the overlay", () => {
  // The case Codex flagged: installing the harness must not turn `npm run check`
  // red. With a well-behaved binary the repo config passes all three layers.
  const r = runRepo((dir) => writeDshStub(dir, {}));
  assert.equal(r.status, 0, r.out);
  assert.match(r.out, /registers the guard bridge/);
});

test("a well-formed fixture passes", () => {
  const r = run();
  assert.equal(r.status, 0, r.out);
});

test("skipping the live layer is reported, never silent", () => {
  const r = run();
  assert.match(r.out, /dsh is NOT installed/);
  assert.match(r.out, /did NOT/);
});

test("a NEW uncovered hook event fails the build", () => {
  // The drift case that matters: someone adds an event the bridge cannot carry,
  // and every guard behind it silently stops running under dsh.
  const r = run({ events: [...REAL_EVENTS, "PreCompact"] });
  assert.equal(r.status, 1, r.out);
  assert.match(r.out, /PreCompact/);
  assert.match(r.out, /will NOT run under dsh/);
});

test("a covered event added to settings does NOT fail the build", () => {
  const r = run({ events: [...REAL_EVENTS, "UserPromptSubmit"] });
  assert.equal(r.status, 0, r.out);
});

test("a narrowed gap fails, so docs cannot overstate it", () => {
  const r = run({ events: REAL_EVENTS.filter((e) => e !== "SessionStart") });
  assert.equal(r.status, 1, r.out);
  assert.match(r.out, /overstate the gap/);
});

test("a missing overlay fails", () => {
  const r = run({ overlay: null });
  assert.equal(r.status, 1, r.out);
  assert.match(r.out, /is missing/);
});

test("an overlay that omits projectDir fails", () => {
  const r = run({
    overlay: [
      "- dsh-hooks-claude-code:",
      "    configPath: ./.claude/settings.json",
      "    defaultTimeoutMs: 600000",
      "",
    ].join("\n"),
  });
  assert.equal(r.status, 1, r.out);
  assert.match(r.out, /projectDir/);
});

test("an overlay pointing at a nonexistent settings file fails", () => {
  const r = run({ events: null });
  assert.equal(r.status, 1, r.out);
  assert.match(r.out, /does not exist/);
});

test("an overlay that never names the bridge plugin fails", () => {
  const r = run({
    overlay: ["- some-other-plugin:", "    configPath: ./.claude/settings.json", ""].join("\n"),
  });
  assert.equal(r.status, 1, r.out);
  assert.match(r.out, /dsh-hooks-claude-code/);
});

test("settings.json with no hooks key fails", () => {
  const r = run({ events: [] });
  assert.equal(r.status, 1, r.out);
  assert.match(r.out, /would carry nothing/);
});

// --- Layer 3, exercised through stubs -------------------------------------

test("layer 3 passes and says so when the overlay resolves", () => {
  const r = run({ bin: (dir) => writeDshStub(dir, {}) });
  assert.equal(r.status, 0, r.out);
  assert.match(r.out, /registers the guard bridge/);
  assert.doesNotMatch(r.out, /NOT installed/);
});

test("layer 3 fails when dsh cannot resolve the overlay", () => {
  const r = run({ bin: (dir) => writeDshStub(dir, { exit: 3, stdout: "boom\n" }) });
  assert.equal(r.status, 1, r.out);
  assert.match(r.out, /failed to resolve/);
});

test("a resolve failure names both causes, so the wrong thing does not get fixed", () => {
  // Fail-closed is right for a guard, but the --dump-config contract has never
  // been run against a real install. The message must not imply the config is
  // definitely at fault.
  const r = run({ bin: (dir) => writeDshStub(dir, { exit: 3, stdout: "boom\n" }) });
  assert.match(r.out, /Two causes are possible/);
  assert.match(r.out, /never been\s+run against a real install|never been run against a real install/);
});

test("layer 3 fails when the resolved config omits the bridge plugin", () => {
  const r = run({
    bin: (dir) => writeDshStub(dir, { exit: 0, stdout: "plugins:\n  - something-else: {}\n" }),
  });
  assert.equal(r.status, 1, r.out);
  assert.match(r.out, /not registered in the effective config/);
});

console.log(`check-deepseek-bridge: ${passed} passed, 0 failed`);
