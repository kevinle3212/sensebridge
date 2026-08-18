#!/usr/bin/env node
// Self-check for require-doc-comments.mjs. The two failure modes that would
// make this hook worse than nothing are noise (flagging documented or untouched
// declarations, which trains the reader to skip its output) and silence on a
// genuinely undocumented declaration. Both are pinned below.
//
// Run: node .claude/hooks/global/tests/require-doc-comments.test.mjs

import { execFileSync } from "node:child_process";
import { mkdtempSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";

const HOOK = new URL("../require-doc-comments.mjs", import.meta.url).pathname;
const sandbox = mkdtempSync(join(tmpdir(), "doc-comments-"));
let failures = 0;

/**
 * Writes a file, runs the hook as if that file had just been written, and
 * returns the declarations it reported.
 *
 * @param {string} name File name inside the sandbox; its extension selects the language.
 * @param {string} body Full file contents.
 * @param {string} [written] The text the edit introduced; defaults to the whole body.
 * @returns {string} The hook's additionalContext, empty when it stayed silent.
 */
function report(name, body, written = body) {
  const path = join(sandbox, name);
  writeFileSync(path, body);
  const payload = JSON.stringify({
    tool_name: "Write",
    tool_input: { file_path: path, content: written },
  });
  const out = execFileSync("node", [HOOK], { input: payload, encoding: "utf8" });
  return out === "" ? "" : JSON.parse(out).hookSpecificOutput.additionalContext;
}

/**
 * Asserts whether the hook flagged a case, printing a diff line on mismatch.
 *
 * @param {boolean} shouldFlag Whether the hook is expected to report something.
 * @param {string} label Human-readable case name.
 * @param {string} got The hook's output.
 */
function expect(shouldFlag, label, got) {
  const flagged = got !== "";
  if (flagged !== shouldFlag) {
    console.log(`FAIL  want=${shouldFlag ? "flag" : "silent"} got=${flagged ? "flag" : "silent"}  ${label}`);
    console.log(got.split("\n").slice(4).join("\n"));
    failures += 1;
  }
}

expect(true, "undocumented Swift func", report("A.swift", "func classify() -> Bool { true }\n"));

// Registered in both the project and the user-global settings, so the same
// edit fires this hook twice; the second must stay silent or every code edit
// costs double the context. (Same file, same content, immediately after.)
expect(false, "identical repeat report is suppressed", report("A.swift", "func classify() -> Bool { true }\n"));

// The report is injected into context, so a file with many new declarations
// must not spend one line per declaration.
{
  const many = Array.from({ length: 20 }, (_, i) => `func step${i}() {}`).join("\n") + "\n";
  const out = report("Many.swift", many);
  const listed = out.split("\n").filter((l) => l.includes("Many.swift:")).length;
  if (listed > 8 || !out.includes("and 12 more")) {
    console.log(`FAIL  report cap: listed ${listed} declaration lines, expected 8 plus an overflow note`);
    failures += 1;
  }
}

expect(false, "documented Swift func", report("B.swift", "/// Classifies the current buffer.\nfunc classify() -> Bool { true }\n"));

expect(false, "doc comment separated by an attribute", report("C.swift", "/// Runs on the main actor.\n@MainActor\nfunc render() {}\n"));

expect(true, "undocumented Swift struct and actor", report("D.swift", "struct Alert {}\n\nactor Sensor {}\n"));

expect(false, "block-comment doc above a class", report("E.swift", "/**\n Owns the microphone.\n */\nfinal class MicSource {}\n"));

expect(true, "undocumented exported TS function", report("f.ts", "export function parse(input: string) {\n  return input;\n}\n"));

expect(false, "JSDoc above an exported function", report("g.ts", "/**\n * Parses input.\n * @param {string} input Raw text.\n */\nexport function parse(input) {\n  return input;\n}\n"));

expect(false, "test files are exempt per the Documentation section", report("SettingsTests.swift", "func testSomething() {}\n"));

expect(false, "spec files are exempt", report("h.spec.ts", "export function helper() {}\n"));

expect(false, "non-code files are out of scope", report("README.md", "func classify() {}\n"));

// "Making changes" forbids improving adjacent code, so a declaration the edit
// did not write must never be reported — only the line this call introduced.
expect(
  false,
  "pre-existing undocumented declaration left alone",
  report("I.swift", "func legacy() {}\n\n/// New and documented.\nfunc added() {}\n", "/// New and documented.\nfunc added() {}\n"),
);

rmSync(sandbox, { recursive: true, force: true });

if (failures === 0) {
  console.log("require-doc-comments: all cases pass");
} else {
  console.log(`require-doc-comments: ${failures} failing case(s)`);
  process.exit(1);
}
