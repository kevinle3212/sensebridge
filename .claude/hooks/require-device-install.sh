#!/usr/bin/env bash
# Two-mode hook enforcing CLAUDE.md → "Hand it back testable": after any change
# to `app/` code, the app is rebuilt for the device and installed before the
# turn is reported done. A change the owner cannot try on the phone is not
# finished, and a simulator build proves nothing here — ARKit, LiDAR depth,
# Apple Intelligence, haptics, and the camera all produce nothing in a simulator.
#
#   stamp-edit  PostToolUse(Edit|Write|MultiEdit) — records that app/ code changed
#   (no arg)    Stop — blocks once when the last app/ edit postdates the last install
#
# The install side of the pair is stamped by `scripts/app.sh install` itself, on
# success only, so a failed install never satisfies the gate.
#
# Why markers rather than reading `git status`: a dirty tree carries edits from
# earlier sessions that were already installed (or already abandoned), so a
# status-based gate would block every stop forever with nothing the session did
# to clear it. A fresh clone starts with no markers and so is never blocked
# spuriously.
#
# Why the edit marker is keyed by session: two sessions open on the same
# checkout share one `tmp/`. A single repo-global edit marker therefore let
# session A's Swift edit block session B's stop, with nothing B did to clear it
# and no `app/*.swift` file B could point at — observed 2026-08-13, and the
# reason a doc-only session was blocked three times running. The install marker
# stays global on purpose: an install genuinely installs the whole checkout, so
# whoever runs it clears the gate for every session at once.
#
# Why `stamp-edit` does not check whether the edit succeeded: PostToolUse fires
# only when the tool actually succeeded, so a failed edit never reaches this
# hook. Verified 2026-08-13 by capturing this hook's own stdin across three
# failure modes — `Edit` with a non-matching `old_string`, `Edit` on a missing
# file, and a `Write` that hit `EACCES` — none of which produced an event at
# all. A successful payload carries no status field to test either way
# (`tool_response` is `{filePath, structuredPatch, originalFile, userModified,
# …}`), so a success guard here would be unreachable code guarding nothing.
# Do not add one; re-verify by the same method if the harness ever changes.
#
# Self-check: bash .claude/hooks/tests/require-device-install.test.sh
set -euo pipefail

input=$(cat)

# Resolve the session's live working directory (git worktree-aware) rather than
# CLAUDE_PROJECT_DIR, which stays pinned to the main checkout — matching the
# convention in guard-main-commit.sh and session-log-reminder.sh.
cwd="$(printf '%s' "$input" | jq -r '.cwd // empty')"
root="$(git -C "${cwd:-${CLAUDE_PROJECT_DIR:-.}}" rev-parse --show-toplevel 2>/dev/null || echo "${CLAUDE_PROJECT_DIR:-.}")"

# Strip anything that is not filename-safe: the id lands in a path, and an
# absent id must not silently collapse two sessions into a shared marker.
session="$(printf '%s' "$input" | jq -r '.session_id // empty' | tr -cd 'A-Za-z0-9_-')"
[ -n "$session" ] || session="unknown"

edit_marker="$root/tmp/.last-app-edit-$session"
install_marker="$root/tmp/.last-app-install"

if [ "${1:-}" = "stamp-edit" ]; then
  # `notebook_path` is deliberately not consulted: NotebookEdit is not in this
  # hook's matcher, and a notebook path could never satisfy the `.swift` filter
  # below even if it were.
  path="$(printf '%s' "$input" | jq -r '.tool_input.file_path // empty')"
  [ -n "$path" ] || exit 0
  # Only Swift sources gate the install. Asset catalogs, plists, and the
  # pbxproj all change the built app too, but they also change constantly for
  # reasons that do not need a device round-trip; Swift is the signal that
  # behaviour moved. Doc-only and comment-only changes are exempt per CLAUDE.md,
  # and a comment-only Swift edit is not worth parsing for — it just costs one
  # extra install.
  case "$path" in
    */app/*.swift | app/*.swift) ;;
    *) exit 0 ;;
  esac
  mkdir -p "$root/tmp" && : >>"$edit_marker" && touch "$edit_marker"
  exit 0
fi

# --- Stop mode ------------------------------------------------------------

# Never re-block a stop another Stop hook already continued — prevents loops.
[ "$(printf '%s' "$input" | jq -r '.stop_hook_active // false')" = "true" ] && exit 0

[ -f "$edit_marker" ] || exit 0
# An install newer than the newest edit clears the gate.
[ -f "$install_marker" ] && [ ! "$edit_marker" -nt "$install_marker" ] && exit 0

jq -n '{
  decision: "block",
  reason: "app/ Swift changed but has not reached the device since (CLAUDE.md → \"Hand it back testable\"). Run `npm run app:install`; the phone must be unlocked or the disk image will not mount — say so rather than reporting a bare failure. Comment-only change, or owner declined? Say so and `touch tmp/.last-app-install`."
}'
