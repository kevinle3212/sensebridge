#!/usr/bin/env node
/**
 * check-settings-hooks.mjs — guard `.claude/settings.json`'s hook table against
 * the two failure modes it has actually hit, both of which are silent: a hook
 * that belongs in the owner's *global* config gets copied into this tracked
 * file, and the same hook gets registered twice so it fires twice.
 *
 * Why this exists rather than a note in a doc: the `tmp/handoff.md` loader was
 * removed from this file on 2026-07-31 at 12:00 PST and was back by 17:00 the
 * same day. It cost ~1.3KB of duplicated context on every single session start
 * and nothing failed — the only symptom was the handoff appearing twice at the
 * top of a transcript, which is invisible unless you happen to look. Twice is
 * a pattern, so it gets a gate.
 *
 * Run: node tools/check-settings-hooks.mjs
 * Wired into .githooks/pre-commit alongside the other node checks.
 */

import { accessSync, constants, readdirSync, readFileSync, statSync } from "node:fs";
import { homedir } from "node:os";
import { resolve } from "node:path";

/** Path to the tracked project settings file this script guards. */
const SETTINGS = ".claude/settings.json";

/** Path to the tracked project-scoped MCP server configuration. */
const MCP_CONFIG = ".mcp.json";

/** Hook script that path-scopes MCP tool arguments the deny rules cannot reach. */
const MCP_PATH_GUARD = "guard-mcp-sensitive-paths.mjs";

/**
 * Project-scoped MCP servers deliberately left out of the path guard's matcher,
 * each with the reason. A server belongs here only if **no** tool it exposes
 * accepts a filesystem path; anything else must be added to the matcher instead,
 * because a path-taking tool outside the guard can read credential material and
 * write to `legal/` no matter what the permission deny rules say.
 *
 * Empty today: `serena` is in the matcher, since its mutating tools take a
 * `relative_path`.
 *
 * @type {Map<string, string>}
 */
const MCP_SERVERS_WITHOUT_PATH_ARGS = new Map();

/**
 * Commands that must never appear in the *tracked* project settings, each with
 * the reason shown to whoever trips the gate.
 *
 * `tmp/handoff.md` is owner-personal machinery: `tmp/` is gitignored, so for
 * any contributor the loader reads a file that does not exist, and for the
 * owner it duplicates the loader already present in `~/.claude/settings.json`.
 * It belongs in exactly one place, and that place is global.
 */
const FORBIDDEN = [
  {
    pattern: "tmp/handoff.md",
    reason:
      "the handoff loader is owner-personal and already lives in ~/.claude/settings.json; " +
      "a copy here makes it fire twice per session start",
  },
];

/**
 * Flattens the settings hook table into one entry per registered hook.
 *
 * The key deliberately includes the group's `matcher` and the hook's own `if`
 * guard, because identical commands under different guards are legitimate —
 * `guard-main-commit.sh` is registered once for `Bash(git *)` and once for
 * `Bash(rtk git *)` precisely so RTK's transparent rewrite cannot slip past it.
 * Only a collision on all three is a genuine double-registration.
 *
 * @param {object} settings Parsed settings.json contents.
 * @returns {Array<{event: string, matcher: string, key: string, command: string}>} One entry per hook.
 */
function flattenHooks(settings) {
  const out = [];
  for (const [event, groups] of Object.entries(settings.hooks ?? {})) {
    for (const group of groups ?? []) {
      for (const hook of group.hooks ?? []) {
        out.push({
          event,
          matcher: group.matcher ?? "",
          command: hook.command ?? "",
          key: JSON.stringify([event, group.matcher ?? null, hook.if ?? null, hook.command ?? ""]),
        });
      }
    }
  }
  return out;
}

/**
 * Reads the project-scoped MCP server names from `.mcp.json`.
 *
 * A missing file is normal — not every clone configures project-scoped servers —
 * and yields an empty list. Malformed JSON is *not* treated as "no servers": that
 * would silently disable the coverage check below, so it is reported instead.
 *
 * @returns {string[]} Configured server names, empty when the file is absent.
 */
function readMcpServers() {
  let raw;
  try {
    raw = readFileSync(MCP_CONFIG, "utf8");
  } catch {
    return [];
  }
  try {
    return Object.keys(JSON.parse(raw).mcpServers ?? {});
  } catch (error) {
    // V8 quotes the offending source in the parse error, newlines and all, which
    // would break the one-problem-per-line contract of the report below.
    const detail = error.message.replace(/\s+/g, " ");
    problems.push(`${MCP_CONFIG} is not valid JSON (${detail}), so its servers cannot be checked.`);
    return [];
  }
}

const problems = [];
const settings = JSON.parse(readFileSync(SETTINGS, "utf8"));
const hooks = flattenHooks(settings);

for (const { event, command } of hooks) {
  for (const { pattern, reason } of FORBIDDEN) {
    if (command.includes(pattern)) {
      problems.push(`${SETTINGS} → hooks.${event} references "${pattern}" — ${reason}.`);
    }
  }
}

/**
 * Extracts the repo-relative script path a hook command runs, if any.
 *
 * Every hook in this file addresses its script through `${CLAUDE_PROJECT_DIR}`,
 * so that prefix is the reliable anchor — anything else (a bare binary, an
 * inline shell one-liner) has no path to verify and is skipped.
 *
 * @param {string} command The hook's `command` string.
 * @returns {{path: string, needsExecBit: boolean}|null} Null when there is no
 *   project-relative script to check.
 */
function scriptTarget(command) {
  const match = /\$\{CLAUDE_PROJECT_DIR\}\/([^"'\s]+)/.exec(command);
  if (match === null) return null;
  // `node "…/x.mjs"` runs through an interpreter, so the file needs no exec
  // bit; `"…/x.sh"` is executed directly and does. Leading `VAR=value`
  // assignments are skipped before looking for the interpreter — without that,
  // `DEBUG=1 node "…/x.mjs"` reads as a direct execution and this gate would
  // demand an exec bit on a file that never needs one, failing a valid config.
  const interpreted = /^\s*(?:[A-Za-z_]\w*=\S*\s+)*[\w./-]+\s/.test(command);
  return { path: match[1], needsExecBit: !interpreted };
}

// A hook whose script has been renamed, moved, or deleted fails silently:
// Claude Code logs the spawn error and carries on, so every guarantee that hook
// provided is simply gone with nothing in the transcript saying so. The two
// symlinked skill trees under `.claude/` and `.agents/` are rearranged often
// enough that this is a live risk, not a theoretical one — and a guard that
// stopped running is strictly worse than one that was never added, because the
// config still claims it is there.
for (const { event, command } of hooks) {
  const target = scriptTarget(command);
  if (target === null) continue;

  const absolute = resolve(target.path);
  let stats;
  try {
    stats = statSync(absolute);
  } catch {
    problems.push(
      `${SETTINGS} → hooks.${event} runs "${target.path}", which does not exist. ` +
        "The hook silently never fires; restore the script or drop the registration.",
    );
    continue;
  }

  if (!stats.isFile()) {
    problems.push(`${SETTINGS} → hooks.${event} runs "${target.path}", which is not a file.`);
    continue;
  }

  if (target.needsExecBit) {
    try {
      accessSync(absolute, constants.X_OK);
    } catch {
      problems.push(
        `${SETTINGS} → hooks.${event} runs "${target.path}" directly, but it is not executable. ` +
          `Fix with: chmod +x ${target.path}`,
      );
    }
  }
}

// Every project-scoped MCP server inherits the bypass that
// `guard-mcp-sensitive-paths.mjs` exists to close: permission-rule path globs
// scope by path for *built-in* tools only, because MCP rules match on tool name
// alone (probed 2026-08-01 — with `Read` of a scratch `.pem` denied,
// `mcp__filesystem__read_text_file` still returned its contents). The guard
// itself needs no change when a server is added; its **matcher** does, and
// nothing but this gate would notice. So adding a server to `.mcp.json` now
// fails the build until it is either covered by the matcher or declared here as
// taking no filesystem path.
//
// Limitation, stated rather than implied: this only sees *project-scoped*
// servers. User-scope servers (`claude mcp add -s user`, e.g. the `filesystem`
// server this repo's matcher already covers) live in the owner's global config,
// which a tracked repo gate cannot read and must not depend on.
const mcpServers = readMcpServers();
const guardMatchers = hooks
  .filter((hook) => hook.command.includes(MCP_PATH_GUARD))
  .map((hook) => hook.matcher)
  .join("\n");

if (mcpServers.length > 0 && guardMatchers === "") {
  problems.push(
    `${SETTINGS} registers no "${MCP_PATH_GUARD}" hook, so every MCP server in ${MCP_CONFIG} ` +
      "can read and write credential material and legal/ regardless of the deny rules.",
  );
}

for (const server of guardMatchers === "" ? [] : mcpServers) {
  if (guardMatchers.includes(`mcp__${server}__`)) continue;
  if (MCP_SERVERS_WITHOUT_PATH_ARGS.has(server)) continue;
  problems.push(
    `${MCP_CONFIG} configures MCP server "${server}", which no "${MCP_PATH_GUARD}" matcher covers. ` +
      "If any of its tools accept a filesystem path, add them to the matcher in " +
      `${SETTINGS}; if none do, record it in MCP_SERVERS_WITHOUT_PATH_ARGS with the reason.`,
  );
}

// `.claude/settings.global.json` is the shareable counterpart to
// CLAUDE.template.md: a user copies it into their own `~/.claude/settings.json`.
// It is tracked and published, so a personal absolute path, a machine-specific
// script, or a private service name leaking into it is both an information
// disclosure and a file that silently does not work on anyone else's machine.
//
// Checked mechanically rather than by review because the failure is invisible:
// the JSON stays valid, the harness loads it, and the only symptom is a hook
// that never fires for the person who copied it.
const GLOBAL_TEMPLATE = ".claude/settings.global.json";

/** Directory holding the hook scripts `GLOBAL_TEMPLATE` is allowed to register. */
const GLOBAL_HOOKS = ".claude/hooks/global";

/**
 * Substrings that must never appear anywhere in the shareable template, each
 * with the reason reported when one does.
 *
 * Home-relative paths are deliberately *not* on this list. The template must be
 * able to register the guards in `GLOBAL_HOOKS`, and a user-scoped hook has no
 * `${CLAUDE_PROJECT_DIR}` equivalent to address them by — `$HOME` is the only
 * portable form. The narrower rule below replaces the blanket ban: a `$HOME`
 * reference is fine when it names a script this repository actually ships.
 *
 * @type {Array<{pattern: RegExp, reason: string}>}
 */
const TEMPLATE_FORBIDDEN = [
  {
    pattern: /\/Users\/|\/home\/|C:\\\\/,
    reason: "an absolute home-directory path is personal and breaks on another machine",
  },
  {
    pattern: /wakatime|caffeinate|away-guard|gitnexus|storage-maintenance/i,
    reason: "a machine-specific helper script that ships with no template",
  },
  { pattern: /truthifi|puppeteer/i, reason: "a private or setup-specific service name" },
  {
    pattern:
      /"(model|theme|editorMode|tui|verbose|preferredNotifChannel|remoteControlAtStartup|enabledPlugins|extraKnownMarketplaces)"/,
    reason: "a personal preference, not part of the engineering standard",
  },
];

let templateRaw;
try {
  templateRaw = readFileSync(GLOBAL_TEMPLATE, "utf8");
} catch {
  problems.push(
    `${GLOBAL_TEMPLATE} is missing — it is the shareable counterpart to CLAUDE.template.md.`,
  );
  templateRaw = "";
}

if (templateRaw !== "") {
  try {
    JSON.parse(templateRaw);
  } catch (error) {
    problems.push(
      `${GLOBAL_TEMPLATE} is not valid JSON (${error.message.replace(/\s+/g, " ")}); it cannot be copied as-is.`,
    );
  }
  for (const { pattern, reason } of TEMPLATE_FORBIDDEN) {
    const hit = pattern.exec(templateRaw);
    if (hit !== null) {
      problems.push(`${GLOBAL_TEMPLATE} contains "${hit[0]}" — ${reason}.`);
    }
  }

  // A `$HOME` path in the template is a promise that copying this repository's
  // `GLOBAL_HOOKS` directory into `~/.claude/hooks/` makes the registration
  // work. Verify the promise: a registration pointing at a script that is not
  // here produces a hook that fails to spawn, and Claude Code reports that only
  // in its own log — the transcript looks exactly like a guard that passed.
  // Backslash is excluded from the path class because this scans the raw JSON
  // source, where a quoted hook command ends `…guard.sh\"` — including that
  // escape in the capture would look for a script whose name ends in a
  // backslash and report every valid registration as missing.
  for (const reference of templateRaw.matchAll(/\$HOME\/([^"'\s\\]+)/g)) {
    const target = reference[1];
    const expected = /^\.claude\/hooks\/(.+)$/.exec(target);
    if (expected === null) {
      problems.push(
        `${GLOBAL_TEMPLATE} references "$HOME/${target}", which is outside ~/.claude/hooks/. ` +
          `Only scripts shipped in ${GLOBAL_HOOKS}/ may be registered by home-relative path.`,
      );
      continue;
    }
    try {
      statSync(resolve(GLOBAL_HOOKS, expected[1]));
    } catch {
      problems.push(
        `${GLOBAL_TEMPLATE} registers "$HOME/${target}", but ${GLOBAL_HOOKS}/${expected[1]} does not exist. ` +
          "Whoever copies this template gets a hook that silently never fires.",
      );
    }
  }
}

// Drift between the shipped template and the owner's installed copy is the
// failure this repository has the standing to catch and nobody else does: the
// installed copy is what actually guards every session, while the tracked copy
// is what gets reviewed. When they disagree, the review is of a file that is
// not running.
//
// Absent installs are not a problem — a contributor who has never copied these
// out should see nothing. Only a copy that exists *and* differs is reported.
const installedHooks = resolve(homedir(), ".claude/hooks");
let shipped = [];
try {
  shipped = readdirSync(GLOBAL_HOOKS).filter(
    (name) => name.endsWith(".sh") || name.endsWith(".mjs"),
  );
} catch {
  problems.push(
    `${GLOBAL_HOOKS}/ is missing, so ${GLOBAL_TEMPLATE} ships registrations with no scripts.`,
  );
}

for (const name of shipped) {
  let installed;
  try {
    installed = readFileSync(resolve(installedHooks, name), "utf8");
  } catch {
    continue; // Not installed on this machine; nothing to compare against.
  }
  if (installed !== readFileSync(resolve(GLOBAL_HOOKS, name), "utf8")) {
    problems.push(
      `${GLOBAL_HOOKS}/${name} differs from the installed ~/.claude/hooks/${name}. ` +
        "The reviewed copy is not the running one; sync whichever is correct.",
    );
  }
}

const seen = new Map();
for (const { event, key, command } of hooks) {
  if (seen.has(key)) {
    problems.push(
      `${SETTINGS} → hooks.${event} registers the same command twice under the same matcher, ` +
        `so it runs twice: ${command.slice(0, 80)}`,
    );
  }
  seen.set(key, true);
}

if (problems.length > 0) {
  console.error("check-settings-hooks: FAILED\n");
  for (const p of problems) console.error(`  - ${p}`);
  console.error('\nSee TODO.md → "Config dedupe" for the history behind this gate.');
  process.exit(1);
}

console.log(
  `check-settings-hooks: clean (${hooks.length} hook(s) checked in ${SETTINGS}, ` +
    `${mcpServers.length} project-scoped MCP server(s) checked for path-guard coverage, ` +
    `${GLOBAL_TEMPLATE} checked for personal data, ` +
    `${shipped.length} shipped global hook(s) checked for drift).`,
);
