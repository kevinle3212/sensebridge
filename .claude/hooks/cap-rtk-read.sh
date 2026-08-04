#!/usr/bin/env bash
# PreToolUse hook (matcher: Bash): clamps `rtk read <file>` the same way
# cap-large-read.sh clamps the native Read tool.
#
# Gap this closes: `Bash(rtk read:*)` is pre-allowlisted in settings.json, and
# cap-large-read.sh is registered only on the Read/MCP-read matchers — never
# on Bash. So `rtk read TODO.md` reached the model at full size, unclamped,
# with zero prompt (found 2026-08-03 auditing the token-saving hook chain).
# rtk read has no offset/pagination, only -m/--max-lines and --tail-lines
# (confirmed via `rtk read --help`, rtk 0.44.1), so this injects --max-lines
# using the same thresholds cap-large-read.sh already uses for Read.
#
# Scope: only a bare `rtk read <file> [flags]` command with no shell
# operators, quoting, or multiple files. A compound or quoted command is rare
# enough that skipping it here (same lazy tradeoff prefer-rtk-shape.mjs makes
# for already-`rtk`-prefixed segments) beats risking a wrong rewrite of a
# shape this hook wasn't built to parse.
#
# Self-check: bash .claude/hooks/tests/cap-rtk-read.test.sh
set -euo pipefail

LARGE_FILE_LINES="${CLAUDE_LARGE_FILE_LINES:-1000}"
MAX_CHUNK_LINES="${CLAUDE_MAX_READ_CHUNK_LINES:-500}"
QUEUE_CHUNK_LINES="${CLAUDE_QUEUE_CHUNK_LINES:-120}"

input=$(cat)
command=$(printf '%s' "$input" | jq -r '.tool_input.command // empty')
[ -z "$command" ] && exit 0

case "$command" in
rtk\ read\ *) ;;
*) exit 0 ;;
esac
# Bail on anything this hook wasn't built to parse: shell operators, quotes,
# command/process substitution.
# shellcheck disable=SC2016 # single quotes are correct here: these are
# literal case-pattern operators to match against, not expressions meant to
# expand.
case "$command" in
*'|'* | *'>'* | *'<'* | *'&&'* | *';'* | *'`'* | *'$('* | *'"'* | *"'"*) exit 0 ;;
esac
# Already has an explicit cap — leave it alone.
case "$command" in
*' -m '* | *' --max-lines'* | *' --tail-lines'*) exit 0 ;;
esac

# First non-flag argument after "rtk read", skipping -l/--level's value.
file_path=$(printf '%s' "$command" | awk '{
  for (i = 3; i <= NF; i++) {
    if ($i == "-l" || $i == "--level") { i++; continue }
    if ($i ~ /^-/) continue
    print $i; exit
  }
}')
[ -z "$file_path" ] && exit 0
[ -f "$file_path" ] || exit 0

total_lines=$(wc -l <"$file_path" 2>/dev/null | tr -d ' ' || true)
[ -z "$total_lines" ] && exit 0
[ "$total_lines" -le "$LARGE_FILE_LINES" ] && exit 0

cap="$MAX_CHUNK_LINES"
case "$(basename "$file_path")" in
TODO.md | COMPLETED.todo) cap="$QUEUE_CHUNK_LINES" ;;
esac

updated_command="${command} --max-lines ${cap}"
reason="${file_path} has ${total_lines} lines — capped this rtk read to ${cap} lines, matching the Read-tool clamp this Bash call would otherwise bypass. Use --tail-lines or a targeted Grep for a different slice."

jq -n --arg cmd "$updated_command" --arg reason "$reason" \
  '{hookSpecificOutput: {hookEventName: "PreToolUse", permissionDecision: "allow", updatedInput: {command: $cmd}, additionalContext: $reason}}'
