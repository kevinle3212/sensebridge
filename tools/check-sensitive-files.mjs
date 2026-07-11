#!/usr/bin/env node
// check-sensitive-files.mjs — refuse to publish signing/credential material.
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

const SENSITIVE_FILENAMES = [/^id_rsa$/, /^id_ed25519$/, /^\.env\..+/];

const SECRET_PATTERNS = [
	[/-----BEGIN [A-Z ]*PRIVATE KEY-----/, "PEM private key block"],
	[/AKIA[0-9A-Z]{16}/, "AWS access key ID"],
	[/xox[baprs]-[0-9A-Za-z-]{10,}/, "Slack token"],
	[/-----BEGIN OPENSSH PRIVATE KEY-----/, "OpenSSH private key"],
];

const MAX_SCAN_BYTES = 1_000_000;

function gitFiles(all) {
	const args = all
		? ["ls-files"]
		: ["diff", "--name-only", "--cached", "--diff-filter=ACM"];
	const out = execFileSync("git", args, { encoding: "utf8" });
	return out.split("\n").filter(Boolean);
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
	for (const file of files) {
		if (isSensitiveByName(file)) {
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

	console.error("check-sensitive-files: found signing/credential material:\n");
	for (const { file, reason } of findings) {
		console.error(`  ${file} — ${reason}`);
	}
	console.error(
		"\nKeep signing/credential material in the Keychain (on-device) or GitHub " +
			"Actions secrets (CI) — never in the repository. See docs/ENVIRONMENT.md.",
	);
	process.exitCode = 1;
}

main();
