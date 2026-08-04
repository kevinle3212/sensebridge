#!/usr/bin/env bash
# PreToolUse hook (matcher: Bash): denies delete/discard commands that touch
# paths this repo can never regenerate from git — gitignored logs and
# local-only config with no version-control recovery path, plus paths gated
# on explicit owner approval. Added after `rm -rf sessions` destroyed a
# gitignored session log mid-task with no way to recover it.
set -euo pipefail

input=$(cat)
raw_cmd=$(printf '%s' "$input" | jq -r '.tool_input.command // empty')
[ -n "$raw_cmd" ] || exit 0

# Cut everything from the first heredoc introducer, matching the sibling
# guard-main-commit.sh. Parameter expansion, not `sed 's/<<.*//'`: sed works
# line by line, so it truncated only the `cat <<EOF` line and left the body it
# was meant to remove. That is what made this guard deny two commands whose
# heredoc *data* merely mentioned a discard verb near a protected path —
# nothing was being removed in either. A guard that fires on prose is a defect,
# not caution; it teaches agents to route around it.
cmd=${raw_cmd%%<<*}
[ -n "$cmd" ] || exit 0

# A command that executes a quoted string is the one place quotes hold code, so
# it opts out of the quote handling below: drop the quote characters up front
# and its contents stay visible in command position, keeping
# `sh -c "rm -rf sessions/"` a real delete.
if printf '%s' "$cmd" | grep -qE '(^|[^[:alnum:]_./-])(eval|(sh|bash|zsh)[[:space:]]+-c)([[:space:]]|$)'; then
  cmd=$(printf '%s' "$cmd" | tr -d "'\"")
fi

# Walk the command once, tracking quote state, and build two views of every
# separator-delimited segment:
#
#   code — quoted runs collapsed to a space, so DATA cannot read as a command.
#          `echo "run rm -rf sessions/"` documents a delete, it does not make
#          one. This is guard-main-commit.sh's blanking fix.
#   full — quote characters dropped, contents kept, so a quoted path is still a
#          path. `rm -rf "sessions/x"` must stay denied, which is why the
#          blanking cannot simply be copied wholesale: unlike `git commit`, the
#          thing this guard matches on is an *argument*, and arguments are
#          routinely quoted.
#
# Splitting is quote-aware for the same reason: a `;` inside a string does not
# start a new command, so `echo "a; rm -rf sessions/"` stays one segment whose
# verb is `echo`.
codes=()
fulls=()
code=""
full=""
quote=""
i=0
len=${#cmd}
while [ "$i" -lt "$len" ]; do
  ch=${cmd:i:1}
  i=$((i + 1))

  # A backslash escapes the next character everywhere except inside single
  # quotes. Without this, `echo "he said \"rm -rf sessions/\""` would flip the
  # quote state twice and leave the prose sitting in command position.
  if [ "$ch" = $'\\' ] && [ "$quote" != "'" ]; then
    nxt=${cmd:i:1}
    i=$((i + 1))
    full+=$nxt
    if [ -z "$quote" ]; then
      code+=$nxt
    fi
    continue
  fi

  if [ -n "$quote" ]; then
    if [ "$ch" = "$quote" ]; then
      quote=""
      code+=" "
    else
      full+=$ch
    fi
    continue
  fi

  case $ch in
    "'" | '"')
      quote=$ch
      ;;
    ";" | "|" | "&" | $'\n')
      codes+=("$code")
      fulls+=("$full")
      code=""
      full=""
      ;;
    *)
      code+=$ch
      full+=$ch
      ;;
  esac
done
codes+=("$code")
fulls+=("$full")

# Commands that can delete or discard files. Matched anywhere in the segment
# rather than in command position only, so `find . -exec rm -rf sessions/{} \;`
# is still caught: for a guard whose job is the accidental `rm -rf sessions`, a
# false negative costs more than a false positive on a contrived shape.
verbs='(^|[;&|[:space:]])(rm|rmdir|shred|git[[:space:]]+clean|git[[:space:]]+checkout|git[[:space:]]+restore)([[:space:]]|$)'

# sessions/          — gitignored session logs (AGENTS.md#session-logs); no
#                       git history to recover from, as proven the hard way.
# legal/              — owner-approval-gated per CLAUDE.md; never touched
#                       without explicit sign-off, deletion included.
# audits/             — append-only by convention (AGENT-GUIDE.md).
# Config/*.local.xcconfig — gitignored signing config, hand-configured per
#                       machine; regenerating it means re-deriving team IDs.
# NOTES.local.md, .env*   — gitignored local notes/secrets.
# .git/               — the repository itself.
# Quote characters are gone from the `full` view by the time this runs, so the
# boundary classes below no longer need to list them.
protected='(^|[/[:space:]])(sessions|legal|audits)(/|[[:space:]]|$)|Config/[A-Za-z0-9._-]*\.local\.xcconfig|NOTES\.local\.md|(^|[/[:space:]])\.env([.[:space:]]|$)|(^|[[:space:]])\.git(/|[[:space:]]|$)'

idx=0
while [ "$idx" -lt "${#codes[@]}" ]; do
  seg_code=${codes[idx]}
  seg_full=${fulls[idx]}
  idx=$((idx + 1))

  printf '%s' "$seg_code" | grep -qE "$verbs" || continue
  printf '%s' "$seg_full" | grep -qE "$protected" || continue

  jq -n --arg cmd "$seg_full" '{hookSpecificOutput: {hookEventName: "PreToolUse", permissionDecision: "deny", permissionDecisionReason: ("Blocked: delete/discard command targets a protected path (sessions/, legal/, audits/, Config/*.local.xcconfig, NOTES.local.md, .env*, or .git/). These are gitignored or owner-gated and cannot be recovered via git. If this is genuinely needed, ask the user to confirm the exact command first. Segment: " + $cmd)}}'
  exit 0
done

exit 0
