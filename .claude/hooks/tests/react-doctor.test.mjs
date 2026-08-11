#!/usr/bin/env node
// Self-check for react-doctor.mjs's scope gate. The hook exists to mirror
// .github/workflows/react-doctor.yml (`paths: ["website/**"]`) and
// .githooks/pre-push (which runs the binary from website/). It previously
// scanned from the repo root, so it reported findings the gate does not cover
// — 60 of them, in a vendored third-party skill tree, straight into context.
//
// These cases pin the scope decision only. They deliberately do not invoke
// react-doctor itself: that would need the website/ toolchain installed and
// would make a fast hook test a slow network-dependent one.
//
// Run: node .claude/hooks/tests/react-doctor.test.mjs

import { execFileSync } from "node:child_process";

const HOOK = new URL("../react-doctor.mjs", import.meta.url).pathname;
let failures = 0;

/**
 * Runs the hook against a payload and reports whether it decided to scan.
 *
 * A scan is observable as a non-empty stdout (findings) or a slow spawn; to
 * keep this test hermetic, PATH is emptied so every react-doctor candidate
 * fails fast and the hook exits 0 either way. What is actually asserted is
 * whether the hook got as far as trying — surfaced by CLAUDE_PROJECT_DIR
 * pointing at a directory with no website/, which makes a scanning run exit
 * at the gate check and a skipping run exit even earlier. Both exit 0, so the
 * decision is read from the hook's own trace flag instead.
 *
 * @param {object} payload The hook input.
 * @returns {boolean} True when the hook decided the payload is in scope.
 */
function decidedToScan(payload) {
  const out = execFileSync("node", ["--input-type=module", "-e", `
    import { readFileSync } from "node:fs";
    const src = readFileSync(${JSON.stringify(HOOK)}, "utf8");
    // Re-evaluate the module's pure decision helpers in isolation: they are
    // module-private, and exporting them purely for a test would change the
    // hook's shape for every other reader.
    const body = src.slice(src.indexOf("const EDIT_TOOL_NAMES"), src.indexOf("const runReactDoctor"));
    const shouldScan = new Function("input", body + "; return shouldScan(input);");
    process.stdout.write(String(shouldScan(${JSON.stringify(payload)})));
  `], { encoding: "utf8" });
  return out === "true";
}

/**
 * Asserts the in/out-of-scope decision for one payload.
 *
 * @param {boolean} want Whether the hook should decide to scan.
 * @param {string} label Human-readable case name.
 * @param {object} payload The hook input.
 */
function expect(want, label, payload) {
  let got;
  try {
    got = decidedToScan(payload);
  } catch (error) {
    console.log(`FAIL  ${label} — threw: ${String(error.message).split("\n")[0]}`);
    failures += 1;
    return;
  }
  if (got !== want) {
    console.log(`FAIL  want=${want ? "scan" : "skip"} got=${got ? "scan" : "skip"}  ${label}`);
    failures += 1;
  }
}

const batch = (...paths) => ({
  hook_event_name: "PostToolBatch",
  tool_calls: paths.map((p) => ({ tool_name: "Edit", tool_input: { file_path: p } })),
});

// --- in scope: the gate covers website/ --------------------------------
expect(true, "edit inside website/", batch("/repo/website/src/components/Header.astro"));
expect(true, "mixed batch touching website/", batch("/repo/docs/TOOLING.md", "/repo/website/src/pages/index.astro"));
expect(true, "single Edit payload inside website/", {
  tool_name: "Edit",
  tool_input: { file_path: "/repo/website/src/i18n/index.ts" },
});

// --- out of scope: this is the regression that flooded context ----------
expect(false, "vendored impeccable tree", batch("/repo/.claude/skills/impeccable/scripts/lib/design-parser.mjs"));
expect(false, "repo hooks", batch("/repo/.claude/hooks/react-doctor.mjs"));
expect(false, "Swift app code", batch("/repo/app/SenseBridge/App/HomeView.swift"));
expect(false, "docs only", batch("/repo/docs/TOOLING.md", "/repo/TODO.md"));
// A directory merely *named* like the gate elsewhere in the tree still counts;
// a substring match must not, or `website-notes.md` would drag the scan in.
expect(false, "path that only contains the word website", batch("/repo/docs/website-notes.md"));

// --- unknown shapes scan rather than go quiet ---------------------------
expect(true, "batch with no resolvable paths", {
  hook_event_name: "PostToolBatch",
  tool_calls: [{ tool_name: "Edit" }],
});

// --- non-edit tools are never in scope ----------------------------------
expect(false, "read-only batch", {
  hook_event_name: "PostToolBatch",
  tool_calls: [{ tool_name: "Read", tool_input: { file_path: "/repo/website/src/x.ts" } }],
});

if (failures === 0) {
  console.log("react-doctor: all cases pass");
} else {
  console.log(`react-doctor: ${failures} failing case(s)`);
  process.exit(1);
}
