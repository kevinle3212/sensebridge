---
title: Tooling — Global vs. Project Decision Matrix
---

# Tooling — Global vs. Project Decision Matrix

Every development/AI tool SenseBridge uses, where it lives, and how to run it.
The standing rule: **global by default; project-level only when the repo needs
a pinned, portable, or shareable config.** Fewer, higher-quality tools beat
more tools.

**This file is current state.** The decision history behind every row — why a
tool was chosen or refused, what broke, what superseded what — lives in
[`docs/archive/TOOLING-DECISIONS.md`](archive/TOOLING-DECISIONS.md), split out
2026-08-01 when this file had reached 92 KB (~23k tokens to read) and had
become session-by-session archaeology rather than a reference. Look a tool up
by name there before changing anything about it; the reasoning is usually
load-bearing.

SenseBridge is a Swift/SwiftUI iOS app with **no Node or Python stack in the
app itself** — that fact still decides most rows below. The repo also has a
small, deliberately separate Node/web stack under `website/` (the marketing
site). It changes nothing about the app: no Node, Python, backend, container,
or orchestration platform touches `app/`.

## Project-level (in this repository)

| Tool / config | Where | What it does |
| --- | --- | --- |
| Git hooks | `.githooks/` (`pre-commit`, `commit-msg`, `pre-push`, `post-commit`, `post-checkout`, `post-merge`) | Shareable quality gate, enabled by `scripts/setup.sh` via `core.hooksPath`. `commit-msg` prefers commitlint and falls back to a dependency-free bash regex; `pre-commit` runs the secret/sensitive/settings/BMAD checks, markdownlint, and staged-workflow actionlint; `pre-push` mirrors the CI build gate, blocks direct pushes to `main`, and runs `osv-scanner` when installed; `post-merge` flags changed manifests and refreshes `website/tsconfig.debug.json` only on `main` |
| Commitlint | Root `package.json` (devDependencies only), `commitlint.config.js` | Conventional-commit format, enforced locally by `.githooks/commit-msg` and blocking in CI (`.github/workflows/commitlint.yml`) over every commit in a PR range plus the PR title. Rules mirror the bash-regex fallback: same 11 types, 72-char subject cap |
| Command center | Root `package.json` `scripts`, `website/package.json` `scripts`; see [`docs/ENVIRONMENT.md`](ENVIRONMENT.md#command-center) | Every routine command is an `npm run` script, so bare `npm run` is the discoverable index of what the repo can do. The scripts are thin wrappers around `scripts/*.sh`, `tools/*.mjs`, and `xcodebuild` — never reimplementations |
| Actionlint | `.githooks/pre-commit` (advisory), `.github/workflows/actionlint.yml` (blocking) | Lints `.github/workflows/*.yml` and shellchecks `run:` blocks. CI downloads a pinned release binary and verifies its SHA256 — see the workflow header for the version-bump procedure |
| Markdownlint | `.markdownlint.jsonc`, `.markdownlint-cli2.jsonc`, `.githooks/pre-commit` (advisory), `ci.yml`'s `docs-links` job (blocking) | Whole-repo Markdown lint. `MD033` allowlists `img`/`details`/`summary`. `markdownlint-cli2` is a pinned root devDependency (`npm run lint:md`, installed by `npm ci`/`scripts/setup.sh`), covering the whole repo, not just `website/` |
| Root `.mjs` lint + format | `eslint.config.mjs`, `prettier.config.mjs`, `npm run lint:mjs` / `format:mjs` (`--fix`/`:fix` variants available), `ci.yml`'s `repo-gates` job (blocking) | ESLint flat config paired with a Prettier config, both pinned root devDependencies (`npm ci`/`scripts/setup.sh`), like markdownlint above. Scoped to `.claude/hooks/*.mjs`, `.cursor/hooks/*.mjs`, and `tools/*.mjs` — the hand-authored `.mjs` tooling. ESLint enforces double-quote strings (`avoidEscape: true`, so a string containing a literal `"` may still use single quotes); Prettier formats the same files (also double-quote by default, 2-space, no tabs — see `.editorconfig`). Every `.mjs` under a `skills/` directory is out of scope: `impeccable`'s are vendor-managed by `npx impeccable install/update`, so a hand-fixed style there is overwritten on the next run; every other skill lives once under `.agents/skills/` with harness dirs symlinked back, so there's no regeneration step to fight. `website/*.mjs` is out of scope too — already covered by `website/eslint.config.mjs` + its own Prettier config (`singleQuote: false`) |
| Claude Code hooks | `.claude/hooks/` (14 shell scripts + `react-doctor.mjs`, `prefer-rtk-shape.mjs`, `guard-mcp-sensitive-paths.mjs`, `guard-bash-secret-read.mjs`), wired in `.claude/settings.json`; the four user-global guards in `.claude/hooks/global/` | Session-level guardrails the git hooks cannot see: read-token discipline, subagent cap, git safety, the MCP and Bash path guards, and RTK shape rewriting. Mechanism, measurements, and the bug history behind each: [Claude Code hooks in detail](#claude-code-hooks-in-detail) |
| Secret scanning (three layers) | `.gitleaks.toml`, `.gitguardian.yaml`, `tools/check-sensitive-files.mjs`, `.gitleaksignore` | Local pattern scan (gitleaks) + hosted detector set (ggshield, advisory if not installed) + a stdlib-only Node path/content check that always runs, so a missing binary can't silently disable the layer. CI adds TruffleHog (verified-credential scan). `.gitleaksignore` holds fingerprint allowlists for verified false positives |
| Settings-hook check | `tools/check-settings-hooks.mjs`; `.githooks/pre-commit`, `npm run check:hooks` | Guards the tracked `.claude/settings.json` hook table against owner-personal hooks leaking into the repo and against double registration. Duplicate key is `(event, matcher, if, command)` — identical commands under *different* guards are deliberate |
| BMAD config check | `tools/check-bmad-config.mjs`; `.githooks/pre-commit`, `npm run check:bmad` | Asserts `user_skill_level` reads `expert` in **both** `_bmad/bmm/config.yaml` and `_bmad/custom/config.user.toml`, since the installer regenerates the YAML |
| Language-stats check | `.gitattributes`, `tools/check-linguist-vendored.mjs`; `npm run check:linguist` | Harness parity checks the vendor-managed `impeccable` tree in five times (`.agents`, `.claude`, `.github`, `.gemini`, `.cursor`) — 530 files, ~13.5 MB of `.mjs` against ~390 KB of Swift — so without a `linguist-vendored` glob GitHub reports this as a JavaScript repo. One `**/skills/impeccable/**` line covers every current and future harness copy; listing the roots individually is how three of the five were once missed. The gate asserts **both** directions: no vendored file counted, and no first-party file (`tools/`, `.claude/hooks/`, `website/`, root configs) excluded by an over-broad glob |
| DeepSeek bridge check | `tools/check-deepseek-bridge.mjs`, suite at `tools/tests/check-deepseek-bridge.test.mjs`; `npm run check:deepseek-bridge` | Asserts `.deepseek/cordis.yml` really wires `@deepseek-ai/dsh-hooks-claude-code` at `.claude/settings.json`, and guards against hook-surface drift in **both** directions: a new event the bridge cannot carry (guards silently stop running under `dsh`), or a recorded gap that overstates reality. Replaces a hand-run "boot `dsh` and see whether a guard denies it" probe — the guard-reuse path is invisible, so nothing else fails loudly when it breaks. Layer three resolves the overlay through the real binary (`dsh --dump-config`) with no network, API key, or agent boot, and is **skipped with an explicit note** while `dsh` is absent rather than passing quietly. The suite pins `DSH_BIN` in every case — without it, installing the harness would flip three assertions and turn `npm run check` red on the documented happy path; pinning also buys stub coverage of all three layer-3 branches (resolves, fails, plugin missing) with nothing installed. `DSH_BIN` is a test seam only — leave it unset in normal use. **The `dsh --dump-config` contract is read from package docs and unverified against a real install**, so layer 3's failure message names that possibility alongside a genuinely broken overlay; check `dsh --help` before "fixing" config on the strength of it |
| npm-script file check | `tools/check-npm-script-files.mjs`, suite at `tools/tests/check-npm-script-files.test.mjs`; `npm run check:npm-script-files` | Asserts every literal script path an npm script invokes under `tools/`, `scripts/`, `.claude/`, or `.githooks/` both **exists** and is **tracked by git**. Existence alone is not the interesting question: a file sitting untracked in the working tree passes an existence check and still gives every fresh checkout a `npm run check` that dies on `Cannot find module`. That is exactly how it was found — a `check:*` entry landed in tracked `package.json` pointing at an untracked `tools/*.mjs`. Globs are checked too, for a sharper reason: a pattern matching files locally while matching nothing **tracked** expands to nothing on a clone, so the loop body never runs and the script exits 0 — a green line proving nothing ran, which is strictly worse than the loud `Cannot find module` above. A glob matching zero files anywhere still passes, since it names a set and an empty one is legitimate. Outside a git work tree it degrades to existence-only **with an explicit note** rather than passing quietly. The suite pins `GIT_BIN` at stubs so tracked / untracked / git-unavailable are deterministic without building fixture repositories; one case leaves it unset to keep the real `git ls-files` call exercised, and asserts only that tracking was consulted, never which files came back — that set changes on the next commit. `GIT_BIN` is a test seam only |
| SwiftLint / SwiftFormat | `scripts/lint.sh` (configs land with `app/`) | Binaries are global (Homebrew); the invocations and configs are repo-specific |
| Serena MCP | `.mcp.json`, `.serena/project.yml` (`languages:`), `.claude/settings.json` (`enabledMcpjsonServers`), `.serena/memories/` | Per-project semantic indexing — local process, no network, project-scoped. **Only add a language to `languages:` when it has a real `referencesProvider`/symbol graph** — yaml-language-server, for example, has none (`find_referencing_symbols` cannot work on it regardless of cache spent), and its document-symbol tree runs ~4.5x source bytes; `Grep`/`rg`/`search_for_pattern` answer config-shaped languages (yaml, json, toml, markdown) faster than an LSP round-trip. See `.serena/project.yml`'s own comments for the measured cost of getting this wrong (2026-08-01 prune, re-evaluated 2026-08-03). **Enabled from tracked settings, not `settings.local.json`**, so the server starts on session open for every clone rather than only on the machine that first approved it. `.serena/memories/` is **versioned on purpose** — those six files are curated project knowledge (doctrine, tech stack, conventions, task-completion checklist), so a fresh clone gets a Serena that already knows the project; `cache/`, `logs/`, and `project.local.yml` are per-machine and gitignored. Health check: `serena project health-check` (last green 2026-08-01, LSP up in 0.65s) |
| CI/CD | `.github/workflows/` | CI, security scanning (CodeQL, TruffleHog, GitGuardian, OSV, Semgrep, Dependency Review, sensitive files), Claude PR review, Dependabot auto-merge |
| Agent instructions | `AGENTS.md` + thin pointers (`CLAUDE.md`, `GEMINI.md`, `.cursor/rules/`, `.github/copilot-instructions.md`) | One canonical instruction file, agent-agnostic; the pointers prevent lock-in and duplication |
| Per-agent configs | `.codex/`, `.gemini/settings.json`, `.copilot/`, `.continue/rules/`, `.windsurf/`, `.cursor/`, `.kimi-code/` | Each wires Serena MCP and defers to root `AGENTS.md` — configuration without instruction duplication. **`.kimi-code/` is notes only, by necessity**: Kimi Code 0.32.0 has no project-scoped config or permission file (a repo's `.kimi-code/local.toml` accepts only `[workspace] additional_dir`), so its approval policy lives entirely in the user-level `~/.kimi-code/config.toml` and a fresh clone inherits **none** of it. It needs no Serena wiring — Kimi reads this repo's `.mcp.json` directly, and auto-discovers `.agents/skills/`, `.claude/skills/`, `.codex/skills/`, and `.agents/agents/` (all three skill dirs merge only because `merge_all_available_skills = true` is set user-side; without it Kimi loads the first and silently ignores the rest). Verify a machine with `kimi doctor`, which validates `config.toml`/`tui.toml` against the real schema — it does **not** read `mcp.json`, and it cannot tell you that a permission glob matches nothing |
| Continue config template | `.continue/config.template.yaml`, `.continue/README.md` | Example only, never active config (Continue reads user-global `~/.continue/config.yaml`) |
| Skills / reviewer personas | `.agents/skills/` (canonical, 61 skills), `.agents/agents/` (9 review personas) | Project-doctrine-specific: safety framing, accessibility, model licensing, plus the `council` decision-review skill and the `website-design` route. One tree, not five — harness dirs (`.claude/`, `.cursor/`, `.gemini/`, `.github/`) hold either a symlink back per skill or a thin router adapter; `impeccable` is the one vendor-managed skill excluded from the lock below |
| Skill-lock | `.agents/manifest.json`, `.agents/skill-lock.json`, `tools/skill-lock.mjs`; `.githooks/pre-commit` and `npm run check:skills` (both `--check` via the tool's default no-flag mode) | Hash-locks the canonical skill tree, the 9 persona files, and every harness adapter, so a canonical edit without a re-sync (`node tools/skill-lock.mjs --write`) shows up as drift instead of silently diverging. Replaces the earlier mirror-and-regenerate model (`tools/sync-skills.mjs`, retired 2026-08-07) |
| Review companions | `REVIEW.md` (root), `.agents/skills/security-review/SKILL.md` (`.claude/commands/security-review.md` is a stub pointing here) | Extend the built-in `/code-review` and `/security-review` with project severity overrides, skip paths, and on-device/privacy/model-license checks — additive, not replacements |
| Audit system | `audits/` | Append-only. Process docs are tracked; findings are gitignored. Create reports via `audits/scripts/new-audit.sh`; read `audits/AGENT-GUIDE.md` first |
| Marketing website | `website/` (Astro, `package.json`, `.stylelintrc.json`, `.prettierrc`, `eslint.config.mjs`) | The one deliberate exception to "no web stack" — copy still follows `docs/SAFETY-FRAMING.md`. Node tooling is scoped to this directory |
| React Doctor, React Scan | `website/package.json` — React Doctor in `devDependencies`, React Scan in **`dependencies`** | `npm run audit:react` / `npm run doctor`, both `--no-telemetry` (load-bearing for the no-telemetry posture). CI gate is `blocking: warning`, held at zero findings; suppressions live in `website/doctor.config.jsonc`. Call it via `env -u GIT_DIR` from any hook. React Scan is a dev-only inline import in `BaseLayout.astro`; **there is no `npm run scan`** |
| Website hosting (Railway) | `docker/` (`Dockerfile`, `nginx.conf.template`, `docker-compose.yml`), `railway.toml` | Deploys the static site only — no env vars, no backend, no effect on the app's serverless/on-device posture. The Railway service's Root Directory must stay the **repo root**, since the build context spans `docker/` and `website/` |
| Impeccable design-QA | Skill in the 5 harness dirs; design context in `.agents/context/`; state in `.impeccable/` — **all rooted at the repo root, never `website/`** | Frontend design-anti-pattern detector. See the two subsections below; both are live rules, not history |
| Handoff auto-load | `SessionStart` hook in `~/.claude/settings.json` (owner-personal, deliberately **not** in the tracked settings) | Surfaces `tmp/handoff.md` on `/clear` or a fresh session. `tmp/` is gitignored; `tools/check-settings-hooks.mjs` blocks this hook from entering the tracked config |
| Notes (public / private split) | `NOTES.md` tracked; `NOTES.local.md` gitignored | `NOTES.md` is a public, linted digest of durable contributor-facing findings, each pointing at the doc that owns the detail. `NOTES.local.md` is the private trail — absolute paths and machine state stay there |
| Workflow commands | `.claude/commands/` (`cleanup-notes`, `session-log`, `todo-groom`, `cleanup-commit`, `security-review`) | Project-scoped commands only. Owner-personal commands (`/handoff`, `/claude-cli`, `/docker-clean`) are owned by `~/.claude/commands/`; project copies mirror them verbatim rather than diverging |
| CodeRabbit | `.coderabbit.yaml`, path-scoped to `website/**` | Second reviewer for the one part of the repo the doctrine-tuned Claude review prompt wasn't written for (general web/CSS quality) |
| ~~GitNexus~~ | **Removed 2026-08-24** | Retired as a code-graph tool. The npm package is uninstalled, the two global `PreToolUse`/`PostToolUse` hooks are gone, and the six `.agents/skills/gitnexus/*` skills are deleted. Residual `.gitnexus/**` entries in `.vscode/settings.json`, `.gitattributes`, and `.claude/settings.json` are inert excludes for a directory that no longer exists |
| Editor config | `.vscode/extensions.json`, `.vscode/settings.json` | Recommended extensions + strict per-language formatting; excludes generated dirs (`.codegraph/`, `graphify-out/`, `tmp/`, `logs/`) from search |
| Agent/CI scratch space | `tmp/`, `logs/` | Gitignored scratch dirs (`.gitkeep` + README tracked) so agents stop reaching for shared `/tmp` or littering the repo root |
| Line-ending/merge hygiene | `.gitattributes` | LF normalization; `linguist-generated` on `.codegraph/`, `.gitnexus/`, lockfiles |
| Static analysis (generic) | `.github/workflows/security.yml` → `semgrep` job | `p/security-audit`, `p/secrets`, `p/owasp-top-ten`, `p/swift` — scans scripts, workflows, `website/`, and Swift |
| Monthly log archive | `.agents/skills/monthly-log-archive/SKILL.md`, `tools/condense-sessions.mjs` | Stdlib-only Node script condensing last month's gitignored `sessions/<YYYY-MM-DD>/*.md` into one `sessions/<YYYY-MM>/SESSIONS.md` |
| Completed-TODO archive | `tools/sweep-done-todo.mjs` (`npm run todo:sweep`); `tools/archive-completed-todo.mjs` is a defensive backstop only | Sweep cuts ticked bullets out of To-Do and writes them straight into `COMPLETED.todo`'s day-grouped blocks — TODO.md never carries a `## Completed` section. The archive script's `main()` now only fires if something is ever hand-pasted under that heading; a machine-global launchd plist still runs it every 3 days as a no-op safety net |

## Claude Code hooks in detail

Each subsection below is self-contained: an agent looking for one of these
answers can stop reading after it.

### Read-token discipline

`cap-large-read.sh`, `warn-duplicate-read.sh`, and `prefer-serena.sh` shape what
a read costs. Measured effect of the read pair (2026-08-01): mean cost per
`Read` fell 911 → 826 tokens, about 9%, and reads over 8k stayed flat at ~1.2%.
Modest because most reads were already small — keep them, but do not expect them
to be the lever.

`cap-large-read.sh` treats `TODO.md` and `COMPLETED.todo` as **queue files**: a
`Read` with no offset *and* no limit is clamped to 120 lines and pointed at
`Grep` for the `###` section heading, because `TODO.md` was the most expensive
file in the whole transcript corpus (264k tokens over 182 reads) and nobody ever
needs it sequentially. An explicit offset or limit falls through to the ordinary
500-line rule.

`limit-agent-fanout.sh` caps subagent fanout, and `prefer-rtk-shape.mjs`
auto-rewrites the command shapes RTK's own hook skips — pipes, redirects, loops,
substitutions, subshells, `eval`.

### Permission-rule path globs do not reach MCP tool arguments

`Read(**/*.pem)` and `Edit(legal/**)` scope by path for *built-in* tools only,
because MCP rules match on tool **name** alone. Confirmed by probe on
2026-08-01, not inferred: with the built-in `Read` of a scratch `.pem` denied,
`mcp__filesystem__read_text_file` returned that same file's contents and
`mcp__filesystem__write_file` wrote to it.

`guard-serena-legal.sh` had already patched one case (`legal/`, Serena's six
mutating tools); `guard-mcp-sensitive-paths.mjs` closes the rest, denying the
whole `mcp__filesystem__*` family plus Serena's mutators on credential material
and `legal/`. It imports its taxonomy from `tools/check-sensitive-files.mjs`
rather than restating it, so the run-time guard and the commit-time gate cannot
drift apart, and it is the one hook here that **fails closed** — an unparseable
payload means the path is unknown, which is exactly what malformed input
produces.

The same bypass shape existed on the *token*-discipline side:
`cap-large-read.sh` and `warn-duplicate-read.sh` only recognized `file_path`
(native `Read`'s field), so `mcp__serena__read_file` (`relative_path`) and
`mcp__filesystem__read_text_file` (`path`) skipped both the size cap and the
duplicate-read nudge entirely. Fixed 2026-08-03: both now check
`file_path // path // relative_path`, wired to those two MCP tools via their own
`PreToolUse` matcher group — kept separate from `prefer-serena.sh`, which would
otherwise misfire advising "use Serena" on a call that already is one. The
`limit`-field rewrite stays `Read`-only: Serena's `read_file`
(`start_line`/`end_line`) and the filesystem MCP's `read_text_file` (no
pagination field) have nothing this hook can safely rewrite, so those two get an
advisory `additionalContext` with no attempted clamp.

### Bash arguments are not path-scoped either

`guard-bash-secret-read.mjs` mirrors the same rules for the shell — same
imported taxonomy, third enforcement point. It is **best-effort and bypassable
by design, and must never be cited as a boundary**: Bash is a general-purpose
interpreter, so `python3 -c 'open(".env").read()'`, a here-doc, a base64 round
trip, or a path assembled from variables all sail past. Demonstrated, not
assumed (2026-08-01).

What it buys is the *accident*: `cat .env` on autopilot, a `grep -r` wandering
into a key file, a `cp` of signing material to a scratch dir. It peels
`rtk`/`sudo`/`env` wrappers (a guard blind to the `rtk` prefix would be blind on
this repo's normal path) and judges each `&&`, `;`, and pipe segment
independently, so a readme read chained to a discard of a stale key stays
allowed. Unlike its MCP sibling it **fails open** — it sits on the Bash path, so
failing closed on a parse error would take the session down to defend a boundary
it already admits it cannot hold. Validated against 20 real commands replayed
from the session that built it: zero false positives.

`guard-main-commit.sh` and `guard-destructive-git.sh` are each registered
**three** times — for `Bash(git *)`, `Bash(rtk git *)`, and
`Bash(rtk proxy git *)` — so neither RTK's transparent rewrite nor its
byte-exact passthrough can slip a destructive command past a guard. The `if`
conditions mean at most one variant spawns per command.

### A guard that fires on prose is a defect, not caution

`guard-main-commit.sh` used to deny any command whose *text* contained
`git commit`, blocking test fixtures and docs that merely quoted it — which
teaches agents to route around the guard. Quoted string literals are now blanked
before classification, with commands that execute a string (`eval`, `sh -c`)
opting out so their contents stay visible.

`guard-protected-delete.sh` had the same defect and got the same treatment on
2026-08-01, after it denied two commands whose here-doc **data** merely
mentioned a discard verb near a protected path: its `sed 's/<<.*//'` ran line by
line, so it truncated the `cat <<EOF` line and left the body it was meant to
cut. The blanking could not simply be copied, though — this guard matches on an
*argument*, and arguments are routinely quoted, so blanking quoted text
wholesale would have let `rm -rf "sessions/x"` through. It instead walks the
command once, quote-aware, keeping two views per segment: quoted runs collapsed
for **verb** detection, quote characters dropped but contents kept for **path**
detection. Splitting is quote-aware for the same reason, so a `;` inside a
string does not start a new command.

### Self-checks and registration gates

Self-checks live in `.claude/hooks/tests/` (12 suites) and
`.claude/hooks/global/tests/` (4 suites), both run by
`npm run check:hook-tests`. The runner globs `*.test.sh` and `*.test.mjs`, so a
new suite is picked up without wiring.

`npm run check:hooks` verifies every registered hook **script still exists and
is executable** — a renamed or deleted hook otherwise fails silently, since
Claude Code logs the spawn error and carries on, leaving the config claiming a
guarantee that is gone. It also cross-checks `.mcp.json` against the
`guard-mcp-sensitive-paths.mjs` matcher: every project-scoped MCP server
inherits the name-only-matching bypass, and the guard itself needs no change
when one is added — only its **matcher** does, which nothing else would notice.
Adding a server now fails the gate until it is either covered by the matcher or
recorded in `MCP_SERVERS_WITHOUT_PATH_ARGS` with the reason it takes no
filesystem path.

That gate sees *project-scoped* servers only. User-scope servers
(`claude mcp add -s user`, e.g. `filesystem`) live in the owner's global config,
which a tracked repo gate cannot read. The user-global
`~/.claude/hooks/away-guard.sh` carries the same fix and its own suite at
`~/.claude/hooks/tests/away-guard.test.sh` — deliberately **not** run by this
repo's CI, since gating a repo on a user-global file would break every other
clone.

## Global (installed on this machine, nothing to add to the repo)

| Tool | Status | Use here |
| --- | --- | --- |
| Xcode / Swift toolchain | required | The build |
| SwiftLint, SwiftFormat, xcbeautify | installed (Homebrew) | Invoked by `scripts/lint.sh` |
| gitleaks | installed | Pre-commit secret scan |
| ggshield | **not installed** — advisory (`brew install ggshield`, then `ggshield auth login`) | Pre-commit GitGuardian scan; CI runs regardless via the `ggshield` job, gated on the `GITGUARDIAN_API_KEY` repo secret |
| semgrep | installed | Ad-hoc local runs; CI coverage lives in `security.yml` |
| osv-scanner | installed (Homebrew) | Pre-push dependency vulnerability scan, mirroring `security.yml`'s `osv-scan` job |
| actionlint | installed (Homebrew) | Pre-commit lint of staged workflows; CI runs a pinned, checksum-verified copy |
| gh | installed | GitHub workflows. **Agents never run `git`/`gh` autonomously** — see `CLAUDE.md` |
| Serena | installed (`uv` tool) | Semantic code navigation via `.mcp.json`. **First tier for any code file** per `CLAUDE.md` |
| CodeGraph | installed (`@colbymchenry/codegraph@1.5.0`, `/opt/homebrew/bin/codegraph`) | Free-text architecture questions (`codegraph explore`), symbol source plus caller/callee trail (`codegraph node`). Index at `.codegraph/`, gitignored; refreshed incrementally by the versioned `post-commit`/`post-checkout` hooks |
| Graphify | installed (`~/.local/bin/graphify`) | Knowledge-graph queries; `graphify-out/` is gitignored. Backs the global `graphify` skill. **Overlaps CodeGraph** — `docs/archive/TOOLING-DECISIONS.md` records a 2026-08-18 decision to retire Graphify that was never carried out; both are installed as of 2026-08-24 and the redundancy is still open |
| ~~GitNexus~~ | **uninstalled 2026-08-24** | Was `npm install -g gitnexus`. Removed along with its global hooks |
| RTK (`rtk`) | installed (`/opt/homebrew/bin/rtk`), global `PreToolUse`/`Bash` hook active | Transparently rewrites covered Bash calls to their output-compacted `rtk` equivalent before they run. **The rewrite matches on command shape and the coverage is partial**: bare commands and `&&`, `;`, `&`, and or-else chains are rewritten; pipes, redirects, substitutions, subshells, and loop bodies are not — `.claude/hooks/prefer-rtk-shape.mjs` fills exactly that gap. **A newline is the shape that mattered most, and it is easy to get wrong**: RTK rewrites only the *first line* of a multi-line command (`ls -la\ngrep foo src` → `rtk ls -la` with `grep` untouched) and rewrites nothing at all when line one is a command outside its set — which is exactly the `cd <abs path>` that opened **1,298 of this repo's 1,810 `cd`-prefixed calls (72%)**. Those reached neither hook until `\n` was added as a leaking shape on 2026-08-01. Note what is *not* a problem: `&&` and `;` are fine, and prefixing a command with `cd` does not block coverage. **Write commands as bare calls anyway** — the Bash working directory already persists between calls and starts at the repo root, so `cd /Users/.../sensebridge` at the head of a command is pure noise on every call that carries it. **How partial, measured** (6,672 project Bash calls, 2026-08-01, `measure-context-growth.py --bash-shapes`): **9.8%** are a plain shape RTK's own hook rewrites, 2.8% were already written as `rtk`, **35.3%** are RTK-coverable but shape-broken (the `prefer-rtk-shape.mjs` gap — `grep` 625 calls, `git` 308, `gh` 207, `ls` 330, `cat` 231), and **52.0%** name a command outside RTK's set (`cd`, `echo`, `npx`, `node`, `python3`, `xcodebuild`, `curl`, `docker`). Those buckets count the *first word*, so they understate real coverage: after the newline fix, a multi-line block opening with `cd` or `echo` still gets every covered command inside it rewritten. Treat RTK as a partial tool, not a general answer to Bash output volume. **Compaction is lossy and the savings are smaller than the marketing**: measured 2026-08-01 at ~10% output reduction on a realistic 12-command mix (`ls`/`find`/`wc` compact 55–76%, large `rg` ~41%, `git log`/`git show`/file reads compact **0%**), against a `rtk gain` headline of 78% that came almost entirely from one outlier. It has silently corrupted a `.patch` file. Use `rtk proxy <cmd>` whenever output must stay byte-exact. **Division of labor with Serena**: RTK compacts *shell* output; Serena replaces *code-file* Read/Grep/Edit |
| Context measurement | `~/.claude/scripts/measure-context-baseline.py` (session-start floor), `measure-context-growth.py` (mid-session growth) | Answer "where did the tokens go" from transcript `message.usage` records rather than from config. The baseline script measures the fixed floor; the growth script attributes the climb from that floor using **real per-request deltas**, not character estimates — `--bash-shapes` adds the RTK-coverage breakdown quoted in the RTK row. Rerun both before acting on any token-optimization theory; the 2026-08-01 pass found a character-based estimate off by 40× on one tool |
| gstack | installed (`~/.claude/skills/gstack`) | Web browsing (`/browse`) + review/ship skill suite. The global standard for all agent browsing |
| Gemini CLI | installed (`@google/gemini-cli`, `/opt/homebrew/bin/gemini`) | Uses this repo's `.gemini/settings.json` + `GEMINI.md` |
| Antigravity | installed (IDE + CLI, Homebrew casks) | Reads this repo's `.agents/rules/*.md` for policy and skill routing. Its MCP configuration is **user-global** (`~/.gemini/config/mcp_config.json`, shared across Antigravity 2.0, IDE, and CLI) — this repo ships no project-level Antigravity MCP file; `.agents/mcp_config.json` was deleted 2026-08-07 as dead config nothing read |
| DeepSeek Harness (`dsh`) | **not installed** — repo adapter ready, harness absent (`npm install -g @deepseek-ai/dsh@<pinned>`) | Plugin-based agent harness from DeepSeek AI (`@deepseek-ai/dsh`, MIT). Reads this repo's [`.deepseek/cordis.yml`](../.deepseek/cordis.yml) as a `--patch` overlay: `dsh --profile tui --patch ./.deepseek/cordis.yml`. **Guard reuse is first-party** — `@deepseek-ai/dsh-hooks-claude-code` (BSD-3-Clause) consumes `.claude/settings.json` directly, so unlike `.codex/hooks/dispatch.sh` there is no shim and no Stop-schema workaround. **Coverage is partial**: the bridge documents `PreToolUse`, `PostToolUse`, `UserPromptSubmit`, `Stop`; this repo also declares `SessionStart` and `PostToolBatch`, which are **not carried** — never read a green `dsh` run as proof the repo gates passed. That gap is machine-asserted by `tools/check-deepseek-bridge.mjs` (in `npm run check`, suite at `tools/tests/check-deepseek-bridge.test.mjs`), which fails in both directions — a new uncovered event, or a recorded gap that overstates reality. Its third layer resolves the overlay through the real binary (`dsh --dump-config`, offline) and is skipped with an explicit note until `dsh` is installed. Two blockers, both owner actions: the package is not installed, and **no `DEEPSEEK_API_KEY` exists on this machine** (every occurrence found in the 2026-08-17 `.env` audit was blank). Both packages are pre-1.0 release candidates that moved versions mid-session (`dsh` rc.5 → rc.7), so pin exact versions |
| Composio | installed (binary at `~/.composio/composio`, **not on `$PATH`**) | Authenticated CLI reaching 1000+ third-party APIs. **A CLI, not an MCP server** — nothing to add to the MCP inventory. Gap-filler only; `gh` and the repo's own scripts win where they apply |
| Ollama | installed | Local LLM experiments only — **not** an app dependency. On-device inference uses Core ML/ANE, never a local server |
| Node, bun, uv, python3 | installed | Script runtimes only; no project package manifests for the app |
| Obsidian vault (`~/Vault`) | present | Cross-project knowledge via the `vault-capture` skill |
| WakaTime | installed (key in `~/.wakatime.cfg`) | Automatic coding-time tracking; posts heartbeats to the WakaTime dashboard. One key, many clients |

## Claude skills and plugins

Installed globally (user scope) from source-verified marketplaces, plus the
project-scoped skills under `.agents/skills/` and `.claude/skills/`. The full
install log — what was added when, from which marketplace, and which
candidates were evaluated and refused — is in
[the archive](archive/TOOLING-DECISIONS.md).

Two rules below are **live constraints, not history**, and are linked from
`CLAUDE.md`:

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
design context lives in
**[`.agents/context/PRODUCT.md`](https://github.com/kevinle3212/sensebridge/blob/main/.agents/context/PRODUCT.md)
and
[`.agents/context/DESIGN.md`](https://github.com/kevinle3212/sensebridge/blob/main/.agents/context/DESIGN.md)**
— the one location that resolves deterministically without misrepresenting
the repo.

**Two files named `PRODUCT.md`, deliberately, with different scopes:**

| File | Scope | Read by |
| --- | --- | --- |
| [`docs/PRODUCT.md`](PRODUCT.md) | The **iOS app** — mission, wedge, success metrics, funding. The repo's primary product. | Humans, planning docs |
| [`.agents/context/PRODUCT.md`](https://github.com/kevinle3212/sensebridge/blob/main/.agents/context/PRODUCT.md) | The **marketing site** (`website/`) — impeccable's `## Register` / `## Platform` design brief. | `impeccable` (auto), humans |

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

## Not needed (and why)

| Tool | Reason |
| --- | --- |
| SWC, Jest, Knip, Husky | `website/` is mostly static HTML/CSS — nothing for a bundler, test runner, or dead-code tool to do yet |
| Playwright | iOS UI testing is XCUITest + VoiceOver passes; no browser E2E surface on the website yet (pa11y-ci covers its accessibility gate) |
| Vercel, Docker, Kubernetes | Serverless-by-doctrine for the **app**: there is no backend to deploy, and a container platform would violate `docs/PRIVACY.md`. Docker exists in this repo only to build the static `website/` image for Railway |
| `@costline/nexus-graph` | A different package from `gitnexus` despite the shared "Nexus" name; no home here |
| Python venv | No Python code in this repo |
| Oracle tooling | No database; explicitly unjustified |
| Caveman | Its core mechanic strips hedging and qualifiers — a direct conflict with awareness-not-safety, and it installs as user-global hooks that cannot be scoped away from SenseBridge sessions. No adaptation preserves both the tool and the doctrine |

## MCP inventory

Verified against `~/.claude.json` and `.mcp.json` on **2026-08-01**. Seven
servers (`dune`, `github`, `gitnexus`, `glyph`, `granola`, `memory`,
`sequential-thinking`) were removed from the user-scope config on 2026-07-31
after 30 days with zero calls; `headroom` was removed when its routing was
disabled. `codegraph`, `graphify`, and `glyph` still work as **CLIs** from Bash;
`gitnexus` was uninstalled entirely on 2026-08-24.
Their original entries are in [the archive](archive/TOOLING-DECISIONS.md).

| Server | Scope | Permissions | Status |
| --- | --- | --- | --- |
| serena | project (`.mcp.json`, plus the per-harness configs) | Local process, project files only. Read/navigation tools and the eight non-destructive mutating tools; destructive ones denied, `guard-serena-legal.sh` mirrors `Edit(legal/**)` for them, and `guard-mcp-sensitive-paths.mjs` mirrors the credential deny rules. **Web dashboard**: enabled project-scoped via `--enable-web-dashboard=true` in `.mcp.json`, binds `127.0.0.1` only (verified 2026-08-01); `.vscode/mcp.json` mirrors both dashboard flags for VS Code's own MCP client, keeping its `--context=vscode --project-from-cwd` args (VS Code resolves the project differently than the CLI, so those two stay client-specific rather than copied verbatim). `--open-web-dashboard` flipped `true` → `false` on 2026-08-05: the harness spawns Serena for a brief tool-schema handshake on most `claude` process launches — `~/.serena/logs/` showed 20 restarts in one day, most living under 25ms — and auto-opening a browser tab on every one of those was popping tabs pointed at a dashboard that was already dead by the time they loaded. This now matches the documented global default (`web_dashboard_open_on_launch: false` in `~/.serena/serena_config.yml`, see `docs/archive/TOOLING-DECISIONS.md`), which the old flag was silently overriding; open the dashboard manually or via Serena's `open_dashboard` tool instead. Serena is spawned **once per MCP client**, not once per project, so two concurrent Claude Code sessions mean two `start-mcp-server` processes — that is stdio MCP working as designed, not a duplicate to hunt down. They do not fight over the dashboard port: it walks up from its base, observed live as 24283 and 24284 with two sessions attached. It cannot be set in `.serena/project.local.yml` — `web_dashboard*` are fields of the global `SerenaConfig`, not `ProjectConfig`, so the key is **silently ignored** there; the CLI flags are the only project-scoped route | Active — first tier for code files |
| context7 | user-global | Remote docs-lookup API (Upstash); **every query is egress** | Active, optional per developer |
| filesystem | user-global | Local process, filesystem read/write scoped to `$HOME` | **Disabled** 2026-08-03 — duplicates built-in Read/Write/Edit; see `~/.claude/REMOVED-MCP-SERVERS.md` |
| puppeteer | user-global | Local headless-browser automation | **Disabled** 2026-08-03 — lost a comparison to gstack `/browse` on features/accuracy/portability/token cost; see `~/.claude/REMOVED-MCP-SERVERS.md` |
| higgsfield | user-global | Remote hosted MCP, AI media generation (egress on use) | **Disabled** 2026-08-03 — dead at the time (HTTP 401, zero working tools); see `~/.claude/REMOVED-MCP-SERVERS.md`. Any marketing use of generated media still passes the honesty and safety-framing gates if re-enabled |
| claude-in-chrome | user-global (browser extension) | Site-gated browser automation | Available; gstack `/browse` preferred per global `CLAUDE.md` |
| perplexity | user-global only — never project-scoped | Remote search API; **every query is egress**, needs `PERPLEXITY_API_KEY` | Approved but **not installed**; opt-in per developer |

Adding an MCP server to this repo requires: local-first, least privilege,
a row in this table, and — if it could ever see user-surroundings data — a
privacy-doc update per `docs/PRIVACY.md`.

## `.claude/settings.global.json` — the shareable global config

[`CLAUDE.template.md`](../CLAUDE.template.md) publishes the engineering standard
as prose; `.claude/settings.global.json` publishes the harness settings that
enforce the mechanical half of it, and
[`.claude/hooks/global/`](../.claude/hooks/global/README.md) ships the four
guard scripts it registers. Copy both into your own user-global config:

```bash
# macOS/Linux — merge the JSON by hand if you already have one; it is not a patch.
cp .claude/hooks/global/*.sh .claude/hooks/global/*.mjs ~/.claude/hooks/
cp .claude/hooks/global/tests/* ~/.claude/hooks/tests/
chmod +x ~/.claude/hooks/*.sh
cp .claude/settings.global.json ~/.claude/settings.json
```

Install the scripts and the settings together or neither. A registration whose
script is missing fails to spawn silently — Claude Code notes it in its own log
and the transcript looks exactly like a guard that passed.

[`RTK.template.md`](../RTK.template.md) is a separate, optional companion —
copy it to `~/.claude/RTK.md` only if you install the RTK token-compaction
proxy CLAUDE.template.md's Tools section references. It has no drift check
(unlike the guards above): it is prose, not load-bearing config, so a stale
copy degrades to a documentation-freshness issue rather than a hook that
silently stops firing.

**What it contains.** Credential and build-artifact `deny` rules for `Read`,
`Grep`, and `Edit` (the §10 secrets rule, enforced rather than trusted);
read-only `allow` entries for RTK, Serena, and Docker so routine inspection
does not prompt; `deny` on the destructive Docker prunes and the Docker MCP's
config-mutating tools; `ask` on the escape hatches (`rtk run`, `rtk pipe`,
`docker run/exec`, `mcp-exec`, Serena's two destructive tools); the
`tmp/handoff.md` loader from §5; RTK's `Bash` rewrite hook; the four
project-agnostic guards described below; and `effortLevel: high`, which the
standard names as the default tier.

Rules that only *restrict* are shipped even when they name a tool you may not
have installed — a deny for an absent MCP server is an inert no-op, whereas
shipping the permissive half of a pair without its restrictive half would make
this template quietly looser than the config it came from.

**What it deliberately omits.**

- **Personal preferences** — `model`, `theme`, `tui`, `editorMode`, `verbose`,
  notification channels, `enabledPlugins`, `extraKnownMarketplaces`. These are
  taste, not standard.
- **Machine-specific hooks** — anything calling a script under `~/.claude/hooks/`
  or `~/bin/` that this repo does not ship (wake-lock management, away-mode
  guards, time tracking, graph indexing, disk-space checks). A registration
  whose script is absent fails to spawn silently, which is worse than no
  registration at all. The four guards *are* registered precisely because
  `.claude/hooks/global/` ships them; that is the whole distinction.

**The four project-agnostic guards** — `guard-attribution.sh`,
`guard-commit-shape.sh`, `guard-long-running-server.sh`, and
`require-doc-comments.mjs` — are addressed by `$HOME/.claude/hooks/…` rather
than `${CLAUDE_PROJECT_DIR}`, because a user-scoped hook has no project
directory to anchor to. They are **not** registered in this repo's own
`.claude/settings.json`: they enforce rules that hold in every repository, so
they live in one place, and a second registration here would fire each guard
twice. Rows in the map below marked **(user-global)** are the ones this covers.

**Prerequisites.** The RTK hook needs `rtk` on `PATH`; the Serena `allow`
entries need the Serena MCP server configured. Both are no-ops otherwise,
beyond a spawn error per `Bash` call if `rtk` is missing — drop that hook entry
if you do not use RTK.

`tools/check-settings-hooks.mjs` fails the build if this file stops being valid
JSON, gains an absolute home path / machine-specific helper name / private
service name / personal-preference key, registers a `$HOME` script that
`.claude/hooks/global/` does not ship, or drifts from an installed copy at
`~/.claude/hooks/`. The check exists because every one of those failures is
invisible: the JSON stays valid and the harness loads it, and the only symptom
is a setting that silently does nothing for whoever copied it.

## Rules enforced mechanically — the CLAUDE.md ↔ hook map

`CLAUDE.md` states each rule once, in one line, and points here for the
mechanism. That split only stays honest if the mapping is written down: a rule
whose hook is renamed, unregistered, or quietly deleted would otherwise revert
to nothing at all, with the short line in `CLAUDE.md` still implying it is
covered. `tools/check-settings-hooks.mjs` guards the registration side (every
hook exists, is executable, and is registered exactly once); this table is the
human-readable side.

Every hook carries its own self-check under `.claude/hooks/tests/`, and the
user-global four under `.claude/hooks/global/tests/`. `npm run check:hook-tests`
runs both sets. Run the lot before touching any of them.

Rows marked **(user-global)** enforce project-agnostic rules from the global
`CLAUDE.md` rather than SenseBridge rules, so they run from
`~/.claude/hooks/`, registered once in the owner's `~/.claude/settings.json` —
registering them here as well would fire each guard twice per command. The
canonical scripts are tracked at [`.claude/hooks/global/`](../.claude/hooks/global/README.md)
and `~/.claude/hooks/` holds installed copies; `npm run check:hooks` fails on
drift between the two, so the reviewed copy is always the running one. A clone
that has not run the install step from that README does **not** inherit these
guards — checking out the repo is not sufficient.

| Rule | Mechanism | Event |
| --- | --- | --- |
| Serena's symbol tools before `Read`/`Grep`/`Edit` on code | `prefer-serena.sh` | PreToolUse `Read`/`Edit`/`Grep`/`Glob` |
| RTK wraps covered shell commands, including shapes RTK's own hook skips | `prefer-rtk-shape.mjs` | PreToolUse `Bash` |
| Serena and RTK are actually wired this session | `announce-tooling.sh` | SessionStart |
| Never commit to `main` | `guard-main-commit.sh` | PreToolUse `Bash` |
| Conventional commit headers; conventional branch prefixes | `guard-commit-shape.sh` **(user-global)** | PreToolUse `Bash` |
| No assistant attribution in history (`Co-Authored-By`, "Generated with…") | `guard-attribution.sh` **(user-global)** | PreToolUse `Bash` |
| No destructive or history-rewriting git without an explicit opt-in | `guard-destructive-git.sh` | PreToolUse `Bash` |
| No deletion of protected paths | `guard-protected-delete.sh` | PreToolUse `Bash` |
| No reading credential material | `guard-bash-secret-read.mjs`, `guard-mcp-sensitive-paths.mjs`, `permissions.deny` | PreToolUse `Bash`/MCP |
| `legal/` is owner-approval-only | `permissions.deny` `Edit(legal/**)`, `guard-serena-legal.sh`, `guard-mcp-sensitive-paths.mjs` | PreToolUse |
| No long-running local server unless asked | `guard-long-running-server.sh` **(user-global)** | PreToolUse `Bash` |
| Every new declaration carries a doc comment | `require-doc-comments.mjs` **(user-global)** | PostToolUse `Edit`/`Write` |
| `app/` changes reach the device before the turn reports done | `require-device-install.sh` + the stamp in `scripts/app.sh install` | PostToolUse `Edit`/`Write`, Stop |
| React Doctor zero findings on `website/` | `react-doctor.mjs`, `.githooks/pre-push`, `.github/workflows/react-doctor.yml` — all three scoped to `website/`, so a hook pass and a CI pass mean the same thing | PostToolBatch, pre-push, CI |
| Markdown links stay live | `check-md-links.sh` | PostToolUse `Edit`/`Write` |
| Accessibility and design checks on UI edits | `.claude/skills/impeccable/scripts/hook.mjs` | PostToolUse `Edit`/`Write` |
| Session log written per hour bucket | `session-log-reminder.sh` | Stop |
| `tmp/handoff.md` retired when the work ships | `handoff-clear-reminder.sh` | Stop |
| Oversized and repeated reads are capped | `cap-large-read.sh`, `cap-rtk-read.sh`, `warn-duplicate-read.sh` | PreToolUse `Read` |
| Subagent fan-out is bounded | `limit-agent-fanout.sh` | PreToolUse `Agent` |

What is deliberately **not** mechanized, and so stays as prose in `CLAUDE.md`
and `AGENTS.md`: the awareness-not-safety doctrine, the zero-unlabeled-elements
gate, protocol-seam and main-thread invariants, model-license clearance, and
every judgment rule about scope, simplicity, and architecture. A hook can check
a string; it cannot decide whether a spoken phrase claims unearned certainty.

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

Need help? See
[`SUPPORT.md`](https://github.com/kevinle3212/sensebridge/blob/main/SUPPORT.md).
