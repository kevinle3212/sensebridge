#!/usr/bin/env bash
# Stop hook: block once when tmp/handoff.md still holds a *finished* plan, so
# it gets emptied (and any leftovers moved to TODO.md) per CLAUDE.md →
# "Durable State — tmp/handoff.md": "When the work is done, empty the file."
#
# A finished plan left in place is stale context that the SessionStart loader
# auto-feeds into the next session, where it reads as live work that never
# happened. That is worse than no plan at all.
#
# The gate is deliberately *not* "handoff.md is non-empty" — a Stop hook fires
# at the end of every assistant turn, and a plan is supposed to be non-empty
# for the whole middle of a task. Blocking on non-empty would fire on every
# turn of normal multi-step work and fight the workflow it is meant to protect.
# Instead it fires only once no unchecked `- [ ]` item remains, which is the
# owner's stated condition: cleared "assuming everything runs and all other
# items are moved to TODO.md already".
#
# ponytail: "no unchecked boxes" is a heuristic — a freeform plan that never
# used checkboxes reads as finished the moment it is written. Tighten to a
# completion marker only if that misfires in practice.
set -euo pipefail

input=$(cat)
# never re-block a stop that a Stop hook already continued — prevents loops
[ "$(printf '%s' "$input" | jq -r '.stop_hook_active // false')" = "true" ] && exit 0

# Resolve the session's actual live working directory (git worktree-aware)
# instead of CLAUDE_PROJECT_DIR, which stays fixed to the main checkout even
# when the session is working in a `.claude/worktrees/*` worktree.
cwd="$(printf '%s' "$input" | jq -r '.cwd // empty')"
root="$(git -C "${cwd:-${CLAUDE_PROJECT_DIR:-.}}" rev-parse --show-toplevel 2>/dev/null || echo "${CLAUDE_PROJECT_DIR:-.}")"

plan="$root/tmp/handoff.md"

# Absent or already zero-byte is the desired end state.
[ -s "$plan" ] || exit 0

# Still-open work: the plan is legitimately holding live state, stay silent.
grep -qE '^[[:space:]]*[-*][[:space:]]+\[[[:space:]]\]' "$plan" && exit 0

jq -n '{decision: "block", reason: "tmp/handoff.md still holds a finished plan (no unchecked items remain). Move anything still outstanding to TODO.md, then truncate the file to zero bytes while keeping it present, per CLAUDE.md → Durable State. A finished plan left in place is auto-loaded into the next session as work that never happened."}'
