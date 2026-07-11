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

### M4 — Bootstrap branch is local-only

`chore/ai-workspace-bootstrap` has never been pushed; no PR exists, CI has
never run on this work, and the GitHub-side workflows (Claude review,
security scans) are unproven. Push + PR are the next concrete action.

## Low

### L1 — Leftover empty `.cursor` stub subdirectories

`.cursor/{context,instructions,settings}/` are empty untracked noise (the
live config is `.cursor/rules/` + `.cursor/mcp.json`). Delete locally at will.

## Not yet done (full inventory, 2026-07-11)

Everything known to be incomplete, uninstalled, or unverified — so nothing
hides behind "bootstrap complete". Cross-references: `SETUP-STATUS.md`
(milestones), `docs/TOOLING.md` (tool decisions).

**Repository / GitHub (needs owner or push access)**

- Push `chore/ai-workspace-bootstrap` + open/merge the PR (M4).
- `ANTHROPIC_API_KEY` repo secret (M1); branch protection + auto-merge (M2).
- Enable GitHub Discussions (the issue-template support link points there).

**Application (the real work)**

- `app/` Xcode project / Swift package — not scaffolded (H1).
- SwiftLint/SwiftFormat config files — land with `app/`.
- Test targets per `docs/TESTING.md` — none exist.
- First on-device model — nothing vendored; must pass `model-license-audit`.
- TestFlight / App Store distribution — requires the paid Apple Developer
  Program (`docs/DISTRIBUTION.md`).

**CI additions deferred until `app/` exists**

- Semgrep `p/swift` job (M3); SwiftLint job in `ci.yml`.

**This machine**

- `xcode-select` points at CommandLineTools, not full Xcode — must be fixed
  before scaffolding `app/` (`sudo xcode-select -s /Applications/Xcode.app`).
- Agent CLIs not installed: `gemini`, `copilot`, `windsurf`, `openclaw`
  (project configs are committed and activate when/if installed; `.sixth/`
  deliberately not configured — tool absent and TrustLedger-specific).

**Plugins / integrations evaluated but not installed**

- Stop Slop, The Council, Caveman, Hyperframes, AI Second Brain, NotebookLM —
  no verifiable canonical source (see `docs/TOOLING.md`); revisit with a
  trusted repo URL.
- Granola, Higgsfield, Perplexity, Agent Browser — no SenseBridge use case;
  add as MCP connectors only when a need exists.

**Validation no machine can provide**

- On-device latency / battery / thermal benchmarks.
- Blind-tester (VoiceOver, eyes-free) validation — the only validation that
  ultimately counts; see the `ci-green-gate` skill.

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
