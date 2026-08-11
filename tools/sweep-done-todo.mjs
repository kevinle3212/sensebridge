#!/usr/bin/env node
/**
 * sweep-done-todo.mjs — move finished items out of TODO.md's dated `## To-Do`
 * sections and into its `## Completed` section, preserving which review or
 * audit each one came from.
 *
 * This is the missing first half of the archive pipeline. TODO.md's own
 * "Item Completion" rule says a finished bullet gets its annotation and is
 * then cut over to `## Completed`, and
 * `tools/archive-completed-todo.mjs` sweeps `## Completed` out to
 * `COMPLETED.todo` every 3 days. Nothing automated the cut in between, so it
 * depended on remembering — and by 2026-07-31 there were 125 ticked items
 * sitting in To-Do while the archive job reported "nothing to archive" on
 * every run. To-Do is supposed to hold only open work; this makes that true
 * mechanically.
 *
 * Sections lose only their ticked bullets. A section whose bullets are *all*
 * ticked moves wholesale — heading and its explanatory preamble included —
 * because that preamble is the record of what produced the items and is
 * meaningless left behind with nothing under it.
 *
 * Run: node tools/sweep-done-todo.mjs [--check]
 *   --check  exit 1 if anything would move, changing nothing (for gates)
 *
 * No dependencies — stdlib only, matching the rest of tools/*.mjs.
 */

import { readFileSync, writeFileSync } from "node:fs";

/** The working TODO file this script rewrites. */
const TODO_PATH = "TODO.md";

/** Heading that opens the region holding open work. */
const TODO_HEADING = "## To-Do";

/** Heading that ends the To-Do region (sections after it are left alone). */
const IN_PROGRESS_HEADING = "## In Progress";

/** Heading that finished items are appended under. */
const COMPLETED_HEADING = "## Completed";

/** Placeholder the archive tool writes when it empties `## Completed`. */
const PLACEHOLDER =
  "*Nothing archived since the last sweep — see [`COMPLETED.todo`](COMPLETED.todo) for history.*";

/** Matches a top-level list item, ticked or not. Indented items are continuations. */
const BULLET = /^- \[([ x])\] /;

/**
 * Splits a dated section's body into its preamble and its top-level bullets.
 *
 * A bullet owns every following line until the next top-level bullet, so its
 * 6-space continuation lines, fenced blocks, and nested `  - [ ]` sub-items
 * travel with it.
 *
 * @param {string[]} lines Section body, excluding the `###` heading itself.
 * @returns {{preamble: string[], bullets: Array<{done: boolean, lines: string[]}>}}
 */
function splitSection(lines) {
  const preamble = [];
  const bullets = [];

  for (const line of lines) {
    const match = BULLET.exec(line);
    if (match !== null) {
      bullets.push({ done: match[1] === "x", lines: [line] });
    } else if (bullets.length > 0) {
      bullets[bullets.length - 1].lines.push(line);
    } else {
      preamble.push(line);
    }
  }

  return { preamble, bullets };
}

/**
 * Splits the To-Do region into its dated `###` sections.
 *
 * @param {string[]} lines The region between `## To-Do` and `## In Progress`.
 * @returns {Array<{heading: string|null, body: string[]}>} Leading loose lines
 *   arrive as one entry with a null heading.
 */
function splitIntoSections(lines) {
  const sections = [{ heading: null, body: [] }];

  for (const line of lines) {
    if (line.startsWith("### ")) {
      sections.push({ heading: line, body: [] });
    } else {
      sections[sections.length - 1].body.push(line);
    }
  }

  return sections;
}

/**
 * Collapses runs of blank lines to one.
 *
 * Both this script and the content it moves are markdownlint-gated (MD012,
 * no-multiple-blanks), and a stray double blank anywhere in the section fails
 * the pre-commit hook. Reflowing costs nothing and means a double blank
 * already sitting in the source cannot be carried through into the output.
 *
 * @param {string[]} lines Any block of lines.
 * @returns {string[]} The same lines with no two consecutive blanks.
 */
function collapseBlanks(lines) {
  return lines.filter(
    (line, index) => line.trim() !== "" || (index > 0 && lines[index - 1].trim() !== ""),
  );
}

/** Drops leading and trailing blank lines without touching interior spacing. */
function trimBlanks(lines) {
  let start = 0;
  let end = lines.length;
  while (start < end && lines[start].trim() === "") start += 1;
  while (end > start && lines[end - 1].trim() === "") end -= 1;
  return lines.slice(start, end);
}

/**
 * Locates a heading's line index, failing loudly rather than silently
 * rewriting a file whose shape has changed underneath this script.
 *
 * @param {string[]} lines Whole-file lines.
 * @param {string} heading Exact heading text to find.
 * @returns {number} Zero-based line index.
 */
function requireHeading(lines, heading) {
  const index = lines.indexOf(heading);
  if (index === -1) {
    throw new Error(`${TODO_PATH}: no "${heading}" heading found`);
  }
  return index;
}

const checkOnly = process.argv.includes("--check");
const original = readFileSync(TODO_PATH, "utf8");
const lines = original.split("\n");

const todoIndex = requireHeading(lines, TODO_HEADING);
const inProgressIndex = requireHeading(lines, IN_PROGRESS_HEADING);
const completedIndex = requireHeading(lines, COMPLETED_HEADING);

if (!(todoIndex < inProgressIndex && inProgressIndex < completedIndex)) {
  throw new Error(`${TODO_PATH}: headings are out of order; refusing to rewrite`);
}

const sections = splitIntoSections(lines.slice(todoIndex + 1, inProgressIndex));

/** Rebuilt To-Do region, holding only sections that still have open work. */
const keptRegion = [];
/** Finished bullets, grouped under the heading of the section they came from. */
const harvested = [];
let movedCount = 0;
let keptCount = 0;

for (const { heading, body } of sections) {
  const { preamble, bullets } = splitSection(body);
  const open = bullets.filter((b) => !b.done);
  const done = bullets.filter((b) => b.done);

  keptCount += open.length;
  movedCount += done.length;

  if (done.length > 0) {
    // Carry the preamble across only when the whole section is retiring;
    // otherwise it stays with the open items it still describes.
    const carriesPreamble = open.length === 0 && heading !== null;
    if (heading !== null) harvested.push(heading, "");
    if (carriesPreamble) {
      const kept = trimBlanks(preamble);
      if (kept.length > 0) harvested.push(...kept, "");
    }
    for (const bullet of done) harvested.push(...trimBlanks(bullet.lines), "");
  }

  if (open.length === 0) continue;

  if (heading !== null) keptRegion.push(heading, "");
  const keptPreamble = trimBlanks(preamble);
  if (keptPreamble.length > 0) keptRegion.push(...keptPreamble, "");
  for (const bullet of open) keptRegion.push(...trimBlanks(bullet.lines), "");
}

if (movedCount === 0) {
  console.log("sweep-done-todo: nothing to sweep (To-Do holds only open items).");
  process.exit(0);
}

if (checkOnly) {
  console.error(
    `sweep-done-todo: ${movedCount} finished item(s) still sit in ${TODO_PATH}'s To-Do region.\n` +
      'Run `npm run todo:sweep` to move them to "## Completed".',
  );
  process.exit(1);
}

// `## In Progress` through the end of file is untouched, except that the
// harvested bullets are spliced in just under `## Completed`.
const tail = lines.slice(inProgressIndex);
const completedOffset = tail.indexOf(COMPLETED_HEADING);
const existingCompleted = trimBlanks(tail.slice(completedOffset + 1)).filter(
  (line) => line !== PLACEHOLDER,
);

/**
 * Splits harvested lines into any leading headingless bullets and the `###`
 * sections that follow.
 *
 * @param {string[]} src Harvested lines, heading-first per section.
 * @returns {{lead: string[], sections: Array<{heading: string, body: string[]}>}}
 */
function splitHarvested(src) {
  const lead = [];
  const sections = [];
  for (const line of src) {
    if (line.startsWith("### ")) sections.push({ heading: line, body: [] });
    else if (sections.length > 0) sections[sections.length - 1].body.push(line);
    else lead.push(line);
  }
  return { lead, sections };
}

// Fold each harvested section into `## Completed` under the heading already
// there, rather than emitting a second copy of it. Sweeping the same section
// twice in one day — which happens whenever a first pass misses an item and a
// second pass catches it — used to produce two identical `###` headings, and
// markdownlint MD024 (no-duplicate-heading) fails the `docs-links` CI job on
// that. A routine bookkeeping command should never be able to redden a build.
// Same defect, same day, as the one fixed in archive-completed-todo.mjs.
const { lead, sections: harvestedSections } = splitHarvested(trimBlanks(harvested));
const mergedCompleted = [...existingCompleted];
const freshSections = [];
for (const section of harvestedSections) {
  const existingAt = mergedCompleted.indexOf(section.heading);
  if (existingAt === -1) {
    freshSections.push(section);
    continue;
  }
  mergedCompleted.splice(existingAt + 1, 0, "", ...trimBlanks(section.body));
}

const harvestedOut = [
  ...lead,
  ...freshSections.flatMap((section) => [section.heading, "", ...trimBlanks(section.body), ""]),
];

const rebuilt = [
  ...lines.slice(0, todoIndex + 1),
  "",
  ...trimBlanks(keptRegion),
  "",
  ...trimBlanks(tail.slice(0, completedOffset)),
  "",
  COMPLETED_HEADING,
  "",
  ...trimBlanks(harvestedOut),
  ...(mergedCompleted.length > 0 ? ["", ...mergedCompleted] : []),
  "",
];

writeFileSync(TODO_PATH, collapseBlanks(rebuilt).join("\n"));
console.log(
  `sweep-done-todo: moved ${movedCount} finished item(s) to "${COMPLETED_HEADING}"; ` +
    `${keptCount} open item(s) remain in To-Do.`,
);
