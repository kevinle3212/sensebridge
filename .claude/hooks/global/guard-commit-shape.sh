#!/usr/bin/env bash
# PreToolUse hook (matcher: Bash): enforces the two shape rules that CLAUDE.md
# states for history — conventional commit headers (`type(scope): subject`) and
# branch names prefixed with a conventional type. Both are mechanical checks on
# a string, which is exactly the kind of rule that should not cost prose.
#
# Scope note: this guards the *shape* of a commit or branch name, nothing else.
# Whether a commit may happen at all is `guard-main-commit.sh` (never on main)
# plus CLAUDE.md §15 requiring an explicit per-command grant from the owner.
# Whether it carries an attribution trailer is `guard-attribution.sh`.
#
# Self-check: bash .claude/hooks/global/tests/guard-commit-shape.test.sh
set -euo pipefail

# The conventional-commit types this repo uses, shared by both checks so a
# branch prefix and a commit header can never drift apart.
TYPES='feat|fix|chore|docs|style|refactor|perf|test|build|ci|revert'

input=$(cat)
raw_cmd=$(printf '%s' "$input" | jq -r '.tool_input.command // empty')
[ -n "$raw_cmd" ] || exit 0

# Detection runs against a copy with quoted literals blanked, so prose that
# merely *describes* a commit does not read as one — the same false positive
# guard-main-commit.sh was bitten by on 2026-08-01. Extraction below runs
# against the raw string, because the message body is precisely what is inside
# those quotes.
detect=$(printf '%s' "${raw_cmd%%<<*}" | sed -e "s/'[^']*'/ /g" -e 's/"[^"]*"/ /g')

# Git's global options sit between `git` and the subcommand, so `git -C <path>
# commit` does not contain the literal "git commit" that every check below
# anchors on — the whole guard was skippable by adding `-C`. Fold those options
# out so detection sees the canonical `git <subcommand>` shape. Only options git
# actually accepts before a subcommand are listed; anything else is left alone
# so an unrecognised token can never swallow the subcommand itself.
detect=$(printf '%s' "$detect" | sed -E \
  's/(^|[;&|(]|[[:space:]])git([[:space:]]+(-C[[:space:]]+[^[:space:]]+|--git-dir[= ][^[:space:]]+|--work-tree[= ][^[:space:]]+|--namespace[= ][^[:space:]]+|-c[[:space:]]+[^[:space:]]+|--no-pager|--bare|--literal-pathspecs|-P))+/\1git/g')

deny() {
  jq -n --arg reason "$1" \
    '{hookSpecificOutput: {hookEventName: "PreToolUse", permissionDecision: "deny", permissionDecisionReason: $reason}}'
  exit 0
}

# --- branch names ---------------------------------------------------------

if [[ $detect =~ git[[:space:]]+(checkout[[:space:]]+-b|switch[[:space:]]+-c)[[:space:]]+([^[:space:]]+) ]]; then
  branch="${BASH_REMATCH[2]}"
  if ! [[ $branch =~ ^($TYPES)/.+ ]]; then
    deny "Branch \"$branch\" does not carry a conventional prefix (CLAUDE.md → Branching and committing). Name it <type>/<subject>, e.g. feat/sound-alerts or fix/voiceover-label — types: $TYPES."
  fi
fi

# --- commit headers -------------------------------------------------------

[[ $detect =~ (^|[;\&|[:space:]])git[[:space:]]+commit ]] || exit 0

# A message supplied from a file or reused from another commit has no inline
# text to inspect, and an editor-driven commit has none yet — all three are the
# owner's own composition path and are left alone.
#
# Scanning only the text *after* the subcommand matters for `-C`, which means
# two different things depending on where it sits: `git commit -C <commit>`
# reuses that commit's message, but `git -C <path> commit` only picks the repo
# and says nothing about the message. Testing the whole command conflated them,
# so `git -C ~/repo commit -m "bad header"` skipped this check entirely.
# Quote-blanked `detect` is used rather than the raw string so that a message
# merely containing "-C" cannot suppress the check either.
post_subcommand=${detect#*commit}
case " $post_subcommand " in
  *" -F "* | *--file* | *" -C "* | *--reuse-message* | *--no-edit* | *--fixup* | *--squash*) exit 0 ;;
esac

# Pull the first -m/--message value out of the raw command. Single- and
# double-quoted forms cover every shape these hooks have seen; a bare unquoted
# word is matched last and can only be a one-word message, which fails the
# header check below anyway.
if [[ $raw_cmd =~ (-m|--message)[[:space:]]*\"([^\"]*)\" ]]; then
  message="${BASH_REMATCH[2]}"
elif [[ $raw_cmd =~ (-m|--message)[[:space:]]*\'([^\']*)\' ]]; then
  message="${BASH_REMATCH[2]}"
elif [[ $raw_cmd =~ (-m|--message)[[:space:]]+([^[:space:]]+) ]]; then
  message="${BASH_REMATCH[2]}"
else
  # No inline message at all — the editor path. Nothing to check.
  exit 0
fi

header="${message%%$'\n'*}"
# `!` marks a breaking change and is part of the convention; the scope is
# optional. The subject must be non-empty after the colon and space.
if ! [[ $header =~ ^($TYPES)(\([a-z0-9._/-]+\))?!?:[[:space:]]+.+ ]]; then
  deny "Commit header \"$header\" is not a conventional message (CLAUDE.md → Branching and committing). Use type(scope): subject — types: $TYPES. Example: fix(sound-alerts): stop classifier on background transition."
fi
