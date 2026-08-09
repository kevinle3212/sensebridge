#!/usr/bin/env node
// guard-bash-secret-read.mjs — PreToolUse hook (matcher: Bash). Denies the
// obvious shapes that read credential material through the shell, mirroring the
// Read(**/*.pem, **/.env, ...) deny rules that Bash arguments escape.
//
// Scope, stated plainly: this is BEST-EFFORT AND BYPASSABLE BY DESIGN. Bash is
// a general-purpose interpreter, so the set of ways to read a file is
// unbounded — `python3 -c 'open(".env").read()'`, a here-doc, a base64 round
// trip, a path assembled from variables, or any script that reads the file
// itself all sail past. It is not a security boundary and must never be cited
// as one; the real boundaries are that secrets live in the Keychain or GitHub
// Actions secrets and never on disk here in the first place.
//
// What it does buy: the accident. `cat .env` typed on autopilot, a `grep -r`
// that wanders into a key file, a `cp` of signing material into a scratch dir.
// Those are the realistic ways a secret ends up in a transcript, and they are
// cheap to catch.
//
// Taxonomy is imported from tools/check-sensitive-files.mjs — the same source
// the commit gate and guard-mcp-sensitive-paths.mjs use. Three enforcement
// points, one list: a path added there is covered everywhere at once.

import { isSensitiveByName, nameCheckExempt } from "../../tools/check-sensitive-files.mjs";
import { isAbsolute, relative, resolve } from "node:path";

/**
 * Commands whose job is to surface file contents.
 *
 * Deliberately narrow. Every entry here is a program whose *purpose* is to read
 * or copy a file, so pairing one with a credential path is almost never
 * intentional. General-purpose interpreters (`node`, `python3`, `sh`) are
 * omitted on purpose: they read files constantly for legitimate reasons, and
 * including them would fire on ordinary work — which is how a guard gets
 * routed around instead of fixed.
 */
const READER_VERBS = new Set([
	"cat", "bat", "head", "tail", "less", "more", "nl", "tac",
	"strings", "xxd", "od", "hexdump", "base64", "shasum", "md5",
	"grep", "egrep", "fgrep", "rg", "ag", "ack",
	"cp", "scp", "rsync", "tee", "open", "pbcopy", "code",
	"awk", "cut", "sort", "uniq", "wc", "diff",
]);

/**
 * Leading tokens that wrap another command rather than being one.
 *
 * `rtk` matters most here: this repo rewrites most Bash calls through RTK, so a
 * guard that only inspected the first token would see `rtk` and miss `rtk grep
 * foo .env` entirely — i.e. it would be blind on the repo's normal path.
 */
const WRAPPER_PREFIXES = new Set([
	"rtk", "proxy", "sudo", "command", "time", "nohup", "nice", "env", "xargs", "builtin", "exec",
]);

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
	if (decision === "allow") process.exit(0);
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
 * @returns {Promise<string>} Raw payload, empty when nothing was piped.
 */
async function readStdin() {
	const chunks = [];
	for await (const chunk of process.stdin) chunks.push(chunk);
	return Buffer.concat(chunks).toString("utf8");
}

/**
 * Splits a command line into independently-executed segments.
 *
 * Segment-level analysis is what keeps this precise: `cat README.md && rm -f
 * old.pem` pairs a reader verb with a credential path only when the two are
 * read as one command. Split first, and each half is judged on its own — the
 * `cat` reads a readme, the `rm` names a key but is not a reader.
 *
 * @param {string} command
 * @returns {string[]} Segments, in order.
 */
function segments(command) {
	return command.split(/\|\||&&|[;|\n]/);
}

/**
 * Strips shell quoting and redirect punctuation from one token.
 *
 * @param {string} token
 * @returns {string} Bare token, possibly empty.
 */
function unquote(token) {
	return token.replace(/^[<>]+/, "").replace(/^["']|["']$/g, "");
}

/**
 * Reports whether a bare token names credential material.
 *
 * Resolves relative paths against the project root so `.env` and its absolute
 * spelling are judged alike, and honours the same `.env.example` carve-out the
 * commit gate uses.
 *
 * @param {string} token
 * @returns {boolean}
 */
function isSensitiveToken(token) {
	if (token === "") return false;
	const absolute = isAbsolute(token) ? token : resolve(PROJECT_DIR, token);
	const rel = relative(PROJECT_DIR, absolute);
	const inRepo = rel !== "" && !rel.startsWith("..") && !isAbsolute(rel);
	if (inRepo && nameCheckExempt.has(rel)) return false;
	return isSensitiveByName(inRepo ? rel : token);
}

const raw = await readStdin();

// Fail OPEN, unlike guard-mcp-sensitive-paths.mjs which fails closed. The
// asymmetry is deliberate: that guard covers a narrow MCP tool family, so
// denying on a bad payload costs one retry through properly-scoped built-ins.
// This one is on the Bash path — every build, test, and git call in the
// session — so failing closed on a parse error would take the whole session
// down to protect a boundary this hook already admits it cannot hold.
let command;
try {
	command = JSON.parse(raw)?.tool_input?.command;
} catch {
	decide("allow");
}
if (typeof command !== "string" || command === "") decide("allow");

for (const segment of segments(command)) {
	const tokens = segment.trim().split(/\s+/).filter(Boolean);
	if (tokens.length === 0) continue;

	// Peel wrappers (and any `VAR=value` assignments) to find the real verb.
	let index = 0;
	while (
		index < tokens.length &&
		(WRAPPER_PREFIXES.has(unquote(tokens[index])) || /^[A-Za-z_]\w*=/.test(tokens[index]))
	) {
		index += 1;
	}

	const verb = unquote(tokens[index] ?? "").split("/").pop() ?? "";
	const args = tokens.slice(index + 1);

	// An input redirect reads the file whatever the verb is (`while read line;
	// do …; done < .env`), so it is checked independently of READER_VERBS.
	// Matched on the raw segment rather than on tokens because the shell
	// accepts `<.env` and `< .env` alike, and the spaced form splits into a
	// bare `<` whose own text says nothing.
	const redirectTarget = /<\s*([^\s<>|&]+)/.exec(segment)?.[1];
	const redirected = redirectTarget !== undefined && isSensitiveToken(unquote(redirectTarget));
	const isReader = READER_VERBS.has(verb);
	if (!isReader && !redirected) continue;

	const hit = redirected ? unquote(redirectTarget) : args.map(unquote).find(isSensitiveToken);
	if (hit === undefined) continue;

	decide(
		"deny",
		`Blocked: this command reads ${hit}, which is credential or signing ` +
			`material. The Read/Grep(**/*.pem, **/.env, ...) deny rules in ` +
			`settings.json cover the built-in tools only — Bash arguments are not ` +
			`path-scoped, so this hook mirrors them. Note it is best-effort and ` +
			`bypassable by design: it catches the accident, not a determined ` +
			`read. Secrets belong in the Keychain (on-device) or GitHub Actions ` +
			`secrets (CI), never on disk here — see docs/ENVIRONMENT.md. If you ` +
			`genuinely need this file, ask the user.`,
	);
}

decide("allow");
