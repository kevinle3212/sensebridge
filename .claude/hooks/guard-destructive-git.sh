#!/usr/bin/env bash
# PreToolUse hook (matcher: Bash, if: "Bash(git *)"): denies the highest-risk
# git operations outright — hard resets, force pushes to main/master, and
# force-deleting branches. CLAUDE.md's Git Safety Protocol already says these
# need explicit per-command authorization; this is the technical backstop so
# a bad call can't slip through as a "shortcut past an obstacle."
set -euo pipefail

input=$(cat)
raw_cmd=$(printf '%s' "$input" | jq -r '.tool_input.command // empty')
[ -n "$raw_cmd" ] || exit 0

# Match only the text before the first heredoc introducer ("<<"), so prose
# inside a `git commit -m "$(cat <<'EOF' ... EOF)"` body — e.g. a commit
# message that *describes* `git reset --hard` — can't trip this guard. Real
# invocations of the commands below are never themselves heredoc bodies.
cmd=$(printf '%s' "$raw_cmd" | sed 's/<<.*//')
[ -n "$cmd" ] || exit 0

deny() {
  jq -n --arg reason "$1" '{hookSpecificOutput: {hookEventName: "PreToolUse", permissionDecision: "deny", permissionDecisionReason: $reason}}'
  exit 0
}

if printf '%s' "$cmd" | grep -qE '(^|[;&|[:space:]])git[[:space:]]+reset[[:space:]]+.*--hard'; then
  deny "Blocked: git reset --hard discards uncommitted work irrecoverably. Confirm the exact command with the user first."
fi

if printf '%s' "$cmd" | grep -qE '(^|[;&|[:space:]])git[[:space:]]+push[[:space:]]' \
   && printf '%s' "$cmd" | grep -qE '(^|[[:space:]])(--force([[:space:]]|$)|-f([[:space:]]|$)|--force-with-lease)' \
   && printf '%s' "$cmd" | grep -qE '(^|[/[:space:]])(main|master)([[:space:]]|$)'; then
  deny "Blocked: force-push targeting main/master. CLAUDE.md forbids this without explicit user authorization — it can overwrite upstream history."
fi

if printf '%s' "$cmd" | grep -qE '(^|[;&|[:space:]])git[[:space:]]+branch[[:space:]]+.*-D([[:space:]]|$)'; then
  deny "Blocked: git branch -D force-deletes even an unmerged branch. Use -d, or confirm with the user first."
fi

exit 0
