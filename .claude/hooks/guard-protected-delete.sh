#!/usr/bin/env bash
# PreToolUse hook (matcher: Bash): denies delete/discard commands that touch
# paths this repo can never regenerate from git — gitignored logs and
# local-only config with no version-control recovery path, plus paths gated
# on explicit owner approval. Added after `rm -rf sessions` destroyed a
# gitignored session log mid-task with no way to recover it.
set -euo pipefail

input=$(cat)
raw_cmd=$(printf '%s' "$input" | jq -r '.tool_input.command // empty')
[ -n "$raw_cmd" ] || exit 0

# Match only the text before the first heredoc introducer ("<<"), so prose
# inside a `git commit -m "$(cat <<'EOF' ... EOF)"` body — e.g. a commit
# message that *mentions* `rm -rf sessions/` — can't trip this guard. Real
# invocations of the commands below are never themselves heredoc bodies.
cmd=$(printf '%s' "$raw_cmd" | sed 's/<<.*//')
[ -n "$cmd" ] || exit 0

# Only look at commands that can delete or discard files.
printf '%s' "$cmd" | grep -qE '(^|[;&|[:space:]])(rm|rmdir|shred|git[[:space:]]+clean|git[[:space:]]+checkout|git[[:space:]]+restore)([[:space:]]|$)' || exit 0

# sessions/          — gitignored session logs (AGENTS.md#session-logs); no
#                       git history to recover from, as proven the hard way.
# legal/              — owner-approval-gated per CLAUDE.md; never touched
#                       without explicit sign-off, deletion included.
# audits/             — append-only by convention (AGENT-GUIDE.md).
# Config/*.local.xcconfig — gitignored signing config, hand-configured per
#                       machine; regenerating it means re-deriving team IDs.
# NOTES.local.md, .env*   — gitignored local notes/secrets.
# .git/               — the repository itself.
protected='(^|[/[:space:]"'"'"'])(sessions|legal|audits)(/|[[:space:]"'"'"']|$)|Config/[A-Za-z0-9._-]*\.local\.xcconfig|NOTES\.local\.md|(^|[/[:space:]])\.env([.[:space:]"'"'"']|$)|(^|[[:space:]])\.git(/|[[:space:]]|$)'

if printf '%s' "$cmd" | grep -qE "$protected"; then
  jq -n --arg cmd "$cmd" '{hookSpecificOutput: {hookEventName: "PreToolUse", permissionDecision: "deny", permissionDecisionReason: ("Blocked: delete/discard command targets a protected path (sessions/, legal/, audits/, Config/*.local.xcconfig, NOTES.local.md, .env*, or .git/). These are gitignored or owner-gated and cannot be recovered via git. If this is genuinely needed, ask the user to confirm the exact command first. Command: " + $cmd)}}'
  exit 0
fi

exit 0
