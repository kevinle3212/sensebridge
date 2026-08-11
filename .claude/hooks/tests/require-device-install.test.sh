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

stamp_edit() {
  jq -nc --arg p "$1" --arg d "$SANDBOX" \
    '{tool_name:"Edit", tool_input:{file_path:$p}, cwd:$d}' \
    | bash "$HOOK" stamp-edit 2>/dev/null
}

# Emits "block" when the Stop hook blocks, "pass" when it stays silent.
verdict() {
  local out
  out=$(jq -nc --arg d "$SANDBOX" '{cwd:$d, stop_hook_active:false}' | bash "$HOOK" 2>/dev/null)
  if [ -z "$out" ]; then printf 'pass'; else printf '%s' "$out" | jq -r '.decision'; fi
}

expect() {
  local want=$1 label=$2 got
  got=$(verdict)
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

# 7. stop_hook_active short-circuits, so a blocked stop can never loop.
loop_out=$(jq -nc --arg d "$SANDBOX" '{cwd:$d, stop_hook_active:true}' | bash "$HOOK" 2>/dev/null)
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
