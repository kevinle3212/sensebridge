---
name: log-markdown
description:
    Format any file written under logs/ as readable ignored Markdown.
---

## Tool Fallback <!-- tool-fallback -->

- If a preferred tool, command, or skill is unavailable, failing, or a worse fit
  for the task, use the best available alternative rather than stopping or
  forcing it. Note which tool you used and why. Never fall back to a tool the
  repository or user has explicitly prohibited.

## Clarify Before Acting <!-- clarify-before-acting -->

Before running this skill or producing output, if the request is ambiguous or the
desired outcome is unclear, interview the user with focused questions until intent
is unambiguous. State assumptions and confirm them before proceeding.

# Log Markdown

Use this skill before writing or updating any file under `logs/`.

## Requirements

- Use Markdown, not plain text, JSON, ANSI terminal output, or raw command
  dumps.
- Use one top-level `#` heading.
- Use sentence-case headings.
- Leave one blank line around headings, tables, lists, and fenced code blocks.
- Use fenced code blocks with language tags for commands or snippets.
- Keep list indentation flat unless hierarchy is required.
- Keep table columns concise.
- Do not include secrets, tokens, `.env` values, raw credentials, or any user
  content captured by the app (recognised text, images, audio).
- Prefer summaries over full noisy command output.

## Notes

`logs/` is ignored by git. Keep run notes and audit scratch here as readable
Markdown summaries rather than raw terminal dumps.
