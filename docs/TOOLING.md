# Tooling — global vs. project decision matrix

Every development/AI tool considered for SenseBridge, where it lives, and why.
The standing rule: **global by default; project-level only when the repo needs
a pinned, portable, or shareable config.** Fewer, higher-quality tools beat
more tools. Last reviewed 2026-07-11.

SenseBridge is a Swift/SwiftUI iOS app with **no Node, Python, or web stack**
— that single fact decides most rows below.

## Project-level (in this repository)

| Tool / config | Where | Why project-level |
| --- | --- | --- |
| Git hooks | `.githooks/` (`pre-commit`, `commit-msg`) | Shareable, dependency-free quality gate; enabled by `scripts/setup.sh` via `core.hooksPath` |
| gitleaks config | `.gitleaks.toml` | Shared by the pre-commit hook and any local sweep; CI uses TruffleHog (complementary: local pattern scan pre-commit, verified-credential scan on push) |
| Sensitive-file check | `tools/check-sensitive-files.mjs` | Stdlib-only Node script; guards signing/credential material (iOS-specific formats) |
| SwiftLint / SwiftFormat | `scripts/lint.sh` (configs land with `app/`) | Binaries are global (Homebrew); the invocations and future configs are repo-specific |
| Serena MCP | `.mcp.json` | Per-project semantic indexing; least privilege — local process, no network, project-scoped |
| CI/CD | `.github/workflows/` | CI, security scanning (TruffleHog + OSV + sensitive files), Claude PR review, Dependabot auto-merge |
| Agent instructions | `AGENTS.md` + thin pointers (`CLAUDE.md`, `GEMINI.md`, `.cursor/rules/`, `.github/copilot-instructions.md`) | One canonical instruction file, agent-agnostic; pointers prevent lock-in and duplication |
| Skills / reviewer personas | `.agents/`, `.claude/skills/` | Project-doctrine-specific (safety framing, accessibility, model licensing) |
| Audit system | `audits/` | Append-only governance artifacts |

## Global (installed on this machine, nothing to add to the repo)

| Tool | Status | Use here |
| --- | --- | --- |
| Xcode / Swift toolchain | required | The build |
| SwiftLint, SwiftFormat, xcbeautify | installed (Homebrew) | Invoked by `scripts/lint.sh` once `app/` exists |
| gitleaks | installed | Pre-commit secret scan |
| semgrep | installed | Ad-hoc static analysis; add a `p/swift` CI job when `app/` lands (see `GAPS.md`) |
| gh | installed | GitHub workflows |
| Serena | installed (`uv` tool) | Semantic code navigation via `.mcp.json` |
| Graphify | installed | Knowledge-graph queries; output (`graphify-out/`) is gitignored |
| RTK | installed | Token-efficient repo indexing |
| gstack | installed (`~/.claude/skills/gstack`) | Web browsing + review/ship skill suite |
| Ollama | installed | Local LLM experiments only — **not** an app dependency; on-device inference uses Core ML/ANE, never a local server |
| Node, bun, uv, python3 | installed | Script runtimes only; no project package manifests |
| Obsidian vault (`~/Vault`) | present | Cross-project knowledge via the `vault-capture` skill (see `MEMORY.md`) |

## Claude skills — evaluated against fit

Kept global and minimal. The Karpathy principles (think-before-coding,
simplicity-first, surgical-changes, goal-driven execution) are already encoded
in the global `~/.claude/CLAUDE.md` — installing the plugin would duplicate
them, so it is deliberately **not** installed. Built-in harness skills already
cover code review, security review, deep research, and scheduling.

Third-party marketplace skills evaluated and **declined for now** (install is
a one-line `/plugin` command if ever needed; each adds context-window cost and
supply-chain surface): claude-mem (harness auto-memory already persists),
codex-plugin-cc, find-skills, The Council, Stop Slop, Superpowers, Humanizer,
Caveman, Hyperframes, AI Second Brain, NotebookLM, Granola, Higgsfield,
Perplexity, Agent Browser (gstack `/browse` covers it), UI/UX Pro / Frontend
Design (web-oriented; iOS UI is reviewed by `.agents/agents/ui-reviewer.md` +
accessibility skill), SEO / Marketing / Social Media / Legal packs (no
marketing surface; `legal/` is owner-gated).

## Not needed (and why)

| Tool | Reason |
| --- | --- |
| ESLint, Prettier, Stylelint, SWC, Jest, Knip, Husky, Commitlint | Node/web toolchain; repo has no `package.json`. Hooks + conventional-commit check are dependency-free shell. SwiftLint/SwiftFormat/XCTest are the equivalents here |
| React Doctor, React Scan, Playwright | No React/web UI; UI testing is XCUITest + VoiceOver passes |
| Vercel, Docker, Kubernetes | Serverless-by-doctrine: there is no backend to deploy — a container platform would violate `docs/privacy.md` |
| CodeRabbit | Duplicates `claude-code-review.yml`, which is already doctrine-tuned. One AI reviewer, well-prompted, beats two generic ones |
| Nexus Graph | TrustLedger-specific script (`scripts/nexus-mcp.js` there); Graphify + Serena cover the need here |
| Python venv | No Python code in this repo |
| Oracle tooling | No database; explicitly unjustified |
| Dune MCP (global) | Crypto analytics for other projects; not referenced here |

## MCP inventory

| Server | Scope | Permissions | Status |
| --- | --- | --- | --- |
| serena | project (`.mcp.json`) | Local process, project files only | Active |
| dune | user-global (`~/.claude.json`) | Remote, read-only analytics | Unrelated to SenseBridge; left global, nothing to remove here |
| claude-in-chrome | user-global (extension) | Site-gated browser automation | Available; gstack `/browse` preferred per global CLAUDE.md |

Adding an MCP server to this repo requires: local-first, least privilege,
a row in this table, and — if it could ever see user-surroundings data — a
privacy-doc update per `docs/privacy.md`.
