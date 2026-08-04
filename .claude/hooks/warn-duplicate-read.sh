#!/usr/bin/env bash
# PreToolUse hook (matcher: Read, mcp__serena__read_file,
# mcp__filesystem__read_text_file): nudges, doesn't block, when the same
# unchanged file region is Read twice in one session.
#
# Non-blocking on purpose: this hook can only see a file path and a session
# id, not whether the earlier read is still visible in context or was
# evicted by compaction. A hard block can't tell those apart, and denying a
# re-read the model genuinely needs (e.g. to recover exact content for an
# Edit) would strand it with no way back. The larger source of redundant
# reads — re-reading a file right after editing it — is already prevented
# natively; Edit/Write tool responses tell the model the file state is
# current, no Read needed. This hook covers the narrower remaining case.
set -euo pipefail

input=$(cat)
# Read uses file_path; the filesystem MCP's read_text_file uses path; Serena's
# read_file uses relative_path. Added 2026-08-03 — those two previously
# bypassed this hook entirely because only file_path was recognized.
file_path=$(printf '%s' "$input" | jq -r '.tool_input.file_path // .tool_input.path // .tool_input.relative_path // empty')
# offset/limit are Read's pagination fields; Serena's read_file uses
# start_line/end_line instead. Good enough for a duplicate-detection key
# either way — it only needs to distinguish "same region" from "different
# region", not to be a chunking parameter.
offset=$(printf '%s' "$input" | jq -r '.tool_input.offset // .tool_input.start_line // "0"')
limit=$(printf '%s' "$input" | jq -r '.tool_input.limit // .tool_input.end_line // "0"')
session_id=$(printf '%s' "$input" | jq -r '.session_id // "unknown"')

[ -z "$file_path" ] && exit 0
[ -f "$file_path" ] || exit 0

if [[ "$(uname)" == "Darwin" ]]; then
  fp="$(stat -f '%m-%z' "$file_path" 2>/dev/null || true)"
else
  fp="$(stat -c '%Y-%s' "$file_path" 2>/dev/null || true)"
fi
[ -z "$fp" ] && exit 0

cache_dir="${TMPDIR:-/tmp}/claude-read-tracker"
mkdir -p "$cache_dir"
cache_file="$cache_dir/${session_id}.txt"
touch "$cache_file"

key="${file_path}|${offset}|${limit}|${fp}"
if grep -qF -- "$key" "$cache_file" 2>/dev/null; then
  reason="Already read ${file_path} (same region, unchanged since) earlier this session — reuse that content instead of re-reading, unless it fell out of context to compaction."
  printf '{"hookSpecificOutput":{"hookEventName":"PreToolUse","additionalContext":"%s"}}\n' "$reason"
else
  printf '%s\n' "$key" >> "$cache_file"
fi
