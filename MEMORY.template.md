<!--
  TEMPLATE — the reusable pattern behind this repo's MEMORY.md, not active
  instructions. Copy this into a new project as MEMORY.md and fill in the
  routing table with that project's actual doc names; delete this comment
  block once adapted.

  The pattern: one fact, one home, everything else links to it. This file
  never stores memories itself — it only says where each kind of knowledge
  belongs, so agents and humans stop re-deciding that per session.
-->

# MEMORY.md — Where Knowledge Lives

One fact, one home; everything else links to it. This file records the
decision and the routing rules — it is **not** itself a memory store.

## The decision

**Project memory belongs in the repository.** Repo docs are versioned,
reviewable, and readable by every agent and every human — no agent lock-in,
no duplication. A private vault or an assistant's own memory feature is a
satellite, not a source of truth.

## Routing

| Knowledge | Home | Examples |
| --- | --- | --- |
| Conventions, doctrines, gates | `{{AGENT_CONVENTIONS_FILE}}` + `{{DOCS_DIR}}` | Coding standards, quality gates |
| Current state of the ground | `{{STATE_FILE}}` | "What exists vs. what's planned" |
| Defects, debt, risks | `{{GAPS_FILE}}` | Known issues, tracked follow-ups |
| Lessons that changed how you work | `{{LEARNING_FILE}}` (append-only) | Why a process changed |
| Tooling decisions | `{{TOOLING_DOC}}` | Why a tool was or wasn't adopted |
| Audit findings | `{{AUDITS_DIR}}` (append-only) | Review reports |
| Cross-project, durable knowledge | a personal knowledge base outside the repo, if you keep one | Reusable patterns, milestones |
| Assistant-private session facts | wherever your tooling persists them | Small pointers only; anything shareable graduates into the repo |

## Rules

- Never restate a repo-recorded fact anywhere else — link to the file
  instead.
- When a private/satellite note turns out to be project-relevant and
  durable, promote it into the matching repo doc and delete the satellite
  copy.
- Convert relative dates to absolute when writing anything here.
