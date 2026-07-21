---
title: Tooling — Global vs. Project Decision Matrix
---

# Tooling — Global vs. Project Decision Matrix

Every development/AI tool considered for SenseBridge, where it lives, and why.
The standing rule: **global by default; project-level only when the repo needs
a pinned, portable, or shareable config.** Fewer, higher-quality tools beat
more tools. Last reviewed 2026-07-11.

SenseBridge is a Swift/SwiftUI iOS app with **no Node or Python stack in the
app itself** — that fact still decides most rows below. As of 2026-07-11 the
repo also has a small, deliberately separate Node/web stack under
[`website/`](../website) (the marketing site) — see that row for scope. It
does not change anything about the app: no Node, Python, backend, container,
or orchestration platform touches `app/`.

## Project-level (in this repository)

| Tool / config | Where | Why project-level |
| --- | --- | --- |
| Git hooks | `.githooks/` (`pre-commit`, `commit-msg`, `pre-push`, `post-commit`, `post-checkout`, `post-merge`) | Shareable, dependency-free quality gate; enabled by `scripts/setup.sh` via `core.hooksPath`. `pre-push` mirrors the CI build gate and blocks direct pushes to `main`, and
also runs a local `osv-scanner` dependency scan mirroring `security.yml`'s
osv-scan job when `osv-scanner` is installed (`brew install osv-scanner`;
advisory-only if it isn't, same as the `ggshield` row below); `post-merge` flags manifest/toolchain files a pull just changed. `post-commit`/`post-checkout`/`post-merge` also each carry a hand-maintained, advisory-only GitNexus staleness reminder (see the GitNexus row) — separate from the Graphify auto-rebuild blocks those first two files otherwise contain |
| Claude Code hooks | `.claude/hooks/` (six scripts), wired in `.claude/settings.json` | Session-level guardrails the git hooks can't see: `cap-large-read.sh` + `warn-duplicate-read.sh` (PreToolUse Read — token discipline), `limit-agent-fanout.sh` (PreToolUse Agent — subagent cap), `guard-main-commit.sh` (PreToolUse Bash — denies `git commit` on `main`, complementing `.githooks/pre-push`), `check-md-links.sh` (PostToolUse Edit/Write — flags broken relative links in edited `.md` files, advisory), `session-log-reminder.sh` (Stop — nudges the hourly session log per `CLAUDE.md`) |
| gitleaks config | `.gitleaks.toml` | Shared by the pre-commit hook and any local sweep; CI uses TruffleHog (complementary: local pattern scan pre-commit, verified-credential scan on push). Extends the default ruleset with **AI-provider key rules the default misses** — verified 2026-07-16 against gitleaks 8.30.1, which caught only `github-pat`/`gcp-api-key` and scanned Anthropic, both OpenAI formats, and Hugging Face **clean**. `sk-ant-` is this repo's likeliest leak. Carries **no path allowlist**: it previously excluded `docs/**.md` + `audits/**.md`, so an identical GitHub PAT was blocked at the repo root and silently allowed in `docs/`. False positives go to `.gitleaksignore` by fingerprint, never back into a blanket path rule |
| ggshield config | `.gitguardian.yaml` | Third, independent secret-detection layer (added 2026-07-20): GitGuardian's hosted detector set, run locally by `.githooks/pre-commit` (advisory if `ggshield` isn't installed/authenticated) and in CI by `.github/workflows/security.yml`'s `ggshield` job. `exit_zero: false` — strict, any finding fails the scan. Same no-path-allowlist stance as `.gitleaks.toml` and for the same reason; false positives go in `secret.ignored_matches` by fingerprint. CI needs the `GITGUARDIAN_API_KEY` repository secret (owner action, not yet set) or the job fails closed |
| Sensitive-file check | `tools/check-sensitive-files.mjs` | Stdlib-only Node script; the **second local layer, not a duplicate** of gitleaks — pre-commit runs gitleaks only when installed and silently skips it otherwise, so on a machine without it this is the sole gate before a public push. Guards signing/credential material (iOS-specific formats), provider tokens, hardcoded machine paths, and **gitignored-but-force-added files** (`git add -f NOTES.local.md`), which it detects via `git check-ignore --no-index` rather than re-encoding `.gitignore` — a second copy of those rules would drift, and negations like `!tmp/README.md` make hand-rolled matching wrong both ways. `--no-index` is load-bearing: without it, check-ignore consults the index and never reports a staged path as ignored, which is precisely the case being caught |
| SwiftLint / SwiftFormat | `scripts/lint.sh` (configs land with `app/`) | Binaries are global (Homebrew); the invocations and future configs are repo-specific |
| Serena MCP | `.mcp.json`, `.serena/project.yml` (`languages:`) | Per-project semantic indexing; least privilege — local process, no network, project-scoped. Update `languages:` whenever a new language is introduced (e.g. `swift` once `app/` lands) so its language server starts |
| CI/CD | `.github/workflows/` | CI, security scanning (TruffleHog + GitGuardian + OSV + sensitive files), Claude PR review, Dependabot auto-merge |
| Agent instructions | `AGENTS.md` + thin pointers (`CLAUDE.md`, `GEMINI.md`, `.cursor/rules/`, `.github/copilot-instructions.md`) | One canonical instruction file, agent-agnostic; pointers prevent lock-in and duplication |
| Per-agent configs | `.codex/` (AGENTS.md, `config.toml`, `hooks.json`), `.gemini/settings.json`, `.copilot/` (instructions + MCP), `.continue/rules/`, `.windsurf/` (rules + MCP), `.openclaw/README.md`, `.cursor/mcp.json`, `.vscode/mcp.json` (VS Code's own Copilot Chat agent mode — separate from `.copilot/mcp-config.json`, which is the Copilot CLI) | Each wires Serena MCP and defers to root `AGENTS.md` — configuration without instruction duplication |
| Continue config template | `.continue/config.template.yaml`, `.continue/README.md` | Example only, never active config (Continue reads the user-global `~/.continue/config.yaml`); shareable starting point so a new machine doesn't hand-roll the role/model setup documented in [`docs/OLLAMA.md`](OLLAMA.md) |
| Skills / reviewer personas | `.agents/`, `.claude/`, `.cursor/`, `.gemini/`, `.github/` skills dirs | Project-doctrine-specific (safety framing, accessibility, model licensing); includes the `council` decision-review skill, the `website-design` integration router, and the vendored `seo-schema`/`seo-technical` offline SEO skills (from `AgriciDaniel/claude-seo`, MIT — see `CREDITS.md`), all mirrored across all five harness dirs via `tools/sync-skills.mjs` (next row) |
| Mirrored-skill sync | `tools/sync-skills.mjs`; enforced by `.githooks/pre-commit` and CI's docs-links job (both run `--check`) | Canonical source for hand-mirrored skills is `.claude/skills/<name>/`; the tool regenerates the `.agents`/`.cursor`/`.gemini`/`.github` copies from it, applying the two deliberate per-harness path substitutions as data-driven rules, so the copies **cannot drift silently**. Edit only the canonical copy, then run `node tools/sync-skills.mjs`. Excludes `impeccable`, which is vendor-managed (`npx impeccable check`/`update`) with intentionally different per-provider content — and, for the same reason, `react-doctor` (see the "React Doctor, React Scan" row above), which is vendor-managed by its own `install`/`ci install` CLI, not this tool |
| Review companions | `REVIEW.md` (root), `.claude/commands/security-review.md` | Extend the built-in `/code-review` and `/security-review` with project severity overrides, skip paths, and on-device/privacy/model-license checks — additive, not a fork. See "Built-in reviews — extended, not replaced" below |
| Audit system | `audits/` | Append-only; process docs (`README.md`, `GOVERNANCE.md`, `AGENT-GUIDE.md`, `scripts/`, `templates/`) are tracked, but report findings themselves are gitignored/local-only — see `audits/README.md` |
| Marketing website | `website/` (`package.json`, `.stylelintrc.json`, `.prettierrc`, `eslint.config.mjs`, mostly static HTML/CSS via Astro) | The one deliberate exception to "no web stack" — copy still follows `docs/SAFETY-FRAMING.md`. Node tooling (Stylelint, Prettier, ESLint) is scoped to this directory only via `.github/workflows/website-ci.yml` (path-filtered) and its own `dependabot.yml` entry. `eslint.config.mjs` is a strict flat config (TypeScript, React Hooks, `jsx-a11y` strict, security). **React (2026-07-20):** `@astrojs/react` is wired in `astro.config.mjs`; React only ships to a page when a component opts into a `client:*` hydration directive (Astro islands), so the zero-JS-by-default posture holds until a component actually needs one — no component uses React yet, this is framework-ready capacity, verified end-to-end (typecheck/lint/build/hydration) but not yet adopted by any real UI; see `website/README.md` |
| React Doctor, React Scan | `website/package.json` devDependencies (added 2026-07-20 alongside the React integration above) | React Doctor (`npm run audit:react`/`npm run doctor`, both `react-doctor --no-telemetry` — `--no-telemetry` is load-bearing for this repo's no-telemetry-by-default posture) is a static audit CLI for AI-agent-written React code (Hooks correctness, a11y, security, perf). Its `install`/`ci install` subcommands were run 2026-07-20, then **manually reconciled to this repo's actual layout** — the upstream CLI assumes npm-root == git-root, which isn't true here (npm root is `website/`, git/agent-config root is the repo root), so its output had to be relocated by hand: skill files → `.claude/skills/react-doctor/`, `.agents/skills/react-doctor/`, `.continue/skills/react-doctor/`, `skills/react-doctor/` (matching this repo's existing per-harness layout, not the tool's own `website/`-nested defaults); agent hooks → `.claude/hooks/react-doctor.mjs` + a merged `PostToolBatch` entry in `.claude/settings.json`, `.cursor/hooks/react-doctor.mjs` + a merged `postToolUse` entry in `.cursor/hooks.json`; the pre-commit integration was hand-rewritten (not the tool's auto-inserted version) to match the existing `cd website && ...`, staged-changes-only pattern already used for `lint-staged` in `.githooks/pre-commit`; the CI workflow was moved from the tool's default `website/.github/workflows/react-doctor.yml` (inert — GitHub Actions never discovers workflows outside the repo-root `.github/workflows/`) to `.github/workflows/react-doctor.yml` with an explicit `directory: website` input, path-filtered like `website-ci.yml`, and the third-party action pinned to the commit behind the `v2` tag (same convention as `security.yml`'s `ggshield` job) — `blocking: error` (fails only on new error-severity findings; current baseline is 0). **Caution for future runs:** the CLI's own `install`/`ci install` **will misplace files again** if re-run naively — always verify output against this repo's actual (root-vs-`website/`) layout before trusting it, and never run it with cwd or `--cwd` pointed anywhere that lacks a clear project root, since it silently falls back to writing into your **global** `~/.claude/`/`~/.cursor/` config when it can't resolve one (this happened once during setup and was cleaned up). React Scan (`npm run scan`, i.e. `react-scan http://localhost:4321` against a running `npm run dev`) is a render-profiler for spotting unnecessary re-renders; also wired as a dev-only inline import in `website/src/layouts/BaseLayout.astro`, gated behind a frontmatter-level `import.meta.env.DEV` check — since the site is `output: "static"`, that check is resolved at build time, so the `<script>` tag itself never appears in the built HTML and zero bytes reach a production visitor |
| Website hosting (Railway) | `docker/` (`Dockerfile`, `Dockerfile.dockerignore`, `nginx.conf.template`, `docker-compose.yml`), `railway.toml` (repo root) | Deploys the static site only — no env vars, no backend, doesn't touch the app's serverless/on-device posture. Requires the Railway service's Root Directory to stay the **repo root** (dashboard setting, not a repo file) since the Dockerfile build context spans both `docker/` and `website/`. See `docker/README.md` and `website/README.md`'s Deployment section for the full setup flow |
| Impeccable design-QA | Skill in the 5 harness dirs; design context in `.agents/context/`; generated state in `.impeccable/` — **all rooted at the repo root, never `website/`** (see "Impeccable project root" and "Impeccable design context" below). Targets `website/` (via `npx impeccable install` + `/impeccable init`, run manually — see below); also runs **automatically** repo-wide via a `PostToolUse` hook in `.claude/settings.json` (`Edit\|Write\|MultiEdit` → `.claude/skills/impeccable/scripts/hook.mjs`) | Frontend design-anti-pattern detector (contrast, layout, typography); the hook self-filters to UI file extensions (`.tsx`, `.jsx`, `.html`, `.css`, etc. — see `hook-lib.mjs`) so it's a no-op on non-UI edits. `.github/workflows/website-ci.yml` runs `impeccable detect` (`continue-on-error: true` until `PRODUCT.md`/`DESIGN.md` are initialized). **The skill is installed in all 5 harness dirs** (`.agents/skills/impeccable/`, `.claude/skills/impeccable/`, `.cursor/skills/impeccable/`, `.gemini/skills/impeccable/`, `.github/skills/impeccable/`) by `npx impeccable install`, which is a **multi-provider build**, not five copies of one file: each copy's content correctly differs by target (invocation prefix `$impeccable` for Codex CLI vs `/impeccable` elsewhere, self-referential script paths, the model-name line, the project-context filename `AGENTS.md` vs `CLAUDE.md`, and Codex-only sections like its sub-agent/sandbox-permission guidance). **Never hand-edit one copy** — that both fights the next `npx impeccable update` and desyncs the others; use `npx impeccable check` to detect version drift and `npx impeccable update` to refresh all installed copies in place. `.agents/skills/impeccable/agents/*.toml` + `agents/openai.yaml` are Codex-CLI-specific sub-agent configs the installer places only in `.agents/`, by design — no equivalent needed elsewhere. **Always invoke it from the repo root** — see "Impeccable project root" below |
| Handoff auto-load | `SessionStart` hook in `.claude/settings.json` (matcher `clear\|startup` → `cat tmp/handoff.md`) | Surfaces the last `/handoff` entry automatically on `/clear` or a fresh session so work survives context resets; `tmp/handoff.md` (and its durable twin `NOTES.local.md`) are gitignored local scratch — see [`.claude/commands/handoff.md`](../.claude/commands/handoff.md) |
| Notes (public / private split) | [`NOTES.md`](../NOTES.md) tracked; `NOTES.local.md` gitignored | **`NOTES.md`** is a public, committed, linted digest: durable contributor-facing findings, each pointing at the doc that owns the detail (never a second copy of it). **`NOTES.local.md`** is private — the full `/handoff` trail plus personal and machine-specific notes — and must never be committed. Full handoffs stay private because they carry absolute `/Users/…` job paths and machine state; `check-sensitive-files.mjs` would block such a commit anyway, but it only scans staged/tracked files, so it cannot protect the private file. `NOTES.md` states the rule; `/handoff` step 6 is where the digest entry gets written |
| Workflow commands | [`.claude/commands/cleanup-notes.md`](../.claude/commands/cleanup-notes.md), [`.claude/commands/session-log.md`](../.claude/commands/session-log.md), [`.claude/commands/todo-groom.md`](../.claude/commands/todo-groom.md) | `/cleanup-notes` grooms the private `NOTES.local.md` (collapses resolved handoff entries, surfaces open items; backup in `tmp/`, never commits); `/session-log` encodes the mandatory `CLAUDE.md` session-log rule (log entry + `TODO.md` follow-up mirroring); `/todo-groom` re-grounds `TODO.md` against actual repo state using the file's own completion-annotation rule. All three are thin wrappers around rules that already live in `CLAUDE.md`/`TODO.md` — mechanics only, no duplicated policy |
| CodeRabbit | `.coderabbit.yaml`, path-scoped to `website/**` only | Second reviewer for the one part of the repo `claude-code-review.yml`'s doctrine-tuned prompt wasn't written for (general web/CSS quality). Requires the CodeRabbit GitHub App installed on the repo (owner action, not yet done) |
| GitNexus (`gitnexus` npm CLI) | Installed globally (`npm install -g gitnexus`); index at `.gitnexus/` (gitignored); config at `.gitnexusrc` (`skipContextFiles: true` so it never touches our hand-curated `CLAUDE.md`/`AGENTS.md`) | Knowledge-graph code navigation (call chains, blast-radius/impact analysis, clusters), alternative/complement to Graphify+Serena. `gitnexus analyze` indexes the repo; `gitnexus setup -c claude` wires the MCP server + PreToolUse/PostToolUse hooks into the **user-global** `~/.claude/` config (not this repo's tracked files — reversible any time with `gitnexus uninstall`). Fully local: parsing, graph store, and embeddings (transformers.js/ONNX) all run on-device with no network calls; only the optional `gitnexus wiki` command needs an LLM API key, and this repo doesn't use it. Corrects a prior mistaken doc entry here that described a VS Code extension called "Nexus" requiring an API key for chat/embeddings — no such tool matches that description; the real `Nexus-tree.nexus-extension` on the VS Code Marketplace is an unrelated Next.js component-tree visualizer with no CLI, evaluated and not used. **Freshness**: the user-global PostToolUse hook only nudges the agent to reindex inside a Claude Code session; unlike Graphify (below), GitNexus ships no `hook install` equivalent, so `.githooks/post-commit`/`post-checkout`/`post-merge` each carry a small hand-maintained, advisory-only block (never blocks, never runs `analyze` itself — a full rebuild can take up to ~120s and an unclean kill risks index corruption, per the vendor's own hook) that prints a stderr reminder to run `gitnexus analyze` after any commit/branch-switch/merge, once the repo has been indexed at least once. This covers git activity outside a Claude Code session (plain terminal, other editors, CI) that the vendor hook can't see |
| Editor config | `.vscode/extensions.json`, `.vscode/settings.json` | Recommended-extensions list + strict per-language formatting/lint settings; excludes generated dirs (`graphify-out/`, `.gitnexus/`, `tmp/`, `logs/`) from search/watch |
| Agent/CI scratch space | `tmp/`, `logs/` | Gitignored scratch dirs (`.gitkeep` + README tracked) so agents stop reaching for shared `/tmp` or leaving untracked litter at repo root |
| Line-ending/merge hygiene | `.gitattributes` | LF normalization, `linguist-generated` on `graphify-out/`, `.gitnexus/`, lockfiles |
| Secret-scan overrides | `.gitleaksignore` | Fingerprint allowlist for verified false positives, separate from the pattern rules in `.gitleaks.toml`; empty until a real false positive needs one |
| Static analysis (generic) | `.github/workflows/security.yml` → `semgrep` job (`p/security-audit`, `p/secrets`, `p/owasp-top-ten`, `p/swift`) | Scans scripts, workflows, `website/`, and (since `app/` landed) Swift — `p/swift` is in the job's config and verified clean, see `GAPS.md`'s H1 resolution |
| Monthly log archive | [`.agents/skills/monthly-log-archive/SKILL.md`](../.agents/skills/monthly-log-archive/SKILL.md), `tools/condense-monthly-logs.mjs` (added 2026-07-21) | Stdlib-only Node script (no new deps) that condenses last month's gitignored `sessions/<YYYY-MM-DD>/*.md` into one `sessions/<YYYY-MM>/SESSIONS.md` and removes the per-day directories. For `audits/` it only ever builds a derived, regeneratable `audits/<YYYY-MM>/INDEX.md` linking to that month's reports — it never moves, edits, or deletes a report, since audits are append-only (`audits/AGENT-GUIDE.md`). The skill's description-based trigger ("today is the 1st") only fires if a session happens to start that day; a guaranteed trigger would need a `SessionStart` hook or a monthly `schedule` cron, neither added yet pending owner sign-off |

## Global (installed on this machine, nothing to add to the repo)

| Tool | Status | Use here |
| --- | --- | --- |
| Xcode / Swift toolchain | required | The build |
| SwiftLint, SwiftFormat, xcbeautify | installed (Homebrew) | Invoked by `scripts/lint.sh` once `app/` exists |
| gitleaks | installed | Pre-commit secret scan |
| ggshield | not installed — advisory (`brew install ggshield`, then `ggshield auth login`) | Pre-commit GitGuardian secret scan; CI runs regardless via the `ggshield` job, gated on the `GITGUARDIAN_API_KEY` repo secret |
| semgrep | installed | Ad-hoc local runs; CI coverage lives in `security.yml`'s `semgrep` job, including `p/swift` (added once `app/` landed) |
| osv-scanner | installed (Homebrew) | Pre-push dependency vulnerability scan (`.githooks/pre-push`), mirroring `security.yml`'s `osv-scan` job |
| gh | installed | GitHub workflows |
| Serena | installed (`uv` tool) | Semantic code navigation via `.mcp.json` |
| Graphify | installed | Knowledge-graph queries; output (`graphify-out/`) is gitignored. Auto-rebuilds via versioned `.githooks/post-commit` + `post-checkout` (installed by `graphify hook install`, detached/non-blocking, skips rebases and graph-only changes); optional live mode: `graphify watch .` (needs `watchdog` in graphify's env). CI rebuilds it advisorily on `main` and uploads it as a downloadable artifact (`.github/workflows/graphify.yml`, scope in `.graphifyignore`) |
| GitNexus (`gitnexus`) | installed (`npm install -g gitnexus`) | Knowledge-graph code navigation via `.mcp.json`-equivalent wired into the user-global `~/.claude/` config (`gitnexus setup -c claude`), not this repo's tracked files. Index (`.gitnexus/`) gitignored; refresh with `gitnexus analyze` |
| RTK | installed | Token-efficient repo indexing |
| gstack | installed (`~/.claude/skills/gstack`) | Web browsing + review/ship skill suite |
| Ollama | installed | Local LLM experiments only — **not** an app dependency; on-device inference uses Core ML/ANE, never a local server. Full setup, two-machine topology, and security posture: [`docs/OLLAMA.md`](OLLAMA.md) |
| Node, bun, uv, python3 | installed | Script runtimes only; no project package manifests |
| Obsidian vault (`~/Vault`) | present | Cross-project knowledge via the `vault-capture` skill (see `MEMORY.md`) |

## Claude skills and plugins

Installed globally (user scope) from source-verified marketplaces. Versions and
sources re-verified 2026-07-11 against upstream (GitHub API + release notes):

| Plugin | Source | Why |
| --- | --- | --- |
| superpowers 6.1.1 | `obra/superpowers-marketplace` | Engineering-workflow skills + skill search (TDD, debugging, planning dispatch). **Note:** the legacy `/brainstorm`, `/write-plan`, `/execute-plan` slash commands and the named `superpowers:code-reviewer` agent were **removed in 6.x** — do not reference them. 6.x also hardened the brainstorm server (per-session auth, sandboxing) and removed a Codex `SessionStart` auto-exec hook (net-positive) |
| claude-mem 13.10.2 | `thedotmack/claude-mem` | Cross-session memory capture/injection. **Disabled at project scope for SenseBridge** (`.claude/settings.json` → `enabledPlugins`) because the harness's built-in auto-memory already persists here — running both would inject duplicated context. Keep disabled here: claude-mem compresses sessions through a configured LLM provider (data egress) and has a history of local-surface issues (an unauthenticated local API on port 37777, since fixed; a `shell:true` spawn footgun, tracked upstream) — neither is a fit for this repo's on-device/no-telemetry posture. It stays available globally; never run both memory systems at once. **2026-07-19:** a personal global tooling build-out asked to wire claude-mem to Obsidian for token savings — see `TODO.md`'s "Global Claude Code tooling build-out" entry for the open question of whether that should touch this row |
| humanizer 2.8.2 | `blader/humanizer` | Strips AI-writing tells from prose/docs. **Guard:** never let a humanizer pass soften a required safety-framing hedge in app or marketing copy (see [SAFETY-FRAMING.md](SAFETY-FRAMING.md)) |
| codex 1.0.6 (`codex-plugin-cc`) | `openai/codex-plugin-cc` (Apache-2.0, official OpenAI) | Optional second-opinion reviewer: shells out to the locally installed `codex` CLI so a different vendor's model can adversarially review a diff — complements `/code-review` and the `council` skill, never replaces them and is never a CI gate. Installed 2026-07-17 after a code-level review: registers `SessionStart`/`SessionEnd` hooks that manage a **local-only** Unix-domain-socket broker for `codex app-server` (pidfile, torn down at session end) plus an **opt-in** `Stop` review gate; zero network calls, telemetry, or auto-updates found in the shipped scripts. Inert without a per-developer OpenAI login/key — never configure one in this repo or CI |
| privacy-legal 1.0.2 (`claude-for-legal`) | `anthropics/claude-for-legal` (Apache-2.0, official) | Privacy-law workflow plugin, installed 2026-07-17 on owner override (the marketplace's 12 sibling plugins are one `claude plugin install <name>@claude-for-legal` away). Zero hooks (verified empty `hooks.json`); bundles Slack + Google Drive hosted MCP connectors that stay **unauthenticated/inert** until the owner logs in. Using it never overrides this repo's rule that `legal/` edits need explicit owner approval |
| task-observer ("One Skill to Rule Them All") | `rebelytics/one-skill-to-rule-them-all` (CC BY 4.0) | Logs skill-improvement observations during task-oriented sessions; mirrored into both `~/.claude/skills/` and `~/.codex/skills/` with a matching activation trigger in `~/.claude/CLAUDE.md` and `~/.codex/AGENTS.md`. **Cowork users only:** the skill persists its observation log (`skill-observations/`) and staged updates (`skill-updates/`) to whatever folder you select as the shared workspace on your first Cowork task for this project — pick one and keep reusing it, since the log won't carry over if you switch folders. Claude Code and Codex CLI need no equivalent step; they use the project root automatically |

### Ponytail — project-scoped only, not global (added 2026-07-17)

Unlike the table above, `ponytail@ponytail` (`DietrichGebert/ponytail`, MIT,
v4.8.4) is installed at **project scope** (`.claude/settings.json` →
`enabledPlugins`), not user scope — it does not apply in other repositories.
A YAGNI/lazy-senior-dev ruleset (smallest correct change, stdlib first, no
unrequested abstractions) — the same instinct this repo's own "Surgical
Changes"/"Simplicity First" norms already ask for.

Evaluated with a real code-level review before install, not just README
claims: fetched every hook file (`ponytail-activate.js`,
`ponytail-mode-tracker.js`, `ponytail-subagent.js`, `ponytail-runtime.js`)
and the bundled `ponytail-mcp` server (`index.js`) directly. Findings: zero
network calls, zero arbitrary `exec`/`spawn`, filesystem writes confined to
Claude's own config tree, path-safety validation before any shell string
embedding, a tested uninstall path, and an MCP server that only serves a
static local instruction string (self-declared `readOnlyHint: true,
openWorldHint: false`). Its claimed popularity (85,184 GitHub stars per the
API, verified directly — an earlier "implausible inflation" concern from a
shallower pass does not hold up) reflects genuine adoption, not a farmed
count.

**One gap the upstream project has no reason to know about, closed
locally**: nothing in Ponytail's own `SKILL.md` "Permanent Exceptions" list
(which already protects security and accessibility from simplification)
covers this repo's hedging string literals specifically. Closed via an
explicit carve-out in `AGENTS.md`'s doctrine #1 — the YAGNI ladder never
applies to `docs/SAFETY-FRAMING.md`-governed spoken/caption/haptic strings
or accessibility labels.

**Configuration, pinned explicitly rather than left to the tool's default:**

- Default mode is `full` (via `~/.config/ponytail/config.json` →
  `defaultMode`) — never `ultra`, which the tool's own docs describe as
  "challenges requirements," the wrong instinct anywhere near a
  safety-framing string. This file was written to make the choice explicit
  and durable rather than relying on the tool's own implicit default, which
  could change in a future release.
- Marketplace registered at project scope too
  (`extraKnownMarketplaces.ponytail` in `.claude/settings.json`), so it
  isn't silently available to other projects that happen to share this
  machine.

### Global skills — standalone, unattributed (added 2026-07-13)

Three more skills sit in `~/.claude/skills/` as bare `SKILL.md` files with no
plugin manifest, marketplace entry, version string, or `LICENSE` — unlike every
plugin in the table above, their provenance could not be verified against an
upstream source. Documented here anyway, since they're active and in scope for
this repo; treat them as unattributed until a source turns up.

| Skill | Location | Why relevant here |
| --- | --- | --- |
| context-budget | `~/.claude/skills/context-budget/SKILL.md` | Audits context-window overhead across loaded agents/skills/MCP servers/`CLAUDE.md` files. Relevant given the size of this repo's own instruction surface (global + project `CLAUDE.md`, `.agents/`, `.claude/skills/`, multiple MCP servers) |
| production-audit | `~/.claude/skills/production-audit/SKILL.md` | Local-evidence production-readiness audit (no external data egress) — complements, doesn't replace, this repo's own `audits/` append-only system and the [ci-green-gate](../.agents/skills/ci-green-gate/SKILL.md) gates |
| agent-architecture-audit | `~/.claude/skills/agent-architecture-audit/SKILL.md` | Diagnostic for agent/LLM application stacks (prompt, memory, tool calling, rendering). Relevant if SenseBridge's on-device model-inference layer ever grows agent-like wrapper logic; not yet exercised |

**Name collision:** the same 2026-07-13 batch also placed a *generic* WCAG
`accessibility` skill at `~/.claude/skills/accessibility/SKILL.md`, sharing its
name with this repo's own `.agents/skills/accessibility` (SenseBridge-specific:
VoiceOver, Dynamic Type, the rotor). They are different files with different
content. Per this harness's "most specific wins" skill-resolution rule, the
project-scoped copy takes precedence for SenseBridge work — the global one is
effectively shadowed here and undocumented elsewhere, so it's noted for
awareness only; no action needed unless resolution behavior changes.

### Global skills — installed 2026-07-17 (prefer-integration re-evaluation)

Installed after the owner reversed the earlier skip-on-overlap policy: overlap
alone no longer disqualifies a tool; each item below passed a fresh
maintenance/license check (GitHub API, 2026-07-17) and a content-level
security review (text-only instruction files, no executable surface, no
network calls) before activation.

| Skill | Source | Scope and guardrail |
| --- | --- | --- |
| stop-slop | `hardikpandya/stop-slop` (MIT) | `~/.claude/skills/stop-slop/`. Anti-AI-slop writing pass, complementing (not replacing) humanizer. **Same guard as humanizer:** a de-slop pass must never soften a required safety-framing hedge — `docs/SAFETY-FRAMING.md` and the `safety-framing-reviewer` win every conflict on app strings and marketing copy |
| copywriting, copy-editing, ai-seo, seo-audit, schema, product-marketing | `coreyhaines31/marketingskills` (MIT) | `~/.claude/skills/<name>/`. The 6-of-47 subset compatible with an honest pre-launch site; the other 41 (CRO, popups/paywalls, paid ads, cold outbound, programmatic SEO, growth loops) were deliberately not installed — conversion-pressure and mass-generated-page mechanics conflict with the restraint and honesty-over-hype doctrines in `.agents/context/PRODUCT.md`. Copy produced with these still routes through `website-design`'s guardrails |
| find-skills | `vercel-labs/skills` (repo has **no top-level LICENSE**) | `~/.claude/skills/find-skills/`. Already installed and in active use (see `MEMORY.md`); documented here rather than re-litigated. **Discovery only:** use it to *find* candidate skills; every candidate still goes through this file's fetch→review→activate flow before install — never let it auto-install unvetted third-party skills. The missing upstream license is tolerable for a locally-run discovery aid but would block vendoring any of its content into this repo |

**Second wave, same evening (explicit owner override of the remaining
blockers).** Each was still fetch→reviewed before activation; the original
concerns didn't vanish — they're recorded here as operating conditions:

| Skill | Source | Scope and guardrail |
| --- | --- | --- |
| hyperframes (8-skill core set incl. `media-use`) | `heygen-com/hyperframes` (Apache-2.0) via `npm i -g hyperframes` (0.7.61) + `hyperframes skills update` | Video/animation authoring. **PostHog telemetry disabled before first run** (`~/.hyperframes/config.json` → `telemetryEnabled: false` — keep it that way per the no-telemetry doctrine). No hooks or daemons. `media-use` legitimately calls HeyGen/TTS provider APIs when used — that's its function, not a defect; never point it at app or user-surroundings data. Rendering needs `ffmpeg` (not yet installed) |
| notebooklm | `PleasePrompto/notebooklm-skill` (MIT) | Installed **files-only**; first run (owner-triggered, deliberately not done by an agent) creates a venv, pip-installs `patchright`, downloads Chrome, and persists Google session cookies to `~/.claude/skills/notebooklm/data/browser_state/` with anti-bot flags (`--no-sandbox`, stealth input). Personal-productivity tool for the owner's own NotebookLM account; **never invoke it from SenseBridge work** — [`NOTEBOOKLM.md`](NOTEBOOKLM.md)'s manual path remains the project rule |
| social-media-skills (all 17) | `charlie947/social-media-skills` (MIT) | Pure-markdown instruction skills, no code (verified by grep). `post-scorer` + `reels-scripting` stay inert without `APIFY_API_TOKEN`/`GOOGLE_AI_API_KEY` — leave unset until wanted. Any SenseBridge-related social copy still routes through safety-framing/honesty guardrails |
| agent-browser | `vercel-labs/agent-browser` (Apache-2.0) via `npm i -g agent-browser` (0.32.2) | Rust CLI + optional stdio MCP (`agent-browser mcp`); registers no hooks/config. **gstack `/browse` remains the default for all agent browsing per the global standard** — use agent-browser only when explicitly asked for it. Its Chrome-for-Testing fetch (`agent-browser install`) is still pending (permission-gated; owner runs it). On use, a local daemon persists between commands (idle-timeout via `AGENT_BROWSER_IDLE_TIMEOUT_MS`); dashboard, when used, listens on `localhost:4848` |

### Global tooling build-out — installed 2026-07-19

A large personal, machine-wide install pass (~30 items: MCP servers, CLI
tools/agent frameworks, and skills), tracked in full at
`~/.claude/tmp/tools.md` — not re-documented item-by-item here since none of
it is SenseBridge-specific except where noted. Listed here only for the
items with a real guardrail or overlap concern relevant to this repo:

| Tool/skill | Source | Guardrail |
| --- | --- | --- |
| usestrix/strix | `usestrix/strix` (installed to `~/.strix/bin`) | AI-driven penetration-testing tool. **Authorized/defensive use only** (owner's own systems, CTFs, sanctioned pentests) — never point it at third-party systems, and never at SenseBridge's own surfaces without a documented reason, since this repo has no backend to scan and its threat model is on-device (`security/THREAT-MODEL.md`) |
| `/watch` (`bradautomates/claude-video`) | via `npx skills add`, → `~/.agents/skills/watch` | **The installer's own risk scan flagged this "Snyk: High Risk"** (Gen: Safe, Socket: 0 alerts — mixed signal). Runs arbitrary Bash, auto-installs `yt-dlp`/`ffmpeg`, and sends audio to a third-party Whisper API (OpenAI/Groq) when a video has no captions. Kept installed per owner decision; **never use it on anything containing user-surroundings data** — that would be a `docs/PRIVACY.md` violation regardless of what the tool itself does with it |
| Skyvern-AI/skyvern | `pipx install skyvern` | Browser-automation agent — same guardrail as `agent-browser`/`puppeteer` above: **gstack `/browse` remains the default**, use Skyvern only when explicitly asked for it |
| SuperClaude-Org/SuperClaude_Framework | `pipx install SuperClaude` + `superclaude install` | Installed 20 agents to `~/.claude/agents/` and `/sc:*` commands to `~/.claude/commands/sc/`. No name collisions with this repo's own agents (`.agents/agents/*`) or the global `advisor`/`code-reviewer`/`implementer`/`orchestrator`/`security-reviewer` set — but if a future `/sc:` command's behavior overlaps one of this repo's doctrinal reviewers (safety-framing, accessibility, model-license), the project-specific reviewer wins per this repo's own gates |
| santifer/career-ops | cloned into `~/.claude/skills/career-ops/` | Personal job-search tool, no SenseBridge relevance; noted only so the skill list here stays complete |

### BMAD-METHOD — project-level, uncommitted, pending review (2026-07-19)

`bmad-code-org/BMAD-METHOD` was installed **into this repo** (not just
globally) via `npx bmad-method install --yes --tools claude-code`, on a
dedicated branch `chore/bmad-method-setup` (kept separate from
`feat/website-first-light` rather than mixing an unrelated scaffold into an
in-progress feature branch). Added `_bmad/` (module core) and 46 skills
under `.claude/skills/bmad-*`. **Left uncommitted** — nothing here is active
until reviewed and committed; see `TODO.md`'s "Global Claude Code tooling
build-out" entry for the open reconciliation question (several `bmad-*`
skills overlap conceptually with this repo's existing `.agents/skills/*` and
review-agent infrastructure, e.g. `bmad-code-review` vs.
`code-reviewer`/`security-reviewer`). If kept, add a "Project-level" table
row above and run the `update-context` skill per this repo's docs-sync rule.

### Built-in reviews — extended, not replaced

Built-in harness skills already cover code review, security review, deep
research, and scheduling. Rather than install competing review plugins, the repo
**extends the built-ins** through their documented, additive extension points
(Anthropic's own guidance: automated reviews complement, never replace, manual
review and the [ci-green-gate](../.agents/skills/ci-green-gate/SKILL.md)):

| Companion | File | Extends |
| --- | --- | --- |
| Code-review guidance | [`REVIEW.md`](../REVIEW.md) (repo root) | `/code-review` reads this as highest-priority, review-only instructions: project severity overrides (safety-framing = Critical, unlabeled UI = blocking, privacy-boundary = Critical), skip paths, and the honesty rule about what CI cannot prove |
| Security-review command | [`.claude/commands/security-review.md`](../.claude/commands/security-review.md) | `/security-review` — runs the stock diff scan, then layers on the data-egress boundary, model-license, secret/signing-material, dependency-provenance, permission-scope, and workflow-integrity checks specific to an on-device app |
| Council | [`.agents/skills/council/SKILL.md`](../.agents/skills/council/SKILL.md) (mirrored to `.claude/`, `.cursor/`, `.gemini/`, `.github/` skills dirs) | Independent multi-perspective review of an important, hard-to-reverse architectural decision **before** approval (architecture, safety-framing, accessibility, privacy/security, performance, licensing, simplicity seats). Advisory; reuses existing personas, does not replace owner sign-off or CI gates |

The Karpathy principles (think-before-coding, simplicity-first, surgical-changes,
goal-driven execution) are already encoded in the global `~/.claude/CLAUDE.md`
— that plugin would duplicate them, so it is deliberately **not** installed.

### Website design — required capability, integrated not duplicated

The public [`website/`](../website) makes distinctive frontend design a real
need. It is served by the already-wired **impeccable** skill (execution +
critique/audit, brand register, AI-slop detection) plus Anthropic's official
**frontend-design** skill for design *direction*, with **ui-reviewer** and the
**accessibility** skill owning review. The
[`website-design`](../.agents/skills/website-design/SKILL.md) skill (mirrored to
`.claude/`, `.cursor/`, `.gemini/`, `.github/` skills dirs) is the router that
ties them together and enforces the two guardrails the generic tools do not
know: honesty-over-hype (no CTA/availability claims) and safety-framing on
product copy.

| Tool | Disposition | Why |
| --- | --- | --- |
| **Frontend Design** (`anthropics/skills` → `skills/frontend-design`, Apache-2.0) | Adopt as a **global** reference skill; wired via `website-design` | Anthropic-official (lowest supply-chain risk); SwiftUI is a supported stack, so it also informs app-side identity. Enable with `npx -y skills add anthropics/skills --skill frontend-design --agent claude-code` or the plugin |
| **UI/UX Pro** (`nextlevelbuilder/ui-ux-pro-max-skill`, MIT) | **Method folded in**; npm package **not installed** | The capability (style/palette/font-pairing selection, a design brief) is already covered by impeccable's `palette.mjs` + brand/product registers and the official frontend-design skill. The package is an unofficial single-maintainer distribution that ships executable install scripts and has an outlier star count — installing it would add supply-chain risk for a capability we already hold. Its *method* is captured in `website-design` |

### Impeccable project root — always the repo root

Impeccable keys its state directory (`.impeccable/`) to its *resolved project
root*. Absent a monorepo marker — and this repo has none (no root
`package.json` workspaces, no `pnpm-workspace.yaml`/`turbo.json`/`nx.json`/
`lerna.json`; the root `.git` halts its upward search) — that resolver falls
back to **whatever directory it was invoked from**. `cd docs && node
…/context.mjs` roots `.impeccable/` in `docs/`.

**Repo root is the only supported root**, and this is not merely a convention:
the editor hook (`hook-lib.mjs` → `resolveCacheCwd`) hard-keys to the repo root
because `.git` is one of its project-root markers, so the hook writes the
root `.impeccable/` no matter which file was edited. A second `.impeccable/`
elsewhere is therefore always a stray, never a second valid project — it
silently misses the real ignore rules and cache in the root one.

Three defenses, all in place:

1. **CI runs from the root.** `website-ci.yml`'s `design-qa` job deliberately
   omits the `working-directory: website` that its `lint` job uses, and passes
   `website` as a target argument instead (`npx impeccable detect website`).
   This was the one automated path that created a stray.
2. **`.gitignore` ignores impeccable local state at any depth** (`**/.impeccable/…`).
   The patterns contain a slash, so without `**/` they would anchor to the repo
   root only and a stray's session/cache files would land in `git status` as
   untracked noise.
3. **Manual invocations**: keep cwd at the repo root, as `SKILL.md`'s setup step
   already instructs, and scope work with `--target <path>`.

### Impeccable design context — `.agents/context/`, not `website/`

Impeccable's context resolver looks for `PRODUCT.md`/`DESIGN.md` at the project
root, then `.agents/context/`, then `docs/` (first match wins; there is no
config key for this, and `IMPECCABLE_CONTEXT_DIR` is consulted only when those
find nothing). Since the project root is necessarily the repo root, the site's
design context lives in **[`.agents/context/PRODUCT.md`](../.agents/context/PRODUCT.md)
and [`.agents/context/DESIGN.md`](../.agents/context/DESIGN.md)** — the one
location that resolves deterministically without misrepresenting the repo.

**Two files named `PRODUCT.md`, deliberately, with different scopes:**

| File | Scope | Read by |
| --- | --- | --- |
| [`docs/PRODUCT.md`](PRODUCT.md) | The **iOS app** — mission, wedge, success metrics, funding. The repo's primary product. | Humans, planning docs |
| [`.agents/context/PRODUCT.md`](../.agents/context/PRODUCT.md) | The **marketing site** (`website/`) — impeccable's `## Register` / `## Platform` design brief. | `impeccable` (auto), humans |

They complement rather than contradict: the app doc owns product strategy and
the context doc cites it for the positioning wedge. Each states its own scope up
top so neither can be mistaken for the other.

This was a real defect until 2026-07-16, not a theoretical one: the context
files had been written to `website/`, so impeccable — resolving from the repo
root — fell through to `docs/PRODUCT.md` and loaded the *app's* strategy doc as
the design context for the *website*, with `designPath: null` (no design system
at all). Every critique/audit/polish ran mis-primed. Verify the fix with:

```bash
node -e "import('./.agents/skills/impeccable/scripts/context.mjs').then(m=>{
  const c=m.loadContext(process.cwd());
  console.log(c.productPath, c.designPath);
})"
# expect: .agents/context/PRODUCT.md .agents/context/DESIGN.md
```

Do **not** "helpfully" move these back next to the site they describe — that is
what caused the bug. If a future `app/` surface ever needs its own impeccable
context, `.agents/context/` holds one project's context, so that needs a real
decision (impeccable's own `init.md` prescribes a per-app `PRODUCT.md` plus a
root one for the primary surface — which requires the workspace markers this
repo deliberately does not have).

### Evaluated 2026-07-11, re-evaluated 2026-07-17 — still not installed

First evaluated 2026-07-11; **re-evaluated item-by-item 2026-07-17** under an
owner-directed prefer-integration policy (overlap alone no longer
disqualifies; adapt/wrap where a conflict can be scoped away). That pass
re-verified every source against the GitHub API (all actively maintained,
none archived) and **installed** what could be integrated safely: Stop Slop,
a 6-skill marketingskills subset, and find-skills (see "Global skills —
installed 2026-07-17"), `codex-plugin-cc` (plugin table above), the offline
slice of claude-seo (vendored as the `seo-schema`/`seo-technical` project
skills — see `CREDITS.md`), and Perplexity as a documented per-developer
option (MCP inventory below). Later the same evening the owner **explicitly
overrode** the remaining blockers for Hyperframes, NotebookLM,
claude-for-legal, Agent Browser, social-media-skills, Granola, and
Higgsfield — all installed; see "Global skills — installed 2026-07-17" (second
wave), the plugin table, and the MCP inventory. Only these remain out:

| Item | Source (verified) | Reason it stays out (re-checked 2026-07-17) |
| --- | --- | --- |
| Caveman | `juliusbrussee/caveman` (MIT, SAFE-with-conditions) | Core mechanic strips hedging/qualifiers for token savings — direct conflict with awareness-not-safety; and its value is delivered through **user-global SessionStart/UserPromptSubmit hooks** that cannot be scoped away from SenseBridge sessions, so no adaptation preserves both the tool and the doctrine. See the expanded rationale below |
| AI Second Brain | `NicholasSpisak/second-brain` | **Still no LICENSE file** (re-verified 2026-07-17: `GET /license` → 404; default copyright is a hard legal blocker to any install or vendoring, regardless of policy); also directs global `npm i -g` of scraping CLIs. Capability already served by `~/Vault` + `vault-capture`. Revisit only if upstream adds a license |
| claude-skills | ambiguous — official `anthropics/skills` vs. community aggregator `alirezarezvani/claude-skills` | Treat `anthropics/skills` as the trusted source (it already supplies frontend-design); do **not** bulk-install the 345-skill unvetted community aggregator |

Revisit any skipped row with `npx -y skills add <owner/repo>` or
`claude plugin marketplace add <repo>` + `claude plugin install` if its reason
stops applying (e.g. a marketing surface appears, or a blocker like AI Second
Brain's missing license is resolved).

#### Why Caveman specifically cannot be installed here (expanded)

This is a hard "no," not a soft preference, so it's worth spelling out the
mechanism rather than just the one-line table reason:

- Caveman's entire purpose is compressing agent output by stripping
  qualifiers, hedges, and softening language to cut token spend. That is the
  literal opposite of what `docs/SAFETY-FRAMING.md` requires: every
  spoken/caption/haptic string this app produces **must** hedge ("looks like
  a person is nearby," never "a person is nearby") because the app has no
  way to guarantee its perception is correct, and asserting false certainty
  to a blind or low-vision user is the single highest-severity failure mode
  this project has. A tool whose core mechanic is "remove qualifiers" would
  need to be actively fought on every output surface, forever — not a
  one-time review comment.
- It's not scoped to chat responses — it installs `SessionStart` and
  `UserPromptSubmit` hooks, meaning it changes agent behavior repo-wide and
  session-wide, not just in places a developer opts in. There's no safe
  partial-install here (unlike Ponytail below, which can be scoped to a
  passive rules file).
- Its secondary features (commit/review skills) are already covered by
  superpowers + the built-in `/code-review`, so there's no unique
  capability being given up by skipping it.

This reasoning is specific to SenseBridge's awareness-not-safety doctrine —
Caveman isn't unsafe in general, it's incompatible with *this* project's one
non-negotiable output constraint.

### Evaluated 2026-07-17 and deliberately not installed

| Item | Source (verified) | Reason to skip |
| --- | --- | --- |
| ctxlint / cclint / agnix | `YawLabs/ctxlint`, `felixgeelhaar/cclint`, `agnix` | Real projects that lint `CLAUDE.md`/`AGENTS.md`/skills against actual repo state for staleness — a legitimate fit for "drift detection." Not adopted yet: none has verified track record/stability from this pass, and the repo already has two lower-risk mechanisms doing most of the same job — the `update-context` skill (manual, on-demand refresh after repo changes) and the fact that this session's own audit found the instruction-file architecture already duplication-free (see Task 10 of the 2026-07-17 mega-audit). Revisit if drift becomes a recurring real problem, not preemptively |
| Prompt-injection / security "enforcement" as a single tool | — | No single named tool fits; current best practice (OWASP Agentic Top 10, 2026) is defense-in-depth via primitives already in use here: Claude Code's `PreToolUse`/`PostToolUse` hooks (`.claude/settings.json`, both project and user-global), permission/sandbox allowlists, and MCP server scoping — not a bolt-on product |

## Not needed (and why)

| Tool | Reason |
| --- | --- |
| SWC, Jest, Knip, Husky, Commitlint | `website/` is mostly static HTML/CSS — nothing for a bundler, test runner, or dead-code/commit-hook tool to do yet. Add if/when the site gains real JS/React logic beyond what ESLint already covers (see the "Marketing website" row above). Hooks + conventional-commit check for the whole repo are already dependency-free shell (`.githooks/`); SwiftLint/SwiftFormat plus Swift Testing (unit/integration) and XCTest (E2E/performance) cover the app — see [`TESTING.md`](TESTING.md) |
| Playwright | iOS UI testing is XCUITest + VoiceOver passes; no browser E2E surface on the website yet (pa11y-ci covers its accessibility gate — see `website/README.md`'s Tooling section). Revisit if the site grows real interactive flows worth E2E-testing |
| Vercel, Docker, Kubernetes | Serverless-by-doctrine for the **app**: there is no backend to deploy — a container platform would violate `docs/PRIVACY.md`. `website/` is a static site with no deploy target chosen yet (see `website/README.md`); revisit only for static hosting, never a container/orchestration platform |
| `@costline/nexus-graph` (TrustLedger's `scripts/nexus-mcp.js`) | Different package from `gitnexus` (the "GitNexus" row above) despite the shared "Nexus" name — that TrustLedger-specific script still has no home here. GitNexus now covers the call-graph/navigation need it would have filled |
| Python venv | No Python code in this repo |
| Oracle tooling | No database; explicitly unjustified |
| Dune MCP (global) | Crypto analytics for other projects; not referenced here |

## MCP inventory

| Server | Scope | Permissions | Status |
| --- | --- | --- | --- |
| serena | project (`.mcp.json` for Claude; `.codex/config.toml`, `.gemini/settings.json`, `.copilot/mcp-config.json`, `.windsurf/mcp_config.json`, `.cursor/mcp.json` for the others) | Local process, project files only | Active |
| gitnexus | user-global (`~/.claude.json`, via `gitnexus setup -c claude`) | Local process, project files only (no network calls) | Active |
| dune | user-global (`~/.claude.json`) | Remote, read-only analytics | Unrelated to SenseBridge; left global, nothing to remove here |
| claude-in-chrome | user-global (extension) | Site-gated browser automation | Available; gstack `/browse` preferred per global CLAUDE.md |
| perplexity (optional, per-developer) | user-global only — never project-scoped | Remote search API; **every query is egress** and needs `PERPLEXITY_API_KEY` | Not installed. Approved 2026-07-17 as a dev-research aid for any developer who wants it: `claude mcp add --scope user perplexity -e PERPLEXITY_API_KEY=<key> -- npx -y @perplexity-ai/mcp-server` (source: `perplexityai/modelcontextprotocol`, MIT, official). Never coupled to the shipped app or CI |
| context7 (optional, per-developer) | user-global only — never project-scoped, same reasoning as perplexity above | Remote docs-lookup API (Upstash); **every query is egress**, optional `CONTEXT7_API_KEY` for higher rate limits | Installed 2026-07-20: `claude mcp add --scope user context7 -- npx -y @upstash/context7-mcp` (source: `upstash/context7-mcp`, MIT, official; unauthenticated — add `-e CONTEXT7_API_KEY=<key>` for a higher rate limit if needed later). Note: the unscoped `context7` npm package is a **different, unrelated** third-party CLI — do not confuse the two |
| granola | user-global (`~/.claude.json`) | Remote hosted MCP (`https://mcp.granola.ai/mcp`), owner's meeting notes | Registered 2026-07-17 (owner override); **needs authentication** — owner completes OAuth via `/mcp`. Personal productivity; unrelated to the app, never touches repo data |
| higgsfield | user-global (`~/.claude.json`) | Remote hosted MCP (`https://mcp.higgsfield.ai/mcp`), AI media generation (egress on use) | Registered 2026-07-17 (owner override); **needs authentication** — owner completes OAuth via `/mcp`. Any marketing use of generated media still passes the honesty-over-hype guardrails |
| filesystem | user-global (`~/.claude.json`) | Local process, filesystem read/write scoped to `$HOME` | Added 2026-07-19, part of a personal global tooling build-out (`~/.claude/tmp/tools.md`); unrelated to SenseBridge, left global |
| github | user-global (`~/.claude.json`) | Remote GitHub API, token reused from `gh auth token` | Added 2026-07-19, same build-out. Unrelated to SenseBridge's own `gh` CLI usage in workflows |
| puppeteer | user-global (`~/.claude.json`) | Local headless-browser automation | Added 2026-07-19, same build-out. **gstack `/browse` remains the default for all agent browsing per the global standard** (same guardrail as `claude-in-chrome`/`agent-browser` above) — use this only when explicitly asked for scripted/programmatic browser automation, never as a substitute for `/browse` |
| memory (`@modelcontextprotocol/server-memory`) | user-global (`~/.claude.json`) | Local knowledge-graph memory store | Added 2026-07-19, same build-out. **Distinct from claude-mem and from this harness's built-in auto-memory** — do not let all three collide; SenseBridge work should keep using the harness's built-in memory (claude-mem stays disabled here, see below), and this MCP memory server is not currently referenced by any SenseBridge workflow |
| sequential-thinking | user-global (`~/.claude.json`) | Local, structured-reasoning scratchpad only, no network | Added 2026-07-19, same build-out |
| glyph (`benmyles/glyph`) | user-global (`~/.claude.json`, binary at `~/.local/bin/glyph`) | Local process, Tree-sitter symbol extraction, no network | Added 2026-07-19, same build-out. **Heavy functional overlap with GitNexus and Serena** (both already cover semantic/graph code navigation here and are more capable) — prefer those two for SenseBridge work; treat glyph as a lightweight fallback only |

Adding an MCP server to this repo requires: local-first, least privilege,
a row in this table, and — if it could ever see user-surroundings data — a
privacy-doc update per `docs/PRIVACY.md`.

## Guardrails required for every tool, MCP server, script, hook, or utility

This is a blocking requirement, not a suggestion — apply it before adding
anything under `scripts/`, `tools/`, `.githooks/`, `.claude/hooks/`, an MCP
server config, or any other executable automation in this repo:

- **Fail closed, fail loud.** Shell: `set -euo pipefail`. Node/other:
  non-zero exit and a clear stderr message on error, never a silent no-op on
  an unexpected condition.
- **Validate and quote everything.** Allowlist input (e.g. `audits/scripts/new-audit.sh`'s
  type enum), quote every variable expansion, and prefer argv-array process
  spawning (`execFileSync(cmd, [args])`) over shell string interpolation —
  never build a shell command by concatenating untrusted input.
- **Bound the blast radius.** No destructive action (delete, force-push,
  overwrite, `main`-branch push) without an explicit opt-in flag or an
  already-documented exception; time out or cap anything that could run away
  (see `.claude/hooks/limit-agent-fanout.sh`'s session cap,
  `.githooks/post-checkout`'s rebuild timeout).
- **Least privilege.** Local-first; no network call, no credential, no
  broader filesystem access than the task needs. A new MCP server follows
  the row above; a new script or hook follows the same principle.
- **Advisory vs. blocking, stated explicitly.** Say in a comment whether a
  missing dependency or failed check blocks (exits non-zero) or just warns
  (see `scripts/setup.sh`'s required-vs-advisory split) — never leave it
  ambiguous.
- **No secrets, ever.** Nothing that reads, logs, or embeds a credential —
  see `tools/check-sensitive-files.mjs` and `docs/ENVIRONMENT.md`.

Existing scripts/hooks in this repo (audited 2026-07-17) already follow this;
use them as reference implementations rather than reinventing the pattern.

---

Need help? See [`SUPPORT.md`](../SUPPORT.md).
