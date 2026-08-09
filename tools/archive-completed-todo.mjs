#!/usr/bin/env node
// archive-completed-todo.mjs — move TODO.md's "## Completed" section into
// COMPLETED.todo so the working file stays short. TODO.md's own convention
// (see its "Item Completion" note) already appends finished items to
// "## Completed"; this just sweeps that section out periodically. Run by the
// `archive-completed-todo` launchd job every 3 days (see docs/TOOLING.md).
//
// No dependencies — stdlib only, matching the rest of tools/*.mjs.

import { readFileSync, writeFileSync } from "node:fs";

const TODO_PATH = "TODO.md";
const ARCHIVE_PATH = "COMPLETED.todo";
const HEADING = "## Completed";
const PLACEHOLDER = "*Nothing archived since the last sweep — see [`COMPLETED.todo`](COMPLETED.todo) for history.*";

function main() {
	const todo = readFileSync(TODO_PATH, "utf8");
	const headingIndex = todo.indexOf(`${HEADING}\n`);
	if (headingIndex === -1) {
		throw new Error(`${TODO_PATH}: no "${HEADING}" heading found`);
	}
	const contentStart = headingIndex + HEADING.length + 1;

	// A trailing "---" divider, if present, is decorative and stays in TODO.md.
	const trailingRuleMatch = todo.slice(contentStart).match(/\n---\n?$/);
	const contentEnd = trailingRuleMatch
		? contentStart + trailingRuleMatch.index
		: todo.length;

	const body = todo.slice(contentStart, contentEnd).trim();
	if (body.length === 0 || body === PLACEHOLDER) {
		console.log("archive-completed-todo: nothing to archive");
		return;
	}

	// Pacific, not UTC. This repo dates everything in Pacific (session logs are
	// sessions/<YYYY-MM-DD>/<HHMM>-PST.md), and `toISOString()` rolls the date
	// over at 16:00/17:00 local — so an evening sweep used to file itself under
	// tomorrow. `en-CA` is the locale that formats as YYYY-MM-DD.
	const stamp = new Intl.DateTimeFormat("en-CA", {
		timeZone: "America/Los_Angeles",
	}).format(new Date());
	const archive = readFileSync(ARCHIVE_PATH, "utf8");

	// Two sweeps on the same day must land under ONE heading. Appending a second
	// `## Archived <stamp>` is a markdownlint MD024 (no-duplicate-heading)
	// violation, which fails the `docs-links` CI job — so the archive would go
	// from tidy to red without anyone touching a doc. This fired for real on
	// 2026-08-01 and had to be merged by hand.
	//
	// Only the LAST archived heading is compared: entries are appended in
	// chronological order, so a same-day heading can only ever be the final one.
	const headings = [...archive.matchAll(/^## Archived (\d{4}-\d{2}-\d{2})$/gm)];
	const lastStamp = headings.at(-1)?.[1];
	const archiveEntry =
		lastStamp === stamp
			? `\n${body}\n`
			: `\n## Archived ${stamp}\n\n${body}\n`;
	writeFileSync(ARCHIVE_PATH, archive + archiveEntry);

	const rest = todo.slice(contentEnd);
	writeFileSync(TODO_PATH, `${todo.slice(0, contentStart)}\n${PLACEHOLDER}\n${rest}`);

	console.log(`archive-completed-todo: moved ${body.split("\n").length} lines to ${ARCHIVE_PATH}`);
}

main();
