#!/usr/bin/env bash
# PreToolUse hook (matcher: Bash): denies commands that start a long-running
# local server — `npm run dev`, `astro dev`, `astro preview`, `vite`,
# `next dev`, `python -m http.server` and friends.
#
# Why a hook rather than a line in AGENTS.md: a server started unasked outlives
# the turn, holds a port, and is invisible to whoever never asked for it, so the
# failure is silent and only shows up later as "address already in use". The
# rule was prose for months and still got broken, because the model reaching for
# `npm run dev` is doing it mid-task with the instruction far behind it in
# context. A deny is checked on every call regardless of how long the session is.
#
# The escape hatch is owner-only, and proving that takes more than the token.
# `--force-server` used to be accepted from the command string alone, on the
# theory that the model "has no reason to type it on its own" — but this hook's
# own deny message names the token, so the model reads it on the first denial
# and can re-issue with it. That made the hatch self-serve: a guard the guarded
# party can open. The token is now necessary but not sufficient. It must also
# appear in a genuine typed turn from the owner in the session transcript, which
# the model cannot author: tool results and hook-injected reminders are excluded
# explicitly, and those are the only channels the model can write into.
#
# Self-check: bash .claude/hooks/global/tests/guard-long-running-server.test.sh
set -euo pipefail

# Fail closed on anything this guard cannot read — see guard-attribution.sh for
# the full rationale. A failing `jq` under `set -e` exits 5, which the harness
# treats as a warning rather than a block, so an unreadable payload used to
# start a server unchecked.
deny_unreadable() {
  jq -n --arg why "$1" '{
    hookSpecificOutput: {
      hookEventName: "PreToolUse",
      permissionDecision: "deny",
      permissionDecisionReason: ("guard-long-running-server could not read this tool call (" + $why + "), so it cannot prove the command does not start a long-running local server. Denying rather than guessing. Re-issue the command; if this repeats, the hook payload is malformed and the guard needs fixing — do not disable it.")
    }
  }' 2>/dev/null || printf '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"deny","permissionDecisionReason":"guard-long-running-server could not read this tool call and jq is unavailable. Denying."}}\n'
  exit 0
}

command -v jq >/dev/null 2>&1 || deny_unreadable "jq is not installed"

input=$(cat)
raw_cmd=$(printf '%s' "$input" | jq -r '.tool_input.command // empty' 2>/dev/null) \
  || deny_unreadable "the payload is not valid JSON"
[ -n "$raw_cmd" ] || exit 0

# True when the owner typed `--force-server` in this session. Only genuine user
# turns count, so the three channels the model can write into are all excluded:
#
#   * tool results — recorded as `type: "user"` records whose content is an
#     array of `tool_result` blocks, so any `echo --force-server` would land
#     here. Only `text` blocks (and plain-string content) are read.
#   * hook and harness injections — marked `isMeta`, dropped outright.
#   * `<system-reminder>` and `<local-command-stdout>` spans appended to an
#     otherwise real user turn. A CLAUDE.md or skill file the model can edit is
#     injected this way, so the spans are stripped before matching rather than
#     trusted for sitting inside a user record.
owner_typed_force_server() {
  local transcript
  transcript=$(printf '%s' "$input" | jq -r '.transcript_path // empty' 2>/dev/null) || return 1
  [ -n "$transcript" ] && [ -f "$transcript" ] || return 1

  jq -r '
    select(.type == "user")
    | select((.isMeta // false) | not)
    | .message.content
    | if type == "string" then .
      elif type == "array" then (map(select(.type == "text") | .text) | join("\n"))
      else empty end
  ' "$transcript" 2>/dev/null \
    | awk '
        /<system-reminder>|<local-command-stdout>/ { skip = 1 }
        /<\/system-reminder>|<\/local-command-stdout>/ { skip = 0; next }
        !skip
      ' \
    | grep -qF -- '--force-server'
}

# Serena's MCP server is launched by the harness via .mcp.json, never via this
# Bash tool, so this guard never sees it in practice. Exempted explicitly
# anyway (not just left as an accidental regex non-match) in case an agent
# ever runs `serena start-mcp-server` by hand to debug a stuck instance —
# that command shape doesn't match the npm/vite/etc. patterns below, but a
# future edit to those patterns should not be able to catch it by accident.
case "$raw_cmd" in *serena\ start-mcp-server*) exit 0 ;; esac

# Cut at the first heredoc introducer: a heredoc body is file content, not a
# command.
scan=${raw_cmd%%<<*}

# A shell's `-c` argument is the one quoted string on a command line that is NOT
# data — it is the command. Blanking it below would erase the very thing being
# guarded, which is how `sh -c 'npm run dev'` got through. Unwrap it first, so
# `sh -c 'npm run dev'` becomes `; npm run dev` and meets the same anchors as a
# bare invocation. The `;` matters: it keeps the payload at a start-of-command
# position rather than splicing it mid-word.
#
# Looped because the payload can itself be another `-c` invocation. Three passes
# is not a parser and is not trying to be one — this guard raises the cost of an
# accidental server launch, and a caller nesting four shells deep to reach one
# has left the territory of accident. Any wrapper this misses still has to get
# past a human reading the command.
for _ in 1 2 3; do
  next=$(printf '%s' "$scan" | sed -E \
    -e "s/(^|[;&|(]|[[:space:]])(env[[:space:]]+)?(sh|bash|zsh|dash|ksh|ash)[[:space:]]+-[a-zA-Z]*c[[:space:]]+'([^']*)'/\1; \4/g" \
    -e 's/(^|[;&|(]|[[:space:]])(env[[:space:]]+)?(sh|bash|zsh|dash|ksh|ash)[[:space:]]+-[a-zA-Z]*c[[:space:]]+"([^"]*)"/\1; \4/g')
  [ "$next" = "$scan" ] && break
  scan=$next
done

# Now blank what genuinely is data, so it cannot read as an executable command —
# matching guard-main-commit.sh: `echo "run npm run dev yourself"` documents a
# server, it does not start one.
cmd=$(printf '%s' "$scan" | sed -e "s/'[^']*'/ /g" -e 's/"[^"]*"/ /g')

# Anchored on a shell operator or start-of-line so `npm run build:dev` and a
# path like `tools/vite-helper.mjs` do not read as a server launch. Each pattern
# is the *whole* invocation shape, not a bare word.
#
# `npm start` is included: for an Astro/Vite project it is an alias for the dev
# server often enough that assuming otherwise is the wrong default, and a
# project that means something else by it can add an exception here.
server_re='(^|[;&|(][[:space:]]*|[[:space:]]&&[[:space:]]|[[:space:]]\|\|[[:space:]])[[:space:]]*'

# Wrapper prefixes are skipped before the invocation shape is matched. This
# started life as a special case for `rtk (proxy )?`, which was the wrong shape
# for the problem: anchoring on the *command* means any wrapper that defers to
# it walks straight through, and `env npm run dev` did exactly that. A leading
# `VAR=value` assignment counts as a wrapper too, since `PORT=3000 npm run dev`
# is the same launch. Widening here can only ever deny more, never less, and the
# group must still be followed by a whole server invocation to match at all.
server_re+='(([A-Za-z_][A-Za-z0-9_]*=[^[:space:]]*|env|command|builtin|exec|nohup|setsid|script|time|nice|ionice|sudo|doas|caffeinate|stdbuf|rtk|proxy|-{1,2}[A-Za-z0-9][A-Za-z0-9-]*)[[:space:]]+)*'
server_re+='(((npm|pnpm|yarn|bun)[[:space:]]+(run[[:space:]]+)?(dev|start|serve|preview)'
server_re+='|(npx[[:space:]]+)?(astro|vite|next|nuxt|remix)[[:space:]]+(dev|preview|start)'
server_re+='|(npx[[:space:]]+)?(vite|serve|http-server|live-server)([[:space:]]|$)'
server_re+='|python3?[[:space:]]+-m[[:space:]]+http\.server'
server_re+='|(npx[[:space:]]+)?astro[[:space:]]+dev'
# `omniroute serve` holds port 20128 exactly like the shapes above, and the
# command-name anchoring meant the guard never saw it. Owner-approved 2026-08-27:
# the extra friction on a tool in daily use is the point, not a side effect.
# `restart` is included because it starts a server when none is running.
server_re+='|omniroute[[:space:]]+(serve|restart)([[:space:]]|$)))'

printf '%s' "$cmd" | grep -qE "$server_re" || exit 0

# The hatch is checked only once the command has already been recognised as a
# server launch. Checking it earlier — as this guard used to — meant a harmless
# `npm run build --force-server` took the hatch's path and could be denied for
# failing an owner check it never needed to pass.
if printf '%s' "$raw_cmd" | grep -qF -- '--force-server'; then
  owner_typed_force_server && exit 0

  jq -n '{
    hookSpecificOutput: {
      hookEventName: "PreToolUse",
      permissionDecision: "deny",
      permissionDecisionReason: "--force-server is an owner-only override and this session transcript has no turn where the owner typed it. The token on its own is not enough — it is named in this guard'"'"'s deny message, so the model can read it there, which is exactly the self-serve hatch this check closes. Do not retry with the flag. Ask the owner to reply with --force-server if they want the server started, or hand them the command to run themselves. Note that some commands reject an unknown flag (commander-based CLIs such as omniroute do), so pass the token as a trailing comment instead: `omniroute serve --daemon # --force-server`."
    }
  }'
  exit 0
fi

jq -n '{
  hookSpecificOutput: {
    hookEventName: "PreToolUse",
    permissionDecision: "deny",
    permissionDecisionReason: "Long-running local servers are never started unasked (AGENTS.md → \"Testing and verification\"): the process outlives the turn, holds a port, and is invisible to whoever did not ask for it. Verify with a build (`npm run build`) instead, then hand the owner the command to run. If the owner explicitly asked for a server, ask them to reply with --force-server — typing it yourself will not open the hatch. Where the command would reject an unknown flag, the token works as a trailing comment: `omniroute serve --daemon # --force-server`."
  }
}'
