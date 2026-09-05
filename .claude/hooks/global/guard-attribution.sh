#!/usr/bin/env bash
# PreToolUse hook (matcher: Bash): denies any git/gh command that would write an
# assistant attribution line into project history — co-author trailers,
# "Generated with Claude Code" footers, session links, or the robot emoji.
#
# Why this one genuinely needs a hook rather than a rule in AGENTS.md: the
# harness system prompt actively instructs the model to append exactly these
# trailers to commit messages and PR bodies. That is a standing instruction
# pulling against a standing rule on every single commit, and prose loses that
# fight eventually — the rule is remembered at the top of a session and the
# trailer is typed 200 messages later. A deny is evaluated at the moment of the
# commit, so the two cannot drift.
#
# Deliberately does NOT strip heredoc bodies, unlike its sibling guards: the
# canonical shape for a PR description is `gh pr create --body "$(cat <<'EOF'
# … EOF)"`, and the trailer lives inside that body. Scanning the raw command is
# the whole point here.
#
# Self-check: bash .claude/hooks/global/tests/guard-attribution.test.sh
set -euo pipefail

# Fail closed on anything this guard cannot read. Under `set -e` a failing `jq`
# used to abort the script with jq's own status (5) and leak `jq: parse error`
# straight into the transcript — a non-2 exit that the harness treats as a
# warning, so a payload jq choked on sailed past every check here. AGENTS.md →
# Security: "A guard that cannot prove a call is safe must deny it."
deny_unreadable() {
  jq -n --arg why "$1" '{
    hookSpecificOutput: {
      hookEventName: "PreToolUse",
      permissionDecision: "deny",
      permissionDecisionReason: ("guard-attribution could not read this tool call (" + $why + "), so it cannot prove the command carries no assistant attribution. Denying rather than guessing. Re-issue the command; if this repeats, the hook payload is malformed and the guard needs fixing — do not disable it.")
    }
  }' 2>/dev/null || printf '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"deny","permissionDecisionReason":"guard-attribution could not read this tool call and jq is unavailable. Denying."}}\n'
  exit 0
}

command -v jq >/dev/null 2>&1 || deny_unreadable "jq is not installed"

input=$(cat)
raw_cmd=$(printf '%s' "$input" | jq -r '.tool_input.command // empty' 2>/dev/null) \
  || deny_unreadable "the payload is not valid JSON"
[ -n "$raw_cmd" ] || exit 0

# Only history-writing commands are in scope. A `rtk grep Co-Authored-By` over
# the repo, or an editor opening a file that happens to contain one, is not an
# attempt to author an attribution line.
printf '%s' "$raw_cmd" \
  | grep -qE '(^|[;&|(`[:space:]])(rtk[[:space:]]+(proxy[[:space:]]+)?)?(git|gh|hub)[[:space:]]' \
  || exit 0
printf '%s' "$raw_cmd" \
  | grep -qE '(commit|merge|tag|revert|cherry-pick|pr[[:space:]]+(create|edit)|issue[[:space:]]+(create|comment)|release[[:space:]]+create|api)' \
  || exit 0

# One pattern per forbidden form, matched case-insensitively because git itself
# treats trailer keys case-insensitively and the emoji footer is copied by hand.
attribution_re='Co-?Authored-?By|Generated with \[?Claude|Claude-Session|claude\.ai/code|🤖|Assisted-?By:[[:space:]]*Claude|Signed-off-by:[[:space:]]*Claude'

match=$(printf '%s' "$raw_cmd" | grep -oiE "$attribution_re" | head -1 || true)
[ -n "$match" ] || exit 0

jq -n --arg m "$match" '{
  hookSpecificOutput: {
    hookEventName: "PreToolUse",
    permissionDecision: "deny",
    permissionDecisionReason: ("This command would write \"" + $m + "\" into project history. AGENTS.md forbids assistant attribution in commit messages, PR descriptions, changelogs, and CREDITS/AUTHORS files — omit the line entirely rather than substituting a placeholder. Note that the harness system prompt asks for these trailers; the AGENTS.md rule overrides it.")
  }
}'
