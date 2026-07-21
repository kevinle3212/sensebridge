# Notes

Shared, committed project notes — the public half of a deliberate two-file
split:

| File | Visibility | Contents |
| --- | --- | --- |
| **`NOTES.md`** (this file) | **Public** — committed, linted, secret-scanned | A curated digest: durable, contributor-facing findings, each pointing at the canonical doc |
| **`NOTES.local.md`** | **Private** — gitignored, never committed | The full session-handoff trail, personal setup, and machine-specific notes |

Anything committed here is public the moment the repo is pushed, and stays in
git history even if deleted later. When in doubt, put it in `NOTES.local.md` —
moving a note from private to public is easy, the reverse is not.

## What belongs here

A **digest, not a duplicate**. Each entry is a few lines that say what was
learned and link to the doc that owns the detail. If a finding has a
purpose-built home, it goes there and gets a pointer here — never a second copy:
[`docs/`](docs) for anything durable and structured, [`GAPS.md`](GAPS.md) for
tracked defects, debt, and risks, [`TODO.md`](TODO.md) for the short
come-back-to-it list, [`audits/`](audits) for filed findings.

Write an entry when a session produces something a *future contributor* would
want and would otherwise rediscover the hard way. Most sessions produce nothing
that qualifies; that is fine and expected.

## What must not

- Secrets, credentials, tokens, or signing material — see
  [`docs/ENVIRONMENT.md`](docs/ENVIRONMENT.md).
- Absolute machine paths (`/Users/<name>/…`), local hostnames, or ports.
- Session mechanics: what stalled, tool/account state, half-formed reasoning.
  That is what `NOTES.local.md` is for.

The first two are enforced, not merely requested:
[`tools/check-sensitive-files.mjs`](tools/check-sensitive-files.mjs) runs on
every commit via [`.githooks/pre-commit`](.githooks/pre-commit) and blocks
staged files containing credential material or hardcoded home-directory paths.
It scans staged and tracked files only, so it never sees — and never protects —
`NOTES.local.md`. That file's safety comes from being gitignored.

## Private notes (`NOTES.local.md`)

Gitignored via [`.gitignore`](.gitignore), excluded from markdownlint via
[`.markdownlintignore`](.markdownlintignore), and never committed. It holds the
full session-handoff trail written by [`/handoff`](.claude/commands/handoff.md),
plus personal setup and machine-specific configuration. Its transient twin
`tmp/handoff.md` is likewise gitignored and auto-loads on the next `/clear`.

Full handoffs go there, never here: they routinely carry absolute job paths and
machine state. This file gets only the curated digest distilled from them.

---

## Digest

### 2026-07-16 — Impeccable: one root, one context

- **The five `impeccable` skill copies are not duplicates.**
  `.agents|.claude|.cursor|.gemini|.github/skills/impeccable/` are a
  multi-provider build produced by `npx impeccable install` — the content is
  *supposed* to differ per target (invocation prefix, script paths, model name,
  `AGENTS.md` vs `CLAUDE.md`, Codex-only sections). A pairwise diff of all 102
  shared files found zero accidental drift. **Never hand-edit one copy**; use
  `npx impeccable check` / `update`. An earlier audit spot-checked two files and
  mistook the build for drift — don't repeat that. See
  [`docs/TOOLING.md`](docs/TOOLING.md) → "Impeccable design-QA".
- **Impeccable roots its state at the current working directory.** With no
  monorepo marker (this repo has none), its project root is just the cwd, so
  running it from a subdirectory silently creates a stray `.impeccable/`. The
  repo root is the only supported root — the editor hook hard-keys there via the
  `.git` marker. CI must run it from the root and pass `website` as a target.
  See [`docs/TOOLING.md`](docs/TOOLING.md) → "Impeccable project root".
- **The site's design context lives in `.agents/context/`, not `website/`.**
  Impeccable resolves context as project root → `.agents/context/` → `docs/`,
  so context left in `website/` was never found: it silently loaded
  [`docs/PRODUCT.md`](docs/PRODUCT.md) (the *app's* strategy doc) with no
  `DESIGN.md` at all, leaving the detector's design-system rules inert. Two
  files are named `PRODUCT.md` on purpose, with different scopes. Do not "tidy"
  the context back next to the site it describes. See
  [`docs/TOOLING.md`](docs/TOOLING.md) → "Impeccable design context".

---

Need help? See [`SUPPORT.md`](SUPPORT.md).
