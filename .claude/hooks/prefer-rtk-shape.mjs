#!/usr/bin/env node
// PreToolUse hook (matcher: Bash): rewrites RTK-covered commands that sit in a
// shape RTK's own hook cannot reach, so `rtk` fires on every call rather than
// only on the shapes RTK happens to match.
//
// RTK's `rtk hook claude` rewrites a command only when the whole line has a
// shape it recognises. Probed directly (rtk 0.44.1, 2026-07-31):
//
//   rewritten      git status / cd x && git status / echo x; npm run build
//   rewritten      git status || true / git status &
//   NOT rewritten  git status | head -5              (pipe)
//   NOT rewritten  git status > out.txt              (redirect)
//   NOT rewritten  for f in a b; do cat $f; done     (loop body)
//   NOT rewritten  echo "$(git status)" / x=$(git status) / `git status`
//   NOT rewritten  ( git status )                    (subshell)
//   NOT rewritten  eval "git status" / bash -c "git status"
//
// The rewrite is all-or-nothing per line: one pipe anywhere and RTK skips the
// entire command, including segments it would otherwise have compacted. This
// hook fills exactly that gap — it acts only on lines RTK declined, so the two
// never both emit `updatedInput` for the same call.
//
// It does NOT hardcode a `cmd -> rtk cmd` table, because RTK's mapping is
// neither identity nor word-level: `cat` and `head` both map to `rtk read`,
// while `git x` is refused and `git status` is accepted — the decision depends
// on the subcommand. So each candidate segment is handed to `rtk hook claude`
// as a synthetic bare command and RTK's own answer is spliced back in. If RTK
// declines a segment, it is left untouched. That keeps correctness with RTK
// and makes an invalid form like `rtk cat` impossible to emit.
//
// TRADEOFF, accepted by the owner 2026-07-31: RTK compaction is lossy, so
// rewriting inside a pipeline, a redirect, or a substitution can change what a
// command produces — `git log | grep foo` greps summarized text, and
// `git diff > patch.diff` writes a patch that will not apply. To opt a call
// out, write it explicitly with `rtk proxy <cmd>`, which executes raw without
// filtering; segments already starting with `rtk` are never touched.
//
// NARROWED 2026-08-01 after that exact footgun fired for real: an away-mode
// backup ran `git diff HEAD > backup.patch`, this hook rewrote it, and RTK
// wrote a 67KB `--stat` summary in place of the 4.7MB diff. The corruption is
// silent — `git apply` only rejects it later, when the restore is needed. The
// opt-out above still stands for every other lossy shape, but "redirect into a
// file whose consumer parses bytes" is now refused outright rather than left to
// the caller to remember: a summarized `.patch`/`.json`/`.lock` is never what
// was wanted, so there is no case where rewriting it is the right call.
//
// FIXED 2026-08-01: heredoc bodies were scanned as command positions, so writing
// a file via `python3 - <<'PY'` whose text contained the literal `git status >
// out.txt` emitted `rtk git status > out.txt` into the generated file. Bodies
// are now blanked before the scan (`maskHeredocs`) — same-length, so offsets
// still index the original command.
//
// Known gap: brace groups (`{ git status; }`) are not scanned. Distinguishing
// a group brace from `${VAR}` and from `find -exec {} \;` costs more than the
// shape is worth — subshell `( … )` covers the realistic case.
//
// Self-check: bash .claude/hooks/tests/prefer-rtk-shape.test.sh

import { execFileSync } from "node:child_process";
import { readFileSync } from "node:fs";

/** Commands whose whole job is to consume a pipeline. Downstream of a pipe
 *  they are the filter, not the leak — and rewriting `| head -5` to
 *  `| rtk read -5` would be actively wrong, since `rtk read` wants a file. */
const CONSUMERS = new Set([
  "head",
  "tail",
  "wc",
  "sed",
  "awk",
  "sort",
  "uniq",
  "cut",
  "tr",
  "jq",
  "less",
  "cat",
  "xargs",
  "tee",
  "column",
  "grep",
  "rg",
]);

/** Extensions whose consumers parse bytes rather than read prose. RTK's
 *  compaction summarizes, so a redirect into one of these yields an artifact
 *  that is corrupt in a way nothing notices until it is used — a patch that
 *  will not apply, a lockfile that will not install, JSON that will not parse. */
/// A trailing write-then-rename suffix does not change what the file is. Found
/// the hard way 2026-08-01: `jq … > .claude/settings.json.new` matched nothing,
/// because only the FINAL extension was tested, so RTK compacted the JSON into
/// a 1.5KB truncation of a 340-line config. Any run of these may follow the real
/// extension — `foo.patch.bak`, `db.sql.tmp`, `out.json.1`.
const TEMP_SUFFIX = String.raw`(?:\.(?:new|tmp|temp|bak|backup|orig|old|part|partial|swp|save|\d+))*`;
const RAW_FIDELITY = new RegExp(
  String.raw`\.(patch|diff|json|jsonl|ndjson|lock|sql|csv|tsv|xml|ya?ml|toml|tar|t?gz|zip|bin|pdf|png|jpe?g|svg|ics|pem|key)` +
    TEMP_SUFFIX +
    "$",
  "i",
);

/** True when the span ending at `end` writes into a raw-fidelity file.
 *  `spanEnd` stops exactly at the redirect operator, so `end` is where to look.
 *  Only output redirects matter — `< in.json` feeds the command, it does not
 *  capture its output. */
function redirectsToRawArtifact(cmd, end) {
  let k = end;
  while (k < cmd.length && (cmd[k] === " " || cmd[k] === "\t")) k++;
  if (!redirectAt(cmd, k)) return false;
  while (k < cmd.length && cmd[k] !== ">" && cmd[k] !== "<") k++;
  if (cmd[k] !== ">") return false;
  while (k < cmd.length && cmd[k] === ">") k++;
  while (k < cmd.length && (cmd[k] === " " || cmd[k] === "\t")) k++;
  let t = k;
  while (t < cmd.length && !" \t|&;\n)".includes(cmd[t])) t++;
  // Quotes and `$VAR` are kept as written; only the trailing extension is read,
  // so `> "$B/backup.patch"` still resolves to `.patch`.
  return RAW_FIDELITY.test(cmd.slice(k, t).replace(/['"]/g, ""));
}

/** Blank out heredoc bodies so their contents never read as command positions.
 *  A heredoc body is data, not shell: `python3 - <<'PY'` whose text contains the
 *  literal `git status > out.txt` was being rewritten to `rtk git status …`
 *  *inside the generated file* (hit for real 2026-08-01). Replacement is
 *  same-length — every offset stays valid for the caller's right-to-left splice
 *  against the original string. Newlines are kept so statement boundaries in the
 *  surrounding command are unaffected. */
function maskHeredocs(cmd) {
  if (!cmd.includes("<<")) return cmd;
  const chars = [...cmd];
  // `<<<` is a here-string with no body; it never matches, since the character
  // after the operator must start a delimiter word.
  const opener = /<<(-?)\s*(['"]?)([A-Za-z_][A-Za-z0-9_-]*)\2/g;
  let m;
  while ((m = opener.exec(cmd)) !== null) {
    const [, dash, , delim] = m;
    const firstNewline = cmd.indexOf("\n", m.index + m[0].length);
    if (firstNewline === -1) break; // no body on this line
    const bodyStart = firstNewline + 1;
    let end = cmd.length;
    for (let lineStart = bodyStart; lineStart <= cmd.length;) {
      let lineEnd = cmd.indexOf("\n", lineStart);
      const atEof = lineEnd === -1;
      if (atEof) lineEnd = cmd.length;
      const line = cmd.slice(lineStart, lineEnd);
      // `<<-` strips leading tabs from the terminator; plain `<<` does not.
      if ((dash ? line.replace(/^\t+/, "") : line).trimEnd() === delim) {
        end = atEof ? cmd.length : lineEnd + 1;
        break;
      }
      if (atEof) break; // unterminated: mask to EOF
      lineStart = lineEnd + 1;
    }
    for (let k = bodyStart; k < end; k++) if (chars[k] !== "\n") chars[k] = " ";
    opener.lastIndex = end; // skip `<<` inside the body
  }
  return chars.join("");
}

/** Words that delegate to another command, so a command word follows them. */
const WRAPPERS = new Set([
  "eval",
  "xargs",
  "time",
  "command",
  "sh",
  "bash",
  "zsh",
  "do",
  "then",
  "else",
  "elif",
  "while",
  "until",
  "if",
  "!",
]);

const QUOTES = new Set(['"', "'"]);
const WORD_BREAK = new Set([
  " ",
  "\t",
  "\n",
  "|",
  "&",
  ";",
  "<",
  ">",
  "(",
  ")",
  "`",
  '"',
  "'",
  "$",
]);

/** True when a redirect operator starts at `k`, including an fd prefix such as
 *  the `2>` in `npm run build 2>&1` — the `2` belongs to the operator, not to
 *  the command, and must not be swallowed into the segment. */
function redirectAt(cmd, k) {
  if (cmd[k] === ">" || cmd[k] === "<") return true;
  let m = k;
  while (m < cmd.length && cmd[m] >= "0" && cmd[m] <= "9") m++;
  return m > k && (cmd[m] === ">" || cmd[m] === "<");
}

/**
 * Walk the command, collecting the span of each command position along with
 * whether it sits directly downstream of a pipe, and whether the line contains
 * any shape RTK declines to rewrite.
 */
function scan(cmd) {
  const positions = [];
  let sawLeak = false;
  let inSingle = false;
  let inDouble = false;
  let expectCommand = true;
  let afterPipe = false;
  let i = 0;

  // End of the command span starting at `from`: the next unquoted operator or
  // redirect. `closer` ends it early for a command that opened inside quotes
  // (`eval "git status"`), whose span stops at the matching quote.
  const spanEnd = (from, closer) => {
    let s = false;
    let d = false;
    for (let k = from; k < cmd.length; k++) {
      const c = cmd[k];
      if (closer && !s && !d && c === closer) return k;
      if (c === "'" && !d) {
        s = !s;
        continue;
      }
      if (c === '"' && !s) {
        d = !d;
        continue;
      }
      if (s || d) continue;
      if ("|&;()`\n".includes(c) || redirectAt(cmd, k)) return k;
    }
    return cmd.length;
  };

  while (i < cmd.length) {
    const c = cmd[i];

    if (c === "'" && !inDouble) {
      if (expectCommand) {
        i++;
        continue;
      } // opening quote of a delegated command
      inSingle = !inSingle;
      i++;
      continue;
    }
    if (c === '"' && !inSingle) {
      if (expectCommand) {
        i++;
        continue;
      }
      inDouble = !inDouble;
      i++;
      continue;
    }
    if (inSingle) {
      i++;
      continue;
    }

    // `${VAR}` is parameter expansion, not a command — skip it whole so its
    // brace never reads as syntax.
    if (c === "$" && cmd[i + 1] === "{") {
      const close = cmd.indexOf("}", i);
      i = close === -1 ? cmd.length : close + 1;
      continue;
    }
    // Command substitution starts a command even inside double quotes.
    if (c === "$" && cmd[i + 1] === "(") {
      sawLeak = true;
      i += 2;
      expectCommand = true;
      afterPipe = false;
      continue;
    }
    if (c === "`") {
      sawLeak = true;
      i++;
      expectCommand = true;
      afterPipe = false;
      continue;
    }
    if (inDouble && !expectCommand) {
      i++;
      continue;
    }

    if (redirectAt(cmd, i)) {
      sawLeak = true;
      while (i < cmd.length && cmd[i] !== ">" && cmd[i] !== "<") i++;
      while (i < cmd.length && (cmd[i] === ">" || cmd[i] === "<")) i++;
      expectCommand = false;
      afterPipe = false;
      continue;
    }
    if (c === "|") {
      if (cmd[i + 1] === "|") {
        i += 2;
        afterPipe = false;
      } // chain, not a pipe
      else {
        i++;
        sawLeak = true;
        afterPipe = true;
      }
      expectCommand = true;
      continue;
    }
    if (c === "&") {
      i += cmd[i + 1] === "&" ? 2 : 1;
      expectCommand = true;
      afterPipe = false;
      continue;
    }
    if (c === "(") {
      sawLeak = true;
      i++;
      expectCommand = true;
      afterPipe = false;
      continue;
    }
    // A newline is a leaking shape. RTK's own hook rewrites only the FIRST line
    // of a multi-line command — `ls -la\ngrep foo src` came back as `rtk ls -la`
    // with `grep` untouched — and rewrites nothing at all when line 1 is a
    // command it does not cover, which is exactly the `cd <abs path>` that
    // opened 72% of this repo's multi-line Bash calls (1,298 of 1,810 measured
    // 2026-08-01). `;` and `&&` do NOT have this problem: RTK rewrites every
    // segment there, so only `\n` sets the flag.
    if (c === "\n") {
      sawLeak = true;
      i++;
      expectCommand = true;
      afterPipe = false;
      continue;
    }
    if (c === ")" || c === ";") {
      i++;
      expectCommand = true;
      afterPipe = false;
      continue;
    }
    if (c === " " || c === "\t") {
      i++;
      continue;
    }

    let j = i;
    while (j < cmd.length && !WORD_BREAK.has(cmd[j])) j++;
    if (j === i) {
      i++;
      continue;
    }
    const word = cmd.slice(i, j);

    if (!expectCommand) {
      i = j;
      continue;
    }

    // `FOO=1 git status` and the `x=` of `x=$(git status)` keep the command
    // position open rather than consuming it.
    if (/^[A-Za-z_][A-Za-z0-9_]*=$|^[A-Za-z_][A-Za-z0-9_]*=\S*$/.test(word)) {
      i = j;
      continue;
    }
    if (word.startsWith("-")) {
      i = j;
      continue;
    } // `-c` of `sh -c`

    const head = word.split("/").pop();
    if (head === "rtk") {
      i = j;
      expectCommand = false;
      continue;
    }
    // A loop body is a shape RTK skips; `for`'s next word is the loop
    // variable, not a command, so the position closes here and reopens at `do`.
    if (head === "for") {
      sawLeak = true;
      i = j;
      expectCommand = false;
      continue;
    }
    if (head === "while" || head === "until") {
      sawLeak = true;
      i = j;
      continue;
    }
    if (WRAPPERS.has(head)) {
      if (head === "eval" || head === "sh" || head === "bash" || head === "zsh") sawLeak = true;
      i = j;
      continue; // command word still to come
    }

    const closer = QUOTES.has(cmd[i - 1]) ? cmd[i - 1] : null;
    positions.push({ start: i, end: spanEnd(i, closer), head, afterPipe });
    expectCommand = false;
    afterPipe = false;
    i = j;
  }

  return { positions, sawLeak };
}

/** Ask RTK what it would make of `segment` on its own. Returns the rewritten
 *  text, or null when RTK declines (or is unavailable). */
function rtkRewrite(segment, cwd) {
  try {
    const out = execFileSync("rtk", ["hook", "claude"], {
      input: JSON.stringify({ tool_name: "Bash", tool_input: { command: segment }, cwd }),
      encoding: "utf8",
      timeout: 3000,
    });
    const next = JSON.parse(out)?.hookSpecificOutput?.updatedInput?.command;
    return typeof next === "string" && next !== segment ? next : null;
  } catch {
    return null;
  }
}

const raw = readFileSync(0, "utf8");
let payload;
try {
  payload = JSON.parse(raw);
} catch {
  process.exit(0);
}
if (payload?.tool_name !== "Bash") process.exit(0);

const command = payload?.tool_input?.command;
if (typeof command !== "string" || command === "") process.exit(0);

// Scan a heredoc-masked copy: same length, so every offset below still indexes
// into the original `command` that gets spliced and re-emitted.
const { positions, sawLeak } = scan(maskHeredocs(command));
// No leaking shape means RTK's own hook already handles this line; acting here
// would duplicate its rewrite.
if (!sawLeak) process.exit(0);

const cwd = payload.cwd || process.cwd();
let result = command;
let changed = 0;

// Right-to-left so each splice leaves earlier offsets valid.
for (const p of [...positions].reverse()) {
  if (p.afterPipe && CONSUMERS.has(p.head)) continue;
  if (redirectsToRawArtifact(command, p.end)) continue;
  const segment = command.slice(p.start, p.end);
  const next = rtkRewrite(segment.trim(), cwd);
  if (!next) continue;
  result = result.slice(0, p.start) + segment.replace(segment.trim(), next) + result.slice(p.end);
  changed++;
}

if (!changed) process.exit(0);

process.stdout.write(
  JSON.stringify({
    hookSpecificOutput: {
      hookEventName: "PreToolUse",
      permissionDecisionReason:
        `RTK shape-gap auto-rewrite: ${changed} command(s) RTK's own hook skipped because the line ` +
        "uses a pipe, redirect, loop, substitution, subshell, or eval. Compaction is lossy — use " +
        "'rtk proxy <cmd>' if this call needs raw output.",
      updatedInput: { command: result },
    },
  }),
);
