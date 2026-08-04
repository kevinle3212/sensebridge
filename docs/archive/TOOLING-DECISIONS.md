---
title: Tooling decisions — archive
---

# Tooling decisions — archive

The full decision history for every tool SenseBridge has considered:
why it was chosen or refused, what broke, what superseded what, and the
dated corrections behind each row. Split out of
[`docs/TOOLING.md`](../TOOLING.md) on 2026-08-01, when that file had grown
to 92 KB (~23k tokens to read) and had become session-by-session
archaeology rather than a reference.

`docs/TOOLING.md` is the current-state matrix and remains authoritative
for **what is installed and how to run it**. This file is the *why*, and
is append-only in spirit: correct an entry here rather than deleting the
history it records. Every entry below is reproduced verbatim from the
pre-split file.

---

## Project-level (in this repository)

### Git hooks

**Where** — `.githooks/` (`pre-commit`, `commit-msg`, `pre-push`, `post-commit`, `post-checkout`, `post-merge`)

**Why project-level** — Shareable quality gate; enabled by `scripts/setup.sh` via `core.hooksPath`. `commit-msg` prefers commitlint (see the "Commitlint" row below) when the root `npm ci` has been run, falling back to a dependency-free bash regex otherwise, so the hook still works with no Node installed. `pre-commit` also lints staged `.github/workflows/*.yml` with actionlint (advisory if not installed). `pre-push` mirrors the CI build gate and blocks direct pushes to `main`, and also runs a local `osv-scanner` dependency scan mirroring `security.yml`'s osv-scan job when `osv-scanner` is installed (`brew install osv-scanner`; advisory-only if it isn't, same as the `ggshield` row below); `post-merge` flags manifest/toolchain files a pull just changed, and — only when the merge lands on `main` and touches `website/` — refreshes `website/tsconfig.debug.json`'s diagnostics output (`npm --prefix website run typecheck:debug`) so it never runs as part of the test suite or `pre-push`, only once code actually reaches `main`. `post-commit`/`post-checkout`/`post-merge` also each carry a hand-maintained, advisory-only GitNexus staleness reminder (see the GitNexus row) — separate from the Graphify auto-rebuild blocks those first two files otherwise contain

### Commitlint

**Where** — Root `package.json` (devDependencies only, no runtime deps), `commitlint.config.js`, `package-lock.json`

**Why project-level** — Added 2026-07-23 to keep manually-typed commits (not just agent-authored ones) consistent with the conventional-commit format — a local hook is always bypassable (`--no-verify`, or Node simply not installed), so `.github/workflows/commitlint.yml` runs it blocking in CI over every commit in a PR's range plus the PR title (the eventual squash-merge message). Rules in `commitlint.config.js` mirror `.githooks/commit-msg`'s bash-regex semantics (same 11 types, 72-char subject cap); the bash regex remains the dependency-free local fallback, so this is additive, not a replacement. This was the repo's first root-level Node surface; the root `package.json` has since also become the script command center (next row), but its dependency list stays commitlint-only — no runtime deps, no build stack

### Command center

**Where** — Root `package.json` `scripts`, `website/package.json` `scripts`; documented in [`docs/ENVIRONMENT.md`](../ENVIRONMENT.md#command-center)

**Why project-level** — Added 2026-07-28. Every routine command is an `npm run` script, so `npm run` with no arguments is the discoverable index of what the repo can do — the entry point an agent finds without being told. The scripts are thin wrappers around the `scripts/*.sh`, `tools/*.mjs`, and `xcodebuild` invocations CI and the git hooks already run, never reimplementations: `scripts/app.sh` replaced the device build/install block that existed only as copy-paste prose in `CLAUDE.md`, and `scripts/check-links.sh` replaced the link checker that was inlined in `ci.yml` and therefore only runnable by pushing. Both are now the single code path for local and CI runs

### Actionlint

**Where** — `.githooks/pre-commit` (staged-workflow-scoped, advisory), `.github/workflows/actionlint.yml` (blocking)

**Why project-level** — Added 2026-07-23 alongside Commitlint. Lints `.github/workflows/*.yml` for syntax/expression errors and shellchecks `run:` blocks. No official GitHub Action exists for it; CI downloads the pinned release binary and verifies its SHA256 before running, tighter supply-chain control than trusting a third-party action wrapper (see the workflow file's header comment for the version-bump procedure)

### Markdownlint

**Where** — `.markdownlint.jsonc` (rules), `.markdownlint-cli2.jsonc` (CLI globs/ignores — repeats `.markdownlintignore`'s excludes explicitly since the CLI doesn't appear to load that file automatically), `.githooks/pre-commit` (whole-repo, advisory alongside the other node-gated checks), `.github/workflows/ci.yml`'s `docs-links` job (blocking)

**Why project-level** — Config existed before either was wired in; added 2026-07-25. `MD033` allowlists `img`/`details`/`summary` (headshot photos, collapsible sections already used deliberately) rather than rewriting that markup — everything else stays flagged. Deliberately unpinned (`npx markdownlint-cli2`, resolved fresh each run) rather than a `website/`-style devDependency, since its globs cover the whole repo, not just one directory

### Claude Code hooks

**Where** — `.claude/hooks/` (twelve shell scripts + `react-doctor.mjs` and `prefer-rtk-shape.mjs`), wired in `.claude/settings.json`

**Why project-level** — Session-level guardrails the git hooks can't see: `cap-large-read.sh` + `warn-duplicate-read.sh` + `prefer-serena.sh` (PreToolUse Read — token discipline; `prefer-serena.sh` added 2026-07-30, advisory-only: once per file **per tool** per session, on any `.swift`/`.ts`/`.tsx`/`.js`/`.jsx`/`.mjs`/`.cjs` file with 80+ lines. Registered **twice**: on `Read` it nudges toward Serena's `get_symbols_overview`/`find_symbol`/`find_referencing_symbols` instead of a whole-file read (skipped when a `limit` ≤ 80 already makes the read targeted); on `Edit`\|`Write`\|`MultiEdit` it nudges toward `replace_symbol_body`/`rename_symbol` for whole-symbol rewrites, while saying plainly that a raw edit is correct for sub-symbol changes. Widened from Read-only/150-line on 2026-07-30 because the original gating made it fire so rarely it was effectively inert, and because the edit half of the hierarchy had nothing enforcing it at all — the Serena-side equivalent of RTK's automatic Bash rewrite below, needed because nothing else enforces the CLAUDE.md "reach for Serena first" rule), `limit-agent-fanout.sh` (PreToolUse Agent — subagent cap), `guard-main-commit.sh` (PreToolUse Bash — denies `git commit` on `main`, complementing `.githooks/pre-push`), `guard-destructive-git.sh` (PreToolUse Bash — denies `git reset --hard`, force-push to `main`/`master`, `git branch -D`), `guard-protected-delete.sh` (PreToolUse Bash, unconditional — denies `rm`/`git clean`/`git checkout`/`git restore` targeting `sessions/`, `legal/`, `audits/`, gitignored signing/secrets config, or `.git/`), `guard-serena-legal.sh` (PreToolUse on Serena's six mutating tools — mirrors `Edit(legal/**)` for Serena, since MCP tool permission rules can't glob-scope by argument the way the built-in `Edit`/`Read`/`Grep` tools can), `check-md-links.sh` (PostToolUse Edit/Write — flags broken relative links in edited `.md` files, advisory), `session-log-reminder.sh` (Stop — nudges the hourly session log per `CLAUDE.md`), `handoff-clear-reminder.sh` (Stop — added 2026-07-31, blocks once when `tmp/handoff.md` still holds a **finished** plan, per `CLAUDE.md` → "Durable State": a finished plan left in place is auto-loaded into the next session as live work that never happened. Deliberately gated on "no unchecked `- [ ]` item remains" rather than "file is non-empty" — a Stop hook fires at the end of every turn, and a plan is *supposed* to be non-empty for the whole middle of a task, so a non-empty gate would fire on every turn of normal multi-step work and fight the workflow it protects. Only the script references `tmp/handoff.md`; the path never enters `.claude/settings.json`, which `tools/check-settings-hooks.mjs` forbids. Self-check: `bash .claude/hooks/tests/handoff-clear-reminder.test.sh`), `announce-tooling.sh` (SessionStart, `startup`\|`resume`\|`clear` — prints a `systemMessage` confirming the Serena binary and RTK's version/hook are both live for the new session, since neither otherwise announces itself: Serena only appears once an `mcp__serena__*` tool is actually called, and RTK's Bash-rewriting hook produces no tool call of its own), `prefer-rtk-shape.mjs` (PreToolUse Bash, unconditional — added 2026-07-31 as an advisory nudge, converted the same day to an **auto-rewrite**: it emits `updatedInput` so `rtk` fires on shapes RTK's own hook skips, rather than only warning about them. RTK's rewrite (see the RTK row below) matches on command **shape**. Probed directly against `rtk hook claude` (rtk 0.44.1) on 2026-07-31: bare commands, `&&` chains, and `;` chains **are** rewritten (`cd /tmp && git status` → `cd /tmp && rtk git status`); pipes (`git status \| head -5`), redirects (`… > out`, `… 2>&1 \| tail`), and loop bodies (`for f in a b; do cat $f; done`) are **not** — the raw output reaches context and `rtk gain` never moves. Measured the day it was added: one bare `git status` saved 642 tokens, the piped form saved nothing. Two corrections landed the same day, both from testing the rewrite instead of assuming it: the original hook nudged on `&&`/`;` chains that RTK already handles (making most of its nudges false positives) and missed redirects and loops entirely; and its once-per-command-per-session cache meant one early `git` nudge bought silence for every later piped `git`, which is precisely how the leak stayed invisible. Now triggers on the full measured leak set — pipes, redirects, loop bodies, command substitution (`echo "$(git status)"`, `x=$(git status)`, backticks), subshells, and `eval`/`sh -c` indirection — while staying silent on `&&`, `;`, `\|\|`, and `&`, which RTK does rewrite. `\|\|` is neutralised before the pipe test, since flagging it was a false positive caused purely by that operator containing a `\|`. Only **single**-quoted spans are stripped before scanning (they never expand, so `git log --grep '>'` is not misread as a redirect); double-quoted spans are deliberately kept, because `"$(git status)"` really does run a command and dropping it would hide the most common leak of all — the residual cost is a false positive on something like `git commit -m "a > b"`, the cheaper error for an advisory hook. Substitutions, subshells, and redirect targets become statement breaks so the command *inside* them is scanned on its own, wrapper words (`eval`, `sh -c`, `xargs`, `time`, `do`/`then`/`else`) and leading `VAR=` assignments are peeled (bounded to ten iterations so a non-consuming match can never hang the session), the stage index resets at each `;`/`&&` (so the `wc` leading its own statement in `echo x; wc -l foo \| cat` is not mistaken for a pipeline filter), segments already prefixed `rtk` are skipped, and pipeline **consumers** (`head`, `wc`, `jq`, …) in non-leading position are skipped so ordinary `echo x \| wc -l` stays quiet. **It does not hardcode a `cmd` → `rtk cmd` table**, because RTK's mapping is neither identity nor word-level: `cat` *and* `head` both map to `rtk read`, while `git x` is refused and `git status` accepted — the answer depends on the subcommand. Each candidate segment is instead handed to `rtk hook claude` as a synthetic bare command (~11 ms) and RTK's own answer is spliced back at the original offsets, right-to-left; a segment RTK declines is left untouched. That keeps the two in lockstep and makes an invalid form like `rtk cat` impossible to emit — which a prefix table would have produced, and which the advisory version's own message wrongly told the caller to type. RTK's rewrite is all-or-nothing per line, so one pipe anywhere makes it skip segments it would otherwise have compacted; this hook fills exactly that gap and acts **only** on lines RTK declined, so the two never both emit `updatedInput` for the same call. **Tradeoff, owner-approved 2026-07-31:** compaction is lossy, so rewriting inside a pipeline, redirect, or substitution can change what a command produces — `git log \| grep foo` greps summarized text and `git diff > patch.diff` writes a patch that will not apply. Escape hatch: write the call as `rtk proxy <cmd>`, which executes raw without filtering; segments already starting with `rtk` are never touched. Verified end-to-end against live `rtk hook claude` output across 18 shapes, plus a live harness run where a piped `git status --short \| head -5` executed as `rtk git status --short` and moved `rtk gain`'s counter. This is the Bash-side counterpart to `prefer-serena.sh` above, and exists for the same reason: `CLAUDE.md` already stated the rule and it was still violated within minutes, because the failure is completely silent. Self-check: `bash .claude/hooks/tests/prefer-rtk-shape.test.sh`). `guard-main-commit.sh` and `guard-destructive-git.sh` are each registered **twice** — once gated `"if": "Bash(git *)"`, once `"if": "Bash(rtk git *)"` — so RTK's transparent `git status` → `rtk git status` rewrite (see the RTK row below) can't silently slip a destructive command past a guard whose `if` only matched the unwrapped form

### gitleaks config

**Where** — `.gitleaks.toml`

**Why project-level** — Shared by the pre-commit hook and any local sweep; CI uses TruffleHog (complementary: local pattern scan pre-commit, verified-credential scan on push). Extends the default ruleset with **AI-provider key rules the default misses** — verified 2026-07-16 against gitleaks 8.30.1, which caught only `github-pat`/`gcp-api-key` and scanned Anthropic, both OpenAI formats, and Hugging Face **clean**. `sk-ant-` is this repo's likeliest leak. Carries **no path allowlist**: it previously excluded `docs/**.md` + `audits/**.md`, so an identical GitHub PAT was blocked at the repo root and silently allowed in `docs/`. False positives go to `.gitleaksignore` by fingerprint, never back into a blanket path rule

### ggshield config

**Where** — `.gitguardian.yaml`

**Why project-level** — Third, independent secret-detection layer (added 2026-07-20): GitGuardian's hosted detector set, run locally by `.githooks/pre-commit` (advisory if `ggshield` isn't installed/authenticated) and in CI by `.github/workflows/security.yml`'s `ggshield` job. `exit_zero: false` — strict, any finding fails the scan. Same no-path-allowlist stance as `.gitleaks.toml` and for the same reason; false positives go in `secret.ignored_matches` by fingerprint. CI needs the `GITGUARDIAN_API_KEY` repository secret (owner action, not yet set) or the job fails closed

### Sensitive-file check

**Where** — `tools/check-sensitive-files.mjs`

**Why project-level** — Stdlib-only Node script; the **second local layer, not a duplicate** of gitleaks — pre-commit runs gitleaks only when installed and silently skips it otherwise, so on a machine without it this is the sole gate before a public push. Guards signing/credential material (iOS-specific formats), provider tokens, hardcoded machine paths, and **gitignored-but-force-added files** (`git add -f NOTES.local.md`), which it detects via `git check-ignore --no-index` rather than re-encoding `.gitignore` — a second copy of those rules would drift, and negations like `!tmp/README.md` make hand-rolled matching wrong both ways. `--no-index` is load-bearing: without it, check-ignore consults the index and never reports a staged path as ignored, which is precisely the case being caught

### Settings-hook check

**Where** — `tools/check-settings-hooks.mjs`; enforced by `.githooks/pre-commit`, also `npm run check:hooks`

**Why project-level** — Guards the tracked `.claude/settings.json` hook table against two silent failures. **Owner-personal hooks:** the `tmp/handoff.md` loader belongs only in `~/.claude/settings.json` — `tmp/` is gitignored, so for a contributor the copy reads a file that never exists, and for the owner it fires the loader twice per session start. **Double registration:** the same command under the same matcher, registered twice. The duplicate key is `(event, matcher, if, command)` rather than the command alone, because identical commands under *different* guards are deliberate — `guard-main-commit.sh` is registered once for `Bash(git *)` and once for `Bash(rtk git *)` so RTK's transparent rewrite cannot slip past it. Exists because the handoff duplicate was removed on 2026-07-31 at 12:00 PST and was back by 17:00 the same day, costing ~1.3KB of duplicated context per session with no failing signal. Separately, `npm run check:hook-tests` (added 2026-07-31, also in the `check` chain) runs every `.claude/hooks/tests/*.test.sh` self-check, and `npm run lint:shell` was widened the same day to shellcheck `.claude/hooks/*.sh` and its tests — until then the hook scripts had no repo-level lint or test gate at all, so a regression in an advisory hook would have stayed silent, which is the exact failure mode those hooks exist to prevent

### BMAD config check

**Where** — `tools/check-bmad-config.mjs`; enforced by `.githooks/pre-commit`, also `npm run check:bmad`

**Why project-level** — Asserts `user_skill_level` reads `expert` in **both** `_bmad/bmm/config.yaml` and `_bmad/custom/config.user.toml`. The YAML is installer-generated and `npx bmad-method install` rewrites it back to `intermediate`; the TOML is the file the owner edits, the YAML is the one most BMAD skills actually read, so a reset silently degrades every BMAD skill to padded explain-every-step output with nothing failing. Replaces a standing "re-apply after any upgrade" TODO item — a recurring manual re-verification is a test that hasn't been written yet. Proven against all three regression shapes (installer reset, key deleted, file missing)

### SwiftLint / SwiftFormat

**Where** — `scripts/lint.sh` (configs land with `app/`)

**Why project-level** — Binaries are global (Homebrew); the invocations and future configs are repo-specific

### Serena MCP

**Where** — `.mcp.json`, `.serena/project.yml` (`languages:`)

**Why project-level** — Per-project semantic indexing; least privilege — local process, no network, project-scoped. Update `languages:` whenever a new language is introduced (e.g. `swift` once `app/` lands) so its language server starts. Each `serena start-mcp-server` instance opens a local **web dashboard** (session log, active tool calls, on-the-fly config) at `http://localhost:24282/dashboard/` — bumping to `24283`, `24284`, etc. per concurrent instance; `web_dashboard_open_on_launch: false` in the user-global `~/.serena/serena_config.yml` keeps it from popping a browser tab on every session, so open it manually or ask the agent to via Serena's `open_dashboard` tool

### CI/CD

**Where** — `.github/workflows/`

**Why project-level** — CI, security scanning (CodeQL + TruffleHog + GitGuardian + OSV + Semgrep + GitHub Dependency Review + sensitive files), Claude PR review, Dependabot auto-merge

### Agent instructions

**Where** — `AGENTS.md` + thin pointers (`CLAUDE.md`, `GEMINI.md`, `.cursor/rules/`, `.github/copilot-instructions.md`)

**Why project-level** — One canonical instruction file, agent-agnostic; pointers prevent lock-in and duplication

### Per-agent configs

**Where** — `.codex/` (AGENTS.md, `config.toml`, `hooks.json`), `.gemini/settings.json`, `.copilot/` (instructions + MCP), `.continue/rules/`, `.windsurf/` (rules + MCP), `.openclaw/README.md`, `.cursor/mcp.json`, `.vscode/mcp.json` (VS Code's own Copilot Chat agent mode — separate from `.copilot/mcp-config.json`, which is the Copilot CLI), `.agents/mcp_config.json` + `.agents/rules/precedence.md` (Antigravity — see "Antigravity vs. Gemini CLI" below)

**Why project-level** — Each wires Serena MCP and defers to root `AGENTS.md` — configuration without instruction duplication

### Continue config template

**Where** — `.continue/config.template.yaml`, `.continue/README.md`

**Why project-level** — Example only, never active config (Continue reads the user-global `~/.continue/config.yaml`); shareable starting point so a new machine doesn't hand-roll the role/model setup documented in [`docs/OLLAMA.md`](../OLLAMA.md)

### Skills / reviewer personas

**Where** — `.agents/`, `.claude/`, `.cursor/`, `.gemini/`, `.github/` skills dirs

**Why project-level** — Project-doctrine-specific (safety framing, accessibility, model licensing); includes the `council` decision-review skill, the `website-design` integration router, and the vendored `seo-schema`/`seo-technical` offline SEO skills (from `AgriciDaniel/claude-seo`, MIT — see `CREDITS.md`), all mirrored across all five harness dirs via `tools/sync-skills.mjs` (next row)

### Mirrored-skill sync

**Where** — `tools/sync-skills.mjs`; enforced by `.githooks/pre-commit` and CI's docs-links job (both run `--check`)

**Why project-level** — Canonical source for hand-mirrored skills is `.claude/skills/<name>/`; the tool regenerates the `.agents`/`.cursor`/`.gemini`/`.github` copies from it, applying the two deliberate per-harness path substitutions as data-driven rules, so the copies **cannot drift silently**. Edit only the canonical copy, then run `node tools/sync-skills.mjs`. Excludes `impeccable`, which is vendor-managed (`npx impeccable check`/`update`) with intentionally different per-provider content — and, for the same reason, `react-doctor` (see the "React Doctor, React Scan" row above), which is vendor-managed by its own `install`/`ci install` CLI, not this tool

### Review companions

**Where** — `REVIEW.md` (root), `.claude/commands/security-review.md`

**Why project-level** — Extend the built-in `/code-review` and `/security-review` with project severity overrides, skip paths, and on-device/privacy/model-license checks — additive, not a fork. See "Built-in reviews — extended, not replaced" below

### Audit system

**Where** — `audits/`

**Why project-level** — Append-only; process docs (`README.md`, `GOVERNANCE.md`, `AGENT-GUIDE.md`, `scripts/`, `templates/`) are tracked, but report findings themselves are gitignored/local-only — see `audits/README.md`

### Marketing website

**Where** — `website/` (`package.json`, `.stylelintrc.json`, `.prettierrc`, `eslint.config.mjs`, mostly static HTML/CSS via Astro)

**Why project-level** — The one deliberate exception to "no web stack" — copy still follows `docs/SAFETY-FRAMING.md`. Node tooling (Stylelint, Prettier, ESLint) is scoped to this directory only via `.github/workflows/website-ci.yml` (path-filtered) and its own `dependabot.yml` entry. `eslint.config.mjs` is a strict flat config (TypeScript, React Hooks, `jsx-a11y` strict, security). **React (2026-07-20):** `@astrojs/react` is wired in `astro.config.mjs`; React only ships to a page when a component opts into a `client:*` hydration directive (Astro islands), so the zero-JS-by-default posture holds until a component actually needs one — no component uses React yet, this is framework-ready capacity, verified end-to-end (typecheck/lint/build/hydration) but not yet adopted by any real UI; see `website/README.md`

### React Doctor, React Scan

**Where** — `website/package.json` — React Doctor in `devDependencies`, React Scan in **`dependencies`** (added 2026-07-20 alongside the React integration above)

**Why project-level** — React Doctor (`npm run audit:react`/`npm run doctor`, both `react-doctor --no-telemetry` — `--no-telemetry` is load-bearing for this repo's no-telemetry-by-default posture) is a static audit CLI for AI-agent-written React code (Hooks correctness, a11y, security, perf). Its `install`/`ci install` subcommands were run 2026-07-20, then **manually reconciled to this repo's actual layout** — the upstream CLI assumes npm-root == git-root, which isn't true here (npm root is `website/`, git/agent-config root is the repo root), so its output had to be relocated by hand: skill files → `.claude/skills/react-doctor/`, `.agents/skills/react-doctor/`, `.continue/skills/react-doctor/`, `skills/react-doctor/` (matching this repo's existing per-harness layout, not the tool's own `website/`-nested defaults); agent hooks → `.claude/hooks/react-doctor.mjs` + a merged `PostToolBatch` entry in `.claude/settings.json`, `.cursor/hooks/react-doctor.mjs` + a merged `postToolUse` entry in `.cursor/hooks.json`; the pre-commit integration was hand-rewritten (not the tool's auto-inserted version) to match the existing `cd website && ...`, staged-changes-only pattern already used for `lint-staged` in `.githooks/pre-commit`; the CI workflow was moved from the tool's default `website/.github/workflows/react-doctor.yml` (inert — GitHub Actions never discovers workflows outside the repo-root `.github/workflows/`) to `.github/workflows/react-doctor.yml` with an explicit `directory: website` input, path-filtered like `website-ci.yml`, and the third-party action pinned to the commit behind the `v2` tag (same convention as `security.yml`'s `ggshield` job) — **`blocking: warning` since 2026-07-25** (any finding fails the check, holding the scan at zero; at `blocking: error` the gate was vacuous, because every finding this repo has ever produced was warning-severity). The gate is deliberately "zero findings" rather than a numeric score: React Doctor's score comes from a **remote score API**, and `--no-telemetry` is documented upstream as an alias for `--no-score`, so a printed score would mean egress. Known false positives are suppressed per-file/per-rule with rationale in `website/doctor.config.jsonc` — React Doctor's dead-code pass does not follow imports out of `src/layouts/**`, so components reachable only through `BaseLayout.astro` read as orphaned; no lint rule is weakened (`react-doctor rules list --configured` returns nothing). **Caution for future runs:** the CLI's own `install`/`ci install` **will misplace files again** if re-run naively — always verify output against this repo's actual (root-vs-`website/`) layout before trusting it, and never run it with cwd or `--cwd` pointed anywhere that lacks a clear project root, since it silently falls back to writing into your **global** `~/.claude/`/`~/.cursor/` config when it can't resolve one (this happened once during setup and was cleaned up). **Second caution — `GIT_DIR`:** `react-doctor --staged` resolves its git queries from `website/`, but an inherited `GIT_DIR` beats normal discovery, and git exports `GIT_DIR` to every hook. From a linked worktree (`.claude/worktrees/*`) that value is `.git/worktrees/<name>`, which makes its index-vs-worktree config precondition resolve against the wrong root and abort with "configuration differs between the index and worktree", listing every gitignored `node_modules/**/package.json` — the run passes standalone and fails only inside the hook, which makes it look transient. `.githooks/pre-commit` therefore calls it via `env -u GIT_DIR`; keep that wrapper on any new invocation that can run from a hook. React Scan is a render-profiler for spotting unnecessary re-renders. **There is no `npm run scan` script** — it was removed 2026-07-25 because react-scan 0.5.x's CLI exposes only `init` (a project scaffolder that installs packages and rewrites config), so the old `react-scan http://localhost:4321` invocation failed with `error: unknown command`. The profiler is instead wired as a dev-only inline import in `website/src/layouts/BaseLayout.astro`, gated behind a frontmatter-level `import.meta.env.DEV` check — just run `npm run dev`. It is interactive and browser-driven, emits no pass/fail and no score, and therefore **cannot** be a CI gate. It also still has nothing to profile: since 2026-07-25 `website/` does contain one `.tsx` file (`src/components/StructuredData.tsx`, the schema.org JSON-LD emitter), but it is server-rendered with no `client:*` directive, so no React ever renders in a browser. React Scan only becomes useful once a real hydrated island ships. That dev-only import is why React Scan sits in `dependencies`, not `devDependencies`: Vite resolves the import before dead-code-eliminating the `false` branch, so the package must be physically installed for `npm ci --omit=dev` builds to succeed (see `docker/README.md`'s "Build-time dependencies") — since the site is `output: "static"`, that check is resolved at build time, so the `<script>` tag itself never appears in the built HTML and zero bytes reach a production visitor

### Website hosting (Railway)

**Where** — `docker/` (`Dockerfile`, `Dockerfile.dockerignore`, `nginx.conf.template`, `docker-compose.yml`), `railway.toml` (repo root)

**Why project-level** — Deploys the static site only — no env vars, no backend, doesn't touch the app's serverless/on-device posture. Requires the Railway service's Root Directory to stay the **repo root** (dashboard setting, not a repo file) since the Dockerfile build context spans both `docker/` and `website/`. See `docker/README.md` and `website/README.md`'s Deployment section for the full setup flow

### Impeccable design-QA

**Where** — Skill in the 5 harness dirs; design context in `.agents/context/`; generated state in `.impeccable/` — **all rooted at the repo root, never `website/`** (see "Impeccable project root" and "Impeccable design context" below). Targets `website/` (via `npx impeccable install` + `/impeccable init`, run manually — see below); also runs **automatically** repo-wide via a `PostToolUse` hook in `.claude/settings.json` (`Edit\|Write\|MultiEdit` → `.claude/skills/impeccable/scripts/hook.mjs`)

**Why project-level** — Frontend design-anti-pattern detector (contrast, layout, typography); the hook self-filters to UI file extensions (`.tsx`, `.jsx`, `.html`, `.css`, etc. — see `hook-lib.mjs`) so it's a no-op on non-UI edits. `.github/workflows/website-ci.yml` runs `impeccable detect` (`continue-on-error: true` until `PRODUCT.md`/`DESIGN.md` are initialized). **The skill is installed in all 5 harness dirs** (`.agents/skills/impeccable/`, `.claude/skills/impeccable/`, `.cursor/skills/impeccable/`, `.gemini/skills/impeccable/`, `.github/skills/impeccable/`) by `npx impeccable install`, which is a **multi-provider build**, not five copies of one file: each copy's content correctly differs by target (invocation prefix `$impeccable` for Codex CLI vs `/impeccable` elsewhere, self-referential script paths, the model-name line, the project-context filename `AGENTS.md` vs `CLAUDE.md`, and Codex-only sections like its sub-agent/sandbox-permission guidance). **Never hand-edit one copy** — that both fights the next `npx impeccable update` and desyncs the others; use `npx impeccable check` to detect version drift and `npx impeccable update` to refresh all installed copies in place. `.agents/skills/impeccable/agents/*.toml` + `agents/openai.yaml` are Codex-CLI-specific sub-agent configs the installer places only in `.agents/`, by design — no equivalent needed elsewhere. **Always invoke it from the repo root** — see "Impeccable project root" below

### Handoff auto-load

**Where** — `SessionStart` hook in `.claude/settings.json` (matcher `clear\|startup` → `cat tmp/handoff.md`)

**Why project-level** — Surfaces the last `/handoff` entry automatically on `/clear` or a fresh session so work survives context resets; `tmp/handoff.md` is gitignored local scratch and the sole `/handoff` output — see [`.claude/commands/handoff.md`](https://github.com/kevinle3212/sensebridge/blob/main/.claude/commands/handoff.md)

### Notes (public / private split)

**Where** — [`NOTES.md`](https://github.com/kevinle3212/sensebridge/blob/main/NOTES.md) tracked; `NOTES.local.md` gitignored

**Why project-level** — **`NOTES.md`** is a public, committed, linted digest: durable contributor-facing findings, each pointing at the doc that owns the detail (never a second copy of it). **`NOTES.local.md`** is private — the user's own personal and machine-specific notes, not written by `/handoff` — and must never be committed. `NOTES.md` states the rule; `/handoff` step 5 is where the digest entry gets written

### Workflow commands

**Where** — [`.claude/commands/cleanup-notes.md`](https://github.com/kevinle3212/sensebridge/blob/main/.claude/commands/cleanup-notes.md), [`.claude/commands/session-log.md`](https://github.com/kevinle3212/sensebridge/blob/main/.claude/commands/session-log.md), [`.claude/commands/todo-groom.md`](https://github.com/kevinle3212/sensebridge/blob/main/.claude/commands/todo-groom.md)

**Why project-level** — `/cleanup-notes` grooms the private `NOTES.local.md` (consolidates personal/reference material, collapses any legacy handoff-style entries, surfaces open items; backup in `tmp/`, never commits); `/session-log` encodes the mandatory `CLAUDE.md` session-log rule (log entry + `TODO.md` follow-up mirroring); `/todo-groom` re-grounds `TODO.md` against actual repo state using the file's own completion-annotation rule. All three are thin wrappers around rules that already live in `CLAUDE.md`/`TODO.md` — mechanics only, no duplicated policy

### CodeRabbit

**Where** — `.coderabbit.yaml`, path-scoped to `website/**` only

**Why project-level** — Second reviewer for the one part of the repo `claude-code-review.yml`'s doctrine-tuned prompt wasn't written for (general web/CSS quality). Requires the CodeRabbit GitHub App installed on the repo (owner action, not yet done)

### GitNexus (`gitnexus` npm CLI)

**Where** — Installed globally (`npm install -g gitnexus`); index at `.gitnexus/` (gitignored); config at `.gitnexusrc` (`skipContextFiles: true` so it never touches our hand-curated `CLAUDE.md`/`AGENTS.md`)

**Why project-level** — Knowledge-graph code navigation (call chains, blast-radius/impact analysis, clusters), alternative/complement to Graphify+Serena. `gitnexus analyze` indexes the repo; `gitnexus setup -c claude` wires the MCP server + PreToolUse/PostToolUse hooks into the **user-global** `~/.claude/` config (not this repo's tracked files — reversible any time with `gitnexus uninstall`). Fully local: parsing, graph store, and embeddings (transformers.js/ONNX) all run on-device with no network calls; only the optional `gitnexus wiki` command needs an LLM API key, and this repo doesn't use it. Corrects a prior mistaken doc entry here that described a VS Code extension called "Nexus" requiring an API key for chat/embeddings — no such tool matches that description; the real `Nexus-tree.nexus-extension` on the VS Code Marketplace is an unrelated Next.js component-tree visualizer with no CLI, evaluated and not used. **Freshness**: the user-global PostToolUse hook only nudges the agent to reindex inside a Claude Code session; unlike Graphify (below), GitNexus ships no `hook install` equivalent, so `.githooks/post-commit`/`post-checkout`/`post-merge` each carry a small hand-maintained, advisory-only block (never blocks, never runs `analyze` itself — a full rebuild can take up to ~120s and an unclean kill risks index corruption, per the vendor's own hook) that prints a stderr reminder to run `gitnexus analyze` after any commit/branch-switch/merge, once the repo has been indexed at least once. This covers git activity outside a Claude Code session (plain terminal, other editors, CI) that the vendor hook can't see

### Editor config

**Where** — `.vscode/extensions.json`, `.vscode/settings.json`

**Why project-level** — Recommended-extensions list + strict per-language formatting/lint settings; excludes generated dirs (`graphify-out/`, `.gitnexus/`, `tmp/`, `logs/`) from search/watch

### Agent/CI scratch space

**Where** — `tmp/`, `logs/`

**Why project-level** — Gitignored scratch dirs (`.gitkeep` + README tracked) so agents stop reaching for shared `/tmp` or leaving untracked litter at repo root

### Line-ending/merge hygiene

**Where** — `.gitattributes`

**Why project-level** — LF normalization, `linguist-generated` on `graphify-out/`, `.gitnexus/`, lockfiles

### Secret-scan overrides

**Where** — `.gitleaksignore`

**Why project-level** — Fingerprint allowlist for verified false positives, separate from the pattern rules in `.gitleaks.toml`; empty until a real false positive needs one

### Static analysis (generic)

**Where** — `.github/workflows/security.yml` → `semgrep` job (`p/security-audit`, `p/secrets`, `p/owasp-top-ten`, `p/swift`)

**Why project-level** — Scans scripts, workflows, `website/`, and (since `app/` landed) Swift — `p/swift` is in the job's config and verified clean, see `GAPS.md`'s H1 resolution

### Monthly log archive

**Where** — [`.agents/skills/monthly-log-archive/SKILL.md`](https://github.com/kevinle3212/sensebridge/blob/main/.agents/skills/monthly-log-archive/SKILL.md), `tools/condense-monthly-logs.mjs` (added 2026-07-21)

**Why project-level** — Stdlib-only Node script (no new deps) that condenses last month's gitignored `sessions/<YYYY-MM-DD>/*.md` into one `sessions/<YYYY-MM>/SESSIONS.md` and removes the per-day directories. For `audits/` it only ever builds a derived, regeneratable `audits/<YYYY-MM>/INDEX.md` linking to that month's reports — it never moves, edits, or deletes a report, since audits are append-only (`audits/AGENT-GUIDE.md`). The skill's description-based trigger ("today is the 1st") only fires if a session happens to start that day; a guaranteed trigger would need a `SessionStart` hook or a monthly `schedule` cron, neither added yet pending owner sign-off

### Completed-TODO archive

**Where** — `tools/archive-completed-todo.mjs` (added 2026-07-28), `~/Library/LaunchAgents/com.kevinkhanhle.sensebridge-archive-completed-todo.plist` (machine-global, not tracked)

**Why project-level** — Stdlib-only Node script that moves everything under `TODO.md`'s `## Completed` heading into a new `## Archived <date>` block in [`COMPLETED.todo`](https://github.com/kevinle3212/sensebridge/blob/main/COMPLETED.todo), replacing it with a one-line placeholder so `TODO.md` stays short. Paired with `tools/sweep-done-todo.mjs` (`npm run todo:sweep`, added 2026-07-31), which is the missing first half: it cuts every ticked bullet out of `TODO.md`'s dated To-Do sections into `## Completed`, grouped under the section heading it came from, and moves a section wholesale — preamble included — once all of its bullets are ticked. That step used to depend on remembering, so by 2026-07-31 there were **124 finished items** sitting in To-Do while this archive job reported "nothing to archive" on every run and the file grew to 4,166 lines; `--check` exits 1 if any remain, for use as a gate. Note the `## Archived <date>` stamp is **Pacific, not UTC** — `toISOString()` rolls over at 16:00/17:00 local, so an evening sweep used to file itself under tomorrow's date. The launchd job runs it every 3 days (`StartInterval: 259200`) with `WorkingDirectory` set to the repo root; load it with `launchctl load ~/Library/LaunchAgents/com.kevinkhanhle.sensebridge-archive-completed-todo.plist`. `COMPLETED.todo` carries the same `.vscode/settings.json` `files.associations` entry (`*.todo` → markdown) as any other `.todo` file, and is linted by `markdownlint-cli2` alongside `**/*.md` (both the pre-commit hook and CI's `docs-links` job pass it explicitly, since `.markdownlint-cli2.jsonc`'s own `globs` are overridden by CLI arguments)

---

## Global (installed on this machine)

### Xcode / Swift toolchain

**Status** — required

**Use here** — The build

### SwiftLint, SwiftFormat, xcbeautify

**Status** — installed (Homebrew)

**Use here** — Invoked by `scripts/lint.sh` once `app/` exists

### gitleaks

**Status** — installed

**Use here** — Pre-commit secret scan

### ggshield

**Status** — not installed — advisory (`brew install ggshield`, then `ggshield auth login`)

**Use here** — Pre-commit GitGuardian secret scan; CI runs regardless via the `ggshield` job, gated on the `GITGUARDIAN_API_KEY` repo secret

### semgrep

**Status** — installed

**Use here** — Ad-hoc local runs; CI coverage lives in `security.yml`'s `semgrep` job, including `p/swift` (added once `app/` landed)

### osv-scanner

**Status** — installed (Homebrew)

**Use here** — Pre-push dependency vulnerability scan (`.githooks/pre-push`), mirroring `security.yml`'s `osv-scan` job

### actionlint

**Status** — installed (Homebrew)

**Use here** — Pre-commit lint of staged `.github/workflows/*.yml` (`.githooks/pre-commit`, advisory if not installed); CI runs a version-pinned, checksum-verified copy of the same binary regardless (`.github/workflows/actionlint.yml`)

### gh

**Status** — installed

**Use here** — GitHub workflows

### Serena

**Status** — installed (`uv` tool)

**Use here** — Semantic code navigation via `.mcp.json`

### Graphify

**Status** — installed

**Use here** — Knowledge-graph queries; output (`graphify-out/`) is gitignored. Auto-rebuilds via versioned `.githooks/post-commit` + `post-checkout` (installed by `graphify hook install`, detached/non-blocking, skips rebases and graph-only changes); optional live mode: `graphify watch .` (needs `watchdog` in graphify's env). CI rebuilds it advisorily on `main` and uploads it as a downloadable artifact (`.github/workflows/graphify.yml`, scope in `.graphifyignore`). `npm run graph` (`PYTHONHASHSEED=0 graphify update .` then `tools/graph-visual.mjs`) renders the graph into the root README's animated `docs/assets/graph.svg` plus its reduced-motion twin `graph-static.svg` — both committed, since the graph itself never is; deterministic (seeded layout) so an unchanged graph re-renders byte-identically, and it excludes the per-harness agent-config mirrors so the picture shows SenseBridge rather than vendored tooling. `npm run graph:visual` redraws from the existing `graph.json` without a graphify rebuild. **Freshness and quality are both enforced.** `.githooks/pre-commit` re-renders and stages the pair whenever a commit touches `docs/`, `app/`, `website/src/`, `tools/`, or `scripts/` (SVG render only — ~1s of node; the graph itself is rebuilt by `post-commit`, so the picture is captioned "at commit &lt;sha&gt;" of the previous commit, by design). CI's `docs-links` job then runs `npm run check:graph` (`tools/graph-visual.mjs --verify`) as a **blocking** gate over the committed bytes: accessible `<title>`/`<desc>`, `role="img"`, a reduced-motion twin that really carries no `@keyframes`/`<animateMotion>`, size ceiling, well-formed XML (balanced groups, no unescaped `&`, not truncated), and both variants rendering the same graph. It lints the artifact rather than rebuilding and diffing, because the source commit is baked into the image — a fresh build at CI's `HEAD` is legitimately different bytes and would fail every PR. `.github/workflows/graphify.yml` stays advisory (`continue-on-error: true`) and is deliberately not the gate

### GitNexus (`gitnexus`)

**Status** — installed (`npm install -g gitnexus`)

**Use here** — Knowledge-graph code navigation via `.mcp.json`-equivalent wired into the user-global `~/.claude/` config (`gitnexus setup -c claude`), not this repo's tracked files. Index (`.gitnexus/`) gitignored; refresh with `gitnexus analyze`

### RTK (`rtk`)

**Status** — installed (`/opt/homebrew/bin/rtk`), global hook active since 2026-07-30 (`rtk init -g --auto-patch`; registers `rtk hook claude` as a user-global `PreToolUse`/`Bash` hook in the swap-account's `settings.json`, plus `@RTK.md` in the global `CLAUDE.md`)

**Use here** — Transparently rewrites Bash calls to their `rtk`-wrapped, output-compacted equivalent (`git status` → `rtk git status`, and likewise for `gh`, `grep`, `ls`, `find`, `diff`, test runners, package managers) before they run — no behavior change to what the command does, only to how much of its output reaches the model. **The rewrite matches on command shape, and the coverage is partial**: bare commands, `&&` chains, and `;` chains are rewritten; pipes (`git status \| head`), redirects (`… > out`, `… 2>&1 \| tail`), and loop bodies are silently *not*, so their raw output lands in context without even incrementing `rtk gain`. Run covered commands bare and shrink output with RTK's own flags rather than piping into `head`/`tail`; `prefer-rtk-shape.mjs` (hooks row above) auto-rewrites the leaking shapes. **Division of labor with Serena**: RTK compacts *shell command* output (git/gh/grep/ls/find/diff/tests); Serena replaces *code file* Read/Grep/Edit with symbol-level tools (`find_symbol`, `get_symbols_overview`, `replace_symbol_body`, …) — the two don't overlap or double-process the same call. Backed up before the patch to `settings.json.bak` in the same directory; reversible with `rtk init -g --uninstall`. Two follow-ups landed 2026-07-30: (1) the `@RTK.md` import was **silently dead** — `rtk init -g` wrote `RTK.md` into `CLAUDE_CONFIG_DIR` (the swap-account dir), but that dir's `CLAUDE.md` is a symlink to `~/.claude/CLAUDE.md`, so the relative import resolved against `~/.claude/`, where no `RTK.md` existed; fixed by moving the real file to `~/.claude/RTK.md` and symlinking it back, mirroring how `CLAUDE.md` itself is laid out. (2) The rewrite targets RTK actually emits for this repo's stack (`rtk rg`\|`jq`\|`npm`\|`npx`\|`swift`\|`xcodebuild`\|`tsc`\|`lint`\|`prettier`\|`format`\|`vitest`\|`playwright`\|`wc`\|`log`) were **not** in `permissions.allow`, so RTK's own rewrite turned pre-approved commands into prompts; they are allow-listed now, while `rtk run`/`rtk proxy`/`rtk pipe` are deliberately **ask**-listed because they execute arbitrary unfiltered shell. See the "Claude Code hooks" row above for why the two git-safety guards are registered twice to stay effective after this rewrite

### gstack

**Status** — installed (`~/.claude/skills/gstack`)

**Use here** — Web browsing + review/ship skill suite

### Gemini CLI

**Status** — installed 2026-07-30 (`npm install -g @google/gemini-cli`, v0.53.0, binary at `/opt/homebrew/bin/gemini`)

**Use here** — Was missing entirely until this date — this repo's `.gemini/settings.json` + `GEMINI.md` had project-level config with no local binary to use it

### Antigravity

**Status** — installed 2026-07-30 — IDE via `brew install --cask antigravity` (2.4.3, `/Applications/Antigravity.app`, 427MB) + CLI via `brew install --cask antigravity-cli` (1.1.8, `agy` binary at `/opt/homebrew/bin/agy`)

**Use here** — Reads this repo's `.agents/mcp_config.json` + `.agents/rules/*.md` (see "Antigravity vs. Gemini CLI" below), which predated the tool install. Homebrew also lists a third cask, `antigravity-ide` — **confirmed not the same thing** (raw cask source fetched from `Homebrew/homebrew-cask` 2026-07-30): it's a separate, older product (v2.1.1 vs. this row's v2.4.3, bundle ID `com.google.antigravity-ide`, its own `agy-ide` binary), distributed from Google's legacy `edgedl.me.gvt1.com` update CDN rather than the `antigravity-public` bucket the two installed casks share. Not installed, not needed

### Composio

**Status** — installed (binary at `~/.composio/composio`, v0.2.32 — **not on `$PATH`**, always use the absolute path), logged in as `kevinle3212@gmail.com`

**Use here** — Authenticated CLI reaching 1000+ third-party APIs. **A CLI, not an MCP server** — nothing to add to the MCP inventory below. Only the `github` toolkit is linked (`ACTIVE`, OAuth2, since 2026-07-25); every other service this repo touches is unlinked. Redundant with the `github` MCP + `gh` for GitHub work — its value here is services with no local integration. Per-toolkit status, coverage gaps, and linking steps: [`TODO.md`](https://github.com/kevinle3212/sensebridge/blob/main/TODO.md) → "Composio". Every `link` needs an owner browser click; treat every response as credential-bearing and never write one into a tracked file

### Ollama

**Status** — installed

**Use here** — Local LLM experiments only — **not** an app dependency; on-device inference uses Core ML/ANE, never a local server. Full setup, two-machine topology, and security posture: [`docs/OLLAMA.md`](../OLLAMA.md)

### Node, bun, uv, python3

**Status** — installed

**Use here** — Script runtimes only; no project package manifests

### Obsidian vault (`~/Vault`)

**Status** — present

**Use here** — Cross-project knowledge via the `vault-capture` skill (see `MEMORY.md`)

### WakaTime

**Status** — installed (key in `~/.wakatime.cfg`, `wakatime-cli` at `~/.wakatime/wakatime-cli`)

**Use here** — Automatic coding-time tracking; the on-device CLI posts heartbeats to the [WakaTime dashboard](https://wakatime.com/dashboard). **One key, many clients** — every client reads `~/.wakatime.cfg`, never a copy, so no secret enters the repo. Wired: **Claude Code** via a `PostToolUse` hook in the user-global `~/.claude/settings.json`; **VS Code** and **Cursor** via the WakaTime extension (Cursor's installed 2026-07-30 — `Cursor.app/Contents/Resources/app/bin/code --install-extension WakaTime.vscode-wakatime`, since Cursor is a genuine VS Code fork with Open VSX support). **Antigravity is not** — corrected 2026-07-30: `agy --help` exposes no `--install-extension`-style flag and the app bundle has no `code`-style CLI shim; it has its own unrelated plugin marketplace (`agy plugin install <target>`), and no WakaTime listing was found there. Still pending: **Xcode + Word/Excel/MySQL Workbench/Terminal** via the macOS menu-bar app (`brew install --cask wakatime`, Monitored Apps); **Codex CLI** via a per-repo `.codex/hooks.json` `PostToolUse` hook (the one project-level touchpoint). No official WakaTime plugin exists for Office/Workbench (app-level heartbeats only), the Copilot CLI (no hook API), or Antigravity (see above)

---

## Not needed (and why)

### SWC, Jest, Knip, Husky

**Reason** — `website/` is mostly static HTML/CSS — nothing for a bundler, test runner, or dead-code tool to do yet. Add if/when the site gains real JS/React logic beyond what ESLint already covers (see the "Marketing website" row above). Husky specifically: hooks are already dependency-free shell (`.githooks/`), no wrapper needed. SwiftLint/SwiftFormat plus Swift Testing (unit/integration) and XCTest (E2E/performance) cover the app — see [`TESTING.md`](../TESTING.md). **Commitlint was in this row until 2026-07-23** — adopted; see the "Commitlint" row above

### Playwright

**Reason** — iOS UI testing is XCUITest + VoiceOver passes; no browser E2E surface on the website yet (pa11y-ci covers its accessibility gate — see `website/README.md`'s Tooling section). Revisit if the site grows real interactive flows worth E2E-testing

### Vercel, Docker, Kubernetes

**Reason** — Serverless-by-doctrine for the **app**: there is no backend to deploy — a container platform would violate `docs/PRIVACY.md`. `website/` is a static site with no deploy target chosen yet (see `website/README.md`); revisit only for static hosting, never a container/orchestration platform

### `@costline/nexus-graph` (TrustLedger's `scripts/nexus-mcp.js`)

**Reason** — Different package from `gitnexus` (the "GitNexus" row above) despite the shared "Nexus" name — that TrustLedger-specific script still has no home here. GitNexus now covers the call-graph/navigation need it would have filled

### Python venv

**Reason** — No Python code in this repo

### Oracle tooling

**Reason** — No database; explicitly unjustified

### Dune MCP (global)

**Reason** — Crypto analytics for other projects; not referenced here

---

## MCP inventory

### serena

**Scope** — project (`.mcp.json` for Claude; `.codex/config.toml`, `.gemini/settings.json`, `.copilot/mcp-config.json`, `.windsurf/mcp_config.json`, `.cursor/mcp.json` for the others)

**Permissions** — Local process, project files only. Read/navigation tools **and the eight non-destructive mutating tools** (`replace_symbol_body`, `insert_after_symbol`, `insert_before_symbol`, `replace_content`, `rename_symbol`, `write_memory`, `edit_memory`, `rename_memory`) are allow-listed in `.claude/settings.json` (`permissions.allow`); `safe_delete_symbol` and `delete_memory` are ask-listed (never auto-run); the six mutating tools are guarded against `legal/**` by `guard-serena-legal.sh` (see the "Claude Code hooks" row above). The write tools were added to the allowlist on 2026-07-30 to close a **friction asymmetry that silently defeated the whole tier order**: `.claude/settings.local.json` sets `defaultMode: acceptEdits`, so a raw `Edit` ran unprompted while every Serena symbol-level edit raised a permission prompt — making the tool CLAUDE.md tells agents to prefer the strictly more expensive one to use, so they routed around it. Destructive tools stay gated; the guard hook still runs on all of them

**Status** — Active

### gitnexus

**Scope** — user-global (`~/.claude.json`, via `gitnexus setup -c claude`)

**Permissions** — Local process, project files only (no network calls)

**Status** — Active

### dune

**Scope** — user-global (`~/.claude.json`)

**Permissions** — Remote, read-only analytics

**Status** — Unrelated to SenseBridge; left global, nothing to remove here

### claude-in-chrome

**Scope** — user-global (extension)

**Permissions** — Site-gated browser automation

**Status** — Available; gstack `/browse` preferred per global CLAUDE.md

### perplexity (optional, per-developer)

**Scope** — user-global only — never project-scoped

**Permissions** — Remote search API; **every query is egress** and needs `PERPLEXITY_API_KEY`

**Status** — Not installed. Approved 2026-07-17 as a dev-research aid for any developer who wants it: `claude mcp add --scope user perplexity -e PERPLEXITY_API_KEY=<key> -- npx -y @perplexity-ai/mcp-server` (source: `perplexityai/modelcontextprotocol`, MIT, official). Never coupled to the shipped app or CI

### context7 (optional, per-developer)

**Scope** — user-global only — never project-scoped, same reasoning as perplexity above

**Permissions** — Remote docs-lookup API (Upstash); **every query is egress**, optional `CONTEXT7_API_KEY` for higher rate limits

**Status** — Installed 2026-07-20: `claude mcp add --scope user context7 -- npx -y @upstash/context7-mcp` (source: `upstash/context7-mcp`, MIT, official; unauthenticated — add `-e CONTEXT7_API_KEY=<key>` for a higher rate limit if needed later). Note: the unscoped `context7` npm package is a **different, unrelated** third-party CLI — do not confuse the two

### granola

**Scope** — user-global (`~/.claude.json`)

**Permissions** — Remote hosted MCP (`https://mcp.granola.ai/mcp`), owner's meeting notes

**Status** — Registered 2026-07-17 (owner override); **needs authentication** — owner completes OAuth via `/mcp`. Personal productivity; unrelated to the app, never touches repo data

### higgsfield

**Scope** — user-global (`~/.claude.json`)

**Permissions** — Remote hosted MCP (`https://mcp.higgsfield.ai/mcp`), AI media generation (egress on use)

**Status** — Registered 2026-07-17 (owner override); **needs authentication** — owner completes OAuth via `/mcp`. Any marketing use of generated media still passes the honesty-over-hype guardrails

### filesystem

**Scope** — user-global (`~/.claude.json`)

**Permissions** — Local process, filesystem read/write scoped to `$HOME`

**Status** — Added 2026-07-19, part of a personal global tooling build-out (`~/.claude/tmp/tools.md`); unrelated to SenseBridge, left global

### github

**Scope** — user-global (`~/.claude.json`)

**Permissions** — Remote GitHub API, token reused from `gh auth token`

**Status** — Added 2026-07-19, same build-out. Unrelated to SenseBridge's own `gh` CLI usage in workflows

### puppeteer

**Scope** — user-global (`~/.claude.json`)

**Permissions** — Local headless-browser automation

**Status** — Added 2026-07-19, same build-out. **gstack `/browse` remains the default for all agent browsing per the global standard** (same guardrail as `claude-in-chrome`/`agent-browser` above) — use this only when explicitly asked for scripted/programmatic browser automation, never as a substitute for `/browse`

### memory (`@modelcontextprotocol/server-memory`)

**Scope** — user-global (`~/.claude.json`)

**Permissions** — Local knowledge-graph memory store

**Status** — Added 2026-07-19, same build-out. **Distinct from claude-mem and from this harness's built-in auto-memory** — do not let all three collide; SenseBridge work should keep using the harness's built-in memory (claude-mem stays disabled here, see below), and this MCP memory server is not currently referenced by any SenseBridge workflow

### sequential-thinking

**Scope** — user-global (`~/.claude.json`)

**Permissions** — Local, structured-reasoning scratchpad only, no network

**Status** — Added 2026-07-19, same build-out

### glyph (`benmyles/glyph`)

**Scope** — user-global (`~/.claude.json`, binary at `~/.local/bin/glyph`)

**Permissions** — Local process, Tree-sitter symbol extraction, no network

**Status** — Added 2026-07-19, same build-out. **Heavy functional overlap with GitNexus and Serena** (both already cover semantic/graph code navigation here and are more capable) — prefer those two for SenseBridge work; treat glyph as a lightweight fallback only

### headroom

**Scope** — user-global (`~/.local/bin/headroom mcp serve`, stdio), registered 2026-07-30 via `headroom mcp install --agent claude`

**Permissions** — Local process; the MCP tools (`headroom_compress`/`headroom_retrieve`/`headroom_stats`, shown as `mcp__headroom__*`) call the local proxy on `127.0.0.1:8787`, not a remote API

**Status** — **Overlaps with RTK — evaluated and scoped down.** Headroom already had a separate, pre-existing footprint on this machine unrelated to SenseBridge: a launchd-managed proxy daemon (`com.headroom.default`, `~/.headroom/deploy/default/`) that had been running continuously since 2026-06-30, drifted to v0.28.0 with its original venv deleted from disk. Discovered mid-session while wiring up the narrow "MCP server only" scope the owner chose over Headroom's full proxy/`wrap claude` modes (which would fight RTK's PreToolUse rewriting — see the RTK row above). Fixing the daemon required `uv tool install --python 3.13 "headroom-ai[proxy,mcp]"` (the initial `[mcp]`-only install broke the live proxy — `ModuleNotFoundError: fastapi` — until `[proxy]` was added back) and a `launchctl kickstart -k gui/$UID/com.headroom.default` restart, which now runs v0.33.0 cleanly (`headroom doctor`: 0 failures). `HEADROOM_BUDGET=20` / `HEADROOM_BUDGET_PERIOD=daily` were added to the `# >>> headroom persistent env >>>` blocks in `~/.zshrc` and `~/.bashrc` (previously unlimited) — that first pass capped only future interactive/manual `headroom proxy`/`headroom wrap` invocations, not the already-deployed daemon, whose fixed `proxy_args` in `~/.headroom/deploy/default/manifest.json` predated the budget vars. **Closed 2026-07-30**: dropped to `HEADROOM_BUDGET=5` in both shell rc blocks, then, with owner go-ahead, applied to the **live daemon** via `headroom install apply --preset persistent-service --runtime python --scope user --providers manual --target codex --profile default --port 8787 --backend anthropic --mode token --no-telemetry --env HEADROOM_BUDGET=5 --env HEADROOM_BUDGET_PERIOD=daily` — the manifest's `base_env` now carries `HEADROOM_BUDGET: "5"`, and `headroom doctor` confirms `budget: ✓ pass — $5.0/daily budget enforced` with savings preserved across the restart (385,144 tokens / $1.93 lifetime, still current as of this check). **Superseded 2026-07-31** — the owner chose to route Claude Code through the proxy after all, so two things above no longer hold. (1) The $5/daily budget was raised to $1000: `--budget` rejects requests with HTTP 429 once reached, and the proxy meters subscription traffic at notional API prices (~$0.09 for one small request), so $5 would have 429'd a normal working session within the hour. Kept capped rather than removed, since the Codex/OpenAI path spends real money. (2) `ANTHROPIC_BASE_URL=http://127.0.0.1:8787` now routes Claude Code's own traffic through the proxy, currently per-project via `.claude/settings.local.json`. That routing, its tradeoffs (`/rc`, on-demand tool loading, and the 1M context window are gated client-side on the default endpoint), the SessionStart proxy-down guard, and full reversal steps are documented in `~/.claude/HEADROOM-ROUTING.md` — kept outside this repo because it is machine-level config, not project config. A PATH fix was also added to `~/.headroom/deploy/default/run-headroom.sh` and `ensure-headroom.sh`: launchd starts them with a minimal `PATH`, so the proxy could not see `rtk` and reported `context_tool` as not installed

---

## Claude skills, plugins, and evaluated-but-refused tools

Verbatim from the pre-split `docs/TOOLING.md`. The two Impeccable subsections that were here are omitted deliberately — they are live rules,
not history, so [`../TOOLING.md`](../TOOLING.md) remains their only home.

Installed globally (user scope) from source-verified marketplaces. Versions and
sources re-verified 2026-07-11 against upstream (GitHub API + release notes):

| Plugin | Source | Why |
| --- | --- | --- |
| superpowers 6.1.1 | `obra/superpowers-marketplace` | Engineering-workflow skills + skill search (TDD, debugging, planning dispatch). **Note:** the legacy `/brainstorm`, `/write-plan`, `/execute-plan` slash commands and the named `superpowers:code-reviewer` agent were **removed in 6.x** — do not reference them. 6.x also hardened the brainstorm server (per-session auth, sandboxing) and removed a Codex `SessionStart` auto-exec hook (net-positive) |
| claude-mem 13.10.2 | `thedotmack/claude-mem` | Cross-session memory capture/injection. **Disabled at project scope for SenseBridge** (`.claude/settings.json` → `enabledPlugins`) because the harness's built-in auto-memory already persists here — running both would inject duplicated context. Keep disabled here: claude-mem compresses sessions through a configured LLM provider (data egress) and has a history of local-surface issues (an unauthenticated local API on port 37777, since fixed; a `shell:true` spawn footgun, tracked upstream) — neither is a fit for this repo's on-device/no-telemetry posture. It stays available globally; never run both memory systems at once. **2026-07-19:** a personal global tooling build-out asked to wire claude-mem to Obsidian for token savings — see `TODO.md`'s "Global Claude Code tooling build-out" entry for the open question of whether that should touch this row |
| humanizer 2.8.2 | `blader/humanizer` | Strips AI-writing tells from prose/docs. **Guard:** never let a humanizer pass soften a required safety-framing hedge in app or marketing copy (see [SAFETY-FRAMING.md](../SAFETY-FRAMING.md)) |
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
| production-audit | `~/.claude/skills/production-audit/SKILL.md` | Local-evidence production-readiness audit (no external data egress) — complements, doesn't replace, this repo's own `audits/` append-only system and the [ci-green-gate](https://github.com/kevinle3212/sensebridge/blob/main/.agents/skills/ci-green-gate/SKILL.md) gates |
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
| notebooklm | `PleasePrompto/notebooklm-skill` (MIT) | Installed **files-only**; first run (owner-triggered, deliberately not done by an agent) creates a venv, pip-installs `patchright`, downloads Chrome, and persists Google session cookies to `~/.claude/skills/notebooklm/data/browser_state/` with anti-bot flags (`--no-sandbox`, stealth input). Personal-productivity tool for the owner's own NotebookLM account; **never invoke it from SenseBridge work** — [`NOTEBOOKLM.md`](../NOTEBOOKLM.md)'s manual path remains the project rule |
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

### BMAD-METHOD — project-level, committed and adopted (2026-07-31)

`bmad-code-org/BMAD-METHOD` v6.10.0 is installed **into this repo** (not just
globally) via `npx bmad-method install --yes --tools claude-code`. It ships
`_bmad/` (module core, scripts, config) and 46 skills under
`.claude/skills/bmad-*` — 248 files, all tracked.

**Adopted 2026-07-31.** A token audit that day found BMAD had been installed,
committed, and configured but invoked exactly once, costing ~2.2k tokens of
skill frontmatter per session for nothing. Rather than remove it, the owner
chose adoption; these are the wiring points:

- **`_bmad-output/project-context.md`** — the doctrine file every BMM skill
  loads on activation. It carries the four doctrines, the blocking gates, and
  the traps that look like success (simulator builds, green CI). This is the
  single source of doctrine for BMAD agents; do not restate it in agent
  descriptors. It is **tracked** despite living under the otherwise-ignored
  `_bmad-output/`: the rule is `_bmad-output/*` plus a
  `!_bmad-output/project-context.md` negation. The trailing `/*` is
  load-bearing — git does not descend into an excluded *directory*, so a
  negation beneath a bare `_bmad-output/` rule silently does nothing. Without
  it tracked, a fresh clone gets BMAD agents with no binding to the
  awareness-not-safety doctrine or the zero-unlabeled-elements gate.
- **`_bmad/custom/config.toml`** (team, committed) — binds `bmad-agent-dev`,
  `bmad-agent-architect`, and `bmad-agent-ux-designer` to this repo's gates.
  `description` is a scalar, so an override replaces the installer's text;
  each block preserves the original persona and appends one binding sentence.
- **`_bmad/custom/config.user.toml`** (personal, gitignored) — raises
  `user_skill_level` to `expert`.

**Config resolution has two paths, and they disagree by default.** 33 skills
read `_bmad/bmm/config.yaml` directly; only 6 call
`_bmad/scripts/resolve_config.py`, which merges four TOML layers
(`config.toml` → `config.user.toml` → `custom/config.toml` →
`custom/config.user.toml`, highest last). A value set only in the TOML layers
is therefore inert for most skills. `user_skill_level` is deliberately set in
**both** places; `_bmad/bmm/config.yaml` is installer-generated, so re-apply
it there after any BMAD upgrade.

Still open: several `bmad-*` skills overlap conceptually with this repo's
existing `.agents/skills/*` and review-agent infrastructure (e.g.
`bmad-code-review` vs. `code-reviewer`/`security-reviewer`). Prefer this
repo's own reviewers where they overlap — they encode the doctrines; the
BMAD equivalents do not.

### Built-in reviews — extended, not replaced

Built-in harness skills already cover code review, security review, deep
research, and scheduling. Rather than install competing review plugins, the repo
**extends the built-ins** through their documented, additive extension points
(Anthropic's own guidance: automated reviews complement, never replace, manual
review and the [ci-green-gate](https://github.com/kevinle3212/sensebridge/blob/main/.agents/skills/ci-green-gate/SKILL.md)):

| Companion | File | Extends |
| --- | --- | --- |
| Code-review guidance | [`REVIEW.md`](https://github.com/kevinle3212/sensebridge/blob/main/REVIEW.md) (repo root) | `/code-review` reads this as highest-priority, review-only instructions: project severity overrides (safety-framing = Critical, unlabeled UI = blocking, privacy-boundary = Critical), skip paths, and the honesty rule about what CI cannot prove |
| Security-review command | [`.claude/commands/security-review.md`](https://github.com/kevinle3212/sensebridge/blob/main/.claude/commands/security-review.md) | `/security-review` — runs the stock diff scan, then layers on the data-egress boundary, model-license, secret/signing-material, dependency-provenance, permission-scope, and workflow-integrity checks specific to an on-device app |
| Council | [`.agents/skills/council/SKILL.md`](https://github.com/kevinle3212/sensebridge/blob/main/.agents/skills/council/SKILL.md) (mirrored to `.claude/`, `.cursor/`, `.gemini/`, `.github/` skills dirs) | Independent multi-perspective review of an important, hard-to-reverse architectural decision **before** approval (architecture, safety-framing, accessibility, privacy/security, performance, licensing, simplicity seats). Advisory; reuses existing personas, does not replace owner sign-off or CI gates |

The Karpathy principles (think-before-coding, simplicity-first, surgical-changes,
goal-driven execution) are already encoded in the global `~/.claude/CLAUDE.md`
— that plugin would duplicate them, so it is deliberately **not** installed.

### Website design — required capability, integrated not duplicated

The public
[`website/`](https://github.com/kevinle3212/sensebridge/tree/main/website)
makes distinctive frontend design a real
need. It is served by the already-wired **impeccable** skill (execution +
critique/audit, brand register, AI-slop detection) plus Anthropic's official
**frontend-design** skill for design *direction*, with **ui-reviewer** and the
**accessibility** skill owning review. The
[`website-design`](https://github.com/kevinle3212/sensebridge/blob/main/.agents/skills/website-design/SKILL.md)
skill (mirrored to
`.claude/`, `.cursor/`, `.gemini/`, `.github/` skills dirs) is the router that
ties them together and enforces the two guardrails the generic tools do not
know: honesty-over-hype (no CTA/availability claims) and safety-framing on
product copy.

| Tool | Disposition | Why |
| --- | --- | --- |
| **Frontend Design** (`frontend-design@claude-plugins-official`, Apache-2.0) | **Installed** as a global (user-scope) plugin; wired via `website-design` | Anthropic-official (lowest supply-chain risk); SwiftUI is a supported stack, so it also informs app-side identity. Installed 2026-07-26 via `claude plugin marketplace add anthropics/claude-plugins-official` + `claude plugin install frontend-design@claude-plugins-official` |
| **UI/UX Pro** (`nextlevelbuilder/ui-ux-pro-max-skill`, MIT) | **Method folded in**; npm package **not installed** | The capability (style/palette/font-pairing selection, a design brief) is already covered by impeccable's `palette.mjs` + brand/product registers and the official frontend-design skill. The package is an unofficial single-maintainer distribution that ships executable install scripts and has an outlier star count — installing it would add supply-chain risk for a capability we already hold. Its *method* is captured in `website-design` |

### Antigravity vs. Gemini CLI — different products, different project config

Both are Google/Gemini tooling and share the user-global `~/.gemini/`
directory on a machine, which invites the assumption that they also share
this repo's `.gemini/`. They don't, at the project level (verified against
Google's own docs, 2026-07-28):

| Product | Project-level MCP config | Project-level rules | Project context |
| --- | --- | --- | --- |
| Gemini CLI | `.gemini/settings.json` | none (root `GEMINI.md` doubles as the entry point) | `GEMINI.md` |
| Antigravity (IDE + `agy` CLI) | [`.agents/mcp_config.json`](https://github.com/kevinle3212/sensebridge/blob/main/.agents/mcp_config.json) | [`.agents/rules/precedence.md`](https://github.com/kevinle3212/sensebridge/blob/main/.agents/rules/precedence.md) | root `AGENTS.md` / `GEMINI.md` (Antigravity reads both) |

Antigravity resolves its workspace MCP servers from `.agents/mcp_config.json`
and its workspace rules from `.agents/rules/*.md` — never from `.gemini/`,
which Antigravity does not read at the project level. Putting Antigravity
config there would be silently inert. `.gemini/settings.json` stays
Gemini-CLI-only; both wire the same Serena MCP server, just under different
files (`--context=agent` for Gemini CLI, `--context=antigravity` for
Antigravity — Serena ships a dedicated `antigravity` context). `.agents/`
already hosts the skills mirror, review-agent personas, and the impeccable
design context above; the MCP config and rules file are a fourth, unrelated
use of the same directory — Antigravity's own convention, not something this
repo invented.

**`.gemini/` audited against `.codex`/`.cursor` for hook parity (2026-07-28),
no gap found to fill.** Gemini CLI does support project-level hooks
(`hooks` key in `settings.json`, distinct event names from Claude Code's —
`BeforeTool`/`AfterTool` rather than `PreToolUse`/`PostToolUse`), so on paper
it could carry the same Serena-reminder and impeccable design-QA automation
`.codex/hooks.json` and `.cursor/hooks.json` wire. Both are blocked by the
supporting tools' own scope, not by choice: `serena-hooks --client` only
accepts `claude-code|vscode|codex` (no `gemini`/`antigravity` value exists to
pass), and `.gemini/skills/impeccable/` has no `scripts/hook.mjs` — unlike
`.agents/skills/impeccable/`, `npx impeccable install` never wired a hook
script for the Gemini CLI target, and hand-adding one would fight the vendor
tool exactly as the Impeccable design-QA row above warns against. Revisit
once either tool adds Gemini CLI support upstream.

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
