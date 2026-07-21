---
description: Print a copy-paste-ready `claude` CLI invocation (optional sleep delay, model, effort, --dangerously-skip-permissions, heredoc prompt) for a later unattended run — e.g. before bed. Never executes it.
---

# claude-cli

Formats a ready-to-paste shell command for a later, unattended `claude` run
(the "before bed" pattern). **Only prints the command — never run it
yourself**, even if asked to "just run it." `--dangerously-skip-permissions`
means zero confirmation prompts for however long the run takes; only the
user, pasting it into their own terminal at the time they choose, should
trigger that.

## Usage

`/claude-cli [--model <id>] [--effort <level>] [--sleep <duration>] -p "<prompt>"`

- `--model` — defaults to `claude-opus-4-8` if omitted.
- `--effort` — one of `low`/`medium`/`high`/`xhigh`/`max`; defaults to `high`
  if omitted.
- `--sleep` — optional delay before running, e.g. `1h 10m`, `45m`, `2h`. Omit
  it (or pass `none`) for no delay — the command runs immediately when
  pasted, with no `sleep &&` prefix.
- `-p` / prompt text — required. What the unattended run should do. If it's
  missing, ask for it — don't invent a task.

## Steps

1. Parse `$ARGUMENTS` for the flags above.
2. If no prompt text was given, ask what the unattended run should do before
   producing anything.
3. Build the command in exactly this shape, substituting the resolved
   values (drop the `sleep <duration> &&` line entirely when no `--sleep`
   was given):

   ```bash
   sleep <duration> && claude \
     --model <model> \
     --effort <effort> \
     --dangerously-skip-permissions \
     -p "$(cat <<'PROMPT'
   <prompt text, verbatim>
   PROMPT
   )"
   ```

4. Output that block as a fenced `bash` code block and nothing else
   executable — no tool calls, no running it.
5. Follow the block with one line reminding the user what
   `--dangerously-skip-permissions` means for that run (no confirmation
   prompts for its full duration) and to re-read the prompt text before
   pasting.
