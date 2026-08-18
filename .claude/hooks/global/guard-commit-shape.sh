#!/usr/bin/env bash
# PreToolUse hook (matcher: Bash): enforces the two shape rules that CLAUDE.md
# states for history — conventional commit headers (`type(scope): subject`) and
# branch names prefixed with a conventional type. Both are mechanical checks on
# a string, which is exactly the kind of rule that should not cost prose.
#
# Scope note: this guards the *shape* of a commit or branch name, nothing else.
# Whether a commit may happen at all is a project-level hook where one exists
# (SenseBridge ships `guard-main-commit.sh` — never on main), plus CLAUDE.md's
# "Git" section requiring an explicit per-command grant from the owner.
# Whether it carries an attribution trailer is `guard-attribution.sh`.
#
# Self-check: bash .claude/hooks/global/tests/guard-commit-shape.test.sh
set -euo pipefail

# The conventional-commit types this repo uses, shared by both checks so a
# branch prefix and a commit header can never drift apart.
TYPES='feat|fix|chore|docs|style|refactor|perf|test|build|ci|revert'

# Delimiter words of every heredoc opened on one command line, in the order
# bash queues their bodies. `<<-` and quoted delimiters are both recognised;
# the quoting is irrelevant here because the body is being read as text, never
# executed.
heredoc_delims_on_line() {
  local rest="$1"
  local op_re="<<-?[[:space:]]*[\"']?([A-Za-z_][A-Za-z0-9_]*)"
  while [[ $rest =~ $op_re ]]; do
    printf '%s\n' "${BASH_REMATCH[1]}"
    rest="${rest#*"${BASH_REMATCH[0]}"}"
  done
}

# The command lines of a shell string, with every heredoc *body* removed.
#
# Detection used to use `${raw_cmd%%<<*}`, which throws away everything after
# the first `<<`. A heredoc opened before the commit therefore hid the commit
# itself: `cat > notes <<NOTE ... NOTE` followed by `git commit -F- <<EOF`
# left detection with only the `cat`, so the guard exited as "not a commit"
# and the real message was never seen. Dropping only the bodies keeps every
# command visible while still ensuring body text is never read as a command.
strip_heredoc_bodies() {
  local raw="$1" pending="" head="" line=""
  while IFS= read -r line || [ -n "$line" ]; do
    if [ -n "$pending" ]; then
      head=${pending%%$'\n'*}
      if [[ $line =~ ^[[:space:]]*${head}[[:space:]]*$ ]]; then
        if [ "$pending" = "$head" ]; then pending=""; else pending=${pending#*$'\n'}; fi
      fi
      continue
    fi
    printf '%s\n' "$line"
    pending=$(heredoc_delims_on_line "$line")
  done <<< "$raw"
}

input=$(cat)
raw_cmd=$(printf '%s' "$input" | jq -r '.tool_input.command // empty')
[ -n "$raw_cmd" ] || exit 0

# Detection runs against a copy with quoted literals blanked, so prose that
# merely *describes* a commit does not read as one — the same false positive
# guard-main-commit.sh was bitten by on 2026-08-01. Extraction below runs
# against the raw string, because the message body is precisely what is inside
# those quotes.
detect=$(strip_heredoc_bodies "$raw_cmd" | sed -e "s/'[^']*'/ /g" -e 's/"[^"]*"/ /g')

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

# Branch and commit checks both run per segment, at the bottom of this file.
# They used to run once against the whole command, which meant only the first
# invocation was ever judged: `git commit -m "feat(a): fine" && git commit -m
# "WIP"` passed, because the conventional header was found first and the one
# after it was never read. The same held for `;`, `||`, and newlines.
#
# Cheap exit: if the command names neither a commit nor a branch creation,
# there is nothing to segment.
case $detect in
  *commit*|*checkout*|*switch*) ;;
  *) exit 0 ;;
esac

# The commit message carried by a `-F -` heredoc, on stdout.
#
# Attribution is the whole job. Taking "the first heredoc in the command" is
# wrong whenever the command opens more than one: a decoy heredoc placed
# earlier, whose body reads as a conventional header, made the real commit
# message invisible and the check pass. Bodies are also skipped while looking
# for the invocation, so a `git commit` written *inside* some other heredoc's
# text can never be mistaken for the real one.
#
# Exit 2 = no heredoc (piped or interactive stdin, genuinely invisible — the
# caller allows it, same as the editor path). Exit 3 = a heredoc exists but
# cannot be attributed unambiguously, which fails closed.
# macOS ships bash 3.2, so this is written to 3.2: no `mapfile`, no `declare
# -A`. An earlier revision used `mapfile` and died with "command not found"
# — and because the caller only saw an empty message, every heredoc commit was
# ALLOWED. A helper that fails open is worse than no helper, so the caller
# now distinguishes "no message" from "could not read one" by exit code.
#
# Every arithmetic step is an explicit assignment, never `((n++))`: under this
# file's `set -e`, `((hits++))` returns the *old* value, so the first
# increment from 0 is a non-zero status that exits the function silently.
heredoc_message_for_commit() {
  local raw="$1"
  local stdin_re='(^|[[:space:]])(-F|--file)([[:space:]]*|=)-([[:space:]]|$)'
  local pending="" head="" delims="" count=0
  local capture_delim="" capturing=0 msg=""
  local hits=0 saw_heredoc=0 ambiguous=0 line=""

  while IFS= read -r line || [ -n "$line" ]; do
    # Inside a heredoc body: consume to this body's terminator. These lines
    # are text, never commands, so a `git commit` written here is ignored.
    if [ -n "$pending" ]; then
      head=${pending%%$'\n'*}
      if [[ $line =~ ^[[:space:]]*${head}[[:space:]]*$ ]]; then
        if [ "$pending" = "$head" ]; then pending=""; else pending=${pending#*$'\n'}; fi
        if [ "$capturing" -eq 1 ] && [ "$head" = "$capture_delim" ]; then
          capturing=0
        fi
      elif [ "$capturing" -eq 1 ]; then
        msg="${msg}${line}"$'\n'
      fi
      continue
    fi

    delims=$(heredoc_delims_on_line "$line")
    if [[ $line =~ $stdin_re ]] && [[ $line == *commit* ]]; then
      hits=$((hits + 1))
      if [ -z "$delims" ]; then
        count=0
      else
        count=$(printf '%s\n' "$delims" | wc -l | tr -d ' ')
      fi
      if [ "$count" -gt 1 ]; then
        # Which heredoc feeds `-F -` depends on redirection order this hook
        # does not model. Fail closed rather than guess.
        ambiguous=1
      elif [ "$count" -eq 1 ]; then
        capture_delim=$delims
        capturing=1
      fi
    fi
    pending=$delims
    if [ -n "$pending" ]; then saw_heredoc=1; fi
  done <<< "$raw"

  # More than one stdin-fed commit in a single command is not a shape this
  # hook can reason about either.
  if [ "$hits" -ne 1 ]; then
    if [ "$saw_heredoc" -eq 1 ]; then return 3; fi
    return 2
  fi
  if [ "$ambiguous" -eq 1 ]; then return 3; fi
  # No heredoc on the commit's line: stdin is piped or interactive, and is
  # genuinely invisible to this hook.
  if [ -z "$capture_delim" ]; then return 2; fi
  # Still capturing at end of input: the body never terminated, so the
  # message cannot be trusted to be complete.
  if [ "$capturing" -eq 1 ]; then return 3; fi

  printf '%s' "$msg"
  return 0
}

# --- splitting a chained command into its invocations ---------------------

# Same length as its input, with characters inside quotes replaced by `x`.
# Preserving length is the point: an offset found in the mask addresses the
# same character in the raw string, so splitting on a separator seen in the
# mask can never cut a quoted message. `git commit -m "a; b"` keeps its
# semicolon because that one is masked.
mask_quotes() {
  local s="$1" out="" q="" c="" i n
  n=${#s}
  for ((i = 0; i < n; i++)); do
    c=${s:i:1}
    if [ -n "$q" ]; then
      if [ "$c" = "$q" ]; then q=""; out="$out$c"; else out="${out}x"; fi
    else
      case $c in
        "'"|'"') q=$c; out="$out$c" ;;
        *) out="$out$c" ;;
      esac
    fi
  done
  printf '%s' "$out"
}

# Fills seg_raw with the command's segments, cut at unquoted `&&`, `||`, `;`,
# `|` and newlines.
seg_raw=()
split_segments() {
  local raw="$1" mask="$2" nl=$'\n'
  local n=${#mask} i=0 start=0 c two
  seg_raw=()
  while [ "$i" -lt "$n" ]; do
    two=${mask:i:2}
    c=${mask:i:1}
    if [ "$two" = "&&" ] || [ "$two" = "||" ]; then
      seg_raw[${#seg_raw[@]}]=${raw:start:i-start}
      i=$((i + 2)); start=$i; continue
    fi
    case $c in
      ';'|'|'|"$nl")
        seg_raw[${#seg_raw[@]}]=${raw:start:i-start}
        i=$((i + 1)); start=$i; continue ;;
    esac
    i=$((i + 1))
  done
  seg_raw[${#seg_raw[@]}]=${raw:start}
}

check_header() {
  local header=${1%%$'\n'*}
  # `!` marks a breaking change and is part of the convention; the scope is
  # optional. The subject must be non-empty after the colon and space.
  if ! [[ $header =~ ^($TYPES)(\([a-z0-9._/-]+\))?!?:[[:space:]]+.+ ]]; then
    deny "Commit header \"$header\" is not a conventional message (CLAUDE.md → Branching and committing). Use type(scope): subject — types: $TYPES. Example: fix(sound-alerts): stop classifier on background transition."
  fi
}

# --- judge every invocation on its own ------------------------------------

raw_nobody=$(strip_heredoc_bodies "$raw_cmd")
split_segments "$raw_nobody" "$(mask_quotes "$raw_nobody")"

seg_idx=0
while [ "$seg_idx" -lt "${#seg_raw[@]}" ]; do
  seg=${seg_raw[seg_idx]}
  seg_idx=$((seg_idx + 1))

  # Per-segment detection copy, built exactly as the whole-command one was:
  # quoted literals blanked so prose describing a commit does not read as one,
  # then git's pre-subcommand global options folded out so `git -C <path>
  # commit` still presents the canonical `git commit` shape.
  seg_detect=$(printf '%s' "$seg" | sed -e "s/'[^']*'/ /g" -e 's/"[^"]*"/ /g' | sed -E \
    's/(^|[;&|(]|[[:space:]])git([[:space:]]+(-C[[:space:]]+[^[:space:]]+|--git-dir[= ][^[:space:]]+|--work-tree[= ][^[:space:]]+|--namespace[= ][^[:space:]]+|-c[[:space:]]+[^[:space:]]+|--no-pager|--bare|--literal-pathspecs|-P))+/\1git/g')

  if [[ $seg_detect =~ git[[:space:]]+(checkout[[:space:]]+-b|switch[[:space:]]+-c)[[:space:]]+([^[:space:]]+) ]]; then
    branch="${BASH_REMATCH[2]}"
    if ! [[ $branch =~ ^($TYPES)/.+ ]]; then
      deny "Branch \"$branch\" does not carry a conventional prefix (CLAUDE.md → Branching and committing). Name it <type>/<subject>, e.g. feat/sound-alerts or fix/voiceover-label — types: $TYPES."
    fi
  fi

  [[ $seg_detect =~ (^|[;\&|[:space:]])git[[:space:]]+commit ]] || continue

  # A message reused from another commit has no inline text to inspect, and an
  # editor-driven commit has none yet — both are the owner's own composition
  # path and are left alone. Reading only the text after the subcommand keeps
  # `git commit -C <commit>` (reuse) distinct from `git -C <path> commit`
  # (repo selection), which the folding above has already removed anyway.
  post_subcommand=${seg_detect#*commit}
  case " $post_subcommand " in
    *" -C "* | *--reuse-message* | *--no-edit* | *--fixup* | *--squash*) continue ;;
  esac

  message=""

  # `-F <path>` reads a file this hook cannot see into and is left alone.
  # `-F -` reads stdin, and a heredoc placed after the command puts that text
  # inline in `raw_cmd`, fully visible. `699d6d6` landed a non-conventional
  # subject exactly that way. The separator is `[[:space:]]*` and not `+`
  # because a short option may be glued to its value: `git commit -F-<<EOF` is
  # valid git meaning `-F -`, and requiring a separator let that spelling fall
  # past every branch below and out through the no-inline-message exit.
  if [[ $post_subcommand =~ (^|[[:space:]])(-F|--file)([[:space:]]*|=)-([[:space:]]|$) ]]; then
    # `message=$(fn)` takes fn's exit status, so under `set -e` a non-zero
    # return killed the hook before it could deny — silently allowing the
    # commit. `|| rc=$?` keeps the status without tripping `set -e`.
    rc=0
    message=$(heredoc_message_for_commit "$raw_cmd") || rc=$?
    case $rc in
      2) continue ;;  # piped or interactive stdin: genuinely invisible here
      3) deny "A \`git commit\` reading its message from stdin has a heredoc this hook cannot attribute unambiguously (several heredocs, several stdin-fed commits, or an unterminated body). Use \`git commit -m \"type(scope): subject\"\` so the header is inspectable." ;;
    esac
    check_header "$message"
    continue
  elif [[ $post_subcommand == *" -F "* || $post_subcommand == *--file* ]]; then
    continue
  fi

  # This segment's own -m/--message value. Reading the first one in the whole
  # command was the chaining bypass; reading every -m in the command would be
  # wrong too, since `mkdir -m 755 dir && git commit -m "feat: x"` would take
  # 755 as a commit message. Single- and double-quoted forms cover every shape
  # these hooks have seen; a bare unquoted word is matched last and can only be
  # a one-word message, which fails the header check anyway.
  if [[ $seg =~ (-m|--message)[[:space:]]*\"([^\"]*)\" ]]; then
    message="${BASH_REMATCH[2]}"
  elif [[ $seg =~ (-m|--message)[[:space:]]*\'([^\']*)\' ]]; then
    message="${BASH_REMATCH[2]}"
  elif [[ $seg =~ (-m|--message)[[:space:]]+([^[:space:]]+) ]]; then
    message="${BASH_REMATCH[2]}"
  else
    continue  # no inline message: the editor path, nothing to check
  fi

  check_header "$message"
done
