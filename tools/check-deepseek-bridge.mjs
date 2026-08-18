#!/usr/bin/env node
/**
 * check-deepseek-bridge.mjs — fail the build if the DeepSeek Harness guard
 * bridge is misconfigured, or if this repository's hook surface drifts past
 * what that bridge can actually carry.
 *
 * Why this exists: `.deepseek/cordis.yml` reuses `.claude/hooks/*` through
 * `@deepseek-ai/dsh-hooks-claude-code` instead of re-implementing the guards.
 * That reuse is invisible — nothing fails loudly when it breaks. The original
 * hand-off shipped a MANUAL probe ("boot dsh and see if a guard denies it"),
 * which is precisely the kind of eyeball step that belongs in a script, so this
 * replaces it.
 *
 * Three layers, cheapest first:
 *   1. The overlay declares the bridge, and its configPath target really has a
 *      `hooks` key.
 *   2. DRIFT GUARD — the highest-value assertion. The bridge documents four
 *      event types. This repository declares more. If `.claude/settings.json`
 *      gains an event the bridge cannot carry, this fails so the gap gets
 *      documented rather than silently believed.
 *   3. When `dsh` is on PATH, resolve the overlay for real via
 *      `dsh --dump-config`. Offline: no API key, no network, no agent boot.
 *      Skipped loudly, never silently, when `dsh` is absent.
 *
 * Read-only. Never writes, never boots an agent, never makes a network call.
 *
 * Run: node tools/check-deepseek-bridge.mjs
 * Wired into `npm run check`.
 */
import { existsSync, readFileSync } from "node:fs";
import { spawnSync } from "node:child_process";

const OVERLAY = ".deepseek/cordis.yml";
const CLAUDE_SETTINGS = ".claude/settings.json";

/**
 * Hook events `@deepseek-ai/dsh-hooks-claude-code` documents as supported.
 * Sourced from the package README via Context7 on 2026-08-17. Widen this only
 * against the installed package's own docs — never because a build went red.
 */
const BRIDGE_COVERED_EVENTS = ["PreToolUse", "PostToolUse", "UserPromptSubmit", "Stop"];

/**
 * Events this repository declares that the bridge does not document. Recorded
 * so the gap is an asserted, reviewed fact rather than a surprise. A mismatch
 * fails the check in BOTH directions: a new uncovered event means the docs
 * understate the gap, and a disappeared one means they overstate it.
 */
const KNOWN_UNCOVERED_EVENTS = ["PostToolBatch", "SessionStart"];

/** Files that describe the coverage gap and must be revised when it moves. */
const DOCS_RECORDING_THE_GAP = [
  OVERLAY,
  ".deepseek/AGENTS.md",
  "docs/TOOLING.md",
  "CLAUDE.md",
];

const failures = [];
const notes = [];

/**
 * Assert a condition, recording a failure message when it does not hold.
 *
 * @param {boolean} condition Condition that must be true for the build to pass.
 * @param {string} message Operator-facing description of what broke.
 */
function assert(condition, message) {
  if (!condition) failures.push(message);
}

// ---------------------------------------------------------------------------
// Layer 1 — the overlay declares the bridge, wired to a real hooks file.
// ---------------------------------------------------------------------------

if (!existsSync(OVERLAY)) {
  console.error(`check-deepseek-bridge: ${OVERLAY} is missing.`);
  console.error("  The DeepSeek harness adapter is gone. Either restore it or");
  console.error("  drop this check and its docs row together.");
  process.exit(1);
}

const overlay = readFileSync(OVERLAY, "utf8");
// Matched line-wise rather than parsed: no YAML parser is a direct dependency
// here, and both candidates are only transitively present. These patterns fail
// CLOSED — a reformat this misses goes red and gets reviewed, which is the
// safe direction for a guard-reuse assertion.
const overlayChecks = [
  [/^\s*-\s*dsh-hooks-claude-code:/m, "declare the `- dsh-hooks-claude-code:` plugin"],
  [/^\s*configPath:\s*\.\/\.claude\/settings\.json\s*$/m, "point configPath at ./.claude/settings.json"],
  [/^\s*projectDir:\s*\.\s*$/m, "set projectDir (substitutes ${CLAUDE_PROJECT_DIR} for every hook)"],
  [/^\s*defaultTimeoutMs:\s*600000\s*$/m, "set defaultTimeoutMs to 600000, matching Claude Code's default"],
];
for (const [pattern, expectation] of overlayChecks) {
  assert(pattern.test(overlay), `${OVERLAY} must ${expectation}.`);
}

assert(
  existsSync(CLAUDE_SETTINGS),
  `${OVERLAY} points configPath at ${CLAUDE_SETTINGS}, which does not exist.`,
);

// ---------------------------------------------------------------------------
// Layer 2 — drift guard.
// ---------------------------------------------------------------------------

let declaredEvents = [];
if (existsSync(CLAUDE_SETTINGS)) {
  const settings = JSON.parse(readFileSync(CLAUDE_SETTINGS, "utf8"));
  declaredEvents = Object.keys(settings.hooks ?? {}).sort();
  assert(
    declaredEvents.length > 0,
    `${CLAUDE_SETTINGS} has no \`hooks\` key, so the bridge would carry nothing.`,
  );

  const uncovered = declaredEvents.filter((e) => !BRIDGE_COVERED_EVENTS.includes(e)).sort();
  const known = [...KNOWN_UNCOVERED_EVENTS].sort();

  const newlyUncovered = uncovered.filter((e) => !known.includes(e));
  const noLongerUncovered = known.filter((e) => !uncovered.includes(e));

  if (newlyUncovered.length > 0) {
    failures.push(
      `${CLAUDE_SETTINGS} now declares ${newlyUncovered.map((e) => `\`${e}\``).join(", ")}, ` +
        "which @deepseek-ai/dsh-hooks-claude-code does not document. Those guards " +
        "will NOT run under dsh. Record the widened gap in " +
        `${DOCS_RECORDING_THE_GAP.join(", ")}, then add the event to ` +
        "KNOWN_UNCOVERED_EVENTS here.",
    );
  }
  if (noLongerUncovered.length > 0) {
    failures.push(
      `${noLongerUncovered.map((e) => `\`${e}\``).join(", ")} is documented as an ` +
        `uncovered event but is no longer declared in ${CLAUDE_SETTINGS}. The docs ` +
        `now overstate the gap — update ${DOCS_RECORDING_THE_GAP.join(", ")} and ` +
        "trim KNOWN_UNCOVERED_EVENTS.",
    );
  }
}

// ---------------------------------------------------------------------------
// Layer 3 — resolve the overlay with the real binary when it is installed.
// ---------------------------------------------------------------------------

/**
 * Which binary to treat as `dsh`.
 *
 * `DSH_BIN` exists so this layer is deterministic under test — the suite pins it
 * at a nonexistent path to exercise the absent branch, and at stub scripts to
 * exercise resolve-succeeds / resolve-fails / plugin-missing. Without that
 * override the tests would silently change behaviour the moment the real harness
 * is installed, which is exactly the trap this override was added to remove.
 * Not intended for production use; leave it unset and the real `dsh` is used.
 */
const DSH_BIN = process.env.DSH_BIN || "dsh";

// Probed by invoking the binary directly rather than via `command -v` in a
// shell: passing args with `shell: true` concatenates without escaping (Node
// DEP0190), and there is no reason to involve a shell to answer "is this on
// PATH". ENOENT is the absent case; any other outcome means dsh exists.
const dshProbe = spawnSync(DSH_BIN, ["--version"], { encoding: "utf8", timeout: 30_000 });
const dshInstalled = dshProbe.error?.code !== "ENOENT";

if (!dshInstalled) {
  // Say what was not checked. A skipped layer reported as nothing reads as
  // "covered everything" when it is not.
  notes.push(
    "dsh is NOT installed, so layers 1-2 (static) ran and layer 3 (live overlay " +
      "resolution) did NOT. Config correctness is asserted; that dsh actually " +
      "loads this overlay is unproven. Install " +
      "`@deepseek-ai/dsh` and re-run to close that gap.",
  );
} else {
  const dump = spawnSync(DSH_BIN, ["--dump-config", "--patch", `./${OVERLAY}`], {
    encoding: "utf8",
    timeout: 60_000,
  });
  if (dump.error || dump.status !== 0) {
    failures.push(
      `dsh is installed but failed to resolve ${OVERLAY} ` +
        `(exit ${dump.status ?? "n/a"}${dump.error ? `, ${dump.error.message}` : ""}). ` +
        "Two causes are possible and they have different fixes. Either the overlay " +
        "genuinely does not load, in which case the guards are NOT wired and the " +
        "config needs fixing; or `dsh --dump-config` does not behave as this check " +
        "assumes. That contract was read from the package docs and has never been " +
        "run against a real install, so verify it with `dsh --help` before changing " +
        `any config. stderr: ${(dump.stderr ?? "").trim().slice(0, 300) || "(empty)"}`,
    );
  } else {
    const resolved = `${dump.stdout ?? ""}`;
    assert(
      /dsh-hooks-claude-code/.test(resolved),
      `dsh resolved ${OVERLAY} but the output names no dsh-hooks-claude-code plugin, ` +
        "so the guard bridge is not registered in the effective config.",
    );
    notes.push("dsh is installed; the overlay resolved and registers the guard bridge.");
  }
}

// ---------------------------------------------------------------------------

if (failures.length > 0) {
  console.error(`check-deepseek-bridge: ${failures.length} problem(s)\n`);
  for (const failure of failures) console.error(`  - ${failure}`);
  for (const note of notes) console.error(`\n  note: ${note}`);
  process.exit(1);
}

console.log(
  `check-deepseek-bridge: bridge wired at ${OVERLAY}; ` +
    `${declaredEvents.length} event(s) declared, ` +
    `${KNOWN_UNCOVERED_EVENTS.length} documented as uncovered ` +
    `(${KNOWN_UNCOVERED_EVENTS.join(", ")}).`,
);
for (const note of notes) console.log(`  note: ${note}`);
