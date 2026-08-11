#!/usr/bin/env node
// guard-mcp-sensitive-paths.mjs — PreToolUse hook (matcher: the MCP tools that
// take a filesystem path). Denies MCP access to credential/signing material and
// to legal/, mirroring the settings.json deny rules that those tools bypass.
//
// Why this exists. Claude Code's permission-rule glob syntax scopes by path for
// *built-in* tools only: `Read(**/*.pem)` and `Edit(legal/**)` never match an
// MCP tool's arguments, because MCP rules match on tool name alone. The repo
// already knew this for one case — guard-serena-legal.sh covers legal/ for
// Serena's six mutating tools — but the same hole was left open twice:
//
//   1. the whole `mcp__filesystem__*` family, which duplicates Read/Write/Edit
//      /Grep with none of their path scoping, and
//   2. every secret path, for both families.
//
// Both were confirmed by probe on 2026-08-01, not assumed: with the built-in
// `Read` of a scratch .pem denied by `Read(**/*.pem)`, an
// `mcp__filesystem__read_text_file` of the *same path* returned its contents,
// and `mcp__filesystem__write_file` wrote to it. That is a full bypass of the
// credential deny list by a tool that is installed by default.
//
// This hook is deliberately name-based and cheap: it is on the latency path of
// every matched MCP call. Contents are never read here — tools/check-sensitive-
// files.mjs owns the content scan at commit time. The two agree by construction
// because the taxonomy is imported from that file rather than re-encoded; a
// second hand-maintained copy would drift, and the direction it drifts in is a
// file the commit gate blocks but this guard hands over.

import { isSensitiveByName, nameCheckExempt } from "../../tools/check-sensitive-files.mjs";
import { isAbsolute, relative, resolve } from "node:path";

/**
 * `tool_input` keys that carry a filesystem path across the guarded MCP tools.
 *
 * Scalars and arrays both appear: `mcp__filesystem__read_multiple_files` takes
 * `paths`, `move_file` takes `source`/`destination`, Serena's editors take
 * `relative_path`, and the rest take `path`. Keys are matched by name rather
 * than by walking every string in `tool_input`, so a path-shaped *content*
 * string (the replacement text of an edit) cannot trip the guard.
 */
const PATH_KEYS = ["path", "paths", "source", "destination", "relative_path", "file_path"];

/** Project root; hook cwd is not guaranteed, so prefer the harness variable. */
const PROJECT_DIR = process.env.CLAUDE_PROJECT_DIR ?? process.cwd();

/**
 * Emits a PreToolUse decision and exits.
 *
 * @param {"deny"|"allow"} decision
 * @param {string} [reason] Shown to the model; omitted for a silent allow.
 * @returns {never}
 */
function decide(decision, reason) {
  if (decision === "allow" && !reason) process.exit(0);
  process.stdout.write(
    JSON.stringify({
      hookSpecificOutput: {
        hookEventName: "PreToolUse",
        permissionDecision: decision,
        permissionDecisionReason: reason,
      },
    }),
  );
  process.exit(0);
}

/**
 * Reads all of stdin.
 *
 * @returns {Promise<string>} Raw payload, empty string when nothing was piped.
 */
async function readStdin() {
  const chunks = [];
  for await (const chunk of process.stdin) chunks.push(chunk);
  return Buffer.concat(chunks).toString("utf8");
}

/**
 * Collects every path-valued entry of `tool_input`.
 *
 * @param {Record<string, unknown>} toolInput
 * @returns {string[]} Non-empty path strings, in declaration order.
 */
function extractPaths(toolInput) {
  const found = [];
  for (const key of PATH_KEYS) {
    const value = toolInput?.[key];
    if (typeof value === "string" && value.length > 0) found.push(value);
    else if (Array.isArray(value)) {
      for (const entry of value) {
        if (typeof entry === "string" && entry.length > 0) found.push(entry);
      }
    }
  }
  return found;
}

/**
 * Classifies one path against the two deny surfaces this hook mirrors.
 *
 * Relative paths resolve against the project root so that `.env` and
 * `/abs/path/to/repo/.env` are judged identically — an MCP tool accepts either
 * spelling, so judging only the literal string would leave the absolute form
 * open. The exemption is applied on the repo-relative form because that is how
 * NAME_CHECK_EXEMPT records its entries.
 *
 * @param {string} candidate Path exactly as the tool received it.
 * @returns {{kind: "secret"|"legal", shown: string}|null} Null when allowed.
 */
function classify(candidate) {
  const absolute = isAbsolute(candidate) ? candidate : resolve(PROJECT_DIR, candidate);
  const rel = relative(PROJECT_DIR, absolute);
  // Inside the repo, judge and display the tidy relative form; outside it
  // (an absolute path elsewhere on the machine) keep the original.
  const inRepo = rel !== "" && !rel.startsWith("..") && !isAbsolute(rel);
  const shown = inRepo ? rel : candidate;

  if (inRepo && (rel === "legal" || rel.startsWith("legal/"))) {
    return { kind: "legal", shown };
  }
  if (inRepo && nameCheckExempt.has(rel)) return null;
  if (isSensitiveByName(shown)) return { kind: "secret", shown };
  return null;
}

const raw = await readStdin();

// Fail closed. Every other hook in this repo is advisory and rightly fails open,
// but this one is the only thing standing between an MCP tool and the
// credential deny list. If the payload cannot be parsed, the path is unknown —
// and "unknown path" is exactly the case an attacker-shaped or malformed input
// produces. Denying costs one retry through the built-in tools, which are
// properly scoped; allowing costs the guarantee. Blast radius is limited to the
// matched MCP tools, and the reason string names the way forward.
let payload;
try {
  payload = JSON.parse(raw);
} catch {
  decide(
    "deny",
    "Blocked: guard-mcp-sensitive-paths could not parse the tool payload, so it " +
      "cannot prove this call stays clear of credential material or legal/. " +
      "This guard fails closed by design. Use the built-in Read/Edit tools, " +
      "whose deny rules are enforced by Claude Code itself.",
  );
}

const toolName = typeof payload?.tool_name === "string" ? payload.tool_name : "(unknown MCP tool)";

for (const candidate of extractPaths(payload?.tool_input)) {
  const hit = classify(candidate);
  if (hit === null) continue;

  const reason =
    hit.kind === "legal"
      ? `Blocked: ${hit.shown} is under legal/, which CLAUDE.md gates on explicit ` +
        `owner approval for every edit. ${toolName} is an MCP tool, so the ` +
        "Edit(legal/**) deny rule in settings.json does not apply to it — this " +
        "hook enforces it instead. Ask the user before touching it."
      : `Blocked: ${hit.shown} is credential or signing material. The ` +
        "Read/Grep/Edit(**/*.pem, **/.env, ...) deny rules in settings.json " +
        `cover built-in tools only; ${toolName} is an MCP tool and would ` +
        "bypass them, so this hook denies it instead. Secrets live in the " +
        "Keychain (on-device) or GitHub Actions secrets (CI) — see " +
        "docs/ENVIRONMENT.md. If you genuinely need this file, ask the user.";

  decide("deny", reason);
}

decide("allow");
