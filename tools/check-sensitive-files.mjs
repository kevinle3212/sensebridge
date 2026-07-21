#!/usr/bin/env node
// check-sensitive-files.mjs — refuse to publish signing/credential material,
// provider tokens, personal-machine paths that tooling (graphify, gitnexus,
// serena, ...) sometimes bakes into a generated/committed file instead of
// resolving at runtime, and gitignored-but-force-staged private files.
//
// The second local layer, not a duplicate of gitleaks: .githooks/pre-commit
// runs gitleaks only when it is installed and silently skips it otherwise, so
// on a machine without it this file is the sole gate before a public push.
// It also catches two classes gitleaks does not — force-added private files,
// and (as of 2026-07-16) every AI-provider key format, which gitleaks 8.30.1's
// default ruleset misses. See .gitleaks.toml.
//
// No dependencies (repo has no package.json / Node project) — stdlib only.
// Run before publishing changes that touch signing or credentials, per
// docs/ENVIRONMENT.md. Checks staged changes by default; --all scans every
// tracked file (useful for a one-off repo-wide sweep).

import { execFileSync } from "node:child_process";
import { readFileSync, statSync } from "node:fs";

const SENSITIVE_EXTENSIONS = [
	".p12",
	".p8",
	".cer",
	".mobileprovision",
	".keystore",
	".jks",
	".pem",
	".key",
	".env",
];

const SENSITIVE_FILENAMES = [
	/^id_rsa$/,
	/^id_ed25519$/,
	/^id_ecdsa$/,
	/^id_dsa$/,
	/^\.env\..+/,
	/^\.netrc$/,
	/^\.npmrc$/,
];

const SECRET_PATTERNS = [
	[/-----BEGIN [A-Z ]*PRIVATE KEY-----/, "PEM private key block"],
	[/AKIA[0-9A-Z]{16}/, "AWS access key ID"],
	[/xox[baprs]-[0-9A-Za-z-]{10,}/, "Slack token"],
	[/-----BEGIN OPENSSH PRIVATE KEY-----/, "OpenSSH private key"],
	// Provider tokens. This is the second layer on purpose: .githooks/pre-commit
	// treats gitleaks as advisory and skips it silently when it is not
	// installed, at which point this file is the only local gate. gitleaks
	// 8.30.1's default ruleset misses every AI-provider format below (verified
	// 2026-07-16), so these are not redundant with it — see .gitleaks.toml.
	[/sk-ant-[a-zA-Z0-9_-]{24,}/, "Anthropic API key"],
	[/sk-proj-[a-zA-Z0-9_-]{40,}/, "OpenAI project API key"],
	[/sk-[a-zA-Z0-9]{48}/, "OpenAI legacy API key"],
	[/hf_[a-zA-Z0-9]{30,}/, "Hugging Face access token"],
	[/gh[pousr]_[A-Za-z0-9]{36,}/, "GitHub token"],
	[/github_pat_[A-Za-z0-9_]{22,}/, "GitHub fine-grained PAT"],
	[/AIza[0-9A-Za-z_-]{35}/, "Google API key"],
	[/glpat-[A-Za-z0-9_-]{20}/, "GitLab personal access token"],
	[/npm_[A-Za-z0-9]{36}/, "npm access token"],
	[/hooks\.slack\.com\/services\/[A-Za-z0-9/+]{20,}/, "Slack webhook URL"],
	// Catches tools (graphify, gitnexus, serena, ...) that bake an absolute,
	// machine-specific path into a generated/committed file instead of
	// resolving it at runtime — a personal-machine leak, not a credential,
	// but still shouldn't ship in a public repo.
	[/\/Users\/[a-zA-Z0-9_.-]+\//, "Hardcoded macOS home-directory path"],
	[/\/home\/[a-zA-Z0-9_.-]+\//, "Hardcoded Linux home-directory path"],
	[/[A-Z]:\\Users\\[a-zA-Z0-9_.-]+\\/, "Hardcoded Windows user-profile path"],
];

const MAX_SCAN_BYTES = 1_000_000;

// Exact paths exempt from the *name-based* check only (contents still get the
// secret-pattern scan). Both are deliberately public: the env template holds
// key names, not values (docs/ENVIRONMENT.md's own guidance is to provide
// one), and website/.npmrc holds dependency-resolution flags
// (engine-strict, legacy-peer-deps) — no registry auth tokens. A real token
// in either would still be caught by SECRET_PATTERNS below.
const NAME_CHECK_EXEMPT = new Set(["website/.env.example", "website/.npmrc"]);

// This file contains the detection patterns as literals, so scanning it
// always self-matches (e.g. the OpenSSH marker). Exempt exactly this path.
const SELF = "tools/check-sensitive-files.mjs";

function gitFiles(all) {
	const args = all
		? ["ls-files"]
		: ["diff", "--name-only", "--cached", "--diff-filter=ACM"];
	const out = execFileSync("git", args, { encoding: "utf8" });
	return out.split("\n").filter(Boolean);
}

// Staged paths that are new to the index (A), not edits to tracked files (M).
// The force-add check below applies only to these — see why there.
function stagedAdditions() {
	const out = execFileSync(
		"git",
		["diff", "--name-only", "--cached", "--diff-filter=A"],
		{ encoding: "utf8" },
	);
	return out.split("\n").filter(Boolean);
}

// Files .gitignore excludes can still reach a commit via `git add -f`, and
// gitignore is the *only* thing protecting the private half of the notes split
// (NOTES.local.md), local settings, and tmp/ + logs/ scratch — none of which the
// content scan below would flag, because machine paths and session state are not
// credentials. Ask git rather than re-encoding .gitignore's rules here: a second
// copy would drift from the first, and negations like `!tmp/README.md` make
// hand-rolled matching wrong in both directions.
//
// Callers MUST pass only newly-added staged paths. Several files here are
// gitignored yet deliberately tracked (GAPS.md, security/THREAT-MODEL.md,
// audits/**) — git honours tracked status over ignore rules, so they are
// legitimate. Checking every staged path would flag each ordinary edit to them
// and block the commit; checking every tracked path (--all) would flag them
// permanently. Only a *new* ignored path in the index implies `git add -f`.
function ignoredButStaged(files) {
	if (files.length === 0) return [];
	try {
		// --no-index is load-bearing: by default check-ignore consults the index
		// and never calls a tracked path ignored. Every path handed to this
		// function is staged (i.e. in the index), so without this flag the check
		// silently matches nothing — which is exactly the `git add -f` case it
		// exists to catch. git's own docs point at --no-index for this.
		const out = execFileSync("git", ["check-ignore", "--no-index", "--stdin"], {
			input: files.join("\n"),
			encoding: "utf8",
		});
		return out.split("\n").filter(Boolean);
	} catch (err) {
		// check-ignore exits 1 when nothing matched — the expected, good path.
		// Anything else is a real failure and must not pass silently.
		if (err.status === 1) return [];
		throw err;
	}
}

function isSensitiveByName(path) {
	const lower = path.toLowerCase();
	if (SENSITIVE_EXTENSIONS.some((ext) => lower.endsWith(ext))) return true;
	const base = path.split("/").pop() ?? path;
	return SENSITIVE_FILENAMES.some((re) => re.test(base));
}

function scanContent(path) {
	let size;
	try {
		size = statSync(path).size;
	} catch {
		return []; // deleted/renamed file, nothing to scan
	}
	if (size > MAX_SCAN_BYTES) return [];

	let text;
	try {
		text = readFileSync(path, "utf8");
	} catch {
		return []; // binary or unreadable — extension check already covers signing formats
	}

	const hits = [];
	for (const [pattern, label] of SECRET_PATTERNS) {
		if (pattern.test(text)) hits.push(label);
	}
	return hits;
}

function main() {
	const all = process.argv.includes("--all");
	const files = gitFiles(all);

	const findings = [];
	// Staged mode only: --all sweeps tracked files, where "ignored but present"
	// is the normal, intended state for GAPS.md / THREAT-MODEL.md / audits/**.
	if (!all) {
		for (const file of ignoredButStaged(stagedAdditions())) {
			findings.push({
				file,
				reason: "gitignored file force-added (`git add -f`) — it is private",
			});
		}
	}
	for (const file of files) {
		if (file === SELF) continue;
		if (!NAME_CHECK_EXEMPT.has(file) && isSensitiveByName(file)) {
			findings.push({ file, reason: "sensitive file extension/name" });
			continue;
		}
		for (const reason of scanContent(file)) {
			findings.push({ file, reason });
		}
	}

	if (findings.length === 0) {
		console.log(`check-sensitive-files: clean (${files.length} file(s) checked).`);
		return;
	}

	console.error("check-sensitive-files: refusing to publish:\n");
	for (const { file, reason } of findings) {
		console.error(`  ${file} — ${reason}`);
	}
	console.error(
		"\nCredentials and signing material belong in the Keychain (on-device) or " +
			"GitHub Actions secrets (CI) — never in the repository; see " +
			"docs/ENVIRONMENT.md. A gitignored file listed above was force-added " +
			"(`git add -f`): it is private by design — unstage it with `git restore " +
			"--staged <file>`. See NOTES.md for the public/private split.",
	);
	process.exitCode = 1;
}

main();
