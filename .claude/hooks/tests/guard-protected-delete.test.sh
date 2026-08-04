#!/usr/bin/env bash
# Self-check for guard-protected-delete.sh.
#
# The allow cases carry the weight. This guard denied two commands during the
# 2026-08-01 session whose here-doc *data* merely mentioned a discard verb near
# a protected path — nothing was being removed in either, and the second was
# the command writing the note describing the first. A guard that fires on
# prose is a defect, not caution: it teaches agents to route around it, which
# is the actual risk. The deny cases exist so that fix cannot be over-applied
# into a hole — quoting a path is ordinary, so `rm -rf "sessions/x"` must stay
# denied even though the blanking that fixed the prose case removes quoted
# text from consideration.
#
# Run: bash .claude/hooks/tests/guard-protected-delete.test.sh
set -uo pipefail

REPO="$(cd "$(dirname "$0")/../../.." && pwd)"
HOOK="$REPO/.claude/hooks/guard-protected-delete.sh"
export CLAUDE_PROJECT_DIR="$REPO"

pass=0
fail=0

# Built with jq so quotes, backslashes, and newlines inside a command survive
# into valid JSON — the here-doc and escaped-quote cases below are exactly the
# shapes hand-rolled interpolation gets wrong.
payload() { jq -nc --arg c "$1" '{tool_name:"Bash",tool_input:{command:$c}}'; }

assert_deny() {
  local label="$1" out
  out=$(payload "$2" | bash "$HOOK" 2>/dev/null)
  # Whitespace-tolerant: this hook emits via `jq -n`, which pretty-prints, so
  # the compact `"key":"value"` spelling its .mjs siblings produce never matches.
  if printf '%s' "$out" | grep -qE '"permissionDecision"[[:space:]]*:[[:space:]]*"deny"'; then
    pass=$((pass + 1))
  else
    fail=$((fail + 1))
    echo "FAIL: expected deny — $label"
    echo "      cmd: $2"
    echo "      got: ${out:-<empty, i.e. ALLOWED>}"
  fi
}

assert_allow() {
  local label="$1" out
  out=$(payload "$2" | bash "$HOOK" 2>/dev/null)
  if [ -z "$out" ]; then
    pass=$((pass + 1))
  else
    fail=$((fail + 1))
    echo "FAIL: expected allow — $label"
    echo "      cmd: $2"
    echo "      got: $out"
  fi
}

# --- the losses this exists to prevent --------------------------------------
assert_deny "bare session-log tree"            'rm -rf sessions'
assert_deny "dated session log"                'rm -rf sessions/2026-08-01'
assert_deny "owner-gated legal/ restore"       'git checkout -- legal/PRIVACY_POLICY.md'
assert_deny "append-only audits/"              'rmdir audits/2026-08-01'
assert_deny "shred of local secrets"           'shred .env'
assert_deny "gitignored signing config"        'rm Config/Signing.local.xcconfig'
assert_deny "gitignored local notes"           'rm -f NOTES.local.md'
assert_deny "the repository itself"            'rm -rf .git'
assert_deny "git clean of the worktree"        'git clean -fdx sessions/'

# Quoting a path is ordinary shell, so the prose fix must not blank it away.
assert_deny "quoted protected path"            'rm -rf "sessions/2026-08-01"'
assert_deny "single-quoted protected path"     "rm -rf 'sessions/2026-08-01'"
assert_deny "quote split mid-token"            'rm -rf sess"ions"/2026-08-01'

# Command position is not required: an accidental mass delete hides in argv.
assert_deny "second segment of a compound"     'ls -la && rm -rf sessions/'
assert_deny "find -exec"                       'find . -name "*.md" -exec rm -rf sessions/{} \;'
assert_deny "rtk proxy wrapper"                'rtk proxy rm -rf sessions/'

# `sh -c` opts out of quote blanking, because there the quotes hold code.
assert_deny "sh -c executes the string"        'sh -c "rm -rf sessions/"'
assert_deny "eval executes the string"         'eval "rm -rf sessions/"'

# --- must NOT fire on prose -------------------------------------------------
# The two real false positives from 2026-08-01, verbatim in shape.
assert_allow "here-doc body mentioning a delete" 'cat > tmp/note.md <<'"'"'EOF'"'"'
- rm -rf sessions/ destroyed a gitignored log with no recovery path.
EOF'
# shellcheck disable=SC2016  # the backticks below are test data handed to the
# hook verbatim; expanding them would change what is asserted.
assert_allow "here-doc into a session log"     'cat >> sessions/2026-08-01/1925-PST.md <<'"'"'EOF'"'"'
Reported: the guard denied a command because `rm -rf sessions/` sat in prose.
EOF'
assert_allow "quoted prose"                    'echo "never run rm -rf sessions/ here"'
assert_allow "escaped quotes inside prose"     'echo "he said \"rm -rf sessions/\" out loud"'
assert_allow "separator inside a quoted string" 'echo "a; rm -rf sessions/"'
assert_allow "protected path named in a sibling segment" 'rm -rf build && echo "sessions/ kept"'

# --- must NOT fire on ordinary work -----------------------------------------
assert_allow "delete of a regenerable path"    'rm -rf node_modules'
assert_allow "prefix is not the path"          'rm -rf tmp/sessions-cache'
assert_allow "reading a protected path"        'cat sessions/2026-08-01/1925-PST.md'
assert_allow "grep over the session logs"      'grep -rn TODO sessions/'
assert_allow "no delete verb at all"           'git status --short'
assert_allow "npm gate"                        'npm run check'

# --- degraded input ---------------------------------------------------------
# Bad payload means no command was parsed, so there is nothing to judge. The
# hook exits non-zero with no stdout, which Claude Code treats as a
# non-blocking error — the same direction guard-bash-secret-read.mjs fails.
assert_allow_raw() {
  local label="$1" out
  out=$(printf '%s' "$2" | bash "$HOOK" 2>/dev/null)
  if [ -z "$out" ]; then
    pass=$((pass + 1))
  else
    fail=$((fail + 1))
    echo "FAIL: expected allow — $label"
    echo "      got: $out"
  fi
}
assert_allow_raw "malformed JSON emits no decision" 'not json'
assert_allow_raw "empty payload emits no decision" ''
assert_allow_raw "non-Bash payload emits no decision" '{"tool_name":"Read","tool_input":{"file_path":"sessions/x.md"}}'

if [ "$fail" -eq 0 ]; then
  echo "guard-protected-delete: $pass passed, 0 failed"
else
  echo "guard-protected-delete: $pass passed, $fail failed"
  exit 1
fi
