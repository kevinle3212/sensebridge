#!/usr/bin/env bash
# Self-check for guard-bash-secret-read.mjs.
#
# The allow cases matter more than the deny cases here. This guard sits on the
# Bash path, so a false positive blocks ordinary work — and the repo already
# learned where that leads: guard-main-commit.sh used to deny any command whose
# *text* contained `git commit`, which taught agents to route around it. A
# guard that fires on prose is a defect, not caution.
#
# Run: bash .claude/hooks/tests/guard-bash-secret-read.test.sh
set -uo pipefail

REPO="$(cd "$(dirname "$0")/../../.." && pwd)"
HOOK="$REPO/.claude/hooks/guard-bash-secret-read.mjs"
export CLAUDE_PROJECT_DIR="$REPO"

pass=0
fail=0

# Payloads are built with jq so that quotes, backslashes, and redirects inside a
# command survive into valid JSON. Hand-rolled string interpolation broke on the
# first case containing a double quote, which is precisely the prose case this
# suite exists to cover.
payload() { jq -nc --arg c "$1" '{tool_name:"Bash",tool_input:{command:$c}}'; }

assert_deny() {
  local label="$1" out
  out=$(payload "$2" | node "$HOOK" 2>/dev/null)
  if printf '%s' "$out" | grep -q '"permissionDecision":"deny"'; then
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
  out=$(payload "$2" | node "$HOOK" 2>/dev/null)
  if [ -z "$out" ]; then
    pass=$((pass + 1))
  else
    fail=$((fail + 1))
    echo "FAIL: expected allow — $label"
    echo "      cmd: $2"
    echo "      got: $out"
  fi
}

# --- the accidents this exists to catch ------------------------------------
assert_deny "plain cat of .env"                'cat .env'
assert_deny "head of a private key"            'head -5 config/id_rsa'
assert_deny "base64 of a p12"                  'base64 certs/app.p12'
assert_deny "cp of signing material"           'cp secrets/server.pem /tmp/'
assert_deny "env-var prefix before the verb"   'DEBUG=1 cat .env'
assert_deny "sudo wrapper"                     'sudo cat /Users/.../.ssh/id_ed25519'
assert_deny "second segment of a compound"     'ls -la && cat .env'
assert_deny "absolute spelling of an in-repo path" "cat $REPO/.env"

# RTK rewrites most Bash calls in this repo, so a guard blind to the `rtk`
# prefix would be blind on the normal path — not an edge case here.
assert_deny "RTK-wrapped grep"                 'rtk grep -rn TOKEN .env'
assert_deny "rtk proxy escape hatch"           'rtk proxy cat .env'

# An input redirect reads the file whatever the verb is. Both spellings.
# shellcheck disable=SC2016  # `$l` is test data handed to the hook, not a value
# this script expands — double-quoting it here would change what is asserted.
assert_deny "spaced input redirect"            'while read l; do echo "$l"; done < .env'
assert_deny "unspaced input redirect"          'read -r x <.env'

# --- must NOT fire on ordinary work ----------------------------------------
assert_allow "prose mentioning .env"           'echo "remember to set your .env file"'
assert_allow "the word pem as a search term"   'grep -rn "pem" docs/'
assert_allow "the .env.example carve-out"      'cat .env.example'
assert_allow "interpreter is not a reader verb" 'node tools/check-sensitive-files.mjs'
assert_allow "ordinary doc read"               'cat docs/TOOLING.md'
assert_allow "segments judged independently"   'cat README.md && rm -f old.pem'
assert_allow "npm gate"                        'npm run check'
assert_allow "git status"                      'git status --short'
assert_allow "heredoc is not a redirect read"  'cat <<EOF
hello
EOF'
assert_allow "sensitive name only as rm target" 'rm -f build/tmp.key'

# --- fail open --------------------------------------------------------------
# Opposite of guard-mcp-sensitive-paths.mjs, and deliberately so: this hook is
# on the Bash path, so failing closed on a bad payload would take the session
# down to defend a boundary it already admits it cannot hold.
assert_allow_raw() {
  local label="$1" out
  out=$(printf '%s' "$2" | node "$HOOK" 2>/dev/null)
  if [ -z "$out" ]; then
    pass=$((pass + 1))
  else
    fail=$((fail + 1))
    echo "FAIL: expected allow (fail open) — $label"
    echo "      got: $out"
  fi
}
assert_allow_raw "malformed JSON fails open" 'not json'
assert_allow_raw "empty payload fails open" ''

if [ "$fail" -eq 0 ]; then
  echo "guard-bash-secret-read: $pass passed, 0 failed"
else
  echo "guard-bash-secret-read: $pass passed, $fail failed"
  exit 1
fi
