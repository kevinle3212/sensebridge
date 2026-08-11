#!/usr/bin/env node
// PostToolUse hook (matcher: Edit|Write|MultiEdit): reports declarations that
// the edit just introduced without a doc comment above them, per CLAUDE.md §14
// ("every function, method, class, struct, interface, and attribute/property
// gets a doc comment").
//
// Advisory, never blocking. A PostToolUse hook fires after the write has
// already landed, so there is nothing to deny; the value is that the omission
// is named in the transcript at the moment it happens rather than surviving to
// review. It reports only declarations whose text appears in *this* edit, so an
// untouched legacy file is never dredged up — CLAUDE.md §7 forbids improving
// adjacent code, and a hook that demanded docs on lines the session did not
// write would be pushing exactly that.
//
// ponytail: covers `func`/`class`/`struct`/`enum`/`protocol`/`actor`/`init` and
// the JS/TS equivalents — not stored properties. Telling a Swift stored
// property from a local `let` inside a function body needs real parsing, and
// the false positives from guessing would train the reader to ignore the hook.
// §14's property requirement therefore stays prose; this covers the rest.
// Upgrade path: swap the regex scan for SwiftSyntax / the TS compiler API if
// property coverage ever proves worth the dependency.
//
// Self-check: node .claude/hooks/global/tests/require-doc-comments.test.mjs

import { createHash } from "node:crypto";
import { readFileSync, statSync, utimesSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";

/**
 * Most declarations to name in one report.
 *
 * Everything this hook prints is injected into the model's context, so an edit
 * that adds forty functions must not spend forty lines of context saying so —
 * the first handful plus a count communicates the same thing.
 */
const MAX_REPORTED = 8;

/** Seconds within which an identical report is treated as already delivered. */
const DEDUPE_WINDOW_SECONDS = 60;

/**
 * True when this exact report was already emitted very recently.
 *
 * This hook is registered in both the project and the user-global settings, so
 * a single edit inside this repo fires it twice and would otherwise inject the
 * same list into context twice. Suppressing the repeat costs one stat call and
 * saves the duplicate outright.
 *
 * @param {string} report The context string about to be emitted.
 * @returns {boolean} True when the caller should stay silent.
 */
function alreadyReported(report) {
  const marker = join(tmpdir(), `claude-doccomments-${createHash("sha256").update(report).digest("hex").slice(0, 32)}`);
  try {
    const age = (Date.now() - statSync(marker).mtimeMs) / 1000;
    if (age < DEDUPE_WINDOW_SECONDS) return true;
    utimesSync(marker, new Date(), new Date());
    return false;
  } catch {
    writeFileSync(marker, "");
    return false;
  }
}

/** Declaration keywords worth a doc comment, per language family. */
const DECLARATION_PATTERNS = {
  swift:
    /^[\t ]*(?:(?:public|internal|private|fileprivate|open|final|static|class|mutating|override|nonisolated|indirect|convenience|required)\s+)*(?:func|class|struct|enum|protocol|actor|init|extension|typealias)\b/,
  web: /^[\t ]*(?:export\s+)?(?:default\s+)?(?:declare\s+)?(?:abstract\s+)?(?:async\s+)?(?:function|class|interface|enum|type)\b/,
};

/** Comment openers that count as documentation on the line above a declaration. */
const DOC_LINE = /^[\t ]*(?:\/\/\/|\/\*\*|\*\/|\*|\/\/!|#|@\w)/;

/**
 * Picks the declaration pattern for a path, or null when the file is out of
 * scope — including test files, which CLAUDE.md §14 exempts when their names
 * are self-documenting.
 *
 * @param {string} path Absolute or repo-relative path that was just written.
 * @returns {RegExp|null} The pattern to scan with, or null to skip the file.
 */
function patternFor(path) {
  if (/(?:Tests?|Spec)\.[a-z]+$|\.(?:test|spec)\.[cm]?[jt]sx?$|\/tests?\//i.test(path)) return null;
  if (/\.swift$/.test(path)) return DECLARATION_PATTERNS.swift;
  if (/\.[cm]?[jt]sx?$/.test(path)) return DECLARATION_PATTERNS.web;
  return null;
}

/**
 * Collects the text an Edit/Write/MultiEdit call introduced.
 *
 * Only newly written text is considered, so the scan can be limited to what
 * this session actually authored.
 *
 * @param {object} toolInput The hook payload's `tool_input`.
 * @returns {string} All new text from the call, newline-joined.
 */
function writtenText(toolInput) {
  const parts = [];
  if (typeof toolInput.content === "string") parts.push(toolInput.content);
  if (typeof toolInput.new_string === "string") parts.push(toolInput.new_string);
  for (const edit of toolInput.edits ?? []) {
    if (typeof edit.new_string === "string") parts.push(edit.new_string);
  }
  return parts.join("\n");
}

const payload = JSON.parse(readFileSync(0, "utf8"));
const path = payload.tool_input?.file_path ?? "";
const pattern = patternFor(path);
if (pattern === null) process.exit(0);

const introduced = new Set(
  writtenText(payload.tool_input ?? {})
    .split("\n")
    .map((line) => line.trim())
    .filter((line) => line.length > 0),
);
if (introduced.size === 0) process.exit(0);

let lines;
try {
  lines = readFileSync(path, "utf8").split("\n");
} catch {
  // The file moved or was deleted between the write and this hook. Nothing to
  // report, and a hook that throws here would surface as a spurious error.
  process.exit(0);
}

const undocumented = [];
for (let i = 0; i < lines.length; i += 1) {
  const line = lines[i];
  if (!pattern.test(line)) continue;
  if (!introduced.has(line.trim())) continue;

  // Walk back over blank lines and attribute/decorator lines to find whatever
  // actually precedes the declaration. `@Test`, `@MainActor`, and `@objc` sit
  // between a doc comment and its declaration all the time.
  let j = i - 1;
  while (j >= 0 && (lines[j].trim() === "" || /^[\t ]*@\w/.test(lines[j]))) j -= 1;
  if (j >= 0 && DOC_LINE.test(lines[j])) continue;

  undocumented.push(`${path}:${i + 1}  ${line.trim().slice(0, 90)}`);
}

if (undocumented.length === 0) process.exit(0);

const shown = undocumented.slice(0, MAX_REPORTED);
const overflow = undocumented.length - shown.length;

const context = [
  `CLAUDE.md §14: ${undocumented.length} declaration(s) just written without a doc comment.`,
  "Add one in the idiomatic form for the language (/// or DocC in Swift, JSDoc/TSDoc in JS/TS)",
  "stating what it does, key params/returns, and for non-trivial logic why — do not restate the name.",
  "",
  ...shown,
  ...(overflow > 0 ? [`… and ${overflow} more in the same file.`] : []),
].join("\n");

if (alreadyReported(context)) process.exit(0);

process.stdout.write(
  JSON.stringify({
    hookSpecificOutput: { hookEventName: "PostToolUse", additionalContext: context },
  }),
);
