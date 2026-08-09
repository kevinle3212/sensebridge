#!/usr/bin/env bash
# Self-check for warn-duplicate-read.sh. Runs the hook against synthetic
# PreToolUse payloads and asserts the same-region-twice nudge, including for
# the two MCP read tools it was extended to cover 2026-08-03
# (mcp__serena__read_file, mcp__filesystem__read_text_file).
#
# Run: bash .claude/hooks/tests/warn-duplicate-read.test.sh
set -uo pipefail

HOOK="$(cd "$(dirname "$0")/.." && pwd)/warn-duplicate-read.sh"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

# The hook's per-session cache lives under $TMPDIR — isolate it.
export TMPDIR="$TMP"

pass=0
fail=0
assert_nudge() {
  if printf '%s' "$2" | grep -q 'additionalContext'; then
    pass=$((pass + 1))
  else
    fail=$((fail + 1))
    echo "FAIL: expected a nudge — $1"
  fi
}
assert_silent() {
  if [ -z "$2" ]; then
    pass=$((pass + 1))
  else
    fail=$((fail + 1))
    echo "FAIL: expected silence — $1"
  fi
}

file="$TMP/Doc.txt"
seq 1 50 > "$file"

# --- native Read: same region twice nudges the second time ------------------
first=$(printf '%s' '{"session_id":"s1","tool_name":"Read","tool_input":{"file_path":"'"$file"'"}}' | bash "$HOOK")
second=$(printf '%s' '{"session_id":"s1","tool_name":"Read","tool_input":{"file_path":"'"$file"'"}}' | bash "$HOOK")
assert_silent "first Read of a file is silent" "$first"
assert_nudge "identical second Read nudges" "$second"

# --- mcp__serena__read_file: relative_path, start_line/end_line as the key --
first=$(cd "$TMP" && printf '%s' '{"session_id":"s2","tool_name":"mcp__serena__read_file","tool_input":{"relative_path":"Doc.txt"}}' | bash "$HOOK")
second=$(cd "$TMP" && printf '%s' '{"session_id":"s2","tool_name":"mcp__serena__read_file","tool_input":{"relative_path":"Doc.txt"}}' | bash "$HOOK")
assert_silent "first Serena read_file is silent" "$first"
assert_nudge "identical second Serena read_file nudges" "$second"

# --- mcp__filesystem__read_text_file: path field -----------------------------
first=$(printf '%s' '{"session_id":"s3","tool_name":"mcp__filesystem__read_text_file","tool_input":{"path":"'"$file"'"}}' | bash "$HOOK")
second=$(printf '%s' '{"session_id":"s3","tool_name":"mcp__filesystem__read_text_file","tool_input":{"path":"'"$file"'"}}' | bash "$HOOK")
assert_silent "first filesystem read_text_file is silent" "$first"
assert_nudge "identical second filesystem read_text_file nudges" "$second"

# --- different region (different start_line) does not false-positive -------
a=$(cd "$TMP" && printf '%s' '{"session_id":"s4","tool_name":"mcp__serena__read_file","tool_input":{"relative_path":"Doc.txt","start_line":0}}' | bash "$HOOK")
b=$(cd "$TMP" && printf '%s' '{"session_id":"s4","tool_name":"mcp__serena__read_file","tool_input":{"relative_path":"Doc.txt","start_line":10}}' | bash "$HOOK")
assert_silent "first read at start_line 0 is silent" "$a"
assert_silent "different start_line is a different region, stays silent" "$b"

echo "warn-duplicate-read: $pass passed, $fail failed"
[ "$fail" -eq 0 ]
