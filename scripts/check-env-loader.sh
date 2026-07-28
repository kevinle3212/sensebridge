#!/usr/bin/env bash
#
# check-env-loader.sh — regression test for scripts/env.sh.
#
# env.sh parses `.env` rather than sourcing it, precisely so a hostile or
# malformed file cannot execute code inside a git hook. That property is
# invisible — nothing fails loudly if someone "simplifies" the parser into a
# `source` — so it gets a test.
#
# Usage: scripts/check-env-loader.sh   (no network, no side effects, CI-safe)
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WORK_DIR="$(mktemp -d)"
trap 'rm -rf "$WORK_DIR"' EXIT

# env.sh resolves the repo root via git, so the fixture has to be a real repo.
git -C "$WORK_DIR" init --quiet
mkdir -p "$WORK_DIR/scripts"
cp "$REPO_ROOT/scripts/env.sh" "$WORK_DIR/scripts/env.sh"

FAILURES=0

# Reports a failure without aborting, so one run surfaces every problem.
fail() {
	echo "FAIL  $1" >&2
	FAILURES=$((FAILURES + 1))
}

# Loads the fixture .env in a clean subshell and prints one variable's value.
# Anything in $2 is exported first, to exercise the already-set precedence.
value_of() {
	local name="$1" preset="${2:-}"
	(
		cd "$WORK_DIR"
		if [ -n "$preset" ]; then export "${preset?}"; fi
		# shellcheck disable=SC1091
		. ./scripts/env.sh
		eval "printf '%s' \"\${$name-<unset>}\""
	)
}

cat >"$WORK_DIR/.env" <<'FIXTURE'
# A comment, then a blank line.

PLAIN=hello
QUOTED="double quoted"
SINGLE='single quoted'
export EXPORTED=prefix-stripped
  INDENTED=leading-whitespace
EMPTY=
WITH_EQUALS=a=b=c
SPECIAL=$(touch pwned)`touch pwned2`
SEMICOLON=x; touch pwned3
ALREADY_SET=from-file
not a valid line at all
9INVALID=leading-digit
IN-VALID=hyphen
FIXTURE

expect() {
	local label="$1" name="$2" want="$3" preset="${4:-}"
	local got
	got="$(value_of "$name" "$preset")"
	if [ "$got" != "$want" ]; then
		fail "$label: $name is [$got], expected [$want]"
	fi
}

expect "plain assignment" PLAIN hello
expect "double quotes stripped" QUOTED "double quoted"
expect "single quotes stripped" SINGLE "single quoted"
expect "export prefix stripped" EXPORTED prefix-stripped
expect "leading whitespace tolerated" INDENTED leading-whitespace
expect "empty value stays empty" EMPTY ""
expect "only the first = splits" WITH_EQUALS "a=b=c"
expect "already-set value wins" ALREADY_SET from-shell ALREADY_SET=from-shell

# The whole point: substitutions stay literal, and nothing runs. The single
# quotes below are the assertion — expanding here would defeat the test.
# shellcheck disable=SC2016
expect "command substitution not evaluated" SPECIAL '$(touch pwned)`touch pwned2`'
expect "semicolon does not start a command" SEMICOLON "x; touch pwned3"

for artifact in pwned pwned2 pwned3; do
	if [ -e "$WORK_DIR/$artifact" ]; then
		fail "env.sh executed the file's contents (created $artifact) — it must parse, not source"
	fi
done

# Malformed keys are ignored rather than guessed at. These names are not valid
# shell identifiers, so they cannot be read back with a parameter expansion —
# check the exported environment itself.
exported_env="$(
	cd "$WORK_DIR"
	# shellcheck disable=SC1091
	. ./scripts/env.sh
	env
)"
for bad_key in "9INVALID" "IN-VALID" "not"; do
	if printf '%s\n' "$exported_env" | grep -q "^${bad_key}="; then
		fail "malformed key '$bad_key' was exported; it should be ignored"
	fi
done

if [ "$FAILURES" -ne 0 ]; then
	echo "scripts/env.sh: $FAILURES check(s) failed." >&2
	exit 1
fi
echo "scripts/env.sh: OK (parsing, precedence, and no code execution)."
