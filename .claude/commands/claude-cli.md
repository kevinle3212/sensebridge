---
description: Print a copy-paste-ready `claude` CLI invocation (optional sleep delay, working directory, model, effort, --dangerously-skip-permissions, heredoc prompt) for a later unattended run — e.g. before bed. Detached with nohup/disown so it survives the terminal closing. Never executes it.
---

# claude-cli

Formats a ready-to-paste shell command for a later, unattended `claude` run
(the "before bed" pattern). **Only prints the command — never run it
yourself**, even if asked to "just run it." `--dangerously-skip-permissions`
means zero confirmation prompts for however long the run takes; only the
user, pasting it into their own terminal at the time they choose, should
trigger that.

The whole `sleep && claude ...` pipeline is written to a temp runner script
and launched with `nohup ... & disown`, so a multi-hour delay survives the
terminal being closed, the laptop sleeping, or an SSH disconnect — it doesn't
depend on the shell that started it staying alive.

## Usage

`/claude-cli [--model <id>] [--effort <level>] [--sleep <duration>] [--dir <path>] -p "<prompt>"`

- `--model` — defaults to `claude-opus-5` if omitted.
- `--effort` — one of `low`/`medium`/`high`/`xhigh`/`max`; defaults to `high`
  if omitted.
- `--sleep` — optional delay before running, e.g. `1h 10m`, `45m`, `2h`. Omit
  it (or pass `none`) for no delay — the command runs immediately when
  pasted, with no `sleep &&` prefix.
- `--dir` — optional working directory. Defaults to the current project root
  when the command is invoked inside one; omit the `cd` entirely if neither
  applies. An unattended run started from the wrong directory is the most
  common way this pattern silently does nothing useful.
- `-p` / prompt text — required. What the unattended run should do. If it's
  missing, ask for it — don't invent a task.

## Steps

1. Parse `$ARGUMENTS` for the flags above.
2. If no prompt text was given, ask what the unattended run should do before
   producing anything.
3. Build the command in exactly this shape, substituting the resolved
   values. Drop the `sleep <duration> &&` line when no `--sleep` was given,
   and drop the `cd <dir> &&` line when there is no directory to resolve.
   `<ts>` is a fresh timestamp (e.g. `$(date +%s)`) so repeated runs don't
   collide on the same runner/log path:

   ```bash
   cat > /tmp/claude-cli-<ts>.sh <<'RUNNER'
   #!/bin/bash
   sleep <duration> && cd <dir> && claude \
     --model <model> \
     --effort <effort> \
     --dangerously-skip-permissions \
     -p "$(cat <<'PROMPT'
   <prompt text, verbatim>
   PROMPT
   )"
   RUNNER
   nohup bash /tmp/claude-cli-<ts>.sh > /tmp/claude-cli-<ts>.log 2>&1 &
   disown
   echo "Backgrounded (pid $!) — tail -f /tmp/claude-cli-<ts>.log"
   ```

4. Output that block as a fenced `bash` code block and nothing else
   executable — no tool calls, no running it.
5. Follow the block with one line reminding the user what
   `--dangerously-skip-permissions` means for that run (no confirmation
   prompts for its full duration), that it's detached (survives closing the
   terminal), and to re-read the prompt text before pasting.
