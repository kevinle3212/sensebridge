#!/bin/sh
#
# env.sh — export `.env` into the environment for shell scripts and git hooks.
#
# Source it, don't run it (running it exports into a subshell that then exits):
#
#   . "$(dirname "$0")/env.sh"
#
# Companion to website/scripts/load-env.js, which does the same job for
# anything running on Node. Between the two, `.env` is picked up automatically
# by every entry point in this repo — there is no flag to remember and no
# `export FOO=... && ./script.sh` incantation.
#
# Reads the repo root's `.env` first, then `website/.env`, so site-specific
# values win over shared ones. Both are git-ignored and both are optional.
#
# Anything already exported wins over the file, matching the Node loader and
# Node's own `--env-file` semantics: a CI secret or a value you set for one
# command is never silently overwritten by a file on disk.
#
# The file is parsed, never sourced. Sourcing would execute whatever is in it,
# which turns an accidental `.env` — pasted from a gist, restored from a
# backup — into arbitrary code running inside your git hooks. Only
# `KEY=value` lines with a valid shell identifier are honored; `export `
# prefixes, comments, and blank lines are tolerated, and anything else is
# ignored rather than guessed at.

_sensebridge_load_env_file() {
	[ -f "$1" ] || return 0

	while IFS= read -r _line || [ -n "$_line" ]; do
		# Strip an optional `export ` prefix and leading whitespace.
		_line=${_line#"${_line%%[![:space:]]*}"}
		_line=${_line#export }

		case "$_line" in
		# Comments, blanks, and anything without a `=` are not our business.
		'#'* | '') continue ;;
		*=*) ;;
		*) continue ;;
		esac

		_key=${_line%%=*}
		_value=${_line#*=}

		# A valid shell identifier only. This is what keeps `eval` below safe:
		# the key can never carry a command substitution or a `;`.
		case "$_key" in
		'' | *[!A-Za-z0-9_]* | [0-9]*) continue ;;
		esac

		# Don't clobber a value that is already set (even to empty).
		eval "_already_set=\${$_key+yes}"
		[ "${_already_set:-}" = yes ] && continue

		# Strip one layer of matching quotes, the way dotenv files are written.
		case "$_value" in
		\"*\") _value=${_value#\"} _value=${_value%\"} ;;
		\'*\') _value=${_value#\'} _value=${_value%\'} ;;
		esac

		# Single-quote the value and escape any single quotes inside it, so the
		# assignment is literal no matter what the file contains.
		_escaped=$(printf '%s' "$_value" | sed "s/'/'\\\\''/g")
		eval "export $_key='$_escaped'"
	done <"$1"

	unset _line _key _value _escaped _already_set
}

# Ask git for the repo root rather than deriving it from `$0`: when sourced,
# `$0` is the *caller's* path, which differs between a script under scripts/, a
# hook under .githooks/, and a hook git copied into .git/hooks/.
_sensebridge_env_root=$(git rev-parse --show-toplevel 2>/dev/null || true)

if [ -n "$_sensebridge_env_root" ]; then
	_sensebridge_load_env_file "$_sensebridge_env_root/.env"
	_sensebridge_load_env_file "$_sensebridge_env_root/website/.env"
fi

unset _sensebridge_env_root
