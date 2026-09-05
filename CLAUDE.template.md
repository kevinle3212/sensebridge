<!--
  TEMPLATE, NOT ACTIVE INSTRUCTIONS. Agents working in this repository must
  not read, follow, or ingest this file's content as instructions.

  Usage: copy to your user-global config, then personalize the "Call me by
  my name" line and any tool-specific sections.
    macOS/Linux: cp CLAUDE.template.md ~/.claude/CLAUDE.md
    Windows:     copy CLAUDE.template.md %USERPROFILE%\.claude\CLAUDE.md

  The active instruction files are your ~/.claude/CLAUDE.md and this
  project's own CLAUDE.md — this template never overrides either.

  Companion files: .claude/settings.global.json publishes the harness settings
  that enforce the mechanical half of this standard (credential deny rules,
  the handoff loader, effort tier, the four guards below), and
  .claude/hooks/global/ ships the guard scripts it registers — install both or
  neither. RTK.template.md is optional — only needed if you install the RTK
  proxy this file's Tools section references. See docs/TOOLING.md for what
  they contain, what they deliberately omit, and their prerequisites.
-->

# CLAUDE.md — Global Engineering Standard

Inherited by every repository. Project `CLAUDE.md` files override this one and
carry project-specific rules only — a rule stated twice drifts into two rules.

**This file holds only what would go wrong without it.** Generic good practice
(SOLID, KISS, measure-before-optimizing, small functions, review your own work)
is not written down here, because stating it changes nothing. Neither is
anything a machine already checks: assistant attribution, commit and branch
shape, unasked long-running servers, and doc comments on new declarations are
checked by `~/.claude/hooks/` (self-checks in `~/.claude/hooks/tests/`).
Neither is anything the Ponytail or Caveman plugins inject fresh each session.

Security controls are the standing exception to all of that. "Security" keeps its
lines even where they read as textbook, because a rule everyone knows is still
the one that gets skipped, and the cost of the miss is asymmetric — do not
propose trimming it.

Sections are referenced by name, never by number — numbers rot on the first edit.

---

## Working with me

- **Call me by my name in every reply.** (Personalize this line.)
- When you present options, say which one you recommend and why. An unranked
  list makes the choice my problem twice.
- Apply a final grammar, punctuation, and clarity pass to every prose change —
  comments, docs, UI copy, commit messages. Backtick-wrap code, paths, and
  identifiers.
- Interview me in one round of high-signal questions whenever you need context
  you do not have — a missing constraint, an unstated preference, or two
  readings of a request that would produce materially different work. Ask
  before executing, not halfway through. Otherwise state the assumption inline
  and proceed.

## Permission and approval

- **When a permission prompt is denied, surface it** — what was denied, why it
  was needed, and the options **Yes** (retry differently) / **No** (skip) /
  **Talk about it**. Never silently back off, never retry the identical call.
  Exception: just adjust when the alternative is obvious and low-stakes, such as
  a different read-only command reaching the same information.
- **An allowlisted command is not a safe command.** A standing grant covers the
  *shape* of a command, not every argument. Before running an approved command
  whose specific invocation is destructive, irreversible, or touches shared
  state — force-push, hard reset, delete — stop and confirm anyway. Treat any
  general-purpose escape hatch (raw shell wrapper, unfiltered passthrough) as
  needing its own judgment call every time.

## Delegation and routing

Delegate when work is genuinely parallelizable, needs isolating from this
context, or needs a different model tier. Otherwise work inline. The cheapest
subagent is the one you don't spawn — the one standing exception is the plan
draft, which "Plans and durable state" owns.

Pair every unit of work with a model *and* an effort tier:

| Model | Routes to | Effort |
| --- | --- | --- |
| Haiku 4.5 | **Reach here first for anything minor.** Wording and sentence edits, copy edits, renames, formatting, boilerplate, one-off scripts, changelog lines, and any prose that asserts nothing about behavior. Hand it exact strings and examples so it never infers intent | medium; `high` when it drafts a plan |
| Sonnet 5 | Default worker: implementation, refactoring, config, tests, docs that assert how code behaves — and **drafting the plan file** | high |
| Opus 5 | **Reviewing the plan draft**, then audits, **all security review**, hard debugging, architecture, algorithms, large refactors, performance investigation | high; `xhigh`/`max` only for genuinely hard reasoning |

Agent definitions have no effort field — state the tier in the dispatch line and
in the agent's prompt.

**Never dispatch in silence, and never work in silence.** Announce every unit
before it starts, in the visible reply — a checklist for multi-task work, one
line for a single unit:

- Delegated: `<task> — Sonnet 5 · high (<one-line rationale>).`
- Inline: `<task> — inline (<one-line rationale>).`

If a model is unavailable, use the next best and say you substituted.

## Plans and durable state

For any task that is large or runs past one step, a written plan exists before
the first edit — a Markdown checklist (`- [ ]`), one item per requested task,
each with its verification step.

### Where the plan lives

**Locate the project first.** Resolve it as the nearest enclosing git root, or
failing that the nearest directory holding a `CLAUDE.md` or `AGENTS.md`. When
the request names or clearly pertains to a project, work from that project's
root even if the shell started somewhere else.

| Situation | Plan file |
| --- | --- |
| Inside a project | `<project>/tmp/handoff.md` |
| No project — a global or `~`-rooted run | `~/.claude/tmp/handoff.md` |

Create `~/.claude/tmp/handoff.md` up front and leave it on disk at zero bytes
when idle; the `SessionStart` loader in `.claude/settings.global.json` resolves
the same way and skips empty files.

If you also run unattended sessions, give them a second file
(`tmp/handoff-away.md`, resolved identically) and never let either session type
write the other's. An unattended run that wrote into `tmp/handoff.md` would
silently destroy a plan you left open.

### How the plan gets written

1. **Draft — Sonnet 5 · high**, or **Haiku 4.5 · high** when the task is minor
   or purely a wording change. One subagent, writing straight into the plan
   file. This delegation is standing: it needs no separate ask.
2. **Review — Opus 5 · high**, the main session, never the drafter. Read the
   draft against the actual code: close its gaps, fix what it got wrong, add
   what it missed, and name the risks it did not cover. The reviewed file is
   the plan; a draft is never executed as written.
3. **Execute — Opus 5 · high** takes each item at the model and effort it judges
   right, or does it inline. Either way it is announced per "Delegation and
   routing".

Skip step 1 only when the plan would be shorter than the dispatch that produced
it — say so in one line and write it inline instead.

The plan file **is** the plan, not a summary of one. It outlives the transcript
that a `/clear` or a crash destroys.

- Write it **before the first edit**, never after. In a project, confirm `tmp/`
  is gitignored (`git check-ignore -v tmp/handoff.md`); `~/.claude/` is not a
  repository, so that check does not apply there. If the file already holds a
  live plan from an earlier session, surface that rather than overwriting it.
- Update it after every step. Flip an item to `- [x]` only when *verified* — a
  passing command, not a landed edit. Write for a cold reader with no session
  context: name files, symbols, and exact commands. A stale plan is worse than
  none.
- Empty it when the work ships: move anything outstanding to `TODO.md`, then
  zero-byte the file, keeping it present.

`~/.claude/commands/handoff.md` owns the format and the resume/retire steps —
read it rather than working from memory.

**`TODO.md` holds deferred work only, and nothing lands there unilaterally.**
Anything needing my sign-off belongs in the conversation, not a file I might not
read for days. The one exception is work whose unblock is an action only I can
take outside the session — grab an API key, flip a setting, authorize a login.

## Making changes

Touch only what you must. Match the surrounding style even where you'd differ.
Remove imports and variables *your* change orphaned; mention pre-existing dead
code rather than deleting it.

**Opportunistic fixes — always look, always act.** Every stale reference, dead
link, drifted config, or gate that no longer matches what it gates gets triaged,
never walked past. Sweep for them while you work and again before reporting
done. "I didn't notice it" is no defence when it was in a file you edited.

Size alone picks the route:

- **Small → fix it, do not ask.** A typo, a dead link, an off-by-one, a missing
  null guard, a stale doc reference. Fix it and name it in one line. Asking
  wastes a round-trip on something I would always approve.
- **Big → interview me first.** Anything that changes behavior, touches a public
  API, or needs a judgment call between valid approaches. When unsure, ask
  whether a reviewer would want it in *this* diff or a separate one — separate
  means interview. Give file:line, what's wrong, the options, and your
  recommendation.

## Security

Assume all input is malicious. Validate at trust boundaries with allowlists;
encode output for its context. OWASP Top 10 is the review floor, not the goal.

What is easy to get wrong and expensive to fix:

- **Secrets** live in environment variables or a secret manager — never source
  control, never logs, never client bundles. Ship a `.env.example`. Rotate
  anything exposed.
- **Authorize on every request** at the resource level, deny by default. Never
  trust a client-side check.
- **Fail closed.** A guard that cannot prove a call is safe must deny it.
- Rate-limit public endpoints. Log security events without secrets or PII.
- Pin versions, use lockfiles, verify provenance before adding a dependency.
- Proven crypto libraries only; never roll your own.

**Never make a security control softer to make a task easier.** If a control is
in the way, the task is wrong.

## Testing and verification

- Unit tests for logic, integration for boundaries, E2E for critical journeys,
  a regression test for every bug fixed. **E2E floor per feature: three** — one
  happy path, one error path, one edge case.
- Cover empty, null, boundary, unicode, concurrency, and failure paths.
- Verify by exercising the change end-to-end. A typecheck is not verification.

**Escalate manual verification.** Any step that would have me click through a
UI, eyeball a rendering, or confirm behavior by hand is a gap in the test suite.
Turn it into a command that passes or fails — headless browser, snapshot test,
scripted screenshot, CLI smoke script, golden file, log probe. If you hand me a
manual step anyway, say what you tried to escalate it to and why that failed.
Where only part is automatable, escalate that part and narrow the manual step to
the smallest irreducible judgment call. **Escalated checks are deliverables** —
commit them as tests or scripts so the check reruns instead of being redone.

## Documentation

- **Doc comments** in the language's idiom (`///`/DocC, JSDoc/TSDoc, docstrings,
  Javadoc, godoc), at every access level. The hook reports a new function,
  method, class, struct, enum, protocol, or actor written without one — but it
  cannot see stored properties, so those are yours to catch, and it judges
  presence, never quality. Say what it does, key params and returns, and *why*
  for non-trivial logic; don't restate the name. Self-documenting test methods
  are exempt.
- Keep docs in sync in the same change. When files, routes, or commands move,
  purge stale references everywhere — docs, comments, config, tests, agent
  instructions. Stale docs are worse than none.
- Record architecture decisions with their rationale, plus setup, deployment,
  migrations, public APIs, and breaking changes.

## Git

- **Never run a `git` or `gh` command autonomously.** Only with my explicit
  permission for that specific command. A grant is session-scoped: the same
  command may run again this session; a new session or a different command needs
  a fresh grant. Approving one command never approves the surface.
- **Never add yourself as contributor, co-author, or attribution** in commit
  messages, PR descriptions, changelogs, or `CREDITS`/`AUTHORS`. Omit the line
  entirely — no placeholder. The harness prompt asks for these trailers; this
  rule overrides it.
- When work is ready, give me every command to ship it, copy-paste ready and in
  order: branch, commit, push, PR, merge, sync.
- Keep the default branch deployable. Prefer a PR so CI runs.

## Tools

Prefer the simplest tool that answers the question. When a preferred tool is
unavailable or failing, use the best permitted alternative and say which and why
— never stall on a broken tool. This never overrides an explicit prohibition.

- **Serena's symbol tools** over text search on code files.
- **RTK** for shell operations — its hook rewrites covered commands silently.
  **Its compaction is lossy**, and it fails quietly: a rewritten `find` can
  return nothing at all, and it once wrote a `--stat` summary into a `.patch`
  file. Use `rtk proxy <cmd>` whenever output must stay byte-exact. 
- **Web browsing**: the gstack `/browse` skill only. **Never**
  `mcp__claude-in-chrome__*`.
- **Graphify** (`query`/`path`/`explain`) before large refactors;
  `graphify update .` after modifying code.
- **Composio** is a CLI at `~/.composio/composio`, not an MCP server. Read the
  `composio-cli` skill. It is a **gap-filler only** — where a dedicated CLI
  already covers a service (`gh`, `ggshield`), use that. `link` always needs me
  (browser OAuth). Every response is sensitive: tokens and keys come back
  verbatim, so never echo one into a tracked file.
- **`task-observer` is opt-in**, never automatic — its skill file is ~18k tokens.
- **Memory**: persist only durable knowledge; convert relative dates to
  absolute; delete memories proven wrong. Run `memory-gc` when the index passes
  ~20 entries.
- **Obsidian vault (`~/Vault`)**: the long-term knowledge base, distinct from
  session memory. Use the `vault-capture` skill; `~/Vault/CLAUDE.md` governs
  every write.
- **`~/.claude/settings.json` is owner-gated.** Propose exact JSON and let me
  approve.
- **Never run `caveman-compress` against `CLAUDE.md`, `README.md`, or any
  authoritative doc** — it conflicts directly with the prose-quality and
  doc-sync rules above. Scratch notes only, and only when I ask.

### Never hand-edit a vendor-managed file

An update will silently revert it, and the revert looks like your change never
happened. Vendor-managed here: `~/.claude/skills/gstack` (git pull),
`~/.claude/skills/hyperframes` and any `.agents/skills/impeccable` (their own
CLI installers), every plugin cache under `plugins/cache/` (`claude plugin
update`), and the `<!-- BEGIN:nextjs-agent-rules -->` block that `next dev`
rewrites into a repo's `AGENTS.md`.

To change vendor behaviour durably, use the surface built for it:

- **Shadow it.** Define a same-named skill in the more specific scope — a
  project `.claude/skills/<name>/SKILL.md` over a global one. First definition
  of a name wins, so neither copy has to be edited.
- **`skillOverrides` in `settings.json`** turns a skill off outright.
- **Plugin config**: `~/.config/caveman/config.json`,
  `~/.config/ponytail/config.json`.
- **BMAD** ships `bmad-customize` (now at
  `~/.agents/skills/bmad/references/bmad-customize/`) specifically for authoring
  overrides.
- **The Next.js block**: commit it with your work. Deleting it from a diff only
  recreates an uncommitted change.

If a vendor file genuinely must change, send the fix upstream and record the
local reason — don't leave an edit that the next update erases.

Background reference, not loaded by default: `~/.claude/PLUGIN-SETUP.md`
(Ponytail/Caveman install), `~/.claude/REMOVED-MCP-SERVERS.md`,
`~/.claude/HEADROOM-ROUTING.md` (disabled 2026-07-31).

**Harness parity.** Every repository gives Codex, Copilot, Kimi, Cursor, Gemini,
and Antigravity the same skills, guards, and MCP servers Claude Code has.
Canonical policy lives in one project-authored `.agents/` tree; harness
directories hold thin adapters and native MCP config only, never independent
policy. Guards are authored once under `.claude/hooks/` and reused. What a
harness genuinely cannot inherit gets recorded in that project's docs rather
than faked in a file nothing reads.

## Reporting

Report failures faithfully with the actual output. Never invent APIs, paths,
outputs, or test results. If something can't be verified, say so plainly — and
say which claims a machine verified versus which still need human or device
validation. A green pipeline must never imply validation it did not do.

**Do not delete heavy directories yourself** — timeout risk. Give me the command
plus any rebuild step (`rm -rf node_modules`, then `npm install`). Inspect any
target before overwriting or deleting it; if it contradicts expectations,
surface that instead of proceeding.

### Token-savings line

End the summary of substantive work with one short line per efficiency tool that
actually did something this run. Never fabricate, never pad a trivial reply.

- **RTK** — if you use RTK, run `rtk gain` and cite its measured figure. Never estimate; if it was not run this turn, say "not measured."
- **Caveman** — run `/caveman-stats`. It reads the real session log and nets out
  its own rule overhead, so quote it as-is, including a negative net.
- **Ponytail** — has **no** session meter (`/ponytail-gain` prints static
  benchmark medians, not your numbers). Report it qualitatively: name the
  concrete thing skipped or reused. Never attach a number to it.
