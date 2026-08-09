#!/usr/bin/env bash
# Self-check for prefer-serena.sh. Runs the hook against synthetic PreToolUse
# payloads and asserts which ones produce a nudge. The Grep/Glob branch exists
# to fire rarely, so a regression there is silent — this is what fails instead.
#
# Run: bash .claude/hooks/tests/prefer-serena.test.sh
set -uo pipefail

HOOK="$(cd "$(dirname "$0")/.." && pwd)/prefer-serena.sh"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

# The hook's once-per-session cache lives under $TMPDIR. Point that at the
# throwaway dir so runs stay isolated from each other and from the real cache —
# otherwise the second run of this file sees every key already recorded and
# every nudge assertion fails.
export TMPDIR="$TMP"

# The nudge-logic assertions below (line count, file type, dedup cache) are
# testing the hook's decision logic, not its serena-availability gate — that
# gate has its own dedicated section further down. Without this, every nudge
# assertion silently depends on serena happening to be on the PATH of whatever
# machine runs the suite: it passes locally (serena installed) and fails in CI
# (serena not installed), because the hook's own availability check exits 0
# before the logic under test ever runs.
export CLAUDE_SERENA_NUDGE_ASSUME_AVAILABLE=1

# Each case gets a fresh session id so the once-per-session cache never
# cross-contaminates results. Payloads arrive on stdin and are single-quoted at
# the call site: embedding escaped double quotes in an argument makes the JSON
# fall apart under word splitting before the hook ever sees it.
#
# The counter lives in a file rather than a shell variable because `run` is
# called inside `$(...)`, and a subshell's variable assignment does not survive.
# With a plain variable every case would reuse `session-1`, which passes only
# while no two cases share a cache key — a property no one is maintaining.
echo 0 > "$TMP/sid"
run() {
  local sid
  sid=$(( $(cat "$TMP/sid") + 1 ))
  echo "$sid" > "$TMP/sid"
  sed -e "s|__SID__|session-$sid|" \
      -e "s|__BIG__|$big|" -e "s|__SMALL__|$small|" -e "s|__PROSE__|$prose|" \
    | bash "$HOOK" 2>/dev/null
}

pass=0
fail=0
assert_nudge() {
  if printf '%s' "$2" | grep -q 'additionalContext'; then
    pass=$((pass + 1))
  else
    fail=$((fail + 1))
    echo "FAIL: expected a nudge — $1"
  fi
}
assert_silent() {
  if [ -z "$2" ]; then
    pass=$((pass + 1))
  else
    fail=$((fail + 1))
    echo "FAIL: expected silence — $1"
  fi
}

big="$TMP/Big.swift"
seq 1 200 > "$big"
small="$TMP/Small.swift"
seq 1 10 > "$small"
prose="$TMP/README.md"
seq 1 200 > "$prose"

# --- Read branch -----------------------------------------------------------
assert_nudge "Read of a 200-line Swift file" \
  "$(run <<<'{"session_id":"__SID__","tool_name":"Read","tool_input":{"file_path":"__BIG__"}}')"

# Same payload as the case above, but a different session. This is what fails
# if `run` ever stops issuing a fresh session id: the cache key is identical, so
# a stale counter suppresses the nudge and the assertion below catches it.
assert_nudge "identical Read in a different session still nudges" \
  "$(run <<<'{"session_id":"__SID__","tool_name":"Read","tool_input":{"file_path":"__BIG__"}}')"

assert_silent "Read of a 10-line Swift file (under MIN_LINES)" \
  "$(run <<<'{"session_id":"__SID__","tool_name":"Read","tool_input":{"file_path":"__SMALL__"}}')"

assert_silent "Read with an explicit small limit is already targeted" \
  "$(run <<<'{"session_id":"__SID__","tool_name":"Read","tool_input":{"file_path":"__BIG__","limit":40}}')"

assert_silent "Read of Markdown — Serena does not index prose" \
  "$(run <<<'{"session_id":"__SID__","tool_name":"Read","tool_input":{"file_path":"__PROSE__"}}')"

# --- Edit branch -----------------------------------------------------------
assert_nudge "Edit of a 200-line Swift file" \
  "$(run <<<'{"session_id":"__SID__","tool_name":"Edit","tool_input":{"file_path":"__BIG__"}}')"

# --- Grep/Glob branch ------------------------------------------------------
assert_nudge "Grep for a bare identifier scoped to Swift" \
  "$(run <<<'{"session_id":"__SID__","tool_name":"Grep","tool_input":{"pattern":"RenderTarget","glob":"*.swift"}}')"

assert_silent "Grep with regex metacharacters is text search, not symbol lookup" \
  "$(run <<<'{"session_id":"__SID__","tool_name":"Grep","tool_input":{"pattern":"Render.*Target","glob":"*.swift"}}')"

assert_silent "Grep unscoped to an indexed language" \
  "$(run <<<'{"session_id":"__SID__","tool_name":"Grep","tool_input":{"pattern":"RenderTarget"}}')"

assert_silent "Grep scoped to Markdown" \
  "$(run <<<'{"session_id":"__SID__","tool_name":"Grep","tool_input":{"pattern":"RenderTarget","glob":"*.md"}}')"

assert_nudge "Glob for a bare identifier in TypeScript" \
  "$(run <<<'{"session_id":"__SID__","tool_name":"Glob","tool_input":{"pattern":"useAwareness","glob":"*.ts"}}')"

# --- Serena-unavailable fallback -------------------------------------------
# Every message this hook emits names an `mcp__serena__*` tool. If Serena is not
# installed those tools do not exist, so the nudge costs a wasted turn per
# qualifying call for the whole session. RTK's hook already fails this way
# correctly (`rtkRewrite` returns null); these assert the Serena side matches.
#
# Only the directory holding `serena` is dropped from PATH — a blanket
# PATH=/usr/bin:/bin would also hide `jq`, and the hook would then exit early
# for the wrong reason and the test would pass while proving nothing.
serena_bin=$(command -v serena 2>/dev/null || true)
if [ -n "$serena_bin" ]; then
  serena_dir=$(dirname "$serena_bin")
  path_without_serena=$(printf '%s' "$PATH" | tr ':' '\n' | grep -vxF "$serena_dir" | paste -sd: -)

  if [ -n "$(PATH="$path_without_serena" command -v jq 2>/dev/null)" ]; then
    # Explicit 0, not just unset: the whole file exports ASSUME_AVAILABLE=1
    # above so the nudge-logic assertions run deterministically without
    # serena installed. This is the one call that must prove the real
    # availability gate, so it overrides that back off rather than inheriting it.
    assert_silent "no nudge when the serena binary is unavailable" \
      "$(printf '%s' '{"session_id":"absent-1","tool_name":"Read","tool_input":{"file_path":"'"$big"'"}}' \
        | PATH="$path_without_serena" CLAUDE_SERENA_NUDGE_ASSUME_AVAILABLE=0 bash "$HOOK" 2>/dev/null)"

    assert_nudge "ASSUME_AVAILABLE=1 overrides the availability check" \
      "$(printf '%s' '{"session_id":"absent-2","tool_name":"Read","tool_input":{"file_path":"'"$big"'"}}' \
        | PATH="$path_without_serena" CLAUDE_SERENA_NUDGE_ASSUME_AVAILABLE=1 bash "$HOOK" 2>/dev/null)"
  else
    echo "SKIP: jq is not reachable without ${serena_dir} on PATH — cannot isolate serena"
  fi
else
  echo "SKIP: serena is not installed, so the unavailable-fallback cases cannot be staged"
fi

# --- once-per-session cache ------------------------------------------------
same_sid='{"session_id":"cache-check","tool_name":"Grep","tool_input":{"pattern":"RenderTarget","glob":"*.swift"}}'
first=$(printf '%s' "$same_sid" | bash "$HOOK" 2>/dev/null)
second=$(printf '%s' "$same_sid" | bash "$HOOK" 2>/dev/null)
assert_nudge "first Grep nudge in a session" "$first"
assert_silent "repeat Grep nudge is suppressed for the session" "$second"

echo "prefer-serena: $pass passed, $fail failed"
[ "$fail" -eq 0 ]
