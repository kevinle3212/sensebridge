import { existsSync, readFileSync, writeFileSync, unlinkSync } from "node:fs";
import { tmpdir } from "node:os";
import { join, dirname } from "node:path";
import { fileURLToPath } from "node:url";
import { spawnSync } from "node:child_process";

const __filename = fileURLToPath(import.meta.url);
const __dirname = dirname(__filename);

// --verbose scans on large diffs can exceed spawnSync's 1 MiB default.
const SPAWN_MAX_BUFFER_BYTES = 16 * 1024 * 1024;

const EDIT_TOOL_NAMES = new Set(["Edit", "Write", "MultiEdit", "NotebookEdit", "ApplyPatch"]);

// The React Doctor gate is scoped to website/ — this repo's only React code —
// in .github/workflows/react-doctor.yml (`paths: ["website/**"]`) and in
// .githooks/pre-push. This hook used to scan from the repo root instead, which
// made it strictly broader than the gate it exists to mirror.
//
// That is not merely redundant, it is actively harmful: `npx impeccable update`
// rewrites five vendored copies of a third-party skill tree, and a root-scoped
// `--scope changed` then reported 60 findings in code this repo does not own
// and cannot fix — the next update overwrites any edit. Every one of those
// findings was injected into the model's context. `npm run lint:md` already
// excludes the same tree (`!**/skills/impeccable/**`) for exactly this reason.
//
// Scoping here restores the documented invariant: the hook, pre-push, and CI
// all check the same thing, so a hook pass and a CI pass mean the same thing.
const GATE_DIRECTORY = "website";

const readFileOrEmpty = (source) => {
  try {
    return readFileSync(source, "utf8");
  } catch {
    return "";
  }
};

// Every path an edit-shaped call in this payload wrote, as far as the payload
// reveals them. Returns null when the shape is unrecognised, which the caller
// treats as "cannot tell" and scans anyway — a guard that goes quiet on an
// unfamiliar payload is worse than one that runs an extra scan.
const editedPaths = (input) => {
  const eventName = input.hook_event_name || input.eventName || input.event_name;
  const calls =
    eventName === "PostToolBatch"
      ? Array.isArray(input.tool_calls)
        ? input.tool_calls
        : null
      : [input];
  if (calls === null) return null;

  const paths = [];
  for (const call of calls) {
    if (!EDIT_TOOL_NAMES.has(call.tool_name || call.toolName || call.tool)) continue;
    const path = call.tool_input?.file_path ?? call.tool_input?.notebook_path;
    if (typeof path !== "string") return null;
    paths.push(path);
  }
  return paths;
};

const shouldScan = (input) => {
  const eventName = input.hook_event_name || input.eventName || input.event_name;
  if (eventName === "PostToolBatch") {
    const toolCalls = Array.isArray(input.tool_calls) ? input.tool_calls : [];
    if (!toolCalls.some((toolCall) => EDIT_TOOL_NAMES.has(toolCall.tool_name))) return false;
  } else {
    const toolName = input.tool_name || input.toolName || input.tool;
    if (toolName && !EDIT_TOOL_NAMES.has(toolName)) return false;
  }

  // Nothing under website/ changed, so there is nothing this gate covers.
  const paths = editedPaths(input);
  if (paths === null) return true;
  return paths.some((path) => path.split(/[\\/]/).includes(GATE_DIRECTORY));
};

// `pnpm dlx`/`npx` resolve an unpinned `@latest` spec by hitting the npm
// registry for the current dist-tag on *every* invocation, even when a
// matching version is already warm in the local store — a network round
// trip this hook otherwise has no reason to pay. Pinning to the version this
// repo already depends on lets both tools serve straight from local cache
// when it's present, while still falling back to `latest` if the package.json
// this pin is read from can't be found or parsed. Same package, same
// behavior — just skippable network I/O in the common case.
const pinnedReactDoctorSpec = (websitePackageJsonPath) => {
  const version = JSON.parse(readFileOrEmpty(websitePackageJsonPath) || "{}")?.devDependencies?.[
    "react-doctor"
  ]?.match(/\d+\.\d+\.\d+/)?.[0];
  return version ? `react-doctor@${version}` : "react-doctor@latest";
};

const runReactDoctor = (outputPath) => {
  // Each candidate is a single shell command string (not an args array):
  // `shell: true` is required to run the Windows `.cmd` shims, and an args
  // array with `shell: true` trips Node's DEP0190. A missing command exits
  // 127 via a POSIX shell (no ENOENT error) and 9009 via cmd.exe, so fall
  // through on those. The local bin is probed with existsSync (its `./`
  // prefix form is not runnable by cmd.exe at all). With no runner found,
  // exit 0 silently — stdout is parsed as the hook's JSON.
  const localBin =
    process.platform === "win32"
      ? "node_modules\\.bin\\react-doctor.cmd"
      : "./node_modules/.bin/react-doctor";
  const flags = "--verbose --scope changed --blocking warning --no-score --no-telemetry";
  const spec = pinnedReactDoctorSpec("package.json");
  const commands = [
    ...(existsSync(localBin) ? [localBin + " " + flags] : []),
    `react-doctor ${flags}`,
    `pnpm dlx ${spec} ${flags}`,
    `npx --yes ${spec} ${flags}`,
  ];

  for (const command of commands) {
    const result = spawnSync(command, {
      encoding: "utf8",
      shell: true,
      maxBuffer: SPAWN_MAX_BUFFER_BYTES,
    });
    if (result.error?.code === "ENOENT" || result.status === 127 || result.status === 9009)
      continue;
    try {
      writeFileSync(outputPath, (result.stdout || "") + (result.stderr || ""));
    } catch {}
    return result.status;
  }

  return 0;
};

const cleanup = (...paths) => {
  for (const path of paths) {
    try {
      unlinkSync(path);
    } catch {}
  }
};

const main = () => {
  let input;
  try {
    input = JSON.parse(readFileOrEmpty(0) || "{}");
  } catch {
    input = {};
  }

  if (!shouldScan(input)) {
    process.exit(0);
  }

  const projectRoot = process.env.CLAUDE_PROJECT_DIR || join(__dirname, "../..");
  const outputPath = join(tmpdir(), `react-doctor-agent-hook-output-${process.pid}.txt`);

  // Scan from website/, matching .githooks/pre-push (which runs the binary
  // with `cd "$REPO_ROOT/website"`) and the workflow's `paths` trigger. This
  // also picks up website/doctor.config.jsonc, whose documented suppressions a
  // root-scoped run silently ignored.
  const gateRoot = join(projectRoot, GATE_DIRECTORY);
  if (!existsSync(gateRoot)) {
    process.exit(0);
  }

  try {
    process.chdir(gateRoot);
  } catch {
    process.exit(0);
  }

  const scanResult = runReactDoctor(outputPath);
  if (scanResult === 0) {
    cleanup(outputPath);
    process.exit(0);
  }

  // The write above is best-effort (unwritable tmpdir), so the read is too
  // — a hook must never crash the agent loop with a stack trace.
  const scanOutput = readFileOrEmpty(outputPath).trim();
  cleanup(outputPath);

  if (!scanOutput) {
    process.exit(0);
  }

  const message = `React Doctor found issues in the changed files. Review this output and fix the regressions before finishing. For confirmed issues that cannot be fixed now, create GitHub issues with the rule, file/line, confidence, impact, and proposed fix.\n\n${scanOutput}`;

  if (input.hook_event_name === "PostToolBatch") {
    console.log(
      JSON.stringify({
        hookSpecificOutput: { hookEventName: "PostToolBatch", additionalContext: message },
      }),
    );
  } else {
    console.log(JSON.stringify({ additional_context: message }));
  }
};

main();
