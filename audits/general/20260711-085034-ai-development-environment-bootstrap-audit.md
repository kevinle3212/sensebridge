# AI development environment bootstrap audit

| Field           | Value         |
| --------------- | ------------- |
| Audit type      | general      |
| Timestamp (UTC) | 2026-07-11T08:50:34Z |
| Git branch      | chore/ai-workspace-bootstrap    |
| Commit hash     | c051241    |
| Auditor         | Kevin Khanh Le    |

## Scope

Fitness of the repository as an AI-first engineering workspace: tooling
inventory (global vs. project), agent interoperability (Claude, Codex, Cursor,
Gemini, Copilot), MCP configuration, git hygiene (hooks, commit conventions,
branch strategy), security defaults, memory/knowledge architecture (repo vs.
Obsidian vault), and documentation completeness. Cross-referenced against the
TrustLedger repository (pattern baseline) and the `andrej-karpathy-skills`
guidelines (already encoded in the global `~/.claude/CLAUDE.md`; deliberately
not installed, to avoid duplication).

Complements `20260711-035626-sensebridge-ground-up-readiness-audit.md`, which
covered the instruction/CI layer's internal consistency. Explicitly out of
scope: the Swift app (not scaffolded), model licensing (nothing vendored), any
on-device or blind-tester validation.

## Files Inspected

- `CLAUDE.md`, `AGENTS.md`, `AGENT-CONTEXT.md`, `SETUP-STATUS.md`, `README.md`
- `.agents/` (7 personas, 13 skills), `.claude/` (commands, skills)
- `.github/workflows/*` (5), `dependabot.yml`, templates, `CODEOWNERS`
- `scripts/{setup,lint}.sh`, `tools/check-sensitive-files.mjs`
- `audits/` system (guide, governance, template, generator)
- `.serena/`, `.cursor/`, `.codex/`, `.gitignore`
- TrustLedger: `.mcp.json`, `.claude/`, `.agents/`, `.gitleaks.toml`,
  `commitlint.config.js`, `.coderabbit.yaml`, `GAPS.md`, `PROJECT_OVERVIEW.md`
- Global machine state: `~/.claude/skills`, `~/.claude.json` MCP servers,
  installed CLIs (semgrep, gitleaks, swiftlint, swiftformat, gh, rtk,
  graphify, serena, ollama, node, bun, uv)

## Issues Found

| #   | Severity | Issue | Location | Status |
| --- | -------- | ----- | -------- | ------ |
| 1   | Medium   | Two days of bootstrap work (docs, CI, agents, governance) sat uncommitted/untracked on `main` — unversioned, unreviewable, one `rm -rf` from gone | repo root | Fixed |
| 2   | Medium   | No local pre-commit gate: secrets/sensitive files only caught in CI, after they enter history; commit conventions unenforced | `.githooks/` (absent) | Fixed |
| 3   | Medium   | No entry point for non-Claude agents: `.codex/` and `.cursor/*` were empty stubs; Gemini/Copilot had nothing | `.cursor/`, `.codex/`, root | Fixed |
| 4   | Medium   | No project MCP config; Serena installed globally but not wired to the repo | `.mcp.json` (absent) | Fixed |
| 5   | Low      | `.DS_Store`, `graphify-out/`, `.claude/worktrees/` not gitignored | `.gitignore` | Fixed |
| 6   | Low      | No root orientation docs (overview, gaps, memory routing, docs index) and no record of tooling decisions | repo root, `docs/` | Fixed |
| 7   | Info     | `ANTHROPIC_API_KEY` secret and branch protection/auto-merge still unconfigured (repo settings — cannot be set from a working tree) | GitHub settings | Deferred |
| 8   | Info     | No Swift static-analysis CI job yet; Semgrep `p/swift` deliberately deferred until `app/` exists | `.github/workflows/security.yml` | Deferred |
| 9   | Info     | Web-stack tooling (ESLint, Jest, Husky, Docker, K8s, Vercel, CodeRabbit, etc.) evaluated against TrustLedger and declined — no Node/web surface here; patterns were adopted, packages were not | `docs/TOOLING.md` | Won't Fix |

## Fixes Applied

- **#1** — Imported the full working tree as commit `c051241` on branch
  `chore/ai-workspace-bootstrap` (never committing to `main`, per policy).
- **#2** — Added dependency-free `.githooks/pre-commit` (gitleaks staged scan
  with shared `.gitleaks.toml`, `tools/check-sensitive-files.mjs`,
  `scripts/lint.sh`) and `.githooks/commit-msg` (conventional-commit header
  check, no commitlint/Node dependency); `scripts/setup.sh` now sets
  `core.hooksPath` and checks gitleaks/node advisorily.
- **#3** — Added thin pointers only (no duplicated instructions):
  `GEMINI.md`, `.cursor/rules/sensebridge.mdc`,
  `.github/copilot-instructions.md`. Codex reads root `AGENTS.md` natively.
- **#4** — Added `.mcp.json` with Serena (local process, project-scoped,
  least privilege). MCP inventory documented in `docs/TOOLING.md`.
- **#5** — Extended `.gitignore`.
- **#6** — Added `PROJECT_OVERVIEW.md`, `GAPS.md`, `MEMORY.md` (memory lives
  in the repo; Obsidian vault for cross-project knowledge only),
  `LEARNING.md`, `WIKI.md`, and `docs/TOOLING.md` (full global-vs-project
  decision matrix, including declined Claude marketplace skills).

## Files Modified

- Created: `.githooks/pre-commit`, `.githooks/commit-msg`, `.gitleaks.toml`,
  `.mcp.json`, `GEMINI.md`, `.cursor/rules/sensebridge.mdc`,
  `.github/copilot-instructions.md`, `PROJECT_OVERVIEW.md`, `GAPS.md`,
  `MEMORY.md`, `LEARNING.md`, `WIKI.md`, `docs/TOOLING.md`, this report
- Modified: `.gitignore`, `scripts/setup.sh`, `docs/ENVIRONMENT.md`,
  `CONTRIBUTING.md`, `SETUP-STATUS.md`, `README.md`, `AGENT-CONTEXT.md`

## Rationale

The repository already had a strong instruction/CI layer; the real gaps were
git hygiene (everything uncommitted, nothing enforced locally), agent
interoperability beyond Claude, and undocumented tooling decisions. Every fix
follows convention-over-customization: shell hooks instead of a Node
toolchain, pointers instead of per-agent instruction copies, one canonical
home per fact (`MEMORY.md` routing). TrustLedger was used as a pattern
source, not a package source — its stack solves web3/TypeScript problems this
serverless Swift app does not have.

## Recommendations

- Merge `chore/ai-workspace-bootstrap` via PR, then configure the repo
  settings in issue #7 (secret, branch protection, auto-merge).
- When `app/` lands: add SwiftLint/SwiftFormat configs, a Semgrep `p/swift`
  job, and activate the test targets per `docs/TESTING.md`.
- Keep `docs/TOOLING.md` as the gate for any new tool: a row with a reason,
  or it doesn't come in.

## Follow-up Actions

- [ ] Owner: merge the PR from `chore/ai-workspace-bootstrap`.
- [ ] Owner: set `ANTHROPIC_API_KEY`; enable branch protection + auto-merge.
- [ ] Scaffold `app/` (top milestone, `SETUP-STATUS.md`).
- [ ] Add Semgrep `p/swift` CI job when `app/` exists (`GAPS.md` M3).

## Remaining Work

Repo settings (#7) require GitHub UI access. The app, tests, and models
remain intentionally absent; nothing in this audit claims otherwise.

## Verification Performed

Static review plus the mechanical checks below. No device, simulator, or
blind tester was involved — there is no app to run, and this audit does not
claim otherwise.

### Commands Executed

```bash
bash -n .githooks/pre-commit .githooks/commit-msg scripts/setup.sh  # syntax OK
scripts/setup.sh   # toolchain check + hooks enabled
python3 -c "import json; json.load(open('.mcp.json'))"              # valid JSON
# commit-msg + pre-commit hooks exercised by this branch's own commits
```

### Test Results

Not applicable — no test targets exist yet.

### Build Status

Not run — no Swift package or Xcode project present; CI builds automatically
once `app/` lands.

## Sign-off

- Auditor: Kevin Khanh Le (via Claude Fable 5, background session)
- Reviewed by:
- Date: 2026-07-11
