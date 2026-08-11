#!/usr/bin/env bash
# Self-check for guard-commit-shape.sh. The risk on a shape guard is symmetric:
# a valid conventional header that gets denied costs a real commit, and an
# unconventional one that slips through defeats the point. Both directions are
# pinned here, plus the "not actually a commit" false-positive case that bit the
# sibling guard-main-commit.sh for real.
#
# Run: bash .claude/hooks/global/tests/guard-commit-shape.test.sh
set -uo pipefail

HOOK="$(cd "$(dirname "$0")/.." && pwd)/guard-commit-shape.sh"
failures=0

verdict() {
  local out
  out=$(jq -nc --arg c "$1" '{tool_name:"Bash", tool_input:{command:$c}}' | bash "$HOOK" 2>/dev/null)
  if [ -z "$out" ]; then printf 'allow'; else
    printf '%s' "$out" | jq -r '.hookSpecificOutput.permissionDecision'
  fi
}

expect() {
  local want=$1 cmd=$2 got
  got=$(verdict "$cmd")
  if [ "$got" != "$want" ]; then
    printf 'FAIL  want=%-5s got=%-5s  %s\n' "$want" "$got" "$cmd"
    failures=$((failures + 1))
  fi
}

# --- commit headers that conform ------------------------------------------
expect allow 'git commit -m "feat: add sound alerts"'
expect allow 'git commit -m "fix(voiceover): label the mute toggle"'
expect allow 'git commit -m "chore(deps): bump astro to 7.1.6"'
expect allow "git commit -m 'refactor(perception)!: split the classifier seam'"
expect allow 'git commit -m "docs: sync TOOLING.md with the new hooks"'
# A body after the header is fine — only the first line is the header.
expect allow 'git commit -m "feat(onboarding): add the permissions step

Explains why the mic is needed before asking for it."'

# --- commit headers that do not -------------------------------------------
expect deny 'git commit -m "add sound alerts"'
expect deny 'git commit -m "WIP"'
expect deny 'git commit -m "Fix: capitalised type"'
expect deny 'git commit -m "feat:no space after colon"'
expect deny 'git commit -m "feature: not a conventional type"'
expect deny 'git commit -m "feat: "'

# --- commits with no inline message are the owner's own path --------------
expect allow 'git commit --amend --no-edit'
expect allow 'git commit -F .git/COMMIT_EDITMSG'
expect allow 'git commit'
# `-C <commit>` after the subcommand genuinely reuses another message.
expect allow 'git commit -C HEAD@{1}'

# --- git's global options must not smuggle a commit past the guard --------
# `-C` before the subcommand selects a repo and says nothing about the message,
# but it was read as `--reuse-message` and skipped the check outright. Every
# option git accepts ahead of a subcommand gets the same treatment.
expect deny 'git -C /tmp/vault commit -m "WIP"'
expect allow 'git -C /tmp/vault commit -m "chore(vault): index Jarvis OS"'
expect deny 'git --git-dir=/tmp/r/.git --work-tree=/tmp/r commit -m "stuff"'
expect deny 'git --no-pager commit -m "stuff"'
expect deny 'git -c user.name=x commit -m "stuff"'
expect deny 'git -C /tmp/r checkout -b my-branch'
expect allow 'git -C /tmp/r checkout -b feat/thing'
# A message that merely mentions the flag must not suppress the check.
expect deny 'git commit -m "passing -C to the thing"'

# --- prose about a commit is not a commit ---------------------------------
expect allow 'echo "then run: git commit -m WIP"'
expect allow 'rtk grep -n "git commit" docs/'

# --- branch names ---------------------------------------------------------
expect allow 'git checkout -b feat/sound-alerts'
expect allow 'git switch -c fix/voiceover-label'
expect allow 'git checkout -b chore/mechanize-claude-md'
expect deny 'git checkout -b sound-alerts'
expect deny 'git switch -c my-branch'
expect deny 'git checkout -b feature/sound-alerts'
# Switching to an existing branch is not creating one.
expect allow 'git checkout main'
expect allow 'git switch main'

if [ "$failures" -eq 0 ]; then
  echo "guard-commit-shape: all cases pass"
else
  echo "guard-commit-shape: $failures failing case(s)"
  exit 1
fi
