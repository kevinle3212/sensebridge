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

	const stamp = new Date().toISOString().slice(0, 10);
	const archive = readFileSync(ARCHIVE_PATH, "utf8");
	const archiveEntry = `\n## Archived ${stamp}\n\n${body}\n`;
	writeFileSync(ARCHIVE_PATH, archive + archiveEntry);

	const rest = todo.slice(contentEnd);
	writeFileSync(TODO_PATH, `${todo.slice(0, contentStart)}\n${PLACEHOLDER}\n${rest}`);

	console.log(`archive-completed-todo: moved ${body.split("\n").length} lines to ${ARCHIVE_PATH}`);
}

main();
