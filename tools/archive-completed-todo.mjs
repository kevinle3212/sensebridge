#!/usr/bin/env node
// archive-completed-todo.mjs — `tools/sweep-done-todo.mjs` now writes
// finished items straight to COMPLETED.todo, so TODO.md never carries a
// "## Completed" heading in normal operation. This script's `main()` is kept
// only as a defensive backstop for the untracked `archive-completed-todo`
// launchd job (see docs/TOOLING.md) and for any content someone pastes under
// a hand-added "## Completed" heading — it does nothing when that heading is
// absent. `archiveWith` and `pacificDateStamp` are the load-bearing exports:
// sweep-done-todo.mjs imports both to do the day-grouped merge itself.
//
// No dependencies — stdlib only, matching the rest of tools/*.mjs.

import { readFileSync, writeFileSync } from "node:fs";

const TODO_PATH = "TODO.md";
const ARCHIVE_PATH = "COMPLETED.todo";
const HEADING = "## Completed";
const PLACEHOLDER =
  "*Nothing archived since the last sweep — see [`COMPLETED.todo`](COMPLETED.todo) for history.*";

/**
 * Splits a markdown block into the text before its first `###` heading plus one
 * entry per `###` section.
 *
 * @param {string} markdown Block to split.
 * @returns {{preamble: string[], sections: {heading: string, lines: string[]}[]}}
 *   `preamble` is every line before the first `###`; each section carries its
 *   own heading line and the lines beneath it.
 */
function splitSections(markdown) {
  /** @type {string[]} */
  const preamble = [];
  /** @type {{heading: string, lines: string[]}[]} */
  const sections = [];
  let current = null;

  for (const line of markdown.split("\n")) {
    if (line.startsWith("### ")) {
      current = { heading: line, lines: [] };
      sections.push(current);
    } else if (current) {
      current.lines.push(line);
    } else {
      preamble.push(line);
    }
  }
  return { preamble, sections };
}

/** Drops leading and trailing blank lines, leaving interior spacing alone. */
function trimBlankEdges(lines) {
  let start = 0;
  let end = lines.length;
  while (start < end && lines[start].trim() === "") start += 1;
  while (end > start && lines[end - 1].trim() === "") end -= 1;
  return lines.slice(start, end);
}

/** Renders a `splitSections` result back to markdown, one blank line between parts. */
function renderSections(preamble, sections) {
  const parts = [];
  const head = trimBlankEdges(preamble);
  if (head.length > 0) parts.push(head.join("\n"));
  for (const section of sections) {
    parts.push([section.heading, "", ...trimBlankEdges(section.lines)].join("\n"));
  }
  return parts.join("\n\n");
}

/**
 * Folds `body` into a day's existing archive block, merging any `###` section
 * whose heading is already present rather than repeating it.
 *
 * Two sweeps in one day that both archive a section with the same `###` title
 * used to emit that heading twice, which is a markdownlint MD024
 * (no-duplicate-heading) violation and fails the `docs-links` CI job — the
 * archive would go from tidy to red without anyone touching a doc. It happened
 * for real on 2026-08-06 (six duplicate headings) and had to be merged by hand.
 *
 * @param {string} block The existing same-day block, starting at its
 *   `## Archived <date>` heading and running to the end of the file.
 * @param {string} body The freshly-swept content to fold in.
 * @returns {string} The rewritten block.
 */
function mergeSameDayBlock(block, body) {
  const existing = splitSections(block);
  const incoming = splitSections(body);

  for (const section of incoming.sections) {
    const match = existing.sections.find((candidate) => candidate.heading === section.heading);
    if (match) {
      // Same title, second sweep: keep the one heading and append beneath it,
      // so nothing is lost and no duplicate is created.
      match.lines = [...trimBlankEdges(match.lines), "", ...trimBlankEdges(section.lines)];
    } else {
      existing.sections.push(section);
    }
  }

  // Loose content before the first `###` (rare, but possible when a sweep
  // catches a stray bullet) is appended after the day's existing preamble
  // rather than dropped.
  const incomingPreamble = trimBlankEdges(incoming.preamble);
  const preamble =
    incomingPreamble.length > 0
      ? [...trimBlankEdges(existing.preamble), "", ...incomingPreamble]
      : existing.preamble;

  return renderSections(preamble, existing.sections);
}

/**
 * Produces the new `COMPLETED.todo` contents for one sweep.
 *
 * Everything before the day's own heading is passed through byte-for-byte: a
 * first attempt at the merge above rewrote the whole file and corrupted
 * unrelated sections, so the rewrite is deliberately confined to the tail.
 *
 * @param {string} archive Current archive file contents.
 * @param {string} body Swept content to file.
 * @param {string} stamp Date stamp, `YYYY-MM-DD`.
 * @returns {string} The new archive contents.
 */
export function archiveWith(archive, body, stamp) {
  // Only the LAST archived heading is compared: entries are appended in
  // chronological order, so a same-day heading can only ever be the final one.
  const headings = [...archive.matchAll(/^## Archived (\d{4}-\d{2}-\d{2})$/gm)];
  const last = headings.at(-1);

  if (last?.[1] !== stamp) {
    return `${archive}\n## Archived ${stamp}\n\n${body}\n`;
  }

  const blockStart = last.index;
  return `${archive.slice(0, blockStart)}${mergeSameDayBlock(archive.slice(blockStart), body)}\n`;
}

/**
 * Today's date, Pacific time, as `YYYY-MM-DD`.
 *
 * Pacific, not UTC. This repo dates everything in Pacific (session logs are
 * sessions/<YYYY-MM-DD>/<HHMM>-PST.md), and `toISOString()` rolls the date
 * over at 16:00/17:00 local — so an evening sweep used to file itself under
 * tomorrow. `en-CA` is the locale that formats as YYYY-MM-DD.
 *
 * @returns {string} Today's date stamp.
 */
export function pacificDateStamp() {
  return new Intl.DateTimeFormat("en-CA", { timeZone: "America/Los_Angeles" }).format(new Date());
}

/**
 * Runs one sweep: cuts TODO.md's "## Completed" body out, files it under
 * today's heading in COMPLETED.todo, and leaves the placeholder behind.
 *
 * A missing heading is the normal state now that `sweep-done-todo.mjs`
 * writes straight to COMPLETED.todo — this is a no-op, not an error.
 *
 * @returns {void}
 */
function main() {
  const todo = readFileSync(TODO_PATH, "utf8");
  const headingIndex = todo.indexOf(`${HEADING}\n`);
  if (headingIndex === -1) {
    console.log("archive-completed-todo: nothing to archive");
    return;
  }
  const contentStart = headingIndex + HEADING.length + 1;

  // A trailing "---" divider, if present, is decorative and stays in TODO.md.
  const trailingRuleMatch = todo.slice(contentStart).match(/\n---\n?$/);
  const contentEnd = trailingRuleMatch ? contentStart + trailingRuleMatch.index : todo.length;

  const body = todo.slice(contentStart, contentEnd).trim();
  if (body.length === 0 || body === PLACEHOLDER) {
    console.log("archive-completed-todo: nothing to archive");
    return;
  }

  writeFileSync(ARCHIVE_PATH, archiveWith(readFileSync(ARCHIVE_PATH, "utf8"), body, pacificDateStamp()));

  const rest = todo.slice(contentEnd);
  writeFileSync(TODO_PATH, `${todo.slice(0, contentStart)}\n${PLACEHOLDER}\n${rest}`);

  console.log(`archive-completed-todo: moved ${body.split("\n").length} lines to ${ARCHIVE_PATH}`);
}

// Importable for tests without running a sweep — `node tools/archive-completed-todo.mjs`
// still performs one, which is how the launchd job invokes it.
if (process.argv[1]?.endsWith("archive-completed-todo.mjs")) {
  main();
}
