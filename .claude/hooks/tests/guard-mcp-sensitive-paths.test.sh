#!/usr/bin/env bash
# Self-check for guard-mcp-sensitive-paths.mjs. This guard is the only thing
# enforcing the credential and legal/ deny rules against MCP tools, which
# Claude Code's own path globs do not reach — so a silent regression here
# reopens a confirmed bypass with nothing else to catch it. This is what fails
# instead.
#
# Run: bash .claude/hooks/tests/guard-mcp-sensitive-paths.test.sh
set -uo pipefail

REPO="$(cd "$(dirname "$0")/../../.." && pwd)"
HOOK="$REPO/.claude/hooks/guard-mcp-sensitive-paths.mjs"
export CLAUDE_PROJECT_DIR="$REPO"

pass=0
fail=0

# Allow is signalled by silence (the hook exits 0 with no payload), deny by a
# JSON decision. Asserting on the decision field rather than on exit status is
# deliberate: PreToolUse hooks report both outcomes with exit 0, so a test that
# checked `$?` would pass no matter which way the guard ruled.
assert_deny() {
  local label="$1" payload="$2" want="$3" out
  out=$(printf '%s' "$payload" | node "$HOOK" 2>/dev/null)
  if printf '%s' "$out" | grep -q '"permissionDecision":"deny"' &&
     printf '%s' "$out" | grep -qF "$want"; then
    pass=$((pass + 1))
  else
    fail=$((fail + 1))
    echo "FAIL: expected deny mentioning '$want' — $label"
    echo "      got: ${out:-<empty, i.e. ALLOWED>}"
  fi
}

assert_allow() {
  local label="$1" payload="$2" out
  out=$(printf '%s' "$payload" | node "$HOOK" 2>/dev/null)
  if [ -z "$out" ]; then
    pass=$((pass + 1))
  else
    fail=$((fail + 1))
    echo "FAIL: expected allow (silence) — $label"
    echo "      got: $out"
  fi
}

# --- the confirmed bypass: filesystem MCP vs the credential deny list --------
assert_deny "read_text_file on a .pem" \
  '{"tool_name":"mcp__filesystem__read_text_file","tool_input":{"path":"secrets/server.pem"}}' \
  "secrets/server.pem"

assert_deny "write_file on .env" \
  '{"tool_name":"mcp__filesystem__write_file","tool_input":{"path":".env","content":"X=1"}}' \
  ".env"

assert_deny "read_multiple_files with one sensitive entry" \
  '{"tool_name":"mcp__filesystem__read_multiple_files","tool_input":{"paths":["docs/TOOLING.md","website/.env.production"]}}' \
  "website/.env.production"

assert_deny "move_file with a sensitive destination" \
  '{"tool_name":"mcp__filesystem__move_file","tool_input":{"source":"docs/a.md","destination":"out/id_ed25519"}}' \
  "out/id_ed25519"

# Absolute and relative spellings must be judged identically — an MCP tool
# accepts either, so judging only the literal string leaves the absolute form
# open. This is the case a name-only guard gets wrong.
assert_deny "absolute path to an in-repo secret" \
  "{\"tool_name\":\"mcp__filesystem__read_file\",\"tool_input\":{\"path\":\"$REPO/config/prod.key\"}}" \
  "config/prod.key"

assert_deny "absolute path to a secret outside the repo" \
  '{"tool_name":"mcp__filesystem__read_text_file","tool_input":{"path":"/Users/.../.ssh/id_rsa"}}' \
  "id_rsa"

# --- legal/: the family guard-serena-legal.sh never covered ------------------
assert_deny "filesystem MCP editing legal/" \
  '{"tool_name":"mcp__filesystem__edit_file","tool_input":{"path":"legal/TERMS.md"}}' \
  "legal/TERMS.md"

assert_deny "serena replace_content on legal/" \
  '{"tool_name":"mcp__serena__replace_content","tool_input":{"relative_path":"legal/PRIVACY_POLICY.md"}}' \
  "legal/PRIVACY_POLICY.md"

assert_deny "serena replace_content on a secret" \
  '{"tool_name":"mcp__serena__replace_symbol_body","tool_input":{"relative_path":".env.production"}}' \
  ".env.production"

# --- must NOT over-block ----------------------------------------------------
assert_allow "ordinary doc read" \
  '{"tool_name":"mcp__filesystem__read_text_file","tool_input":{"path":"docs/TOOLING.md"}}'

assert_allow "legal-adjacent name that is not under legal/" \
  '{"tool_name":"mcp__filesystem__read_text_file","tool_input":{"path":"docs/legal-notes.md"}}'

# .env.example holds key names, not values, and check-sensitive-files.mjs
# exempts it. The guard imports that exemption rather than restating it; if the
# two ever disagree this case is what says so.
assert_allow "the .env.example carve-out is honoured" \
  '{"tool_name":"mcp__filesystem__read_text_file","tool_input":{"path":".env.example"}}'

# Only known path-bearing keys are inspected. A path-shaped string sitting in
# edit *content* is data, not a target, and must not trip the guard.
assert_allow "secret-looking text in content is not a path" \
  '{"tool_name":"mcp__filesystem__write_file","tool_input":{"path":"docs/x.md","content":"see .env and server.pem"}}'

assert_allow "tool with no path argument at all" \
  '{"tool_name":"mcp__filesystem__list_allowed_directories","tool_input":{}}'

# --- fail closed ------------------------------------------------------------
# Every other hook here is advisory and fails open. This one is load-bearing:
# an unparseable payload means the path is unknown, and "unknown" is exactly
# what a malformed or hostile input produces.
assert_deny "malformed JSON denies rather than allowing" \
  'not json at all' \
  "fails closed"

assert_deny "empty payload denies" \
  '' \
  "fails closed"

if [ "$fail" -eq 0 ]; then
  echo "guard-mcp-sensitive-paths: $pass passed, 0 failed"
else
  echo "guard-mcp-sensitive-paths: $pass passed, $fail failed"
  exit 1
fi
