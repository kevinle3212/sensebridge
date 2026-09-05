#!/usr/bin/env node
// skill-lock.mjs — sha256-hash-lock the canonical skill tree (.agents/skills),
// the review-persona registrations (.agents/agents/*.md), and every harness
// adapter, so a canonical edit without a re-sync shows up as drift instead of
// silently diverging. Adapted from salon-os's scripts/maintenance/sync-skills.mjs
// — same manifest schema, same lock shape; this repo's own skill bodies are
// unchanged by the port.
//
// `impeccable` is vendor-managed by `npx impeccable install`/`update`, which
// writes different per-provider content into each harness's skills dir on its
// own schedule — it is registered in the manifest for discoverability but
// excluded from this lock's hashed file set so its own churn never reads as
// drift here.
//
// Usage:
//   node tools/skill-lock.mjs           verify against .agents/skill-lock.json
//   node tools/skill-lock.mjs --write   regenerate .agents/skill-lock.json
//   node tools/skill-lock.mjs --print   print the expected lock, write nothing

import { createHash } from "node:crypto";
import { readdir, readFile, realpath, writeFile } from "node:fs/promises";
import { relative, resolve, sep } from "node:path";

const root = resolve(import.meta.dirname, "..");
const manifestPath = resolve(root, ".agents/manifest.json");
const lockPath = resolve(root, ".agents/skill-lock.json");
const write = process.argv.includes("--write");
const print = process.argv.includes("--print");

/** Repo-relative, forward-slash path for `path`; throws if it resolves outside the repo root. */
function portablePath(path) {
  const value = relative(root, path).split(sep).join("/");
  if (value.startsWith("../") || value === "..")
    throw new Error(`Path escapes repository: ${path}`);
  return value;
}

/** Every regular file under `path`, recursively, sorted for a deterministic lock. */
async function filesUnder(path) {
  const entries = await readdir(path, { withFileTypes: true });
  const files = [];
  for (const entry of entries.sort((a, b) => a.name.localeCompare(b.name))) {
    const target = resolve(path, entry.name);
    if (entry.isDirectory()) files.push(...(await filesUnder(target)));
    else if (entry.isFile()) files.push(target);
  }
  return files;
}

/** SHA-256 hex digest of the file at `path`. */
async function digest(path) {
  return createHash("sha256")
    .update(await readFile(path))
    .digest("hex");
}

const manifest = JSON.parse(await readFile(manifestPath, "utf8"));
if (manifest.schema_version !== 1 || manifest.canonical_root !== ".agents/skills") {
  throw new Error("Unsupported skill manifest schema or canonical root");
}

const names = new Set();
const vendorNames = new Set();
const nativeTopLevelDirs = new Set();
for (const skill of manifest.skills ?? []) {
  if (names.has(skill.name)) throw new Error(`Duplicate skill name: ${skill.name}`);
  names.add(skill.name);
  if (skill.kind === "vendor") vendorNames.add(skill.name);
  // Most skills sit directly under canonical_root (.agents/skills/<name>/SKILL.md);
  // a few (gitnexus's sub-skills) nest one level deeper — either shape is fine as
  // long as the immediate parent directory matches the registered name.
  if (
    !skill.path.startsWith(`${manifest.canonical_root}/`) ||
    !skill.path.endsWith(`/${skill.name}/SKILL.md`)
  ) {
    throw new Error(`Non-canonical skill path for ${skill.name}`);
  }
  const body = await readFile(resolve(root, skill.path), "utf8");
  if (!body.startsWith("---\n") || !body.includes(`\nname: ${skill.name}\n`)) {
    throw new Error(`Invalid skill frontmatter: ${skill.path}`);
  }
  if (skill.kind === "vendor") continue;
  // Claude Code's native Skill tool only autoloads from .claude/skills/<dir>/SKILL.md —
  // it does not discover .agents/skills/ on its own (a manifest/lock entry with no
  // matching .claude/skills/ entry is invisible to Claude's own Skill tool, degrading
  // silently to sensebridge-router's slower manual-lookup fallback). Track each skill's
  // top-level canonical directory (gitnexus's 6 sub-skills share one parent) and verify
  // it below.
  const topLevel = skill.path.slice(`${manifest.canonical_root}/`.length).split("/")[0];
  nativeTopLevelDirs.add(topLevel);
}

for (const topLevel of nativeTopLevelDirs) {
  const claudePath = resolve(root, ".claude/skills", topLevel);
  const canonicalPath = resolve(root, manifest.canonical_root, topLevel);
  let claudeReal, canonicalReal;
  try {
    claudeReal = await realpath(claudePath);
  } catch {
    throw new Error(
      `.claude/skills/${topLevel} is missing — Claude's native Skill tool can't discover this skill without it`,
    );
  }
  canonicalReal = await realpath(canonicalPath);
  if (claudeReal !== canonicalReal) {
    throw new Error(
      `.claude/skills/${topLevel} does not resolve to ${manifest.canonical_root}/${topLevel}`,
    );
  }
}

const adapterPaths = Object.values(manifest.harnesses?.adapters ?? {});
for (const path of adapterPaths) await readFile(resolve(root, path), "utf8");

const skillFiles = (await filesUnder(resolve(root, manifest.canonical_root))).filter((path) => {
  const [, name] = /\.agents\/skills\/([^/]+)\//.exec(portablePath(path)) ?? [];
  return !vendorNames.has(name);
});

const personaFiles = await filesUnder(resolve(root, ".agents/agents"));

const tracked = [
  manifestPath,
  ...skillFiles,
  ...personaFiles,
  resolve(root, ".agents/rules/skills.md"),
  resolve(root, ".agents/rules/precedence.md"),
  ...adapterPaths.map((path) => resolve(root, path)),
];
const entries = Object.fromEntries(
  await Promise.all(
    [...new Set(tracked.map((path) => resolve(path)))]
      .sort()
      .map(async (path) => [portablePath(path), await digest(path)]),
  ),
);
const expected = `${JSON.stringify({ schema_version: 1, algorithm: "sha256", files: entries }, null, 2)}\n`;

if (print) {
  process.stdout.write(expected);
} else if (write) {
  await writeFile(lockPath, expected, { encoding: "utf8", mode: 0o644 });
  console.log(`skill-lock: wrote ${portablePath(lockPath)} (${Object.keys(entries).length} files)`);
} else {
  const actual = await readFile(lockPath, "utf8").catch(() => "");
  if (actual !== expected) {
    throw new Error(
      "Canonical skills, personas, or adapters drifted; review the changes, then regenerate with `node tools/skill-lock.mjs --write`.",
    );
  }
  console.log(
    `skill-lock: clean (${manifest.skills.length} skills, ${Object.keys(entries).length} files)`,
  );
}
