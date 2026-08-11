#!/usr/bin/env sh
# Codex wrapper: reuse the same guards Claude Code has under .claude/hooks/
# instead of re-implementing them per harness. Sits alongside (not instead
# of) the serena-hooks CLI calls already wired in .codex/hooks.json — those
# manage Serena's own session lifecycle; this covers repository guards.
#
# guard-main-commit.sh and guard-destructive-git.sh are safe to call
# unconditionally: both no-op (exit 0, no output) on a non-git command,
# verified 2026-08-07 against a synthetic `ls -la` payload. Claude's own
# settings.json only gates them behind an `if: Bash(git *)` filter as an
# optimization, not because an unfiltered call misbehaves — so this dispatch
# needs no equivalent filter.
#
# The three Stop-time gates (session-log-reminder.sh, handoff-clear-reminder.sh,
# require-device-install.sh with no args) emit Claude's `{decision: "block",
# reason: ...}` Stop-hook schema, which is NOT what Codex's Stop hook expects —
# the same incompatibility salon-os already hit and solved by making its Codex
# session-summary hook a bare `{"continue": true}` passthrough. Follow the same
# fix here rather than guessing at an unconfirmed Codex block schema: run the
# gate for its side effects and reason text, surface that reason on stderr
# (visible in Codex's own transcript even though it cannot structurally block),
# and always tell Codex to continue.
set -eu

action=${1:-}
script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
root=$(CDPATH= cd -- "$script_dir/../.." && pwd)

stop_passthrough() {
  out=$("$1" 2>&1 || true)
  [ -n "$out" ] && printf '%s\n' "$out" >&2
  printf '{"continue": true}\n'
}

case "$action" in
  bash-secret)      exec node "$root/.claude/hooks/guard-bash-secret-read.mjs" ;;
  mcp-sensitive)     exec node "$root/.claude/hooks/guard-mcp-sensitive-paths.mjs" ;;
  rtk-shape)         exec node "$root/.claude/hooks/prefer-rtk-shape.mjs" ;;
  react-doctor)      exec node "$root/.claude/hooks/react-doctor.mjs" ;;
  main-commit)       exec "$root/.claude/hooks/guard-main-commit.sh" ;;
  destructive-git)   exec "$root/.claude/hooks/guard-destructive-git.sh" ;;
  protected-delete)  exec "$root/.claude/hooks/guard-protected-delete.sh" ;;
  serena-legal)      exec "$root/.claude/hooks/guard-serena-legal.sh" ;;
  cap-read)          exec "$root/.claude/hooks/cap-large-read.sh" ;;
  dup-read)          exec "$root/.claude/hooks/warn-duplicate-read.sh" ;;
  prefer-serena)     exec "$root/.claude/hooks/prefer-serena.sh" ;;
  md-links)          exec "$root/.claude/hooks/check-md-links.sh" ;;
  session-log)       stop_passthrough "$root/.claude/hooks/session-log-reminder.sh" ;;
  handoff)           stop_passthrough "$root/.claude/hooks/handoff-clear-reminder.sh" ;;
  device-install)    stop_passthrough "$root/.claude/hooks/require-device-install.sh" ;;
  device-install-edit) exec "$root/.claude/hooks/require-device-install.sh" stamp-edit ;;
  *) exit 0 ;;
esac
