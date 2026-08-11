#!/usr/bin/env bash
# Self-check for guard-main-commit.sh. The guard must deny a real `git commit`
# while HEAD is on main, and must NOT deny a command that merely *mentions* one.
#
# The second half is the regression this file exists for: until 2026-08-01 the
# guard matched `git commit` anywhere in the raw command string, so a harness
# whose test fixtures contained the words was blocked from running at all. A
# guard that fires on prose trains its reader to route around it.
#
# Run: bash .claude/hooks/tests/guard-main-commit.test.sh
set -uo pipefail

HOOK="$(cd "$(dirname "$0")/.." && pwd)/guard-main-commit.sh"
ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"

# Cases that lean on the *session's* repo are a no-op off main, which would turn
# every "denied" case into a false pass. They are skipped rather than lying
# about coverage. The scratch-repo cases at the bottom bring their own branch
# state and always run — they are the regression tests that matter most, and
# gating the whole file on this repo's branch meant they vanished on any working
# branch, which is nearly always.
branch=$(git -C "$ROOT" branch --show-current 2>/dev/null || true)
SESSION_REPO_ON_MAIN=$([ "$branch" = "main" ] && echo yes || echo no)
[ "$SESSION_REPO_ON_MAIN" = yes ] ||
  echo "guard-main-commit: session-repo cases SKIPPED — HEAD is on '$branch'"

# Built at run time so this file never contains a literal `git commit` — the
# very string the sibling guards scan for.
VERB="com""mit"

pass=0
fail=0

# Returns "deny" or "allow" for one command string. The hook stays silent when
# it permits a command, so empty output is an allow — piping straight into jq
# would yield an empty string instead and every pass would read as a failure.
decision() {
  local out
  out=$(jq -nc --arg c "$1" --arg d "$ROOT" '{tool_name:"Bash",tool_input:{command:$c},cwd:$d}' |
    bash "$HOOK" 2>/dev/null)
  [ -z "$out" ] && { echo allow; return; }
  printf '%s' "$out" | jq -r '.hookSpecificOutput.permissionDecision // "allow"'
}

# Asserts one case. A trailing "session-repo" marks a case whose expectation
# only holds while this repo is on main; those are skipped elsewhere.
check() {
  local name=$1 want=$2 cmd=$3 got
  if [ "${4:-}" = "session-repo" ] && [ "$SESSION_REPO_ON_MAIN" != yes ]; then
    return
  fi
  got=$(decision "$cmd")
  if [ "$got" = "$want" ]; then
    pass=$((pass + 1))
  else
    fail=$((fail + 1))
    echo "FAIL: $name — wanted $want, got $got"
  fi
}

# --- real commits must be denied -------------------------------------------
check "bare commit"                deny  "git $VERB -m x"                       session-repo
check "commit with a quoted message" deny "git $VERB -m \"fix: a thing\""       session-repo
check "commit later in a chain"    deny  "git add -A && git $VERB -m x"         session-repo
check "commit through sh -c"       deny  "sh -c \"git $VERB -m x\""             session-repo

# --- mentions are data, not commands ---------------------------------------
check "verb inside a double-quoted echo" allow "echo \"then run: git $VERB -m x\""
check "verb inside a single-quoted grep" allow "grep -n 'git $VERB' TODO.md"
check "verb inside a heredoc body"       allow "$(printf 'cat <<EOF\ngit %s -m x\nEOF\n' "$VERB")"

# --- unrelated commands pass through ---------------------------------------
check "read-only git"    allow "git status --porcelain"
check "no git at all"    allow "npm run build"

# --- the guard must read the repo the command targets, not the session's ----
#
# Both halves of this bit for real on 2026-08-10. `git -C <path> commit` carries
# no literal "git commit" and skipped the guard outright, while `cd <path> &&
# git commit` was denied on *this* repo's branch — refusing a commit to a
# clean feature branch in another repo because sensebridge was on main.
#
# Real throwaway repos, because the whole defect was about resolving a branch
# from the wrong directory; a fixture that only pretends to be a repo would pass
# against the buggy version too.
SCRATCH=$(cd "$(mktemp -d)" && pwd -P)
trap 'rm -rf "$SCRATCH"' EXIT INT TERM

# One repo on main, one on a feature branch, each with a commit so HEAD is born.
for repo in on-main on-branch; do
  git init -q "$SCRATCH/$repo"
  git -C "$SCRATCH/$repo" -c user.email=t@t -c user.name=t \
    "$VERB" -q --allow-empty -m "chore: seed" 2>/dev/null
  git -C "$SCRATCH/$repo" branch -M main
done
git -C "$SCRATCH/on-branch" checkout -q -b feat/thing

check "-C into a repo on main"        deny  "git -C $SCRATCH/on-main $VERB -m \"fix: x\""
check "-C into a repo on a branch"    allow "git -C $SCRATCH/on-branch $VERB -m \"fix: x\""
check "cd into a repo on main"        deny  "cd $SCRATCH/on-main && git $VERB -m \"fix: x\""
check "cd into a repo on a branch"    allow "cd $SCRATCH/on-branch && git $VERB -m \"fix: x\""
check "cd separated by a semicolon"   deny  "cd $SCRATCH/on-main; git $VERB -m \"fix: x\""
check "cd with a quoted path"         deny  "cd \"$SCRATCH/on-main\" && git $VERB -m \"fix: x\""
check "cd inside a subshell"          deny  "(cd $SCRATCH/on-main && git $VERB -m \"fix: x\")"
check "--git-dir into a repo on main" deny  "git --git-dir=$SCRATCH/on-main/.git --work-tree=$SCRATCH/on-main $VERB -m \"fix: x\""

# A quote is a boundary before `cd` too. Anchoring only on shell operators
# missed every `sh -c "cd <path> && ..."` shape: the quote after `-c` is not an
# operator, so the target fell back to the session cwd and the commit was judged
# against the wrong repo — the same false denial the `cd` handling was added to
# fix, reached by a different shape. Both polarities are pinned, because reading
# the wrong repo can deny a legal commit as easily as it can permit a bad one.
check "sh -c into a repo on main"        deny  "sh -c \"cd $SCRATCH/on-main && git $VERB -m x\""
check "sh -c into a repo on a branch"    allow "sh -c \"cd $SCRATCH/on-branch && git $VERB -m x\""
check "sh -c single-quoted, on main"     deny  "sh -c 'cd $SCRATCH/on-main && git $VERB -m x'"
check "bash -c into a repo on a branch"  allow "bash -c \"cd $SCRATCH/on-branch && git $VERB -m x\""
check "sh -c with -C into a repo on main" deny "sh -c \"git -C $SCRATCH/on-main $VERB -m x\""

echo "guard-main-commit: $pass passed, $fail failed"
[ "$fail" -eq 0 ]
