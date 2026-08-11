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

# Git's global options sit between `git` and the subcommand, so `git -C <path>
# commit` contains no literal "git commit" and skipped this guard entirely
# (found 2026-08-10). Fold those options out first so detection sees the
# canonical shape. Only options git accepts before a subcommand are listed, so
# an unrecognised token can never swallow the subcommand itself.
cmd=$(printf '%s' "$cmd" | sed -E \
  's/(^|[;&|(]|[[:space:]])git([[:space:]]+(-C[[:space:]]+[^[:space:]]+|--git-dir[= ][^[:space:]]+|--work-tree[= ][^[:space:]]+|--namespace[= ][^[:space:]]+|-c[[:space:]]+[^[:space:]]+|--no-pager|--bare|--literal-pathspecs|-P))+/\1git/g')

printf '%s' "$cmd" | grep -qE '(^|[;&|[:space:]])git[[:space:]]+commit' || exit 0

# Resolve the repo the command will actually commit *into*. The session's cwd is
# only the default: `git -C <path> commit` and `cd <path> && git commit` both
# retarget it, and reading the branch from cwd regardless produced a false
# denial for real (2026-08-10) — a commit in ~/Vault was refused because
# *sensebridge* happened to be on main. Worktree-aware, so it also beats
# CLAUDE_PROJECT_DIR, which stays pinned to the main checkout.
cwd="$(printf '%s' "$input" | jq -r '.cwd // empty')"
target="${cwd:-${CLAUDE_PROJECT_DIR:-.}}"

# The raw command is re-read here: normalisation above deliberately deleted the
# `-C <path>` this needs, and a `cd` target may legitimately be quoted.
#
# A quote counts as a boundary before `cd`, not just `;`/`&&`/`|`. Anchoring on
# shell operators alone missed `sh -c "cd /repo && git commit"` — the quote
# after `-c` is not an operator, so the target silently fell back to the session
# cwd and the commit was judged against the wrong repo. That is the same false
# denial the `cd` handling was added to fix, reached by a different shape.
git_c_re="git[[:space:]]+-C[[:space:]]+[\"']?([^[:space:]\"']+)"
worktree_re="--work-tree[= ][\"']?([^[:space:]\"']+)"
gitdir_re="--git-dir[= ][\"']?([^[:space:]\"']+)"
cd_re="(^|[;&|(\"'[:space:]])[[:space:]]*cd[[:space:]]+[\"']?([^[:space:];&|\"']+)"

# `--work-tree`/`--git-dir` retarget a commit exactly like `-C` does, but were
# only ever folded out of the *detection* regex above (so the command still
# read as `git commit`), never read for *target resolution* -- so a commit
# routed through them was judged against the session's own cwd instead of the
# repo it actually committed into (found 2026-08-10, same shape as the -C and
# cd false-denial bugs this file already fixes). `--git-dir` alone points at
# the `.git` directory, not the worktree `rev-parse --show-toplevel` needs, so
# a trailing `/.git` is stripped to approximate it.
if [[ $raw_cmd =~ $git_c_re ]]; then
  target="${BASH_REMATCH[1]}"
elif [[ $raw_cmd =~ $worktree_re ]]; then
  target="${BASH_REMATCH[1]}"
elif [[ $raw_cmd =~ $gitdir_re ]]; then
  target="${BASH_REMATCH[1]%/.git}"
elif [[ $raw_cmd =~ $cd_re ]]; then
  target="${BASH_REMATCH[2]}"
fi

# `~` is a shell expansion, not a path component; it never expanded here because
# the value only ever lives in a variable. A relative target resolves against
# the session cwd, matching what the shell would do.
target="${target/#\~/$HOME}"
case "$target" in
  /*) ;;
  *) target="${cwd:-.}/$target" ;;
esac

root="$(git -C "$target" rev-parse --show-toplevel 2>/dev/null || echo "$target")"

branch=$(git -C "$root" branch --show-current 2>/dev/null || true)
[ "$branch" = "main" ] || exit 0

# The repo is named because the denial used to be baffling when the command
# targeted a different one than the session's cwd.
jq -n --arg root "$root" '{hookSpecificOutput: {hookEventName: "PreToolUse", permissionDecision: "deny", permissionDecisionReason: ("HEAD is on main in " + $root + " — never commit to main (CLAUDE.md). Create a feat/, fix/, or chore/ branch there first.")}}'
