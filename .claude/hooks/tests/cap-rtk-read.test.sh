#!/usr/bin/env bash
# Self-check for cap-rtk-read.sh. Runs the hook against synthetic PreToolUse
# Bash payloads and asserts the `rtk read` clamp/pass-through behavior.
#
# Run: bash .claude/hooks/tests/cap-rtk-read.test.sh
set -uo pipefail

HOOK="$(cd "$(dirname "$0")/.." && pwd)/cap-rtk-read.sh"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
cd "$TMP"

pass=0
fail=0
assert_has() {
  if printf '%s' "$3" | grep -qF -- "$2"; then
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

seq 1 2000 >Big.txt
seq 1 10 >Small.txt
seq 1 2000 >TODO.md

run() {
  printf '{"tool_name":"Bash","tool_input":{"command":"%s"}}' "$1" | bash "$HOOK"
}

out=$(run "rtk read Big.txt")
assert_has "large rtk read gets an updatedInput clamp" '"updatedInput"' "$out"
assert_has "clamp appends --max-lines with the generic cap" '--max-lines 500' "$out"

out=$(run "rtk read TODO.md")
assert_has "rtk read of the queue file uses the tighter queue cap" '--max-lines 120' "$out"

out=$(run "rtk read Small.txt")
assert_silent "small file under threshold is silent" "$out"

out=$(run "rtk read Big.txt -m 50")
assert_silent "explicit -m is left alone" "$out"

out=$(run "rtk read Big.txt --tail-lines 20")
assert_silent "explicit --tail-lines is left alone" "$out"

out=$(run "rtk read Big.txt | head -5")
assert_silent "piped command is skipped, not parsed" "$out"

out=$(run "git status")
assert_silent "non rtk-read command is skipped" "$out"

echo "cap-rtk-read: $pass passed, $fail failed"
[ "$fail" -eq 0 ]
