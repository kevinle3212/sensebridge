#!/usr/bin/env bash
# PreToolUse hook (matcher: Bash, if: "Bash(git *)"): denies `git commit`
# while HEAD is on main — CLAUDE.md forbids committing to main directly.
set -euo pipefail

input=$(cat)
cmd=$(printf '%s' "$input" | jq -r '.tool_input.command // empty')
printf '%s' "$cmd" | grep -qE '(^|[;&|[:space:]])git[[:space:]]+commit' || exit 0

# Resolve the repo the command will actually run in (git worktree-aware)
# instead of CLAUDE_PROJECT_DIR, which stays fixed to the main checkout even
# when the session is working in a `.claude/worktrees/*` worktree.
cwd="$(printf '%s' "$input" | jq -r '.cwd // empty')"
root="$(git -C "${cwd:-${CLAUDE_PROJECT_DIR:-.}}" rev-parse --show-toplevel 2>/dev/null || echo "${CLAUDE_PROJECT_DIR:-.}")"

branch=$(git -C "$root" branch --show-current 2>/dev/null || true)
[ "$branch" = "main" ] || exit 0

jq -n '{hookSpecificOutput: {hookEventName: "PreToolUse", permissionDecision: "deny", permissionDecisionReason: "HEAD is on main — never commit to main (CLAUDE.md). Create a feat/, fix/, or chore/ branch first."}}'
