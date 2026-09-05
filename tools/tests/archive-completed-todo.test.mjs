#!/usr/bin/env node
// Regression test for the same-day double-sweep bug: two sweeps on one day
// that both archive a section with the same `### ` title used to emit that
// heading twice, which markdownlint rejects as MD024 and which fails the
// `docs-links` CI job. Reproducing it is the point — a plausible-looking merge
// diff was written and reverted once before because it corrupted unrelated
// content, so this asserts both halves: no duplicates, and nothing lost.
//
// Run: node tools/tests/archive-completed-todo.test.mjs

import assert from "node:assert/strict";
import { archiveWith } from "../archive-completed-todo.mjs";

let passed = 0;

/** Runs one named assertion block, tallying it for the summary line. */
function test(name, fn) {
  fn();
  passed += 1;
  console.log(`  ok — ${name}`);
}

/** Counts how many times a `### ` heading appears in `text`. */
function headingCount(text, heading) {
  return text.split("\n").filter((line) => line === heading).length;
}

const STAMP = "2026-08-06";
const EARLIER = [
  "# Completed work",
  "",
  "## Archived 2026-08-01",
  "",
  "### Some older section",
  "",
  "- [x] An older item that must not move.",
  "",
].join("\n");

const SWEEP_ONE = ["### Shared heading", "", "- [x] First sweep item.", ""].join("\n");
const SWEEP_TWO = [
  "### Shared heading",
  "",
  "- [x] Second sweep item.",
  "",
  "### Only in the second sweep",
  "",
  "- [x] A brand new section.",
  "",
].join("\n");

console.log("archive-completed-todo:");

test("a first sweep on a new day opens its own dated heading", () => {
  const result = archiveWith(EARLIER, SWEEP_ONE, STAMP);
  assert.equal(headingCount(result, `## Archived ${STAMP}`), 0 + 1);
  assert.ok(result.includes("- [x] First sweep item."));
});

test("a same-day second sweep does not duplicate a shared ### heading", () => {
  const once = archiveWith(EARLIER, SWEEP_ONE, STAMP);
  const twice = archiveWith(once, SWEEP_TWO, STAMP);

  assert.equal(headingCount(twice, "### Shared heading"), 1, "MD024: heading was duplicated");
  assert.equal(headingCount(twice, `## Archived ${STAMP}`), 1, "day heading was duplicated");
});

test("both sweeps' content survives the merge", () => {
  const twice = archiveWith(archiveWith(EARLIER, SWEEP_ONE, STAMP), SWEEP_TWO, STAMP);

  assert.ok(twice.includes("- [x] First sweep item."), "first sweep's item was lost");
  assert.ok(twice.includes("- [x] Second sweep item."), "second sweep's item was lost");
  assert.ok(twice.includes("### Only in the second sweep"), "new section was dropped");
  assert.ok(twice.includes("- [x] A brand new section."));
});

test("content above the day's heading is byte-identical", () => {
  // The reverted first attempt failed exactly here: it rewrote the whole file
  // and damaged sections it had no business touching.
  const twice = archiveWith(archiveWith(EARLIER, SWEEP_ONE, STAMP), SWEEP_TWO, STAMP);
  const untouched = EARLIER.slice(0, EARLIER.indexOf("## Archived 2026-08-01"));

  assert.equal(twice.slice(0, untouched.length), untouched);
  assert.ok(twice.includes("### Some older section"));
  assert.ok(twice.includes("- [x] An older item that must not move."));
  assert.equal(headingCount(twice, "## Archived 2026-08-01"), 1);
});

test("a sweep on a later day starts a fresh heading instead of merging", () => {
  const once = archiveWith(EARLIER, SWEEP_ONE, STAMP);
  const nextDay = archiveWith(once, SWEEP_TWO, "2026-08-07");

  assert.equal(headingCount(nextDay, `## Archived ${STAMP}`), 1);
  assert.equal(headingCount(nextDay, "## Archived 2026-08-07"), 1);
  // A repeated title under a *different* day heading is not an MD024 problem
  // and must stay separate — merging across days would rewrite history.
  assert.equal(headingCount(nextDay, "### Shared heading"), 2);
});

test("three sweeps in one day still produce one heading", () => {
  const thrice = archiveWith(
    archiveWith(archiveWith(EARLIER, SWEEP_ONE, STAMP), SWEEP_TWO, STAMP),
    SWEEP_ONE,
    STAMP,
  );

  assert.equal(headingCount(thrice, "### Shared heading"), 1);
  assert.equal(headingCount(thrice, "### Only in the second sweep"), 1);
});

console.log(`archive-completed-todo: ${passed} passed, 0 failed`);
