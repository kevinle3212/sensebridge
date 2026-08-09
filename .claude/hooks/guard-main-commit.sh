#!/usr/bin/env bash
# PreToolUse hook (matcher: Bash, if: "Bash(git *)"): denies `git commit`
# while HEAD is on main — CLAUDE.md forbids committing to main directly.
set -euo pipefail

input=$(cat)
raw_cmd=$(printf '%s' "$input" | jq -r '.tool_input.command // empty')
[ -n "$raw_cmd" ] || exit 0

# Blank out quoted string literals so DATA cannot read as an executable command:
# `echo "then run: git commit -m x"` documents a commit, it does not make one,
# but the raw-string match denied it as one (hit for real 2026-08-01, blocking a
# test harness whose fixtures merely contained the words). Stripping can only
# remove text from consideration, never invent a denial. A command that executes
# a quoted string is the one place quotes are code, so it opts out and is
# scanned raw. Heredoc bodies are handled by the sibling guard-destructive-git.sh
# convention of cutting at `<<`.
if printf '%s' "$raw_cmd" | grep -qE '(^|[^[:alnum:]_./-])(eval|(sh|bash|zsh)[[:space:]]+-c)([[:space:]]|$)'; then
  # Quotes here wrap code the shell is about to run, so flatten them to spaces
  # rather than stripping their contents: `sh -c "git commit -m x"` must still
  # read as a commit, and the match below anchors on a shell operator or
  # whitespace before `git`, which a bare `"` is not.
  cmd=$(printf '%s' "$raw_cmd" | tr "'\"" '  ')
else
  # Cut at the first heredoc introducer, matching the sibling
  # guard-destructive-git.sh convention: a heredoc body is data being written to
  # a file, and prose describing a commit is not one. This uses parameter
  # expansion rather than `sed 's/<<.*//'` because sed works line by line and so
  # truncates only the `cat <<EOF` line, leaving the body it was meant to remove.
  # Accepted tradeoff: a real commit placed AFTER a heredoc terminator in the
  # same call escapes this guard. That is the same exposure the sibling guard
  # already carries, and commits are separately gated by CLAUDE.md §15 requiring
  # explicit per-command authorization — this hook is a backstop, not the only
  # control.
  cmd=$(printf '%s' "${raw_cmd%%<<*}" | sed -e "s/'[^']*'/ /g" -e 's/"[^"]*"/ /g')
fi

printf '%s' "$cmd" | grep -qE '(^|[;&|[:space:]])git[[:space:]]+commit' || exit 0

# Resolve the repo the command will actually run in (git worktree-aware)
# instead of CLAUDE_PROJECT_DIR, which stays fixed to the main checkout even
# when the session is working in a `.claude/worktrees/*` worktree.
cwd="$(printf '%s' "$input" | jq -r '.cwd // empty')"
root="$(git -C "${cwd:-${CLAUDE_PROJECT_DIR:-.}}" rev-parse --show-toplevel 2>/dev/null || echo "${CLAUDE_PROJECT_DIR:-.}")"

branch=$(git -C "$root" branch --show-current 2>/dev/null || true)
[ "$branch" = "main" ] || exit 0

jq -n '{hookSpecificOutput: {hookEventName: "PreToolUse", permissionDecision: "deny", permissionDecisionReason: "HEAD is on main — never commit to main (CLAUDE.md). Create a feat/, fix/, or chore/ branch first."}}'
