#!/usr/bin/env node
/**
 * check-bmad-config.mjs — assert the BMAD skill level stays `expert` in both
 * files that carry it.
 *
 * Why a gate rather than a reminder: `_bmad/bmm/config.yaml` is
 * installer-generated, and `npx bmad-method install` rewrites it back to
 * `intermediate`. The value is duplicated into
 * `_bmad/custom/config.user.toml` deliberately — the TOML is the file the
 * owner edits, the YAML is the file most BMAD skills actually read, and a
 * skill that reads the YAML gets `intermediate` behaviour (padded,
 * explain-every-step output) with nothing failing to signal it.
 *
 * This replaces the standing "re-apply after any BMAD upgrade" TODO item: an
 * upgrade that resets the YAML now fails the commit instead of silently
 * degrading every BMAD skill until someone notices the tone change.
 *
 * Run: node tools/check-bmad-config.mjs
 * Wired into .githooks/pre-commit and `npm run check`.
 */

import { existsSync, readFileSync } from "node:fs";

/** The skill level both files must agree on. */
const EXPECTED = "expert";

/**
 * The two files carrying `user_skill_level`, with the syntax each uses.
 *
 * `installerOwned` marks the file that `npx bmad-method install` regenerates —
 * it is the one that actually regresses, and the error message says so.
 */
const TARGETS = [
  {
    path: "_bmad/bmm/config.yaml",
    pattern: /^user_skill_level:\s*["']?([\w-]+)["']?\s*$/m,
    syntax: `user_skill_level: ${EXPECTED}`,
    installerOwned: true,
  },
  {
    path: "_bmad/custom/config.user.toml",
    pattern: /^user_skill_level\s*=\s*["']([\w-]+)["']\s*$/m,
    syntax: `user_skill_level = "${EXPECTED}"`,
    installerOwned: false,
  },
];

const problems = [];
let checked = 0;

for (const { path, pattern, syntax, installerOwned } of TARGETS) {
  if (!existsSync(path)) {
    // config.user.toml is deliberately gitignored (_bmad/custom/.gitignore) —
    // it's the owner's local override file, so a fresh CI checkout will never
    // have it. Only the installer-owned file (committed, actually read by
    // BMAD skills) is required to exist; the TOML is cross-checked when
    // present, not demanded.
    if (!installerOwned) continue;
    problems.push(`${path} is missing — BMAD is expected to be installed in this repo.`);
    continue;
  }

  checked++;
  const match = readFileSync(path, "utf8").match(pattern);
  if (match === null) {
    problems.push(`${path} declares no \`user_skill_level\` — add \`${syntax}\`.`);
    continue;
  }

  if (match[1] !== EXPECTED) {
    const cause = installerOwned
      ? " — this file is installer-generated, so a `npx bmad-method install` run almost certainly reset it"
      : "";
    problems.push(
      `${path} sets \`user_skill_level\` to "${match[1]}", expected "${EXPECTED}"${cause}.`,
    );
  }
}

if (problems.length > 0) {
  console.error("check-bmad-config: FAILED\n");
  for (const p of problems) console.error(`  - ${p}`);
  console.error('\nBoth files must agree; see TODO.md → "Token/usage audit + BMAD adoption".');
  process.exit(1);
}

console.log(`check-bmad-config: clean (user_skill_level="${EXPECTED}" in ${checked} file(s)).`);
