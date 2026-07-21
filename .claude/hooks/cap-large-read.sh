#!/usr/bin/env bash
# PreToolUse hook (matcher: Read): caps how much of a LARGE file gets read
# in a single pass. Files above CLAUDE_LARGE_FILE_LINES get their `limit`
# clamped to CLAUDE_MAX_READ_CHUNK_LINES per call (unless the caller already
# asked for less), by rewriting the tool input.
#
# This is a mechanical clamp on volume-per-call, not "did the model find
# what it needed" — that's a semantic judgment only the model can make, and
# no hook can see it. What this DOES enforce is the "keep going if not"
# half of the request: a clamped read still returns a normal, honest Read
# result (fewer lines than the file has), so the model can see it's
# partial and issue a follow-up Read with a higher offset if the answer
# wasn't in this chunk. It just can't pull a huge file in one shot by
# default.
set -euo pipefail

LARGE_FILE_LINES="${CLAUDE_LARGE_FILE_LINES:-1000}"
MAX_CHUNK_LINES="${CLAUDE_MAX_READ_CHUNK_LINES:-500}"

input=$(cat)
file_path=$(printf '%s' "$input" | jq -r '.tool_input.file_path // empty')
requested_limit=$(printf '%s' "$input" | jq -r '.tool_input.limit // empty')

[ -z "$file_path" ] && exit 0
[ -f "$file_path" ] || exit 0

total_lines=$(wc -l < "$file_path" 2>/dev/null | tr -d ' ' || true)
[ -z "$total_lines" ] && exit 0
[ "$total_lines" -le "$LARGE_FILE_LINES" ] && exit 0

if [ -n "$requested_limit" ] && [ "$requested_limit" -le "$MAX_CHUNK_LINES" ]; then
  exit 0
fi

offset=$(printf '%s' "$input" | jq -r '.tool_input.offset // 0')
updated_tool_input=$(printf '%s' "$input" | jq -c --argjson cap "$MAX_CHUNK_LINES" '.tool_input * {limit: $cap}')
reason="${file_path} has ${total_lines} lines — capped this read to ${MAX_CHUNK_LINES} lines starting at offset ${offset}. If what you need isn't in this chunk, Read again with a higher offset to keep going."

jq -n --argjson ti "$updated_tool_input" --arg reason "$reason" \
  '{hookSpecificOutput: {hookEventName: "PreToolUse", permissionDecision: "allow", updatedInput: $ti, additionalContext: $reason}}'
