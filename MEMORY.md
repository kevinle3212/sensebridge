# MEMORY.md — where knowledge lives

One fact, one home; everything else links to it. This file records the
decision and the routing rules — it is **not** itself a memory store.

## The decision

**Project memory belongs in the repository.** Repo docs are versioned,
reviewable, and readable by every agent (Claude, Codex, Cursor, Gemini,
Copilot) and every human — no agent lock-in, no duplication. The Obsidian
vault and Claude's private memory are satellites, not sources of truth.

## Routing

| Knowledge | Home | Examples |
| --- | --- | --- |
| Conventions, doctrines, gates | `AGENTS.md` + `docs/` | Safety framing rules, quality gates |
| Current state of the ground | `AGENT-CONTEXT.md`, `SETUP-STATUS.md` | "app/ is not scaffolded yet" |
| Defects, debt, risks | `GAPS.md` | Missing repo secret |
| Lessons that changed how we work | `LEARNING.md` (append-only) | Why CI no-ops instead of failing |
| Tooling decisions | `docs/TOOLING.md` | Why there is no ESLint here |
| Audit findings | `audits/` (append-only) | Review reports |
| Cross-project, durable knowledge | Obsidian `~/Vault` via the `vault-capture` skill | Reusable patterns, milestones, debugging discoveries that outlive this repo |
| Claude-private session facts | `~/.claude/projects/<this>/memory/` | Small pointers only; anything shareable graduates into the repo |

## Rules

- Never restate a repo-recorded fact in the vault or Claude memory — link to
  the file instead.
- When a satellite note turns out to be project-relevant and durable, promote
  it into the matching repo doc and delete the satellite copy.
- Convert relative dates to absolute when writing anything here.
