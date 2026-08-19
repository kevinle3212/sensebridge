# TODO

Lightweight personal reminders, grouped by status: **To-Do**, **In Progress**.
Finished work lives in [`COMPLETED.todo`](COMPLETED.todo), never here. Tracked
defects/debt/risks live in [`GAPS.md`](GAPS.md); this file is just a short
list of things to come back to.

Within To-Do, items stay grouped by the review/audit that produced them and
ordered so earlier work unblocks later work.

**Item Completion** Don't just flip `- [ ]` to `- [x]`. Append, in bold, the
completion date plus what was actually done (and any verification, links, or
follow-on notes): `**Done/Fixed YYYY-MM-DD** — <what changed, how it was
verified, anything relevant left over>`. Ticking is all you have to do by
hand: `npm run todo:sweep` cuts every ticked bullet straight out of its To-Do
dated section into [`COMPLETED.todo`](COMPLETED.todo), grouped by day. To-Do
holds only open work; TODO.md never holds a completed one.

## Legend

| Label | Meaning |
| --- | --- |
| **P0** | Blocking — violates a hard gate (accessibility, safety-framing, security). Fix before anything else here. |
| **P1** | High priority — user-facing gap or incorrect behavior; no hard gate violated. |
| **P2** | Medium priority — spec/design fidelity or polish; non-blocking. |
| **P3** | Low priority — already decided/documented, or blocked on other work; revisit opportunistically. |
| **Needs owner** | Requires the repo owner specifically — a GitHub web-UI action, a `git`/`gh` command (agents never run these autonomously), Apple Developer credentials, a physical device, a human tester, or a decision only they can make. Combine with a priority, e.g. `**[P1]** **[Needs owner]**`. |

## Open queue (summary)

**133 open** as of **2026-08-17**, of which **103 are `Needs owner`**
(blocked on credentials, device access, a human tester, or a decision only
Kevin can make) and **30 are agent-actionable**. Both halves are now counted
rather than carried forward: the total is `grep -cE '^[[:space:]]*- \[ \] '`,
and the split is `grep -c 'Needs owner]'` less the one example in the Legend
table above. The previous line read 104/27, which was two off in each
direction — carrying a hand-maintained split across four passes had drifted it. This is a signpost, not a second source of truth —
every item is detailed in its dated section under **To-Do** below; act from
there. `npm run todo:sweep:check` only reports whether completed items need
sweeping; it does not reprint the count.

## To-Do

### Device install is blocked on Xcode signing (2026-08-18, 13:30 PST)

From [`sessions/2026-08-18/1330-PST.md`](sessions/2026-08-18/1330-PST.md).

- [ ] **[P1]** **[Needs owner]** **Sign Xcode back in so `npm run app:install`
      can complete.** `xcodebuild` for the device fails at signing with
      `error: No Accounts: Add a new account in Accounts settings.` and
      `No profiles for 'com.sensebridge.app' were found`. A codesigning identity
      exists (`security find-identity -v -p codesigning` returns one), so the
      certificate is fine — Xcode simply has no Apple ID account to fetch or
      create a provisioning profile with. Fix in Xcode → Settings → Accounts.
      If the profile still will not issue afterwards, add a prefix of your own
      to the gitignored `app/Config/Signing.local.xcconfig`, which currently
      sets `DEVELOPMENT_TEAM` but not `BUNDLE_ID_PREFIX`, so every device build
      tries to sign `com.sensebridge.app` — see that file's own comment. Until
      this clears, **no `app/` change since 2026-08-18 has been validated on
      hardware**, only in the Simulator.

- [ ] **[P2]** **[Needs owner]** **Decide whether an on-screen caption should
      expire.** `CaptionRenderTarget` holds the last text until a capture
      replaces it, so it survives navigation to another feature — a Deaf user
      can be looking at a sentence from the screen they left. That matches how
      each feature's own `lastResult` already behaves, but it is a different
      semantic from speech, which is transient by nature. Either is defensible;
      the caption's doc comment should state whichever is chosen.

### Deaf visual captions need owner staging (2026-08-18, 12:00 PST)

- [ ] **[P1]** **[Needs owner]** **Stage the new caption sources before a
      clean checkout can deliver the Deaf profile.** The implementation adds
      `app/SenseBridge/App/CaptionRenderTarget.swift` and
      `app/SenseBridge/App/CaptionOverlay.swift`; both are registered in
      `app/SenseBridge.xcodeproj/project.pbxproj` but are untracked in the
      current worktree. Run:
      `git add app/SenseBridge/App/CaptionRenderTarget.swift app/SenseBridge/App/CaptionOverlay.swift app/SenseBridge.xcodeproj/project.pbxproj app/SenseBridge/App/AppEnvironment.swift app/SenseBridge/App/SenseBridgeApp.swift app/SenseBridge/Features/Labeling/LabelingView.swift app/SenseBridge/Features/SceneDescription/SceneDescriptionView.swift app/SenseBridge/Features/Reading/ReadingSession.swift app/Packages/SenseBridgeCore/Sources/SenseBridgeCore/Output/RenderTarget.swift app/Packages/SenseBridgeCore/Sources/SenseBridgeCore/Output/MultiRenderTarget.swift app/SenseBridgeTests/AppEnvironmentTests.swift app/SenseBridgeUITests/SenseBridgeUITests.swift docs/ARCHITECTURE.md README.md PROJECT_OVERVIEW.md GAPS.md TODO.md`.
      Then rerun `xcodebuild -project app/SenseBridge.xcodeproj -scheme SenseBridge -sdk iphonesimulator -configuration Debug build CODE_SIGNING_ALLOWED=NO`; it must end with `BUILD SUCCEEDED`.

### Untracked scripts break `npm run check` on a fresh checkout (2026-08-17, 16:10 PST)

From [`sessions/2026-08-17/1610-PST.md`](sessions/2026-08-17/1610-PST.md). Found
by the new `check:npm-script-files` gate, which fails on its own repository and
is meant to. Nothing here is a code defect — every file exists and every test
passes locally. The defect is that three of them have never been staged, so a
clone gets a `package.json` invoking modules that are not in the tree. Away mode
is armed, and `git add` is a repository write, so an agent cannot clear it.

- [ ] **[P1]** **[Needs owner]** **Stage the three untracked scripts that
      `package.json` already invokes.** `tools/check-npm-script-files.mjs`
      (referenced by `check:npm-script-files`),
      `tools/check-deepseek-bridge.mjs` (`check:deepseek-bridge`), and the
      pre-existing `tools/check-codegraph-perms.mjs` (`check:codegraph`,
      `codegraph`, `codegraph:perms`, `codegraph:sync`). The last one predates
      this session — it has been referenced by four npm scripts while untracked
      for as long as those scripts have existed, so every fresh checkout has had
      a broken `npm run check:codegraph`. Also stage all three suites under
      `tools/tests/`: the whole directory is untracked, so on a clone both
      `check:tools-tests` and `lint:mjs` expand their globs to nothing and pass
      without running anything. Staging alone fixes the gate, because
      `git ls-files` counts the index, not just `HEAD`. Copy-paste command in
      [`tmp/handoff-away.md`](tmp/handoff-away.md) under "Needs you". Verify:
      `npm run check:npm-script-files` prints `present and tracked` and exits 0,
      then `npm run check` runs the full chain green.

- [ ] **[P2]** **[Needs owner]** **Decide whether `tools/tests/` belongs in
      the repository at all.** The gate now fails on it, so this is no longer
      silent, but the underlying call is still yours: track the directory
      (recommended — the three suites are real regression coverage and are worth
      nothing if they never reach CI), or, if they are deliberately local-only,
      drop `check:tools-tests` from the `check` chain and say so in
      [`docs/TESTING.md`](docs/TESTING.md), so the chain stops implying coverage
      it does not have. Verify: whichever you choose,
      `npm run check:npm-script-files` exits 0.

### OmniRoute provider wiring — blocked on admin auth (2026-08-17, 15:00 PST)

From [`sessions/2026-08-17/1500-PST.md`](sessions/2026-08-17/1500-PST.md). The
machine-wide `.env` audit is complete and a verified loader script exists; the
load itself cannot run. This supersedes the "Decide what consumes OmniRoute"
item below — the consumer is now decided (Claude Code, subscription-first with
API-key fallback), it is just not built.

- [ ] **[P1]** **[Needs owner]** **Give OmniRoute an admin credential so writes
      stop returning `401`.** `omniroute keys add` fails for every provider
      because `/opt/homebrew/lib/node_modules/omniroute/.env` defines no
      `MANAGEMENT_TOKEN`, `OMNIROUTE_API_KEY`, or `ADMIN_PASSWORD`. Reads work
      only because the CLI queries `~/.omniroute/storage.sqlite` directly.
      `doctor` concurs: *"health endpoint returned 401, likely requires
      MANAGEMENT_TOKEN."* The hardened backup
      `~/.config/omniroute-env.backup.20260812` does not carry one either, so
      this is not an upgrade wiping a token that once existed. Options, best
      first: set `MANAGEMENT_TOKEN` then `omniroute restart` and run the loader;
      or add providers through `omniroute dashboard` (owner login, manual); or
      `omniroute setup --password` — untested here, mutates admin state on a
      running server, and will likely `401` too.

      **Update 2026-08-18:** a fourth option, better than all three above and
      missed on the first pass — `omniroute connect localhost --scope admin
      --name default` runs the password flow against the *local* server, mints a
      scoped access token, and saves it into the `default` context. No `.env`
      edit, no restart, nothing mutated server-side. It needs only the admin
      password. `omniroute contexts list` currently shows `default` with
      `Auth ✗`, which is precisely why every admin route answers `401` while
      `keys list` and `models` still work.

- [ ] **[P1]** **[Needs owner]** **Do not connect Claude Code / Codex OAuth
      until the encryption-key item below is settled.** Requested 2026-08-18:
      wire both subscription CLIs to OmniRoute globally. Blocked on the same
      `401`, but it carries a sharper version of the at-rest risk: an OAuth
      connection stores a live **subscription refresh token** for the Anthropic
      and OpenAI accounts in `~/.omniroute/storage.sqlite`, not a revocable
      per-service API key. If `STORAGE_ENCRYPTION_KEY` is empty, those land
      unencrypted in a 1.7 MB SQLite file that is also backed up under
      `~/.omniroute/db_backups/`. `omniroute oauth providers` confirms both are
      `device` flow, so each needs a browser approval from the owner regardless.
      Runnable sequence, re-runnable and verified in `--check` mode:
      `bash tmp/omniroute-setup.sh`. Verify: `omniroute oauth status` lists both
      providers without a `401`.

- [ ] **[P1]** **[Needs owner]** **Confirm `STORAGE_ENCRYPTION_KEY` is non-empty
      *before* loading any provider key.** This gates the item above and is the
      security-relevant half. The existing P1 below warns that a global upgrade
      restores shipped defaults including an **empty** `STORAGE_ENCRYPTION_KEY`,
      which writes provider credentials unencrypted at rest. `doctor` reports
      that existing encrypted samples decrypt, but that says nothing about what a
      *new* write would do, and the `.env` deny-rule hook blocked the read needed
      to check the current value. Loading six provider keys into a store that
      might not encrypt them is the wrong order of operations.

- [ ] **[P3]** **Report two OmniRoute defects upstream (v3.8.48).**
      `omniroute setup --list` crashes with `Cannot find package
      '@omniroute/open-sse' imported from .../src/shared/constants/cliTools.ts`,
      consistent with a partial global upgrade — `config list` covers the same
      ground and works. Separately, `doctor` warns dashboard port `20128` is
      "already in use" when the listener is OmniRoute's own (node PID 33755), a
      cosmetic self-detection bug.

### Read + Awareness build-out — follow-ups (2026-08-13, 22:00 PST)

Feature work, tests, and docs all landed and are green (`swift test` 318/318,
`npm run app:test` 31/31, `npm run lint && npm run check` clean). What remains
needs a person, not a commit.

- [ ] **[P1]** **[Needs owner]** **Native-speaker review of the 69 new `es`
      and `vi` keys** added for Read playback/history and the awareness
      direction, proximity, and session-summary copy
      (`app/Packages/SenseBridgeCore/Sources/SenseBridgeCore/Resources/Localizable.xcstrings`
      and `app/SenseBridge/Resources/Localizable.xcstrings`).
      `check:catalog-coverage` proves each key *has* a translation; nothing
      proves the hedges still read as hedges. The doctrine-pinned strings in
      [`docs/superpowers/specs/2026-07-19-LANGUAGE-SUPPORT-DESIGN.md`](docs/superpowers/specs/2026-07-19-LANGUAGE-SUPPORT-DESIGN.md)
      are the ones that matter most: a hedge that reads as a flat assertion in
      Spanish or Vietnamese is a safety-framing defect, not a copy nit.
- [ ] **[P2]** **[Needs owner]** **Device validation of the awareness
      geometry**, per
      [`docs/TESTING.md`](docs/TESTING.md) "What only a device can settle":
      which third is really the user's left, whether the proximity pulse reads
      as "getting nearer" in the hand, whether the auto-torch threshold suits a
      real dim room, and whether "next" lands between sentences.

### Claude Code URL-handler stub fails Gatekeeper (2026-08-13, 14:00 PST)

From [`sessions/2026-08-13/1400-PST.md`](sessions/2026-08-13/1400-PST.md).
Diagnosis is complete; nothing was modified, per the read-only ask.

- [ ] **[P3]** **[Needs owner]** **Report the `Claude Code URL Handler.app`
      signing defect upstream via `/bug`.** `~/Applications/Claude Code URL
      Handler.app` fails `codesign --verify` with `code has no resources but
      signature indicates they must be present`: the stub the CLI installer
      writes has no `Contents/_CodeSignature/CodeResources`, while the binary it
      symlinks to carries a bundle-style, resource-sealing Developer ID
      signature. macOS reports it as "damaged" whenever a `claude-cli://` deep
      link asks LaunchServices to open it; the terminal CLI is unaffected
      because direct `exec` skips bundle verification. Optional stopgap:
      `codesign --force --deep -s - "$HOME/Applications/Claude Code URL Handler.app"`,
      which the next CLI update will undo.

### Global orchestration pipeline — follow-ups (2026-08-13, 12:00 PST)

From [`sessions/2026-08-13/1200-PST.md`](sessions/2026-08-13/1200-PST.md) and
[`1300-PST.md`](sessions/2026-08-13/1300-PST.md). The doctrine change, the
SenseBridge sync, and the device-install concurrency fix are done and verified;
these are what is left.

- [ ] **[P3]** **Confirm the draft → review pipeline earns its extra call.**
      `~/.claude/CLAUDE.md` → "Plans and durable state" now routes plan-writing
      through a Sonnet 5 · high drafter before the Opus 5 · high review. Nothing
      machine-checks that this beats Opus planning directly. On the next few
      substantive multi-step tasks, note whether the review step actually finds
      gaps in the draft; if it consistently finds none, collapse step 1.

### Tooling round 2 — CodeGraph, OmniRoute, browser tier (2026-08-12, 23:00 PST)

From [`sessions/2026-08-12/2300-PST.md`](sessions/2026-08-12/2300-PST.md). The
configuration work is done and verified; these are the decisions left over.
Note the earlier "Decide whether to retire `graphify`" and "Close out the
CodeGraph trial" items below now have measured evidence behind them.

- [ ] **[P1]** **Needs owner: disconnect unused `claude.ai` account connectors
      to cut per-turn token overhead.** Machine/account-level, not SenseBridge
      code — logged here per `AGENTS.md`'s "any substantive follow-up...
      also goes into TODO.md." Full audit in `sessions/2026-08-01/2300-PST.md`
      and `tmp/AWAY-REPORT.md` (this file may be gone by the time you read
      this — `tmp/` is cleared once work ships).

- [ ] **[P2]** **[Needs owner]** **Retire `graphify`, or keep both — this is
      the still-open T4.** Round-2 bake-off ran three questions against fresh
      indexes for all three tools. CodeGraph was fastest on every one
      (0.23–0.45 s vs 0.87–1.78 s) and the only one that answered. The decisive
      case, "what depends on `SpokenPhrase`": graphify returned the **fewest
      bytes in the whole table** (680 B) and was wrong — degree 3, all inside
      the same file, every real dependent missed — while `codegraph impact`
      named 21 symbols across 5 files in 1,538 B. Disk: `.codegraph` 27 MB,
      `.gitnexus` 86 MB, `graphify-out` **330 MB**. Serena and the GitNexus
      `PreToolUse` hook are unaffected either way. Recommendation: retire it.
      Removal is the `graph`/`graph:visual` scripts in `package.json`, then
      `rm -rf graphify-out`, then `pipx uninstall graphify`.

- [ ] **[P2]** **[Needs owner]** **Decide what consumes OmniRoute.** It is
      installed (since 2026-07-28, before the refusal was written), now
      hardened, and running on `127.0.0.1:20128` — but nothing points at
      `/v1`. Claude Code is deliberately not routed through it. Until a
      consumer exists it is attack surface with no benefit: either give it one
      or stop it with `pkill -f "omniroute serve"`. Audit table and both
      operational traps: `docs/archive/TOOLING-DECISIONS.md` →
      "OmniRoute — server-only hardening".

- [ ] **[P1]** **[Needs owner]** **Re-run the OmniRoute hardening after any
      `npm update -g omniroute`.** Its secrets live inside
      `/opt/homebrew/lib/node_modules/omniroute/.env`, so an upgrade discards
      them and restores the shipped defaults — including
      `INITIAL_PASSWORD=CHANGEME` and an **empty** `STORAGE_ENCRYPTION_KEY`,
      which would write stored provider credentials unencrypted at rest. The
      package offers no external config path. Backup:
      `~/.config/omniroute-env.backup.20260812` (mode `600`).

- [ ] **[P2]** **[Needs owner]** **Add a `permissions.deny` entry for
      `mcp__playwright__browser_run_code_unsafe`** in `~/.claude/settings.json`
      (owner-gated). That tool ships in Playwright MCP's `core` capability,
      cannot be removed by config, and its own description calls it
      "RCE-equivalent"; Playwright's docs say to rely on client-level
      permissions for exactly this.

- [ ] **[P3]** **[Needs owner]** **Decide whether to take four ECC skills, and
      at what scope.** All are pure guidance with no MCP dependency, and each
      was checked against this repo rather than assumed:
      `ios-icon-gen` (strongest — no icon tooling exists in `tools/` and
      `AppIcon.appiconset` is being edited now), `swiftui-patterns` (the
      missing sibling to the three ECC Swift skills already credited in
      `CREDITS.md`), `liquid-glass-design` (target is
      `IPHONEOS_DEPLOYMENT_TARGET = 26.0`), and `foundation-models-on-device`
      (moderate — `FoundationModelsSceneComposer`/`@Generable` are already
      built, so it helps review rather than bootstrap). Recommendation: take
      the first two **project-scoped** into `.agents/skills/`, matching the
      precedent already set, for zero global skill-menu cost. Adding any
      requires extending the ECC attribution in `CREDITS.md`. Ruflo yields
      nothing portable — every candidate is a shim over its own MCP or CLI.

- [ ] **[P3]** **[Needs owner]** **Puppeteer MCP was requested and refused —
      override available.** `@modelcontextprotocol/server-puppeteer` is
      npm-deprecated, bundles a deprecated `puppeteer@23.11.1`, and returned
      **zero tools** on probes at 9 s and 25 s; the alternatives are stale
      single-maintainer packages. Playwright MCP drives Chromium over the same
      protocol, so no capability is lost. To add it anyway:
      `claude mcp add -s user puppeteer -- npx -y @modelcontextprotocol/server-puppeteer`

### TODO burn-down pass — findings (2026-08-12, 22:00 PST)

Found while closing 26 items from the sections below. These are new, not
restatements: each was discovered by running something rather than by reading.

- [ ] **[P1]** **[Needs owner]** **Commit and push the burn-down work — it is
      all uncommitted.** 36 closed items' worth of changes sit in the working
      tree, machine-verified but unshipped, because agents never run `git` here.
      Six copy-paste commits, in order, with the diff split already worked out:
      [`sessions/2026-08-12/2200-PST.md`](sessions/2026-08-12/2200-PST.md)
      → "Ship commands". **Read the caveat there first:** `TODO.md` is shared
      with the concurrent 21:00 tooling-evaluation session, so committing it
      commits both sessions' edits, and that session's `docs/NOTEBOOKLM.md`,
      `docs/archive/TOOLING-DECISIONS.md`, and `.codegraph/` are deliberately
      excluded from all six commands.

- [ ] **[P1]** **[Needs owner]** **`npm run check` in `website/` is red, and
      was before this session.** `check:audio` reports
      `website/public/audio/main.mp3` stale: the built page's `<main>` text no
      longer hashes to `public/audio/manifest.json`'s `textHash`. **Confirmed
      pre-existing, not caused by this session's website edits** — with
      `website/src` stashed and rebuilt, the check fails identically. Needs the
      owner because fixing it means `npm run generate:audio`, which spends
      roughly 4,400 of the free plan's 10,000 monthly ElevenLabs credits (see
      the quota item below) — an agent should not burn a metered quota
      unprompted. **Verify a fix:** `npm --prefix website run check:audio`
      prints "matches the current page text."

- [ ] **[P3]** **`check:scene-drag` and `check:bfcache` are flaky under
      machine load, and fail in a way that reads as a real regression.** Both
      passed, then both failed while an `xcodebuild test` simulator run was
      using the machine, then both passed again once it finished — with the
      suspect source changes stashed in between to rule them out.
      `check:scene-drag`'s message is the misleading part: *"glasses stage
      mounts its WebGL scene (WebGL2 is available, so this is real)"*, which
      states the opposite of what happened. WebGL2 being *available* does not
      mean a headless GPU under contention will mount a scene inside the
      script's timeout. Cost this session: one stash-and-rebuild cycle to prove
      a change innocent. **Fix worth making:** retry the mount once before
      failing, or widen the timeout when the first attempt times out rather
      than errors, and reword the parenthetical so it does not assert that a
      timeout is a genuine failure. **Reproduce:** run either check while a
      simulator test run is in progress.
      **Done/Fixed 2026-08-18 — and the diagnosis above was wrong.** They are
      not flaky under load. They cannot pass in this environment at all, for
      two separate reasons found by instrumenting the page rather than by
      re-reading the scripts:
      1. **`requestIdleCallback` never fires in the pinned headless Chrome.**
         Measured directly: a bare `requestIdleCallback(cb)` on `about:blank`
         never called back in 8s. Both loaders in `BaseLayout.astro` deferred
         their dynamic `import()` behind it, so `motion.js` and
         `scenes/index.js` were never fetched — no error, no canvas, silence.
         **This was a real production bug, not just a test problem**: the API
         is explicitly best-effort, so any visitor on a page that never goes
         idle could get the same nothing. Fixed by passing
         `{ timeout: 2000 }`, which turns it into a deadline. Verified: both
         chunks now load where neither did before.
      2. **`IntersectionObserver` never delivers a callback in that Chrome
         either** — confirmed against a bare 300x300 fixed-position div on a
         `data:` URL, so it is nothing to do with this site. Every scene mounts
         from an IO callback, so no scene can ever mount under this runner.
      Both checks now probe that capability first
      (`intersectionObserverDelivers` in `website/scripts/lib/scene-mount.js`)
      and **skip loudly** — "This is not a pass" — instead of asserting a
      regression that is not there. They also retry the mount once
      (`waitForSceneMount`) and the misleading parenthetical is reworded.
      **Still open, and worth its own item:** these two checks now verify
      nothing on this machine. Getting real coverage back needs a runner whose
      Chrome delivers IO callbacks — a different channel, `headless: "shell"`
      (needs its own Chrome download), or a headed run in CI.

- [ ] **[P3]** **`.impeccable/design.json` is stale in content, not just in
      mtime.** The hook warns on every `website/` edit that `DESIGN.md` is
      newer. Checked directly rather than trusting the timestamp: the sidecar's
      `narrative.northStar` is still **"The Quiet Signal"** and it was generated
      `2026-07-11`, while `.agents/context/DESIGN.md` §0 voided that doctrine on
      2026-07-18 in favour of "First Light". Its `colorMeta` ramps do still
      match the shipped tokens, so the drift is the narrative and rules, not the
      palette. Regenerating is `/impeccable document`'s job — an authoring task,
      not a mechanical one — which is why it was left rather than half-done
      here. Sharpens the "hook also warns" note below, which assumed the warning
      was only an in-flight-edit artefact.

### Twelve-repository tooling evaluation (2026-08-12, 21:00 PST)

Twelve candidate repositories assessed blind for global versus per-project
adoption. All verdicts, with the mechanism spelled out for the doctrinal
refusals, are in
[`docs/archive/TOOLING-DECISIONS.md`](docs/archive/TOOLING-DECISIONS.md)
→ "Evaluated 2026-08-12". Session log:
`sessions/2026-08-12/2100-PST.md`. Working plan: `tmp/handoff-tooling.md`.

- [x] **[P2]** **Decide whether to retire `graphify`.** CodeGraph and
      graphify are the one genuine redundancy the bake-off found — Serena
      answers symbol questions and the GitNexus `PreToolUse` hook works
      passively, so neither is a removal candidate. On the same architecture
      question, `codegraph explore` answered with verified `file:line`
      accuracy in 0.66s while `graphify explain` returned only "Ambiguous:
      'depth' matches 12 nodes"; graphify has no free-text question verb, and
      its index additionally covers all five mirrored copies of the
      `impeccable` skill scripts. Either retire graphify or run the CodeGraph
      trial week first, then decide on evidence.
      **Done 2026-08-18** — retired, on owner's decision after a fresh
      measurement pass: `graphify-out/` was **365 MB** against CodeGraph's
      28 MB and GitNexus's 86 MB, and backing out the 4:1 skill-mirror
      inflation put graphify's real coverage (~4,500 nodes) *below*
      CodeGraph's 6,752. Removed `.github/workflows/graphify.yml`,
      `.graphifyignore`, the vendor-installed rebuild blocks in
      `.githooks/post-commit` and `post-checkout` (~370 lines), the `graph`
      npm script, and every stale reference across 18 tracked files.
      **The measurement also found the one real argument for keeping it**:
      graphify was the only index that self-refreshed, and GitNexus was 14
      days and ~100 commits stale at the time of removal. That gap is closed
      by a new `codegraph sync` block in both hooks — incremental,
      backgrounded, and advisory, so it can never fail a commit.
      `docs/assets/graph*.svg`, `tools/graph-visual.mjs`, and the
      `check:graph` CI gate are **deliberately kept**: the picture is
      committed and self-contained, and `--verify` reads only the committed
      bytes, so it needs no graph tool installed. Redrawing is now a
      deliberate one-off via `npm run graph:visual -- --graph <path>`.
      Still owner-only: `rm -rf graphify-out && pipx uninstall graphify`.

- [ ] **[P2]** **Close out the CodeGraph trial.** Installed 2026-08-12 as a
      CLI-only trial: no MCP configuration and no marker-fenced block in any
      instruction file, so reverting is `codegraph uninit .` plus
      `npm uninstall -g @colbymchenry/codegraph` and nothing else. Adopt if it
      answers architecture questions that would otherwise cost a multi-file
      read sweep, **and** long sessions do not start compacting sooner —
      CodeGraph's own benchmarks report roughly 80% more residual retrieval
      context left resident at end of session. Revert if compaction arrives
      noticeably earlier.

- [ ] **[P3]** **Decide whether CodeGraph should also index Salon-OS**
      (Next.js + React + Supabase, TypeScript). Only SenseBridge is indexed
      today. Related: whether to run `codegraph install` to wire the MCP once
      the trial concludes — that step writes agent configuration, which the
      trial deliberately avoided.

- [ ] **[P3]** **[Needs owner]** Re-enable the `obsidian-cli` skill.
      `~/.claude/settings.json` is owner-gated, so this is a proposal, not an
      applied change: delete the line `"obsidian-cli": "off",` from
      `skillOverrides`. The official `obsidian` CLI is already installed at
      `/usr/local/bin/obsidian`; this was the stated alternative to installing
      `obsidian-local-rest-api`, which was refused because it adds an
      authenticated HTTPS listener on port 27124 for a surface the CLI and
      filesystem access already cover.

### Awareness feature + reasoning-tier implementation (2026-08-11, 21:00 PST)

Executing the approved, Opus-5-reviewed plan at
[`docs/superpowers/plans/2026-08-11-awareness-ai-tiers-plan.md`](docs/superpowers/plans/2026-08-11-awareness-ai-tiers-plan.md)
on `feat/awareness-reasoning-tiers` via `superpowers:subagent-driven-development`
— one implementer + one reviewer subagent per task, progress tracked in
`.superpowers/sdd/progress.md` (gitignored) and `tmp/handoff.md`. This entry
covers findings surfaced mid-execution that aren't this plan's own scope;
the plan's own Task 19 closes this TODO.md item out fully once all 23 tasks
land.

- [ ] **[P2]** **`xcodebuild test -scheme SenseBridgeCore -destination
      'platform=macOS'` fails when run from `app/`** — `xcodebuild: error:
      Scheme SenseBridgeCore is not currently configured for the test
      action.` Reproduced directly (not just via subagent report). No shared
      `SenseBridgeCore.xcscheme` exists under
      `app/SenseBridge.xcodeproj/xcshareddata/xcschemes/` (only
      `SenseBridge.xcscheme` does), so the SPM package's auto-generated
      scheme has no Test action when accessed through the umbrella Xcode
      project — even though `docs/TESTING.md` names this exact command as
      the one CI itself uses (`.github/workflows/ci.yml`) for validating
      String Catalog (`.xcstrings`) compilation, which bare `swift test`
      cannot do. Workaround confirmed equivalent (real `xcodebuild`, not a
      simulation): run the identical command from
      `app/Packages/SenseBridgeCore` instead of `app/` — resolves the
      package's own scheme, which does carry a Test action, and exercises
      the same `SenseBridgeCoreTests` target and the same compiled resource
      bundle. **Needs owner + Xcode GUI**: open the project, select the
      SenseBridgeCore scheme, Product → Scheme → Edit Scheme, add a Test
      action targeting `SenseBridgeCoreTests`, check "Shared," and commit
      the resulting `xcshareddata/xcschemes/SenseBridgeCore.xcscheme` — a
      CLI-only fix risks hand-authoring scheme XML that Xcode itself would
      reject or silently ignore. **Confirmed not a CI risk**:
      `.github/workflows/ci.yml:49-60` already `cd`s into each
      `app/Packages/*` directory before running `xcodebuild test`, exactly
      matching the working substitution above — CI was never affected. The
      imprecision is only in `docs/TESTING.md`'s prose and this plan's own
      task verification commands, both of which say `cd app &&` without
      naming the package subdirectory CI actually uses.

- [ ] **[P1]** **[Needs owner]** **Device-validate everything the reasoning-tier
      plan's own spec names as explicitly unverifiable by a machine** — see
      "What stays explicitly unverified after this session" in
      [`docs/superpowers/specs/2026-08-11-awareness-ai-tiers-design.md`](docs/superpowers/specs/2026-08-11-awareness-ai-tiers-design.md).
      Specifically: (1) whether `NSAllowsLocalNetworking` actually covers a
      bare RFC1918 IP literal (`192.168.1.20`) versus only qualified/`.local`
      addresses, and when the local-network permission prompt fires for a
      direct `URLSession` connection (Task 18) — if it fails, restrict
      self-hosted to `https://` only rather than reaching for
      `NSAllowsArbitraryLoads`; (2) which cloud providers and self-hosted
      servers (Ollama, LM Studio, vLLM) actually honor the compression-only
      system prompt in practice versus relying on
      `ReasoningOutputValidator` to catch drift; (3) real round-trip latency
      for each network backend against the ~4s hands-free /~8s single-capture
      timeouts; (4) VoiceOver *experience* — not just accessibility labels —
      on `ReasoningBackendSettingsView`'s picker/toggle/paste-key flow,
      including whether the "Test connection" round trip reads naturally
      with VoiceOver mid-flight; (5) thermal/battery impact of hands-free
      awareness running against a network composer versus on-device only.
      None of these can be checked from a machine; needs Kevin's own device
      pass.

- [ ] **[P2]** **[Needs owner]** **`legal/PRIVACY_POLICY.md` and
      `legal/SUBPROCESSORS.md` disclosure changes are uncommitted** — Kevin
      applied the drafted Local/Cloud reasoning-backend disclosure himself
      (agent was blocked from writing `legal/` by `.claude/settings.json`'s
      `Edit(legal/**)` deny rule, by design), and the matching
      `CHANGELOG.md` entry was added in the same working tree. "Which branch"
      answered 2026-08-12: current branch, `feat/awareness-reasoning-tiers` —
      still needs Kevin to actually run the commit (see `tmp/handoff-away.md`
      for the exact command; agents don't run `git` autonomously).

- [ ] **[P1]** **[Needs owner]** **Full-word distance units (2026-08-12,
      overnight session) are implemented, tested, and installed on-device,
      but uncommitted** — root cause + fix + regression test + verification
      commands are all in `tmp/handoff-away.md`. Files: both
      `MeasurementFormatter` call sites
      (`AmbientAwarenessSession+Support.swift`,
      `SettingsSections.swift`) now set `unitStyle = .long` instead of
      defaulting to `.medium`'s abbreviation ("in"/"ft"), which is what a
      synthesizer was reading literally. New test:
      `app/SenseBridgeTests/AmbientAwarenessSessionSupportTests.swift`
      (required manual `project.pbxproj` registration, also uncommitted).
      **Still needs your ear on-device** — no CI substitute for confirming
      the spoken result actually sounds right in your locale/accent.

- [ ] **[P1]** **[Needs owner]** **Review the descriptive-voice /
      more-comprehensive-AI plan and its execution (2026-08-12, overnight
      session)** — per your "Opus 5 writes and reviews the plan, Sonnet 5
      executes" instruction: an Opus 5 agent researched the composer
      pipeline and wrote (then self-reviewed) a plan at
      [`docs/superpowers/plans/2026-08-12-descriptive-voice-plan.md`](docs/superpowers/plans/2026-08-12-descriptive-voice-plan.md),
      constrained to no new dependencies and no fine-tuning/dataset work
      (those are the "Deferred to Kevin" items below, with options, not
      built). All 10 of the plan's tasks were then executed inline this
      session (task-by-task, verified against the plan's own acceptance
      commands) — see `tmp/handoff-away.md` and the "Configurable
      spoken-output verbosity" item above for what shipped. Uncommitted, same
      as everything else tonight. **This is a genuinely large diff for an
      unattended session to have produced** — worth a closer read than the
      smaller items above before committing.

- [ ] **[P2]** **[Needs owner]** **Real model/dataset work for more
      comprehensive on-device descriptions** — deferred by design, not
      built. Three options with tradeoffs are written out in
      `docs/superpowers/plans/2026-08-12-descriptive-voice-plan.md`'s
      "Deferred to Kevin" §1: (A) stay on Apple Vision + Foundation Models
      (recommended — zero license/bundle/maintenance cost), (B) train a
      Core ML classifier with Create ML on a vetted dataset (this repo
      already paid the license-audit cost once on the ESC-50 sound
      compilation — see `audits/model-license/`), (C) bundle an open
      vision-language model as the Local reasoning tier (blocked on a full
      license audit — AGPL/`apple-amlr` are hard blockers per `AGENTS.md`
      — plus gigabyte-scale bundle growth and thermal testing). Recommended:
      A now, B only if field testers name specific missed object classes.

- [ ] **[P2]** **Decide the shipped default `SpokenDetail` value** — shipped
      as `.standard` tonight (no behavior change for anyone who doesn't open
      Settings). Options in the plan's "Deferred to Kevin" §3. Needs a device
      listen at both `.standard` and `.detailed` before flipping the default
      — see the P1 device-validation item above.

- [ ] **[P3]** **Extend `SpokenPhrase`'s abbreviation table from real Vision
      identifiers** — currently seeded from identifiers hand-verified during
      planning (`tv`, `cd player`, `atm`, etc. — see
      `app/Packages/SenseBridgeCore/Sources/SenseBridgeCore/Perception/SpokenPhrase.swift`),
      not enumerated from the framework. Plan's "Deferred to Kevin" §4
      recommends a `#if DEBUG` dump of the classifier's known identifiers run
      once on device — ten minutes, converts a guess into a list.

- [ ] **[P3]** **Fold recognized sounds/text into scene descriptions** —
      genuinely more comprehensive, genuinely not attempted tonight.
      `.detectedSound` is dropped by every composer; `OCRService` discards
      Vision's per-observation confidence, so there's nothing to hedge from
      without changing its return type first. Options in the plan's
      "Deferred to Kevin" §5.

- [ ] **[P3]** **Two hook friction points found by tonight's safety-framing
      review, worth a look but not urgent:** (1) `audits/scripts/new-audit.sh`
      creates a report file, then `guard-protected-paths.sh` denies every
      `Edit` to it as append-only — so the skill's own generate-then-fill
      workflow can't use `Edit` to fill in the template it just generated;
      the reviewer worked around it by appending instead, but the template
      placeholders are still sitting above the real findings in
      `audits/safety-framing/20260812-105707-...md`. (2) `away-guard.sh`
      blocked an audit-report append because the report's *prose* quoted
      version-control verbs inside a heredoc — no actual `git`/`gh` call was
      involved, just words describing one. Both are minor tooling
      false-positives, not correctness bugs in the review itself.

- [ ] **[P2]** **[Needs owner]** **Push `feat/awareness-reasoning-tiers` and
      open a PR** — 25+ commits ahead of `main` once the two items above are
      committed; nothing pushed yet. Every `git`/`gh` command needs Kevin's
      explicit per-command permission per `CLAUDE.md`.

### Deferred from docs/planning/ (2026-08-07, 14:36 PST)

`docs/planning/` (the original 7-document pre-implementation strategy plan,
written before most of the current codebase existed) moved to
`deprecated/planning/` this session — superseded by the living docs it
seeded (`docs/ROADMAP.md`, `docs/PRODUCT.md`, `docs/AI-MODELS.md`,
`docs/ARCHITECTURE.md`, `docs/TESTING.md`, `docs/DISTRIBUTION.md`,
`GOVERNANCE.md`, `COMMUNITY_GUIDELINES.md`, `FUNDING.yml`, `legal/`). Most of
the plan's proposals are already either built (Reading, Labeling, Scene
Description, Obstacle Awareness, Sound Alerts, the `SensingSource`/
`RenderTarget`/`OutputProfile` protocol seams, model-license ledger,
repository governance/contribution scaffolding) or already tracked elsewhere
in this file (Apple Developer Program/TestFlight setup, Discord tester
recruitment — see the "App Store Connect / TestFlight" and "Discord" items
above). The five items below are the ones a full cross-reference against
current docs, `TODO.md`, and `app/` code found genuinely proposed and never
built or tracked. Cross-referenced files fully superseded, contributing
nothing here: none — every one of the 7 source documents had at least one
item that was either still open or worth re-verifying below; the merged
`SENSEBRIDGE-COMPLETE-PLAN.md` is a section-for-section duplicate of the 7
numbered files (verified by header diff) and contributed no additional items.

- [ ] **[P2]** **AI evaluation harness for perception quality regressions.**
      Source: `SENSEBRIDGE-04-ENGINEERING-QUALITY.md` §16 "AI evaluation" (and
      `docs/TESTING.md`'s "AI evaluation" row, which documents the *target*
      but nothing implements it yet — no eval folder, script, or fixture set
      exists under `app/` or `tools/`). Proposed: a small, periodically-run,
      eyeballed evaluation harness — a folder of real-world images (mail,
      packaging, rooms) with expected-ish outputs, checked by hand for
      reading-accuracy regressions and for new over-confident or hallucinated
      scene claims (the `SceneComposer`/`FoundationModelsSceneComposer`
      output must never assert something the underlying Vision labels didn't
      support — see `docs/SAFETY-FRAMING.md`). Why it still matters: this is
      the one testing layer in `docs/TESTING.md`'s table with no automated or
      scripted-manual counterpart anywhere in the repo, and it's the layer
      most likely to catch a silent hedging regression that a passing unit
      test wouldn't. **[Needs owner]** for the image set itself (real mail/
      room/packaging photos have to come from an actual device and a real
      environment), but the harness scaffolding (a `tools/` script that loads
      a fixture folder, runs it through the existing perception services, and
      prints a diff-able report) is a plain implementation task an agent can
      do without the owner.

- [ ] **[P2]** **Structured on-device logging via `OSLog`/`Logger`.** Source:
      `SENSEBRIDGE-04-ENGINEERING-QUALITY.md` §17 "Observability &
      Reliability" → "Logging". Proposed: local, structured logging via
      Apple's unified logging, with privacy-aware redaction (mark recognized
      text/images/audio content `private` so it's never captured in device
      logs) and level control for on-device debugging. Current state:
      grepped `app/Packages/SenseBridgeCore/Sources` and `app/SenseBridge`
      for `OSLog`/`Logger`/`import os` — zero hits. There is no logging of
      any kind in the app today, debug or otherwise. Not `Needs owner` — this
      is a self-contained implementation task, and the redaction rule
      (**never log recognized text, images, or audio content — events and
      states only**) should be enforced the same way `docs/PRIVACY.md`
      already enforces "no user content persisted."

- [ ] **[P3]** **[Needs owner]** **Consent-based facial-enrollment
      *framework* (not full facial recognition).** Source:
      `SENSEBRIDGE-02-FEATURES-AND-SCOPE.md` §9 "Roadmap" (listed as part of
      MVP Increment 2 / Phase 2, still true in `docs/ROADMAP.md` today),
      `SENSEBRIDGE-03-TECHNICAL-ARCHITECTURE.md` §11 "Face recognition
      architecture (deferred, designed now)", and
      `SENSEBRIDGE-05-GOVERNANCE-SECURITY-LEGAL.md` §20–21 (encrypted
      on-device-only storage, consent UX, BIPA/CUBI/GDPR Article 9 exposure).
      The plan's point was to stand up the *consent flow and on-device
      encrypted storage design* before recognition itself grows, so the
      legally-safe pattern exists early — not to ship matching in the MVP.
      Current state: no `EnrollmentStore`, no consent-flow UI, and no
      `Features/Enrollment` directory exist anywhere in `app/`; the only
      trace is a one-line comment in `Settings.swift` confirming enrollment
      data "is never stored here." `docs/PRIVACY.md` describes the intended
      design (consent-enrolled matching only, everyone else labeled
      "person") but nothing implements it. Flagged `[Needs owner]` because
      `GOVERNANCE.md` itself says biometric-data decisions are the
      maintainer's call, consulting counsel — this needs an explicit
      go/no-go before any code, not just an implementation ticket.

### Safety-framing verdict on `fire_alarm`/`siren` alpha readiness (2026-08-06, 06:42 UTC)

Answers the open **[P2]** question at "Alpha-readiness scaffolding
implementation (2026-08-04, 17:00 PST)" below — is ~21–24% validation error on
`fire_alarm`/`siren` acceptable to ship in alpha as framed? **Verdict: no, not
as currently framed — and the error rate is not the reason.** Full reasoning,
measured evidence, and severities in
`audits/safety-framing/20260806-064241-custom-sound-classifier-out-of-distribution-false-positives-reach-spoken-output.md`,
which extends (does not supersede)
`audits/safety-framing/20260805-205701-fire-alarm-siren-validation-error-alpha-acceptability-verdict.md`.
That P2 item stays open; the work that closes it is below.

- [ ] **[P1]** **[Needs owner]** **`CombinedSoundClassifier`'s `max`-confidence
      merge cannot express a correct rejection.**
      `app/Packages/SenseBridgeCore/Sources/SenseBridgeCore/Perception/CombinedSoundClassifier.swift:17-31`
      returns the highest-confidence record across both classifiers. A
      classifier that correctly recognizes non-alert audio contributes **zero
      records**, which is indistinguishable from it not having run. Verified:
      on all six probes Apple's built-in classifier was right
      (`music`/`waterfall`/`synthesizer`/`beep`) and contributed nothing, while
      the custom model's 1.000 passed straight through. For false positives the
      combined system is by construction as bad as the worse of its two
      members — so the premise that the built-in classifier makes the custom
      model's error rate tolerable is false as implemented. **Owner decision**
      (real usability cost — more misses on a screen that already misses):
      require agreement between both classifiers before an alert class is
      spoken; or raise the floor for `fire_alarm`/`siren` above the shared 0.7;
      or fall back to a weaker claim on disagreement.

- [ ] **[P1]** **[Needs owner]** **Uncalibrated confidence reaches the
      strongest hedge tier.** `Phrasing.certainty(forConfidence:)`
      (`Phrasing.swift:25-31`) applies one mapping to raw confidences from
      Apple's production classifier and from a 78-clip, no-reject model. With
      the 0.7 floor, `.low` is unreachable on the sound path and `.high`
      (`≥ 0.8`) is trivially reached by the weak model. `docs/SAFETY-FRAMING.md`
      says a model may supply *what* is named, never *how certainly* — that
      safeguard assumes the detector's confidence means something. **Proposed:**
      clamp custom-model detections to `.medium` until the model is calibrated.

### Full TODO.md sweep — device-first + autonomous batches (2026-08-05, 13:00 PST)

Owner asked for all 166 open items worked through in one session: device-first
work while a physical device was plugged in, then a live interview on
product/decision items, then full autonomous sweep after the owner stepped
away (per CLAUDE.md, no git commit/push — everything below stays
uncommitted for owner review). Plan and full 166-item catalog in
`tmp/handoff.md`. This section accumulates findings/completions as the sweep
runs; see also `sessions/2026-08-05/1300-PST.md` (to be written at session end).

- [ ] **[P1]** **[Needs owner]** Resumed the Phase 0 on-device
      `AlphaScaffoldingUITests` blocker (2026-08-05, ~23:15 PST, device
      reattached): 4/8 tests fail on Kevin's iPhone 17 Pro
      (`testAwarenessScreenPassesAccessibilityAudit`,
      `testOnboardingWalkthroughAdvancesThroughEveryStepToHome`,
      `testReplayWalkthroughReturnsToOnboarding`,
      `testSettingsAwarenessSectionPassesAccessibilityAudit`), all
      `performAccessibilityAudit()` `.contrast` findings on *labeled*
      elements the existing nil-label exemption doesn't cover — a Simulator
      run of the same suite the 2026-08-05 12:00 PST session logged as
      clean did not surface these. Instrumented the audit closure
      (temporarily, reverted after) to capture which element failed each
      run, then pixel-sampled that run's own screenshot at the reported
      text: every one of the three distinct elements checked — the two
      children of `SettingsView.UnavailableProfileRow`'s combined
      name+reason row (label came back as either `"Deaf"` or `"Captions
      aren't built yet."` depending on the run) and
      `ObstacleAwarenessView`'s plain `previewPending` text — measured
      **6.99:1 to ~18:1** against their real rendered card background
      (`#1C1C1E`/`#0A0A0A`), clearing the 4.5:1 WCAG AA floor by 2-4x. Not
      filtered in code: *which* element fails is non-deterministic across
      runs (confirmed — the same combined row implicated a different child
      on consecutive runs), so a label-match exemption narrow enough not to
      mask a real regression would also miss the next instance. Full
      reasoning and the four already-acknowledged categories this joins:
      `app/SenseBridgeUITests/AccessibilityAuditSupport.swift`'s
      `performScopedAccessibilityAudit` doc comment (moved there 2026-08-13,
      when the two duplicate copies of the helper were merged; that change also
      exempts contrast findings on elements that are not fully in view, which
      may account for some — not all — of these device-run findings).
      **Needs an owner call**:
      trust pixel-verified device runs over `performAccessibilityAudit`'s
      `.contrast` verdict for this class of finding (and filter it), or
      treat this as a `performAccessibilityAudit` reliability problem on
      this iOS build (26.6) worth a radar/report to Apple, or something
      else. Also unresolved: `testBackButtonReturnsToPreviousStep` failed
      once on `XCTAssertTrue(app.staticTexts["Camera and microphone"]
      .waitForExistence(timeout: 5))` (line 162) — not yet reproduced a
      second time, likely the same on-device step-transition timing class
      already documented on
      `testOnboardingWalkthroughAdvancesThroughEveryStepToHome`, but
      unconfirmed.

### Device install + VoiceOver pass for Sentry/Diagnostics UI (2026-08-05, 12:00 PST)

Session log: [`1200-PST.md`](sessions/2026-08-05/1200-PST.md). Owner
reattached a device; completed the install + escalated VoiceOver pass that
the 2026-08-04 17:00 PST session had left blocked on "no device attached."
Found and fixed a real gap along the way: `app/project.yml` never wired
`SenseBridgeTests`/`SenseBridgeUITests` to `Config/Signing.xcconfig`, so
neither test target could sign for a device run — meaning the earlier
session's "6/6 passed on device" claim for this suite did not run through
this signing path as committed. Fixed durably in `project.yml` (not the
generated `project.pbxproj`), regenerated via `xcodegen generate`, verified:
6/6 `AlphaScaffoldingUITests` passed on Kevin's iPhone 17 Pro, 0 failures.

- [ ] **[P1]** **[Needs owner]** The `project.yml` signing fix and
      regenerated `project.pbxproj` are uncommitted, riding along with the
      rest of the alpha-readiness scaffolding work already tracked below
      (2026-08-04, 17:00 PST — "Nothing from this implementation is
      committed yet"). No separate branch/commit needed — just make sure
      this fix is included when that diff is reviewed and committed.

### Dead-weight plugins/connectors follow-through (2026-08-04, 23:00 PST)

Acted on a prior audit's two findings (0-use plugins, unused claude.ai
connectors). Plugin disable done locally; two items need the owner directly —
no tool in this session reaches either surface.

- [ ] **[Needs owner] [P3]** Prune unused claude.ai connectors at
  `claude.ai/settings/connectors` — Aiwyn Tax, Blockscout, Calendly, Clerk,
  ClickUp, Cloudflare, Courtroom5, Coupler.io, Crypto.com, Docusign,
  ElevenLabs, Excalidraw, Fellow.ai, Goodnotes, Harvey, Indeed, LegalZoom,
  Microsoft 365/Learn, Midpage, PlanetScale, Postman, S&P Global, Scholar
  Gateway, Spotify, Square, Stripe, tldraw, Zoom, Atlassian. Toggling there is
  reversible; no CLI/MCP surface exists to do this from a session.

### Alpha-readiness scaffolding implementation (2026-08-04, 17:00 PST)

Session log: [`1700-PST.md`](sessions/2026-08-04/1700-PST.md). Continuation
of the 16:00 PST design session — owner said "Execute the code plan" for the
approved four-section design. All 13 tasks in `tmp/handoff.md` implemented:
Identify/Describe wired to real Vision, Sound Alerts built from scratch
(including a real trained Create ML classifier on filtered ESC-50 data),
onboarding flow added, docs synced. Build green, 90/90 package tests
passing, real device install confirmed on Kevin's iPhone 17 Pro. Nothing
committed — no `git` command has run this session.

- [ ] **[P1]** **[Needs owner]** **Nothing from this implementation is
      committed yet.** ~15 files changed/added under `app/` (App layer +
      `SenseBridgeCore` package), 4 new files under `models/sound-classifier/`,
      plus doc updates across `docs/ARCHITECTURE.md`, `docs/PRIVACY.md`,
      `docs/TESTING.md`, `docs/CODE-MAP.md`, `CREDITS.md`, `models/README.md`.
      Owner needs to review the diff and run the branch/commit/PR sequence —
      `tmp/handoff.md`'s per-task `git add`/`git commit` blocks are ready to
      copy-paste once reviewed, though several no longer match the plan's
      original file lists (see each task's "STATUS: DONE" deviation notes).

- [ ] **[P3]** **Device-only validation the build/reviews can't prove:**
      Sound Alerts' real classification accuracy for both classifiers on
      real-world sound, onboarding's actual system permission-prompt
      sequencing, lens/torch/haptic behavior on the two newly-wired camera
      screens (Identify/Describe), and the Deaf profile's visual caption
      output. For captions: select Settings → Output → Deaf, run each capture
      feature, and confirm the newest hedged result is readable at the largest
      Dynamic Type size while a signal-only capture-start message clears the
      old caption. Unlike the VoiceOver/label pass above, classification
      accuracy and physical camera/haptic behavior aren't things an XCUITest
      accessibility audit can exercise — these remain genuinely manual,
      subjective calls for the owner.

### React Doctor 100/100 gate + privacy/cookie consent banner (2026-08-04, 02:00 PST, away mode)

Session log: [`0200-PST.md`](sessions/2026-08-04/0200-PST.md). Owner asked to
(1) get React Doctor to 100/100 with a rule blocking merge/push below that,
(2) do the same for react-scan, and (3) add an "accept privacy policy/cookies"
button, legally compliant, referencing `legal/`. Owner went to bed mid-task;
finished (1) and (2) under the away-mode contract (no `git`/`gh`), escalated
(3).

- [ ] **[P1]** **[Needs owner]** **Cookie/privacy consent banner — conflicts
      with the published policy, decide before any code changes.**
      `legal/PRIVACY_POLICY.md:106-117` states the site sets no cookies and
      shows no banner because there is nothing to consent to under ePrivacy
      Article 5(3) until the visitor acts — that file is owner-approval-only
      per `CLAUDE.md`, so it could not be reconciled unilaterally.
      `website/src/scripts/monitoring-consent.ts` already implements the thing
      that *does* need consent: an opt-in switch (footer + `/privacy`,
      `localStorage`, not a cookie) for the optional Sentry crash reporting,
      with GPC honored as a hard override. Building a generic "accept
      privacy policy / cookies" banner on top would contradict the published
      legal position (implies tracking/cookies exist pre-consent when they
      do not) and the site's "restraint over conversion pressure" doctrine
      (`CLAUDE.md`'s Design context section). **Recommendation:** keep the
      current no-banner design — it is already the strictest compliant
      reading and already has a visible, footer-level accept/reject control.
      If the owner wants something added, the likely candidates are: (a) a
      more prominent link/label on the existing footer switch, (b) a
      one-time first-visit toast pointing at `/privacy` (informational only,
      no accept/reject choice needed since nothing is being consented to),
      or (c) this was written with a future non-website surface in mind (the
      iOS app?) — needs the owner to say which, since guessing wrong here is
      a legal-accuracy mistake, not a cosmetic one.

- [ ] **[P1]** **[Needs owner]** **Ship (1) and (2) — still uncommitted on
      `main`.** Two unrelated diffs, ship separately so history stays honest:
      ```sh
      # 1. Earlier session's work (double-quote consistency + .mjs lint gate)
      git checkout -b chore/mjs-lint-consistency
      git add .claude/hooks/guard-bash-secret-read.mjs .claude/hooks/guard-mcp-sensitive-paths.mjs \
        .claude/hooks/prefer-rtk-shape.mjs .claude/hooks/react-doctor.mjs .cursor/hooks/react-doctor.mjs \
        .github/workflows/ci.yml .github/workflows/codeql.yml TODO.md docs/TOOLING.md package.json \
        tools/check-bmad-config.mjs tools/check-settings-hooks.mjs tools/graph-visual.mjs \
        tools/sweep-done-todo.mjs eslint.config.mjs .kimi-code
      git commit -m "chore(lint): enforce double quotes on hand-authored .mjs files"
      git push -u origin chore/mjs-lint-consistency && gh pr create --fill

      # 2. React Doctor 100/100 gate + docs
      git checkout main && git checkout -b chore/react-doctor-100-gate
      git add website/doctor.config.jsonc .githooks/pre-push CLAUDE.md docs/CI-CD.md TODO.md
      git commit -m "chore(website): enforce React Doctor zero-findings gate on merge/push"
      git push -u origin chore/react-doctor-100-gate && gh pr create --fill
      ```
      Both branches touch `TODO.md`; rebase branch 2 onto branch 1's tip after
      merging, or squash into one PR. After merge, `react-doctor.yml`/the new
      pre-push hook only *report* red — nothing stops an admin from merging
      past a red check until "React Doctor" is a **required status check**:
      ```sh
      gh api repos/kevinle3212/sensebridge/commits/main/status --jq '.statuses[].context'
      gh api -X PATCH repos/kevinle3212/sensebridge/branches/main/protection/required_status_checks \
        -f strict=true -f 'contexts[]=<exact context name from the command above>'
      ```

- [ ] **[P3]** **[Needs owner]** `.claude/commands/{handoff,claude-cli,docker-clean}.md`
      are byte-identical tracked duplicates of the global `~/.claude/commands/`
      versions (synced 2026-08-01, still identical as of 2026-08-04) —
      deleting the project copies is the cleaner endstate so they can't drift
      again: `git rm .claude/commands/{handoff,claude-cli,docker-clean}.md`.

### Kimi Code CLI harness setup — follow-ups (2026-08-04, 01:00 PST)

Installed Kimi Code CLI 0.32.0 and configured it strict on both scopes
(`~/.kimi-code/` + tracked `.kimi-code/AGENTS.md`): manual approval mode,
plan-mode default, telemetry off, and a `[permission]` policy ported from
`~/.claude/settings.json`. `kimi doctor` and all 9 `npm run check` gates are
green. The published `MoonshotAI/kimi-cli` docs describe a **different
product** (`~/.kimi/`, Python tool paths, `kimi mcp`/`plugin` subcommands) and
do not apply — the schema was derived from the binary. Full detail in
`sessions/2026-08-04/0100-PST.md`.

- [ ] **[P2]** **[Needs owner]** The same rewrite **strips every comment** from
      `config.toml` and normalizes `[permission] deny = [...]` / `ask = [...]`
      into canonical `[[permission.rules]]` blocks with explicit `decision` +
      `scope = "user"`. All 103 rules survived semantically (96 deny + 7 ask),
      but the rationale comments explaining *why* each rule exists are gone.
      **2026-08-05** — searched this repository for an annotated master copy:
      **none exists.** `.kimi-code/AGENTS.md`, `docs/TOOLING.md`, and
      `docs/archive/TOOLING-DECISIONS.md` describe the policy in prose but hold
      no per-rule rationale, and `~/.kimi-code/` contains no `.bak`. The
      comments are unrecoverable from anything an agent can reach — do not let
      a future pass "reconstruct" them by guessing. Owner decision: rebuild the
      annotated master from memory/backups, or accept the loss and treat the
      live file as generated from here on.

- [ ] **[P1]** **[Needs owner]** **Moonshot account has no balance** — the
      first live session returned `429 provider.rate_limit: … suspended due to
      insufficient balance`. This is *not* an auth failure: a 429 billing
      rejection only happens after the key authenticates, so the provider
      import and key extraction are confirmed correct. Recharge at
      `platform.moonshot.ai`, or activate a Kimi Code membership and switch
      back to the OAuth path. **Until then no session can run**, so every
      permission rule remains unexercised. **2026-08-05** — still unresolved and
      still unverifiable from inside the repo. No read-only probe reaches
      billing: `kimi doctor` only validates config files, and
      `kimi provider list` reports `moonshotai type=openai models=10
      source=inline` from local config without contacting the provider. The
      only probes that would answer it are a live prompt (`kimi -p …`, spends
      money) or an authenticated call to `https://api.moonshot.ai/v1` (requires
      handling the plaintext API key, which agents must not do). Owner: check
      `platform.moonshot.ai`.

- [ ] **[P2]** Verify empirically whether an `ask` rule still prompts once a
      session is in `--yolo`. Currently recorded as **unknown** in
      `~/.kimi-code/AGENTS.md` rather than assumed; if it does not hold, the
      `git`/`gh` owner-gating rule needs a different mechanism. **2026-08-05** —
      still blocked on the balance item above; keep it recorded as unknown.
      `kimi --help` distinguishes `-y/--yolo` ("auto-approve regular tool calls;
      the agent may still ask questions") from `--auto` ("fully autonomous, the
      agent will not ask questions"), which *suggests* `ask` survives `--yolo`
      and does not survive `--auto` — but help text is not evidence, and the
      `git`/`gh` gate is exactly the rule that must not be assumed.

- [ ] **[P3]** No project-scoped permission file exists in Kimi Code 0.32.0
      (`.kimi-code/local.toml` accepts only `[workspace] additional_dir`), so
      this repo's rules live in the user config and **a fresh clone inherits
      none of them**. Re-check on upgrade; if project scope lands, move the
      repo-specific rules (`legal/`, git gating) back into the repo.
      **2026-08-05** — re-checked: `kimi --version` is still `0.32.0` (no
      upgrade has happened), and `kimi --help` exposes no config-scope flag, so
      the finding stands unchanged. Standing item; re-check after
      `kimi upgrade`.
      **2026-08-12** — re-checked again: `kimi --version` still reports
      `0.32.0`. No upgrade, so nothing has changed. Still open.

### Repo stabilization pass — deferred items (2026-08-04, 06:15 PST)

PR #67 merged (commit `ae3540f`): committed ~409 files of pending WIP that
had accumulated across prior sessions (Sentry crash reporting, legal docs,
website privacy/accessibility pages, impeccable skill sync, BMAD adoption,
tooling), fixed 10 npm audit findings (0 vulnerabilities remain), and
hardened CI (gate every branch, new repo-guardrails job, pinned actions).
Full detail in `sessions/2026-08-04/` (background session).

- [ ] **[P1]** **[Needs owner]** Device build/install and VoiceOver pass for
      the Sentry crash-reporting UI (`SettingsView`/`DiagnosticsSettingsSection`).
      Re-verified 2026-08-06: `xcrun xctrace list devices` still lists iPhone
      and iPad as Offline. Simulator build + all unit/package tests (26 + 83)
      passed; device validation is the one gate CI cannot prove.

      **How:** unlock the iPhone and connect it (cable, or Wi-Fi debugging on
      the same network) until `xcrun xctrace list devices` shows it under
      `== Devices ==` rather than Offline, then run `npm run app:install` to
      build and deploy. Open Settings → Diagnostics, enable VoiceOver
      (triple-click the side button, or Settings → Accessibility →
      VoiceOver), and swipe through every control in that section.
      **Verify:** every control announces a real label (never a bare
      "button"), and `npm run app:install` exits 0.

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

- [ ] **[P3]** **[Needs owner]** **Hosted opt-in-sync for on-device state
      (deferred, not built).** The 2026-08-05 IndexedDB migration above keeps
      visitor state (crash-reporting consent, theme, debug flag) on-device
      only, so it still doesn't survive a device change or browser data
      clearing — the original complaint that prompted the migration. A hosted,
      explicitly opt-in sync layer would fix that, but it is a real change of
      posture: the first server-side store this project would ever have, and
      it would need `docs/PRIVACY.md`, `legal/PRIVACY_POLICY.md`,
      `legal/SUBPROCESSORS.md`, and the consent flow updated in the same
      change (same reasoning the original entry above gave for a hosted
      database). Not scoped or estimated. Needs the owner to decide whether
      it's worth building at all before any design work starts.

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

- [ ] **[P2]** **[Needs owner]** **VoiceOver pass on the rendered README.** The
      graph SVG carries `<title>`, `<desc>`, and `role="img"`, and the `<img>`
      carries alt text naming the clusters and hub nodes — but none of it has
      been heard through a real screen reader, and a decorative-image
      misannouncement here would be exactly the failure this repo gates against.

      **How:** open `README.md` in a renderer that keeps the `<picture>`/`<img>`
      markup (GitHub's web view works) with VoiceOver running, and navigate to
      the "Knowledge Graph (Graphify)" section's image. **Verify:** VoiceOver
      announces the alt text (the cluster/hub-node names), not "image", the
      filename, or silence.

### Config dedupe + Headroom teardown verification (2026-07-31, 12:00 PST)

Produced by an audit of RTK/Serena wiring, global vs. project settings
redundancy, and the `127.0.0.1:8787` question. The token-leak fix itself is
recorded under the `tmp/handoff.md` entry further down; these are what is left.

- [ ] **[P1]** **[Needs owner]** **cswap rotation is still broken, symptom has
      shifted.** Re-verified 2026-08-06: the original "both slots hold the
      same credential" warning is gone — `cswap list` now shows two distinct
      emails (`kevinle3212@gmail.com` active, `kevinle@uoregon.edu` idle). But
      rotation still doesn't work: slot 2 reports `re-login needed — refresh
      token dead; log in with Claude Code, then run: cswap add`, and
      `cswap status` still shows `live credential belongs to another account
      — a switch repairs it` on slot 1. Net effect is unchanged from the
      original finding — only one account is actually usable.

      **How:** log in to Claude Code as `kevinle@uoregon.edu` (interactive
      browser login, cannot be scripted), then run `cswap add --slot 2` — the
      `--slot` argument stops it landing in a third slot. If `cswap list`
      still shows a stale-token or same-credential warning afterward, run
      `cswap remove 2` first and re-add. **Verify:** `cswap list` shows both
      slots with no `re-login needed` or `hold the same credential` warning,
      and `cswap status` no longer shows `live credential belongs to another
      account`.

### Live secrets sit unexpanded in `~/.claude.json` (2026-07-31, 01:00 PST)

- [ ] **[P1]** **[Needs owner]** **Rotate the two credentials, then shred the
      backup that still holds one.** A 40-char GitHub PAT and a 32-char Dune
      API key sat as plaintext literals in `~/.claude.json`
      (`mcpServers.github.env.GITHUB_PERSONAL_ACCESS_TOKEN` and
      `mcpServers.dune.headers["x-dune-api-key"]`).

      Re-verified 2026-08-06: `bash ~/.claude/scripts/migrate-mcp-secrets.sh
      --check` now reports both as **absent** from `~/.claude.json` (no longer
      `LITERAL`) — the config-file exposure is closed. What remains is
      owner-only:

      1. **Rotate both at the issuer** — removing a value from the config does
         not invalidate it; both are presumed still valid. GitHub PAT:
         <https://github.com/settings/tokens>. Dune key:
         <https://dune.com/settings/api>.
      2. **Shred the last copy of the Dune key**: `~/.claude.json.bak.premcpmerge`
         still exists (confirmed present 2026-08-06, 0600, dated 2026-07-18)
         and still contains the Dune key as a literal (the GitHub PAT is not in
         it; that backup predates it). Run `rm -P
         ~/.claude.json.bak.premcpmerge` after rotating.
      3. **Verify:** `bash ~/.claude/scripts/migrate-mcp-secrets.sh --check`
         continues to report both as absent, and `ls ~/.claude.json.bak.*`
         returns no matches.

      Repo itself stayed clean throughout — `ggshield secret scan repo .`
      passed on full history, and neither value ever appeared in tracked
      files.

### Dedicated Google Account for project tooling (2026-07-30)

- [ ] **[P3]** Create a Google Account dedicated to SenseBridge (not the
      owner's personal account), then migrate every tool currently
      authenticated under a personal/ad-hoc Google account (Analytics, Search
      Console, Firebase, Drive, or any other OAuth-connected service) onto it.
      Lowest priority — revisit only after everything else in this file.
      **Verify:** each service's admin/access page lists only the dedicated
      account, not the personal one.

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
      **Re-checked 2026-08-12** — both upstreams still absent:
      `~/.gemini/skills/impeccable/scripts/hook.mjs` does not exist, and
      `serena-hooks` exposes no `gemini`/`antigravity` client value. Still open,
      still not worth hand-rolling around.

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

**Third re-check (2026-08-07), both blockers still hold, nothing moved
upstream:** `serena-hooks activate --help` / `remind --help` / `auto-approve
--help` still cap `--client` at `[claude-code|vscode|codex]`, no `gemini`
value. `.gemini/skills/impeccable/scripts/hook.mjs` (present from the prior
`npx impeccable update`, itself now at 3.5.0) still only branches on
`hook_event_name === 'Stop'` / the `PostToolUse` path — still not
Gemini's actual event names. Still a genuine upstream gap, still not worth
hand-rolling around; revisit only when one of the two lands.

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

- [ ] **[P2]** **[Needs owner]** The glasses browline (`BROWLINE_Y` in
      `src/scripts/scenes/glasses.ts:46`, currently `LENS_RADIUS + 0.15`)
      floats visibly detached above the lens rims, which reads as a stray bar
      once the model is dragged toward profile. Pre-existing geometry,
      untouched under surgical-changes — decide whether to lower it onto the
      rims or leave it as stylization. To fix: lower the offset toward
      `LENS_RADIUS` (e.g. `LENS_RADIUS + 0.02`) and re-run
      `npm run check:scene-drag`, then eyeball `#future` in a local dev build
      dragged to profile to confirm the bar now sits on the rim.

- [ ] **[P2]** **[Needs owner]** Judgement call: no lens fill or waveguide
      display plane was added to the glasses. A translucent disc muddies the
      wireframe read, so it was deliberately skipped — say if it's wanted.

- [ ] **[P2]** **[Needs owner]** Run the drag on a real touch device.
      `touch-action: pan-y` is asserted by CSS and reasoned about, but the
      headless check drives a mouse — the horizontal-drag-vs-vertical-scroll
      split on an actual phone is unverified. To verify: open the deployed
      site on a phone, scroll to the `#future` glasses stage, drag the model
      horizontally (should orbit it, not scroll the page) and then scroll
      vertically past it normally (should scroll the page, not orbit).

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
      plan/org). `.github/workflows/github-models.yml` already exists and
      runs `models: read` jobs on every push to `main` and PR touching
      `.github/prompts/**`, which implies access already works — but that has
      not been confirmed via the marketplace page itself.

- [ ] **[P2]** **[Needs owner]** `.github/workflows/github-models.yml`
      already scaffolds `actions/ai-inference` (final pick:
      `openai/gpt-4.1`, not the DeepSeek-V3-0324 discussed — check
      `.github/prompts/*.prompt.yml`'s `model:` field if that should change).
      What is not verified: a manual `workflow_dispatch` run succeeding in
      Actions. To verify: Actions tab → "GitHub Models prompts" → Run
      workflow, then confirm the `prompt-files` matrix jobs complete with a
      non-empty response for each prompt.

### Docs GH Pages header/content gap (2026-07-28, 12:00 PST)

Owner reported no visible gap between the sticky nav header and the page
content on `https://kevinle3212.github.io/sensebridge/`. A static read of
`docs/assets/css/docs.css` found no bug: `main` already has
`padding-block: 24px` (`40px` at ≥900px, lines 300-320) and `.signal-hero`
carries no negative margin. The live site was serving `main`'s last deploy
the whole time this was checked, which predated the PR fixing the adjacent
hero-SVG "Camera" clip (merged 2026-07-28 as `5e26b01`) — so this needs a
fresh look now that the fix is live, not more static reading.

- [ ] **[P3]** **[Needs owner]** A newer deploy is live (`Last-Modified: Tue,
      04 Aug 2026`, confirmed via `curl -I`, postdating the `5e26b01` fix),
      so this is now checkable. Load
      `https://kevinle3212.github.io/sensebridge/` and check the
      header/content boundary directly (screenshot or a headless-browser
      pass — no visual-regression tooling covers `docs/` today). If a gap is
      genuinely missing, it's most likely something JS-driven or
      page-specific, not the shared `main`/`.signal-hero` rules already read.

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

**Regenerated 2026-08-05** — the prior `tmp/logo/` output (and its 5 build
scripts) had been cleared to `~/.Trash` since 2026-07-27 (`tmp/` is
gitignored and gets swept); recovered the 5 scripts from there, then ran the
full pipeline fresh per the steps above: `python3 -m venv /tmp/logo-venv`,
then `pip install fonttools brotli`, `build-wordmark.py`, `build-svg.js`,
`build-raster.js`, `build-sheet.js`, `build-preview.js`. Output lands back
in `tmp/logo/`: 56 SVG masters, 281 rasters (207 PNG + 52 JPEG + 1 ICO + 21
app-icon), `index.html`, `wordmark.json`. Verified as real (not truncated):
`build-preview.js`'s own puppeteer pass reports "broken images: 0,
console/request errors: 0"; file counts cross-checked file-by-file against
the manifests with `rtk proxy find` (the default `find` rewrite undercounted
the `svg/` dir); every file freshly timestamped and non-trivial in size (3.4
KB–90.6 KB PNGs, 490 B–14.7 KB SVGs). No API key or network dependency in
any of the 5 scripts — pure vector extraction from the vendored Fraunces
woff2 plus local raster/screenshot rendering. Not wired into production
(favicon swap, app icon, credits) — that stays gated on the open items
below per owner decision.

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
      can check this: ARKit produces no frames there. On device: start
      hands-free awareness, point the camera at a known object, and confirm
      the yellow outline sits on it rather than offset — an offset outline
      means the video-format assumption broke.

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
      images cannot settle this. On device: point the camera at objects of
      varying size and distance and note where outlines under- or
      over-trigger; adjust `minimumRegionArea` and rerun if consistently
      wrong.

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
      this. How to check: wear the phone for a 15-20 minute walk with
      hands-free awareness running, then check Settings > Battery > SenseBridge
      for drain rate and watch for the iOS thermal-throttling banner; compare
      against an equal-length walk with the app merely foregrounded and idle.

- [ ] **[P1]** **[Needs owner]** **Blind-tester pass on the narration cadence.**
      Defaults are 6 s between descriptions, 20 s before an unchanged scene is
      re-stated, 1.5 m alert distance, 750 ms depth sampling. These are guesses
      about how much speech is useful versus exhausting in the ear all day, and
      that judgement is not the developer's to make. How to check: have a
      blind or low-vision tester wear the phone chest-mounted for a real walk
      and report whether the defaults feel right, too frequent, or too
      sparse; adjust the Settings > Awareness sliders (`narrationIntervalSeconds`,
      `awarenessAlertDistanceMeters`) if they say so.

- [ ] **[P1]** **[Needs owner]** **VoiceOver pass on the rebuilt Awareness
      screen and the new Settings "Awareness" section.** The screen changed from
      a `VStack` to a sectioned `List` with a start/stop control, three
      conditional status rows, and two new sliders. Zero unlabelled elements is a
      hard gate and a machine cannot certify it. **Partially escalated
      2026-08-05** — added `testAwarenessScreenPassesAccessibilityAudit`/
      `testSettingsAwarenessSectionPassesAccessibilityAudit` to
      `AlphaScaffoldingUITests`, exercising `performAccessibilityAudit()` on
      both screens (both now pass on Simulator; see the "App-wide screens
      have no ScrollView" completion above for the fixes this surfaced).
      This is the machine-certifiable half — zero unlabeled elements, hit
      targets, contrast — now automated for these two screens. What's left
      is genuinely owner-only: subjective navigation/rotor flow under a real
      VoiceOver session, which the automated audit doesn't judge. How to
      check: enable VoiceOver (Settings > Accessibility > VoiceOver), swipe
      through the Awareness screen and Settings > Awareness section, and
      confirm reading order matches visual order and the rotor exposes every
      control.

- [ ] **[P2]** **[Needs owner]** **Native-speaker review of three new es/vi
      strings** in the Core String Catalog: `"something ahead"`,
      `"something about %@ ahead"`, and
      `"The nearest measured distance is further away now."` These are
      doctrine-pinned physical-world language, written without a native speaker.
      **Scope grew 2026-08-12** — the same reviewer should now also cover, in
      one pass: (a) the ~75 `es`/`vi` entries in `SpokenVocabulary.swift`, which
      are seeded but unreviewed, and where Vietnamese classifier choice
      (`cái`/`con`/`chiếc`/`quyển`) is the part most likely to be wrong; (b) the
      five new lifecycle/thermal strings in the Core catalog ("the phone is
      warm/hot", the two hands-free stop/resume sentences, and the back-to-normal
      one); (c) the new `read_aloud_now_section` website message; and (d) the
      `DetailLevelSettingsSection` footer copy. Nothing in (a) is derived from
      anything else, so a reviewer changing one entry changes only that entry.
      Mis-naming a physical object is ranked above a crash in
      [`docs/SAFETY-FRAMING.md`](docs/SAFETY-FRAMING.md), which is why the
      lookup falls back to the English phrase rather than guessing.

### `docs/` accuracy overhaul + designed Pages site (2026-07-26, 05:00 PST)

Bringing every page in `docs/` factually current and publishing it as a
designed, animated GitHub Pages site with a custom Jekyll layout layer.
Markdown stays canonical — the design ships as `docs/_layouts/`,
`docs/_includes/`, `docs/_data/`, and `docs/assets/{css,js,fonts}/`, because
~40 in-repo `docs/*.md` references, GitHub's own markdown rendering, and
`tools/generate-wiki-home.mjs` all depend on those files staying where they
are. Session log: `sessions/2026-07-26/0500-PST.md`.

- [ ] **[P1]** **The new `docs-a11y` CI job has never run on a GitHub runner.**
      It was verified only locally (macOS, Node 26, Puppeteer's cached Chrome).
      CI differs in three ways that could each break it on the first PR:
      `actions/jekyll-build-pages` writes to `./_site` and its exact output
      path is assumed, not verified; `npm install --no-save puppeteer` must
      download Chrome on an ubuntu runner under Node 22, not the Node 26 this
      machine runs; and the runner's headless Chrome uses a different GPU stack
      than the macOS one the `--enable-unsafe-swiftshader` fallback was
      exercised against. The "first PR" already happened and merged (PR #42,
      commit `339cec6`, 2026-07-27) and several docs-touching PRs (#53, #56)
      have merged since with no follow-up TODO flagging a failure — but that's
      circumstantial, not a confirmed pass (checking Actions history needs
      `gh`/the web UI, which agents don't run autonomously). How to check:
      open the repo's Actions tab, find the `docs-a11y` job on PR #42 or any
      later docs-touching run, and confirm it's green; treat a failure as the
      job's problem, not the site's — the site itself is verified green
      locally.

- [ ] **[P2]** **[Needs owner]** A real screen-reader pass over the rendered
      docs site — VoiceOver on Safari and NVDA on Windows — covering the
      sidebar nav, the scroll-spy table of contents, the command-palette
      search combobox, the theme control, and the copy-code buttons. Automated
      checks are not a screen-reader session, and this is an accessibility
      project: a clean build must never be presented as validation by the
      people it is for. Also needs a keyboard-only walkthrough and a
      `prefers-reduced-motion` check on a real OS toggle.

- [ ] **[P3]** **[Needs owner]** The unused `jekyll/jekyll:4` Docker image
      (2.05 GB) can be removed; this machine has ~17 GB free. Command:
      `docker image rm jekyll/jekyll:4`. Couldn't verify whether it's already
      gone — the Docker daemon isn't running on this machine and starting it
      just to check is out of scope. How to verify: `docker images | grep
      jekyll` should return nothing after the removal.

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
      ~1.3s locally but spikes past 5s. Confirmed the setting is still present
      at this value. How to do it: Cmd+Shift+P > "Developer: Reload Window".
      How to verify: run a SweetPad build/task a few times and confirm no
      shell-timeout error, even when `zsh -i` startup spikes.

- [ ] **[P3]** **[Needs owner]** Restart the Claude Code session so the
      WakaTime `PostToolUse` hook loads. A test heartbeat was accepted (no
      offline-queue file written), so the wiring itself is verified. How to
      verify after restart: make an edit in the new session, then run
      `~/.wakatime/wakatime-cli --today` and confirm coding time is
      incrementing (or check the WakaTime dashboard for a fresh
      `claude-code/1.0` heartbeat).

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

- [ ] **[P2]** **[Needs owner]** **App Store Connect / TestFlight** — needed at
      Phase 2 public beta ([`docs/ROADMAP.md`](docs/ROADMAP.md)), the project's
      largest future external-service surface. **No Composio toolkit exists**
      (searched 2026-07-26 and re-confirmed 2026-08-06:
      `"app store connect testflight ios build"` returns only mobile-CI
      vendors — `codemagic`, `appcircle` — with no native Apple/App Store
      Connect toolkit; `"apple developer program membership"` falls through to
      generic web search — that fall-through is itself the proof no Apple
      toolkit exists). Do not hold a distribution task waiting on one. The
      real setup path, in order, none of it Composio:
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
      Verify: `xcrun altool --upload-app` (or the CI workflow's equivalent
      step) exits 0, and the build appears under App Store Connect →
      TestFlight for the app.

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
      → add the domain → assign to Production. It currently resolves but was
      stale as of 2026-07-24 (last built 2026-07-21, not in the current
      production deployment's alias list) — a leftover manual assignment
      that auto-alias-on-deploy no longer touches. One-time; after that it
      updates automatically on every future push same as the project's other
      three domains already do. **Re-checked 2026-08-06** — `curl -sI
      https://sensebridge.vercel.app` now returns a `last-modified` of
      today's date (age ~15 min), so the staleness this item reported is
      gone; that's consistent with the domain now being on Production, but a
      `curl` can't distinguish that from some other auto-alias behavior —
      confirm on the dashboard link above before closing this out.

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
      **Engineering half done 2026-08-12; the examples half still needs you.**
      Both improvements this item names are now implemented, without waiting on
      specifics, because neither depends on which examples you bring:
      - **Reading order is banded, not `y`-sorted.** Two words on one printed
        row almost never share an exact `y` — glyph heights, a dipping comma,
        any camera tilt — so the old strict sort interleaved columns and read a
        receipt's item and its price as separate lines far apart. Boxes whose
        vertical centre falls inside a row's span now group into that row and
        order by `x`. Centre-in-span rather than any-overlap, so a tall heading
        brushing the line beneath it does not swallow it.
      - **Low-confidence lines are dropped, not spoken.** Vision returns a
        plausible string for a smudge; speaking it is a claim about text that
        may not exist. Floor is `0.3` and deliberately low — a floor against
        garbage, not a quality bar, since legitimate text shot at an angle
        scores mid-range and a silent omission is worse than a visible mistake
        for someone who cannot see that anything was missed.
      The ordering logic was extracted as a generic `inReadingOrder(_:boundingBox:)`
      specifically so it could be tested against plain rectangles — Vision's
      observation types cannot be constructed in a test, which is why the old
      ordering was only ever exercised through a rendered image. **Verified:**
      5 new unit tests (same-row unequal `y`, top-to-bottom rows, the tall
      heading, empty/single input, three columns) plus the existing
      rendered-image tests; package suite 183/183.
      **Still open, and genuinely yours:** the concrete examples. If the
      remaining complaint is garbled *words* rather than order or noise, the
      next lever is `recognitionLanguages`, and picking it needs to know
      whether you are reading English or something else.

### Read/OCR wiring follow-ups (2026-07-23)

- [ ] **[P2]** **[Needs owner]** Confirm the Read flow on a physical device:
      launch the app, grant camera permission, aim at real printed text, tap
      Capture, and confirm the recognized text is spoken correctly. This is
      the first real (non-simulator) exercise of `CameraSource`/`OCRService`.

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
      a 404 on the personal-account Copilot-seat endpoint (re-confirmed
      2026-08-06, still absent). Verify it worked: `gh api
      repos/kevinle3212/sensebridge/assignees --jq '.[].login'` lists a
      Copilot bot login once enabled.

- [ ] **[Needs owner]** Checking GitHub Projects (v2) board status needs a
      wider CLI token scope. Grant explicit one-turn permission for `gh auth
      refresh -s read:project`, then run `gh project list --owner
      kevinle3212 --format json`. Not run this or the prior session — it
      changes the stored CLI token's scopes, outside the granted "run gh api
      commands" permission. Verify: the command returns the project list
      instead of a missing-scope error.

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

- [ ] **[P3]** **[Needs owner]** Generate a real `og:image`/`twitter:image`
      (1200×630 PNG), add it under `website/public/`, and wire the two meta
      tags next to the existing OG/Twitter block in
      `website/src/layouts/BaseLayout.astro:71-78` — currently omitted
      rather than pointed at a nonexistent file. Verify: after deploy, view
      page source (or run a social-preview debugger) and confirm the image
      URL resolves instead of 404ing.

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
      Developers → API keys → roll key. Verify: the dashboard's API keys
      page shows a new "created" date on the test secret key and the old one
      marked rolled/revoked — don't re-run `stripe config --list` to check,
      that's what leaked it originally.

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

### Signal Bridge motif follow-ups (2026-07-18)

- [ ] **[P1]** **[Needs owner]** Real VoiceOver pass over the Signal Bridge
      section (`website/src/components/SignalBridge.astro`, between Hero and
      Features) — no machine check substitutes for a screen-reader session.
      The automated half is done: `npm run test:a11y` (pa11y-ci) passes
      **8/8 URLs, 0 errors** across the built site, this section included
      (verified 2026-07-26). How to do it: `npm run build && npm run
      preview`, enable VoiceOver (Cmd+F5), tab/VO-navigate through the
      section. Verify: every element announces a sensible label/role,
      reading order matches visual order, no silent or mislabeled controls.

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
      static code inspection only. How to do it: `npm run build && npm run
      preview`, then walk the built site with VoiceOver (macOS) or NVDA
      (Windows), and again keyboard-only (no mouse). Verify: focus order
      follows visual order, every interactive element has an announced
      label, and nothing traps or skips keyboard focus.

- [ ] **[P2]** **[Needs owner]** Visual sign-off of the pointer-reactive hero
      glow on a real device — owner approved it conditionally ("aesthetic and
      clean"); headless screenshots (2026-07-18 session) show the bloom
      following the pointer at unchanged intensity, but the final call is the
      owner's. Pull it (ship the static glow) if it reads as gimmick.

### Website rebuild ("First Light" Astro site) follow-ups (2026-07-18)

- [ ] **[P1]** **[Needs owner]** Manual accessibility pass on the rebuilt
      site: VoiceOver + keyboard-only walkthrough, and a
      `prefers-reduced-motion: reduce` check that the page is complete and
      static (pa11y-ci passes with 0 errors, but the human gate per
      `docs/TESTING.md` cannot be automated). Verify: every element has a
      sensible VoiceOver label, focus order matches visual order, and with
      reduced motion enabled the page shows no animation.

- [ ] **[P1]** **[Needs owner]** Lighthouse mobile run in a real browser
      against the built site: `npm run build && npm run preview`, then run
      Lighthouse (Chrome DevTools → Lighthouse tab, Mobile preset) against
      the preview URL. Verify: ≥95 on all categories, LCP element is the
      hero H1 text. CI has no Lighthouse job yet — add one if the manual run
      regresses.

- [ ] **[P2]** **[Needs owner]** Re-verify the Railway deploy after merge:
      service Root Directory still `website`, new multi-stage Dockerfile
      builds on Railway, site serves on `$PORT`.

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
      (2026-07-17 evening, all optional-when-wanted). `agent-browser
      install` and `brew install ffmpeg` are done — confirmed 2026-08-06
      (`which agent-browser` and `which ffmpeg` both resolve). `granola` was
      removed from the MCP config on 2026-07-31 (zero calls in 30 days, see
      `docs/TOOLING.md` → MCP inventory) — drop that step. `higgsfield`
      authentication step is moot — the server was found dead (HTTP 401,
      zero working tools) and disabled on 2026-08-03; see
      `~/.claude/REMOVED-MCP-SERVERS.md` → "Disabled, not removed". Only
      re-add it if a future check shows the endpoint is back online.
      Remaining: trigger the NotebookLM skill's first run yourself (pip +
      Chrome download + Google login, deliberately manual); set
      `APIFY_API_TOKEN`/`GOOGLE_AI_API_KEY` only if the two dependent social
      skills are ever wanted.

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

- [ ] **[P1]** **[Needs owner]** On-device latency/battery/thermal
      benchmarking and blind/low-vision tester validation — standing item,
      not a one-time task; no machine (including CI) can substitute for this.
      See `docs/TESTING.md` and the `ci-green-gate` skill.

### Website audit follow-ups (from `/impeccable audit website`, 2026-07-11)

- [ ] `/impeccable polish website` — final pass once the above land.

### CI/security automation audit (2026-07-27)

- [ ] **[P3]** **[Needs owner]** CodeQL alert #93 (`js/file-access-to-http`,
      `tools/docs-a11y.mjs:159`) is still open after the 2026-07-28 inline-
      suppression reformat (`339cec6`): confirmed 2026-08-06 via `gh api
      repos/kevinle3212/sensebridge/code-scanning/alerts/93` —
      `state: open`, `most_recent_instance` is the current `main` HEAD, so
      CodeQL has rescanned since the fix and still flags it. Dismiss
      manually: repo → Security → Code scanning → alert #93 → Dismiss →
      "False positive", justification: URL host is always
      `http://127.0.0.1:PORT`, only the path segment is filesystem-derived
      and already passed through `SAFE_HTML_FILENAME` (see the comment
      directly above the flagged line). Verify: `gh api
      repos/kevinle3212/sensebridge/code-scanning/alerts/93 --jq .state`
      returns `dismissed`.

## In Progress

*Nothing in progress.*
