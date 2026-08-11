#!/usr/bin/env bash
# Self-check for guard-attribution.sh. This guard exists because a standing
# harness instruction pulls the other way, so the deny side is pinned hard —
# including the heredoc PR-body shape, which every other guard in this directory
# deliberately ignores. The allow side pins that reading or grepping for the
# words is never treated as writing them.
#
# Run: bash .claude/hooks/global/tests/guard-attribution.test.sh
set -uo pipefail

HOOK="$(cd "$(dirname "$0")/.." && pwd)/guard-attribution.sh"
failures=0

verdict() {
  local out
  out=$(jq -nc --arg c "$1" '{tool_name:"Bash", tool_input:{command:$c}}' | bash "$HOOK" 2>/dev/null)
  if [ -z "$out" ]; then printf 'allow'; else
    printf '%s' "$out" | jq -r '.hookSpecificOutput.permissionDecision'
  fi
}

expect() {
  local want=$1 label=$2 cmd=$3 got
  got=$(verdict "$cmd")
  if [ "$got" != "$want" ]; then
    printf 'FAIL  want=%-5s got=%-5s  %s\n' "$want" "$got" "$label"
    failures=$((failures + 1))
  fi
}

# --- must be denied -------------------------------------------------------
expect deny "co-author trailer in a commit" \
  'git commit -m "feat: add sound alerts

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>"'
expect deny "lowercase git-style trailer" \
  'git commit -m "fix: x

Co-authored-by: Claude <noreply@anthropic.com>"'
expect deny "session link trailer" \
  'git commit -m "feat: x

Claude-Session: https://claude.ai/code/session_abc"'
expect deny "generated-with footer in a PR body" \
  'gh pr create --title "feat: x" --body "Does the thing.

🤖 Generated with [Claude Code](https://claude.com/claude-code)"'
expect deny "heredoc PR body, the canonical shape" \
  "gh pr create --title 'feat: x' --body \"\$(cat <<'EOF'
Summary here.

🤖 Generated with [Claude Code](https://claude.com/claude-code)
EOF
)\""
expect deny "rtk-wrapped commit still caught" \
  'rtk git commit -m "feat: x

Co-Authored-By: Claude"'
expect deny "annotated tag" \
  'git tag -a v1.0 -m "release

Co-Authored-By: Claude"'

# --- must stay silent -----------------------------------------------------
expect allow "a clean conventional commit" 'git commit -m "feat(sound-alerts): add the built-in classifier"'
expect allow "a clean PR body" 'gh pr create --title "feat: x" --body "Adds the classifier and its tests."'
expect allow "searching for the string is not writing it" 'rtk grep -rn "Co-Authored-By" .'
expect allow "reading history that may contain one" 'git log --format=%B -5'
expect allow "a non-git command mentioning the words" 'echo "never add Co-Authored-By"'
expect allow "git status is not history-writing" 'git status --porcelain'

if [ "$failures" -eq 0 ]; then
  echo "guard-attribution: all cases pass"
else
  echo "guard-attribution: $failures failing case(s)"
  exit 1
fi
