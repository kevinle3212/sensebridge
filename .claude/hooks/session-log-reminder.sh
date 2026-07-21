#!/usr/bin/env bash
# Stop hook: if the working tree is dirty but no session log exists for the
# current PST hour bucket, block the stop once so the log (and TODO.md
# follow-ups) get written per CLAUDE.md → "Session logs". Self-silencing:
# once sessions/<date>/<HH00>-PST.md exists, every later stop in that hour
# passes.
set -euo pipefail

input=$(cat)
# never re-block a stop that a Stop hook already continued — prevents loops
[ "$(printf '%s' "$input" | jq -r '.stop_hook_active // false')" = "true" ] && exit 0

root="${CLAUDE_PROJECT_DIR:-.}"
# ponytail: dirty-tree gate is coarse — pre-existing dirt also triggers it;
# tighten to session-modified files if it gets noisy.
git -C "$root" status --porcelain 2>/dev/null | grep -q . || exit 0

bucket="$(TZ=America/Los_Angeles date +%Y-%m-%d)/$(TZ=America/Los_Angeles date +%H)00-PST.md"
[ -f "$root/sessions/$bucket" ] && exit 0

jq -n --arg f "sessions/$bucket" \
  '{decision: "block", reason: ("No session log for this hour yet. Write \($f) (append if the bucket file appears meanwhile) and mirror any outstanding follow-ups into TODO.md, per CLAUDE.md → Session logs. If this session did no substantive work, a one-line entry is fine.")}'
