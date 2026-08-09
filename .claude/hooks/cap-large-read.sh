#!/usr/bin/env bash
# PreToolUse hook (matcher: Read, mcp__serena__read_file,
# mcp__filesystem__read_text_file): caps how much of a LARGE file gets read
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
#
# The `limit` rewrite below is a native-Read-only trick: Read's schema has a
# `limit` field to clamp with. Serena's read_file (start_line/end_line) and
# the filesystem MCP's read_text_file (no pagination field at all) don't, so
# injecting `limit` into their tool_input would be a no-op at best — added 2026-08-03
# to close the gap where those two tools bypassed this hook's file_path lookup
# entirely (only `Read`'s `file_path` was recognized), but the rewrite path
# stays Read-only; the MCP tools get the same advisory `additionalContext`
# with no attempted clamp.
set -euo pipefail

LARGE_FILE_LINES="${CLAUDE_LARGE_FILE_LINES:-1000}"
MAX_CHUNK_LINES="${CLAUDE_MAX_READ_CHUNK_LINES:-500}"
# Queue files are read to answer "what does it say about X", which a Grep for
# the section heading answers in a fraction of the tokens. Measured 2026-08-01:
# TODO.md was the single most expensive file in the whole transcript corpus —
# 264k tokens over 182 reads, and 62% of those reads passed no offset or limit
# at all. The generic 500-line clamp was already firing; it just is not a small
# enough default for a file nobody ever needs sequentially.
QUEUE_CHUNK_LINES="${CLAUDE_QUEUE_CHUNK_LINES:-120}"

input=$(cat)
tool_name=$(printf '%s' "$input" | jq -r '.tool_name // "Read"')
# Read uses file_path; the filesystem MCP's read_text_file uses path; Serena's
# read_file uses relative_path (confirmed against serena/tools/file_tools.py).
file_path=$(printf '%s' "$input" | jq -r '.tool_input.file_path // .tool_input.path // .tool_input.relative_path // empty')
requested_limit=$(printf '%s' "$input" | jq -r '.tool_input.limit // empty')
requested_offset=$(printf '%s' "$input" | jq -r '.tool_input.offset // empty')

[ -z "$file_path" ] && exit 0
[ -f "$file_path" ] || exit 0

total_lines=$(wc -l < "$file_path" 2>/dev/null | tr -d ' ' || true)
[ -z "$total_lines" ] && exit 0
[ "$total_lines" -le "$LARGE_FILE_LINES" ] && exit 0

# A blind read of a queue file — no offset, no limit — is the expensive pattern.
# Clamp it harder than a normal large file and name the cheaper tool, since the
# caller almost always wants one `###` section rather than the first N lines.
# An explicit offset or limit means the caller already knows where to look, so
# it falls through to the ordinary rules below.
case "$(basename "$file_path")" in
TODO.md | COMPLETED.todo)
  if [ -z "$requested_limit" ] && [ -z "$requested_offset" ]; then
    reason="$(basename "$file_path") is a ${total_lines}-line queue file and this ${tool_name} passed no offset or limit. Reading it end to end is the most expensive habit in this repo's transcripts. To find one item, Grep for its '### ' section heading and Read from that line; to see what is open, Grep '^- \[ \]'. Read again with an explicit offset if you genuinely need the next chunk."
    if [ "$tool_name" = "Read" ]; then
      updated_tool_input=$(printf '%s' "$input" |
        jq -c --argjson cap "$QUEUE_CHUNK_LINES" '.tool_input * {limit: $cap}')
      reason="${reason} Capped to ${QUEUE_CHUNK_LINES} lines."
      jq -n --argjson ti "$updated_tool_input" --arg reason "$reason" \
        '{hookSpecificOutput: {hookEventName: "PreToolUse", permissionDecision: "allow", updatedInput: $ti, additionalContext: $reason}}'
    else
      # ${tool_name} has no `limit`-equivalent field this hook can rewrite —
      # advisory only, same as the general-file branch below.
      jq -n --arg reason "$reason" \
        '{hookSpecificOutput: {hookEventName: "PreToolUse", additionalContext: $reason}}'
    fi
    exit 0
  fi
  ;;
esac

if [ -n "$requested_limit" ] && [ "$requested_limit" -le "$MAX_CHUNK_LINES" ]; then
  exit 0
fi

offset=$(printf '%s' "$input" | jq -r '.tool_input.offset // .tool_input.start_line // 0')

if [ "$tool_name" = "Read" ]; then
  updated_tool_input=$(printf '%s' "$input" | jq -c --argjson cap "$MAX_CHUNK_LINES" '.tool_input * {limit: $cap}')
  reason="${file_path} has ${total_lines} lines — capped this read to ${MAX_CHUNK_LINES} lines starting at offset ${offset}. If what you need isn't in this chunk, Read again with a higher offset to keep going."
  jq -n --argjson ti "$updated_tool_input" --arg reason "$reason" \
    '{hookSpecificOutput: {hookEventName: "PreToolUse", permissionDecision: "allow", updatedInput: $ti, additionalContext: $reason}}'
else
  # ${tool_name} has no field this hook can rewrite to clamp the read — advisory only.
  reason="${file_path} has ${total_lines} lines. ${tool_name} has no chunking parameter this hook can clamp — consider a targeted range instead of the whole file."
  jq -n --arg reason "$reason" \
    '{hookSpecificOutput: {hookEventName: "PreToolUse", additionalContext: $reason}}'
fi
