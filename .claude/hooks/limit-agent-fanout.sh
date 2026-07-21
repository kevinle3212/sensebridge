#!/usr/bin/env bash
# PreToolUse hook (matcher: Agent): caps Agent-tool spawns (including forks)
# per session to guard against runaway/huge subagent fan-out burning
# tokens. Hard cap, not a warning — unlike re-reads, a blocked Agent call
# has a safe, obvious recovery path (do the work inline, or tell the user
# why more subagents are needed), so blocking is the right default here.
# Override the cap per-session with CLAUDE_AGENT_FANOUT_CAP if a task
# genuinely needs more.
set -euo pipefail

CAP="${CLAUDE_AGENT_FANOUT_CAP:-8}"

input=$(cat)
session_id=$(printf '%s' "$input" | jq -r '.session_id // "unknown"')

cache_dir="${TMPDIR:-/tmp}/claude-agent-fanout"
mkdir -p "$cache_dir"
counter_file="$cache_dir/${session_id}.count"
[ -f "$counter_file" ] || echo 0 > "$counter_file"

count=$(($(cat "$counter_file") + 1))
echo "$count" > "$counter_file"

if [ "$count" -gt "$CAP" ]; then
  reason="Session Agent-call cap (${CAP}) reached (this is call #${count}) — guarding against runaway subagent fan-out. Do the remaining work inline, or tell the user you need more subagents and why before continuing."
  printf '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"deny","permissionDecisionReason":"%s"}}\n' "$reason"
fi
