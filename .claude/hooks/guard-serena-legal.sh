#!/usr/bin/env bash
# PreToolUse hook (matcher: the six Serena mutating tools — replace_content,
# replace_symbol_body, insert_before_symbol, insert_after_symbol,
# safe_delete_symbol, rename_symbol): denies edits under legal/. Mirrors the
# built-in Edit(legal/**) deny rule in settings.json, which only covers the
# built-in Edit tool — Claude Code's permission-rule glob syntax (path
# scoping like Edit(legal/**)) does not extend to MCP tool arguments, so
# Serena's equivalent editing tools needed this hook instead of a settings.json
# rule. CLAUDE.md: never edit legal/ without explicit owner approval.
set -euo pipefail

input=$(cat)
relative_path=$(printf '%s' "$input" | jq -r '.tool_input.relative_path // empty')
[ -n "$relative_path" ] || exit 0

case "$relative_path" in
  legal/*|legal)
    jq -n --arg path "$relative_path" '{hookSpecificOutput: {hookEventName: "PreToolUse", permissionDecision: "deny", permissionDecisionReason: ("Blocked: " + $path + " is under legal/, which CLAUDE.md gates on explicit owner approval for every edit, Serena tools included. Ask the user before touching it.")}}'
    exit 0
    ;;
esac

exit 0
