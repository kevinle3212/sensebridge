---
name: update-context
description:
    Keep docs, comments, agent instructions, and visible project surfaces
    synchronized after code, config, workflow, or documentation changes.
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

# Update Context

Use this skill after a prompt causes repository changes, especially when the
change affects behaviour, build steps, models, permissions, workflows, tests,
user-facing copy, or agent guidance.

## Workflow

1. Identify the changed surface: Swift code, build/project config, workflow,
   docs, models, tests, permissions, or agent instructions.
2. Update the nearest authoritative documentation instead of duplicating long
   guidance. Prefer `docs/`, `README.md`, `.cursor/rules/`, `.codex/AGENTS.md`,
   `CLAUDE.md`, or the relevant `.agents/` file based on scope.
3. Keep the root orientation docs current — mandatory, not optional, whenever
   the change makes them stale:
   - `GAPS.md` — a defect/debt item was fixed (move it to `## Resolved` with
     the date), a new gap was discovered (add it with severity + evidence),
     or something planned was completed or deferred.
   - `PROJECT_OVERVIEW.md` — the layout, milestones, or state of the ground
     changed (e.g. `app/` scaffolded, a new top-level directory or gate).
   - `WIKI.md` — any doc was added, removed, moved, or renamed.
   - Also: `GAPS.md` when set-up/pending status shifts,
     `docs/TOOLING.md` when a tool or MCP server is added or removed, and
     `LEARNING.md` when a lesson changed how we work.
4. Remove or update stale references to moved or renamed code, screens, scripts,
   models, workflows, or legal/doc files. `CONTRIBUTING.md` links to `app/`,
   `.github/` templates, `docs/ENVIRONMENT.md`, and `docs/TESTING.md` — keep
   those targets real.
5. Update comments only when the surrounding code would otherwise mislead.
   Remove stale comments rather than adding new ones.
6. Add or adjust tests and validation steps when behaviour or tooling changes.
7. For user-facing copy, follow the
   [capitalization](../capitalization/SKILL.md) skill (Title Case vs. sentence
   case, acronym handling).
8. Anything describing spoken output or the physical world must honour the
   awareness-not-safety doctrine (`docs/SAFETY-FRAMING.md`).
9. If a mistake took substantial debugging to fix, or a complex problem took a
   long time to solve, run the
   [lessons-learned](../lessons-learned/SKILL.md) skill to capture it in its
   correct durable home. Do not record typos or routine fixes.
10. Keep run notes under `logs/` as readable Markdown (see the `log-markdown`
   skill).

## Validation

Run the narrowest checks that prove context stayed current — e.g. confirm links
resolve and any changed build/test step still runs (`xcodebuild build`,
`swift test`) — and note honestly what was not verified.
