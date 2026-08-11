#!/usr/bin/env bash
# Self-check for guard-long-running-server.sh. Two halves matter equally: every
# shape that actually holds a port must be denied, and the build/test commands
# this repo runs constantly must stay silent — a guard that blocks `npm run
# build` would be turned off within the hour.
#
# Run: bash .claude/hooks/global/tests/guard-long-running-server.test.sh
set -uo pipefail

HOOK="$(cd "$(dirname "$0")/.." && pwd)/guard-long-running-server.sh"
failures=0

# Emits "deny" when the hook blocks, "allow" when it stays silent.
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

# --- must be denied -------------------------------------------------------
expect deny 'npm run dev'
expect deny 'cd website && npm run dev'
expect deny 'npm start'
expect deny 'pnpm dev'
expect deny 'yarn dev'
expect deny 'npx astro dev'
expect deny 'astro preview'
expect deny 'npx vite'
expect deny 'vite preview'
expect deny 'next dev'
expect deny 'python3 -m http.server 8000'
expect deny 'npx serve dist'
expect deny 'rtk npm run dev'
expect deny 'rtk proxy npm run dev'
expect deny 'npm run build; npm run dev'
expect deny 'npm run build && npm run dev'

# --- must stay silent -----------------------------------------------------
expect allow 'npm run build'
expect allow 'npm run lint:js'
expect allow 'npm run app:install'
expect allow 'npm test'
expect allow 'npm run build:dev'
expect allow 'swift build'
expect allow 'xcodebuild build -scheme SenseBridge'
# Prose describing a server is not a server: quoted literals are blanked.
expect allow 'echo "next step: run npm run dev yourself"'
# Heredoc bodies are file content, not commands.
expect allow "cat <<'EOF' > notes.md
run npm run dev to preview
EOF"
# The owner-typed override.
expect allow 'npm run dev --force-server'
# Serena's MCP server: explicitly exempted, not just a regex non-match.
expect allow 'serena start-mcp-server --context=claude-code --project .'
# A path that merely contains a server binary's name.
expect allow 'node tools/vite-report.mjs'
expect allow 'rtk grep -n "astro dev" docs/'

if [ "$failures" -eq 0 ]; then
  echo "guard-long-running-server: all cases pass"
else
  echo "guard-long-running-server: $failures failing case(s)"
  exit 1
fi
