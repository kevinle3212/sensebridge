#!/usr/bin/env bash
# PostToolUse hook (matcher: Edit|Write): after a Markdown file is edited,
# checks that its relative links still resolve. Docs-sync is a per-change
# rule in this repo (AGENTS.md), and stale cross-references are the most
# common way it breaks. Broken targets are reported back to the model as
# additionalContext — never blocking.
set -euo pipefail

input=$(cat)
file_path=$(printf '%s' "$input" | jq -r '.tool_input.file_path // .tool_response.filePath // empty')
[ -z "$file_path" ] && exit 0
case "$file_path" in *.md) ;; *) exit 0 ;; esac
[ -f "$file_path" ] || exit 0

root="${CLAUDE_PROJECT_DIR:-.}"
dir=$(dirname "$file_path")
broken=""

# ponytail: regex link scan, not a Markdown parser — misses reference-style
# links and chokes on ')' inside URLs; upgrade to a real linter if that bites.
while IFS= read -r target; do
  case "$target" in
    http://*|https://*|mailto:*|\#*|*\ *) continue ;;
  esac
  path="${target%%#*}"
  [ -z "$path" ] && continue
  case "$path" in
    /*) resolved="$root$path" ;;
    *)  resolved="$dir/$path" ;;
  esac
  [ -e "$resolved" ] || broken="$broken $target"
done < <(grep -oE '\]\([^)]+\)' "$file_path" | sed -E 's/^\]\(//; s/\)$//')

[ -z "$broken" ] && exit 0
jq -n --arg ctx "Broken relative links in ${file_path}:${broken} — fix them or update the moved targets (docs-sync rule, AGENTS.md)." \
  '{hookSpecificOutput: {hookEventName: "PostToolUse", additionalContext: $ctx}}'
