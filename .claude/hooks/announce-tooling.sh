#!/usr/bin/env bash
# SessionStart hook: proves Serena and RTK are actually wired for this
# session, since both are otherwise invisible until first used — Serena
# only appears in the transcript once an mcp__serena__* tool is called, and
# RTK's Bash-rewriting hook produces no tool call of its own.
set -euo pipefail

serena_status="not found on PATH"
command -v serena >/dev/null 2>&1 && serena_status="binary found; auto-connects via .mcp.json"

rtk_status="not found on PATH"
if rtk_version=$(rtk --version 2>/dev/null); then
  rtk_status="${rtk_version} · global PreToolUse hook active"
fi

message="Tooling check — Serena: ${serena_status} · RTK: ${rtk_status}"
printf '{"systemMessage":%s}' "$(printf '%s' "$message" | jq -Rs .)"
