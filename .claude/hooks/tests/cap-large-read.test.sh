#!/usr/bin/env bash
# Self-check for cap-large-read.sh. Runs the hook against synthetic PreToolUse
# payloads and asserts the clamp/advisory behavior for native Read and for the
# two MCP read tools it was extended to cover 2026-08-03 (mcp__serena__read_file,
# mcp__filesystem__read_text_file).
#
# Run: bash .claude/hooks/tests/cap-large-read.test.sh
set -uo pipefail

HOOK="$(cd "$(dirname "$0")/.." && pwd)/cap-large-read.sh"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

pass=0
fail=0
assert_has() {
  if printf '%s' "$3" | grep -qF "$2"; then
    pass=$((pass + 1))
  else
    fail=$((fail + 1))
    echo "FAIL: expected to find '${2}' — $1"
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

big="$TMP/Big.txt"
seq 1 2000 > "$big"
small="$TMP/Small.txt"
seq 1 10 > "$small"

# --- native Read: unchanged behavior, clamps via updatedInput ---------------
out=$(printf '%s' '{"tool_name":"Read","tool_input":{"file_path":"'"$big"'"}}' | bash "$HOOK")
assert_has "large Read gets an updatedInput clamp" '"updatedInput"' "$out"
assert_has "large Read clamp uses the limit field" '"limit": 500' "$out"

out=$(printf '%s' '{"tool_name":"Read","tool_input":{"file_path":"'"$small"'"}}' | bash "$HOOK")
assert_silent "small file under threshold is silent" "$out"

# --- mcp__serena__read_file: relative_path, advisory only, no updatedInput --
out=$(cd "$TMP" && printf '%s' '{"tool_name":"mcp__serena__read_file","tool_input":{"relative_path":"Big.txt"}}' | bash "$HOOK")
assert_has "Serena read_file of a large file gets additionalContext" 'additionalContext' "$out"
if printf '%s' "$out" | grep -qF '"updatedInput"'; then
  fail=$((fail + 1))
  echo "FAIL: mcp__serena__read_file must not get an updatedInput rewrite (no limit field to rewrite)"
else
  pass=$((pass + 1))
fi

# --- mcp__filesystem__read_text_file: path, advisory only -------------------
out=$(printf '%s' '{"tool_name":"mcp__filesystem__read_text_file","tool_input":{"path":"'"$big"'"}}' | bash "$HOOK")
assert_has "filesystem read_text_file of a large file gets additionalContext" 'additionalContext' "$out"

# --- queue-file (TODO.md) branch, both tool shapes ---------------------------
queue="$TMP/TODO.md"
seq 1 2000 > "$queue"

out=$(printf '%s' '{"tool_name":"Read","tool_input":{"file_path":"'"$queue"'"}}' | bash "$HOOK")
assert_has "queue-file Read clamps to the queue chunk size" '"limit": 120' "$out"

out=$(cd "$TMP" && printf '%s' '{"tool_name":"mcp__serena__read_file","tool_input":{"relative_path":"TODO.md"}}' | bash "$HOOK")
assert_has "queue-file Serena read gets an advisory, no rewrite" 'additionalContext' "$out"
if printf '%s' "$out" | grep -qF '"updatedInput"'; then
  fail=$((fail + 1))
  echo "FAIL: queue-file mcp__serena__read_file must not get an updatedInput rewrite"
else
  pass=$((pass + 1))
fi

echo "cap-large-read: $pass passed, $fail failed"
[ "$fail" -eq 0 ]
