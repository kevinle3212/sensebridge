#!/usr/bin/env bash
# PreToolUse hook (matcher: Read): nudges toward Serena's symbol tools when
# a `Read` targets a source file Serena has a language server for (see
# `languages:` in `.serena/project.yml` — swift, typescript/js). CLAUDE.md
# says to reach for `find_symbol`/`get_symbols_overview`/
# `find_referencing_symbols` before a raw `Read` on code, but that's a
# judgment call with nothing enforcing it — unlike RTK's Bash hook, which is
# automatic. This is the Serena-side equivalent of that same category of
# hook, scoped to what a bash script can safely judge.
#
# Non-blocking on purpose, mirrors warn-duplicate-read.sh: this hook can't
# know whether a whole-file Read is actually the right call this time (e.g.
# staging exact text for an Edit's old_string, or Serena being unavailable),
# so it never denies — it only adds context once per file per session, on
# reads big enough that a full-file Read is the more expensive option.
set -euo pipefail

MIN_LINES="${CLAUDE_SERENA_NUDGE_MIN_LINES:-80}"

# Clean fallback: never advertise a tool that isn't there. Every message below
# tells the reader to call `mcp__serena__*`; if Serena is not installed, that
# advice costs a wasted turn discovering the tool does not exist, on every
# qualifying Read/Edit/Grep for the whole session. RTK's hook already fails this
# way correctly (`rtkRewrite` returns null and the command is left alone), so
# this is the Serena-side equivalent of that same contract.
#
# `command -v` proves the binary is installed, which is the failure mode this
# catches (fresh clone, new machine, uninstalled tool). It cannot prove the MCP
# server completed its handshake — nothing available to a PreToolUse hook can.
# `announce-tooling.sh` reports the live wiring at session start; this is the
# cheap per-call floor, not a liveness probe.
# Override with CLAUDE_SERENA_NUDGE_ASSUME_AVAILABLE=1 when the binary is
# resolved by something this hook's PATH cannot see.
if [ "${CLAUDE_SERENA_NUDGE_ASSUME_AVAILABLE:-0}" != "1" ]; then
  command -v serena >/dev/null 2>&1 || exit 0
fi

input=$(cat)
file_path=$(printf '%s' "$input" | jq -r '.tool_input.file_path // empty')
limit=$(printf '%s' "$input" | jq -r '.tool_input.limit // empty')
session_id=$(printf '%s' "$input" | jq -r '.session_id // "unknown"')
tool_name=$(printf '%s' "$input" | jq -r '.tool_name // "Read"')

# Grep/Glob carry no file_path, so they need their own (much narrower) test.
# Only nudge when the search is scoped to a language Serena indexes AND the
# pattern is a bare identifier — no regex metacharacters. That combination is
# almost always "find this symbol", which find_symbol and
# find_referencing_symbols answer directly. Any regex, or an unscoped search,
# is text search and is left alone: a nudge that fires on ordinary greps would
# be noise, and noise is what makes the Read/Edit nudges above get ignored.
if [ "$tool_name" = "Grep" ] || [ "$tool_name" = "Glob" ]; then
  pattern=$(printf '%s' "$input" | jq -r '.tool_input.pattern // empty')
  search_glob=$(printf '%s' "$input" | jq -r '.tool_input.glob // .tool_input.pattern // empty')

  [ -z "$pattern" ] && exit 0
  # Bare identifier only: letters, digits, underscore.
  case "$pattern" in
    *[!A-Za-z0-9_]*|"") exit 0 ;;
  esac
  case "$search_glob" in
    *.swift|*.ts|*.tsx|*.js|*.jsx|*.mjs|*.cjs) ;;
    *) exit 0 ;;
  esac

  cache_dir="${TMPDIR:-/tmp}/claude-serena-nudge"
  mkdir -p "$cache_dir"
  cache_file="$cache_dir/${session_id}.txt"
  touch "$cache_file"
  cache_key="${tool_name}	${pattern}"
  grep -qF -- "$cache_key" "$cache_file" 2>/dev/null && exit 0
  printf '%s\n' "$cache_key" >> "$cache_file"

  reason="'${pattern}' is a bare identifier searched inside code Serena indexes. find_symbol locates its definition and find_referencing_symbols lists its call sites, both with the symbol's scope rather than every textual match. Proceeding with ${tool_name} is fine if you want raw text hits (a comment, a string literal, a name in docs)."
  jq -n --arg reason "$reason" \
    '{hookSpecificOutput: {hookEventName: "PreToolUse", permissionDecision: "allow", additionalContext: $reason}}'
  exit 0
fi

[ -z "$file_path" ] && exit 0
[ -f "$file_path" ] || exit 0

# A caller-specified small limit is already a targeted read — nothing to nudge.
if [ "$tool_name" = "Read" ] && [ -n "$limit" ] && [ "$limit" -le 80 ]; then
  exit 0
fi

case "$file_path" in
  *.swift|*.ts|*.tsx|*.js|*.jsx|*.mjs|*.cjs) ;;
  *) exit 0 ;;
esac

total_lines=$(wc -l < "$file_path" 2>/dev/null | tr -d ' ' || true)
[ -z "$total_lines" ] && exit 0
[ "$total_lines" -lt "$MIN_LINES" ] && exit 0

cache_dir="${TMPDIR:-/tmp}/claude-serena-nudge"
mkdir -p "$cache_dir"
cache_file="$cache_dir/${session_id}.txt"
touch "$cache_file"

# Key by tool as well as path: the Read and Edit nudges give different advice,
# so seeing one shouldn't suppress the other for the same file.
cache_key="${tool_name}	${file_path}"
grep -qF -- "$cache_key" "$cache_file" 2>/dev/null && exit 0
printf '%s\n' "$cache_key" >> "$cache_file"

if [ "$tool_name" = "Read" ]; then
  reason="${file_path} has ${total_lines} lines. Before reading it whole, consider Serena: get_symbols_overview for its structure, find_symbol for one symbol's body, find_referencing_symbols for its usages — usually cheaper than this Read. Proceeding with Read is fine if you already need the raw file (e.g. staging exact text for an Edit)."
else
  reason="${file_path} has ${total_lines} lines and is a file Serena indexes. If this edit replaces a whole symbol (function, method, type), replace_symbol_body edits it by name without staging exact text, and rename_symbol updates every reference. Proceeding with ${tool_name} is fine for sub-symbol changes — a single line, an import, a string."
fi

jq -n --arg reason "$reason" \
  '{hookSpecificOutput: {hookEventName: "PreToolUse", permissionDecision: "allow", additionalContext: $reason}}'
