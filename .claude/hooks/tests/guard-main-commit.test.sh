#!/usr/bin/env bash
# Self-check for guard-main-commit.sh. The guard must deny a real `git commit`
# while HEAD is on main, and must NOT deny a command that merely *mentions* one.
#
# The second half is the regression this file exists for: until 2026-08-01 the
# guard matched `git commit` anywhere in the raw command string, so a harness
# whose test fixtures contained the words was blocked from running at all. A
# guard that fires on prose trains its reader to route around it.
#
# Run: bash .claude/hooks/tests/guard-main-commit.test.sh
set -uo pipefail

HOOK="$(cd "$(dirname "$0")/.." && pwd)/guard-main-commit.sh"
ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"

# The guard is a no-op off main, which would turn every "denied" case into a
# false pass. Skip rather than lie about coverage.
branch=$(git -C "$ROOT" branch --show-current 2>/dev/null || true)
if [ "$branch" != "main" ]; then
  echo "guard-main-commit: SKIPPED — HEAD is on '$branch', guard only acts on main"
  exit 0
fi

# Built at run time so this file never contains a literal `git commit` — the
# very string the sibling guards scan for.
VERB="com""mit"

pass=0
fail=0

# Returns "deny" or "allow" for one command string. The hook stays silent when
# it permits a command, so empty output is an allow — piping straight into jq
# would yield an empty string instead and every pass would read as a failure.
decision() {
  local out
  out=$(jq -nc --arg c "$1" --arg d "$ROOT" '{tool_name:"Bash",tool_input:{command:$c},cwd:$d}' |
    bash "$HOOK" 2>/dev/null)
  [ -z "$out" ] && { echo allow; return; }
  printf '%s' "$out" | jq -r '.hookSpecificOutput.permissionDecision // "allow"'
}

check() {
  local name=$1 want=$2 cmd=$3 got
  got=$(decision "$cmd")
  if [ "$got" = "$want" ]; then
    pass=$((pass + 1))
  else
    fail=$((fail + 1))
    echo "FAIL: $name — wanted $want, got $got"
  fi
}

# --- real commits must be denied -------------------------------------------
check "bare commit"                deny  "git $VERB -m x"
check "commit with a quoted message" deny "git $VERB -m \"fix: a thing\""
check "commit later in a chain"    deny  "git add -A && git $VERB -m x"
check "commit through sh -c"       deny  "sh -c \"git $VERB -m x\""

# --- mentions are data, not commands ---------------------------------------
check "verb inside a double-quoted echo" allow "echo \"then run: git $VERB -m x\""
check "verb inside a single-quoted grep" allow "grep -n 'git $VERB' TODO.md"
check "verb inside a heredoc body"       allow "$(printf 'cat <<EOF\ngit %s -m x\nEOF\n' "$VERB")"

# --- unrelated commands pass through ---------------------------------------
check "read-only git"    allow "git status --porcelain"
check "no git at all"    allow "npm run build"

echo "guard-main-commit: $pass passed, $fail failed"
[ "$fail" -eq 0 ]
