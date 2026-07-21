# TODO

Lightweight personal reminders, grouped by status: **To-Do**, **In Progress**,
**Completed**. Tracked defects/debt/risks live in [`GAPS.md`](GAPS.md); this
file is just a short list of things to come back to.

Within To-Do, items stay grouped by the review/audit that produced them and
ordered so earlier work unblocks later work.

**Item Completion** Don't just flip `- [ ]` to `- [x]`. Keep the original
text and append, in bold, the completion date plus what was actually done
(and any verification, links, or follow-on notes) — the pattern already used
throughout this file: `**Done/Fixed YYYY-MM-DD** — <what changed, how it was
verified, anything relevant left over>`.

## Legend

| Label | Meaning |
| --- | --- |
| **P0** | Blocking — violates a hard gate (accessibility, safety-framing, security). Fix before anything else here. |
| **P1** | High priority — user-facing gap or incorrect behavior; no hard gate violated. |
| **P2** | Medium priority — spec/design fidelity or polish; non-blocking. |
| **P3** | Low priority — already decided/documented, or blocked on other work; revisit opportunistically. |
| **Needs owner** | Requires the repo owner specifically — a GitHub web-UI action, a `git`/`gh` command (agents never run these autonomously), Apple Developer credentials, a physical device, a human tester, or a decision only they can make. Combine with a priority, e.g. `**[P1]** **[Needs owner]**`. |

## To-Do

### Gitignore + config-strictness audit (2026-07-20)

Full findings in `sessions/2026-07-20/1300-PST.md`. Both concrete gaps found
were fixed directly in the same pass (`.gitignore` now covers
`_bmad/**/*.user.toml`; `.github/dependabot.yml` now tracks the `docker`
ecosystem for `website/Dockerfile`) — this is the one deferred nice-to-have.

- [ ] **[P3]** Pin `website/Dockerfile`'s `node:22-alpine` base image to a
      digest (`node:22-alpine@sha256:...`) instead of a mutable tag, for
      supply-chain immutability — same rationale already applied to the
      GitHub Actions pins in `.github/workflows/security.yml`. Needs a
      registry lookup for the current correct digest (not fabricated this
      session); the new Dependabot `docker` ecosystem entry added this
      session will keep a pinned digest current automatically once set.

### Full markdown documentation sync sweep (2026-07-20)

Full findings in `audits/documentation/20260720-194209-full-markdown-sync-sweep.md`.
Clear-cut dangling links and stale facts were fixed directly in that same
pass (`security/CHECKLIST.md`, `audits/AGENT-GUIDE.md`, `docs/PRIVACY.md`,
`GAPS.md`, `PROJECT_OVERVIEW.md`, `SETUP-STATUS.md`, `models/README.md`); the
items below need an owner decision or a `git` action and were left untouched.

- [ ] **[P2]** **[Needs owner]** `legal/PRIVACY_POLICY.md:31` links to
      `docs/PRIVACY.md`, but that's relative to `legal/`, which has no
      `docs/` subdirectory — the link should be `../docs/PRIVACY.md` (see
      the correct pattern already used at `legal/DISCLAIMER.md:16` and
      `legal/TERMS_AND_CONDITIONS.md:23`). Left unfixed because `legal/`
      requires explicit owner approval before any edit, per `CLAUDE.md`.
- [ ] **[P3]** **[Needs owner]** `GOVERNANCE.md:34` says architecture
      decisions "are recorded as they're made in `docs/adr/`," but
      `docs/adr/` does not exist anywhere in the repo (verified via `find`).
      Needs an owner call: either start actually recording ADRs there (and
      create the directory with a first entry or a README describing the
      convention), or reword the claim to reflect that this practice hasn't
      started yet. Left unfixed because either fix is a judgment call, not a
      mechanical correction.
- [ ] **[P2]** **[Needs owner]** Several files that tracked docs reference as
      if already part of the repo are actually untracked (`git status`
      shows `??`) on this branch: the entire `app/` scaffold (referenced
      throughout `PROJECT_OVERVIEW.md`, `AGENT-CONTEXT.md`, `SETUP-STATUS.md`,
      `README.md`), `docs/OLLAMA.md` (referenced from `.continue/README.md`
      and `docs/TOOLING.md`), `docs/NOTEBOOKLM.md`, `CLAUDE.template.md`
      (referenced from `README.md`), and this file (`TODO.md`, which
      `CLAUDE.md` itself calls "the tracked `TODO.md`" even though it isn't
      tracked yet). None of these are dangling links today — the files exist
      on disk, so relative links resolve locally — but a fresh clone of the
      current `HEAD` would 404 on every one of them. This is a `git add`
      action, which this session doesn't have standing permission to run
      autonomously; needs the owner to stage and commit these paths (or
      confirm they're intentionally still WIP-only).

### Language support EN/ES/VI — implementation in progress (2026-07-19)

Spec: `docs/superpowers/specs/2026-07-19-language-support-design.md`. Session
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
- [ ] **[P1]** **[Needs owner]** Git handover — QA now passed (all units
      built, tested, reviewed; see `sessions/2026-07-20/1200-PST.md`).
      `SenseBridgeCore` and the app UI (`app/SenseBridge*`, `app/project.yml`,
      `app/SenseBridge.xcodeproj`) are cleanly separable commits — never
      committed before this feature, no prior state to preserve. `website/`
      is **not** cleanly separable: its modified files (`Header.astro`,
      `Disclaimer.astro`, `BaseLayout.astro`, etc.) already carried
      uncommitted "First Light" rebuild changes before this session touched
      them for i18n, with no commit boundary between the two — staging just
      the i18n hunks risks mis-splitting unrelated in-progress work. Decide:
      ship `website/` as one bundle (rebuild + i18n together), or hand-split
      via `git add -p` yourself (only you know the rebuild/i18n boundary from
      memory). Same open question as before on BMAD sequencing (the ~103
      pre-existing uncommitted files unrelated to this feature) — commands
      for the achievable split are in this session's final report.
- [ ] **[P2]** Unit C (website) shipped `/`, `/es/`, `/vi/` routes, but
      `website/.pa11yci.json` still only tests `http://localhost:4321/` —
      add `/es/` and `/vi/` so `npm run test:a11y` actually covers the two
      new locales, not just English.
- [ ] **[P2]** Unit C's "Listen (natural voice)" control
      (`website/src/components/ReadAloud.astro`) has its label translated on
      `/es/`/`/vi/`, but the pre-rendered narration it plays
      (`public/audio/main.mp3`, generated by `scripts/generate-audio.js`) is
      English-only regardless of page locale — a Spanish/Vietnamese visitor
      who activates it hears English. Either scope the button to the English
      route only, or generate per-locale narration once ElevenLabs
      generation is set up (see the read-aloud narration item elsewhere in
      this file).

### e2e test floor (2026-07-19)

The tracked change is the e2e testing floor (≥3 e2e per feature — happy
path / error / edge case — and all code tested) added to
`docs/TESTING.md`, the `testing` + `ci-green-gate` skills, project
`CLAUDE.md`, `audits/README.md`, and `WIKI.md`.

- [ ] **[P1]** **[Needs owner]** Commit the e2e-floor batch (commands in the
      2026-07-19 `0800-PST` session log). Caveat: those files already carried
      uncommitted `chore/bmad-method-setup` modifications, so per-file
      `git add` bundles both — `git add -p` to separate.
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

- [ ] **[P1]** **[Needs owner]** Ship the batch: commit
      `website/` + `.agents/context/DESIGN.md` + `TODO.md` on
      `feat/website-first-light`, push, open the PR (commands in the
      2026-07-19 `0600-PST` session log / final session reply). Agents never
      run `git`/`gh`.
- [ ] **[P1]** **[Needs owner]** Decide the pre-existing uncommitted
      `legal/*.md` diffs (doc-casing links, `<email>` formatting, maintainer
      name — they pre-date this session; no agent touched `legal/`): approve
      them to ride along or stash them out before committing. `legal/` edits
      require explicit owner approval per `CLAUDE.md`.
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

- [ ] **[P2]** **[Needs owner]** Commit the new hooks + settings change
      (git is owner-gated; copy-paste commands were provided in the
      2026-07-19 `0000-PST` session).
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
- [ ] **[P3]** **[Needs owner]** Review and reconcile the uncommitted
      `chore/bmad-method-setup` branch (46 new skills under `.claude/skills/bmad-*`,
      `_bmad/` core) — some overlap conceptually with this repo's existing review
      agents (`bmad-code-review` vs. `code-reviewer`/`security-reviewer`,
      `bmad-architecture` vs. `docs/ARCHITECTURE.md` + existing skills). Decide
      precedence, then commit/merge or discard.

### Signal Bridge motif follow-ups (2026-07-18)

- [ ] **[P1]** **[Needs owner]** Run `npm run test:a11y` (pa11y-ci) and a real
      VoiceOver pass over the new Signal Bridge section
      (`website/src/components/SignalBridge.astro`, between Hero and
      Features) on a machine with Chrome and a device available. This
      session could only verify heading hierarchy, `aria-labelledby`, and
      `aria-hidden` placement statically from the built HTML — `pa11y-ci`
      couldn't launch (no local Chrome binary for Puppeteer in this
      environment).
- [ ] **[P3]** `npm run format` (`prettier --check .`) fails on every
      `.astro` file, including pre-existing ones (`Hero.astro` hits the same
      "No parser could be inferred" error) — `prettier-plugin-astro` isn't in
      `devDependencies`. Pre-existing gap, not introduced this session; fix
      by adding the plugin (with a `.prettierrc` `plugins` entry) or
      knowingly excluding `.astro` from the format script.

### Signal Spine motion batch — accessibility review follow-ups (2026-07-18)

Full report:
`audits/accessibility/20260719-024433-website-first-light-batch-signal-spine-motion-choreography-sticky-header-a11y-review.md`
(local-only — `audits/**` is gitignored). One High finding (sticky header
obscuring the `#main` skip-link target, new WCAG 2.2 SC 2.4.11 exposure) was
fixed in-session (`website/src/styles/global/_base.scss`); these are the
remaining open items.

- [ ] **[P1]** **[Needs owner]** Re-run `scripts/generate-audio.js` before
      shipping this batch (once the ElevenLabs key from the narration item
      below is set) so `/audio/main.mp3` includes the new Signal Bridge
      section copy and the reworded FollowProgress copy — the device-voice
      read-aloud option already covers both live; only the pre-rendered
      natural-voice option is currently stale.
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
      once `/audio/main.mp3` exists, drive the Signal Spine pulse from
      narration progress while the natural-voice player runs. Blocked on the
      narration asset above.
- [ ] **[P3]** Read-aloud per-section segmentation + polite stage
      announcements ("Now: what it does today" etc., derived from h2 text) in
      the existing `#read-aloud-status` live region. Skipped in the motion
      batch because `read-aloud.ts` speaks one monolithic utterance —
      requires restructuring it into per-section segments first.
- [ ] **[P1]** **[Needs owner]** Ship the branch: stage + commit the
      uncommitted website batch, push `feat/website-first-light`, open the PR
      against `main` (commands handed over in the 2026-07-18 19:00 PST
      session log / final session reply).

### Website rebuild ("First Light" Astro site) follow-ups (2026-07-18)

- [ ] **[P1]** **[Needs owner]** Ship the rebuild: commit is prepared locally
      on a `feat/` branch (website/ + CI + docs + TODO) — push, open the PR,
      and merge after CI. Agents never push/PR autonomously.
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
- [ ] **[P2]** Add a regression guard for the verbatim safety disclaimer
      (it is hand-inlined in `website/src/components/Disclaimer.astro`; a CI
      grep of `dist/index.html` for the exact string — or a shared constant —
      would stop a future edit from silently breaking the verbatim
      guarantee).
- [ ] **[P3]** Refresh `.impeccable/design.json` from the rewritten
      `.agents/context/DESIGN.md` ("First Light" superseded "Quiet Signal"),
      then re-run `impeccable detect website` so its design-system detectors
      key off the current tokens, and revisit the deferred
      `/impeccable polish website` pass.

### Website read-aloud follow-ups (from the 1400 PST session, 2026-07-17 — backfilled; the session log had these but this file never did)

- [ ] **[P1]** **[Needs owner]** Generate the ElevenLabs narration (paths
      updated 2026-07-18 for the Astro rebuild): `cd website &&
      cp .env.example .env`, add a real `ELEVENLABS_API_KEY`, run
      `npm run build && npm run generate:audio`, then commit
      `public/audio/main.mp3` + `public/audio/manifest.json` together. The
      natural-voice button stays hidden on the live site until this exists.
      Afterwards re-run `npm run build && npm run check:audio` and confirm it
      reports a match instead of the informational skip.

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

### Agent role layer — global orchestrator/advisor/worker (2026-07-17, late session)

- [ ] **[P2]** **[Needs owner]** Commit the agent registrations sitting on
      this branch: the 9 project subagent shims under `.claude/agents/`
      (created 2026-07-17 evening, still untracked) plus this session's
      `SETUP-STATUS.md`/`TODO.md` updates. Blocked behind this file's P0
      filename-case rename item, which must land first on
      `chore/uppercase-markdown-filenames`. The three new role agents
      (`orchestrator`, `advisor`, `implementer`) live at `~/.claude/agents/`
      outside the repo — nothing to commit for those, but they are
      machine-local; recreate them on any new machine from
      `~/.claude/CLAUDE.md` §3's bullet if that machine is rebuilt.

### Claude/Obsidian integration follow-ups (2026-07-17, night session)

- [ ] **[P2]** **[Needs owner]** Commit the three new workflow commands
      (`.claude/commands/cleanup-notes.md`, `.claude/commands/session-log.md`,
      `.claude/commands/todo-groom.md`) and the matching `docs/TOOLING.md`
      "Workflow commands" row. Blocked behind this file's P0 filename-case
      rename item on `chore/uppercase-markdown-filenames`.

### Owner actions pending (from the `app/` scaffold session, 2026-07-17)

- [ ] **[P1]** **[Needs owner]** Make the repo public and recreate the
      "Protect main" ruleset — `GAPS.md` M5. Commands:
      `gh repo edit kevinle3212/sensebridge --visibility public
      --accept-visibility-change-consequences`, then confirm
      `gh api repos/kevinle3212/sensebridge/rulesets` no longer 403s, then
      recreate the ruleset per the settings in this file's "GitHub branch
      protection — ruleset setup" section.
- [ ] **[P1]** **[Needs owner]** Commit, push, and open a PR for this
      session's work (the `app/` scaffold, CI/lint fixes, doc corrections) —
      never run autonomously per `CLAUDE.md` § Branching and committing.
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

### First real Swift validation — partially done now that `app/` exists (2026-07-17)

- [ ] **[P1]** Run the Swift tooling against real `.swift` files, as the
      **first** Swift work done — before any volume of tests exists.
      Everything below was decided, written, and documented while the repo had
      **zero `.swift` files**; it is verified by grep, markdownlint, and
      reading upstream — **no compiler has ever run any of it**. That is not a
      hedge, it is the actual state, and it mirrors the rule in `CLAUDE.md`:
      never let a green pipeline imply validation nobody performed.

      Do it first, not eventually: the whole case for the Swift Testing
      decision is that migration cost is zero at zero tests. If a claim below
      is false, it is cheap to correct now and expensive after 200 tests.

      Each item is falsifiable — the point is to try to break the claim, not
      to confirm it:

      - [x] **Swift Testing runs at all.** `import Testing`, `@Test`,
            `#expect` compile and pass on the Swift 6 / iOS 26 toolchain
            (`docs/ENVIRONMENT.md`). Verified 2026-07-17: `swift test` on
            `app/Packages/SenseBridgeCore` (Swift 6.3.3, iOS 26 SDK).
      - [x] **Coexistence.** One Swift Testing test and one XCTest/XCUITest
            test in the same scheme both run in a single `xcodebuild test`.
            This is load-bearing: `docs/TESTING.md` → "Frameworks" calls the
            split *permanent, not transitional* on the strength of it. If they
            cannot coexist, that section is wrong and the decision reopens.
            Verified 2026-07-17: `xcodebuild test` on the `SenseBridge` scheme
            with no `-only-testing` filter ran `SenseBridgeTests` (Swift
            Testing) and `SenseBridgeUITests` (XCUITest) together —
            **TEST SUCCEEDED**.
      - [x] **`@Test(arguments:)`** works and names the failing input. This is
            the "matches the shape of our tests" argument. Verified 2026-07-17:
            `PhrasingTests.certaintyBucketing` output named each case, e.g.
            "Test case passing 2 arguments confidence → 0.1, expected → .low".
      - [ ] **Measure the parallelism claim.** `docs/TESTING.md` asserts Swift
            Testing parallelises in-process while XCTest clones simulators,
            and that this compounds into CI minutes. Time a fixture-heavy
            suite both ways rather than trusting the claim — it is the main
            cost argument, and it is currently only read, not measured.
      - [ ] **The vendored skill examples compile.** The code in
            `swift-concurrency-6-2`, `swift-actor-persistence`, and
            `swift-protocol-di-testing` came from upstream and was never built
            here. Check the suspicious ones specifically: `nonisolated struct`,
            `extension …: @MainActor Exportable` (isolated conformance), and
            the `@concurrent` example — the skill itself warns that one **has
            a data race** unless Approachable Concurrency (SE-0466, SE-0461)
            is enabled, so confirm those build settings are actually on before
            trusting it.
      - [ ] **Typed throws.** `throws(LoadError)` compiles — folded into
            `swift-reviewer` from ecc's rules, never built.
      - [ ] **The agents' commands run.** `swift-reviewer` shells out to
            `swift build`, `swiftlint lint --quiet`, `swift test`, and
            `swift-format lint`; `swift-build-resolver` to `xcodebuild`. Confirm
            `scripts/lint.sh` and the SwiftLint/SwiftFormat configs land with
            `app/` as `docs/TOOLING.md` promises, and that a review actually
            completes end to end. Partially verified 2026-07-17:
            `.swiftlint.yml`/`.swiftformat` now land with `app/` and
            `scripts/lint.sh` completes clean end to end (0 violations) — that
            script's project-detection had a real bug, fixed in the same
            change (see `GAPS.md` → Resolved). Still unverified: whether the
            `swift-reviewer`/`swift-build-resolver` **agents themselves**
            (not just the underlying commands) run correctly.
      - [ ] **Correct the docs to match reality**, not the other way round.
            `docs/TESTING.md` → "Frameworks" is the authority; if it is wrong,
            fix it there first, then propagate (`docs/TOOLING.md`, the
            `testing` / `ci-green-gate` / `swift-protocol-di-testing` skills,
            and both planning docs — `04` and `COMPLETE-PLAN` duplicate each
            other and must stay identical).

## In Progress

_Nothing currently in progress._

## Completed

- [x] `/impeccable critique website` — scored UX review of the marketing
      site (dual-assessment: design review + detector/browser evidence).
      Scored 30/40 (Good); follow-ups tracked above. Snapshot:
      `.impeccable/critique/2026-07-11T22-30-54Z__website-index-html.md`.
- [x] `/impeccable audit website` — a11y/perf/responsive technical checks
      on the marketing site. Scored 17/20 (Good); follow-ups tracked above.
- [x] **Done 2026-07-17 (late evening)** — Owner explicitly overrode the
      remaining skip decisions: installed hyperframes (8-skill core set,
      PostHog telemetry disabled pre-first-run), notebooklm-skill
      (files-only; bootstrap left to the owner), all 17 social-media-skills
      (markdown-only, verified), agent-browser CLI (Chrome fetch pending —
      permission-gated), the `privacy-legal` plugin from claude-for-legal
      (no hooks; Slack/GDrive connectors unauthenticated), and registered
      the Granola + Higgsfield hosted MCPs user-scope (both pending owner
      OAuth). Also removed the stale "Adam Framework" row from
      `docs/TOOLING.md`. Docs synced (`docs/TOOLING.md` second-wave section,
      plugin + MCP tables, `docs/NOTEBOOKLM.md` status update). gstack
      `/browse` remains the browsing default per the global standard.
- [x] **Done 2026-07-17 (evening)** — Canonical-source skill sync:
      `tools/sync-skills.mjs` (stdlib Node; regenerate + `--check` modes;
      data-driven per-harness substitution rules) now enforces that the
      hand-mirrored skills (`council`, `website-design`, `seo-schema`,
      `seo-technical`) cannot drift from their `.claude/skills/` canonicals —
      wired into `.githooks/pre-commit` and CI's docs-links job. Verified by
      injected-drift test (caught, repaired byte-identical). Impeccable stays
      vendor-managed and excluded.
- [x] **Done 2026-07-17 (evening)** — Re-evaluated all 16 previously skipped
      AI tools under the owner's new prefer-integration policy. Installed 7
      (stop-slop; 6-of-47 marketingskills subset; codex-plugin-cc plugin;
      claude-seo offline slice vendored as `seo-schema`/`seo-technical`;
      Perplexity documented per-dev; find-skills formalized), 9 remain out,
      each with a re-verified current blocker. Full outcomes in
      `docs/TOOLING.md`; attribution in `CREDITS.md`. Also added the
      `council`/`security-review`/`code-review` gate step to
      `website-design`'s flow (frontend-design routing now complete) and
      verified the GitNexus integration closed (CLI 1.6.9 + MCP + advisory
      hooks all live; VS Code "Nexus" extension confirmed unrelated).
- [x] **Done 2026-07-17** — Mirrored `council` and `website-design` skills
      (previously `.claude/skills/` only) to `.agents/skills/`, `.cursor/skills/`,
      `.gemini/skills/`, and `.github/skills/`, matching the impeccable
      multi-harness pattern, so Cursor/Gemini CLI/Copilot can invoke them
      too. Fixed the `audit-refresh` sibling link in each new `council` copy
      (only exists under `.claude/skills/`, so it now points there via
      `../../../.claude/skills/audit-refresh/SKILL.md`) and the impeccable
      cross-reference display text in each new `website-design` copy.
      Updated `AGENTS.md` and `docs/TOOLING.md` to reflect the new
      locations. Not adapted per-tool the way impeccable's `npx impeccable
      install` build differs by provider (invocation prefix, CLAUDE.md vs.
      AGENTS.md, etc.) — these are plain copies since neither skill had any
      other tool-specific content; `docs/TOOLING.md`'s `frontend-design`
      install command (`--agent claude-code`) is still Claude-Code-specific
      and left as-is rather than guessed for other tools.
- [x] **[P2]** Add `scroll-margin-top: space("7");` to `.bridge` in
      `website/src/components/SignalBridge.module.scss` — the new `#bridge`
      section is a valid headed anchor (unlike its three sibling stage
      sections, it never got this) and would land under the sticky header on
      any future nav link or external deep link to it.
      **Done 2026-07-18** — applied in-session; gate + pa11y re-run green.
- [x] **[P3]** Add `pointer-events: none;` to `.scroll-progress` in
      `website/src/components/Header.astro` — defensive hardening to match
      every other decorative overlay in this batch; no live click-
      interception found at current header spacing.
      **Done 2026-07-18** — applied in-session; gate + pa11y re-run green.
- [x] **[P0]** Finalize the actual git rename for the 6 `docs/` files this
      branch renamed to uppercase on disk. This checkout is on a
      case-insensitive APFS volume with `core.ignorecase=true`, so the
      plain renames done so far never registered as a git rename: `git
      status` still shows each file as **content-modified at its original
      lowercase path** (e.g. `docs/accessibility.md`, a 6-line diff), even
      though the file on disk is now named `docs/ACCESSIBILITY.md`.
      Verified by diffing `git ls-files` (git's tracked path) against a
      case-sensitive directory listing — exactly 6 mismatches:
      `docs/accessibility.md` → `ACCESSIBILITY.md`, `docs/ai-models.md` →
      `AI-MODELS.md`, `docs/architecture.md` → `ARCHITECTURE.md`,
      `docs/privacy.md` → `PRIVACY.md`, `docs/roadmap.md` → `ROADMAP.md`,
      `docs/safety-framing.md` → `SAFETY-FRAMING.md`. Committing as-is would
      ship a tree where the tracked filenames are still lowercase, so every
      uppercase reference already added throughout the repo this same
      branch (`README.md`, `AGENTS.md`, `CLAUDE.md`, `WIKI.md`, and ~30
      other files) would 404 on any case-sensitive checkout — including
      `.github/workflows/ci.yml`'s "Docs link check" job, which runs on
      `ubuntu-latest` (`ci.yml:86`); that job would fail on push. Fix: for
      each of the 6 files, force git to see an explicit rename — a
      case-only rename needs a two-step move on a case-insensitive
      filesystem, e.g. `git mv docs/accessibility.md
      docs/accessibility.md.tmp && git mv docs/accessibility.md.tmp
      docs/ACCESSIBILITY.md` (repeat per file), or run the batch with `git
      -c core.ignorecase=false mv <old> <new>`. Re-run `git status`
      afterward and confirm each shows as `renamed:` (or `new file` +
      `deleted`), never `modified`. **Done 2026-07-19** — ran the two-step
      temp-name `git mv` trick for all 6 files (repo owner explicitly
      authorized running `git mv` this turn). Verified via `git status
      --short docs/` showing all 6 as `R` (renamed), not `M`.
- [x] **[P1]** Once the rename above lands, fix the remaining stale
      lowercase `docs/*.md` references that survived this branch's
      reference-update pass (grep for
      `docs/(accessibility|architecture|privacy|roadmap|safety-framing)\.md`
      once the 6 renamed files' own tracked paths no longer match):
      `REVIEW.md:20,24,27` (`safety-framing.md`, `accessibility.md`,
      `privacy.md`), `SETUP-STATUS.md:59` (`architecture.md`),
      `.coderabbit.yaml:10` (`safety-framing.md`), `website/README.md:8,47`
      (`safety-framing.md`, both occurrences), `.agents/context/PRODUCT.md:76`
      (`safety-framing.md`), `website/eslint.config.mjs:57` (code comment,
      `safety-framing.md`), `.claude/commands/security-review.md:31`
      (`privacy.md`), `.agents/skills/swift-actor-persistence/SKILL.md:26`
      (`privacy.md`), and the `council` skill's `docs/privacy.md` reference
      at line 64 in **all 5** mirrored copies (`.claude/skills/council`,
      `.agents/skills/council`, `.cursor/skills/council`,
      `.gemini/skills/council`, `.github/skills/council`) — same fix needed
      in each, per the multi-harness mirroring pattern already documented
      below under "Agentic-file audit follow-ups". **Done 2026-07-19** —
      fixed all 21 stale references (the 9 listed above plus 12 more the
      same-session grep also found: 9 Swift doc-comments under `app/` and
      one unrelated pre-existing broken relative link caught mid-edit in
      `.claude/commands/security-review.md`; full list in the 2026-07-19
      `1200-PST` session log). Re-verified: zero stale lowercase
      `docs/*.md` references remain outside this file's own historical
      narrative.
- [x] **[P2]** Docker build verification. **Done 2026-07-18** — Dockerfile
      rewritten multi-stage (Astro build → non-root static serve of `dist/`);
      `docker build` succeeded and a container smoke test returned HTTP 200
      with the disclaimer present on port 3000.
- [x] **[P0]** `/impeccable harden` — Safety disclaimer semantics.
      **Resolved 2026-07-18** by the Astro rebuild:
      `website/src/components/Disclaimer.astro` wraps the verbatim copy in
      `<aside role="note" aria-label="Safety disclaimer">`; routed through the
      `safety-framing-reviewer` agent (full PASS, zero findings).
- [x] **[P1]** `/impeccable clarify` — Footer CTA. **Resolved 2026-07-18**:
      `website/src/components/Footer.astro` has the descriptive
      "SenseBridge on GitHub" link plus pre-launch fine print.
- [x] **[P1]** `/impeccable onboard` — Visible pre-launch sentence.
      **Resolved 2026-07-18**: hero status line ("SenseBridge is in open
      development and not yet available to download…") plus footer fine print.
- [x] **[P2]** `/impeccable distill` — 5 `<li>` vs ≤4 chunking guideline.
      **Closed by decision 2026-07-18**: all five kept deliberately — they are
      the real capability list and trimming one would misstate scope
      (honesty > chunking); the scroll reveal staggers them one-by-one, which
      provides the temporal chunking the guideline is after.
- [x] **[P2]** `/impeccable layout` — 320px overflow risk. **Resolved
      2026-07-18**: header/nav use `flex-wrap` + `gap`; the rebuilt layout is
      responsive down to 320px (single-column below the 48rem breakpoint).
- [x] **[P1]** `/impeccable typeset` — Heading typography. **Superseded
      2026-07-18** by the "First Light" rebuild: hero H1 uses the Inter
      Variable display face (600, `clamp(2rem…3.5rem)`, 1.1 line-height,
      -0.02em tracking) from `Hero.module.scss`; the old "Quiet Signal"
      400-weight spec no longer applies.
- [x] **[P1]** `/impeccable layout` — Header divider. **Resolved
      2026-07-18**: `border-bottom` sits on `.site-header` itself
      (`website/src/components/Header.astro`), spanning full width.
- [x] **[P2]** `/impeccable adapt` — Nav responsive handling. **Resolved
      2026-07-18**: `flex-wrap` + `gap` on both `.site-header .wrap` and
      `nav` in the rebuilt Header.
- [x] **[P2]** `/impeccable polish` — Nav link color. **Superseded
      2026-07-18**: "First Light" documents links as Signal Blue everywhere
      (the global `a { color: accent-primary }` in
      `src/styles/global/_base.scss` is now the spec, not a divergence);
      DESIGN.md's rewrite reflects this.
- [x] **[P2]** `/impeccable polish` — `color-scheme: dark`. **Resolved
      2026-07-18**: set on `html` in `src/styles/global/_base.scss`.
- [x] **[P2]** `/impeccable typeset` — The `.disclaimer` callout set
      `font-size: 0.9375rem` (15px), not a documented step on `DESIGN.md`'s
      type ramp. Three-way drift: the CSS used it, `.impeccable/design.json`
      recorded it, `DESIGN.md` never documented it. **Fixed 2026-07-16** by
      dropping the override so the callout inherits `body` (1rem) — the
      on-ramp step — rather than documenting a 5th step, which would have
      worsened the existing `flat-type-hierarchy` finding (14/15/16/18px).
      Size moved _up_ (15px → 16px): this element carries the safety-framing
      disclaimer, so it must never be the smallest text on the page. Copy
      untouched, so no safety-framing review was required. Made the rule
      explicit in `DESIGN.md` (callout now declares
      `typography: "{typography.body}"` plus a stated floor) and refreshed
      `design.json`. Verified: `impeccable detect website` 4 → 3 findings,
      `design-system-font-size` gone.
      **Only surfaced 2026-07-16**, once `DESIGN.md` actually resolved; the
      detector's design-system rules had been silently inert before that,
      which is also why the 2026-07-11 critique snapshot's "zero drift
      between the documented system and the shipped code" claim was never
      actually tested for type.
- [x] **[P1]** Impeccable read `docs/PRODUCT.md` (the **iOS app's** product
      doc) as the design context for **website** work, and found no
      `DESIGN.md` at all — so every `/impeccable` run on the site was primed
      with the wrong product and no design system. **Fixed 2026-07-16** by
      moving the site's context to `.agents/context/PRODUCT.md` +
      `.agents/context/DESIGN.md` (impeccable checks `.agents/context/`
      before `docs/`, so it now resolves deterministically), each with a
      scope header distinguishing it from `docs/PRODUCT.md`. Verified:
      `loadContext()` reports `productPath: .agents/context/PRODUCT.md`,
      `designPath: .agents/context/DESIGN.md` (was `docs/PRODUCT.md` /
      `null`). Rejected alternatives and the reasoning are in
      `docs/TOOLING.md` → "Impeccable design context".
- [x] **[P2]** Cherry-pick the Swift skills/agents from
      [`affaan-m/ecc`](https://github.com/affaan-m/ecc) (v2.0.0, commit
      `ed38744`, MIT). **Done 2026-07-16** — vendored 5 of the 10 planned
      files: skills `swift-concurrency-6-2`, `swift-protocol-di-testing`,
      `swift-actor-persistence`; agents `swift-reviewer`,
      `swift-build-resolver`. Each was adapted, not copied: conformed to house
      style (skills gained the `tool-fallback` / `clarify-before-acting`
      blocks; agents lost their YAML frontmatter, since all 7 existing agents
      are plain markdown), had upstream's broken references rewritten, and
      gained a header naming the SenseBridge invariant it serves. Attribution
      + the MIT notice are in `CREDITS.md` (MIT is compatible with this
      repo's Apache-2.0). Verified: markdownlint 0 errors, all links resolve,
      `gitleaks --no-git` clean, `check-sensitive-files` clean on the staged 5.
      **Note:** these are preparation — the repo has **zero `.swift` files**
      today, so none of this is exercised until `app/` exists.

- [x] **[P3]** Resolve `rules/swift/*.md` — **content folded in, files not
      vendored. Done 2026-07-16.** The 5 files were not copied, because
      nothing here reads a `rules/` tree or their `paths:` frontmatter (it
      would be dead weight), and each is a stub extending a `rules/common/*`
      tree that was never in scope. Instead every claim in them was audited
      individually and routed. Nothing was dropped silently:

      **Folded in (was genuinely absent from this repo — verified by grep):**

      - Apple API Design Guidelines naming + "`static let` over global
        constants" → new "MEDIUM - Naming" section in `swift-reviewer`.
      - Typed throws (Swift 6 `throws(LoadError)`) → `swift-reviewer`, CRITICAL
        Error Handling.
      - Enum-with-associated-values for state → `swift-reviewer`,
        Protocol-Oriented Design.
      - Force-unwrapped `URL(string:)!`, and validation of deep links /
        pasteboard / imported files / OCR text → `swift-reviewer`, CRITICAL
        Safety. Reframed: these are the *realistic* untrusted-input surfaces
        for an app with no network.
      - Test isolation, table-driven cases, `swift test
        --enable-code-coverage` → the [testing](.agents/skills/testing/SKILL.md)
        skill.

      **Already covered, so not duplicated** (a rule stated twice drifts into
      two rules): SwiftFormat/SwiftLint (`docs/TOOLING.md`), `let` over `var`,
      `struct` over `class`, hardcoded secrets, Keychain-not-`UserDefaults`
      (`SECURITY.md`, `docs/ENVIRONMENT.md`), ATS, injection, `print()` →
      `os.Logger`, `Sendable`, structured concurrency, protocol-oriented
      design (`AGENTS.md`, `api-design`), and DI-by-default-parameter.

      **Rejected, on doctrine:**

      - Certificate pinning / "validate all server certificates" — presumes a
        server. SenseBridge is serverless; a finding here is an architecture
        violation, not a practice to adopt. `swift-reviewer` already carries an
        "On-device caveat" saying exactly that.
      - `.xcconfig` for build-time secrets — would add a third secret
        location beside the established two (Keychain on-device, GitHub Actions
        secrets in CI, per `docs/ENVIRONMENT.md`). A third place to look is a
        security regression, not a feature.
      - `rules/swift/hooks.md` in full — it configures `~/.claude/settings.json`,
        the user's global machine config, which a repo file has no business
        owning. Its one novel claim (`print()` → `os.Logger`) was already in
        `swift-reviewer`.

- [x] **[P3]** Adopt **Swift Testing** for unit + integration; keep **XCTest**
      for end-to-end and performance. **Decided 2026-07-16**, while the repo
      had zero `.swift` files — the cheapest this decision will ever be.
      Rationale, all cost-as-it-grows: migration cost is zero now and rises
      with every test written; Swift Testing parallelises in-process while
      XCTest clones simulators, which compounds into CI minutes on
      fixture-heavy suites; and `@Test(arguments:)` matches the shape our tests
      actually take (one assertion across N fixtures — reading-order cases,
      hedging phrasings, perception fixtures) instead of N copy-pasted methods.
      The split is **permanent, not transitional**: `XCUITest` and `XCTMetric`
      have no Swift Testing equivalent, and the two frameworks coexist in one
      target. Requires the Swift 6 toolchain, already mandated by
      `docs/ENVIRONMENT.md`. Authority + reasoning now live in
      `docs/TESTING.md` → "Frameworks"; propagated to `docs/TOOLING.md`, the
      `testing` and `ci-green-gate` skills, `swift-protocol-di-testing`, and
      both planning docs (04 + COMPLETE-PLAN, which duplicate each other).
      Verified: zero remaining XCTest references outside the E2E/performance
      layer.

- [x] **[P3]** Docs sync for the 3 global skills installed 2026-07-13
      (`context-budget`, `production-audit`, `agent-architecture-audit`) that
      the ECC arc had deferred to land alongside this Swift cherry-pick.
      **Done 2026-07-16.** All three were bare `SKILL.md` files in
      `~/.claude/skills/` with zero mention anywhere in the repo. Added a
      "Global skills — standalone, unattributed" section to
      `docs/TOOLING.md`, documenting each and — since unlike every plugin in
      the table above them, none has a plugin manifest, marketplace entry,
      version, or `LICENSE` — flagging that their provenance couldn't be
      verified, rather than silently filing them under the "source-verified
      marketplaces" table. Also caught and documented a name collision:
      the same batch placed a generic WCAG `accessibility` skill globally,
      shadowed for SenseBridge work by the pre-existing, more specific
      `.agents/skills/accessibility`. A 4th skill from the same 07-13 batch
      (`swift-*` content) was already covered by the cherry-pick items above.
- [x] **[P1]** De-duplicate the 5 independent copies of the `impeccable`
      skill. **Resolved 2026-07-16 — the premise was wrong, not the
      files.** A full pairwise diff (all 5 trees, all 102 shared files,
      normalizing out expected per-provider substitutions before comparing)
      found **zero accidental drift**. Every difference across the 5 copies
      is correct, vendor-generated, per-provider content from `npx
      impeccable` (installed skill version 3.9.1 in all 5, confirmed current
      via `npx impeccable check`): invocation prefix (`$impeccable` for
      Codex CLI vs `/impeccable` elsewhere), self-referential script paths,
      the model-name line, the project-context filename (`AGENTS.md` vs
      `CLAUDE.md`), harness-specific frontmatter (`license`,
      `user-invocable`, `allowed-tools`), and entire Codex-only sections
      (sub-agent/sandbox-permission guidance, "Codex-specific defects").
      `.agents/skills/impeccable/agents/*.toml` + `agents/openai.yaml` are
      Codex-CLI-specific sub-agent configs the installer places only in
      `.agents/` by design.
      **Why the original diagnosis was wrong:** the 2026-07-11 audit spot-
      checked two files and assumed the differences meant independent hand-
      edits drifting apart. They don't — they're the correct output of the
      same `impeccable` release, templated per provider.
      **What this means going forward:** don't hand-edit any one copy (it
      fights the next `npx impeccable update` and desyncs the others); run
      `npx impeccable check` to detect real version drift and `npx
      impeccable update` to refresh all installed copies together. No
      custom sync script or git hook needed — the vendor CLI already is
      that mechanism. Documented in `docs/TOOLING.md`'s "Impeccable
      design-QA" row.
      **Side effect, since reviewed and kept:** running `npx impeccable
      update --help` / `install --help` during this investigation did not
      respect `--help` on those subcommands and performed real (idempotent,
      additive) work — it wrote `.cursor/hooks.json` and
      `.github/hooks/impeccable.json`, wiring the same UI-detector hook
      already active for Claude via `.claude/settings.json` into Cursor and
      GitHub Copilot too. Security-reviewed 2026-07-16 and kept:
      `.github/skills/impeccable/scripts/hook.mjs` is **byte-identical**
      (sha256 `6ffed896…`) to the Claude copy already approved and running,
      and neither entrypoint has any network or process-spawn surface (the
      sole `spawn` grep hit is a comment). Same vendor detector, two more
      harnesses — no new code, no new trust boundary.
- [x] Configure Railway hosting for `website/`, expanding the general
      Railway flow (create project → connect repo → build/run config → env
      vars → deploy) into repo-specific steps. Added
      `website/Dockerfile` (Node 22 + `serve`, matching the existing local-
      preview command, PORT-aware for Railway), `website/.dockerignore`, and
      `website/railway.toml` (Dockerfile builder, restart-on-failure
      policy). Documented the full first-time-setup flow — including
      setting the Railway service's Root Directory to `website` since the
      repo root also holds the iOS app — in `website/README.md`'s
      Deployment section, which previously just said "not yet configured."
      No env vars needed: the site has no backend/accounts/telemetry (see
      `CLAUDE.md`'s architecture invariants). **Verified 2026-07-16**:
      `docker build -t sensebridge-website website` succeeds and `docker run
      -p 3000:3000 -e PORT=3000 sensebridge-website` serves `index.html`
      with `HTTP 200`.
- [x] Configure a GitHub ruleset protecting `main`, closing `GAPS.md` M2.
      **Done 2026-07-17.**

      **Correction, same day:** re-checking this against the live repo via
      `gh api repos/:owner/:repo/rulesets` returned `403 — Upgrade to GitHub
      Pro or make this repository public to enable this feature`. Rulesets
      aren't available on a private Free-tier repo, so this configuration
      either never took effect or was verified against the wrong state. See
      `GAPS.md` M5 for the open item and `SETUP-STATUS.md` for the exact
      commands to make the repo public and re-verify/recreate this ruleset.
      The settings below remain the target configuration once that's done.

      **Ruleset "Protect main"** — target: default branch; enforcement:
      Active; bypass list: empty (no exceptions, including the owner —
      matches `AGENTS.md`'s "never commit directly to main").

      - Restrict deletions — enabled.
      - Restrict force pushes — enabled.
      - Require linear history — enabled (squash-only merges).
      - Require signed commits — **disabled for now.** Commit history isn't
        GPG-signed yet; enabling this would block every push including the
        owner's. Revisit once commit signing is set up.
      - Require a pull request before merging — enabled.
        - Required approvals: **0**. `CODEOWNERS` is solely `@kevinle3212`
          (solo-maintained per `GOVERNANCE.md`); requiring 1 approval with no
          second reviewer would deadlock every PR. Raise to 1 the moment a
          co-maintainer or second CODEOWNER exists.
        - Dismiss stale approvals on new commits — enabled (pre-set,
          currently moot at 0 required approvals).
        - Require review from Code Owners — disabled (same reasoning; enable
          alongside the approval count).
        - Require approval of most recent push — enabled (pre-set).
        - Require conversation resolution before merging — enabled.
        - Allowed merge methods — squash only.
      - Require status checks to pass — enabled; require branches up to date
        — enabled. Required checks (exact names from workflow `name:`
        fields):
        - `Build and test` (CI)
        - `Lint (SwiftFormat + SwiftLint)` (CI)
        - `Docs link check` (CI)
        - `Secret scan (TruffleHog)` (Security)
        - `Dependency scan (OSV)` (Security)
        - `Sensitive file scan` (Security)
        - `Semgrep (scripts, workflows, website, Swift)` (Security)
      - Require deployments to succeed — disabled (no gating environment).
      - Require code scanning results — disabled (Semgrep/TruffleHog run as
        plain Actions, not GitHub's native code-scanning integration).

      **Deliberately not required:**
      `Stylelint + ESLint + Prettier` / `Impeccable design detectors`
      (`website-ci.yml`) are path-filtered to `website/**` — requiring a
      check that doesn't trigger on non-website PRs would block merge
      forever (no path-conditional required checks in GitHub Rulesets).
      `review` (`claude-code-review.yml`) is an AI first-pass, not a
      deterministic gate, and its `ANTHROPIC_API_KEY` auth is still
      unverified as reliable per `GAPS.md` M1 — revisit once M1 closes.

      **Adjacent repo settings** (Settings → General → Pull Requests):
      squash merging only (merge commits and rebase merging disabled to
      match "require linear history"); "Allow auto-merge" enabled (needed by
      `dependabot-automerge.yml`); "Automatically delete head branches"
      enabled.

      **Not done:** a tag-protection ruleset for release tags (`v*`) — no
      tags exist yet; deferred until `docs/DISTRIBUTION.md`'s release
      process actually starts cutting them.

      Propagated to `SETUP-STATUS.md` (branch protection moved from
      "pending" to "set up") and `GAPS.md` (M2 moved to Resolved).

---

Need help? See [`SUPPORT.md`](SUPPORT.md).
