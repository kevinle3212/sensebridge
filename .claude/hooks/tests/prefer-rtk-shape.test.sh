#!/usr/bin/env bash
# Self-check for prefer-rtk-shape.mjs. The hook rewrites RTK-covered commands
# that sit in a shape RTK's own hook declines, so the two halves worth pinning
# down are: it must act on every leaking shape, and it must stay out of the way
# on every shape RTK already handles — a double rewrite is as wrong as none.
#
# Run: bash .claude/hooks/tests/prefer-rtk-shape.test.sh
set -uo pipefail

HOOK="$(cd "$(dirname "$0")/.." && pwd)/prefer-rtk-shape.mjs"

# The hook delegates each rewrite decision to `rtk hook claude`, so without rtk
# on PATH every case would collapse to "unchanged" and report false passes.
if ! command -v rtk >/dev/null 2>&1; then
  echo "prefer-rtk-shape: SKIPPED — rtk not on PATH (hook delegates to it)"
  exit 0
fi

run() {
  jq -nc --arg c "$1" --arg d "$PWD" \
    '{session_id:"test", tool_name:"Bash", tool_input:{command:$c}, cwd:$d}' \
    | node "$HOOK" 2>/dev/null
}

# Extract the rewritten command, or "(unchanged)" when the hook stayed silent.
result() {
  local out
  out=$(run "$1")
  if [ -z "$out" ]; then
    printf '(unchanged)'
  else
    printf '%s' "$out" | jq -r '.hookSpecificOutput.updatedInput.command'
  fi
}

pass=0
fail=0
assert_rewrite() {
  local got
  got=$(result "$2")
  if [ "$got" = "$3" ]; then
    pass=$((pass + 1))
  else
    fail=$((fail + 1))
    echo "FAIL: $1"
    echo "        input: $2"
    echo "     expected: $3"
    echo "          got: $got"
  fi
}
assert_unchanged() {
  local got
  got=$(result "$2")
  if [ "$got" = "(unchanged)" ]; then
    pass=$((pass + 1))
  else
    fail=$((fail + 1))
    echo "FAIL: expected no rewrite — $1"
    echo "        input: $2"
    echo "          got: $got"
  fi
}

# --- shapes RTK already rewrites: this hook must not touch them -------------
# Acting here would duplicate RTK's own rewrite for the same call.
assert_unchanged "bare covered command" 'git status'
assert_unchanged "&& chain" 'cd /tmp && git status'
assert_unchanged "; chain" 'echo start; npm run build'
assert_unchanged "|| chain — a chain operator that merely contains a pipe" 'git status || true'
assert_unchanged "backgrounded command" 'git status &'

# --- nothing to gain --------------------------------------------------------
assert_unchanged "command outside RTK's covered set" 'npm test'
assert_unchanged "uncovered command in a pipeline" 'echo hello | base64'
assert_unchanged "already routed through rtk" 'rtk git status | head -5'
assert_unchanged "redirect char inside single quotes is a literal" "git log --grep '>'"

# --- pipes ------------------------------------------------------------------
assert_rewrite "covered command piped into a filter" \
  'git status | head -5' 'rtk git status | head -5'

assert_rewrite "leading grep piped onward" \
  'grep -rn foo . | head -20' 'rtk grep -rn foo . | head -20'

assert_rewrite "find piped into a counter" \
  "find . -name '*.mjs' | wc -l" "rtk find . -name '*.mjs' | wc -l"

# `cat` maps to `rtk read`, not `rtk cat` — the reason each segment is handed to
# RTK instead of being prefixed from a hardcoded table.
assert_rewrite "cat resolves through RTK's own mapping" \
  'cat pkg.json | jq .name' 'rtk read pkg.json | jq .name'

# --- pipeline consumers are the filter, not the leak ------------------------
assert_unchanged "wc downstream of a pipe is consuming" 'echo hello | wc -l'

# `wc` leads its own statement here, so the consumer exemption must not apply.
assert_rewrite "consumer leading a statement after a semicolon" \
  'echo x; wc -l foo | cat' 'echo x; rtk wc -l foo | cat'

# --- redirects --------------------------------------------------------------
assert_rewrite "redirect to a file" \
  'git status > out.txt' 'rtk git status > out.txt'

# The `2` of `2>&1` belongs to the operator and must not be swallowed into the
# command segment.
assert_rewrite "stderr merged then piped" \
  'npm run build 2>&1 | tail' 'rtk npm run build 2>&1 | tail'

# --- loop bodies ------------------------------------------------------------
# shellcheck disable=SC2016
assert_rewrite "for-loop body" \
  'for f in a b; do cat $f; done' 'for f in a b; do rtk read $f; done'

# shellcheck disable=SC2016
assert_rewrite "while-loop body" \
  'while read -r f; do git show $f; done' 'while read -r f; do rtk git show $f; done'

# --- command substitution ---------------------------------------------------
# Double-quoted spans must stay scannable, or the command inside disappears.
# shellcheck disable=SC2016
assert_rewrite "substitution inside double quotes" \
  'echo "$(git status)"' 'echo "$(rtk git status)"'

# shellcheck disable=SC2016
assert_rewrite "substitution captured into a variable" \
  'x=$(git status)' 'x=$(rtk git status)'

# shellcheck disable=SC2016
assert_rewrite "leading VAR=value assignment" \
  'FOO=1 git status | head -3' 'FOO=1 rtk git status | head -3'

# --- subshells and indirection ---------------------------------------------
assert_rewrite "subshell" '( git status )' '( rtk git status )'
assert_rewrite "eval" 'eval "git status"' 'eval "rtk git status"'
assert_rewrite "nested shell" 'bash -c "git status"' 'bash -c "rtk git status"'

# --- parameter expansion is not a brace group -------------------------------
# shellcheck disable=SC2016
assert_rewrite "\${VAR} must not read as syntax" \
  'ls ${HOME} | head -2' 'rtk ls ${HOME} | head -2'

# --- redirects into raw-fidelity artifacts must stay unfiltered -------------
# Regression: on 2026-08-01 an away-mode backup ran `rtk git diff HEAD > b.patch`,
# this hook rewrote it, and RTK wrote a `--stat` summary. The patch was 67KB
# instead of 4.7MB and `git apply` rejected it — silently, only at restore time.
assert_unchanged "git diff into .patch" 'git diff HEAD > backup.patch'
assert_unchanged "git diff into a quoted, variable path" 'git diff HEAD > "$B/backup.patch"'
assert_unchanged "append into .patch" 'git diff HEAD >> backup.patch'
assert_unchanged "git log into .json" 'git log --format=%H > commits.json'
assert_unchanged "ls into .lock" 'ls -la > deps.lock'
assert_unchanged "find into .tar.gz" 'find . -name "*.md" > archive.tar.gz'

# Prose targets stay rewritten — compaction is the whole point for those.
assert_rewrite "redirect into .txt is still compacted" \
  'git status > out.txt' 'rtk git status > out.txt'
assert_rewrite "redirect into .md is still compacted" \
  'ls -la docs > listing.md' 'rtk ls -la docs > listing.md'
assert_rewrite "no extension is still compacted" \
  'git status > out' 'rtk git status > out'
# `<` feeds input, it does not capture output, so it must not trigger the guard.
assert_rewrite "input redirect from .json does not shield the command" \
  'git status < in.json' 'rtk git status < in.json'

# --- heredoc bodies are data, not shell -------------------------------------
# Regression: writing a file via `python3 - <<'PY'` whose *content* contained the
# literal string `git status > out.txt` produced `rtk git status > out.txt` in
# the generated file (hit for real 2026-08-01). A heredoc body is never a
# command position.
# shellcheck disable=SC2016
assert_unchanged "quoted heredoc body containing a covered command" \
  "$(printf 'python3 - <<%s\nprint("git status > out.txt")\nPY\n' "'PY'")"

# shellcheck disable=SC2016
assert_unchanged "unquoted heredoc body containing a covered command" \
  "$(printf 'cat <<EOF\ngit status | head -5\nEOF\n')"

# `<<-` strips leading tabs from its terminator; the body must still be masked.
assert_unchanged "tab-indented heredoc terminator" \
  "$(printf 'cat <<-EOF\n\tls -la | wc -l\n\tEOF\n')"

# Masking must not swallow the command that owns the heredoc, nor anything after
# the terminator — those are real command positions.
assert_rewrite "command after a heredoc terminator is still rewritten" \
  "$(printf 'cat <<EOF\ngit status\nEOF\nls -la | head -3\n')" \
  "$(printf 'cat <<EOF\ngit status\nEOF\nrtk ls -la | head -3\n')"

# `<<<` is a here-string with no body — the operand is a word, not a delimiter.
assert_rewrite "here-string is not a heredoc" \
  'grep -rn foo . <<< "$x" | head -2' 'rtk grep -rn foo . <<< "$x" | head -2'

# --- newline is a leaking shape (added 2026-08-01) -------------------------
# RTK's own hook rewrites only the FIRST line of a multi-line command, and
# nothing at all when line 1 is a command it does not cover. Measured on this
# repo's history, 1,298 of 1,810 `cd`-prefixed calls (72%) were multi-line and
# so reached neither hook. `;` and `&&` are deliberately NOT leaks — RTK
# rewrites every segment there, and claiming them would double-rewrite.
assert_rewrite "multi-line opened by an uncovered cd" \
  "$(printf 'cd /tmp\ngrep -rn foo src')" \
  "$(printf 'cd /tmp\nrtk grep -rn foo src')"

assert_rewrite "every line of a multi-line command, not just the first" \
  "$(printf 'cd /tmp\nls -la\ncat README.md')" \
  "$(printf 'cd /tmp\nrtk ls -la\nrtk read README.md')"

assert_rewrite "echo scaffolding between covered commands" \
  "$(printf 'echo "=== a ==="\ngit status\nwc -l TODO.md')" \
  "$(printf 'echo "=== a ==="\nrtk git status\nrtk wc -l TODO.md')"

# The raw-fidelity refusal must survive the newline change — this is the exact
# shape that silently corrupted a backup .patch on 2026-08-01.
assert_unchanged "multi-line redirect into a raw-fidelity artifact" \
  "$(printf 'cd /tmp\ngit diff HEAD > backup.patch')"

# --- write-then-rename suffixes keep raw-fidelity protection ----------------
# Only the final extension used to be tested, so `> settings.json.new` slipped
# past the .json guard and RTK compacted a 340-line config into 1.5KB (hit for
# real 2026-08-01, while editing this repo's own settings).
assert_unchanged "raw-fidelity extension behind .new" \
  'jq . config.json > config.json.new'
assert_unchanged "raw-fidelity extension behind .tmp" \
  'git diff HEAD > out.patch.tmp'
assert_unchanged "raw-fidelity extension behind a numeric suffix" \
  'cat a.sql > a.sql.1'
# A temp suffix on a prose file is still safe to compact — the guard must not
# grow into a blanket refusal of every redirect.
assert_rewrite "prose file with a temp suffix is still rewritten" \
  'grep -rn foo src > notes.md.new' 'rtk grep -rn foo src > notes.md.new'

# --- non-Bash tools are out of scope ---------------------------------------
out=$(jq -nc '{tool_name:"Read", tool_input:{file_path:"/tmp/a.swift"}}' | node "$HOOK" 2>/dev/null)
if [ -z "$out" ]; then pass=$((pass + 1)); else fail=$((fail + 1)); echo "FAIL: non-Bash payload"; fi

echo "prefer-rtk-shape: $pass passed, $fail failed"
[ "$fail" -eq 0 ]
