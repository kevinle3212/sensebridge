#!/usr/bin/env bash
# PreToolUse hook (matcher: Bash, if: "Bash(git *)"): denies `git commit`
# while HEAD is on main — CLAUDE.md forbids committing to main directly.
set -euo pipefail

input=$(cat)
cmd=$(printf '%s' "$input" | jq -r '.tool_input.command // empty')
printf '%s' "$cmd" | grep -qE '(^|[;&|[:space:]])git[[:space:]]+commit' || exit 0

branch=$(git -C "${CLAUDE_PROJECT_DIR:-.}" branch --show-current 2>/dev/null || true)
[ "$branch" = "main" ] || exit 0

jq -n '{hookSpecificOutput: {hookEventName: "PreToolUse", permissionDecision: "deny", permissionDecisionReason: "HEAD is on main — never commit to main (CLAUDE.md). Create a feat/, fix/, or chore/ branch first."}}'
