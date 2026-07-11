# GAPS.md

Known defects, debt, and risks, verified against the working tree on
2026-07-11. Update when items are fixed; move resolved entries to
`## Resolved` with a date. Severity: **Critical** (breaks correctness/security
now) · **High** (will cause real failures or drift soon) · **Medium**
(friction, waste, risk) · **Low** (polish).

## High

### H1 — The app does not exist yet

Everything downstream — tests, accessibility gates, model licensing, device
validation — is blocked on scaffolding `app/`. CI and docs are wired to
activate when it lands. This is the top milestone in `SETUP-STATUS.md`, not an
oversight; it is listed here because every other gate is moot until it closes.

## Medium

### M1 — `ANTHROPIC_API_KEY` repo secret not configured

`claude.yml` and `claude-code-review.yml` fail until it is set (GitHub →
Settings → Secrets → Actions). Core CI and security workflows are unaffected.

### M2 — Branch protection and auto-merge not enabled

`dependabot-automerge.yml` needs "Allow auto-merge" plus branch protection on
`main` requiring the CI checks. Until then the automation is inert.

### M3 — No static analysis job for Swift yet

Deliberately deferred: add a Semgrep job (`p/swift`) to
`.github/workflows/security.yml` when `app/` lands, alongside SwiftLint in CI.
Adding it now would scan nothing and cost CI minutes.

## Low

### L1 — Leftover empty `.cursor` stub subdirectories

`.cursor/{context,instructions,settings}/` are empty untracked noise (the
live config is `.cursor/rules/` + `.cursor/mcp.json`). Delete locally at will.

## Resolved

- **2026-07-11** — Per-agent configuration was Claude-only → `.codex/`
  (AGENTS.md, `config.toml`, `hooks.json`), `.gemini/settings.json`,
  `.copilot/` (instructions + MCP), `.continue/rules/`, `.windsurf/` (rules +
  MCP), `.openclaw/README.md`, `.cursor/mcp.json`; verified Claude plugins
  (superpowers, claude-mem, humanizer) installed at user scope. See
  `docs/TOOLING.md`.

- **2026-07-11** — No pre-commit gate existed → `.githooks/` (gitleaks staged
  scan, sensitive-file check, lint, conventional-commit header) enabled via
  `scripts/setup.sh`.
- **2026-07-11** — No root orientation docs → `PROJECT_OVERVIEW.md`, `WIKI.md`,
  `MEMORY.md`, `LEARNING.md`, `docs/TOOLING.md`.
- **2026-07-11** — No agent entry points for Gemini/Cursor/Copilot →
  thin pointers to `AGENTS.md` (no duplicated instructions).
- **2026-07-11** — No project MCP config → `.mcp.json` (Serena, local-only).
- **2026-07-11** — `.DS_Store`, `graphify-out/`, `.claude/worktrees/`
  ungitignored → added to `.gitignore`.
- **2026-07-11** — Two days of bootstrap work sat uncommitted on `main` →
  imported on branch `chore/ai-workspace-bootstrap`.
