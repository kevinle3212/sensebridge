#!/usr/bin/env bash
# Self-check for handoff-clear-reminder.sh. The hook's whole value is in *when*
# it stays quiet: a Stop hook that blocked on any non-empty plan would fire on
# every turn of normal multi-step work, so the open-items exemption is the part
# most worth pinning down.
#
# Run: bash .claude/hooks/tests/handoff-clear-reminder.test.sh
set -uo pipefail

HOOK="$(cd "$(dirname "$0")/.." && pwd)/handoff-clear-reminder.sh"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

# The hook falls back to CLAUDE_PROJECT_DIR when cwd is not a git worktree, so
# pointing it at the scratch dir keeps the test off the real repo entirely.
export CLAUDE_PROJECT_DIR="$TMP"
mkdir -p "$TMP/tmp"

# $1 = handoff.md contents ("" means remove the file), $2 = stop_hook_active
run() {
  if [ -z "$1" ]; then
    rm -f "$TMP/tmp/handoff.md"
  else
    printf '%s\n' "$1" > "$TMP/tmp/handoff.md"
  fi
  jq -nc --argjson active "${2:-false}" \
    '{cwd:"", stop_hook_active:$active, hook_event_name:"Stop"}' \
    | bash "$HOOK" 2>/dev/null
}

pass=0
fail=0
assert_block() {
  if printf '%s' "$2" | grep -q '"block"'; then
    pass=$((pass + 1))
  else
    fail=$((fail + 1))
    echo "FAIL: expected a block — $1"
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

# --- desired end state: nothing to nag about -------------------------------
assert_silent "no handoff.md at all" \
  "$(run '')"

: > "$TMP/tmp/handoff.md"
assert_silent "zero-byte handoff.md is exactly what the rule asks for" \
  "$(jq -nc '{cwd:"", stop_hook_active:false}' | bash "$HOOK" 2>/dev/null)"

# --- live plan mid-task: must not fight the workflow -----------------------
assert_silent "plan with an unchecked item is live work" \
  "$(run '# PLAN

- [x] 1. Done thing
- [ ] 2. Still outstanding')"

assert_silent "plan whose only open item uses an asterisk bullet" \
  "$(run '* [ ] outstanding')"

assert_silent "indented unchecked item still counts as open" \
  "$(run '# PLAN

  - [ ] nested open item')"

# --- finished plan: this is the case worth blocking on ---------------------
assert_block "every item checked off" \
  "$(run '# PLAN

- [x] 1. First
- [x] 2. Second')"

assert_block "freeform finished notes with no checkboxes" \
  "$(run 'Everything shipped. Ship commands were handed to the owner.')"

# --- loop guard -------------------------------------------------------------
assert_block "finished plan blocks on a normal stop" \
  "$(run '- [x] done')"

assert_silent "already-continued stop is never re-blocked" \
  "$(run '- [x] done' true)"

echo "handoff-clear-reminder: $pass passed, $fail failed"
[ "$fail" -eq 0 ]
