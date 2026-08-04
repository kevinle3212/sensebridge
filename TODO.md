# TODO

Lightweight personal reminders, grouped by status: **To-Do**, **In Progress**,
**Completed**. Tracked defects/debt/risks live in [`GAPS.md`](GAPS.md); this
file is just a short list of things to come back to.

Within To-Do, items stay grouped by the review/audit that produced them and
ordered so earlier work unblocks later work.

**Item Completion** Don't just flip `- [ ]` to `- [x]`. Append, in bold, the
completion date plus what was actually done (and any verification, links, or
follow-on notes): `**Done/Fixed YYYY-MM-DD** — <what changed, how it was
verified, anything relevant left over>`. Ticking is all you have to do by
hand: `npm run todo:sweep` then cuts every ticked bullet out of its To-Do
dated section into **Completed** below, and `npm run todo:archive` sweeps that
section out to [`COMPLETED.todo`](COMPLETED.todo). To-Do holds only open work.

## Legend

| Label | Meaning |
| --- | --- |
| **P0** | Blocking — violates a hard gate (accessibility, safety-framing, security). Fix before anything else here. |
| **P1** | High priority — user-facing gap or incorrect behavior; no hard gate violated. |
| **P2** | Medium priority — spec/design fidelity or polish; non-blocking. |
| **P3** | Low priority — already decided/documented, or blocked on other work; revisit opportunistically. |
| **Needs owner** | Requires the repo owner specifically — a GitHub web-UI action, a `git`/`gh` command (agents never run these autonomously), Apple Developer credentials, a physical device, a human tester, or a decision only they can make. Combine with a priority, e.g. `**[P1]** **[Needs owner]**`. |

## Open queue (summary)

Snapshot **2026-08-01** (fourth pass, owner back) — 141 open across 52 dated
sections (75 `Needs owner`, 66 other; by priority: 1 P0, 25 P1, 49 P2, 59 P3,
7 unlabeled). Counted by parsing the **To-Do** region, not by hand;
`npm run todo:sweep` prints the open total and is the check that it stays true.
This is a signpost, not a second source of truth: every item is detailed in its
dated section under **To-Do** below; act from there.

The count is down 4 from the third pass's 145: the owner returned, ended away
mode, and decided all four mid-session-context items in one interview, so they
were implemented and closed the same day rather than waiting. Across all four
passes on 2026-08-01, `npm run todo:sweep` cut **14 finished items** and
`npm run todo:archive` moved **321 lines** to
[`COMPLETED.todo`](COMPLETED.todo) in a single dated block — single, because the
archive script used to append a fresh `## Archived <date>` heading on every run
and a second same-day sweep therefore produced a duplicate heading that failed
markdownlint MD024 in the `docs-links` CI job. It now appends under the existing
heading when the date matches. Note that **more than half the queue (75) is
`Needs owner`**: it is blocked on decisions, credentials, devices, or human
testers, not on engineering time.

The 2026-07-25 snapshot's 84 is not comparable — it was counting a To-Do region
that also held **124 already-finished items** that had been ticked but never
cut across, so the archive job reported "nothing to archive" on every run while
the file grew to 4,166 lines. The sweep now does that cut mechanically.

Everything still open falls into buckets a machine cannot close for you:

- **Device & human validation (8× P1)** — on-device latency/battery/thermal +
  blind/low-vision testers; native-speaker ES/VI review; real VoiceOver/NVDA +
  keyboard-only passes; Lighthouse mobile; simulator/device Read-flow +
  tap-through. No CI substitute exists for any of these.
- **Secrets & security (owner)** — rotate the exposed Stripe test key (P1);
  add `GITGUARDIAN_API_KEY` to **Dependabot** secrets too (Settings → Secrets
  and variables → Dependabot), not just Actions — confirmed 2026-07-28 the
  Actions secret is valid (PR #53, pushed directly, passes both GitGuardian
  checks with it), but GitHub withholds Actions secrets from
  Dependabot-triggered `pull_request` runs by design, so every dependabot PR
  saw `Error: Invalid GitGuardian API key` from an empty value, not a bad
  one; Stripe dashboard 2FA/Radar (P2).
- **GitHub / hosting settings (owner web-UI)** — make repo public + full
  "Protect main" ruleset (P1); attach `sensebridge.vercel.app` to Production
  (P1); squash-only merges, Actions allowlist, first-time-contributor approval,
  secret-scanning sub-toggles, mark commitlint/actionlint required (P2);
  Copilot agent + MCP, CodeRabbit, Discussions, tag/signed-commit rules (P2/P3);
  `RAILWAY_TOKEN`, custom domain, `og:image` (P2/P3).
- **Narration & audio assets** — done 2026-07-25: `/audio/main.mp3` is
  generated from the current copy (Signal Bridge / `#device` / `#future`
  included) and `npm run check:audio` reports a match. What remains is a real
  listen-through on device and the per-locale narration decision (P2/P3).
- **Decisions & design (owner)** — Vision English-label localization approach,
  JSON-LD-under-CSP, `npm audit` Railway `tar` CVE, `.gitnexus` read access,
  ADR convention, claude-mem project scope (P2/P3).
- **App camera + output subsystems (built; owner does git + device)** — the
  camera/lens/capture stack and the speech + haptic output stack are
  implemented and machine-verified (build green, 44 Core tests / 9 suites).
  What remains is genuinely manual: branching and committing off `main`, and
  device validation of lens switching, torch, real haptic feel, orientation,
  and thermal/battery — none of which Simulator or CI can prove. See the
  2026-07-25 07:00 PST section below.
- **Deferred / conditional (P3, non-blocking)** — extend real capture to the
  other four modes, read-aloud per-section segmentation, `impeccable`
  polish/design-json refresh, e2e-floor propagation to sibling skills, Swift
  parallelism measurement, and a handful of YAGNI/"only if it proves noisy"
  notes. Revisit opportunistically.

## To-Do

### Context-budget follow-up: computer-use MCP + eager skill-injection hooks (2026-08-03, 21:00 PST)

Owner asked whether any plugins/MCPs need disabling for heavy token usage.
Re-ran `~/.claude/scripts/measure-context-baseline.py --project sensebridge`:
session-start floor is still ~66k mean, unchanged since the 2026-08-01
pruning pass (7 MCP servers removed, 27 skills parked, claude-mem disabled) —
that pass never moved the floor. Full detail in
`sessions/2026-08-03/2100-PST.md`. Found two hook-level costs the prior audit
didn't measure (they're not skill/plugin/MCP menu entries): SessionStart
hooks eagerly inject the full `superpowers:using-superpowers` skill body and
the full `ponytail` ruleset every session (not just descriptions), and MCP
"Server Instructions" text for `computer-use`/`context7`/`serena` is injected
unconditionally every session — unlike tool schemas, this text is not
deferred. No changes made; both need owner sign-off before acting, per the
`parked-skills-development-dir` memory's rule against silently re-parking or
disconnecting anything.

- [x] **[P3]** **[Needs owner]** Decide whether to disconnect the
      `computer-use` MCP server. **Decided 2026-08-03 — keep enabled.**
      Investigated in full: usage across every project, all time, is 3 calls
      total (2026-07-22, one clipboard write for a Higgsfield ad prompt —
      already covered free by `pbcopy`); measured cost is ~1,200–1,600
      tokens/session (777 words / 4,880 chars in its MCP instructions block,
      ~2% of the 66k floor); its browser capability is neutered by design and
      redirects to `claude-in-chrome`, which this project already bans in
      favor of `gstack`. Owner chose to keep it enabled anyway, valuing
      standby availability for native-app GUI control over the small
      per-session cost. No config change made.
- [x] **[P3]** **[Needs owner]** Decide whether `superpowers`/`ponytail`
      need to keep eagerly injecting full skill/ruleset text via
      SessionStart hook every session. **Investigated 2026-08-03 — no
      action possible.** `superpowers`'s `session-start` hook has no config
      knob at all (unconditionally injects the full `using-superpowers/
      SKILL.md`). `ponytail` already mode-filters
      (`filterSkillBodyForMode`), but only the intensity-table row and
      worked example differ by level — the ladder/rules/output/boundaries
      sections are identical at lite/full/ultra, so switching levels
      wouldn't meaningfully shrink the injection. Leaving both as-is; both
      are active features currently in use.

### Token/usage optimization sign-off pass (2026-08-03, 00:00 PST)

Owner interview against `tmp/optimization-audit-2026-08-01.md` and
`tmp/AWAY-REPORT-token-optimization.md`, scoped to two reversible actions only:
park unused skills to `~/Development/skills`, disable (not remove) MCP
servers. Full detail in `sessions/2026-08-03/0000-PST.md`. 20 skills parked, 3
MCP servers disabled (`filesystem`, `higgsfield`, `puppeteer` — all reversible
via `mcpServers_disabled` in `~/.claude.json`), 8 `gitnexus-*` skills parked
after an Opus 5 escalation, `gitnexus-cli` SKILL.md gained query-verb docs,
hyperframes cluster kept global after a rendered demo video convinced the
owner.

- [x] **[P2]** **`gstack /browse` is non-functional — Playwright browser
      binary won't finish installing.** Resolved 2026-08-03. Root cause was
      two compounding bugs, not a Gatekeeper/XProtect scan as originally
      suspected: (1) the active Node was v26.3.1 — the same Node-26
      extraction-truncation bug already seen with `puppeteer`'s Chrome
      download (see memory `puppeteer-chrome-node26-unpack.md`), which stops
      writing a large binary partway through; (2) RTK's shell hook silently
      rewrites a bare `npx playwright install ...` into `rtk playwright
      install ...`, and every prior attempt (across two sessions, 5 total)
      went through that rewritten path unnoticed. Fix: ran the install from
      inside `~/.claude/skills/gstack` (so it resolved the project's own
      pinned `playwright` dependency, not a fresh temp install) under Node
      22.22.3 LTS via `nvm`, wrapped in `rtk proxy` to force the raw,
      unwrapped path. Completed clean on the first try — no hang, exit 0,
      full 147.7MB `chrome-headless-shell` extracted. Verified end-to-end:
      `browse/dist/browse goto https://example.com` → `Navigated to
      https://example.com (200)`, then `browse/dist/browse text` → returned
      clean page text. `gstack /browse` is fully functional; browser
      automation is available again.

- [x] **[P3]** **Review the `.impeccable/config.json` scope exclusion added
      today.** Resolved 2026-08-03: kept. `"tmp/hyperframes-demo/**"` in
      `detector.ignoreFiles` directly supports the same-session "keep
      hyperframes" decision — `tmp/hyperframes-demo/` is a real, gitignored
      video-render project, not website content, and would otherwise trip the
      design-linter's brand checks for no reason. The only other change in
      that diff was incidental JSON key reordering (`createdAt`/`reason`
      swap) from whatever wrote the file — cosmetic, no semantic effect, left
      as-is.

### Legal hardening, WCAG sweep, CI wiring (2026-08-01, overnight, away mode)

Owner asked for maximum liability protection, US governing law in
`legal/TERMS_AND_CONDITIONS.md`, US + international compliance across the legal
docs, ADA/EAA/WCAG conformance on the website, and every remaining local gate
wired into GitHub CI. What landed and what was verified is in
`tmp/AWAY-REPORT.md`. These are the parts a machine could not close.

- [ ] **[P1]** **[Needs owner]** **Have counsel review `legal/` before public
      launch.** Every file there still carries its own "not legal advice, review
      by qualified counsel" banner, and that banner is now load-bearing: the
      liability, warranty-disclaimer, indemnity, limitation-period, and
      class-action-waiver clauses added on 2026-08-01 are drafted to the
      strongest position US law generally allows, which is exactly the kind of
      drafting a court trims when it is over-reached and unsupervised. Nothing
      in `legal/` has been read by a lawyer. Acceptance: counsel sign-off
      recorded, or the specific clauses they struck listed here.

- [ ] **[P2]** **Add localStorage migration to databases.** The website keeps
      visitor state in `localStorage` in three places —
      `src/scripts/monitoring-consent.ts` (the crash-reporting consent answer,
      key `sb-monitoring-consent`), `src/components/Header.astro` (theme mode),
      and `src/scripts/debug.ts` (the `sb-debug` flag). `localStorage` is
      per-origin, per-browser, and silently unavailable in some private-browsing
      modes, so none of it survives a device change and consent has to be
      re-asked. Migrating it to a database is a real change of posture, not a
      refactor: it would introduce the first server-side store this project has
      ever had, and `CLAUDE.md`'s "serverless, on-device, no backend, no
      accounts" invariant plus `docs/PRIVACY.md` and `legal/PRIVACY_POLICY.md`
      all currently assert the opposite. Decide the destination first (an
      on-device store such as IndexedDB keeps the invariant; a hosted database
      breaks it and needs the privacy docs, `legal/SUBPROCESSORS.md`, and the
      consent flow updated in the same change). Acceptance: destination chosen
      and recorded, migration path written for each of the three keys including
      what happens to a visitor who already answered, and every doc that claims
      "no backend" reconciled with whatever is chosen.

- [ ] **[P2]** **[Needs owner]** **Run a real screen-reader pass over the new
      `/accessibility` page** (`website/src/pages/accessibility.astro` and its
      `es/` and `vi/` siblings). pa11y and axe both pass on it, but this is the
      page that tells blind visitors what the product promises them, and no
      automated check can tell you whether it is *understandable* when heard
      rather than read. Acceptance: one pass with VoiceOver and one with NVDA or
      TalkBack, in at least one non-English locale, with any confusing
      announcement fixed.

- [ ] **[P2]** **[Needs owner]** **Get a native speaker to review the Spanish
      and Vietnamese accessibility-statement copy** (`accessibilityPage` in
      `website/src/i18n/es.ts` and `website/src/i18n/vi.ts`, added 2026-08-01).
      It was written without native review, and it is not ordinary marketing
      copy: it names the European Accessibility Act's required feedback
      mechanism, the response timelines the statement commits to (5 working days
      to acknowledge, 30 days to answer substantively), and per-jurisdiction
      enforcement routes. A mistranslation there misstates a legal commitment
      rather than reading awkwardly. The page states that the English version
      governs, which limits the exposure but does not remove it. This is
      narrower than the general ES/VI review already tracked at the top of this
      file — that one is about product copy; this one is about a compliance
      document. Acceptance: both locales read by a native speaker, with the
      timeline sentences and the enforcement-route names confirmed as accurate.

### README orientation + animated Graphify visual (2026-07-31, 20:00 PST)

`website/README.md` now reads as a sub-README that routes to the root
`README.md`, and the root README's "Knowledge Graph (Graphify)" section carries
an animated SVG rendered from the real `graphify-out/graph.json` by the new
`npm run graph:visual`. Gates green before handoff — `npm run check` exit 0,
markdownlint 0 issues across 148 files, and the SVG re-renders byte-identically.
Full write-up in `sessions/2026-07-31/2000-PST.md`. This is what is left.

- [ ] **[P2]** **[Needs owner]** **Commit this session's work.** New:
      `tools/graph-visual.mjs`, `docs/assets/graph.svg`,
      `docs/assets/graph-static.svg`. Modified: `README.md`,
      `website/README.md`, `package.json` (`graph:visual`),
      `.markdownlint.jsonc` (MD033 `allowed_elements` += `picture`, `source`),
      `docs/TOOLING.md`. **Same caveat as the sections below:**
      `docs/TOOLING.md` already carried unrelated pre-existing edits, so stage
      it with `git add -p` rather than a plain `git add`. Suggested branch
      `docs/readme-graph-visual`; ready-to-paste commands are in
      `tmp/handoff.md`.

- [ ] **[P2]** **[Needs owner]** **VoiceOver pass on the rendered README.** The
      graph SVG carries `<title>`, `<desc>`, and `role="img"`, and the `<img>`
      carries alt text naming the clusters and hub nodes — but none of it has
      been heard through a real screen reader, and a decorative-image
      misannouncement here would be exactly the failure this repo gates against.
      Machine checks cannot close this one.

### Sweep pipeline + BMAD gate (2026-07-31, 18:00 PST)

Closed the two owner-named sections below, applied the CLAUDE.md dedupe
decision, and made this file's own archive pipeline self-maintaining — the
124 finished items that had silently accumulated in To-Do are now in
[`COMPLETED.todo`](COMPLETED.todo). Two standing manual re-verifications became
gates. Full write-up in `sessions/2026-07-31/1800-PST.md`. This is what is
left.

- [ ] **[P2]** **[Needs owner]** **Commit this session's work.** New:
      `tools/sweep-done-todo.mjs`, `tools/check-bmad-config.mjs`,
      `sessions/2026-07-31/1800-PST.md`. Modified:
      `tools/archive-completed-todo.mjs` (UTC → Pacific date stamp),
      `package.json` (`check:bmad`, `todo:sweep`, `todo:sweep:check`),
      `.githooks/pre-commit`, `docs/TOOLING.md`, `docs/ENVIRONMENT.md`,
      `TODO.md`, `COMPLETED.todo`. Also edited **outside the repo** and so not
      part of any commit: `~/.claude/CLAUDE.md` §17 (backup at
      `~/.claude/backups/CLAUDE.md.pre-serena-rtk-dedupe-20260731`).
      **Same caveat as the section below:** `docs/TOOLING.md` already carried
      unrelated pre-existing edits, so stage it with `git add -p` rather than a
      plain `git add`. Suggested branch `chore/todo-sweep-pipeline`. Gates were
      green before handoff — `npm run check` exit 0, markdownlint 0 issues
      across 148 files.

### RTK command-shape enforcement hook (2026-07-31, 16:00 PST)

Verification pass over Ponytail / RTK / Serena confirmed all three work and are
prioritized (RTK saved 776 tokens over 11 covered commands; `prefer-serena.sh`
12/12; Ponytail active at `full`). It also found that RTK's rewrite matches on
command **shape** — a bare `git status` is rewritten and saved 642 tokens, but
`git status --short | head -5` is not, and nothing warns. Fixed structurally by
`.claude/hooks/prefer-rtk-shape.sh` (+ a 14-case self-check); see the session
log for the full write-up. These are what is left.

- [ ] **[P2]** **[Needs owner]** **Commit and PR the new hook.** Files:
      `.claude/hooks/prefer-rtk-shape.sh` and
      `.claude/hooks/tests/prefer-rtk-shape.test.sh` (both new),
      `.claude/settings.json` (registration), `docs/TOOLING.md` (hook count
      eleven → twelve plus the entry). **Caveat:** `settings.json` and
      `TOOLING.md` were *already* modified before this session, so a plain
      `git add` sweeps in unrelated pre-existing edits — stage those two with
      `git add -p`. Suggested branch `chore/rtk-command-shape-hook`; the full
      copy-paste sequence is in `sessions/2026-07-31/1600-PST.md`.

### Config dedupe + Headroom teardown verification (2026-07-31, 12:00 PST)

Produced by an audit of RTK/Serena wiring, global vs. project settings
redundancy, and the `127.0.0.1:8787` question. The token-leak fix itself is
recorded under the `tmp/handoff.md` entry further down; these are what is left.

- [ ] **[P1]** **[Needs owner]** **Both cswap slots now hold the *same*
      credential, so rotation is a no-op.** Surfaced 2026-07-31, 18:00 PST,
      immediately after the account-1 re-login above fixed the dead token.
      `cswap list` warns `Account-1 and Account-2 hold the same credential
      (kevinle@uoregon.edu) — one slot's backup was overwritten`, and
      `cswap status` adds `live credential belongs to another account — a
      switch repairs it`. Slot 1 still *labels* itself
      `kevinle3212@gmail.com` and still reports that account's usage
      (5h: 100%), so the label and usage poll survived while the stored
      refresh token did not. Most likely cause: `cswap add` was run while the
      live credential was still account 2's, which writes account 2's token
      into slot 1's backup under slot 1's existing label.

      **Consequence:** `cswap switch` cannot actually rotate — both slots
      authenticate as `kevinle@uoregon.edu` — so the account-1 budget
      (currently 100% of its 5h window) is unreachable and the 7d limit on
      account 2 is the only real ceiling.

      **Steps** (owner-only; every one needs an interactive browser login that
      an agent cannot perform): log in to Claude Code as
      `kevinle3212@gmail.com`, then run `cswap add --slot 1` — the `--slot`
      argument is what stops it landing in a third slot. **Verify:**
      `cswap list` should print two distinct emails with no
      `hold the same credential` warning, and `cswap status` should drop the
      `live credential belongs to another account` line. If the warning
      persists, `cswap remove 1` first and re-add.

### Live secrets sit unexpanded in `~/.claude.json` (2026-07-31, 01:00 PST)

- [ ] **[P1]** **[Needs owner]** **Rotate the two credentials, and shred the
      backup that still holds one.** Fallout from the item above.

      1. **Rotate both.** The 40-char GitHub PAT and the 32-char Dune key were
         live in a plaintext file for an extended period and were never
         rotated — step 2 of the original plan was owner-only and never
         executed. Removing them from `~/.claude.json` does nothing to the
         credentials themselves; both are presumed still valid at their
         issuers. GitHub PAT: <https://github.com/settings/tokens>. Dune key:
         <https://dune.com/settings/api>.
      2. **`~/.claude.json.bak.premcpmerge` still contains the Dune API key as
         a literal** — 82,938 bytes, mode `0600`, dated 2026-07-18, verified by
         inspection this session (the GitHub PAT is *not* in it; that backup
         predates it). Shred it after rotating: `rm -P
         ~/.claude.json.bak.premcpmerge`. It is the last copy on disk either
         credential is known to sit in.
      3. Re-verify with `bash ~/.claude/scripts/migrate-mcp-secrets.sh --check`
         and confirm no `.bak` files remain: `ls ~/.claude.json.bak.*`.

      Note the repo itself stayed clean throughout — `ggshield secret scan repo
      .` passed on full history this session, and neither value ever appeared
      in tracked files.

      **Historical detail.** A 40-character GitHub PAT was stored literally at
      `mcpServers.github.env.GITHUB_PERSONAL_ACCESS_TOKEN`, and a Dune API key at
      `mcpServers.dune.headers["x-dune-api-key"]`. Owner chose `${VAR}` expansion
      plus self-rotation. Not applied by the agent: `~/.claude.json` is a live
      94KB state file that the running Claude Code process also writes, so
      editing it mid-session risks clobbering project history. Neither value
      appears anywhere in this repo (verified — `TODO.md` mentions the variable
      *names* only).

      **Steps:**

      1. Inspect current state at any time (read-only, safe while Claude runs):
         `bash ~/.claude/scripts/migrate-mcp-secrets.sh --check`
      2. **Rotate both credentials first** — swapping in a placeholder does not
         invalidate the old value. GitHub PAT:
         <https://github.com/settings/tokens>. Dune key:
         <https://dune.com/settings/api>.
      3. **Quit Claude Code completely**, then run
         `bash ~/.claude/scripts/migrate-mcp-secrets.sh`. It refuses to run while
         Claude Code is up, backs up to `~/.claude.json.bak.<timestamp>` at
         `0600`, rewrites atomically via temp file + `mv`, verifies the scalar
         count is unchanged, and is a no-op on re-run.
      4. Export the rotated values (the script prints both the plain and keychain
         forms), restart the shell, then confirm with
         `claude mcp list | grep -E 'github|dune'`.
      5. `rm -P` the backup — it still holds the old literals.

      The script was verified end-to-end against a **copy** of the real
      `~/.claude.json`: both placeholders written, all 1,534 scalars preserved,
      output valid JSON, backup at `0600`, idempotent on re-run.

      **Still open as of 2026-07-31, 11:00 PST.** Re-ran step 1 this session:
      both values are still `LITERAL` (PAT 40 chars, Dune key 32 chars).
      Steps 2–5 are owner-only by construction — rotation happens in two web
      UIs, and the script refuses to run while Claude Code is up.

### `pre-push` doesn't actually use `scripts/app.sh` (2026-07-30, 21:00 PST)

- [ ] **[P1]** **[Needs owner]** **`scripts/app.sh` is untracked and must be
      committed.** Surfaced 2026-07-31, 17:00 PST while verifying the change
      above: `git status` reports it `??`, and `git check-ignore` exits 1, so it
      is not ignored — it simply was never committed. Every sibling in
      `scripts/` is tracked (`check-env-loader.sh`, `env.sh`, `lint.sh`,
      `open-xcode.sh`, `setup.sh`); `app.sh` alone is not.

      This was already latent — `package.json`'s `app:*` scripts and
      `CLAUDE.md`'s "Hand it back testable" section both point at a file no
      fresh clone has. Routing `.githooks/pre-push` through it **raises the
      severity**: the hook used to be self-contained, and now a fresh clone
      would fail the push gate outright. Mitigated but not fixed — `pre-push`
      now checks for the file first and exits with a sentence naming the cause
      rather than a bare `No such file or directory`. The real fix is one
      `git add scripts/app.sh` in the next commit; until then the delegation is
      owner-machine-only.

      **Original finding.** `scripts/app.sh`'s header comment claimed it consolidated "the
      simulator build in `.github/workflows/ci.yml` and `.githooks/pre-push`"
      into one entry point, but `.githooks/pre-push` still duplicates its own
      inline Xcode-project detection and `xcodebuild build` invocation rather
      than calling `scripts/app.sh build` — the comment and the code have
      drifted. Surfaced while making `scripts/setup.sh`, `scripts/lint.sh`,
      and `.githooks/pre-push` skip cleanly on non-macOS (see
      `sessions/2026-07-30/2100-PST.md`). Not fixed there: routing pre-push
      through `app.sh` would touch the CI-mirroring build gate itself, which
      the file's own comment says must stay in sync with `ci.yml` — more
      regression risk than that task warranted. Either de-duplicate
      `pre-push` onto `scripts/app.sh build`, or fix the header comment to
      stop claiming it already is.

### Dedicated Google Account for project tooling (2026-07-30)

- [ ] **[P3]** Create a Google Account dedicated to SenseBridge (not the
      owner's personal account), then migrate every tool currently
      authenticated under a personal/ad-hoc Google account (Analytics, Search
      Console, Firebase, Drive, or any other OAuth-connected service) onto it.
      Lowest priority — revisit only after everything else in this file.

### npm command center (2026-07-28, 19:45 PST)

Root `package.json` went from zero scripts to a full suite, `website/` gained
the `tsc` commands for both tsconfigs, and two copy-paste-only recipes became
real scripts (`scripts/app.sh`, `scripts/check-links.sh` — the latter now the
single code path for both `npm run check:links` and `ci.yml`'s docs-links job).
Documented in `docs/ENVIRONMENT.md` → "Command center". Verified locally:
`npm run check`, `lint:md`, `lint:shell`, `actionlint`, `app:build`
(BUILD SUCCEEDED), and `website`'s `typecheck:tsc`, `lint`, `format` all pass.

- [ ] **[P3]** Two findings surfaced while doing the above, neither caused by
      it, both left for the owner:
      - `~/.cache/puppeteer/chrome-headless-shell/mac_arm-148.0.7778.97` is a
        **truncated extraction** (only `ABOUT` + `LICENSE`, dated 2026-07-25) —
        the Node 26 unzip bug that `website/README.md` documents. The
        2026-07-25 session repaired `chrome/` and missed this one, and no
        cached `.zip` remains to repair from. Harmless today, because pa11y
        launches the full Chrome binary and `scripts/docs.sh` now sets
        `PUPPETEER_SKIP_CHROME_HEADLESS_SHELL_DOWNLOAD=true`; still a trap for
        anything requesting `headless: "shell"`, which would find the folder,
        assume it is installed, and fail. Clear it with
        `rm -rf ~/.cache/puppeteer/chrome-headless-shell` to let a future
        install re-fetch cleanly.
      - `docs/GITHUB_MODELS.md` (lines 10 and 60) links to
        `../.github/prompts/README.md`, which is outside the Jekyll source, so
        `jekyll-relative-links` leaves it alone and it **404s on the published
        site** — though it does resolve when the file is read on GitHub. These
        are the only two such links in the whole built site;
        `docs/AI-MODELS.md` handles the same out-of-source case three times
        (lines 12, 73, 99) with absolute `github.com/.../blob/main/...` URLs.
        Not fixed here: which audience a `docs/` page should favour is a
        content decision, not a typo.

### Antigravity + Gemini CLI agent config (2026-07-28, 19:00 PST)

Added `.agents/mcp_config.json` + `.agents/rules/precedence.md` (Antigravity's
actual project-level config location, confirmed against Google's docs —
`.gemini/` is Gemini-CLI-only, not shared with Antigravity at the project
level). Audited `.gemini/` for hook parity with `.codex/`/`.cursor/` and found
it's genuinely blocked upstream, not just skipped — see
`docs/TOOLING.md`'s "Antigravity vs. Gemini CLI" section for the full finding.

- [ ] **[P3]** Revisit wiring `.gemini/settings.json` hooks (Serena reminder +
      impeccable design-QA, matching `.codex/hooks.json`/`.cursor/hooks.json`)
      once either lands upstream: `serena-hooks` adding a
      `gemini`/`antigravity` `--client` value, or `npx impeccable update`
      shipping a `.gemini/skills/impeccable/scripts/hook.mjs`. Neither exists
      today (checked 2026-07-28) — don't hand-roll around either gap.

**Addendum (2026-07-30):** the tools this project-level config targets are now
actually installed on this machine, not just configured for. `npm install -g
@google/gemini-cli` (0.53.0) — the `gemini` binary was missing entirely before
this. `brew install --cask antigravity` (2.4.3, `/Applications/Antigravity.app`)
and `brew install --cask antigravity-cli` (1.1.8, `agy` binary) — both were
absent. **Correction to `docs/TOOLING.md`'s WakaTime row**: Antigravity is
*not* a VS Code fork with Open VSX support the way Cursor is — `agy --help`
exposes no `--install-extension`-style flag, and the app bundle carries no
`code`-style CLI shim; instead `agy plugin install <target>` manages
Antigravity's own plugin marketplace, an unrelated system. No WakaTime listing
was found there, so the WakaTime-for-Antigravity row stays open, now correctly
scoped as "different extension model," not "same Open VSX extension, just not
installed yet." Cursor's half is done: `WakaTime.vscode-wakatime` v30.2.1
installed via `/Applications/Cursor.app/Contents/Resources/app/bin/code
--install-extension` (Cursor.app was already present, v3.12.17, not installed
by this session).

**Second addendum (2026-07-30) — re-checked the P3 hook-parity item above now
that both blockers might have moved:** `serena-hooks --help` (installed,
v1.5.3) still only accepts `--client [claude-code|vscode|codex]` — confirmed
directly against the live tool, not stale docs; still no `gemini`/`antigravity`
value. `npx impeccable update` (v3.5.0 → v4.0.4, same session) **did** add
`.gemini/skills/impeccable/scripts/hook.mjs` where it didn't exist before —
but it's byte-identical to `.claude/skills/impeccable/scripts/hook.mjs`
(`diff` confirms), and that script's own docstring says it "reads the Claude
Code / Codex / Cursor hook event from stdin and routes by `hook_event_name`"
— Gemini CLI isn't in that list, and isn't compatible: Gemini's actual hook
event names are `SessionStart`/`BeforeAgent`/`BeforeToolSelection`/
`BeforeTool`/`AfterModel`/`AfterAgent`/`SessionEnd` (confirmed against the
installed `@google/gemini-cli`'s own bundled
`docs/hooks/writing-hooks.md`), not `PostToolUse`/`Stop`, which is what
`hook.mjs` checks for. Wiring it in under Gemini's event names would either
silently no-op (the script's own "never break a turn, always exit 0"
contract) or run the wrong code path — not a real fix, so still not wired.
Also tried the vendor's own migration path first, on the theory it might
side-step hand-rolling: `gemini hooks migrate --from-claude` — it reads
`.claude/settings.local.json` (gitignored, personal, no hooks in it), not
`.claude/settings.json` (the tracked file where every hook in this repo
actually lives), so it reports "No hooks found" and migrates nothing. Genuine
dead end via the official tooling, not a shortcut skipped. Item stays open,
now closed out as precisely as it can be without patching a third-party
package (`serena-hooks`) or fighting `npx impeccable update`'s vendor sync —
both explicitly against this repo's own rules for those tools.

**Antigravity cask ambiguity — resolved (2026-07-30):** fetched the raw cask
definitions from `Homebrew/homebrew-cask` for all three. `antigravity`
(2.4.3, installed) and `antigravity-cli` (1.1.8, installed, `agy` binary) both
ship from `storage.googleapis.com/antigravity-public/...` and are the current
"Antigravity Hub" + companion-CLI pairing — this is what `docs/TOOLING.md`
means by "Antigravity (IDE + `agy` CLI)". `antigravity-ide` is a separate,
older product (2.1.1, bundle ID `com.google.antigravity-ide`, its own
`agy-ide` binary, distributed from Google's legacy `edgedl.me.gvt1.com` update
CDN rather than the antigravity-public bucket) — not a duplicate cask entry,
a genuinely different/superseded app. Correctly left uninstalled; no action
needed.

### Spatial Future glasses — drag, components, neural pathways (2026-07-28, 13:00 PST)

Shipped in `website/` this session: drag-to-orbit on the `#future` glasses
stage (`createDragOrbit` in `src/scripts/scenes/core.ts`), seven new glasses
components, and a shared `createNeuralPathways()` network wired into both
`glasses.ts` and `phone.ts`. Covered by the new
`npm run check:scene-drag` (4/4 locally, now in CI's `a11y` job). Full
narrative in `sessions/2026-07-28/1300-PST.md`. What's left:

- [ ] **[P2]** The glasses browline (`BROWLINE_Y` in
      `src/scripts/scenes/glasses.ts`) floats visibly detached above the lens
      rims, which reads as a stray bar once the model is dragged toward
      profile. Pre-existing geometry, untouched under surgical-changes —
      decide whether to lower it onto the rims or leave it as stylization.

- [ ] **[P2]** **[Needs owner]** Judgement call: no lens fill or waveguide
      display plane was added to the glasses. A translucent disc muddies the
      wireframe read, so it was deliberately skipped — say if it's wanted.

- [ ] **[P2]** **[Needs owner]** Run the drag on a real touch device.
      `touch-action: pan-y` is asserted by CSS and reasoned about, but the
      headless check drives a mouse — the horizontal-drag-vs-vertical-scroll
      split on an actual phone is unverified.

### GitHub Models workflow scaffold (2026-07-28, 12:30 PST)

Owner wants a `.github/workflows/` job that calls a GitHub Models model via
`actions/ai-inference` (auth via the built-in `GITHUB_TOKEN`, `models: read`
permission — no secret needed). Model choice discussed: DeepSeek-V3-0324
recommended over GPT-5 (cost/latency) and Llama 4 Scout 17B-16E (weaker
reasoning) for general dev use. Not yet built — owner confirmed Codespaces
prebuilds are enabled but repo Settings didn't show a "Models" feature
toggle; likely an org/account-level Copilot policy gate rather than a repo
setting (see `github.com/marketplace/models` → "Use this model" as the
direct way to confirm access regardless of the repo Settings toggle).

- [ ] **[P2]** **[Needs owner]** Confirm GitHub Models access is enabled for
      the account/org (via `github.com/marketplace/models`, not just repo
      Settings → Features, which may not surface the toggle on every
      plan/org).

- [ ] **[P2]** Once confirmed, scaffold `.github/workflows/` calling
      `actions/ai-inference` with `models: deepseek/DeepSeek-V3-0324` (or
      final pick) and verify a run succeeds in Actions.

### Docs GH Pages header/content gap (2026-07-28, 12:00 PST)

Owner reported no visible gap between the sticky nav header and the page
content on `https://kevinle3212.github.io/sensebridge/`. A static read of
`docs/assets/css/docs.css` found no bug: `main` already has
`padding-block: 24px` (`40px` at ≥900px, lines 300-320) and `.signal-hero`
carries no negative margin. The live site was serving `main`'s last deploy
the whole time this was checked, which predated the PR fixing the adjacent
hero-SVG "Camera" clip (merged 2026-07-28 as `5e26b01`) — so this needs a
fresh look now that the fix is live, not more static reading.

- [ ] **[P3]** Load `https://kevinle3212.github.io/sensebridge/` after the
      next Pages deploy and check the header/content boundary directly
      (screenshot or a headless-browser pass). If a gap is genuinely
      missing, it's most likely something JS-driven or page-specific, not
      the shared `main`/`.signal-hero` rules already read.

### Contributor-configurable deployment (`SITE_URL`) (2026-07-27, 23:50 PST)

The site's deployment origin now comes from `SITE_URL` (untracked
`website/.env`, the Dockerfile's `SITE_URL` build arg, or the host's project
settings) with a `http://localhost:4321` fallback, so a fork builds green and
can never point at this project's Vercel or Railway. `npm run check:site-url`
is the gate. The app side uses the same seam: `BUNDLE_ID_PREFIX` in the
gitignored `app/Config/Signing.local.xcconfig`, defaulting to
`com.sensebridge`.

- [ ] **[P3]** Optional: set the `RAILWAY_SERVICE` / `RAILWAY_ENVIRONMENT`
      repository *variables* if those names ever diverge from `sensebridge` /
      `preview`; the workflow falls back to today's names.

### `.env` auto-loading (2026-07-28, 00:00 PST)

`.env` is now read automatically by every entry point — `scripts/env.sh` for
shell scripts and git hooks, `website/scripts/load-env.js` for everything in
`website/` that runs on Node, `website/scripts/with-env.js` for the
`railway:*` / `vercel:*` CLI wrappers. Root `.env` first, then `website/.env`;
an already-exported variable always wins. `scripts/check-env-loader.sh` guards
the parse-don't-source property and runs in CI. Details in
`sessions/2026-07-28/0000-PST.md`.

- [ ] **[P2]** **[Needs owner — decision]** A GitGuardian outage blocks every
      local commit. `.githooks/pre-commit` runs `ggshield secret scan
      pre-commit` under `set -euo pipefail`, so when the API returns 503 (hit
      on 2026-07-28) the hook aborts and nothing can be committed — even
      though gitleaks passed and CI scans independently. Options: leave it
      (fail-closed on a security gate, which is defensible), or treat a
      *transport/API* failure as advisory while keeping a real finding
      blocking. Not fixed unilaterally — it weakens a security gate, so it is
      your call.

### Admin dashboard setup — Next.js + WakaTime (2026-07-27)

**Decision (2026-07-27):** Next.js, not Astro, for the admin dashboard.
`website/` is deliberately static/zero-JS/content-first (see
[`docs/TOOLING.md`](docs/TOOLING.md)); an admin dashboard is the opposite
profile — dynamic, behind auth, all interactive widgets, no SEO/zero-JS
constraint — so it should be a **separate app**, not bolted onto `website/`.
Next.js API routes/middleware handle auth and keep the WakaTime API key
server-side.

- [ ] **[P3]** Scaffold a new Next.js app (outside `website/`, e.g.
      `admin/`) for the dashboard — decide hosting (Vercel, same as
      `website/`?) and auth approach (single-owner login) before scaffolding.

- [ ] **[P3]** Wire in WakaTime: start with the public embed/share widgets
      (`wakatime.com/share/@user/...` — SVG badges/charts, no API key
      needed) before building a custom API-route + chart integration. The
      WakaTime API key already lives at `~/.wakatime.cfg`
      ([`docs/TOOLING.md`](docs/TOOLING.md)) — if a custom integration is
      built later, read it server-side only, never in a client bundle.

- [ ] **[P3]** Decide dashboard scope (WakaTime stats only vs. TODO/session-log
      surfacing, CI status, etc.) before scaffolding — affects whether a
      backend/DB is needed at all or if this stays a thin read-only view.

- [ ] **[P3]** Surface Sentry analytics in the dashboard — issue counts, crash-free
      rate, release health, and error trend for **both** reporting surfaces: the
      `website/` browser SDK and the `app/` iOS SDK. (This item originally said the
      iOS app was out of scope, on the no-telemetry doctrine. The owner reversed
      that doctrine on 2026-07-31 and the app now reports, opt-in and off by
      default — see the environment-variable section below.)
      Read Sentry's Web API server-side only, from a Next.js route handler holding a
      **read-scoped** auth token (`event:read`, `project:read`, `org:read` — never
      `project:write` or `org:admin`). The token is server-side secret material: it
      goes in the host's env store and `admin/.env.example` as a placeholder only,
      never in a client bundle, never in `NEXT_PUBLIC_*`, never committed. Cache
      responses (Sentry rate-limits per-org) and fail soft — a dashboard tile that
      cannot reach Sentry renders "unavailable", it does not break the page.
      Blocked on the scaffold item above; there is nothing to add a page to yet.

### Logo system — "First Light" mark, generated to `tmp/logo/` (2026-07-27)

A full logo system was generated into `tmp/logo/` for review: 56 SVG masters
and 281 rasters covering icon-only, stacked and horizontal lockups, app icon,
GitHub avatar, navbar, favicon/browser-tab, and PNG + JPEG in full colour,
monochrome, and 1-bit black/white. Nothing is wired into the app or the site
yet — `tmp/` is gitignored, so this is a proposal, not a shipped asset.

The mark keeps the DNA of the existing `website/public/favicon.svg` (ink field,
Signal Blue sensing ring, solid core) and adds one element: the ring is broken
at the lower right and a Perception Glow chord bridges the break. Ring = the
sensing horizon; the break = the gap between the sensed world and
understanding; the warm chord = the bridge across it.

Regenerate with, from the repo root, in order:

- `python3 -m venv /tmp/logo-venv && /tmp/logo-venv/bin/pip install fonttools brotli`
- `/tmp/logo-venv/bin/python tmp/logo/build-wordmark.py` — Fraunces to vector paths
- `node tmp/logo/build-svg.js` — geometry, colourways, lockups
- `node tmp/logo/build-raster.js` — PNG / JPEG / ICO / app icon
- `node tmp/logo/build-sheet.js && node tmp/logo/build-preview.js` — contact
  sheet + screenshots

`build-raster.js` and `build-preview.js` borrow `sharp` and `puppeteer` from
`website/node_modules` by absolute path, so `npm install` must have run in
`website/` first. Open `tmp/logo/index.html` to review everything at once.

The prompt that produced it, kept verbatim so the system can be regenerated or
re-briefed from scratch:

> Generate a project logo for SenseBridge, derived from the existing brand.
> I want multiple versions: one with full colour, monochrome, black/white,
> stacked logo, horizontal, icon only, app icon, GitHub avatar preview,
> navbar, favicon, PNG and JPEG, browser tab icon. Store into `./tmp/` for me
> to view.

- [ ] **[P2]** **[Needs owner]** Approve or reject the "First Light" mark in
      `tmp/logo/index.html`. It is a proposal; the current favicon still ships.
      If rejected, say what to change (the bridging chord is the only new
      element and is the easiest thing to drop or redraw).

- [ ] **[P2]** If approved, wire the assets in: replace
      `website/public/favicon.svg` with `tmp/logo/svg/favicon-adaptive.svg`,
      add `favicon.ico` + `apple-touch-icon-180.png` + `icon-192/512`, and
      populate the empty
      `app/SenseBridge/Resources/Assets.xcassets/AppIcon.appiconset/` (it
      currently holds only `Contents.json` — the app has no icon at all).
      Move the masters out of `tmp/` to a tracked home first; `tmp/*` is
      gitignored, so nothing there survives a clean.

- [ ] **[P3]** If approved, decide where the masters live long-term
      (`website/public/brand/` vs a top-level `assets/brand/`) and whether the
      three build scripts ship with them. They depend on `website/node_modules`
      and on the self-hosted Fraunces woff2 — both already in-repo, but the
      `sharp`/`puppeteer` paths are hard-coded absolute and need relativizing
      before the scripts are tracked.

- [ ] **[P3]** Add the mark to `CREDITS.md` / brand docs if it ships, and note
      that the wordmark is Fraunces (SIL OFL 1.1, already vendored under
      `website/public/fonts/` with its licence).

### Repo-sync commit backlog + CI-green fixups (2026-07-27, 13:00 PST)

- [ ] **[P3]** CodeQL's `js/file-access-to-http` ("File data in outbound
      network request") still fires on `tools/docs-a11y.mjs`'s
      `page.goto(url)` call after two fix attempts: filtering built HTML
      filenames through an explicit allowlist regex before building the URL,
      then an inline `// codeql[js/file-access-to-http]` suppression comment
      above the flagged line — neither cleared it on PR #42's "CodeQL"
      umbrella check (non-blocking; only "CodeQL (JavaScript/TypeScript)" is
      in the required-checks ruleset, and that one passes). The URL is always
      `http://127.0.0.1:PORT/...`; only the already-allowlisted path segment
      comes from the local build directory listing, so this reads as a false
      positive from a CI-only local crawler, not a real request-forgery risk.
      Next step if revisited: confirm the exact rule id GitHub expects for
      inline suppression (mine may be wrong), or dismiss the alert directly
      via the code-scanning UI/API with a stated false-positive reason once
      it posts as a numbered alert on `main`.

### Awareness camera preview + object highlights (2026-07-27, 00:30 PST)

Live ARKit camera feed on the awareness screen with a yellow outline around
each recognized object, and a more accurate naming pass behind both. Object
naming moved from one whole-frame `ClassifyImageRequest` to
`GenerateObjectnessBasedSaliencyImageRequest` → per-region classification via
`regionOfInterest`, which is what produces the bounding boxes; the spoken
narration is composed from the same detections the outlines are drawn from, so
the two channels cannot disagree. New: `Perception/DetectedObject.swift`,
`ObjectClassificationService.detect(...)`,
`AmbientSensingSource.previewImage(for:maximumDimension:)`, and
`Features/ObstacleAwareness/{AwarenessPreviewFeed,AwarenessPreviewView}.swift`.
The preview draws ARKit frames directly rather than hosting `ARSCNView` — see
the closed item below. Machine-verified: Core 83 tests / 13 suites,
`xcodebuild build` green with zero warnings, `xcodebuild test` green (13
swift-testing + 8 UI), `scripts/lint.sh` 0 violations in 62 files. Session logs:
`sessions/2026-07-27/0030-PST.md` and `sessions/2026-07-27/0100-PST.md`.

- [ ] **[P0]** **[Needs owner]** **Confirm camera frames actually reach the
      screen, on device.** The conversion is now unit-tested
      (`SenseBridgeTests/AmbientPreviewImageTests`, 3 tests) but delivery is not
      and cannot be: ARKit produces no frames in a simulator, so the end-to-end
      path is device-only. Two rounds were already lost to reporting an
      unobservable fix as confirmed. Reinstall, open Awareness, tap "Start
      hands-free awareness", and report which of three states appears — the live
      feed (done), "Waiting for the camera…" (session running, frames not
      arriving from `AmbientSensingSource.latestFrame()`), or no preview row at
      all (`status` never reached `.running`). Each points somewhere different.

- [ ] **[P1]** **[Needs owner]** **Confirm the outlines land on the objects, on
      device.** The preview is constrained to `AwarenessPreviewFeed.aspectRatio`
      (measured from `ARFrame.camera.imageResolution`, transposed for portrait)
      precisely so the renderer's fill matches the feed and normalized boxes map
      linearly onto it. That reasoning is sound but unverified against real
      frames — if world tracking picks a non-4:3 video format on this device,
      a mis-shaped preview would pull every box off its object. No simulator
      can check this: ARKit produces no frames there.

- [ ] **[P1]** **[Needs owner]** **Battery and thermal, re-measured with the
      preview running.** Detection now runs on the 750 ms depth cadence rather
      than the narration cadence, so outlines track the scene instead of sitting
      over where the camera used to point. The added work is one saliency pass
      plus at most a few classifier crops — expected to be small beside the
      VIO session and the full-brightness display this mode already holds on,
      but "expected" is not measured. Fold into the existing walk-test item in
      the section below rather than doing a separate walk.

- [ ] **[P2]** **[Needs owner]** **Judge the region-area floor
      (`ObjectClassificationService.minimumRegionArea`, 2% of the frame) on real
      scenes.** It exists because saliency returns slivers the classifier will
      confidently misname. Too high and a genuinely small object across the room
      goes unmentioned; too low and the app outlines noise. Synthetic test
      images cannot settle this.

- [ ] **[P2]** **Detected-object labels are still English-only.** The outline
      captions inherit the same Vision-identifier limitation already documented
      on `ObjectClassificationService` — a user running the app in Spanish or
      Vietnamese now *reads* the English noun as well as hearing it. Same root
      cause, same open question, no new work needed until that one is answered.

### Hands-free worn awareness ("walk mode") (2026-07-26, 20:00 PST)

Continuous chest-mounted awareness with AirPods: ARKit LiDAR `sceneDepth` +
Vision classification + Foundation Models, narrated through the existing
speech/haptic targets. Built and machine-verified this session — Core 65 tests
/ 11 suites, `xcodebuild build` for iOS green with zero warnings,
`scripts/lint.sh` 0 violations in 55 files.
Session log: `sessions/2026-07-26/2000-PST.md`.

Nothing below is machine-closable — every item needs the device, a human ear,
or a native speaker.

- [ ] **[P1]** **[Needs owner]** **Validate `AmbientSensingSource.floorClearanceMeters`
      (0.2 m) on a real walk.** Floor rejection no longer guesses a rectangle:
      `DepthGeometry` projects every sample onto gravity using
      `ARCamera.transform`, and `DepthStatistics` discards whatever sits within
      the clearance of the lowest surface in view. That makes it independent of
      the strap's pitch, which is why this dropped from P0 — the remaining
      number is real headroom in metres and means the same thing at any mount
      angle. Still wants a walk: too low and floor texture reads as an obstacle,
      too high and a kerb goes unmentioned. Check specifically that a kerb, a
      doorway threshold, and a box on the floor are all still reported, and that
      open floor is not.

- [ ] **[P1]** **[Needs owner]** **Battery and thermal over a real walk.**
      `ARWorldTrackingConfiguration` runs visual-inertial odometry continuously
      and the display is held awake (`isIdleTimerDisabled`). Plane detection and
      environment texturing are already off. If this proves too costly, the
      lighter path is `AVCaptureDepthDataOutput` on `.builtInLiDARDepthCamera`,
      which skips VIO entirely at the cost of more plumbing. No CI can measure
      this.

- [ ] **[P1]** **[Needs owner]** **Blind-tester pass on the narration cadence.**
      Defaults are 6 s between descriptions, 20 s before an unchanged scene is
      re-stated, 1.5 m alert distance, 750 ms depth sampling. These are guesses
      about how much speech is useful versus exhausting in the ear all day, and
      that judgement is not the developer's to make.

- [ ] **[P1]** **[Needs owner]** **VoiceOver pass on the rebuilt Awareness
      screen and the new Settings "Awareness" section.** The screen changed from
      a `VStack` to a sectioned `List` with a start/stop control, three
      conditional status rows, and two new sliders. Zero unlabelled elements is a
      hard gate and a machine cannot certify it.

- [ ] **[P2]** **[Needs owner]** **Native-speaker review of three new es/vi
      strings** in the Core String Catalog: `"something ahead"`,
      `"something about %@ ahead"`, and
      `"The nearest measured distance is further away now."` These are
      doctrine-pinned physical-world language, written without a native speaker.

- [ ] **[P2]** **Vision classifier labels are English only.** A user running the
      app in Spanish or Vietnamese hears an English noun inside a translated
      hedge. ~1,300 Vision identifiers have no reviewed translation; naming the
      object *wrongly* would be worse than naming it in the wrong language. This
      is the same open decision already logged under "Decisions & design".

- [ ] **[P3]** **Auto-resume after backgrounding.** The session currently stops
      and announces when the app leaves the screen, and the user must restart it
      by hand — awkward for someone whose phone is strapped to their chest, but
      resuming a camera session unattended is a decision worth making
      deliberately rather than by default.

- [ ] **[P2]** **Nothing checks that `app/project.yml` matches
      `app/SenseBridge.xcodeproj/project.pbxproj`.** Found 2026-07-27: the spec
      was missing `INFOPLIST_KEY_UIBackgroundModes: audio`, which had been added
      straight to the pbxproj the day before. Regenerating with XcodeGen would
      have silently dropped the background mode, and with it the spoken
      "hands-free awareness stopped" announcement — a failure a user with the
      phone on their chest cannot see. Fixed for this one setting, but the class
      of bug is open: build settings are edited in two places and only one is
      the source of truth. Options are a CI step that regenerates into a temp
      directory and diffs the build settings, or dropping XcodeGen and making
      the pbxproj authoritative. Either is a decision, not a mechanical fix.

- [ ] **[P3]** **`SceneDescriptionView` still uses canned records.**
      `FoundationModelsSceneComposer` and `ObjectClassificationService` now
      exist and are wired into hands-free awareness; pointing the "Describe"
      screen at a real capture is a small follow-up. Same for `LabelingView`.

### `docs/` accuracy overhaul + designed Pages site (2026-07-26, 05:00 PST)

Bringing every page in `docs/` factually current and publishing it as a
designed, animated GitHub Pages site with a custom Jekyll layout layer.
Markdown stays canonical — the design ships as `docs/_layouts/`,
`docs/_includes/`, `docs/_data/`, and `docs/assets/{css,js,fonts}/`, because
~40 in-repo `docs/*.md` references, GitHub's own markdown rendering, and
`tools/generate-wiki-home.mjs` all depend on those files staying where they
are. Session log: `sessions/2026-07-26/0500-PST.md`.

- [ ] **[P1]** **[Needs owner]** Nothing from this work is committed. It spans
      `docs/**` (16 rewritten pages, 4 new pages, the whole presentation
      layer), plus `docs/index.md`, `WIKI.md`, `NOTES.md`, `TODO.md`, and
      `.github/workflows/ci.yml` and `tools/docs-a11y.mjs` (the `node --check`
      regression guard and the docs accessibility gate, both of which belong
      with this change). Needs a branch off `main` (`docs/...` or
      `chore/...`), a conventional commit, and a PR so CI runs `pages.yml` and
      `wiki-sync.yml` against it. Agents never run `git`/`gh` autonomously —
      owner explicitly chose that no `git` command be run in the 2026-07-26
      session. **Use `git add docs/`, not `git add -u`:** 21 files under
      `docs/` are untracked and `-u` would silently miss every one of them.
      Copy-paste ship block is in `tmp/handoff.md`.

- [ ] **[P1]** **[Needs owner]** `docs/SECRETS.md` is **untracked** in git
      (`git status` shows `??`) while `docs/index.md` links to it — so the link
      404s on github.com today. It must be staged with this change. It also had
      no YAML front matter, which meant Jekyll copied it as a raw file instead
      of rendering it as a page.

- [ ] **[P1]** **The new `docs-a11y` CI job has never run on a GitHub runner.**
      It was verified only locally (macOS, Node 26, Puppeteer's cached Chrome).
      CI differs in three ways that could each break it on the first PR:
      `actions/jekyll-build-pages` writes to `./_site` and its exact output
      path is assumed, not verified; `npm install --no-save puppeteer` must
      download Chrome on an ubuntu runner under Node 22, not the Node 26 this
      machine runs; and the runner's headless Chrome uses a different GPU stack
      than the macOS one the `--enable-unsafe-swiftshader` fallback was
      exercised against. **Watch this job on the first PR** and treat a failure
      as the job's problem, not the site's — the site itself is verified green.

- [ ] **[P3]** **Five `impeccable` findings on `docs/assets/css/docs.css` are
      deliberate — do not "fix" them in a future audit.** Two are `font-size:
      1rem` on `body` and `li`: 1rem **is** the documented body size, written
      in `.agents/context/DESIGN.md` as `clamp(1rem, …, 1.0625rem)`, and the
      detector cannot reduce a `clamp()`, so its allowed set is only the two
      fixed steps `0.875rem`/`0.8125rem`. Shrinking body copy to satisfy the
      tool would be a real readability regression. The other three are
      `#fff`/`#000` inside `@media print`, where pure black on white is
      correct. Not suppressed via `ignore-value`, so they stay visible; this
      entry exists so the next reader knows they were considered, not missed.

- [ ] **[P3]** The hook also warns that `.agents/context/DESIGN.md` is newer
      than `.impeccable/design.json` and asks for `/impeccable document`. Left
      alone deliberately: `DESIGN.md` was already modified before this work
      started, so regenerating the sidecar would pull an unrelated in-flight
      change into this diff.

- [ ] **[P2]** **[Needs owner]** A real screen-reader pass over the rendered
      docs site — VoiceOver on Safari and NVDA on Windows — covering the
      sidebar nav, the scroll-spy table of contents, the command-palette
      search combobox, the theme control, and the copy-code buttons. Automated
      checks are not a screen-reader session, and this is an accessibility
      project: a clean build must never be presented as validation by the
      people it is for. Also needs a keyboard-only walkthrough and a
      `prefers-reduced-motion` check on a real OS toggle.

- [ ] **[P2]** The 7 links into `docs/planning/` were dead for every public
      reader — that directory is gitignored (`.gitignore:126`) **and**
      Jekyll-excluded (`docs/_config.yml`). Owner decision taken 2026-07-26:
      strip the links and inline the substance, keeping planning notes local.
      If `docs/planning/` is ever published, revisit — the inlined copies then
      become duplication rather than the only public record.

- [ ] **[P3]** **[Needs owner]** The unused `jekyll/jekyll:4` Docker image
      (2.05 GB) can be removed; this machine has ~17 GB free. Command:
      `docker image rm jekyll/jekyll:4`.

### Website motion pass — remaining candidates (2026-07-25)

Surfaced while auditing for further motion candidates. None is a defect; each
is a judgment call left for the owner rather than decided unilaterally inside a
motion pass.

- [ ] **[P3]** `aria-pressed` on the two `.read-aloud-toggle` buttons has no
      **visual** counterpart — the pressed state is carried only by the label
      text swapping and by `aria-pressed` itself. A sighted non-AT user sees a
      label change and no change in the control. Not fixed here because it is a
      visual-design decision (a filled or accent-bordered active treatment)
      rather than motion. Next step: pick the treatment, then apply it to
      `[aria-pressed="true"]` in `ReadAloud.astro`'s style block.

- [ ] **[P3]** The header scroll-progress bar could take the same
      velocity reaction as the Signal Spine pulse. **Deliberately not done:**
      two velocity-reactive elements on screen at once compete, and the spine
      is the one carrying the story. Revisit only if the spine treatment is
      ever dropped.

- [ ] **[P3]** The skip link has no transition on appear. **Deliberately not
      done:** a focus indicator should be instant, and easing one in delays
      the feedback a keyboard user is waiting on. Recorded so it is not
      "fixed" later by someone reading the gap as an oversight.

- [ ] **[P3]** `prefers-reduced-transparency` and `prefers-contrast` are not
      handled anywhere in `website/src`. Out of scope for a motion pass and not
      a WCAG 2.2 AA requirement, but the site's screen-reader-first posture
      makes them worth a look. Next step: audit `glass-slate` and the loader
      panels against `prefers-reduced-transparency: reduce`.

- [ ] **[P3]** `website/src/styles/global/_base.scss` (the `h2` block) and
      `.agents/skills/capitalization/SKILL.md` still cite **"The One Display
      Face Rule"** as if in force. `.agents/context/DESIGN.md` §0 voided it on
      2026-07-18. Not corrected here because the right wording depends on the
      owner's answer to the flagged question in the won't-fix entry below — if
      the rule is meant to be back in force, §0 is what needs amending instead.

- [ ] **[P3]** `website/src/styles/abstracts/_motion.scss`'s file header still
      says "this phase ships zero animation — Phase 5 (motion layer) is the
      first real consumer." Phase 5 shipped long ago and the file now has a
      dozen consumers. Safe one-line comment fix, left out only to keep the
      motion diff reviewable.

### Dev-environment fixes: SweetPad timeout + WakaTime + shell error (2026-07-25, 16:00 PST)

> **Reconstructed 2026-07-25 (late).** The original of this section was lost to
> an agent error — `git checkout HEAD -- TODO.md` was run against a file with
> ~750 lines of uncommitted work in it, and only an older revision was
> recoverable from `.git/lost-found`. This has been rebuilt from
> [`sessions/2026-07-25/1600-PST.md`](sessions/2026-07-25/1600-PST.md), which
> covers the same work. **Per-client WakaTime setup steps that were listed here
> may be missing** — `docs/TOOLING.md`'s WakaTime row is the canonical
> reference; re-derive the checklist from there if something looks absent.

WakaTime is already configured for Claude Code (`PostToolUse` hook in
`~/.claude/settings.json`) and VS Code (extension). The API key lives once in
`~/.wakatime.cfg` and every client below reads it from there — **never paste the
key into any client config.** `wakatime-cli` is at `~/.wakatime/wakatime-cli`.

- [ ] **[P3]** **[Needs owner]** Reload the VS Code window so
      `"sweetpad.shellEnv.timeout": 15000` (added to
      `~/Library/Application Support/Code/User/settings.json`) takes effect.
      The 5000ms default was timing out intermittently: `zsh -i` measures
      ~1.3s locally but spikes past 5s.

- [ ] **[P3]** **[Needs owner]** Restart the Claude Code session so the
      WakaTime `PostToolUse` hook loads. A test heartbeat was accepted (no
      offline-queue file written), so the wiring itself is verified.

- [ ] **[P3]** `~/.openclaw/completions/openclaw.zsh:3874` calls `compdef`
      before `compinit`, printing `command not found: compdef` on every shell
      exit. Not fixed — it is outside this repo and harmless, but noisy.

### Composio: connect the rest of the project's tool surface (2026-07-25, 16:00 PST)

Composio CLI is installed (`~/.composio/composio`, v0.2.32 — **not on `$PATH`,
always use the absolute path or add `~/.composio` to `PATH` once**) and logged
in as `kevinle3212@gmail.com`. The `composio-cli` skill auto-installed itself
and documents the general `search` / `execute` / `link` workflow — this entry
only covers what's specific to *this* project: which of SenseBridge's actual
external services have a Composio toolkit, which don't, and the exact linking
steps for each. Verified 2026-07-25 by running `composio search` against every
service this repo's docs actually reference (`docs/TOOLING.md` MCP inventory,
`docs/SECRETS.md` §§1–3) rather than guessing toolkit names.

**Already connected:** `github` — confirmed via
`composio execute GITHUB_LIST_NOTIFICATIONS_FOR_THE_AUTHENTICATED_USER -d '{}'`
(50 unread notifications returned, mostly CI-failure activity). No relinking
needed; `composio whoami` after any future session should still show
`kevinle3212@gmail.com` with no further login step required unless credentials
are explicitly cleared.

- [ ] **[P2]** Link `vercel` (hosts `website/`, per
      `docs/TOOLING.md`/the Vercel production-hosting TODO section below).
      Composio's toolkit is real and well-covered: primary tools
      `VERCEL_GET_PROJECTS`, `VERCEL_GET_DEPLOYMENTS`, `VERCEL_GET_DEPLOYMENT`,
      `VERCEL_GET_DEPLOYMENT_LOGS2`, `VERCEL_ADD_ENVIRONMENT_VARIABLE`,
      `VERCEL_EDIT_PROJECT_ENV`, `VERCEL_CREATE_NEW_DEPLOYMENT`,
      `VERCEL_FILTER_PROJECT_ENVS`.
      Steps: `composio link vercel --no-browser` (run in background so it
      doesn't block; it prints a `dashboard.composio.dev` URL and then waits
      up to its own timeout for the browser step) → open the URL, complete
      Vercel OAuth → confirm with `composio execute VERCEL_GET_PROJECTS -d '{}'`
      and check the `sensebridge` project appears. Useful once connected: read
      deployment status/logs without the dashboard, and — carefully — automate
      the still-open `sensebridge.vercel.app` Production-domain alias fix
      (TODO below, "CI/CD security audit" section). **Domain-alias coverage
      confirmed present** on re-search 2026-07-26 (the 2026-07-25 entry had
      left this open): `VERCEL_ADD_PROJECT_DOMAIN`, `VERCEL_GET_DOMAIN_CONFIG`,
      `VERCEL_UPDATE_PROJECT_DOMAIN`, `VERCEL_VERIFY_PROJECT_DOMAIN`,
      `VERCEL_GET_PROJECT_DOMAINS`, `VERCEL_MOVE_PROJECT_DOMAIN`,
      `VERCEL_LIST_DOMAINS`. This makes `vercel` the highest-value unlinked
      toolkit for this repo — it is the only one that unblocks work currently
      blocked on the dashboard.
      Edge case: `VERCEL_CREATE_NEW_DEPLOYMENT` can 402 on plan/quota limits
      even when reads still work — don't treat a failed deploy call as proof
      the connection is broken.

- [ ] **[P3]** Link `elevenlabs` (narration audio, `ELEVENLABS_API_KEY` in
      `website/.env`, only used by `npm run generate:audio` per
      `docs/SECRETS.md` §3). Primary tool `ELEVENLABS_TEXT_TO_SPEECH`; related
      `ELEVENLABS_GET_VOICES`, `ELEVENLABS_GET_MODELS`,
      `ELEVENLABS_GET_VOICE_SETTINGS`, `ELEVENLABS_GET_USAGE_CHARACTER_STATS`,
      `ELEVENLABS_GET_USER_SUBSCRIPTION_INFO`.
      Steps: `composio link elevenlabs --no-browser` → authorize → smoke-test
      with the read-only `ELEVENLABS_GET_USAGE_CHARACTER_STATS` (never burn
      quota on a connectivity check).
      Edge case: this key already exists locally in `website/.env` and drives
      `npm run generate:audio` directly — linking Composio's `elevenlabs`
      toolkit adds a *second*, independent credential (Composio manages its
      own OAuth/API-key linkage, it does not read `website/.env`). Only worth
      doing if there's a concrete reason to call ElevenLabs from an agent
      session instead of the existing npm script; otherwise this is low
      value and can stay unlinked indefinitely.

- [ ] **[P3]** Do **not** link `railway` expecting parity with the existing
      `RAILWAY_TOKEN` / `railway:*` npm-script workflow. Composio's `railway`
      toolkit is thin. Re-searched 2026-07-26: coverage **has grown** past the
      single `RAILWAY_UPDATE_PROJECT` recorded on 2026-07-25 — it now also
      exposes `RAILWAY_GET_DEPLOYMENT_LOGS`, `RAILWAY_GET_ENVIRONMENT`, and
      `RAILWAY_UPDATE_SERVICE_INSTANCE`. Still **no deploy-trigger tool**, so
      the `RAILWAY_TOKEN` / `railway:*` npm scripts stay the deploy path
      regardless; the only new reason to link is reading deployment logs
      without the dashboard. Low value while deploys still need the CLI.

- [ ] **[P3]** **Deferred, don't link yet:** `stripe` and `resend` toolkits
      both exist in Composio (`STRIPE_RETRIEVE_BALANCE`/`STRIPE_LIST_CHARGES`/
      `STRIPE_LIST_PAYMENT_INTENTS`; `RESEND_SEND_EMAIL`/
      `RESEND_SEND_BATCH_EMAILS`), but per the "Vercel production hosting +
      Stripe/Resend hardening" TODO section below, the product decided *not*
      to build a Stripe/Resend integration yet (pre-launch, "nothing is being
      sold" doctrine) and the exposed Stripe test key still needs rotating
      first. Only link either toolkit after that product decision changes —
      linking Stripe now would just be live access to an already-flagged
      leaked test key with nothing to do with it.

- [ ] **[P3]** No Composio toolkit exists for **GitGuardian** (confirmed again
      2026-07-26 — `composio search "gitguardian secret scanning"` still
      returns only unrelated `GITHUB_*` secret/code-scanning-alert tools).
      Keep using the local `ggshield`
      CLI + the `security.yml` CI job; re-search only if this changes.
      **Docker Hub** has a real toolkit (`docker_hub` — repos, teams, orgs,
      webhooks) but this project doesn't publish images to Docker Hub (local
      `docker/Dockerfile` build only) — not applicable unless that changes.

**Future tool surface — what this project will need, and how to set it up
(added 2026-07-26):**

Everything above is a service SenseBridge uses *today*. These are the ones the
roadmap implies it will need *later*, each verified against Composio's live
catalog on 2026-07-26 rather than assumed. Two of the four have no Composio
path at all — record them here so a future session stops looking.

- [ ] **[P2]** **App Store Connect / TestFlight** — needed at Phase 2 public
      beta ([`docs/ROADMAP.md`](docs/ROADMAP.md)), the project's largest future
      external-service surface. **No Composio toolkit exists** (searched
      2026-07-26: `"app store connect testflight ios build"` returns only
      `codemagic`, an unrelated mobile-CI vendor; `"apple developer program
      membership"` falls through to generic web search — that fall-through is
      itself the proof no Apple toolkit exists). Do not hold a distribution
      task waiting on one. The real setup path, in order, none of it Composio:
      1. Enroll in the Apple Developer Program — the one unavoidable cost, and
         check the fee-waiver options first
         ([`docs/DISTRIBUTION.md`](docs/DISTRIBUTION.md) §"The one unavoidable
         cost").
      2. In App Store Connect → Users and Access → Integrations, create an
         **App Store Connect API key** (Issuer ID + Key ID + `.p8` private
         key). The `.p8` downloads exactly once and cannot be re-downloaded.
      3. Store all three as GitHub Actions repository secrets, never in the
         repo — same rule as every other entry in
         [`docs/SECRETS.md`](docs/SECRETS.md), and add them there when created.
      4. Upload from CI with `xcrun altool --upload-app` (no new dependency) or
         `fastlane pilot` (a real dependency to justify first). Prefer
         `altool` — it ships with Xcode.
      5. Only then add the TestFlight upload workflow.
         [`docs/DISTRIBUTION.md`](docs/DISTRIBUTION.md) §"Signing and CI" is
         explicit that adding one before there's a Developer Program account is
         premature — respect that ordering.

- [ ] **[P3]** **Discord** — [`docs/DISTRIBUTION.md`](docs/DISTRIBUTION.md)
      §"Recruiting real testers" names accessibility Discord communities as a
      likely blind-tester channel. Toolkits exist (`discord` for user-scoped
      reads, `discordbot` for bot-scoped writes: `DISCORDBOT_CREATE_MESSAGE`,
      `DISCORDBOT_LIST_GUILD_CHANNELS`, `DISCORD_LIST_MY_GUILDS`,
      `DISCORDBOT_EXECUTE_WEBHOOK`, `DISCORDBOT_TEST_AUTH`).
      Setup if ever wanted: `~/.composio/composio link discord --no-browser` →
      owner completes OAuth → smoke-test with the read-only
      `DISCORD_LIST_MY_GUILDS`.
      **Guardrail, and the reason this is P3 and not P2:** recruiting blind
      testers is human relationship work in communities that owe this project
      nothing. Automated posting into a disability community reads as spam and
      would burn the exact channel it targets — an agent may draft outreach
      copy for owner review, and must never post it. Any copy still clears the
      honesty-over-hype and safety-framing guardrails.

- [ ] **[P3]** **Model licensing** — no HuggingFace toolkit exists (searched
      2026-07-26; the query falls back to `github` license tools). For any
      GitHub-hosted candidate model, the **already-connected** `github`
      toolkit covers the
      [model-license-audit](.agents/skills/model-license-audit/SKILL.md) gate
      today: `GITHUB_GET_THE_LICENSE_FOR_A_REPOSITORY`,
      `GITHUB_LIST_LICENSES_GRAPH_QL`, `GITHUB_GET_RAW_REPOSITORY_CONTENT` to
      read a `LICENSE` verbatim. Relevant when the SmolVLM-vs-Apple fork in
      [`docs/ROADMAP.md`](docs/ROADMAP.md) §"Open questions" gets resolved.
      A machine-read license string is **evidence, not clearance** — AGPL and
      `apple-amlr` remain hard blockers decided by the skill, not by a tool
      call, and HuggingFace-hosted models still need a manual license read.

- [ ] **[P3]** **Do not link, on doctrine** — record these so a future session
      doesn't "helpfully" connect one:
      - **Analytics and product telemetry** (PostHog, Amplitude, and every
        sibling). Toolkits exist; nothing in this project has anything to send
        them, and linking one creates a live egress path to a product that must
        not have one. **Sentry is no longer in this list** — the owner reversed
        that doctrine on 2026-07-31 and crash reporting now ships on `website/`
        and `app/`, opt-in and off by default. The reversal covers crash and
        error reporting only; it is not a general licence to add telemetry, and
        product analytics stays prohibited. See
        [`docs/PRIVACY.md`](docs/PRIVACY.md).
      - **`composio_search`** (`COMPOSIO_SEARCH_WEB`,
        `COMPOSIO_SEARCH_FETCH_URL_CONTENT`, `COMPOSIO_SEARCH_NEWS`) —
        Composio's own built-in web-search toolkit, which surfaces
        unprompted in search results. The global standard routes **all** agent
        web browsing through gstack `/browse`; this is a second, undocumented
        browsing path and is not to be used.
      - **`stripe` / `resend`** — already covered above; still gated on a
        product decision that has not changed.

**Edge cases to reason about whenever executing any of the above:**

- Every `link` needs a human to click through OAuth in a real browser in the
  moment — same pattern as today's GitHub login: run the link command
  backgrounded with `--no-browser`, hand the printed URL to the user, then
  read the background output once it completes. It cannot happen unattended.
- Treat anything a Composio tool call returns about an account (tokens, keys,
  email, balances) as sensitive — never echo it verbatim into a committed
  file, and never write a Composio-obtained credential into `docs/SECRETS.md`
  or any tracked file.
- Large tool outputs auto-spill to a file (`storedInFile: true` +
  `outputFilePath` in the JSON envelope) once they're big enough — today's
  50-notification GitHub call was ~80K tokens and got redirected to disk.
  Parse the file with `python3`/`jq` for just the fields needed; don't cat the
  whole thing into context.
- Before assuming a toolkit is connected or absent, check with
  `composio execute <slug> -d '{}'` or `composio link <toolkit> --list` rather
  than trusting this entry's snapshot — Composio's catalog and this project's
  connected accounts both change over time.

### Secrets inventory + React Doctor zero-findings gate (2026-07-25, 14:00 PST)

Session log: [`1400-PST.md`](sessions/2026-07-25/1400-PST.md). Added
[`docs/SECRETS.md`](docs/SECRETS.md) (every CI/deploy/local credential), took
React Doctor to zero findings, and raised its CI gate to `blocking: warning`.
A follow-up pass fixed the font-license defect below plus a cluster of
docker/docs claims that had drifted from reality.

- [ ] **[P3]** Re-test `website/doctor.config.jsonc`'s suppressions on each
      `react-doctor` upgrade and delete any entry upstream has fixed. Both
      entries exist only because React Doctor's dead-code pass does not follow
      imports out of `src/layouts/**` (verified 2026-07-25 — see the file's
      comments for the experiment that isolated it), not because the code is
      dead. Currently pinned at `react-doctor@0.8.1`.

- [ ] **[P3]** React is installed in `website/` but **nothing uses it** — zero
      `.tsx`/`.jsx` files exist. React Doctor therefore only ever exercises its
      `deslop` maintainability rules, and React Scan has nothing to profile.
      Decide whether to keep `@astrojs/react` + `react` + `react-dom` +
      `react-scan` as ready-for-an-island infrastructure or drop them until an
      island actually lands.
      **Resolved 2026-07-25 by integrating, not removing** — owner chose to put
      React to work. Added `website/src/components/StructuredData.tsx`, the
      site's only React component: it emits schema.org JSON-LD (`WebSite` +
      `Organization` + `WebPage`), a surface that did not exist before, so it
      overlaps nothing. Server-rendered with **no `client:*` directive**, so
      Astro prerenders it and it ships zero JavaScript — verified against the
      built output, where all 195 pages carry valid JSON-LD across all three
      locales (`en-US`/`es-ES`/`vi-VN`) and **zero** pages reference React's
      client runtime.
      Doctrine: only `WebSite`/`Organization`/`WebPage` are emitted.
      `SoftwareApplication`, `offers`, `downloadUrl`, and `aggregateRating` are
      deliberately excluded — any of them would let a search engine advertise a
      download that does not exist, which is the honesty rule the site's copy
      is held to. Do not add them before the app ships.
      Two real defects were caught while building it, both fixed rather than
      suppressed: ESLint's `security/detect-object-injection` (raised to
      `error` repo-wide) plus `noUncheckedIndexedAccess` rejected the
      `Record` lookups, so both maps became `Map` with explicit fallbacks; and
      React Doctor's `Unescaped JSON in HTML or script sink` fired on the
      `dangerouslySetInnerHTML` form, so the payload is now passed as a text
      child instead — React 19 renders `<script>` children verbatim, confirmed
      against `dist/index.html`. The raw-HTML sink is gone from the codebase.

- [ ] **[P3]** `dist/_astro/client.*.js` — the ~187kB React DOM client runtime
      — is emitted into the build output even though **no page references it**
      (confirmed: 0 of 195). It is dead weight in the deployed artifact, not
      shipped to visitors. Pre-existing and **not** caused by
      `StructuredData.tsx`: a baseline build with that component removed still
      emits the chunk, so it comes from the `@astrojs/react` integration
      itself. Worth an `astro.config.mjs` / Vite look to stop emitting it while
      no island hydrates; harmless to visitors either way.

### CI/CD security audit — CodeQL fix, dependency review, branch ruleset, Vercel alias gap (2026-07-24, late session)

Full session log: [`sessions/2026-07-24/2200-PST.md`](sessions/2026-07-24/2200-PST.md).
Fixed CodeQL's "1 configuration not found" (dead skip-conditional, now
removed) and its 20+ minute PR wait (Swift analysis moved to push:main +
weekly + manual dispatch only; JS/TS stays on every PR); confirmed OSV was
never flaky, just correctly catching a since-patched `brace-expansion` CVE;
added `actions/dependency-review-action`; created a `main-required-checks`
branch ruleset (owner-approved); attempted the two secret-scanning
sub-toggles (API silently refuses, personal-account plan gate). Also chased a
Vercel auto-deploy question — auto-deploy already works, the real gap was a
stale `sensebridge.vercel.app` alias.

- [ ] **[P1]** **[Needs owner]** Attach `sensebridge.vercel.app` to the
      Vercel project's Production domains: `https://vercel.com/trustledger/sensebridge/settings/domains`
      → add the domain → assign to Production. It currently resolves but is
      stale (last built 2026-07-21, not in the current production
      deployment's alias list) — a leftover manual assignment that
      auto-alias-on-deploy no longer touches. One-time; after that it
      updates automatically on every future push same as the project's other
      three domains already do.

- [ ] **[P2]** **[Needs owner]** Try `secret_scanning_non_provider_patterns`
      and `secret_scanning_validity_checks` via the Settings UI directly
      (`https://github.com/kevinle3212/sensebridge/settings/security_analysis`)
      — `gh api PATCH repos/.../sensebridge` returns 200 with admin
      permission confirmed present, but both fields silently stay `disabled`
      in the response. Looks like a plan-level gate the API won't surface.

- [ ] **[P2]** **[Needs owner]** Decide whether to close the gap between the
      `main-required-checks` ruleset created this session (id `19721689`:
      deletion + force-push protection + 7 required status checks) and the
      fuller "Protect main" spec drafted 2026-07-17 (below, "Owner actions
      pending" section) — that spec also wanted a `pull_request` rule
      (require-PR-before-merge, squash-only merge methods, conversation
      resolution), `required_linear_history`, and 3 more checks (`Docs link
      check`, `Sensitive file scan`, `Semgrep`). Today's ruleset is narrower
      by design (avoided checks that would deadlock PRs — `Actionlint` is
      path-filtered, `CodeQL (Swift)` no longer runs on `pull_request`) but
      wasn't reconciled against the older, more complete plan.

### Reading screen had no audio output (2026-07-23)

Owner ran the app on-device (see session above), OCR parsed text but no
speech played on Capture. Full write-up in the addendum to
`sessions/2026-07-23/2200-PST.md`.

- [ ] **[P2]** Owner also flagged OCR recognition quality as "decent, could
      be better" but hasn't given specifics yet — get concrete examples
      (garbled words, reading order, missed lines) on next device test,
      then look at
      `app/Packages/SenseBridgeCore/Sources/SenseBridgeCore/Perception/OCRService.swift`
      (currently a plain `VNRecognizeTextRequest`, no line/paragraph
      grouping or confidence filtering).

### Basic screen functionality wired to mock data (2026-07-23)

Owner couldn't open/simulate `app/` at all and asked for some basic
functionality. Build/install/launch pipeline turned out to work fine via
CLI (`xcodebuild build` → `simctl install` → `simctl launch`, confirmed with
a screenshot) — the real gap found was all 5 feature screens' capture
buttons being empty no-op closures. Wired `ReadingView`, `LabelingView`,
`SceneDescriptionView`, `ObstacleAwarenessView`, and `SoundAlertsView` to
the existing, unit-tested `SenseBridgeCore` Reasoning/Output layer
(`Phrasing`, `LabelListSceneComposer`, `AwarenessEngine`,
`SpeechRenderTarget`) using canned `PerceptionRecord` data in place of the
not-yet-built camera/mic/depth capture layer. Full write-up in
`sessions/2026-07-23/2100-PST.md`.

- [ ] **[P1]** **[Needs owner]** If the simulator still won't open in the
      Xcode GUI (CLI build/install/launch all succeeded cleanly this
      session), check whether the last-selected run destination is the
      physical device rather than a simulator — the free-account 7-day
      sideload signing window may have expired (see
      `sessions/2026-07-23/2100-PST.md` for the CLI evidence ruling out a
      project-level break).

- [ ] **[P2]** Confirm on an actual simulator tap-through that each of the 5
      screens speaks/shows its canned sentence — this session verified via
      `xcodebuild build`/`test` and `swift test` only; the live on-tap
      behavior was never visually confirmed (computer-use hit an unrelated
      macOS notification-layer click-blocking issue mid-session).

### Read/OCR wiring follow-ups (2026-07-23)

- [ ] **[P2]** **[Needs owner]** Confirm the Read flow on a physical device:
      launch the app, grant camera permission, aim at real printed text, tap
      Capture, and confirm the recognized text is spoken correctly. This is
      the first real (non-simulator) exercise of `CameraSource`/`OCRService`.

- [ ] **[P3]** Extend the same real-capture pattern to the remaining four
      modes (`Identify`/`LabelingView`, `Describe`/`SceneDescriptionView`,
      `Awareness`/`ObstacleAwarenessView`, `Sounds`/`SoundAlertsView`) —
      Vision detect, ARKit depth, and Sound Analysis respectively, per
      `docs/ARCHITECTURE.md`'s "Perception Layer".

- [ ] **[P3]** `ReadingView`'s camera-permission-denied message is a plain
      string with no deep link to Settings — consider
      `UIApplication.openSettingsURLString` once a second permission-gated
      feature makes the pattern worth extracting.

### Git/CI cleanup, history purge, impeccable CodeQL remediation (2026-07-23)

Full cleanup pass: merged the GitHub-platform-setup PR, collapsed every branch
down to `main` (Dependabot auto-deletes head branches on merge, so the 4 stale
feature branches and the working branch all disappeared on their own), ran
`git filter-repo` to purge `docs/planning/` from history (including the
initial commit) per the go-ahead already recorded in `.gitignore`'s own
comment, fixed the first-ever `Deploy Docs to GitHub Pages` run (v3 of
`upload-pages-artifact` calls an unpinned nested action, which this repo's
SHA-pinning policy blocks), and triaged all 53 CodeQL findings the merge
surfaced in the `impeccable` skill (a locally-authored dev tool, not the
SenseBridge app/website) — see PR #28 for the fix commit. Along the way,
converted `impeccable/scripts/` (4 of 5 mirror copies) and `react-doctor` (3
of 4 copies) from independent files to symlinks, since they were byte-for-byte
identical and drifting was exactly how one CodeQL-scanned copy (`.github`'s)
ended up different from the one being hand-edited (`.claude`'s).

- [ ] **[P2]** **[Needs owner]** Confirm Claude Code, Cursor, Gemini CLI, and
      GitHub Copilot's skill loaders all resolve the new `impeccable`/
      `react-doctor` symlinks correctly at runtime (not just `git`/the
      filesystem, which already prove the symlinks materialize and read
      correctly) — invoke each tool's version of the skill once and confirm
      it behaves identically to before the symlink conversion.

- [ ] **[P3]** The single→double quote conversion (`eslint --rule quotes`)
      only covers the 24 files touched by the CodeQL fix, not the rest of
      `impeccable/scripts/`'s real files (now only one copy to edit, at
      `.github/skills/impeccable/scripts/`, since the other 4 are symlinks) —
      extend it for full-skill consistency whenever there's a reason to touch
      the rest of the skill anyway.

- [ ] **[P3]** `core.symlinks` is unset in both local and global git config
      (defaults to `true` on this filesystem, proven by the symlinks above
      materializing and resolving correctly) — no action needed on this
      machine, but flag it if this repo is ever cloned on Windows: that
      machine needs `git config core.symlinks true` (and Developer
      Mode/admin rights) for these symlinks to check out as real symlinks
      rather than placeholder text files.

### actionlint + commitlint setup (2026-07-23)

Full session log: [`sessions/2026-07-23/1400-PST.md`](sessions/2026-07-23/1400-PST.md).
Requested to keep manual (non-agent) commits consistent with the existing
conventional-commit convention, plus lint `.github/workflows/*` with
actionlint. Surveyed the existing posture first: `.githooks/commit-msg`
already enforces conventional commits via a dependency-free bash regex
(deliberately built without a Node/commitlint dependency); `pre-commit`/
`pre-push` follow a consistent `command -v <tool>` graceful-degradation
pattern; no root `package.json` exists (only `website/` is a Node project);
all GitHub Actions are pinned to full commit SHAs as of `159bca1`. Dispatched
an Opus planning pass with that context before implementing.

- [ ] **[Needs owner]** Mark `commitlint` and `actionlint` as required status
      checks in branch protection once this branch merges and both jobs have
      run at least once — a CI job alone is advisory (red X, still
      mergeable) until a ruleset requires it. This is the honest limit of
      "strict": `--no-verify` always bypasses the local hook, so branch
      protection is what actually makes it inescapable.

### GitHub platform hardening — Actions policies, tag rules, branch rulesets (2026-07-21)

Audited live via `gh api` (read-only, no changes made). `main` has **zero
branch protection** (`GET .../branches/main/protection` → 404 "Branch not
protected"), **zero rulesets exist** (`GET .../rulesets` → `[]`), and no tags
have been created yet (`git tag -l` empty). Actions is set to
`allowed_actions: "all"`, `sha_pinning_required: true`; default
`GITHUB_TOKEN` permissions are already `read` repo-wide and every workflow in
`.github/workflows/` already declares its own least-privilege `permissions:`
block — that part needs no change. The repo allows all three merge
strategies (merge commit, squash, rebase) with `delete_branch_on_merge:
true`. All items below are `gh`/web-UI actions this session doesn't have
standing permission to run.

- [ ] **[P2]** **[Needs owner]** Set merge strategy to squash-only: Settings
      → General → Pull Requests → uncheck "Allow merge commits" and "Allow
      rebase merging," keep "Allow squash merging." Matches the clean-history
      instruction in `CLAUDE.md` §15 and is required for the ruleset's
      "require linear history" rule above to actually hold.

- [ ] **[P2]** **[Needs owner]** Narrow Actions permissions from "Allow all
      actions and reusable workflows" to "Allow ... and select non-GitHub
      actions and reusable workflows" (or at minimum "Allow actions created
      by GitHub" + verified creators): Settings → Actions → General →
      Actions permissions. The repo is public and at least one workflow
      already uses a secret (`GITGUARDIAN_API_KEY`; `RAILWAY_TOKEN` is
      pending per the item above) — an unpinned third-party action from an
      unreviewed source is a meaningfully bigger risk here than on a private
      repo. `sha_pinning_required` is already on, which helps but doesn't
      substitute for an allowlist.

- [ ] **[P2]** **[Needs owner]** Require approval for first-time contributors
      on fork PR workflow runs: Settings → Actions → General → "Fork pull
      request workflows from outside collaborators" → "Require approval for
      first-time contributors." Not visible via the REST API for
      personal-account repos (confirmed 404 on the
      fork-pr-workflows-approval endpoint this session) — UI-only setting.
      Stops an untrusted fork PR from running workflows with repo secrets
      before a human looks at the diff.

- [ ] **[P3]** **[Needs owner]** Create a tag protection ruleset once a
      release/tagging scheme is decided — the repo has zero tags today.
      Settings → Rules → Rulesets → New tag ruleset, target pattern `v*` (or
      whatever scheme is chosen), rules: restrict deletions, restrict
      updates (no re-pointing a tag after it's cut). Low priority until
      there's an actual release to protect.

- [ ] **[P3]** **[Needs owner]** Consider adding "Require signed commits" to
      the `main` ruleset once local commit signing is set up. Checked this
      session: no commit in this repo's history is GPG/SSH-signed (`git log
      --show-signature` empty, no `commit.gpgsign`/`user.signingkey`
      configured locally) — turning this on today would immediately block
      the owner's own merges.

### README badges, monthly log archive skill, Railway preview env, Copilot MCP (2026-07-21)

Full session log: [`sessions/2026-07-21/1600-PST.md`](sessions/2026-07-21/1600-PST.md).
Added Actions badges for every actively-triggered workflow to `README.md`
(skipped the two intentionally-disabled Claude workflows — a badge would just
show permanent "no status"). Added `tools/condense-monthly-logs.mjs` +
`.agents/skills/monthly-log-archive/SKILL.md`: condenses `sessions/` into one
file per month (gitignored, safe to merge-and-delete) and builds an
`audits/<month>/INDEX.md` for that month's append-only audit reports
(originals never touched). Created a Railway `preview` environment since none
existed — `https://sensebridge-preview.up.railway.app`, linked in `README.md`
and documented in `docker/README.md`; now auto-deploys via
[`.github/workflows/railway-preview-deploy.yml`](.github/workflows/railway-preview-deploy.yml)
on push to any branch except `main` (added after this section was first
written — see the follow-up below for the one remaining setup step). Gave the
Copilot GitHub MCP `mcpServers`
JSON inline in chat (not committed — it's a Settings-field config, not a
repo file); it can't do anything until Copilot coding agent is enabled.

- [ ] **[Needs owner]** Wire up the Copilot GitHub MCP server. Blocked on
      enabling Copilot coding agent first (Settings → Copilot → Coding agent
      → enable — needs a Copilot license tier that includes it; see the item
      below). Once that's on:
      1. **Generate the token.** GitHub → your avatar → Settings → Developer
         settings → Personal access tokens → Fine-grained tokens → "Generate
         new token." Set:
         - Resource owner: `kevinle3212`.
         - Repository access: "Only select repositories" → `sensebridge`.
         - Repository permissions: `Contents` → Read and write, `Issues` →
           Read and write, `Pull requests` → Read and write, `Metadata` →
           Read-only (forced default). Widen later only if the agent's MCP
           calls actually need more — start minimal.
         - Expiration: pick something you're comfortable rotating on (this
           token cannot be scoped down further later, only regenerated).
         - Generate, then copy the `github_pat_...` value immediately — GitHub
           only shows it once.
      2. **Store it as a Copilot secret**, not a repo/Actions secret. Repo →
         Settings → Copilot → Coding agent → "Secrets" → add one named
         exactly `COPILOT_MCP_GITHUB_PERSONAL_ACCESS_TOKEN` (the `COPILOT_MCP_`
         prefix is required for Copilot's coding agent to see it), value = the
         token from step 1.
      3. **Paste this into the same page's "MCP configuration" field**
         (copy-paste ready, no edits needed — the `env` value below is a
         reference to the secret name from step 2, not the token itself):

         ```json
         {
           "mcpServers": {
             "github": {
               "type": "local",
               "command": "docker",
               "args": [
                 "run",
                 "-i",
                 "--rm",
                 "-e",
                 "GITHUB_PERSONAL_ACCESS_TOKEN",
                 "ghcr.io/github/github-mcp-server"
               ],
               "env": {
                 "GITHUB_PERSONAL_ACCESS_TOKEN": "COPILOT_MCP_GITHUB_PERSONAL_ACCESS_TOKEN"
               },
               "tools": ["*"]
             }
           }
         }
         ```

      4. Save. Copilot's coding agent runner pulls
         `ghcr.io/github/github-mcp-server` itself on its next run — nothing
         else to install. Rotate the PAT before its expiration by repeating
         steps 1–2 with a new token value; the JSON in step 3 never needs to
         change.

- [ ] **[Needs owner]** Create the `RAILWAY_TOKEN` repository secret so
      `railway-preview-deploy.yml` can actually deploy (it fails closed
      without one):
      1. Railway dashboard → the `sensebridge` project → Settings → Tokens →
         "Create Token." Scope it to the `preview` environment if the
         dashboard offers a per-environment option — this token should never
         be able to touch `production`. This is a **project token**, not your
         personal Railway login; do not reuse the CLI session already
         authenticated on this machine for CI.
      2. Copy the generated token value immediately (shown once).
      3. GitHub repo → Settings → Secrets and variables → Actions → "New
         repository secret" → name it exactly `RAILWAY_TOKEN`, paste the
         value.
      4. Push any branch other than `main` touching `docker/**`, `website/**`,
         or `railway.toml` to confirm the workflow deploys successfully —
         watch the Actions tab for the "Railway preview deploy" run.
      Until this secret exists, `railway up --service sensebridge
      --environment preview --ci` (run locally, already authenticated) is the
      fallback way to update the preview site. **Lower urgency than it looks**:
      confirmed via `gh api repos/.../deployments` this session that Railway's
      own GitHub App already auto-deploys both `production` and `preview` on
      every push independent of this workflow (both show `success` there) —
      the missing token only breaks this one *additional* CLI-based deploy
      path, not preview deploys in general.

- [ ] **[Needs owner]** Decide whether `monthly-log-archive` needs a
      guaranteed trigger (`SessionStart` hook or a monthly `schedule` cron)
      instead of relying on a session starting on the 1st — not added without
      sign-off, since both touch shared harness config.

### GitHub platform audit + Copilot coding agent + website URL fix (2026-07-21)

Full session log: [`sessions/2026-07-21/1600-PST.md`](sessions/2026-07-21/1600-PST.md).
Audited Wiki/Pages/Models/Dependabot/Code Scanning/Secret Scanning/Security
Policy/Advisories against the live repo via `gh api` (explicit one-turn
permission granted): secret scanning, push protection, and Dependabot
security updates are all enabled; Pages is already set to build via GitHub
Actions. `pages.yml` and `wiki-sync.yml` 404 on their workflow-runs endpoint
because they — along with most of this branch's GitHub-platform setup —
haven't merged to `main` yet (`chore/github-platform-setup` is 12 commits
ahead, 0 behind). Fixed `README.md`'s "Website" link, which duplicated the
Docs link instead of pointing at the live marketing site.

- [ ] **[Needs owner]** Enable Copilot coding agent (Settings → Copilot →
      Coding agent) once a Copilot license tier that includes it is
      confirmed. No REST/CLI/MCP endpoint exists to toggle this remotely —
      confirmed by an empty `assignees` list (no Copilot bot assignable) and
      a 404 on the personal-account Copilot-seat endpoint.

- [ ] **[Needs owner]** Checking GitHub Projects (v2) board status requires
      `gh auth refresh -s read:project` first — not run this session, since
      it changes the stored CLI token's scopes and wasn't part of the
      granted "run gh api commands" permission.

### Vercel GitHub auto-deploy + website SEO/accessibility (2026-07-21)

Full session log: [`sessions/2026-07-21/1200-PST.md`](sessions/2026-07-21/1200-PST.md).
Reverses the `0000-PST.md` decision to leave Vercel's Git integration
disconnected (to avoid racing Railway) — owner confirmed in-session that
dual auto-deploy is now intentional. SEO: added `astro.config.mjs`'s `site`,
`@astrojs/sitemap`, `public/robots.txt`, and canonical/OG/Twitter meta to
`BaseLayout.astro` — verified via `npm run build`. Accessibility: audited,
found already clean (zero `<img>` tags anywhere, every decorative SVG/canvas
already `aria-hidden`, icon-only controls already labeled) — no code change
needed. Root Directory on the Vercel project was `.` (would have broken any
Git-connected build against this monorepo) — fixed to `website` via the
Vercel API.

- [ ] **[P2]** **[Needs owner]** `https://sensebridge.vercel.app` resolves
      but is stale (last built 2026-07-21) — **not** in the current
      production deployment's alias list (`sensebridge-website.vercel.app`,
      `sensebridge-trustledger.vercel.app`, and the `-git-main-` variant are;
      the short name isn't). Attach it in
      `https://vercel.com/trustledger/sensebridge/settings/domains` →
      assign to Production. One-time; auto-updates on every future push
      after that, same as the other three domains already do. (Re-scoped
      2026-07-25 from the original "confirm it resolves" framing — it does
      resolve, just not to the current build.)

- [ ] **[P3]** **[Needs owner]** Generate and wire a real `og:image`/
      `twitter:image` (1200×630 PNG) once a social-preview asset exists —
      currently omitted rather than pointed at a nonexistent file.

- [ ] **[P3]** **[Needs owner]** Decide the JSON-LD structured-data approach
      given the zero-exception CSP (`script-src 'self'`, no nonce mechanism
      on this static site): accept `'unsafe-inline'` (security regression),
      pin per-locale SHA-256 hashes into `vercel.json` (brittle), or skip
      structured data entirely. Tried and reverted this session rather than
      ship something CSP would silently drop.

### Editor lint fixes + Dockerfile critical/high CVE fix (2026-07-21)

Full session log: `sessions/2026-07-21/0100-PST.md`. Fixed TS5090 in
`website/tsconfig.json` (non-relative `paths` entry), moved `vercel.json`/
`tsconfig.json` schema associations from inline `$schema` (blocked by VS
Code workspace trust) to `.vscode/settings.json`'s `json.schemas`, added a
missing glob comment to `_bmad/custom/.gitignore`, and fixed the Docker DX
"1 critical and 4 high vulnerabilities" finding in `docker/Dockerfile` —
root-caused to npm 10.9.8's own vendored `tar`/`sigstore`/`picomatch`/
`brace-expansion` (node:22-alpine's pinned digest is already the newest
published build, so no digest bump was available); fixed with a self-
upgrading `npm install -g npm@latest` before `npm ci`, verified via
`docker scout cves` on a full rebuild of both stages before and after.

- [ ] **[P3]** **[Needs owner]** Decide whether `.gitnexus/**` should be
      readable by the agent — it's currently hard-blocked by a `deny` rule in
      `.claude/settings.json` (`Read/Bash/Grep(.gitnexus/**)`), which a
      verbal "I give you permission" can't override by design. If wanted,
      edit that deny list directly; otherwise no action needed.

### Vercel production hosting + Stripe/Resend hardening (2026-07-21)

Full session log: `sessions/2026-07-21/0000-PST.md`. `website/` is now live
in production on Vercel (`https://sensebridge-website.vercel.app`,
`trustledger/sensebridge-website`) with a zero-exception CSP and full
security-header set, verified live via `curl -I`. The Vercel project was
renamed `sensebridge-website` → `sensebridge` on 2026-07-21; the
`sensebridge.vercel.app` alias doesn't bind until the next production
deploy (renaming doesn't retroactively rebind the default alias) — until
then the site is still reachable at the old `sensebridge-website.vercel.app`
URL. Railway stays for
previews/testing per owner decision — no GitHub auto-deploy connected on the
Vercel side, so the two hosts don't race on the same push. Stripe/Resend
were scoped to infra hardening only (no checkout/email code, no SSR
adapter) — the site's `output: "static"` no-backend invariant and "nothing
is being sold" pre-launch doctrine are both still intact.

- [ ] **[P1]** **[Needs owner]** Rotate the Stripe test-mode secret key
      (`sk_test_...`). It printed in full, unmasked, into this session's
      transcript via `stripe config --list` — the live-mode restricted key
      was properly masked by the CLI, the test key was not. Dashboard →
      Developers → API keys → roll key.

- [ ] **[P2]** **[Needs owner]** Stripe Dashboard hardening (none of this is
      CLI/API-scriptable without an owner decision or identity/bank details
      this session doesn't have): enable/confirm account 2FA; review Radar
      fraud rules once there's real transaction history to base them on;
      confirm payout schedule and business profile. Also worth switching the
      test-mode key to a restricted key (matching the live-mode key's
      posture) whenever it's next touched.

- [ ] **[P3]** **[Needs owner]** Attach a custom domain to the Vercel project
      (`trustledger/sensebridge`) once one is decided — currently only
      reachable at the `*.vercel.app` URL.

- [ ] **[P3]** **[Needs owner]** Resend setup, parked until there's an actual
      feature to send email for (a waitlist or contact form): create an
      account if one doesn't exist, pick a sending domain, verify it
      (DKIM/SPF/DMARC — needs DNS registrar access this session doesn't
      have), and generate a sending-only scoped API key.

### GitGuardian secret scanning (2026-07-20)

Full session log: `sessions/2026-07-20/1900-PST.md`. Added `ggshield` as a
third, independent secret scanner alongside the existing Gitleaks
(pre-commit, pattern-based) and TruffleHog (CI, verified-credential):
`.gitguardian.yaml` (strict — `exit_zero: false`, no path allowlist),
`.githooks/pre-commit` (advisory-skip if not installed), a new `ggshield`
job in `.github/workflows/security.yml` (pinned to the commit behind
`v1.52.2`), an advisory check in `scripts/setup.sh`, and synced
`docs/TOOLING.md`/`docs/ENVIRONMENT.md`. Same session also set
`autoCompactWindow: 100000` and added Effort Level orchestration guidance to
the global `~/.claude/CLAUDE.md` (personal config, not repo-tracked).

- [ ] **[P2]** **[Needs owner]** Add `GITGUARDIAN_API_KEY` to the repo's
      **Dependabot** secrets too (Settings → Secrets and variables →
      Dependabot → New repository secret), not just Actions. Every
      dependabot PR's `Secret scan (GitGuardian)` check failed with `Error:
      Invalid GitGuardian API key`, which first looked like a bad key value —
      but PR #53 (a direct, non-dependabot push, 2026-07-28) passed both
      GitGuardian checks with the *same* Actions secret, proving the key
      itself is fine. GitHub withholds repository Actions secrets from
      workflows triggered by Dependabot's `pull_request` events by design
      (so a malicious dependency bump can't exfiltrate them), so the value
      resolved empty in those runs — not invalid. No key rotation needed;
      reuse the existing value in the separate Dependabot secret store. Not
      P1: it only affects the optional GitGuardian check on dependabot's own
      PRs, which are otherwise fine to verify and merge manually.

### Full markdown documentation sync sweep (2026-07-20)

Full findings in `audits/documentation/20260720-194209-full-markdown-sync-sweep.md`.
Clear-cut dangling links and stale facts were fixed directly in that same
pass (`security/CHECKLIST.md`, `audits/AGENT-GUIDE.md`, `docs/PRIVACY.md`,
`GAPS.md`, `PROJECT_OVERVIEW.md`, `SETUP-STATUS.md`, `models/README.md`); the
items below need an owner decision or a `git` action and were left untouched.

- [ ] **[P3]** **[Needs owner]** `GOVERNANCE.md:34` says architecture
      decisions "are recorded as they're made in `docs/adr/`," but
      `docs/adr/` does not exist anywhere in the repo (verified via `find`).
      Needs an owner call: either start actually recording ADRs there (and
      create the directory with a first entry or a README describing the
      convention), or reword the claim to reflect that this practice hasn't
      started yet. Left unfixed because either fix is a judgment call, not a
      mechanical correction.

### Language support EN/ES/VI — implementation in progress (2026-07-19)

Spec: `docs/superpowers/specs/2026-07-19-LANGUAGE-SUPPORT-DESIGN.md`. Session
log: 2026-07-19 `2300-PST`. Implementation units may still land in-session;
these items outlive it regardless.

- [ ] **[P1]** **[Needs owner]** Native-speaker validation of all Spanish and
      Vietnamese strings — app output (hedges, fallback, permission strings),
      app UI chrome (Unit B: `app/SenseBridge/Resources/Localizable.xcstrings`
      — nav titles, accessibility labels/hints, `SettingsView`'s language
      picker), and website copy. Machine gates can't prove translation
      quality, and the hedge semantics are safety-framing doctrine; treat
      like device validation.

- [ ] **[P2]** Vision detector labels arrive in English, so the fallback
      composer can localize the hedge around an English noun (documented
      known limitation in the spec). Resolve via the Foundation-Models
      composer (compose directly in the target language) or a label
      translation layer.

### e2e test floor (2026-07-19)

The tracked change is the e2e testing floor (≥3 e2e per feature — happy
path / error / edge case — and all code tested) added to
`docs/TESTING.md`, the `testing` + `ci-green-gate` skills, project
`CLAUDE.md`, `audits/README.md`, and `WIKI.md`.

- [ ] **[P3]** Propagate the e2e floor to the other testing-flavored skills
      (`sc:test`, `bmad-qa-generate-e2e-tests`) at the next weekly skill
      review — logged as task-observer observation #5.

### Flagship website evolution — "First Light" 3D batch follow-ups (2026-07-19)

Overnight autonomous run on `feat/website-first-light` (tracker:
`tmp/WEB.md`, batches A–I all ✅): runtime light/dark/system theming,
Fraunces/Geist/Geist Mono typography, five lazy three.js scenes (hero,
ambient, phone exploded view, glasses, suspension bridge), site-wide motion
upgrade, header responsive restructure. Machine gates all green (build /
typecheck / stylelint / eslint / prettier / pa11y WCAG2AA 0 errors / 12-combo
puppeteer visual matrix). `.agents/context/DESIGN.md` rewritten to match.

- [ ] **[P1]** **[Needs owner]** Real-device pass over the 3D batch:
      VoiceOver/NVDA read-through of the new `#device` and `#future`
      sections, Safari/iOS WebGL behavior (headless QA used SwiftShader),
      OS-level reduced-motion setting, and battery/thermal while the scenes
      run. Headless verification confirmed zero 3D bytes under reduced
      motion, but no human or physical device has seen this yet.

- [ ] **[P2]** **[Needs owner]** The owner directive "no design guardrails,
      only security matters" (2026-07-18) voided the repo's visual-restraint
      doctrines; `DESIGN.md` §0 now records that. Confirm the doctrine files
      it supersedes (e.g. anti-reference lists in
      `.agents/context/PRODUCT.md`) should stay as-is or be updated to
      match — deferred rather than edited, since PRODUCT.md is strategy, not
      just style.

- [ ] **[P3]** `scripts/generate-audio.js` narration: hero/bridge copy is
      unchanged this batch, but the page gained two new sections
      (`#device`, `#future`) the pre-rendered natural-voice audio has never
      covered — fold into the existing narration-regeneration item below.

### New Claude hooks — commit + tuning (2026-07-19)

Three new hook scripts under `.claude/hooks/` wired into
`.claude/settings.json`: `check-md-links.sh` (PostToolUse — flags broken
relative links in edited `.md` files), `guard-main-commit.sh` (PreToolUse —
denies `git commit` while on `main`), and `session-log-reminder.sh` (Stop —
blocks stopping once per hour bucket when the tree is dirty and no session
log exists). All pipe-tested; the Markdown-link hook proven live in-session.

- [ ] **[P3]** If the Stop-hook session-log reminder proves noisy (its
      dirty-tree gate also triggers on pre-existing uncommitted work),
      tighten it to session-modified files — see the `ponytail:` comment in
      `.claude/hooks/session-log-reminder.sh`.

### Global Claude Code tooling build-out (2026-07-19)

One piece of a personal, machine-wide tooling build-out touched this repo
directly — see the BMAD-METHOD row in `docs/TOOLING.md`'s "Project-level"
table. (The rest of that build-out is machine-scoped and tracked in
`NOTES.local.md`, not here.)

- [ ] **[P2]** **[Needs owner]** `docs/TOOLING.md` already documents claude-mem as
      **deliberately disabled at project scope for SenseBridge** (duplicate-memory
      risk + prior local-surface issues — see that entry). The global build-out's
      Phase 5 (not yet started) asks to wire claude-mem to Obsidian for token
      savings — decide whether that global change should also flip this repo's
      project-scope override, or stay disabled here regardless of what happens
      globally, before Phase 5 runs.

### Signal Bridge motif follow-ups (2026-07-18)

- [ ] **[P1]** **[Needs owner]** Real VoiceOver pass over the Signal Bridge
      section (`website/src/components/SignalBridge.astro`, between Hero and
      Features) — no machine check substitutes for a screen-reader session.
      The automated half of this item, `npm run test:a11y` (pa11y-ci), is now
      **done 2026-07-26**: the local Puppeteer/Chrome blocker this item
      originally cited is stale — the cache was already repaired by the
      2026-07-25 fix (see the pa11y items under "Website layout width,
      motion, and a cow on every HTTP status page"). Re-ran it directly
      (`npm run build && npm run preview`, then `npm run test:a11y`; this
      machine is on Node 26.3.1, and it launched fine — the repaired cache,
      not a Node downgrade, is what fixed it here): **8/8 URLs, 0 errors**,
      covering the whole built site including this section, not just the
      static heading-hierarchy/`aria-labelledby`/`aria-hidden` analysis this
      item originally fell back to.

### Signal Spine motion batch — accessibility review follow-ups (2026-07-18)

Full report:
`audits/accessibility/20260719-024433-website-first-light-batch-signal-spine-motion-choreography-sticky-header-a11y-review.md`
(local-only — `audits/**` is gitignored). One High finding (sticky header
obscuring the `#main` skip-link target, new WCAG 2.2 SC 2.4.11 exposure) was
fixed in-session (`website/src/styles/global/_base.scss`); these are the
remaining open items.

- [ ] **[P1]** **[Needs owner]** Real VoiceOver/NVDA + keyboard-only pass over
      this batch (Signal Spine rail, per-stage reveal choreography, sticky
      header, magnetic CTA, Signal Bridge) before merge — this review was
      static code inspection only.

- [ ] **[P2]** **[Needs owner]** Visual sign-off of the pointer-reactive hero
      glow on a real device — owner approved it conditionally ("aesthetic and
      clean"); headless screenshots (2026-07-18 session) show the bloom
      following the pointer at unchanged intensity, but the final call is the
      owner's. Pull it (ship the static glow) if it reads as gimmick.

- [ ] **[P3]** Audio-narration ↔ spine-pulse sync (design roadmap #3):
      drive the Signal Spine pulse from narration progress while the
      natural-voice player runs. **Unblocked 2026-07-25** — `/audio/main.mp3`
      now exists and the natural-voice control renders on `/`.

- [ ] **[P3]** Read-aloud per-section segmentation + polite stage
      announcements ("Now: what it does today" etc., derived from h2 text) in
      the existing `#read-aloud-status` live region. Skipped in the motion
      batch because `read-aloud.ts` speaks one monolithic utterance —
      requires restructuring it into per-section segments first.

### Website rebuild ("First Light" Astro site) follow-ups (2026-07-18)

- [ ] **[P1]** **[Needs owner]** Manual accessibility pass on the rebuilt
      site: VoiceOver + keyboard-only walkthrough, and a
      `prefers-reduced-motion: reduce` check that the page is complete and
      static (pa11y-ci passes with 0 errors, but the human gate per
      `docs/TESTING.md` cannot be automated).

- [ ] **[P1]** **[Needs owner]** Lighthouse mobile run in a real browser
      against the built site (target ≥95 all categories; LCP must be the hero
      H1 text). CI has no Lighthouse job yet — add one if the manual run
      regresses.

- [ ] **[P2]** **[Needs owner]** Re-verify the Railway deploy after merge:
      service Root Directory still `website`, new multi-stage Dockerfile
      builds on Railway, site serves on `$PORT`.

- [ ] **[P3]** Refresh `.impeccable/design.json` from the rewritten
      `.agents/context/DESIGN.md` ("First Light" superseded "Quiet Signal"),
      then re-run `impeccable detect website` so its design-system detectors
      key off the current tokens, and revisit the deferred
      `/impeccable polish website` pass.

### Website read-aloud follow-ups (from the 1400 PST session, 2026-07-17 — backfilled; the session log had these but this file never did)

- [ ] **[P3]** Send the two `/browse` fixes upstream to gstack (element
      screenshot stability timeout, and `eval`'s `ENAMETOOLONG` message). They
      are patched locally in `~/.claude/skills/gstack/browse/src/` on top of
      HEAD `7c9df1c5` and `/gstack-upgrade` will overwrite them.

- [ ] **[P2]** **[Needs owner]** Real VoiceOver/NVDA pass over the footer
      ElevenLabs credit and its logo badge (`website/src/components/Footer.astro`).
      `pa11y-ci` passes 8/8 with it, but that is automated checking, not a
      screen-reader session — the badge is decorative and must stay silent
      while the credit text reads normally.

- [ ] **[P2]** **[Needs owner]** **[Legal]** Regenerate the narration under a
      paid ElevenLabs plan **before** SenseBridge becomes commercial in any
      way — a paid tier, sponsorship, paid placement, anything transactional.
      Free-plan audio carries no commercial licence, and the obligation
      attaches to the audio file itself: upgrading the account later does
      **not** relicense audio that was generated while free. The
      `elevenlabs.io` credit must stay until the audio is regenerated under a
      paid plan; it is not removable just because the plan changed. Touches
      `legal/`, which is owner-gated.

- [ ] **[P2]** Watch the free-plan quota. It is 10,000 credits/month and a
      full regeneration is ~4,400 characters, so roughly **two** regenerations
      per month — and the narration needs two runs each time it changes (the
      button's own label lives inside the hashed `<main>`, so run one goes
      stale the moment the button appears). Two regenerations were already
      spent on 2026-07-25. If narration churn picks up, or per-locale
      narration lands (three pages, so ~13,000 characters per full refresh),
      the free plan stops being enough.

- [ ] **[P2]** Per-locale narration, or keep the English-only guard. Now that
      `/audio/main.mp3` ships, `/es/` and `/vi/` are the only routes without a
      natural-voice option — `ReadAloud.astro` gates `naturalVoiceAvailable` on
      `locale === "en"` because playing English audio to a Spanish or
      Vietnamese visitor would break the site's honesty principle. Lifting the
      guard means generating `main.es.mp3` / `main.vi.mp3` from the translated
      `<main>` text (the extraction in `scripts/generate-audio.js` is
      hard-coded to `dist/index.html`, so it needs a locale parameter first).
      The `ReadAloud.astro` comment points here.

- [ ] **[P3]** Decide whether to shrink the narration asset. ElevenLabs'
      default output is 128 kbps MP3, so `main.mp3` is 5.3 MB and every
      regeneration adds another 5.3 MB blob to git history forever. Appending
      `?output_format=mp3_44100_64` to the request URL in
      `website/scripts/generate-audio.js` roughly halves it at speech-adequate
      quality. Deferred rather than done because the audience for this control
      is precisely the audience least well served by degraded audio — the call
      is the owner's after the listen-through above.

### AI-tooling re-evaluation follow-ups (2026-07-17, evening session)

- [ ] **[P3]** **[Needs owner]** Optional, only if wanted: log the `codex`
      CLI into an OpenAI account to activate the `codex-plugin-cc`
      second-opinion reviewer (inert without it), and/or add the Perplexity
      MCP per-developer via the command in `docs/TOOLING.md` → MCP inventory.
      Neither is required by any gate.

- [ ] **[P2]** **[Needs owner]** Finish activating the override-wave installs
      (2026-07-17 evening, all optional-when-wanted): run
      `agent-browser install` (Chrome-for-Testing fetch was permission-gated);
      `brew install ffmpeg` before any hyperframes render; authenticate the
      `granola` and `higgsfield` MCPs via `/mcp`; trigger the NotebookLM
      skill's first run yourself (pip + Chrome download + Google login —
      deliberately left to a human); set `APIFY_API_TOKEN`/`GOOGLE_AI_API_KEY`
      only if the two dependent social skills are ever wanted.

### Owner actions pending (from the `app/` scaffold session, 2026-07-17)

- [ ] **[P1]** **[Needs owner]** Make the repo public, then create the
      GitHub ruleset protecting `main` — `GAPS.md` M5. GitHub Free can't use
      Rulesets on a private repo, which is why the 2026-07-17 attempt below
      403'd. Repo is public now and a narrower ruleset exists
      (`main-required-checks`, 2026-07-25) — this fuller spec (require-PR-
      before-merge, linear history, squash-only, 3 more checks) is still the
      gap to close if it turns out to matter; see the "CI/CD security audit"
      To-Do entry above. Both rulesets are now also codified as settings-as-
      code in [`.github/rulesets/`](.github/rulesets/README.md) (added
      2026-07-28) — `protect-main.json` is this exact spec, ready to
      `gh api --method POST` once approved; the steps below are still the
      authoritative walkthrough. Steps, in order:
      1. `gh repo edit kevinle3212/sensebridge --visibility public --accept-visibility-change-consequences`
      2. `gh api repos/kevinle3212/sensebridge/rulesets` — confirm it now
         returns `[]` instead of `403`.
      3. Create the **"Protect main"** ruleset — target: default branch;
         enforcement: Active; bypass list: empty (no exceptions, including
         the owner). Two equivalent ways:
         - **UI** — Settings → Rules → Rulesets → New branch ruleset. Set:
           restrict deletions **on**, restrict force pushes **on**, require
           linear history **on**, require signed commits **off** (commit
           history isn't GPG-signed yet); require a pull request before
           merging **on** with required approvals **0** (`CODEOWNERS` is
           solely `@kevinle3212` — raise to 1 the moment a co-maintainer
           exists), dismiss stale approvals **on**, require review from Code
           Owners **off** (same reasoning as approvals), require approval of
           most recent push **on**, require conversation resolution **on**,
           allowed merge methods **squash only**; require status checks to
           pass **on** with require branches up to date **on**, adding these
           checks by exact name: `Build and test`, `Lint (SwiftFormat +
           SwiftLint)`, `Docs link check`, `Secret scan (TruffleHog)`,
           `Dependency scan (OSV)`, `Sensitive file scan`, `Semgrep
           (scripts, workflows, website, Swift)`; require deployments to
           succeed **off** (no gating environment), require code scanning
           results **off** (Semgrep/TruffleHog run as plain Actions, not
           GitHub's native code-scanning integration). Do **not** add
           `Stylelint + ESLint + Prettier` / `Impeccable design detectors`
           (`website-ci.yml` is path-filtered to `website/**` — would block
           every non-website PR forever) or `review`
           (`claude-code-review.yml` — an AI first-pass, not a deterministic
           gate).
         - **`gh api`** — equivalent, one shot:
           ```sh
           gh api --method POST repos/kevinle3212/sensebridge/rulesets \
             --input - <<'JSON'
           {
             "name": "Protect main",
             "target": "branch",
             "enforcement": "active",
             "bypass_actors": [],
             "conditions": { "ref_name": { "include": ["~DEFAULT_BRANCH"], "exclude": [] } },
             "rules": [
               { "type": "deletion" },
               { "type": "non_fast_forward" },
               { "type": "required_linear_history" },
               {
                 "type": "pull_request",
                 "parameters": {
                   "required_approving_review_count": 0,
                   "dismiss_stale_reviews_on_push": true,
                   "require_code_owner_review": false,
                   "require_last_push_approval": true,
                   "required_review_thread_resolution": true,
                   "allowed_merge_methods": ["squash"]
                 }
               },
               {
                 "type": "required_status_checks",
                 "parameters": {
                   "strict_required_status_checks_policy": true,
                   "required_status_checks": [
                     { "context": "Build and test" },
                     { "context": "Lint (SwiftFormat + SwiftLint)" },
                     { "context": "Docs link check" },
                     { "context": "Secret scan (TruffleHog)" },
                     { "context": "Dependency scan (OSV)" },
                     { "context": "Sensitive file scan" },
                     { "context": "Semgrep (scripts, workflows, website, Swift)" }
                   ]
                 }
               }
             ]
           }
           JSON
           ```
      4. `gh api repos/kevinle3212/sensebridge/rulesets` — verify it now
         lists "Protect main".
      5. Settings → General → Pull Requests: disable merge commits and
         rebase merging, leaving squash merging as the only option
         (belt-and-suspenders with the ruleset's `allowed_merge_methods`).
      A full-history secret scan (`gitleaks detect`,
      `check-sensitive-files.mjs --all`) already ran clean before this was
      decided, so nothing else blocks going public.

- [ ] **[P2]** **[Needs owner]** Install the CodeRabbit GitHub App —
      <https://github.com/apps/coderabbitai/installations/new>, "Only select
      repositories" → `sensebridge`. Requires owner consent on github.com,
      no API/token path.

- [ ] **[P2]** **[Needs owner]** Set the real bundle identifier and Apple
      Developer signing team in `app/project.yml` (`PRODUCT_BUNDLE_IDENTIFIER`
      is currently the placeholder `com.sensebridge.app`, no
      `DEVELOPMENT_TEAM` set) once you have an Apple Developer identity — see
      `docs/DISTRIBUTION.md`.

- [ ] **[P3]** **[Needs owner]** Enable GitHub Discussions if you want the
      issue-template support link to resolve (Settings → General →
      Features).

- [ ] **[P1]** **[Needs owner]** On-device latency/battery/thermal
      benchmarking and blind/low-vision tester validation — standing item,
      not a one-time task; no machine (including CI) can substitute for this.
      See `docs/TESTING.md` and the `ci-green-gate` skill.

### Website audit follow-ups (from `/impeccable audit website`, 2026-07-11)

- [ ] `/impeccable polish website` — final pass once the above land.

### CI/security automation audit (2026-07-27)

- [ ] **[P1]** The `dependabot-automerge.yml` fix (repo settings: enabled
      `allow_auto_merge` + "Allow GitHub Actions to create and approve pull
      requests") is confirmed working — PRs #46/#47/#49 now show
      `autoMergeRequest` enabled and approved. But merge is still blocked by
      **separate, unrelated CI failures**: `Secret scan (GitGuardian)` fails
      on all three; `Deploy to Railway preview` fails on all three;
      `Build + smoke-test docker/Dockerfile` and
      `Stylelint + ESLint + Prettier + typecheck + build` fail on #47/#49;
      `Impeccable design detectors` fails on #46. Not investigated further
      this session — out of scope for the auto-merge-permission fix. Needs
      its own look: whether these are flaky/transient, a shared root cause
      (all three failing GitGuardian is suspicious), or genuinely broken on
      these dependency-bump branches specifically.

- [ ] **[P2]** `dependabot.yml`'s grouped PRs (`dev-dependencies` group, e.g.
      #44 "dev-dependencies group with 2 updates", #45 "...in /website with 4
      updates") never auto-merge even when every member update is
      patch/minor. Root cause: `dependabot/fetch-metadata` can't report a
      single `update-type` for a grouped PR (known upstream limitation), so
      `dependabot-automerge.yml`'s
      `steps.meta.outputs.update-type == 'version-update:semver-patch' ||
      ...-minor'` condition never matches a grouped PR. Fix needs a design
      decision, not a quick patch: either stop grouping dev-dependencies (loses
      the batching benefit) or switch the workflow's gate to something that
      inspects each dependency in the group (e.g.
      `steps.meta.outputs.dependency-names` + per-dep version comparison, or
      GitHub's newer `dependency-group` output plus a stricter allowlist).

- [ ] **[P3]** CodeQL alert #93 (`js/file-access-to-http`,
      `tools/docs-a11y.mjs:155`) had a well-reasoned inline suppression
      comment (lines 151-154, added in `339cec6`) explaining the flow is safe
      (URL host is always `http://127.0.0.1:PORT`, only the path segment is
      filesystem-derived and already passed through `SAFE_HTML_FILENAME`),
      but the `codeql[rule-id]` directive sat 4 lines above the flagged line
      with continuation comments in between — GitHub's inline-suppression
      parser likely requires the directive on the line immediately above.
      **Reformatted 2026-07-28**: prose moved above, `codeql[js/file-access-to-http]`
      is now the line directly above `page.goto`. `gh api
      repos/kevinle3212/sensebridge/code-scanning/alerts` confirmed this was
      the only open alert (#93) before this change. Closing the alert
      depends on the next CodeQL scan on `main` actually picking up the new
      placement — if it's still open after that scan, dismiss #93 manually
      with the same justification.

## In Progress

*Nothing currently in progress.*

## Completed

### Serena/RTK coverage audit — MCP deny bypass closed (2026-08-01, 19:57 PST)

Audit of whether Serena and RTK are actually prioritized across every tool call,
with clean fallbacks and proof by test. The substantive finding: **Claude Code
permission-rule path globs do not reach MCP tool arguments** — `Read(**/*.pem)`
scopes by path for built-in tools only, because MCP rules match on tool *name*
alone. Confirmed by probe: with the built-in `Read` of a scratch `.pem` denied,
`mcp__filesystem__read_text_file` returned that file's contents and
`mcp__filesystem__write_file` wrote to it. Closed by
`.claude/hooks/guard-mcp-sensitive-paths.mjs` and verified live against all
three vectors (read, write, and a sensitive path smuggled into a
`read_multiple_files` batch). Detail in `sessions/2026-08-01/1925-PST.md`.

- [x] **[P2]** **Kill the duplicate Serena MCP servers.**
      **Not a defect — closed 2026-08-01 by measurement, and the original
      finding was wrong.** Two `serena start-mcp-server` processes are live, but
      they have *different parents*: PID 14152 (`claude`, the interactive
      session) and PID 97344 (`claude bg-spare`, the background daemon). Serena
      is spawned once per MCP client, not once per project, so this is stdio
      MCP working as designed — nothing to kill, and the `.mcp.json` edit did
      not produce it. The claim that they "each try to bind the dashboard port,
      so at most one gets 24285" is also wrong: the port walks up from its base,
      and `lsof` shows them holding **24283 and 24284**, both `127.0.0.1`-only,
      with 24285 free. Corrected in `docs/TOOLING.md`'s serena row.

- [x] **[P2]** **`guard-protected-delete.sh` fires on prose.**
      **Fixed 2026-08-01** (owner approved the change explicitly). Root cause
      was narrower than reported: `sed 's/<<.*//'` works line by line, so it
      truncated only the `cat <<EOF` line and left the here-doc body it was
      meant to remove — now `${raw_cmd%%<<*}`, matching the sibling guard.
      `guard-main-commit.sh`'s quoted-literal blanking could **not** be copied
      wholesale: that guard matches a *verb*, this one matches an *argument*,
      and arguments are routinely quoted, so blanking quoted text would have
      let `rm -rf "sessions/x"` through. It now walks the command once,
      quote-aware, keeping two views per segment — quoted runs collapsed for
      verb detection, quote characters dropped but contents kept for path
      detection — and splits on separators only outside quotes, so
      `echo "a; rm -rf sessions/"` stays one `echo`. Verified by a new
      `.claude/hooks/tests/guard-protected-delete.test.sh` (32 assertions, 12 of
      them prose/false-positive cases) **and** end-to-end: the exact here-doc
      shape that was denied twice now executes.

- [x] **[P3]** **Consider extending the MCP path guard to other servers.**
      **Fixed 2026-08-01 with automatic detection**, which is what was actually
      missing. `tools/check-settings-hooks.mjs` now cross-checks `.mcp.json`
      against the `guard-mcp-sensitive-paths.mjs` matcher and fails until every
      project-scoped server is either covered or recorded in
      `MCP_SERVERS_WITHOUT_PATH_ARGS` with the reason it takes no filesystem
      path. Proven in both directions against a sandbox copy: clean on the real
      config, failing on an added `newthing` server. Scope stated rather than
      implied — it sees project-scoped servers only, since user-scope ones
      (`filesystem` included) live in the owner's global config, which a tracked
      repo gate cannot read.

- [ ] **[P1]** **Needs owner: disconnect unused `claude.ai` account connectors
      to cut per-turn token overhead.** Machine/account-level, not SenseBridge
      code — logged here per `AGENTS.md`'s "any substantive follow-up...
      also goes into TODO.md." Full audit in `sessions/2026-08-01/2300-PST.md`
      and `tmp/AWAY-REPORT.md` (this file may be gone by the time you read
      this — `tmp/` is cleared once work ships).

      Account `kevinle3212@gmail.com` (the account this ran under) has 44
      `claude.ai` connectors (`claude mcp list`); account
      `kevinle_uoregon.edu` has zero. These are pure account-scoped web
      integrations (claude.ai → Settings → Connectors) — confirmed
      unreachable from any local file, `.mcp.json`, or `claude mcp
      remove`/`logout` (the CLI's own answer: "its credentials live on
      claude.ai, not this machine"). Every connected one contributes its full
      tool-name list to every single turn in every session on that account,
      regardless of project — this is very likely the dominant token cost
      behind "even small tasks feel expensive."

      **Do this:** open https://claude.ai/customize/connectors, and
      disconnect these (cross-checked against real usage in
      `~/Development/{sensebridge,TrustLedger,archon,website}` — none of
      them appear in any repo's dependencies, env examples, or docs):

      Never-authenticated (zero function, pure cost) — Fellow.ai, Zoom for
      Claude, PlanetScale, S&P Global, Scholar Gateway, Atlassian Rovo,
      Stripe, Midpage Legal Research, Microsoft 365, Docusign, Harvey,
      Coupler.io, Square.

      Connected but no evidence of use anywhere on this machine — Blockscout,
      Crypto.com, Aiwyn Tax (Column Tax), Courtroom5, LegalZoom, Indeed,
      Goodnotes, tldraw, Excalidraw, ClickUp, Postman, Clerk, Cloudflare
      Developer Platform, Supabase, Hugging Face, Microsoft Learn,
      Composio MCP (redundant — `CLAUDE.md` §17 already documents Composio as
      CLI-only with no MCP surface; this connector contradicts that), claude.ai
      Context7 (duplicate of the already-configured local `context7` MCP
      server).

      **Keep** — Vercel (confirmed: `website/package.json` deploy scripts,
      `TrustLedger/.vercel/`), Slack (confirmed: `archon` Slack bot env vars),
      Sentry (documented, wired into SenseBridge's crash reporting), Calendly
      (connected by you this same session, deliberately), plus
      identity-adjacent/personal-productivity ones I didn't find hard
      evidence for either way but left alone rather than guess: Gmail, Google
      Calendar, Google Drive, Notion, Todoist, Figma, ElevenLabs — worth a
      2-minute look yourself since some are probably also dead weight.

      After: re-run `claude mcp list` and confirm the account matches
      account 2's near-empty connector list. No further automated step —
      this is the end of the chain.
