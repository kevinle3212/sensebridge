#!/usr/bin/env bash
# PreToolUse hook (matcher: Bash): denies commands that start a long-running
# local server — `npm run dev`, `astro dev`, `astro preview`, `vite`,
# `next dev`, `python -m http.server` and friends.
#
# Why a hook rather than a line in CLAUDE.md: a server started unasked outlives
# the turn, holds a port, and is invisible to whoever never asked for it, so the
# failure is silent and only shows up later as "address already in use". The
# rule was prose for months and still got broken, because the model reaching for
# `npm run dev` is doing it mid-task with the instruction far behind it in
# context. A deny is checked on every call regardless of how long the session is.
#
# The escape hatch is deliberate and human-only: the deny message names
# `--force-server`, a token the model has no reason to type on its own. The
# owner asking for a server is the case this hook must not block, and the owner
# can always re-run the command themselves.
#
# Self-check: bash .claude/hooks/global/tests/guard-long-running-server.test.sh
set -euo pipefail

input=$(cat)
raw_cmd=$(printf '%s' "$input" | jq -r '.tool_input.command // empty')
[ -n "$raw_cmd" ] || exit 0

# Explicit owner override, matching the sibling guards' convention of letting a
# human-typed token through rather than making the rule unbypassable.
case "$raw_cmd" in *--force-server*) exit 0 ;; esac

# Serena's MCP server is launched by the harness via .mcp.json, never via this
# Bash tool, so this guard never sees it in practice. Exempted explicitly
# anyway (not just left as an accidental regex non-match) in case an agent
# ever runs `serena start-mcp-server` by hand to debug a stuck instance —
# that command shape doesn't match the npm/vite/etc. patterns below, but a
# future edit to those patterns should not be able to catch it by accident.
case "$raw_cmd" in *serena\ start-mcp-server*) exit 0 ;; esac

# Blank out quoted string literals so DATA cannot read as an executable command,
# matching guard-main-commit.sh: `echo "run npm run dev yourself"` documents a
# server, it does not start one. Cut at the first heredoc introducer for the
# same reason — a heredoc body is file content, not a command.
cmd=$(printf '%s' "${raw_cmd%%<<*}" | sed -e "s/'[^']*'/ /g" -e 's/"[^"]*"/ /g')

# Anchored on a shell operator or start-of-line so `npm run build:dev` and a
# path like `tools/vite-helper.mjs` do not read as a server launch. Each pattern
# is the *whole* invocation shape, not a bare word.
#
# `npm start` is included: for an Astro/Vite project it is an alias for the dev
# server often enough that assuming otherwise is the wrong default, and a
# project that means something else by it can add an exception here.
server_re='(^|[;&|(][[:space:]]*|[[:space:]]&&[[:space:]]|[[:space:]]\|\|[[:space:]])[[:space:]]*'
server_re+='((rtk[[:space:]]+(proxy[[:space:]]+)?)?((npm|pnpm|yarn|bun)[[:space:]]+(run[[:space:]]+)?(dev|start|serve|preview)'
server_re+='|(npx[[:space:]]+)?(astro|vite|next|nuxt|remix)[[:space:]]+(dev|preview|start)'
server_re+='|(npx[[:space:]]+)?(vite|serve|http-server|live-server)([[:space:]]|$)'
server_re+='|python3?[[:space:]]+-m[[:space:]]+http\.server'
server_re+='|(npx[[:space:]]+)?astro[[:space:]]+dev))'

printf '%s' "$cmd" | grep -qE "$server_re" || exit 0

jq -n '{
  hookSpecificOutput: {
    hookEventName: "PreToolUse",
    permissionDecision: "deny",
    permissionDecisionReason: "Long-running local servers are never started unasked (CLAUDE.md → \"Hand it back testable\"): the process outlives the turn, holds a port, and is invisible to whoever did not ask for it. Verify with a build (`npm run build`) instead, then hand the owner the command to run. If the owner explicitly asked for a server, re-issue with --force-server."
  }
}'
