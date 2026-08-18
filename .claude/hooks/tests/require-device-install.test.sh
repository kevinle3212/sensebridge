#!/usr/bin/env bash
# Self-check for require-device-install.sh. The gate is a two-marker comparison,
# so the cases that matter are the four orderings of "did an app/ edit happen"
# against "did an install happen since", plus the path filter that decides
# whether an edit counts at all.
#
# Run: bash .claude/hooks/tests/require-device-install.test.sh
set -uo pipefail

HOOK="$(cd "$(dirname "$0")/.." && pwd)/require-device-install.sh"
failures=0

# A throwaway git repo keeps the real tmp/ markers untouched — this test must
# never make the live session think an install is owed, or clear one that is.
SANDBOX=$(mktemp -d)
trap 'rm -rf "$SANDBOX"' EXIT
git -C "$SANDBOX" init -q
mkdir -p "$SANDBOX/tmp"

# Every helper takes a session id so the concurrency cases below can drive two
# sessions against one sandbox checkout; single-session cases default to "s1".
stamp_edit() {
  jq -nc --arg p "$1" --arg d "$SANDBOX" --arg s "${2:-s1}" \
    '{tool_name:"Edit", tool_input:{file_path:$p}, cwd:$d, session_id:$s}' \
    | bash "$HOOK" stamp-edit 2>/dev/null
}

# Emits "block" when the Stop hook blocks, "pass" when it stays silent.
verdict() {
  local out
  out=$(jq -nc --arg d "$SANDBOX" --arg s "${1:-s1}" \
    '{cwd:$d, stop_hook_active:false, session_id:$s}' | bash "$HOOK" 2>/dev/null)
  if [ -z "$out" ]; then printf 'pass'; else printf '%s' "$out" | jq -r '.decision'; fi
}

expect() {
  local want=$1 label=$2 got
  got=$(verdict "${3:-s1}")
  if [ "$got" != "$want" ]; then
    printf 'FAIL  want=%-5s got=%-5s  %s\n' "$want" "$got" "$label"
    failures=$((failures + 1))
  fi
}

# 1. Nothing has happened — a fresh clone is never blocked.
expect pass "no markers at all"

# 2. A non-Swift edit under app/ does not arm the gate.
stamp_edit "$SANDBOX/app/SenseBridge/Info.plist"
expect pass "app/ plist edit does not arm the gate"

# 3. A Swift edit outside app/ does not arm it either.
stamp_edit "$SANDBOX/tools/helper.swift"
expect pass "Swift edit outside app/ does not arm the gate"

# 4. A Swift edit under app/ arms it.
stamp_edit "$SANDBOX/app/SenseBridge/App/HomeView.swift"
expect block "app/ Swift edit with no install"

# 5. An install after the edit clears it.
sleep 1 && touch "$SANDBOX/tmp/.last-app-install"
expect pass "install newer than the edit"

# 6. A further edit re-arms it.
sleep 1 && stamp_edit "$SANDBOX/app/Packages/Core/Sources/Settings.swift"
expect block "later edit re-arms the gate"

# 7. Regression (2026-08-13): a second session sharing the checkout must not
#    inherit session one's armed gate. One repo-global edit marker used to block
#    every concurrent session, with nothing the blocked session did to clear it.
expect pass "another session's edit does not block this one" s2

# 8. That second session is still gated by its own edits.
stamp_edit "$SANDBOX/app/SenseBridge/Features/Other.swift" s2
expect block "second session blocked by its own edit" s2

# 9. One install clears every session at once — the install marker stays global
#    because an install genuinely installs the whole checkout.
sleep 1 && touch "$SANDBOX/tmp/.last-app-install"
expect pass "install clears session one" s1
expect pass "install clears session two" s2

# 10. stop_hook_active short-circuits, so a blocked stop can never loop. Case 9
#     cleared the gate, so re-arm first — otherwise this passes for the wrong
#     reason and would keep passing if the short-circuit were deleted.
sleep 1 && stamp_edit "$SANDBOX/app/SenseBridge/App/Loop.swift"
expect block "gate re-armed before the loop check"
loop_out=$(jq -nc --arg d "$SANDBOX" '{cwd:$d, stop_hook_active:true, session_id:"s1"}' | bash "$HOOK" 2>/dev/null)
if [ -n "$loop_out" ]; then
  echo "FAIL  stop_hook_active should short-circuit but the hook still blocked"
  failures=$((failures + 1))
fi

if [ "$failures" -eq 0 ]; then
  echo "require-device-install: all cases pass"
else
  echo "require-device-install: $failures failing case(s)"
  exit 1
fi
