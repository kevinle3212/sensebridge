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

import { accessSync, constants, readFileSync, statSync } from 'node:fs';
import { resolve } from 'node:path';

/** Path to the tracked project settings file this script guards. */
const SETTINGS = '.claude/settings.json';

/** Path to the tracked project-scoped MCP server configuration. */
const MCP_CONFIG = '.mcp.json';

/** Hook script that path-scopes MCP tool arguments the deny rules cannot reach. */
const MCP_PATH_GUARD = 'guard-mcp-sensitive-paths.mjs';

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
    pattern: 'tmp/handoff.md',
    reason:
      'the handoff loader is owner-personal and already lives in ~/.claude/settings.json; ' +
      'a copy here makes it fire twice per session start',
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
          matcher: group.matcher ?? '',
          command: hook.command ?? '',
          key: JSON.stringify([event, group.matcher ?? null, hook.if ?? null, hook.command ?? '']),
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
    raw = readFileSync(MCP_CONFIG, 'utf8');
  } catch {
    return [];
  }
  try {
    return Object.keys(JSON.parse(raw).mcpServers ?? {});
  } catch (error) {
    // V8 quotes the offending source in the parse error, newlines and all, which
    // would break the one-problem-per-line contract of the report below.
    const detail = error.message.replace(/\s+/g, ' ');
    problems.push(`${MCP_CONFIG} is not valid JSON (${detail}), so its servers cannot be checked.`);
    return [];
  }
}

const problems = [];
const settings = JSON.parse(readFileSync(SETTINGS, 'utf8'));
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
        'The hook silently never fires; restore the script or drop the registration.',
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
  .join('\n');

if (mcpServers.length > 0 && guardMatchers === '') {
  problems.push(
    `${SETTINGS} registers no "${MCP_PATH_GUARD}" hook, so every MCP server in ${MCP_CONFIG} ` +
      'can read and write credential material and legal/ regardless of the deny rules.',
  );
}

for (const server of guardMatchers === '' ? [] : mcpServers) {
  if (guardMatchers.includes(`mcp__${server}__`)) continue;
  if (MCP_SERVERS_WITHOUT_PATH_ARGS.has(server)) continue;
  problems.push(
    `${MCP_CONFIG} configures MCP server "${server}", which no "${MCP_PATH_GUARD}" matcher covers. ` +
      'If any of its tools accept a filesystem path, add them to the matcher in ' +
      `${SETTINGS}; if none do, record it in MCP_SERVERS_WITHOUT_PATH_ARGS with the reason.`,
  );
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
  console.error('check-settings-hooks: FAILED\n');
  for (const p of problems) console.error(`  - ${p}`);
  console.error('\nSee TODO.md → "Config dedupe" for the history behind this gate.');
  process.exit(1);
}

console.log(
  `check-settings-hooks: clean (${hooks.length} hook(s) checked in ${SETTINGS}, ` +
    `${mcpServers.length} project-scoped MCP server(s) checked for path-guard coverage).`,
);
