#!/usr/bin/env node
// sync-skills.mjs — keep the 5 hand-mirrored copies of each shared skill
// byte-identical to their canonical source, so an edit made in one place
// cannot silently drift out of the other four.
//
// Canonical/mirror model: `council` and `website-design` are authored once at
// .claude/skills/<name>/ (canonical) and hand-copied into .agents/skills/<name>/,
// .cursor/skills/<name>/, .gemini/skills/<name>/, and .github/skills/<name>/
// (mirrors), so every harness that reads its own skills/ directory sees the
// same skill. Nothing regenerates the mirrors automatically on its own — a
// human, or this tool, must re-run the copy after every canonical edit.
//
// `impeccable` is also present in all 5 dirs but is OUT OF SCOPE here: it is
// vendor-managed by `npx impeccable install`/`update`, which deliberately
// writes different per-provider content into each dir. Running this tool
// against it would fight that tool instead of cooperating with it.
//
// Two per-harness substitutions are deliberate, not drift — SUBSTITUTION_RULES
// below reproduces them so `--check` does not flag them as mismatches:
//   1. council/SKILL.md links to audit-refresh, which exists only under
//      .claude/skills (it has no mirror of its own). Canonical uses the short
//      same-root path (../audit-refresh/SKILL.md); every mirror needs the long
//      path back through the repo root
//      (../../../.claude/skills/audit-refresh/SKILL.md) because there is no
//      audit-refresh sitting next to the mirror to link to.
//   2. website-design/SKILL.md shows the path to the impeccable skill as link
//      *text*, e.g. "[.claude/skills/impeccable/SKILL.md](../impeccable/SKILL.md)".
//      Each mirror must name its own root in that display text (e.g.
//      ".agents/skills/impeccable/SKILL.md" in the .agents copy) so the text
//      matches where the reader is actually standing, even though the link
//      target itself (../impeccable/SKILL.md) is identical everywhere.
//
// No dependencies (repo has no package.json / Node project) — stdlib only,
// matching tools/check-sensitive-files.mjs.
//
// Usage:
//   node tools/sync-skills.mjs           regenerate every mirror from canonical
//   node tools/sync-skills.mjs --check   verify only, writes nothing; exit 1 on drift

import {
	existsSync,
	mkdirSync,
	readdirSync,
	readFileSync,
	writeFileSync,
} from "node:fs";
import { dirname, join } from "node:path";

const MIRRORED_SKILLS = [
	"council",
	"website-design",
	"seo-schema",
	"seo-technical",
];
const CANONICAL_ROOT = ".claude/skills";
const MIRROR_ROOTS = [".agents", ".cursor", ".gemini", ".github"];

// Data-driven substitutions applied when projecting a canonical file onto a
// mirror. To add a new deliberate per-harness difference, add a rule here —
// never change the logic that applies them.
const SUBSTITUTION_RULES = [
	{
		skill: "council",
		file: "SKILL.md",
		canonicalPattern: "[audit-refresh](../audit-refresh/SKILL.md)",
		mirrorReplacement: () =>
			"[audit-refresh](../../../.claude/skills/audit-refresh/SKILL.md)",
	},
	{
		skill: "website-design",
		file: "SKILL.md",
		canonicalPattern:
			"[.claude/skills/impeccable/SKILL.md](../impeccable/SKILL.md)",
		mirrorReplacement: (mirrorRoot) =>
			`[${mirrorRoot}/skills/impeccable/SKILL.md](../impeccable/SKILL.md)`,
	},
];

// Recursively list files under `dir`, returned as "/"-joined paths relative
// to `dir`, sorted for deterministic output.
function walkFiles(dir, prefix = "") {
	const out = [];
	const entries = readdirSync(dir, { withFileTypes: true }).sort((a, b) =>
		a.name.localeCompare(b.name),
	);
	for (const entry of entries) {
		const relPath = prefix ? `${prefix}/${entry.name}` : entry.name;
		if (entry.isDirectory()) {
			out.push(...walkFiles(join(dir, entry.name), relPath));
		} else if (entry.isFile()) {
			out.push(relPath);
		}
	}
	return out;
}

// Apply every substitution rule that targets this skill/file to canonical
// text, producing the content the mirror at `mirrorRoot` is expected to hold.
// Throws if a rule's pattern is missing from canonical — a stale rule must
// fail loud, not silently stop applying.
function applySubstitutions(canonicalText, skill, file, mirrorRoot) {
	let text = canonicalText;
	for (const rule of SUBSTITUTION_RULES) {
		if (rule.skill !== skill || rule.file !== file) continue;
		if (!text.includes(rule.canonicalPattern)) {
			throw new Error(
				`substitution rule pattern not found in canonical ${CANONICAL_ROOT}/${skill}/${file}: ` +
					`${JSON.stringify(rule.canonicalPattern)} — canonical changed out from under this rule; fix the rule.`,
			);
		}
		text = text.split(rule.canonicalPattern).join(rule.mirrorReplacement(mirrorRoot));
	}
	return text;
}

function main() {
	const check = process.argv.includes("--check");

	const problems = []; // check mode: { path, reason }
	const writes = []; // default mode: { path, action }
	const extras = []; // default mode: mirror paths absent from canonical
	let filesChecked = 0;

	for (const skill of MIRRORED_SKILLS) {
		const canonicalDir = join(CANONICAL_ROOT, skill);
		if (!existsSync(canonicalDir)) {
			throw new Error(`canonical skill directory missing: ${canonicalDir}`);
		}
		const canonicalFiles = walkFiles(canonicalDir);
		const canonicalFileSet = new Set(canonicalFiles);

		for (const mirrorRoot of MIRROR_ROOTS) {
			const mirrorDir = join(mirrorRoot, "skills", skill);

			for (const relPath of canonicalFiles) {
				filesChecked += 1;
				const canonicalText = readFileSync(join(canonicalDir, relPath), "utf8");
				const expectedText = applySubstitutions(canonicalText, skill, relPath, mirrorRoot);
				const mirrorPath = join(mirrorDir, relPath);

				if (check) {
					let actualText;
					try {
						actualText = readFileSync(mirrorPath, "utf8");
					} catch {
						problems.push({ path: mirrorPath, reason: "missing from mirror" });
						continue;
					}
					if (actualText !== expectedText) {
						problems.push({
							path: mirrorPath,
							reason: "content diverges from canonical (after known substitutions)",
						});
					}
					continue;
				}

				const exists = existsSync(mirrorPath);
				const currentText = exists ? readFileSync(mirrorPath, "utf8") : null;
				if (currentText === expectedText) continue;
				mkdirSync(dirname(mirrorPath), { recursive: true });
				writeFileSync(mirrorPath, expectedText, "utf8");
				writes.push({ path: mirrorPath, action: exists ? "updated" : "created" });
			}

			// Report, never delete, files a mirror has that canonical does not —
			// that decision is left to a human.
			if (!check && existsSync(mirrorDir)) {
				for (const relPath of walkFiles(mirrorDir)) {
					if (!canonicalFileSet.has(relPath)) {
						extras.push(join(mirrorDir, relPath));
					}
				}
			}
		}
	}

	if (check) {
		if (problems.length === 0) {
			console.log(
				`sync-skills --check: clean (${filesChecked} file(s) across ${MIRRORED_SKILLS.length} skill(s) x ${MIRROR_ROOTS.length} mirror(s) match canonical).`,
			);
			return;
		}
		console.error("sync-skills --check: mirrors have drifted from canonical:\n");
		for (const { path, reason } of problems) {
			console.error(`  ${path} — ${reason}`);
		}
		console.error("\nRemediation: node tools/sync-skills.mjs");
		process.exitCode = 1;
		return;
	}

	if (writes.length === 0) {
		console.log(`sync-skills: all mirrors already match canonical (${filesChecked} file(s) checked).`);
	} else {
		console.log("sync-skills: wrote:\n");
		for (const { path, action } of writes) {
			console.log(`  ${action} ${path}`);
		}
	}

	if (extras.length > 0) {
		console.log(
			"\nsync-skills: present in a mirror but absent from canonical (not deleted — review by hand):\n",
		);
		for (const path of extras) {
			console.log(`  ${path}`);
		}
	}
}

main();
