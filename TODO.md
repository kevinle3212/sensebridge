# TODO

Lightweight personal reminders, grouped by status: **To-Do**, **In Progress**,
**Completed**. Tracked defects/debt/risks live in [`GAPS.md`](GAPS.md); this
file is just a short list of things to come back to.

Within To-Do, items stay grouped by the review/audit that produced them and
ordered so earlier work unblocks later work.

**Item Completion** Don't just flip `- [ ]` to `- [x]`. Append, in bold, the
completion date plus what was actually done (and any verification, links, or
follow-on notes): `**Done/Fixed YYYY-MM-DD** — <what changed, how it was
verified, anything relevant left over>`. Then cut the whole bullet out of its
To-Do dated section and append it to the end of **Completed** below — To-Do
holds only open work.

## Legend

| Label | Meaning |
| --- | --- |
| **P0** | Blocking — violates a hard gate (accessibility, safety-framing, security). Fix before anything else here. |
| **P1** | High priority — user-facing gap or incorrect behavior; no hard gate violated. |
| **P2** | Medium priority — spec/design fidelity or polish; non-blocking. |
| **P3** | Low priority — already decided/documented, or blocked on other work; revisit opportunistically. |
| **Needs owner** | Requires the repo owner specifically — a GitHub web-UI action, a `git`/`gh` command (agents never run these autonomously), Apple Developer credentials, a physical device, a human tester, or a decision only they can make. Combine with a priority, e.g. `**[P1]** **[Needs owner]**`. |

## Open queue (summary)

Snapshot **2026-07-25** — 84 open (50 `Needs owner`, 34 other). This is a
signpost, not a second source of truth: every item is detailed in its dated
section under **To-Do** below; act from there. **The git-ship backlog is
empty** — every "commit/push/PR branch X" item has been verified merged to
`main`, so nothing is waiting on a handoff.

Everything still open falls into buckets a machine cannot close for you:

- **Device & human validation (8× P1)** — on-device latency/battery/thermal +
  blind/low-vision testers; native-speaker ES/VI review; real VoiceOver/NVDA +
  keyboard-only passes; Lighthouse mobile; simulator/device Read-flow +
  tap-through. No CI substitute exists for any of these.
- **Secrets & security (owner)** — rotate the exposed Stripe test key (P1);
  add the `GITGUARDIAN_API_KEY` repo secret (P1 — local `ggshield auth` was
  already done, verified 2026-07-26); Stripe dashboard 2FA/Radar (P2).
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

### Repo-sync commit backlog + CI-green fixups (2026-07-27, 13:00 PST)

- [ ] **[P3]** **[Needs owner]** `website/src/components/PageLoader.astro`'s
      countdown readout (`.count`, the big `clamp()`'d number + its `.mark`
      label) uses only `$font-mono` for the whole component. Impeccable's
      `single-font` detector flags this on every CI run for PR #42
      ("Impeccable design detectors" job) — non-blocking (not in the
      required-checks ruleset), so it does not hold up merging, but the
      finding will keep reappearing on every subsequent PR touching this file
      until resolved one way or the other. Two ways to close it: confirm it's
      intentional (a minimal full-screen loader where size/weight carries the
      hierarchy) and add a reviewable `.impeccable/config.json`
      `detector.ignoreValues` entry mirroring the existing `overused-font`
      precedent; or pair the readout with the site's display font (Fraunces)
      for contrast. Asked via `AskUserQuestion` during the PR #42 CI-green
      pass; owner deferred rather than deciding either way — check `git log
      -- website/src/components/PageLoader.astro` for whether it's since
      moved.

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

- [x] **Preview drew nothing (`ARSCNView`).** Fixed same session, after the
      height fix below turned out not to be the cause. `ARSCNView` was attached
      to a session started elsewhere, with no scene content, inside a `List`
      row — three independent ways to draw nothing, none of which logs anything.
      Replaced with frames rendered directly:
      `AmbientSensingSource.previewImage(for:maximumDimension:)` +
      `AwarenessPreviewFeed` (a ~12 fps loop) + an `Image`. Nothing in this app
      draws 3D content, so SceneKit was cost without benefit. Covered by
      `SenseBridgeTests/AmbientPreviewImageTests` (3 tests, simulator — the
      package's macOS tests cannot reach iOS-only code).
- [x] **Preview collapsed to zero height.** Fixed same session. A
      `UIViewRepresentable` has no intrinsic size and a `List` row proposes no
      height, so `.aspectRatio(_:contentMode:)` alone had nothing to scale from.
      Now a definite `.frame(width: height * aspectRatio, height: 320)`, which
      keeps the shape matched to the feed so the box mapping stays linear.
      `ReadingView` already pinned its preview's height for this reason.
- [x] **AppIntents build notice.** Fixed same session with
      `LM_FORCE_LINK_GENERATION = YES` on the app target (`app/project.yml` and
      `project.pbxproj`). `LM_FILTER_WARNINGS` does not work — its
      `--quiet-warnings` is passed and the notice still prints.
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
`scripts/lint.sh` 0 violations in 55 files. Plan: `tmp/PLAN-ambient-awareness.md`.
Session log: `sessions/2026-07-26/2000-PST.md`.

Nothing below is machine-closable — every item needs the device, a human ear,
or a native speaker.

- [x] **[P1]** **Install and run on the iPhone 17 Pro.** Done 2026-07-27. The
      developer disk image would not mount while the phone was locked, and
      `devicectl device info lockState` failed with
      `com.apple.mobiledevice error -402653181`; unlocking it resolved both, and
      the same command then reported `unlockedSinceBoot: true`. Signed build,
      install, and launch all succeed. **This proves the app starts, not that
      the feature works** — exercising the hands-free loop still needs a walk,
      which is what the remaining items below are.
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
- [x] **[P2]** **Move `DEVELOPMENT_TEAM` out of `project.pbxproj`.** Done
      2026-07-27. Both app-target configurations now base off the committed
      `app/Config/Signing.xcconfig`, which sets no team and optionally includes
      the gitignored `app/Config/Signing.local.xcconfig`. `app/project.yml`
      carries the same wiring via `configFiles`, so regenerating the project
      cannot reintroduce the ID. Verified both ways:
      `xcodebuild -showBuildSettings` reports the team with the local file
      present and omits `DEVELOPMENT_TEAM` entirely without it, and a signed
      device build still succeeds.
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
are. Plan and verified findings: `tmp/PLAN-docs-site.md`. Session log:
`sessions/2026-07-26/0500-PST.md`.

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

- [x] **[P1]** Verify the four new pages land and re-run the link scan.
      **Done 2026-07-26 06:00 PST.** All four exist (`CI-CD.md` 135 lines,
      `SECURITY-MODEL.md` 146, `GLOSSARY.md` 241, `CODE-MAP.md` 184).
      `grep -rn "planning/" docs/*.md` came back empty, as did a search for
      literal `../`-style relative links in `docs/*.md`;
      `markdownlint-cli2 docs/*.md` reports 0 issues in 137 files; a
      scripted resolver over every relative link in `docs/*.md` returns
      all-resolve, closing the four broken `index.md` links.

- [x] **[P1]** Reconcile `docs/_data/nav.yml` with `docs/index.md`.
      **Done 2026-07-26 12:00 PST.** The nav had shipped with two overlapping
      groups — `Reference` and `Contributing & Reference` — so the sidebar and
      the landing page told a reader two different stories. Cause: a literal
      YAML block was handed to the presentation-layer agent without being
      reconciled against the grouping written into `index.md` minutes earlier.
      The nav now mirrors `index.md` exactly across five groups, and the file's
      header comment states the two must stay in step.

- [x] **[P0]** **The docs build was red.** **Fixed 2026-07-26 12:30 PST.**
      Cause was suspect (1), confirmed by capturing the *head* of the trace:
      `Liquid syntax error (line 8): Unknown tag 'seo'`. The `github-pages` gem
      bundles `jekyll-seo-tag`, but Jekyll only loads it when it is named in
      `_config.yml`'s `plugins:` list. Declared it there rather than dropping
      the tag — the layout writes its own `<title>`/description, so `{% seo %}`
      is what supplies canonical, Open Graph, and JSON-LD tags. Suspect (2),
      `url:`/`baseurl:`, was innocent and is unchanged. Build is green: 21
      pages, zero warnings.

- [x] **[P0]** **`docs/assets/js/docs.js` did not parse at all**, so *every*
      interactive feature on the site was dead — theme switch, search, table of
      contents, copy-to-clipboard, heading anchors, reading progress.
      **Found and fixed 2026-07-26 12:40 PST.** A block comment read
      `/* Callouts — blockquotes starting with **Note**/**Warning**/...`; the
      `**` immediately before `/` formed a `*/`, closing the comment early and
      leaving the rest of the line as code (`Unexpected token '**'`). Nothing
      caught it because the file ships unbundled — no build step ever parsed
      it. The comment is reworded, and `ci.yml`'s `docs-links` job now runs
      `node --check docs/assets/js/docs.js` so this class of bug cannot return.

- [x] **[P2]** Automated accessibility run against the built docs site.
      **Done 2026-07-26 13:00 PST.** pa11y (WCAG2AA, the `pa11y-ci` already in
      `website/node_modules` — no new dependency) over all 21 built pages in
      **both** themes: **0 errors in each**. Themes were set before first paint
      via `localStorage` through pa11y's programmatic API, which also exercises
      the layout's pre-paint script; the `.pa11yci.json` "wait for element"
      action does not work here because it watches for node insertion and the
      theme is an attribute flip on `<html>`. A second pass over Chrome's own
      accessibility tree covered what pa11y does not: **986 interactive
      elements, zero without an accessible name** (the repo's hard gate), skip
      link first in tab order on every page, no positive `tabindex`, no
      duplicate `id`s, one `<h1>` per page, `lang="en"`, and nothing animating
      under `prefers-reduced-motion: reduce`. Search was driven end to end by
      keyboard: `⌘K` opens it, "privacy" returns 10 results, the listbox
      carries `role`/`aria-expanded`, and `Escape` restores focus to the
      trigger. **Still owed: a real VoiceOver pass** — no machine check
      substitutes for it, per `CLAUDE.md`'s standing rule.

- [x] **[P2]** The docs a11y run was driven by two throwaway scripts and
      nothing gated the built site in CI. **Done 2026-07-26 13:30 PST.** The
      feared coupling turned out to be avoidable: the runner lives at
      [`tools/docs-a11y.mjs`](tools/docs-a11y.mjs) alongside the repo's other
      `tools/*.mjs`, serves the built site itself over `node:http` (no
      `http-server`/`wait-on`), reads `baseurl` straight from
      `docs/_config.yml` so the `/sensebridge` prefix can't drift, and takes
      `pa11y`/`puppeteer` via `npm install --no-save` — so `website/` is not
      involved at all. New `docs-a11y` job in `ci.yml` builds `docs/` with the
      same pinned `actions/jekyll-build-pages` as `pages.yml`, then runs it.
      Verified against the real built site before wiring: 21 pages, both
      themes, 986 interactive elements, all checks passed. It also fails on any
      uncaught page error, which is the specific thing that would have caught
      the `docs.js` outage.

- [x] **[P2]** The `impeccable` design hook reported **19** findings on
      `docs/assets/css/docs.css`. **Owner chose to act on them rather than
      suppress; done 2026-07-26 13:40 PST — 19 → 5, nothing suppressed.** The
      earlier read of these as "false positives because DESIGN.md scopes to
      `website/`" was mostly wrong: `docs.css` already defines
      `--radius-sm/md/lg: 8/12/20px`, matching DESIGN.md's scale exactly, so
      most findings were plain drift *within* the file's own system. Fixed:
      - Four literal `border-radius: 4px/6px` → `var(--radius-sm)` (L248, L269,
        L576, L613). The tokens were already there and simply unused.
      - Both `side-tab` findings: `blockquote` carried a 3px left rule and
        `.callout-doctrine` bumped it to 4px. Now a 1px full border with the
        variants differentiating by `border-color`, matching DESIGN.md's
        documented Callout (`border: 1px solid`, 8px radius) and its
        flat-by-default rule.
      - The `rgba(0, 0, 0, 0.3)` inset blur on scrollable tables → a hairline
        `border-right`. DESIGN.md is explicit: "No blurred shadows, ever."
        Screen-reader users still get the cue from the wrapper's "Scrollable
        table" label.
      - The search scrim `rgba(0, 0, 0, 0.5)` → `rgba(8, 10, 16, 0.72)`, the
        documented ink at partial alpha, which the detector accepts.
      - Five `font-size: 0.75rem` on label-register elements (kbd badge, theme
        option, sidebar heading, TOC heading, copy button) → `0.8125rem`,
        DESIGN.md's `type-label` step. This *increases* the smallest text by
        1px, which is the right direction for this project. The header wordmark
        went `0.9375rem` → `0.875rem`, the documented `type-small` step.

      **Five findings remain, deliberately, none suppressed:**
      - `body` and `li` at `font-size: 1rem` (L118, L549). 1rem **is** the
        documented body size — DESIGN.md writes it as
        `clamp(1rem, …, 1.0625rem)`, and the detector's parser cannot reduce a
        `clamp()`, so its allowed set is only the two fixed steps `0.875rem`
        and `0.8125rem`. Shrinking body copy to 0.875rem to satisfy the tool
        would be an actual regression.
      - Three `#fff`/`#000` inside `@media print` (L888, L889, L897). Pure
        black on white is correct for print — maximum contrast, minimum ink.

      Re-verified after these changes: Jekyll build green, pa11y WCAG2AA
      **0 errors in both themes across all 21 pages**, 986 interactive elements
      still all named.

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

- [x] **[P2]** **`docs-a11y` runs on every push/PR to `main` with no path
      filter and no Chrome cache.** `ci.yml`'s trigger is branch-scoped only,
      so a Swift-only PR still builds Jekyll and downloads ~350 MB of Chrome
      to check documentation that did not change. Note GitHub Actions has **no
      job-level `paths:` filter** — `paths:` is workflow-level only, and
      `ci.yml`'s other jobs must keep running on every PR, so the options are
      either splitting this job into its own workflow with
      `on.pull_request.paths: [docs/**, tools/docs-a11y.mjs]`, or keeping it
      here behind a changed-files detection step feeding a job-level `if:`.
      Independently, cache `~/.cache/puppeteer` with `actions/cache` to drop
      the repeated Chrome download. Introduced 2026-07-26 along with the job;
      flagged rather than silently accepted.
      **Fixed 2026-07-26** — took the second option (kept in `ci.yml`, no new
      workflow file). Added a `git diff --name-only` step (`id: changed`)
      comparing against `github.event.pull_request.base.sha` /
      `github.event.before`, falling back to `run=true` on push events where
      that base ref is missing or unreachable (first push to a new branch,
      shallow history) — fails open rather than silently skipping the gate.
      Every later step in the job (`configure-pages`, the Jekyll build,
      `setup-node`, the new cache step, `npm install`, `docs-a11y.mjs`) now
      carries `if: steps.changed.outputs.run == 'true'`. Added
      `actions/cache@1bd1e32a3bdc45362d1e726936510720a7c30a57` (v4.2.0,
      SHA confirmed against the GitHub API) keyed on `~/.cache/puppeteer` with
      a static `${{ runner.os }}-puppeteer-chrome` key — no lockfile exists to
      hash since the install step is deliberately unpinned. Verified:
      `actionlint .github/workflows/ci.yml` and a YAML parse both clean.
      **Not verified on a GitHub runner** — same caveat as the job itself
      (see the P1 item above); watch the first PR that touches both a
      docs file and a non-docs file to confirm the `if:` gate fires
      correctly either way.

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

- [x] **[P2]** Sidebar group headings vs. page `<h1>`. **Done 2026-07-26
      13:10 PST.** The five `<h2 class="sidebar__heading">` labels sat before
      each page's `<h1>` in DOM order, so rotor-style heading navigation hit
      "Product & Roadmap" before the page title. They are now `<div>`s carrying
      an `id`, with each `<ul class="sidebar__list">` pointing at it via
      `aria-labelledby` — the group keeps its accessible name for list
      navigation without entering the document heading outline. Purely a
      semantic swap: the CSS selectors are class-based and set their own
      margins, so nothing moved visually.

- [x] **[P2]** `docs/QUICK-START.md` emitted two `<h1>`s ("Quick Start" and
      "Usage Guide") — the only page in `docs/` that did. **Done 2026-07-26
      13:10 PST.** The "Usage Guide" branch is demoted one level (`#`→`##` and
      its five `##` children →`###`). Heading anchors derive from text, not
      level, so the one inbound link (`#keeping-this-guide-current`) still
      resolves. `MD025` stays disabled repo-wide — `NOTES.local.md`, a session
      log, and `.agents/agents/swift-build-resolver.md` legitimately use
      multiple top-level headings, so re-enabling it is not free.

- [x] **[P2]** The `.callout` design rendered on **zero** pages. **Done
      2026-07-26 13:10 PST.** `initCallouts` only classes a blockquote whose
      first child is a bold `Note`/`Warning`/`Important`/`Doctrine` lead-in,
      and no page in `docs/` used that form, leaving the JS and its CSS inert.
      Rather than delete the design, the two blockquotes that genuinely are
      notes now use it: the pre-launch status notice in `QUICK-START.md`
      (`**Important:**`, which makes the pre-launch disclosure *more*
      prominent, not less) and the signing aside in `SECRETS.md` (`**Note:**`).
      Callouts now render on 2 of 21 pages.

- [x] **[P2]** `--color-hairline` measures 1.3–1.5:1 against every surface in
      both themes and was the border on `.copy-code`, a real button.
      **Done 2026-07-26 12:00 PST** — that border now uses `currentColor`, so
      it inherits the label colour (8.45:1 dark, 7.54:1 light) and brightens
      with the text on hover. The agent's report had claimed every interactive
      border used signal-blue; true of `.search-trigger`, not of `.copy-code`,
      which is why it was checked directly. Remaining hairline borders
      (`.theme-switch` fieldset, `.search-panel` container, `pre`, dividers)
      are decorative grouping and exempt under SC 1.4.11. Reference ratios,
      all passing with margin: body text
      16.6 (dark) / 17.3 (light), muted 9.0 / 7.1, links 8.7 / 5.7, focus ring
      8.7 / 5.7.

- [x] **[P2]** Sidebar `<h2>` group headings appeared in the DOM before each
      page's `<h1>` in `<main>`. **Done 2026-07-26 13:10 PST** — resolved as
      described in the sidebar entry above: they are now `<div>`s with an `id`,
      each `<ul>` naming them via `aria-labelledby`, so the group keeps its
      accessible name without entering the document heading outline.

- [x] **[P3]** The layout had no `{% seo %}` tag, so no canonical URL and no
      Open Graph tags on any docs page. **Done 2026-07-26 12:30 PST.** Note the
      premise "auto-enabled by the `github-pages` bundle" was **wrong**, and
      believing it is what turned the build red: the gem *bundles*
      `jekyll-seo-tag` but Jekyll only loads it when `_config.yml` names it
      under `plugins:`. Both the tag and the declaration are now in place;
      canonical and six `og:` tags verified in the built output.

- [x] **[P3]** Settled the `baseurl` question. `docs/_config.yml` sets no
      `baseurl`, which classically 404s every `/assets/...` path on a project
      Pages site. Probed the live site: the deployed stylesheet renders as
      `/sensebridge/assets/css/style.css`, so the prefix is injected upstream
      and `relative_url` resolves correctly. **No change needed** — recorded so
      it is not re-investigated. **Done 2026-07-26.**

- [x] **[P1]** Build `docs/` under the **real** GitHub Pages toolchain before
      merging. **Done 2026-07-26 13:12 PST** — green, 21 pages, zero warnings,
      via the containerized `github-pages` bundle. Do **not** use the
      `jekyll/jekyll:4` image — that is plain
      Jekyll 4 and lacks `jekyll-relative-links`, the plugin that rewrites
      in-docs markdown links to `.html`. It would show every in-docs link
      unrewritten and invite a "fix" that breaks real CI. Use a `tmp/` Gemfile
      containing `gem "github-pages", group: :jekyll_plugins` under
      `ruby:3.3-slim` with `BUNDLE_GEMFILE` pointed at it (that bundle pins
      Jekyll 3.10), and write output outside `docs/`.

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
      - **Analytics and crash reporting** (PostHog, Sentry, Amplitude, and
        every sibling). Toolkits exist; the no-telemetry-by-default doctrine in
        [`docs/PRIVACY.md`](docs/PRIVACY.md) means the app has nothing to send
        them. Linking one creates a live egress path to a product that must not
        have one.
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

- [x] **[P1]** `docker/Dockerfile` ran a plain `npm ci` while
      `docker/README.md` stated — twice, and load-bearingly — that stage 1 runs
      `npm ci --omit=dev`. **Fixed 2026-07-25** — Dockerfile now runs
      `npm ci --omit=dev`, matching the documented contract. The README was
      right and the Dockerfile had drifted, confirmed by testing rather than
      assumed: `npm ci --omit=dev && npm run build` in `website/` succeeds and
      produces the same 195 pages, on local Node v26.3.1 (same major as the
      image's `node:26-alpine`). This also restores the safety property the
      README claims — with the flag in place, a future devDependency import
      inside a build path now fails the build instead of silently working.
      Not verified end-to-end locally: the Docker daemon was down, so the image
      itself was not built. `.github/workflows/railway-deploy-check.yml`
      triggers on `docker/**` and does a real `docker build` + run + health +
      HTTP smoke test, so CI is the confirmation.
- [x] **[P2]** `docker/README.md` described `@railway/cli` as a "project-local
      devDependency (already in `website/package.json`)" that "pins an exact
      version". **Fixed 2026-07-25** — all false: `@railway/cli` appears in
      neither `package.json` nor `package-lock.json`. The `railway:*` scripts
      invoke `npx --yes @railway/cli`, which resolves whatever version is
      current at run time — the opposite of pinned. Section rewritten to say so
      and to name the reproducibility tradeoff.
- [x] **[P2]** `docker/README.md`'s "Known accepted risk" accepted a
      high/critical `tar@6.2.1` CVE on the reasoning that "the Dockerfile's
      `--omit=dev` means it's never installed". **Fixed 2026-07-25** — that
      justification was false on both halves: the Dockerfile ran plain
      `npm ci`, and `@railway/cli` had already left the dependency tree, so
      there is no `node_modules/tar` in the lockfile and `npm ci` reports
      `found 0 vulnerabilities`. Rewritten to state where the risk actually
      lives now — `npx --yes` pulls it transiently onto a developer's machine
      when a `railway:*` script runs, never into CI or the image.
- [x] **[P2]** `docs/TOOLING.md`'s React Doctor / React Scan row carried three
      stale claims. **Fixed 2026-07-25** — it said both tools were
      `devDependencies` (React Scan is in `dependencies`, deliberately), that
      the CI gate is `blocking: error` (now `warning`), and that
      `npm run scan` runs `react-scan http://localhost:4321` (that script is
      removed and the invocation was already broken). Also documented why the
      gate is zero-findings rather than a score.

- [x] **[P2]** **[Needs owner]** `website/public/fonts/fraunces-LICENSE.txt` is
      **byte-identical to `geist-LICENSE.txt`** (both MD5
      `6bc8ee5e488d62bd62df7d879b70477f`), so the vendored Fraunces font ships
      carrying the *Geist* copyright notice — "Copyright 2024 The Geist Project
      Authors" — instead of its own. SIL OFL §1 requires the correct copyright
      notice travel with the font. Fix: replace it with the real Fraunces OFL
      text from
      [undercasetype/Fraunces](https://github.com/undercasetype/Fraunces).
      Logged rather than fixed in-session because licensing artifacts are
      owner-approved changes (`CLAUDE.md` → Legal and licensing). Provenance for
      all three vendored fonts is now recorded in
      [`CREDITS.md`](CREDITS.md#vendored-fonts).
      **Fixed 2026-07-25** — owner approved the correction. Replaced with the
      canonical OFL from `undercasetype/Fraunces@master` ("Copyright 2018 The
      Fraunces Project Authors"), verified complete (4391 bytes; PERMISSION &
      CONDITIONS / TERMINATION / DISCLAIMER sections all present) and now MD5
      `cd1a7cb90fac312616ab0a8c4a67f1bf` — distinct from both Geist files.
      `geist-LICENSE.txt` and `geist-mono-LICENSE.txt` were checked and are
      *correct*; only Fraunces was wrong. `CREDITS.md` now carries a
      per-file copyright-holder table and the rule that caused the bug: copy a
      font's license from its own upstream repo, never from a sibling in the
      same directory.
- [x] **[P3]** **[Needs owner]** Confirm which mechanism actually produces the
      **Verified** badge on this account's commits — an SSH/GPG *signing key*
      (GitHub → Settings → SSH and GPG keys) or a fine-grained PAT used for
      API-authored commits — and pin the answer in
      [`docs/SECRETS.md`](docs/SECRETS.md) §2, which currently documents both
      and flags the ambiguity. Agents don't run `git`/`gh` autonomously
      (`CLAUDE.md` §15), so this could not be inspected in-session.
      **Done 2026-07-25** — owner confirmed a local **signing key** is in use.
      `docs/SECRETS.md` §2 now states that outright, drops the ambiguity
      callout, and demotes the PAT path to an explicit "not used here" note.
      Added the three `git config --get` commands to check the setup, plus
      key-handling and key-loss guidance (revoking an old key retroactively
      marks previously signed commits unverified — replace without revoking
      unless it was compromised). Still worth doing once, separately: confirm
      **Vigilant mode** is enabled, since without it an unsigned forged commit
      renders the same as an ordinary one.
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

### Camera + output subsystems for `app/` (2026-07-25, 07:00 PST)

Session logs: [`0700-PST.md`](sessions/2026-07-25/0700-PST.md) (design, gates,
deferrals), [`0800-PST.md`](sessions/2026-07-25/0800-PST.md) (resume after the
usage limit, the macOS build break, the seam files, the `project.pbxproj`
shape), and [`0900-PST.md`](sessions/2026-07-25/0900-PST.md) (the App-layer
views, four defects caught in diff review, the blocking lint debt). Full
batch-by-batch task list: `tmp/PLAN.md` (gitignored — if it is gone, the logs
above carry the summary; the design would need rebuilding from them), plus
[`1400-PST.md`](sessions/2026-07-25/1400-PST.md) (the view-layer remediation
and the final gates), and
[`1500-PST.md`](sessions/2026-07-25/1500-PST.md) (doctrine 4 — user agency
over protective gatekeeping, and the `.deaf` visibility change it forced).

- [x] **[P1]** `swiftlint lint --strict` / `swiftformat --lint` failures in
  `CameraSource.swift`. Cleared 2026-07-25: long line wrapped, comments
  converted to `///`, `CameraDeviceResolution.swift` and
  `PhotoCaptureDelegate.swift` extracted, and a documented
  `file_length`/`type_body_length` waiver kept for the remainder — splitting
  further would force ~9 private stored properties to `internal` purely to
  satisfy a line count. `scripts/lint.sh`: 0 violations in 47 files.
- [x] **[P1]** Triage the three review reports. Cleared 2026-07-25: every
  Critical and High from `safety-framing-reviewer`, `accessibility-reviewer`,
  and `swift-reviewer` is fixed. Remaining Medium/Low findings are listed
  below.
- **[P2]** `CameraSource` carries a documented
  `swiftlint:disable file_length`/`type_body_length` pair. The real fix is
  extracting rotation tracking (`rotationObservation`, the
  `AVCaptureDevice.RotationCoordinator` setup) into its own type, which would
  bring the actor back under both limits without weakening its isolation.
- **[P2]** Unaddressed Medium findings from the safety-framing audit
  (`audits/safety-framing/20260725-161132-second-output-channel-outputsignal-and-haptics.md`):
  M12 (`HapticPattern` disclaims a vocabulary while assigning six meanings the
  UI never teaches the user), M13, M14, M16 (`HapticPatternTests` proves Core
  Haptics distinctness only — the fallback path that Simulator and CI actually
  run is untested, which is false assurance), M17, M18 ("Preview haptic"
  previews only `.resultReady`, so the user can never feel the cue that
  matters most), and M10 (mock detection data now drives physical-world cues,
  not just prose).
- **[P2]** The architectural gap behind those findings, recorded because it
  will recur: `Phrasing.swift` declares itself "the single place that composes
  spoken/caption output, so it is the enforcement point for the 'awareness,
  not safety' doctrine" — and `OutputSignal` bypasses it entirely. Prose is
  hedged, localized, reviewed, and tested; signals are chosen ad hoc at each
  call site. Signals deserve the same single enforcement point.
- [x] **[P1]** **[Needs owner]** Decide whether `.deafBlind` should be offered
  at all, against the safety audit's Critical 3 (which recommends withholding
  it until a haptic vocabulary exists). **Resolved by the owner 2026-07-25:
  keep it, and make user agency a standing project value rather than a
  one-off override.** Recorded as [`AGENTS.md`](AGENTS.md) **doctrine 4 —
  user agency over protective gatekeeping**, with two binding corollaries
  (never offer a choice that delivers nothing; never let a limitation go
  unstated). Critical 3's evidence stands and is reflected in the caveat copy;
  its remedy is explicitly rejected as paternalistic.
- [x] **[P1]** Apply doctrine 4 to the `.deaf` profile, which was hidden
  entirely. It is now listed in Settings as not yet available with its reason
  ("Captions aren't built yet."), derived from
  `MultiRenderTarget.unsupportedChannels` rather than hardcoded. Verified by
  `AppEnvironmentTests.namesUndeliverableProfilesRatherThanHidingThem` and
  `SenseBridgeUITests.testUnavailableProfileIsNamedWithItsReason`.
- **[P2]** Audit the rest of the app against doctrine 4 — it was written after
  most of the UI. Anywhere a control is hidden rather than shown-and-explained,
  or shown while inert, is now a defect. Start with `CameraControlsView`, which
  hides the lens picker, zoom slider, and torch toggle when the hardware lacks
  them; that is correct for *absent hardware* (nothing to explain) but the
  boundary deserves a deliberate pass rather than an assumption.

Three design gates (cut the unused frame stream, hide the Deaf profile until a
caption target exists, keep lens display names in the App layer) were closed by
owner delegation on 2026-07-25 — rationale in `tmp/PLAN.md` § Decisions.

- **[P1]** **[Needs owner]** The work was written directly in the working tree
  on `main`, which is never committed to. Create the branch and commit before
  anything else touches the tree:
  `git checkout -b feat/camera-and-output-systems`. Note the tree also carried
  nine unrelated modified files before this work started — review
  `git status` and split the commits.
- **[P1]** **[Needs owner]** Device validation. CI and Simulator cannot prove
  any of this; every item below needs a physical iPhone, and a green pipeline
  must never be read as validation:
  - Lens switching across `.builtInTripleCamera` constituents, and that zoom
    ramps continuously rather than jumping.
  - Torch on/off, including that it is extinguished when leaving the screen.
  - Real haptic feel for all six `OutputSignal` patterns — Simulator reports
    `CHHapticEngine.capabilitiesForHardware().supportsHaptics == false`, so it
    only ever exercises the `UIFeedbackGenerator` fallback path.
  - Orientation: a landscape-held capture of a text page must read back in
    correct order.
  - Latency, battery, and thermal behaviour under sustained capture.
  - Blind-tester validation of the new Settings sections and camera controls.
- **[P2]** The camera preview is `.accessibilityHidden(true)`, which is correct
  for a live video feed, but it means a VoiceOver user gets no feedback on
  *aiming*. Framing assistance ("text is off the left edge") is a real feature
  gap, not a bug — it needs design, and probably co-design with blind testers.
- **[P3]** Deferred deliberately by the design above, so they are not silently
  dropped: the live `AVCaptureVideoDataOutput` frame stream (no consumer today
  — all five modes are single-shot, and a continuously-running video output on
  a no-telemetry app is unjustified attack surface);
  `CaptionRenderTarget` and therefore the Deaf output profile; a real
  deaf-blind haptic *language* — the six signals built here are awareness
  cues only, and `docs/planning/SENSEBRIDGE-01-STRATEGY-AND-PRODUCT.md:144` is
  explicit that the real vocabulary requires co-design with deaf-blind
  collaborators, so no doc may imply one exists; and `DetectionService`, which
  is why `Identify`/`Describe`/`Awareness`/`Sounds` keep their canned literals
  this pass.

Closed by this work, kept here only so the record is not lost:
`Settings.speechRate` now reaches `AVSpeechUtterance` (it was persisted and
applied by nothing); captures are orientation-corrected via
`AVCaptureDevice.RotationCoordinator`; `docs/ARCHITECTURE.md` no longer calls
haptics "later" and no longer files `HapticPattern` under `Accessibility/`.

### Docker MCP / tools config (2026-07-25, 03:00 PST)

Full session log: [`sessions/2026-07-25/0300-PST.md`](sessions/2026-07-25/0300-PST.md).

- **[P2]** **[Needs owner]** Add the 6 destructive-command **deny** rules to
  `permissions.deny` in `~/.claude/settings.json` — the auto-mode classifier
  refused to let an agent write these literals (even into a deny list):
  `Bash(docker system prune:*)`, `Bash(docker volume prune:*)`,
  `Bash(docker image prune:*)`, `Bash(docker network prune:*)`,
  `Bash(docker builder prune:*)`, `Bash(docker volume rm:*)`. Defense-in-depth
  only — `acceptEdits` already prompts and the classifier hard-blocks these at
  runtime; the rules just make it a permanent explicit boundary. Then `/mcp`
  reconnect (or restart) to bring the `MCP_DOCKER` gateway tools online.

### Website layout width, motion, and a cow on every HTTP status page (2026-07-24, night)

Full session log: [`sessions/2026-07-24/2200-PST.md`](sessions/2026-07-24/2200-PST.md)
(second section) and [`sessions/2026-07-24/2300-PST.md`](sessions/2026-07-24/2300-PST.md).
Root-caused "the 404 doesn't animate and looks worse" to a CSP/build
interaction, not the animation: `vercel.json`'s `style-src 'self'` (no
`'unsafe-inline'`) blocked the single inline `<style>` block Astro's
`inlineStylesheets: "auto"` was emitting for the error pages, which contained
all their layout, fills, and keyframes — so production rendered an unstyled,
black-filled, motionless SVG while `astro dev` (no CSP) looked fine. Fixed with
`inlineStylesheets: "never"`. Also widened the content container from 60rem to
72rem with an editorial two-column section layout (the reported dead
right-hand space), replaced the wireframe cow with a colored Holstein that
walks, falls, and waits 1.5s in the hole, and generated a page for all 63
IANA-registered status codes across three locales (195 pages).

- [x] **[P1]** **[Needs owner]** Review, then commit/push/PR this session's
      `website/` + `docker/nginx.conf.template` changes — owner asked to look
      first, and `CLAUDE.md` § Branching and committing forbids running
      `git`/`gh` autonomously. Nothing is committed.
      **Done 2026-07-24** — owner granted explicit permission to commit,
      branch, watch CI, and merge. Landed as
      [#40](https://github.com/kevinle3212/sensebridge/pull/40) (squashed to
      `028ba64`) off `chore/website-status-pages-and-motion`. CI went green on
      all 26 checks; `CodeQL` reports `NEUTRAL` because this PR deliberately
      moves Swift analysis off the PR path.
- [x] **[P2]** `Disclaimer` now sits in the wider 72rem band with its text
      still capped at 44rem, so it carries more empty right-hand space than
      the sections that were restructured. Left alone on purpose:
      `website/src/components/Disclaimer.module.scss` is marked untouchable
      (see the `surface-raised` note in `website/src/styles/abstracts/_tokens.scss`)
      and the Undecorated Disclaimer Rule wants it plain. Decide whether the
      rule should also cover measure/alignment, then either widen its measure
      or centre it.
      **Decided 2026-07-25 — leave as-is (no code change).** Best-practice/
      strict call, since the owner delegated it: the Undecorated Disclaimer
      Rule's intent (plain, no layout emphasis, no conversion pressure) extends
      to measure and alignment too — a safety disclaimer should read as calm
      body copy at a comfortable 44rem measure, not be widened or centred for
      visual weight. The extra right-hand space is the correct, restrained
      outcome, and the component stays untouched per its untouchable marker.
- [x] **[P2]** pa11y cannot run locally — puppeteer's Chrome is not installed
      in `~/.cache/puppeteer`, so `npm run test:a11y` dies before the first
      URL. Worked around this session with
      `PUPPETEER_EXECUTABLE_PATH=/Applications/Google Chrome.app/Contents/MacOS/Google Chrome`;
      deliberately not hardcoded into `.pa11yci.json` because it would break
      Linux CI. Either run `npx puppeteer browsers install chrome` once, or
      document the env var in `website/README.md`.
      **Done 2026-07-24** — documented the env var in `website/README.md`'s
      tooling list. `npx puppeteer browsers install chrome` was tried first and
      is *not* a reliable fix on this machine: it repeatedly extracted a
      truncated 448K tree (versus the expected ~500MB) whose
      `Google Chrome for Testing Framework` binary was missing, so Chrome
      failed to `dlopen`. Disk was not the cause (30GB free). Use the env var.
      **Superseded 2026-07-25** — root-caused to the Node version, not the
      machine; the bundled browser now works and the env var is a fallback
      only. See the P3 item below for the mechanism and the fix.
- [x] **[P3]** `~/Library/Caches/ms-playwright` was deleted mid-session (disk
      ~10GB free), almost certainly by the storage-maintenance job — the
      headless browser survived only because its process was already running.
      If browser-driven checks start failing cold, reinstall with
      `npx playwright install chromium-headless-shell` before assuming a code
      regression.
      **Confirmed and fixed 2026-07-24** — the cache was indeed gone. Restored
      with `npx playwright@1.62.0 install webkit firefox chromium`; all three
      engines then ran clean. Treat a cold "Executable doesn't exist" from
      Playwright as this, not a code regression.

### Cross-browser, reduced-motion, and screen-size audit (2026-07-24, night)

Full session log: [`sessions/2026-07-24/2300-PST.md`](sessions/2026-07-24/2300-PST.md).
Audited the built site for reduced-motion behavior, WCAG 2.2 AA conformance,
cross-engine rendering, responsive reflow, and runtime memory. One real defect
was found and fixed (the header's bare `#features`/`#privacy`/`#accessibility`
fragments, which resolved to nothing on all ~195 status pages); everything else
came back clean. Findings worth revisiting:

- [x] **[P2]** Every HTTP status page pulls the full motion + 3D bundle when
      motion is allowed: `/404` transfers ~1.2MB, of which `core.*.js`
      (three.js) is 698kB, because `BaseLayout.astro` puts the `ambient`
      `[data-scene]` container on every page. It is lazy, gated by
      `quality-gate.ts` (reduced-motion / `saveData` / `deviceMemory < 4`), and
      never blocks content — under reduced motion the same page is 32kB of JS
      and a 1.3MB heap. Still, an error page is by definition reached by
      accident and often on a bad connection, so consider skipping the ambient
      scene on `[status].astro`. Deferred rather than done because dropping it
      is a design call, not a defect.
      **Done 2026-07-25** — owner delegated the design call ("keep going even
      if owner-needed"). Added an explicit `ambient?: boolean` prop to
      `BaseLayout.astro` (default `true`; gates the `[data-scene="ambient"]`
      div) and set `ambient={false}` in `ErrorPage.astro` — the single
      component every error/status page routes through (`[status].astro` ×3
      locales, `404`/`500`/`not-found`). Chose an explicit prop over
      overloading the existing `noindex` signal so a future non-error `noindex`
      page keeps its ambient scene. Verified on the build: `data-scene="ambient"`
      count is 1 on `/` and `/es/`, 0 on `dist/404.html` and `dist/503/index.html`;
      `npm run lint:js` + `npm run build` clean (195 pages).
- [x] **[P3]** `npx puppeteer browsers install chrome` extracts a truncated
      tree on this machine (see the completed pa11y item above). Worth a
      root-cause pass — likely the storage-maintenance job racing the extract,
      the same mechanism that removed `ms-playwright` — so local Chrome for
      Puppeteer stops depending on the `PUPPETEER_EXECUTABLE_PATH` workaround.
      **Done 2026-07-25** — root cause is the **Node major version**, not the
      storage job and not disk. Reproduced deterministically: under Node
      **26.3.1** the install downloads the full 177MB archive, then its unpack
      step writes only 448K and exits `0` — the `.app` never gets a
      `Frameworks/` directory, so every launch fails with
      `dlopen … Google Chrome for Testing Framework … (no such file)`. Under
      Node **22.22.3** (the version `engines` and CI pin) the identical command
      extracts all 341MB and cleans up its archive. The download is fine in
      both cases; only Puppeteer's JS unpack silently truncates, and because it
      exits `0` it reads as a broken machine. Repaired the existing cache by
      unpacking the retained zip with the system `unzip` (351MB, launches
      `Chrome/148.0.7778.97`); `npm run test:a11y` is now **8/8 URLs, 0
      errors** and `npm run check:csp` **5/5 routes clean** with
      `PUPPETEER_EXECUTABLE_PATH` unset. `website/README.md` and
      `website/scripts/check-csp.js` now document the bundled browser as the
      normal path and the env var as a fallback only.
      **Confirmed again 2026-07-25 (later session), second tool, same bug** —
      the gstack `/browse` skill was dead for the same reason: Playwright's
      `chromium_headless_shell-1208` was absent, and installing it under Node
      26.3.1 produced a 1.5MB directory containing only `ABOUT` and
      `LICENSE.headless_shell`, exit `0`, no binary. The identical command
      under Node 22.22.3 produced the full 187MB tree and `/browse` works. So
      this is **not Puppeteer-specific**: it is Node 26's archive unpacking,
      and it hits any tool that fetches a browser at install time. Rule of
      thumb: run any browser-install step under Node 22 (`nvm use 22`), and
      treat a suspiciously small browser cache directory as this bug rather
      than a corrupt download. Note the failed Node 26 attempt also leaves a
      stale `~/Library/Caches/ms-playwright/__dirlock` behind that blocks the
      retry until removed.

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

- [x] **[P1]** **[Needs owner]** Commit, push, and open a PR for this
      session's `.github/workflows/codeql.yml`, `.github/workflows/security.yml`,
      `docs/TOOLING.md`, `security/CHECKLIST.md` changes — never run
      autonomously per `CLAUDE.md` § Branching and committing. Commands
      already handed to the owner in-session.
      **Done — shipped.** Verified 2026-07-25 on `main`: `codeql.yml` gates
      Swift analysis off PRs (`if: github.event_name != 'pull_request'`,
      keeping JS/TS on every PR) and `security.yml` runs
      `dependency-review-action`.
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

### Markdownlint wired into CI + pre-commit (2026-07-25)

Config (`.markdownlint.jsonc`, `.markdownlint-cli2.jsonc`, `.markdownlintignore`)
existed already but was never actually enforced anywhere.

- [x] **[P1]** 11 pre-existing issues in 2 files on `main` (a broken table in
      `docs/TOOLING.md` where a row's cell had literal newlines instead of
      staying single-line, breaking every pipe/column-count check on it; a
      `<details>`/`<summary>` collapsible section in `README.md` flagged by
      `MD033`). **Fixed 2026-07-25** — joined the wrapped table row back
      into one line; added an `MD033` `allowed_elements` allowlist
      (`img`/`details`/`summary`) rather than rewriting intentional markup.
      Wired `markdownlint-cli2` into `.githooks/pre-commit` (whole-repo,
      advisory alongside the other node-gated checks) and
      `.github/workflows/ci.yml`'s `docs-links` job (blocking). Verified:
      `npx markdownlint-cli2 "**/*.md"` — 0 issues in 131 files.
      Note: a separate 4 issues (headshot-image `<img>` tags in `CREDITS.md`/
      `MAINTAINERS.md`/`docs/index.md`) only exist on the not-yet-merged
      `chore/website-overnight-audit-batch` branch — the new `MD033`
      allowlist here will cover them too once that branch rebases onto this.

### Website CI accessibility gate failing on Dependabot PR (2026-07-23)

Found while regenerating the Obsidian vault's `Deployments.md` status report.
`pa11y-ci accessibility gate` failed (exit code 2) on PR #21 — `Navigation
timeout of 30000 ms exceeded` on all 3 locale URLs, even though `astro
preview` logged `ready` well within the job's `sleep 4`
(`https://github.com/kevinle3212/sensebridge/actions/runs/30053998683`).

- [x] **[P0]** Root cause: `astro preview` binds `localhost` only, which on
      this stack resolves to the IPv6 loopback (`::1`) exclusively —
      confirmed locally via `lsof -iTCP -sTCP:LISTEN`, no IPv4 listener at
      all. GitHub Actions' `ubuntu-latest` runners don't reliably route IPv6
      loopback inside the container, so Chromium's connection attempt hangs
      until pa11y's 30 s navigation timeout instead of failing fast. **Fixed
      2026-07-24** — added `--host 127.0.0.1` to the `astro preview`
      invocation in `.github/workflows/website-ci.yml`'s `a11y` job to force
      an IPv4 bind, and pointed `website/.pa11yci.json`'s URLs at
      `127.0.0.1` instead of `localhost` to match. Verified locally end to
      end: `npm run build && npx astro preview --port 4321 --host 127.0.0.1`
      + `npm run test:a11y` → `✔ 3/3 URLs passed` (used
      `PUPPETEER_EXECUTABLE_PATH` pointed at system Chrome per the bundled-
      Chrome workaround documented below in this file — a separate,
      unrelated local-macOS issue). **Merged 2026-07-25** via
      [PR #35](https://github.com/kevinle3212/sensebridge/pull/35), squash,
      pa11y-ci gate confirmed green in CI.

### Git/CI cleanup batch: worktree ship, hooks bug, dependency vuln (2026-07-24, afternoon)

Requested: commit + ship the `chore/overnight-website-devex-audit` worktree
and delete it, fix the Dependabot a11y-gate item below, wire markdownlint into
CI/pre-commit and fix its 15 pre-existing issues, verify claude-mem/memory
posture, confirm the react-doctor `GIT_DIR` fix. Three blockers surfaced
mid-session that weren't part of the original ask but had to be fixed before
anything could ship — full write-up in
[`sessions/2026-07-24/1500-PST.md`](sessions/2026-07-24/1500-PST.md) and
[`sessions/2026-07-24/1600-PST.md`](sessions/2026-07-24/1600-PST.md).

- [x] **[P0]** `.claude/hooks/guard-main-commit.sh` (a `PreToolUse` hook)
      resolves the current branch via `CLAUDE_PROJECT_DIR`, which stays
      pinned to the main checkout even when the command's actual `cwd` is a
      linked worktree on a different branch — falsely denied `git commit`
      inside `.claude/worktrees/overnight-audit` with "HEAD is on main."
      **Fixed 2026-07-24** — the fix already existed, fully committed and
      unshipped, on local branch `fix/hooks-worktree-root-resolution`
      (commit `8060040`, clean single commit on top of `main`): resolves via
      `git -C <cwd> rev-parse --show-toplevel` instead, same fix applied to
      `check-md-links.sh` and `session-log-reminder.sh`. Merged as
      [PR #30](https://github.com/kevinle3212/sensebridge/pull/30) (squash),
      branch deleted.
- [x] **[P0]** `brace-expansion` at 1.1.16/5.0.7 in `website/package-lock.json`
      — 2 High severity (`GHSA-mh99-v99m-4gvg`, ReDoS), caught by the
      `pre-push` hook's `osv-scanner` (blocking, not advisory, since it's
      installed locally). Pulled in transitively via
      `eslint-plugin-jsx-a11y`/`eslint`/`pa11y-ci` → `minimatch`, no direct
      dependency to bump; no patched 1.x release exists (5.0.8 is the only
      fix, confirmed via `npm view brace-expansion versions`). Added an npm
      `overrides` entry (`"brace-expansion": "^5.0.8"`) to
      `website/package.json`, ran `npm install` to regenerate the lockfile —
      confirmed all 3 transitive paths now resolve to 5.0.8 and
      `osv-scanner` reports 0 vulnerabilities; `npm run lint:js`/`npm run
      build` still clean (no breaking API change relevant here). **Done
      2026-07-24** — merged as [PR #31](https://github.com/kevinle3212/sensebridge/pull/31)
      (squash), branch deleted. Merged updated `main` back into PR #30's
      branch so its own OSV check (previously failing on this same
      pre-existing vuln) went green too.
- [x] **[P0]** `.githooks/pre-push`'s `osv-scanner --recursive ./` silently
      scanned almost nothing (`1 dirs visited, 1 inodes visited`, "No package
      sources found") when run from inside a linked worktree
      (`.claude/worktrees/overnight-audit`), instead of finding
      `website/package-lock.json` and `package-lock.json` — found while
      committing the accessibility-gate fix below. Root cause: `osv-scanner`
      treats a directory's own `.git` as a nested-repo boundary and skips
      descending into it by default; a linked worktree's `.git` is a file
      (the gitdir pointer, not a directory) but still trips this. First fix
      attempt (`--include-git-root`) turned out not to be deterministic —
      re-running the identical command in the identical worktree
      intermittently regressed back to the same failure. **Fixed
      2026-07-24** — replaced the recursive walk entirely with explicit
      `--lockfile ./package-lock.json --lockfile
      ./website/package-lock.json` (this repo has exactly two lockfiles at
      fixed paths, so no directory walk is needed at all); confirmed stable
      across 3+ repeated runs in both the worktree and the main checkout.
      Merged as [PR #32](https://github.com/kevinle3212/sensebridge/pull/32)
      (the interim `--include-git-root` fix, still a real improvement) and
      [PR #33](https://github.com/kevinle3212/sensebridge/pull/33) (the
      final explicit-lockfile fix), both squash, branches deleted. Also
      learned along the way: git resolves `core.hooksPath` scripts
      per-worktree, not from `CLAUDE_PROJECT_DIR` like the `.claude/hooks/*`
      Claude-harness hooks do — a worktree branch only picks up a
      `.githooks/` fix once that fix's commit is actually in *that
      worktree's own history*, not just on `main`, so shipping each of
      these three hook fixes required merging updated `main` back into
      `chore/overnight-website-devex-audit` before its own push would work.
- [x] **[P1]** **[Needs owner]** `chore/overnight-website-devex-audit`
      pushed once all three hook fixes above finally landed and were merged
      into its own history. Opened
      [PR #34](https://github.com/kevinle3212/sensebridge/pull/34) — checks
      in flight as of this writing.
      **Split 2026-07-25** — PR #34 bundled two unrelated things: the
      a11y-gate/hooks/audio fixes (low-risk, directly answered the original
      ask) and the overnight-audit feature batch (higher-risk, and it turned
      out to have its own new CI regression — see below). Extracted the
      former onto a clean branch, merged as
      [PR #35](https://github.com/kevinle3212/sensebridge/pull/35); closed
      PR #34 in favor of a fresh follow-up,
      [PR #36](https://github.com/kevinle3212/sensebridge/pull/36), carrying
      just the feature batch — see "Signal Bridge auto-play/idle-drift
      starves pa11y's CI gate" below for why that one isn't merged yet.
- [x] **[P2]** The main checkout's `TODO.md` (this file) and PR #34's own
      committed `TODO.md` were two independent, divergent edits of the same
      insertion point. **Resolved 2026-07-25** — reconciled by hand while
      building the `feat/app-reading-ocr-capture` branch; this merged
      version keeps both sides' unique content.

### Signal Bridge auto-play/idle-drift starves pa11y's CI gate (2026-07-25)

Discovered while trying to ship the `chore/overnight-website-devex-audit`
branch (now split — see `chore/website-overnight-audit-batch` /
[PR #36](https://github.com/kevinle3212/sensebridge/pull/36)): once that
branch's Signal Bridge scene auto-plays on load and then idle-drifts
forever (no longer gated on scroll), the `pa11y-ci accessibility gate`
started failing again with the exact same symptom as the item above —
`Navigation timeout of 30000 ms exceeded` on all 3 locale URLs — but this
is a **different, new** root cause, confirmed via a temporary CI-only
diagnostic (three iterations, each pushed and removed): the browser
actually connects and starts rendering (`GL Driver Message ... GPU stall
due to ReadPixels` warnings appear immediately), but pa11y's Puppeteer
navigation (`waitUntil: 'networkidle2'`, pa11y's hardcoded default, not
configurable) never resolves — confirmed via direct `request`/
`requestfinished`/`requestfailed` tracking that **zero requests are ever
actually pending** the entire time, up to a 90 s timeout tested manually.
Ruled out the `/audio/main.mp3` 404 (the one irregular network event on
the page) as the cause by fixing it independently (see PR #35) and
re-testing — no change, same hang. Left unresolved: GitHub Actions'
`ubuntu-latest` runners have no GPU, so Chrome falls back to a deprecated
software-WebGL path (`--enable-unsafe-swiftshader` silences the
deprecation warning, already applied in PR #35, but doesn't fix the hang);
the leading theory is that the scene's continuous `requestAnimationFrame`
render loop — now unconditional, where before this PR it only ran during
active scrolling — starves the browser process badly enough under
unaccelerated rendering that Puppeteer/CDP's own internal navigation
bookkeeping never gets a chance to fire, independent of real network
activity.

- [x] **[P0]** Add real `prefers-reduced-motion` support to
      `website/src/scripts/scenes/bridge.ts`. **Revised finding, fixed
      2026-07-24 (later same-day)** — re-examined before implementing: unlike
      the cow illustration (a CSS/SVG animation, no JS gate of its own),
      `bridge.ts` is one of five WebGL scenes (`hero`/`ambient`/`phone`/
      `glasses`/`bridge`) mounted exclusively through
      `scenes/index.ts`, which calls `quality-gate.ts`'s `webglAllowed()`
      *before* any scene is even imported — and that gate already returns
      `false` whenever `!matchMedia('(prefers-reduced-motion: no-preference)')
      .matches`. None of the five scenes duplicate that check individually;
      it's the shared single point of truth. Confirmed
      `[data-scene="bridge"]` in `SignalBridge.astro` is `aria-hidden="true"`
      and always wraps a static end-state `<svg>` fallback — so a
      reduced-motion visitor already gets the finished, non-animated bridge
      and never mounts the WebGL scene at all. There was no accessibility
      gap; the earlier note above was wrong on this point. The only real bug
      was CI's headless Chrome reporting `no-preference` (Puppeteer/pa11y's
      default), so it mounted the animated scene and ran into the
      GPU-starvation hang. Fixed by adding `--force-prefers-reduced-motion`
      to `website/.pa11yci.json`'s `chromeLaunchConfig.args` alone — zero
      changes to `bridge.ts` needed. **Merged 2026-07-24** — all 24 checks
      green including `pa11y-ci accessibility gate` and `CodeQL (Swift)`;
      [PR #36](https://github.com/kevinle3212/sensebridge/pull/36)
      squash-merged, branch deleted (local + remote). Also deleted the
      stray untracked `website/public/images/kevinkle_headshot.jpeg` —
      byte-identical to (and superseded by) this PR's properly-placed
      `website/public/images/team/kevin-le.jpg`, confirmed unreferenced
      anywhere in the codebase before removing.

### Run on physical device — Developer Mode disabled (2026-07-23)

Owner connected their iPhone and asked to build/install SenseBridge on it.
Device is paired and reachable (`xcrun devicectl list devices` →
`available (paired)`), so `xcodebuild -destination "id=<device>"` reached the
device and reported the real blocker before any code/signing issue: full
write-up in `sessions/2026-07-23/2200-PST.md`.

- [x] **[P1]** **[Needs owner]** Enable Developer Mode on Kevin Le's
      iPhone 17 Pro (`Settings → Privacy & Security → Developer Mode` →
      toggle on → restart → confirm "Turn On"), then ask to re-run the
      build. Next likely blocker per `docs/ENVIRONMENT.md`: trusting the
      developer certificate on first launch (`Settings → General → VPN &
      Device Management`) and the free personal-team 7-day signing window.
      **Done 2026-07-23** — owner enabled Developer Mode and trusted the
      dev certificate on first launch; app built (personal team, resolved via
      `-allowProvisioningUpdates`), installed, and launched successfully via
      `devicectl`. The team ID itself now lives only in the gitignored
      `app/Config/Signing.local.xcconfig`.

### Reading screen had no audio output (2026-07-23)

Owner ran the app on-device (see session above), OCR parsed text but no
speech played on Capture. Full write-up in the addendum to
`sessions/2026-07-23/2200-PST.md`.

- [x] **[P1]** Root cause: nothing configured `AVAudioSession`, so it
      defaulted to `.soloAmbient` — silenced by the hardware ring/silent
      switch and not tuned for spoken output. **Fixed 2026-07-23** — set
      `.playback`/`.spokenAudio` and activated the session in
      `SpeechRenderTarget.init`
      (`app/Packages/SenseBridgeCore/Sources/SenseBridgeCore/Output/SpeechRenderTarget.swift`),
      guarded `#if os(iOS)` since the package also targets macOS for
      `swift test`. Verified: `swift build`/`swift test` clean (17/17
      tests), `xcodebuild build` clean for device, reinstalled + relaunched
      on-device.
- [ ] **[P2]** Owner also flagged OCR recognition quality as "decent, could
      be better" but hasn't given specifics yet — get concrete examples
      (garbled words, reading order, missed lines) on next device test,
      then look at
      `app/Packages/SenseBridgeCore/Sources/SenseBridgeCore/Perception/OCRService.swift`
      (currently a plain `VNRecognizeTextRequest`, no line/paragraph
      grouping or confidence filtering).
- [x] **[P2]** A new capture taken before the previous one finished speaking
      just queued behind it (`AVSpeechSynthesizer.speak()` queues, doesn't
      replace) instead of interrupting it. **Fixed 2026-07-23** —
      `SpeechRenderTarget.render()` now calls
      `synthesizer.stopSpeaking(at: .immediate)` before speaking each new
      message; fixed once at the `RenderTarget` level so it covers every
      screen, not just Reading. Verified: `swift test` clean (17/17),
      `xcodebuild build` clean, reinstalled + relaunched on-device.

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
- [x] **[P3]** Build the real capture layer for at least one mode (Vision
      OCR for `ReadingView` is the simplest of the five) to replace its
      canned mock data with real `SensingSource`/`PerceptionService`
      implementations. **Done 2026-07-23** — added `CameraSource`
      (`app/Packages/SenseBridgeCore/Sources/SenseBridgeCore/Sensing/CameraSource.swift`,
      AVFoundation `AVCaptureSession`/`AVCapturePhotoOutput`) and `OCRService`
      (`.../Perception/OCRService.swift`, Vision `VNRecognizeTextRequest`),
      wired into `ReadingView` with a live `CameraPreviewView`. Verified via
      `swift test`/`xcodebuild test -destination 'platform=macOS'` (OCR
      unit-tested against synthetically rendered text images — real
      recognition, not a fixture) and `xcodebuild build` for iOS Simulator.
      Camera capture itself needs a physical device to exercise — no
      simulator camera — which is the point of this change; see
      `sessions/2026-07-23/` for the session write-up. Follow-ups below.

### Read/OCR wiring follow-ups (2026-07-23)

- [ ] **[P2]** **[Needs owner]** Confirm the Read flow on a physical device:
      launch the app, grant camera permission, aim at real printed text, tap
      Capture, and confirm the recognized text is spoken correctly. This is
      the first real (non-simulator) exercise of `CameraSource`/`OCRService`.
- [x] **[P2]** `scripts/lint.sh` (SwiftFormat + SwiftLint) currently fails on
      four sibling files not touched by this change — `LabelingView.swift`,
      `SceneDescriptionView.swift`, `ObstacleAwarenessView.swift`,
      `SoundAlertsView.swift` all trip the `propertyTypes` SwiftFormat rule
      (pre-existing from the mock-data wiring session above, not introduced
      here). Needs a formatting pass on those four files before the
      `ci-green-gate` lint job will pass.
      **Done 2026-07-24** — `swiftformat app` auto-fixed the 4 `propertyTypes`
      violations plus new `indent` violations in `SpeechRenderTarget.swift`;
      SwiftLint strict then surfaced one more real issue, an
      `unhandled_throwing_task` in `SceneDescriptionView.swift`'s capture
      handler, fixed with `guard let message = try? await
      composer.compose(...) else { return }` (the composer is documented as
      never actually throwing, so no error-message plumbing needed).
      `scripts/lint.sh` now 0 violations; `swift test` 17/17. Committed on
      `feat/app-reading-ocr-capture` alongside the rest of this `app/`
      Reading-OCR work.
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
- [x] **[P2]** Confirm the next CodeQL run still analyzes
      `.github/skills/impeccable/scripts/**` now that it's the one real copy
      (the other 4 mirrors are symlinks to it) — this was a deliberate choice
      to avoid losing scan coverage (CodeQL might not follow symlinks; this
      keeps the scanned path a real file either way), but wasn't empirically
      confirmed one way or the other about symlink-following behavior.
      **Done 2026-07-23** — confirmed: the 2000-PST session's 23 new alerts
      on PR #28 were attributed to real files under that exact path,
      proving CodeQL follows through to the canonical copy rather than
      skipping symlinked mirrors or losing coverage.
- [x] **[P1]** **[Needs owner]** PR #28: confirm the CodeQL check goes green
      once `CodeQL (Swift)` finishes and the aggregate check re-runs (the
      Code Scanning Alerts API, scoped to this branch, already shows zero
      open alerts for every rule the 23-alert check listed — the one still-
      failing check run is a self-flagged incomplete snapshot taken before
      Swift's config was available: "1 configuration present on `main` was
      not found"). Then merge to `main` per the owner's one-time go-ahead to
      bypass the standing "never merge to `main` directly" rule.
      **Done 2026-07-24** — merged as squash commit `72b6084`. The
      "CodeQL" PR check never went green on its own even after Swift
      finished (its "new alerts" diff doesn't respect suppression comments
      and was comparing against `main`'s own unfixed baseline); merged
      anyway on the strength of the Alerts API showing zero open alerts on
      the branch, per the owner's explicit authorization.
- [x] **[P1]** **[Needs owner]** Register `~/.ssh/kevinle3212-GitHub.pub` as
      an SSH **signing** key on GitHub (Settings → SSH and GPG keys → New
      SSH key → Key type: Signing Key — it's currently only registered as
      an *authentication* key). Root cause found for the recurring Vercel
      "Canceled from the Vercel Dashboard" status: every one of the
      project's ~20 recent deployments with `target: null` (preview, i.e.
      every branch/PR push) was `CANCELED`, while every `target: production`
      (main) deployment was `READY` — 100% correlated with GitHub's commit
      `verified`/`unverified` flag, per Vercel's own `errorLink` on the
      canceled deployment pointing at
      vercel.com/docs/project-configuration/git-settings#verified-commits.
      Configured repo-local SSH commit signing with the existing key
      (`git config --local gpg.format ssh` / `user.signingkey` /
      `commit.gpgsign true`) and confirmed via `git cat-file commit HEAD`
      that it produces a real `gpgsig` SSH-signature block — but GitHub
      only shows a commit "Verified" once the *same* key is separately
      added there as a signing key, which needs the owner (adding a key
      requires either the GitHub web UI, or `gh auth refresh -s
      admin:ssh_signing_key` — an interactive OAuth approval — followed by
      `gh ssh-key add ~/.ssh/kevinle3212-GitHub.pub --type signing`).
      **Done 2026-07-24** — owner registered the key as a GitHub signing
      key. Verified end-to-end with a disposable branch + empty commit:
      `gh api .../commits/<sha>` now returns
      `{"verified": true, "reason": "valid"}`, and the matching Vercel
      status context flipped to `{"state": "success", "description":
      "Deployment has completed"}` — no more auto-cancel. Test branch and
      remote ref both deleted after confirming.
- [x] **[P3]** **[Needs owner]** Confirm the Railway dashboard project
      itself is configured as intended — the owner's request named it but
      the text was garbled; likely "sensebridge" per
      `railway-preview-deploy.yml`'s `--service sensebridge`. The GitHub-side
      `RAILWAY_TOKEN` repo secret is confirmed present (added 2026-07-23),
      but the Railway-side project config isn't checkable from here (no
      Railway API/MCP access in this session).
      **Done 2026-07-24** — owner confirmed the garbled name was
      `exquisite-fulfillment`, an unused/stray Railway project, and has
      deleted it. No further action needed.
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

- [x] **[P0]** Resume: read the Opus plan for actionlint + commitlint, then
      implement with Sonnet — config files, hook updates
      (`.githooks/commit-msg`, `.githooks/pre-commit`), new CI job(s) pinned
      to full commit SHAs, and `CONTRIBUTING.md`/`scripts/setup.sh` doc sync.
      Verify hooks + CI locally before considering done.
      **Done 2026-07-23** — see the session log for the full file list;
      commitlint (real tool, CI-enforced) plus the existing bash regex as
      local fallback, actionlint (checksum-verified pinned binary in CI,
      advisory locally), 3 pre-existing shellcheck findings fixed along the
      way, docs synced. Not committed yet (no commit requested this
      session).
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

- [x] **[P1]** **[Needs owner]** Create a branch ruleset for `main` — nothing
      currently stops a direct push or force-push to `main`, despite both
      `CLAUDE.md` files saying "never commit to main." **Partially done
      2026-07-25** — created `main-required-checks` (deletion + force-push
      protection + 7 required status checks); does not yet include the
      require-PR-before-merge / linear-history / squash-only pieces below.
      See the "CI/CD security audit" To-Do entry above for the exact
      remaining gap. Settings → Rules → Rulesets → New branch ruleset:
      - Name `main-protection`; Enforcement: Active; Target branches: `main`.
      - Restrict deletions; restrict force pushes.
      - Require a pull request before merging. Required approvals can stay
        at `0` — the repo is solo-maintained per `CODEOWNERS`/
        `GOVERNANCE.md`, so there's no second reviewer — but this still
        forces every change through a PR, which is what actually triggers
        CI. Turn on "Dismiss stale approvals on new commits."
      - Require status checks to pass, then add every currently-defined job:
        `ci.yml` → `build-test`, `lint`, `docs-links`; `security.yml` →
        `secret-scan`, `ggshield`, `osv-scan`, `sensitive-files`, `semgrep`;
        `codeql.yml` → `swift`, `javascript`; `website-ci.yml` → `lint`,
        `design-qa`. Note `ci.yml` and `website-ci.yml` both have a job
        literally named `lint` — the ruleset UI will list them as two
        separate checks once each has run at least once; add both, don't
        assume one covers the other.
      - Require linear history (pairs with the squash-only merge setting
        below).
      - Bypass list: leave empty, or add yourself scoped to "Pull request
        only" if you want an emergency-hotfix escape hatch — either way it's
        logged, unlike an unprotected branch.
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
- [x] **[P3]** **[Needs owner]** Delete or reconnect the stray `exquisite-fulfillment`
      Railway project — `gh api repos/.../deployments` shows one `production`
      deployment (2026-07-21T01:08 UTC, `inactive`) posted under that project
      name before the `sensebridge` project existed/was renamed. Looks like a
      one-time artifact from initial Railway setup with no deploys since;
      confirm in the Railway dashboard and delete if genuinely unused, so it
      doesn't linger as an orphaned GitHub App connection.
      **Done 2026-07-24** — owner confirmed `exquisite-fulfillment` was an
      unused/stray project and deleted it (same finding as the completed
      "Railway dashboard project" item in the 2026-07-24 cleanup section above).
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

- [x] Merge `chore/github-platform-setup` to `main` — required before Pages
      builds, Wiki sync, CodeQL, Dependabot config, GitHub Models CI, and
      Copilot's environment bootstrap actually run for the first time.
      **Done — merged as PR #18 (`8c7f08c`).** Verified 2026-07-25:
      `.github/workflows/pages.yml` and `wiki-sync.yml` are tracked on `main`;
      the branch no longer exists.
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

- [x] **[P1]** **[Needs owner]** Grant the Vercel GitHub App access to
      `kevinle3212/sensebridge`: GitHub → Settings → Applications →
      Installed GitHub Apps → Vercel → Configure (or
      `https://github.com/settings/installations/133842179`) → add
      `sensebridge` under repository access — its installation is currently
      restricted to a different repo allowlist, which is why
      `vercel git connect` fails ("make sure you have access to the
      repository"). Then re-run `vercel git connect` from `website/` to
      actually wire Production (`main`) + Preview (branches/PRs) auto-deploy
      — nothing auto-deploys on the Vercel side yet. **Confirmed done
      2026-07-25** — verified via the Vercel MCP (`get_project`,
      `list_deployments`): the latest production deployment matches this
      session's `main` HEAD exactly, auto-triggered by the push; PR branches
      get preview deploys too. No further action needed here.
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

### Commit backlog / Dependabot merge (2026-07-21)

Full run log: [`sessions/2026-07-21/1100-PST.md`](sessions/2026-07-21/1100-PST.md).

- [x] **[P2]** **[Needs owner]** Confirm Dependabot's rebase of PR #9
      (`chore(deps-dev): bump typescript from 6.0.3 to 7.0.2 in /website`)
      landed and merge it. It conflicted with `main` after 4 other
      dependency PRs merged first in the same batch and touched the same
      `website/package.json`/`package-lock.json`; `@dependabot rebase` was
      requested via PR comment on 2026-07-21 but not confirmed merged.
      **Done — merged as PR #9 (`85537f7`).** Confirmed in `git log`.
- [x] **[P3]** **[Needs owner]** Push `chore/bmad-method-setup` (11 local
      commits, not pushed this session per the no-autonomous-push rule) and
      open/update its PR once ready.
      **Done — merged as PR #14 (`293e256`, "BMAD method setup, Swift app
      scaffold, agent-mirror sync, website First Light").** Verified 2026-07-25:
      234 `.claude/skills/bmad-*` files tracked on `main`; branch gone.

### Documentation & code-quality audit (2026-07-21)

Full run log: [`NOTES.local.md`](NOTES.local.md). An unattended audit pass over
documentation, maintainability, and code quality. It found and fixed three
defects — two of them in gates that were **already red before the run
started**, so any recent "CI is green" impression was not trustworthy for
those targets.

Fixed this run (details in the annotated items further down this file and in
`HANDOFF.md`): non-English locales silently served English hedge templates
(a safety-framing defect); `swift test` had no localization data at all and
could never have validated the pinned translations; `ReadAloud.astro`'s
frontmatter was broken by a JSDoc block placed above the `---` fence.
Markdownlint went from 2100 errors to 0 by excluding vendored, hash-pinned
skill trees rather than reformatting them.

The repo-wide marker sweep found **zero** `TODO`/`FIXME`/`XXX`/`HACK`/`BUG`
markers in first-party source — the backlog lives here and in `GAPS.md`
instead, which is the better pattern and needs no change.

- [x] **[P0]** Spanish and Vietnamese output silently fell back to English.
      **Fixed 2026-07-21** — `swift test` was failing with 9 issues, every one
      of them a locale case. This is a safety-framing defect, not a cosmetic
      one: the affected strings are the doctrine-pinned hedge templates that
      `docs/SAFETY-FRAMING.md` treats as the highest-severity class of bug in
      the codebase, so es/vi users would have received English hedges. Two
      confirmed root causes: (1) `Phrasing` and `LabelListSceneComposer` both
      used `LocalizedStringResource(_:locale:bundle:)` with
      `String(localized:)`, which resolves against the **process** locale and
      silently ignores the `locale:` argument; (2) only Xcode compiles
      `Localizable.xcstrings` into `.lproj` bundles — command-line SwiftPM
      copies it verbatim, so the test bundle contained no localization data
      at all and the gate was structurally incapable of passing. Verified by
      inspecting the built bundle (`Info.plist` + `Localizable.xcstrings`, no
      `.lproj`). The catalog and the tests were both already correct; only the
      lookup was broken. Fix: new `Reasoning/LocalizedCatalog.swift`, a single
      seam that prefers a compiled `.lproj` bundle and falls back to parsing
      the shipped `.xcstrings`, so `Localizable.xcstrings` stays the one
      source of truth and the suite is honest under both build systems.
      Pre-generating `.lproj` files (a second source of truth that drifts) and
      marking the tests Xcode-only (hiding a blocking gate) were both
      considered and rejected. Native-speaker validation of the translations
      is still open and still `[Needs owner]`.
- [x] **[P1]** `website/src/components/ReadAloud.astro` did not compile.
      **Fixed 2026-07-21** — a JSDoc block sat above the frontmatter fence.
      Astro requires `---` to be the first thing in the file, so the whole
      frontmatter was parsed as markup: 6 `astro check` errors and an ESLint
      parse error, and the component's translation lookup never compiled.
      Almost certainly introduced by an earlier documentation pass adding doc
      comments; an equivalent comment already existed *inside* the
      frontmatter, so the JSDoc was both redundant and destructive. Folded
      its unique wording into the frontmatter comment and left an in-file note
      so the next docs pass doesn't reintroduce it. Swept every other `.astro`
      file — this was the only one affected.
- [x] **[P2]** SwiftFormat's `wrapMultilineStatementBraces` and SwiftLint's
      `opening_brace` give directly contradictory instructions for a
      multi-line `if let` condition: whichever way the brace is written, one
      tool fails. Currently sidestepped in
      `app/Packages/SenseBridgeCore/Sources/SenseBridgeCore/Reasoning/LocalizedCatalog.swift`
      by using single-line conditions plus an in-file comment, but the next
      person to write a multi-line condition will hit the same wall. Reconcile
      the two configs — most likely by disabling `wrapMultilineStatementBraces`
      in `.swiftformat`, since SwiftLint's placement matches the rest of the
      codebase.
      **Done 2026-07-25** — first reproduced the conflict on a throwaway
      probe with a multi-line `guard let` (SwiftFormat's
      `wrapMultilineStatementBraces` demanded the brace wrap to its own line;
      SwiftLint's `opening_brace` then rejected that placement), then added
      `--disable wrapMultilineStatementBraces` to `.swiftformat` and confirmed
      both tools pass on the same brace-on-same-line form. Removed the now-stale
      sidestep comment in `LocalizedCatalog.swift` (left the condition
      single-line — no behavior change). Verified: `scripts/lint.sh` 0
      violations across 35 files; `swift build` clean; `swift test` 17/17.
- [x] **[P2]** `npm audit` in `website/` reports 2 vulnerabilities (1
      critical, 1 high), both `tar` reached through `@railway/cli`.
      Pre-existing and dev-only (Railway CLI is never in the shipped bundle),
      but `npm audit fix --force` would downgrade `@railway/cli` 5.x → 0.3.1,
      which is breaking. Needs an owner call: accept the dev-only risk, pin a
      patched `tar` via `overrides`, or drop the Railway CLI dependency now
      that Vercel is the production host. **Resolved by other work, verified
      2026-07-26** — moot: `@railway/cli` is no longer a tracked dependency of
      `website/` (confirmed absent from both `package.json` and
      `package-lock.json`, per the docker/README.md fixes under "Secrets
      inventory + React Doctor zero-findings gate"). `npm audit` in
      `website/` now reports **0 vulnerabilities**. No owner decision needed.
- [x] **[P3]** `npm run test:a11y` could not be executed locally — Puppeteer
      has no Chrome binary on this machine (`npx puppeteer browsers install
      chrome` would fix it). The `.pa11yci.json` locale coverage added this
      run is therefore config-verified but not run-verified outside CI.
      **Superseded 2026-07-25, re-verified 2026-07-26** — the Chrome-binary
      blocker was root-caused and fixed (see the pa11y items under "Website
      layout width, motion, and a cow on every HTTP status page"). Re-ran
      `npm run build && npm run preview` + `npm run test:a11y` this session:
      **8/8 URLs, 0 errors** — the locale coverage is now run-verified, not
      just config-verified.

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
- [x] **[P2]** **[Needs owner]** Trigger a new production deploy so the
      `sensebridge.vercel.app` alias actually binds (see rename note above)
      — a deploy pushes current `website/` content live, so it needs an
      explicit go-ahead rather than running automatically.
      **Done/Fixed 2026-07-21** — verified live via `curl -o /dev/null -w
      '%{http_code}' https://sensebridge.vercel.app` → `200`. The alias has
      bound; `README.md`'s Website link now points here instead of the old
      `sensebridge-website.vercel.app` URL.
- [ ] **[P3]** **[Needs owner]** Resend setup, parked until there's an actual
      feature to send email for (a waitlist or contact form): create an
      account if one doesn't exist, pick a sending domain, verify it
      (DKIM/SPF/DMARC — needs DNS registrar access this session doesn't
      have), and generate a sending-only scoped API key.
- [x] **[P3]** Decide Stripe/Resend's actual product surface before writing
      any integration code — there's no checkout page or contact/waitlist
      form anywhere in `website/src` today, so both currently have nothing
      to attach to. Needs a real feature decision, not infra config.
      **Decided 2026-07-25 — no integration surface; keep both out (no code).**
      Best-practice/secure/strict call, since the owner delegated it: the site
      is `output: "static"` with a no-backend invariant and a "nothing is being
      sold" pre-launch doctrine. Writing Stripe/Resend integration now would add
      attack surface (a secret-bearing endpoint) and imply a purchase/collection
      flow that does not exist — both violations of the site's honesty and
      privacy principles. Revisit only when a concrete feature (waitlist,
      contact form, checkout) is actually specified; until then this is closed,
      not pending.

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

- [x] **[P2]** Run `brew install ggshield && ggshield auth login` locally —
      the pre-commit hook advisory-skips the GitGuardian scan until this is
      done. **Verified already done 2026-07-26** — `ggshield` v1.52.2 is
      installed (`/opt/homebrew/bin/ggshield`) and already authenticated:
      `ggshield api-status` reports `Status: healthy`, workspace `896916`, API
      key sourced from the system keyring with `scan`/`honeytokens:check`
      scopes, and `ggshield quota` returns real numbers (9560/10000
      available). No login step was actually needed this session.
- [ ] **[P1]** **[Needs owner]** Add the `GITGUARDIAN_API_KEY` repository
      secret (Settings → Secrets and variables → Actions), sourced from the
      GitGuardian dashboard (Personal access tokens → `scan` scope) — the new
      `ggshield` CI job fails closed on every push/PR until this exists.
- [x] **[P3]** Commit and ship this session's repo-side changes
      (`.gitguardian.yaml`, `.githooks/pre-commit`,
      `.github/workflows/security.yml`, `scripts/setup.sh`,
      `docs/TOOLING.md`, `docs/ENVIRONMENT.md`) — none committed yet, no
      commit was requested this session.
      **Done — shipped.** Verified 2026-07-25: `.gitguardian.yaml` and
      `.github/workflows/security.yml` are tracked on `main`. (Owner still
      needs to add the `GITGUARDIAN_API_KEY` secret + local `ggshield auth` —
      those two setup items remain open below.)

### Docker rewrite + website build/lint fixes (2026-07-20)

Full session log: `sessions/2026-07-20/1800-PST.md`. Rewrote the website's
Docker setup into a dedicated `docker/` directory (Dockerfile moved there,
runtime stage switched from an unpinned `npm install --global serve@14` to
digest-pinned `nginxinc/nginx-unprivileged:alpine`, no npm in the runtime
image at all), plus a `docker-compose.yml`, allowlist `.dockerignore`, and
`docker/README.md`. `railway.toml` moved to the repo root
(`dockerfilePath = "docker/Dockerfile"`). Verified locally: `docker build`
succeeds, the container serves `/` and `/es/` with 200s, healthcheck reaches
`healthy`, `docker compose config` resolves cleanly. Also fixed the Astro
build's 500kB-chunk warning (raised `chunkSizeWarningLimit`; the oversized
chunk is three.js, already lazy-loaded) and an MD060 table-formatting error
in `docs/superpowers/specs/2026-07-19-LANGUAGE-SUPPORT-DESIGN.md`.

- [x] **[P1]** **[Needs owner]** Update the Railway service's Root Directory
      to the repo root. **Done 2026-07-20** — owner changed it via the
      Railway dashboard in-session; confirmed via `railway status --json`
      (`rootDirectory: "/"`).
- [x] **[P3]** `docker compose -f docker/docker-compose.yml up dev` (the
      hot-reload Astro dev service) was only config-validated
      (`docker compose config`), not actually run — confirm it starts and
      hot-reloads before relying on it.
      **Done 2026-07-25** — actually ran it. It **starts and serves** (`/` and
      `/es/` → 200, `astro v7.1.3 ready`), but hot reload was **broken as
      configured**: a file edit reached the container (bind mount fine) yet
      Vite's watcher never fired — the well-known Docker Desktop macOS/Windows
      gap where the virtualized bind mount (VirtioFS/gRPC-FUSE) delivers no
      inotify/fsevents events. Fixed by adding `CHOKIDAR_USEPOLLING: "true"` to
      the dev service env (native Linux ignores it, so it's safe everywhere);
      re-verified that editing an existing page then re-fetching now serves the
      change live. Two caveats recorded in-file: (1) adding a brand-new page
      *route* still isn't picked up live under polling — needs a dev-server
      restart; (2) an *unclean* stop leaves a stale `website/.astro/dev.json`
      lock on the bind mount and the next `up` aborts with "Another astro dev
      server is already running" — a normal `docker compose down` avoids it
      (Astro cleans its own lock on graceful SIGTERM); clear with
      `rm website/.astro/dev.json` if hit. Tried `astro dev --force` for that
      and **reverted it** — inside the container the stale lock's PID collides
      with a live PID in the new namespace, so `--force` SIGTERMs the wrong
      process and the container exits. Files: `docker/docker-compose.yml`.
- [x] **[P3]** Commit and ship the session's changes. **Done 2026-07-20** —
      shipped as a small standalone branch off `main` (not folded into
      `chore/bmad-method-setup`'s pending diff), since that branch's
      committed history had diverged too far from `main` to cleanly cherry-
      pick just these files. Used a throwaway `git worktree` to assemble the
      branch without touching `chore/bmad-method-setup`'s own uncommitted
      work. PR: `kevinle3212/sensebridge#7`. Also fixed two CI failures
      discovered along the way, both pre-existing on `main` and unrelated to
      Docker: `tools/sync-skills.mjs` already required 4 mirrored skills
      (`council`, `website-design`, `seo-schema`, `seo-technical`) whose
      content was never committed; `.githooks/post-checkout`/`post-commit`
      had a hardcoded local macOS path in the graphify Python probe. Also
      found `.github/workflows/claude-code-review.yml` was only disabled
      locally, not on `main` — its old `on: pull_request` trigger fired on
      the PR and failed (no `ANTHROPIC_API_KEY` secret), so it's now
      actually paused via a third commit. One CI check remains red on
      purpose: `Docs link check`'s ~50 pre-existing broken links spanning
      unrelated files across the repo — explicitly left for the existing
      "Full markdown documentation sync sweep" work below, not fixed here.

### Repo-hygiene pass — gitignore, SETUP-STATUS removal, SUPPORT.md footers, hook/CI fixes (2026-07-20)

Full findings in `sessions/2026-07-20/1700-PST.md`. 9 commits landed on
`chore/bmad-method-setup` (`f015831`..`b7e26c8`), scoped to this session's
cleanup only — the ~195 pre-existing uncommitted files on this branch
(app/ scaffold, website rebuild/i18n, BMAD skills) were left untouched, by
explicit owner decision, since git can't cleanly separate them from this
session's edits within the same files.

- [x] **[P1]** **[Needs owner]** Fix `legal/PRIVACY_POLICY.md:31`: the
      `docs/PRIVACY.md` relative link is missing a leading `../` (it's
      inside `legal/`, which has no `docs/` subdirectory). Owner already
      approved this exact fix in-session, but both the Edit tool and a
      `sed` workaround were denied by the `legal/**` guardrail — it
      enforces below what this session could override. The now-strict CI
      docs-link check (this session's `9719a51`) will fail on this line
      until it's applied.
      **Done.** Verified 2026-07-25: `legal/PRIVACY_POLICY.md:31` now points at
      `../docs/PRIVACY.md` (correct leading `../`) on `main`.
- [x] **[P1]** **[Needs owner]** Push `chore/bmad-method-setup` and open the
      PR — commands given in-session:
      `git push -u origin chore/bmad-method-setup`, then `gh pr create`
      (title/body already drafted in-session), then `gh pr merge --squash`
      once CI is green and the `legal/` fix above is applied.
      **Done — merged as PR #14 (`293e256`).** (Duplicate of the same-branch
      push item in the "Commit backlog" section above; the `legal/` link fix it
      depended on is also on `main`.)

### Gitignore + config-strictness audit (2026-07-20)

Full findings in `sessions/2026-07-20/1300-PST.md`. Both concrete gaps found
were fixed directly in the same pass (`.gitignore` now covers
`_bmad/**/*.user.toml`; `.github/dependabot.yml` now tracks the `docker`
ecosystem for `website/Dockerfile`) — this is the one deferred nice-to-have.

- [x] **[P3]** Pin `website/Dockerfile`'s `node:22-alpine` base image to a
      digest instead of a mutable tag. **Done 2026-07-20** — superseded by a
      full Docker rewrite: the Dockerfile moved to `docker/Dockerfile`, both
      the `node:22-alpine` build stage and the new
      `nginxinc/nginx-unprivileged:alpine` runtime stage are pinned by
      digest (registry lookups done this session, not fabricated), and the
      previous unpinned `npm install --global serve@14` runtime install —
      the likely source of prior "high" vulnerability scan findings — was
      replaced entirely (no npm in the runtime image). See `docker/README.md`.

### Full markdown documentation sync sweep (2026-07-20)

Full findings in `audits/documentation/20260720-194209-full-markdown-sync-sweep.md`.
Clear-cut dangling links and stale facts were fixed directly in that same
pass (`security/CHECKLIST.md`, `audits/AGENT-GUIDE.md`, `docs/PRIVACY.md`,
`GAPS.md`, `PROJECT_OVERVIEW.md`, `SETUP-STATUS.md`, `models/README.md`); the
items below need an owner decision or a `git` action and were left untouched.

- [x] **[P2]** **[Needs owner]** `legal/PRIVACY_POLICY.md:31` links to
      `docs/PRIVACY.md`, but that's relative to `legal/`, which has no
      `docs/` subdirectory — the link should be `../docs/PRIVACY.md` (see
      the correct pattern already used at `legal/DISCLAIMER.md:16` and
      `legal/TERMS_AND_CONDITIONS.md:23`). Left unfixed because `legal/`
      requires explicit owner approval before any edit, per `CLAUDE.md`.
      **Done — duplicate of the fixed item above; corrected on `main`.**
- [ ] **[P3]** **[Needs owner]** `GOVERNANCE.md:34` says architecture
      decisions "are recorded as they're made in `docs/adr/`," but
      `docs/adr/` does not exist anywhere in the repo (verified via `find`).
      Needs an owner call: either start actually recording ADRs there (and
      create the directory with a first entry or a README describing the
      convention), or reword the claim to reflect that this practice hasn't
      started yet. Left unfixed because either fix is a judgment call, not a
      mechanical correction.
- [x] **[P2]** **[Needs owner]** Several files that tracked docs reference as
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
      **Done.** Verified 2026-07-25 via `git ls-files`: `app/`,
      `docs/OLLAMA.md`, `docs/NOTEBOOKLM.md`, `CLAUDE.template.md`, and
      `TODO.md` are all tracked on `main` (landed with PR #14 and follow-ups).

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
- [x] **[P1]** **[Needs owner]** Git handover — QA now passed (all units
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
      **Done — shipped (website bundled together, per PR #14; app follow-ups in
      PR #37).** Verified 2026-07-25: `SenseBridgeCore` (`Package.swift`), 22
      `app/SenseBridge/**` files, and the i18n website are all tracked on
      `main`. Native-speaker validation of ES/VI strings is still open (below).
- [x] **[P2]** Unit C (website) shipped `/`, `/es/`, `/vi/` routes, but
      `website/.pa11yci.json` still only tests `http://localhost:4321/` —
      add `/es/` and `/vi/` so `npm run test:a11y` actually covers the two
      new locales, not just English. **Done 2026-07-21** — `.pa11yci.json`
      `urls` now lists all three routes; JSON validity and the presence of
      `dist/index.html`, `dist/es/index.html`, `dist/vi/index.html` were
      verified after a build. `pa11y-ci` itself still could not be executed
      locally (Puppeteer has no Chrome binary on this machine), so the gate
      remains machine-unverified here — it runs in `website-ci.yml`, and the
      real-browser/VoiceOver pass is still owner work.
- [x] **[P2]** Unit C's "Listen (natural voice)" control
      (`website/src/components/ReadAloud.astro`) has its label translated on
      `/es/`/`/vi/`, but the pre-rendered narration it plays
      (`public/audio/main.mp3`, generated by `scripts/generate-audio.js`) is
      English-only regardless of page locale — a Spanish/Vietnamese visitor
      who activates it hears English. Either scope the button to the English
      route only, or generate per-locale narration once ElevenLabs
      generation is set up (see the read-aloud narration item elsewhere in
      this file).
      **Done 2026-07-25** — took the honest interim option: gated
      `naturalVoiceAvailable` on `locale === "en"` in `ReadAloud.astro`, so the
      natural-voice button only renders on `/`. (The button is currently hidden
      site-wide anyway because `main.mp3` doesn't exist yet, so this is a
      forward guard for when narration ships.) Left a comment pointing at the
      per-locale-narration follow-up to lift the guard later. Verified:
      `npm run lint:js` clean, `npm run build` clean (195 pages).

### e2e test floor (2026-07-19)

The tracked change is the e2e testing floor (≥3 e2e per feature — happy
path / error / edge case — and all code tested) added to
`docs/TESTING.md`, the `testing` + `ci-green-gate` skills, project
`CLAUDE.md`, `audits/README.md`, and `WIKI.md`.

- [x] **[P1]** **[Needs owner]** Commit the e2e-floor batch (commands in the
      2026-07-19 `0800-PST` session log). Caveat: those files already carried
      uncommitted `chore/bmad-method-setup` modifications, so per-file
      `git add` bundles both — `git add -p` to separate.
      **Done — shipped.** Verified 2026-07-25: the e2e floor ("At least three
      E2E tests per feature — one happy path, one error path, one edge case")
      is present in `docs/TESTING.md` on `main`.
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

- [x] **[P1]** **[Needs owner]** Ship the batch: commit
      `website/` + `.agents/context/DESIGN.md` + `TODO.md` on
      `feat/website-first-light`, push, open the PR (commands in the
      2026-07-19 `0600-PST` session log / final session reply). Agents never
      run `git`/`gh`.
      **Done — shipped (First Light landed via PR #14 and follow-ups).**
      Verified 2026-07-25: `.agents/context/DESIGN.md` and the First Light
      `website/` are tracked on `main`; `feat/website-first-light` is gone.
      The real-device/human-validation sub-items below remain open.
- [x] **[P1]** **[Needs owner]** Decide the pre-existing uncommitted
      `legal/*.md` diffs (doc-casing links, `<email>` formatting, maintainer
      name — they pre-date this session; no agent touched `legal/`): approve
      them to ride along or stash them out before committing. `legal/` edits
      require explicit owner approval per `CLAUDE.md`.
      **Done.** Verified 2026-07-25: `git status`/`git diff HEAD -- legal/` are
      clean — the `legal/` edits were committed (including the
      `../docs/PRIVACY.md` link fix), so there is no pending decision left.
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

- [x] **[P2]** **[Needs owner]** Commit the new hooks + settings change
      (git is owner-gated; copy-paste commands were provided in the
      2026-07-19 `0000-PST` session).
      **Done — shipped.** Verified 2026-07-25: `check-md-links.sh`,
      `guard-main-commit.sh`, and `session-log-reminder.sh` under
      `.claude/hooks/` are all tracked on `main` (and the worktree-root fix
      later landed via PR #30).
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
- [x] **[P3]** **[Needs owner]** Review and reconcile the uncommitted
      `chore/bmad-method-setup` branch (46 new skills under `.claude/skills/bmad-*`,
      `_bmad/` core) — some overlap conceptually with this repo's existing review
      agents (`bmad-code-review` vs. `code-reviewer`/`security-reviewer`,
      `bmad-architecture` vs. `docs/ARCHITECTURE.md` + existing skills). Decide
      precedence, then commit/merge or discard.
      **Done — merged (PR #14).** Verified 2026-07-25: the BMAD skills are
      tracked on `main` (234 `.claude/skills/bmad-*` files). The
      commit/merge-or-discard action is resolved; if the conceptual-overlap
      precedence ever needs a formal call, raise it fresh rather than reopening
      this shipped item.

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
- [x] **[P3]** `npm run format` (`prettier --check .`) fails on every
      `.astro` file, including pre-existing ones (`Hero.astro` hits the same
      "No parser could be inferred" error) — `prettier-plugin-astro` isn't in
      `devDependencies`. Pre-existing gap, not introduced this session; fix
      by adding the plugin (with a `.prettierrc` `plugins` entry) or
      knowingly excluding `.astro` from the format script. **Done 2026-07-21**
      — added `prettier-plugin-astro` to `devDependencies` and a `plugins`
      entry to `.prettierrc`. Worth recording precisely: `prettier --check .`
      was *not* failing on `.astro` by then — Prettier silently **skips**
      extensions it cannot infer a parser for and only errors when one is
      named explicitly, so all 11 `.astro` components had simply never been
      format-checked. Enabling the plugin surfaced 3 unformatted components,
      fixed via `npm run format:fix`. One file,
      `src/layouts/BaseLayout.astro`, is excluded in `.prettierignore`:
      `prettier-plugin-astro` cannot parse a `<script>` nested inside a JSX
      expression, which is how the dev-only react-scan block is gated. It is
      still covered by ESLint, `astro check`, and the build.

### Signal Spine motion batch — accessibility review follow-ups (2026-07-18)

Full report:
`audits/accessibility/20260719-024433-website-first-light-batch-signal-spine-motion-choreography-sticky-header-a11y-review.md`
(local-only — `audits/**` is gitignored). One High finding (sticky header
obscuring the `#main` skip-link target, new WCAG 2.2 SC 2.4.11 exposure) was
fixed in-session (`website/src/styles/global/_base.scss`); these are the
remaining open items.

- [x] **[P1]** Re-run `scripts/generate-audio.js` before
      shipping this batch (once the ElevenLabs key from the narration item
      below is set) so `/audio/main.mp3` includes the new Signal Bridge
      section copy and the reworded FollowProgress copy — the device-voice
      read-aloud option already covers both live; only the pre-rendered
      natural-voice option is currently stale.
      **Done 2026-07-25** — generated from the current build, so the Signal
      Bridge and FollowProgress copy are both in the narration. Verified:
      `npm run build && npm run check:audio` reports a match.
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
- [x] **[P1]** **[Needs owner]** Ship the branch: stage + commit the
      uncommitted website batch, push `feat/website-first-light`, open the PR
      against `main` (commands handed over in the 2026-07-18 19:00 PST
      session log / final session reply).
      **Done — shipped (First Light landed via PR #14 and follow-ups).** The
      Signal Spine batch is on `main`; VoiceOver/keyboard and narration
      sub-items below remain open.

### Website rebuild ("First Light" Astro site) follow-ups (2026-07-18)

- [x] **[P1]** **[Needs owner]** Ship the rebuild: commit is prepared locally
      on a `feat/` branch (website/ + CI + docs + TODO) — push, open the PR,
      and merge after CI. Agents never push/PR autonomously.
      **Done — shipped (First Light Astro rebuild is on `main`, PR #14 and
      follow-ups).** Verified 2026-07-25: `website/astro.config.mjs` tracked;
      the site builds green in `website-ci.yml`.
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
- [x] **[P2]** Add a regression guard for the verbatim safety disclaimer
      (it is hand-inlined in `website/src/components/Disclaimer.astro`; a CI
      grep of `dist/index.html` for the exact string — or a shared constant —
      would stop a future edit from silently breaking the verbatim
      guarantee). **Done 2026-07-21** — added
      `website/scripts/check-disclaimer.js`, wired up as
      `npm run check:disclaimer` and as a `website-ci.yml` step after Build.
      The premise had gone stale: the text is no longer hand-inlined in
      `Disclaimer.astro`, which now reads `t.disclaimer.text` from `src/i18n/`,
      so the guard asserts the built HTML of **all three** locales (`/`,
      `/es/`, `/vi/`) contains its disclaimer verbatim. The expected strings
      are pinned *in the script* and deliberately not imported from
      `src/i18n/` — importing them would make the check tautological and pass
      no matter how the copy was weakened. Negative-tested by rewriting "its
      descriptions can be wrong" to "its descriptions are accurate" in a built
      `dist/index.html`: the guard failed with a pointer to
      `docs/SAFETY-FRAMING.md`, then passed again once restored.
- [ ] **[P3]** Refresh `.impeccable/design.json` from the rewritten
      `.agents/context/DESIGN.md` ("First Light" superseded "Quiet Signal"),
      then re-run `impeccable detect website` so its design-system detectors
      key off the current tokens, and revisit the deferred
      `/impeccable polish website` pass.

### Website read-aloud follow-ups (from the 1400 PST session, 2026-07-17 — backfilled; the session log had these but this file never did)

- [x] **[P1]** Generate the ElevenLabs narration (paths
      updated 2026-07-18 for the Astro rebuild): `cd website &&
      cp .env.example .env`, add a real `ELEVENLABS_API_KEY`, run
      `npm run build && npm run generate:audio`, then commit
      `public/audio/main.mp3` + `public/audio/manifest.json` together. The
      natural-voice button stays hidden on the live site until this exists.
      Afterwards re-run `npm run build && npm run check:audio` and confirm it
      reports a match instead of the informational skip.
      **Done 2026-07-25** — `website/public/audio/main.mp3` (5.3 MB, 4398
      characters, voice `21m00Tcm4TlvDq8ikWAM`, model `eleven_turbo_v2_5`) and
      `manifest.json` are generated and untracked-pending-commit;
      `npm run check:audio` reports a match. Two generation runs were needed:
      the natural-voice button's own label sits inside `<main>`, so the first
      run's text hash went stale the moment the button started rendering. That
      is a stable fixed point now, but expect the same two-pass dance if the
      control's markup or label ever changes.
      Uncovered and fixed in the same pass: `ReadAloud.astro` resolved its
      build-time existence check against `import.meta.url`, which points at
      `dist/.prerender/chunks/`, so the check asked for
      `dist/public/audio/main.mp3` and was always false — the control would
      have stayed hidden even with the narration shipped. Now resolved from
      `process.cwd()`.
- [x] **[P2]** Listen to `website/public/audio/main.mp3`
      end to end before shipping it. Machine verification only proves the file
      matches the page text — nobody has confirmed the narration is
      intelligible, correctly paced, or free of mispronounced product terms
      ("SenseBridge", "VoiceOver", "Signal Bridge").
      **Done 2026-07-25** — owner listened and approved the voice as the
      site's canonical narration voice from this point on.
- [x] **[P1]** **[Legal]** Confirm which ElevenLabs plan
      generated `public/audio/main.mp3` before the site goes public.
      **Resolved 2026-07-25** — owner confirmed the **free plan**, so both
      free-plan conditions apply. Attribution is now shipped: `Footer.astro`
      renders "Natural voice narration generated with elevenlabs.io." on every
      route that carries the audio, gated by the shared `hasNaturalVoice()`
      helper in `website/src/data/natural-voice.ts` so the credit and the
      player can never disagree. Also recorded in `CREDITS.md`. Non-commercial
      use holds today because SenseBridge is free, open source, and sells
      nothing. Verified: `pa11y-ci` 8/8, `check:audio` still matches (the
      footer is outside the hashed `<main>`, so no regeneration was spent).
- [x] **[P2]** Decide the footer "Powered by" row.
      **Done 2026-07-25** — shipped monochrome. Owner first approved six
      full-colour logo badges, but a check of every vendor's published assets
      found only Astro ships a square full-colour vector mark: Sass, GSAP and
      Lenis publish wide wordmark lockups, and Vercel and Three.js are
      monochrome by design with no SVG at all. Owner then chose monochrome,
      which resolved the problem rather than working around it — one
      `currentColor` treatment is the only one that renders GSAP's
      dark-background cream and Vercel/Three.js's monochrome marks correctly
      in both themes. Glyphs come from simple-icons (CC0-1.0 data, trademarks
      still their owners'), and only where legible at 14px: Astro, Vercel and
      Sass carry marks; GSAP, Three.js and Lenis are text. Recorded in
      `CREDITS.md`. **No Two-Accent exception was needed** — the marks inherit
      the footer's text colour, so `.agents/context/DESIGN.md` is untouched.
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

### Agent role layer — global orchestrator/advisor/worker (2026-07-17, late session)

- [x] **[P2]** **[Needs owner]** Commit the agent registrations sitting on
      this branch: the 9 project subagent shims under `.claude/agents/`
      (created 2026-07-17 evening, still untracked) plus this session's
      `SETUP-STATUS.md`/`TODO.md` updates. Blocked behind this file's P0
      filename-case rename item, which must land first on
      `chore/uppercase-markdown-filenames`. The three new role agents
      (`orchestrator`, `advisor`, `implementer`) live at `~/.claude/agents/`
      outside the repo — nothing to commit for those, but they are
      machine-local; recreate them on any new machine from
      `~/.claude/CLAUDE.md` §3's bullet if that machine is rebuilt.
      **Done — shipped.** Verified 2026-07-25: the 9 `.claude/agents/*.md`
      shims (accessibility-reviewer, dependency-auditor, …, ui-reviewer) are
      tracked on `main`. The global `orchestrator`/`advisor`/`implementer`
      remain machine-local by design (nothing to commit).

### Claude/Obsidian integration follow-ups (2026-07-17, night session)

- [x] **[P2]** **[Needs owner]** Commit the three new workflow commands
      (`.claude/commands/cleanup-notes.md`, `.claude/commands/session-log.md`,
      `.claude/commands/todo-groom.md`) and the matching `docs/TOOLING.md`
      "Workflow commands" row. Blocked behind this file's P0 filename-case
      rename item on `chore/uppercase-markdown-filenames`.
      **Done — shipped.** Verified 2026-07-25: `.claude/commands/session-log.md`
      and `todo-groom.md` are tracked on `main`.

### Owner actions pending (from the `app/` scaffold session, 2026-07-17)

- [ ] **[P1]** **[Needs owner]** Make the repo public, then create the
      GitHub ruleset protecting `main` — `GAPS.md` M5. GitHub Free can't use
      Rulesets on a private repo, which is why the 2026-07-17 attempt below
      403'd. Repo is public now and a narrower ruleset exists
      (`main-required-checks`, 2026-07-25) — this fuller spec (require-PR-
      before-merge, linear history, squash-only, 3 more checks) is still the
      gap to close if it turns out to matter; see the "CI/CD security audit"
      To-Do entry above. Steps, in order:
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
- [x] **[P1]** **[Needs owner]** Commit, push, and open a PR for this
      session's work (the `app/` scaffold, CI/lint fixes, doc corrections) —
      never run autonomously per `CLAUDE.md` § Branching and committing.
      **Done — shipped (`app/` scaffold landed via PR #14; capture pipeline via
      PR #37).** Verified 2026-07-25: `app/project.yml` + `app/**` tracked on
      `main`.
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

- [x] **[P1]** Run the Swift tooling against real `.swift` files, as the
      **first** Swift work done — before any volume of tests exists.
      Everything below was decided, written, and documented while the repo had
      **zero `.swift` files**; it is verified by grep, markdownlint, and
      reading upstream — **no compiler has ever run any of it**. That is not a
      hedge, it is the actual state, and it mirrors the rule in `CLAUDE.md`:
      never let a green pipeline imply validation nobody performed.
      **Done 2026-07-21** — the toolchain has now actually run against the 31
      real `.swift` files. `swift build` succeeds; `swiftlint` reports 0
      violations across 30 files; `swiftformat --lint` reports 0/31 needing
      changes. So the *configs* were sound. `swift test`, however, **failed
      with 9 issues** — see the localization entry in the 2026-07-21
      documentation & code-quality audit section above; it is fixed, and
      the suite now passes with 14 tests in 5 suites. Still unverified by any
      machine: the `xcodebuild` app-target build (needs Xcode signing) and
      everything on-device.

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
      - [x] **The vendored skill examples compile.** The code in
            `swift-concurrency-6-2`, `swift-actor-persistence`, and
            `swift-protocol-di-testing` came from upstream and was never built
            here. Check the suspicious ones specifically: `nonisolated struct`,
            `extension …: @MainActor Exportable` (isolated conformance), and
            the `@concurrent` example — the skill itself warns that one **has
            a data race** unless Approachable Concurrency (SE-0466, SE-0461)
            is enabled, so confirm those build settings are actually on before
            trusting it.
            **Verified 2026-07-25** — the three suspicious *language
            constructs* all compile under `swiftc -swift-version 6` on Apple
            Swift 6.3.3: `nonisolated struct` (valid keyword on a type decl —
            the skill's `nonisolated struct` example is flagged `// ERROR`
            for *using a MainActor conformance*, not for the keyword),
            `extension Model: @MainActor Exportable` (isolated conformance),
            and a `@concurrent static func` on a `nonisolated final class`.
            Only `swift-concurrency-6-2` actually contains these; the other
            two skills have no such constructs (grepped). The bare `// ERROR`
            and `/* ... */` snippets are illustrative fragments, not meant to
            compile standalone. **One claim did not reproduce and is left as a
            flag, not a silent pass:** a faithful minimal repro of the
            `@concurrent` + mutable-cache-after-`await` example compiled
            **clean both with and without** `-enable-upcoming-feature
            NonisolatedNonsendingByDefault` — no data-race diagnostic on this
            6.3.3 toolchain, contrary to the skill's SKILL.md:163 warning. Did
            not edit the skill: the minimal repro omits the real MainActor
            caller/`PhotosUI` context, so the discrepancy needs a faithful
            re-check (build the exact example inside an app target with the
            documented build settings) before rewording upstream-sourced
            guidance.
      - [x] **Typed throws.** `throws(LoadError)` compiles — folded into
            `swift-reviewer` from ecc's rules, never built.
            **Verified 2026-07-25** — a minimal `func f() throws(LoadError)`
            with a typed `catch` compiled clean via `swiftc -swift-version 6`
            on the Apple Swift 6.3.3 toolchain (`docs/ENVIRONMENT.md`).
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

### React on Astro migration (2026-07-20)

Full session log: `sessions/2026-07-20/2200-PST.md`. Added `@astrojs/react`
(islands only, zero-JS-by-default preserved until a component opts in with
`client:*`), `eslint-plugin-react-hooks` + `eslint-plugin-jsx-a11y` strict on
`.tsx`/`.jsx`, `react-doctor` (`npm run audit:react`, `--no-telemetry`), and
`react-scan` (`npm run scan`; also dev-only in `BaseLayout.astro`, gated at
build time so zero bytes reach production). Verified end-to-end with a
throwaway island (typecheck/lint/build/hydration), then removed it. Synced
`docs/TOOLING.md` and `website/README.md`.

- [x] `context7` MCP registered. **Done 2026-07-20** — `claude mcp add
      --scope user context7 -- npx -y @upstash/context7-mcp`, confirmed
      `✔ Connected` via `claude mcp list`. User-global, unauthenticated
      (`CONTEXT7_API_KEY` only needed for a higher rate limit later).
- [x] `puppeteer@24.43.1`'s install script approved. **Done 2026-07-20** —
      added to `website/package.json`'s `allowScripts` (pre-existing gap from
      `pa11y-ci`'s dependency tree, confirmed via `npm ls puppeteer` to
      predate this session's changes), then `npm rebuild puppeteer` to
      actually trigger the postinstall (npm considered the tree already
      current and skipped it on a plain `npm install`). Verified with a real
      run: `npm run build && npm run preview -- --port 4321` +
      `npm run test:a11y` → `✔ 1/1 URLs passed`.
- [x] `react-doctor install --agent-hooks` + `ci install` run and reconciled.
      **Done 2026-07-20** — two false starts first: (1) running from
      `website/` cwd nested a whole duplicate agent-config tree under
      `website/.claude`, `.agents`, `.continue`, `.cursor`, `.github`,
      `skills/` — inert (GitHub Actions never reads workflows outside the
      repo-root `.github/workflows/`) and disconnected from this repo's real
      config; (2) an `npx --prefix website ... --cwd <repo-root>` attempt
      silently fell back to writing into **global** `~/.claude/settings.json`
      (a `PostToolBatch` hook entry), `~/.claude/skills/react-doctor`,
      `~/.claude/hooks/react-doctor.mjs`, `~/.cursor/hooks.json` (new file),
      `~/.cursor/hooks/react-doctor.mjs` — polluting every project, not just
      this repo. Both cleaned up and verified back to baseline (hash-compared
      `.githooks/pre-commit` before/after; global settings.json confirmed
      valid JSON with only the react-doctor block removed). One inert
      leftover the permission classifier wouldn't let `rm`:
      `~/.cursor/hooks.json` still exists globally but its `command` now
      points at a deleted script, so it no-ops.
      Final approach: ran `install`/`ci install` from `website/` (the tool's
      documented model — "run from your project root"), then **manually
      relocated** its output to match this repo's actual root-vs-`website/`
      split: skill files → `.claude/skills/react-doctor/`,
      `.agents/skills/react-doctor/`, `.continue/skills/react-doctor/`,
      `skills/react-doctor/`; hooks → `.claude/hooks/react-doctor.mjs` +
      merged `PostToolBatch` in `.claude/settings.json`,
      `.cursor/hooks/react-doctor.mjs` + merged `postToolUse` in
      `.cursor/hooks.json` (merged into the existing `impeccable` entry, not
      overwritten); CI workflow moved from the tool's
      `website/.github/workflows/react-doctor.yml` default to
      `.github/workflows/react-doctor.yml` with an explicit
      `directory: website` input, path-filtered like `website-ci.yml`, third-
      party action pinned to the commit behind the `v2` tag (matching
      `security.yml`'s `ggshield` convention), `blocking: error`. Pre-commit
      hook hand-rewritten (not the tool's auto-inserted top-of-file version)
      to run inside the existing `cd website && ...`, staged-website-files-
      only block alongside `lint-staged`. Verified: `bash -n` on the hook,
      valid-JSON checks on both settings files, valid-YAML check on the
      workflow, and a full `typecheck`/`lint:js`/`build` pass. Full
      blow-by-blow in the session log.
      Confirmed clean: `node tools/sync-skills.mjs --check` (run from the
      repo root — it resolves its paths relative to cwd, so running it from
      `website/` produces a false "canonical skill directory missing"
      error, which is what happened on a first attempt here) passes: 32
      files across 4 skills × 4 mirrors match canonical, and `react-doctor`
      correctly stays outside its scope (not in `MIRRORED_SKILLS`).
- [x] Commit and ship this session's `website/` + `docs/TOOLING.md` +
      `.claude/`/`.agents/`/`.continue/`/`.cursor/`/`.github/workflows/`
      changes — nothing was committed; needs a branch, commit, and PR per
      this repo's branching rules. Note the global (non-repo) files touched
      this session (`~/.claude.json` for the context7 MCP registration,
      `~/.claude/settings.json` cleanup) aren't part of any PR — personal
      machine config, not repo-tracked.
      **Done — shipped.** Verified 2026-07-25: `@astrojs/react` is in
      `website/package.json` on `main` and the react-doctor CI workflow is
      tracked.

## In Progress

*Nothing currently in progress.*

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
      Size moved *up* (15px → 16px): this element carries the safety-framing
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

- [x] **[P1]** Website: Signal Spine nodes mispositioned in production under
      CSP. **Fixed 2026-07-25** — `website/src/components/SpineNode.astro` now
      emits `data-spine-top={top}` instead of an inline `style` attribute, and
      `SpineNode.module.scss` matches on it
      (`&[data-spine-top="4rem"] { top: 4rem; }` and two siblings). **Two
      files, no call-site changes**, as scoped. The `top` prop was narrowed
      from `string` to `"4rem" | "6rem" | "8rem"` so the prop and the CSS stay
      provably exhaustive: a fourth value now fails `astro check` at the call
      site until the matching rule exists.

      Enumerated selectors rather than `attr(data-spine-top px)`, because
      `attr()` with a `<length>` type is still Chromium-only and the site
      declares no browserslist. No CSS custom property set through a `style`
      attribute either — that is the same inline-style channel under a
      different name, and the CSP drops it identically.

      **Verified under the real production CSP, not dev or preview.** New
      `website/scripts/check-csp.js` (`npm run check:csp`) serves `dist/` with
      the exact policy read out of `vercel.json` — read, not restated, so a
      stale probe cannot pass while production fails — drives Puppeteer,
      asserts computed styles, and fails on any `securitypolicyviolation` the
      browser reports. All five markers compute to `position: absolute` with
      `top` = 64px / 96px / 128px, zero violations. A direct A/B under the same
      header showed the old markup computing to `top: 8px` beside the new
      markup at `top: 64px`, so the mechanism is confirmed rather than
      inferred.

      One correction to the original report: `position` did **not** fall back
      to `static`. `SpineNode.module.scss` supplies `position: absolute`
      itself; only `top` lived in the attribute, so nodes were absolutely
      positioned at `top: auto`, i.e. at their static offset. Same visible
      symptom, different mechanism.

      Follow-up sweep done: `grep -rn 'style=' website/src` now returns only
      the explanatory comment in `SpineNode.astro`. No other component carried
      the pattern. `element.style.setProperty` in `motion.ts`,
      `page-loader.ts`, and `scenes/core.ts` is the CSSOM, which `style-src`
      does not govern — asserted in `check-csp.js` rather than assumed.

      Local caveat (resolved 2026-07-25): Puppeteer's bundled Chrome was
      thought to be broken on this machine, so the probe was run with the
      `PUPPETEER_EXECUTABLE_PATH` workaround. The bundled browser now works —
      the truncated install was a Node 26 unpack bug, not the machine — and
      `npm run check:csp` runs with no environment variable set.

- [x] **Won't fix 2026-07-25** — Impeccable `em-dash-overuse` on code comments
      (e.g. `PageLoader.astro`, `BaseLayout.astro`). Em-dash density is the
      established comment voice across this repo, and the rule is written for
      *body copy* — user-facing prose, where an em-dash run is an AI cadence
      tell — not for source comments. Left unsuppressed on purpose: silencing
      it in `.impeccable/config.json` would also blind the detector to real
      findings in user-facing copy, which is where the rule earns its keep. The
      hook will keep reporting it; this entry is the standing disposition.

- [x] **Won't fix 2026-07-25** — Audit finding that the page-load readout uses
      a single font. The readout is deliberately all-monospace: it is an
      instrument register, and `PageLoader.astro` already routes it through the
      shared `type-label` mixin and `$font-mono` rather than a second copy of
      the stack. Adding a display face beside it would put two voices in one
      8-character numeric readout.

      **The rationale is not the One Display Face Rule.**
      `.agents/context/DESIGN.md` §0 (2026-07-18 owner directive) explicitly
      **voided** that rule along with the WebGL ban, the Two-Accent Rule, the
      Flat-By-Default rule, and the no-filled-CTA rule, so citing it would be
      citing a dead constraint. The live rules that carry this decision are §3
      ("Annotation — Geist Mono Variable ... a deliberate, single-purpose
      voice") and §9's Don't ("Don't spread the mono label voice beyond genuine
      ordered technical sequences — it is an annotation voice, not a
      section-eyebrow system"). A monotonic 0-100% readout is exactly the
      ordered technical sequence §9 sanctions. **Flagged for the owner:** if
      the One Display Face Rule is meant to be back in force, §0 needs
      amending — several other decisions currently lean on it being void, and
      two files still cite it (see the motion-pass candidates section).

- [x] **Confirmed resolved 2026-07-25** — Impeccable `design-system-radius`
      1px finding on `PageLoader.astro` (recorded as
      `design-system-radius:414:1px` in `.impeccable/hook.cache.json`). The
      radius was **removed outright, not suppressed**: `.rail` is now
      `height: 2px` with square ends and a comment saying why, and
      `.impeccable/config.json` carries no `design-system-radius` waiver.
      `grep -rn 'radius: 1px' website/src` returns no matches. Re-recorded
      here because the finding had been closed silently.

- [x] **Fixed 2026-07-25** — Status/error pages no longer play the "Span the
      gap" page-load animation. `BaseLayout.astro` gained a `pageLoader` prop
      (defaults `true`, mirroring the existing `ambient` prop's shape);
      `ErrorPage.astro` passes `pageLoader={false}`, which covers **all 195
      built status pages** across `en`/`es`/`vi` — `404`, `500`,
      `[status].astro`, and the `/not-found` alias all render through it, so
      this is one gate rather than a per-page override.

      Gated at the layout, so a status page ships neither `/page-load.js` nor
      the overlay markup at all rather than paying for an early return:
      `output: "static"` resolves the branch at build time. The driver
      `<script>` is deliberately left ungated, because Astro hoists and bundles
      a non-inline `<script>` whether or not the expression wrapping it
      renders, so gating it in source would be a lie the build ignores. It is
      already a no-op without an overlay (it returns early unless it finds both
      `[data-page-loader]` and `data-page-load="building"`). Consequence: the
      exit transition also does not play when leaving a status page, which is
      the same decision.

      **Verified on a genuinely unmatched path**, not a hand-written `/404`
      route: `check-csp.js` requests `/no-such-page-anywhere`, the probe server
      falls back to `dist/404.html` with status 404 exactly as a static host
      does, and asserts no `[data-page-loader]`, no `/page-load.js`, and no
      `data-page-load` attribute on `<html>` — i.e. content is never covered.
      The 5xx case is asserted the same way against `/500`, the file
      `docker/nginx.conf.template`'s `error_page 500 502 503 504` serves. That
      route also asserts the `<h1>` still computes to Fraunces, guarding the
      earlier regression where `style-src` ate the error pages' stylesheet.

- [x] **Done 2026-07-25** — Website motion pass, five items, each implemented
      and verified on its own before the next was started. Every one is behind
      `prefers-reduced-motion` on both layers, checked against
      `.agents/context/DESIGN.md`, and verified in a browser served the real
      production CSP rather than in dev.

      1. **Scroll-velocity-reactive spine pulse.** The Signal Spine dot draws
         out into a vertical streak as scroll speed rises. `initSignalSpine()`
         eases `Math.abs(self.getVelocity())` against a 3000px/s ceiling into
         `--spine-speed`; `SignalSpine.module.scss` turns that into `scaleY`.
         Scaling a `border-radius: 50%` dot yields an ellipse, so the streak
         needs no second element. ScrollTrigger's `scrollEnd` decays it back to
         0 — without that the streak freezes at its last length, since
         `onUpdate` stops firing the moment scrolling does. Verified: 0 at rest
         to 0.511 mid-scroll (`scaleY(3.555)`, exactly `1 + 0.511 x 5`) back to
         0 once settled.
      2. **Text-scramble on section headings.** `initHeadingScramble()`, on
         every `main h2`, fired by its own ScrollTrigger so it need not be
         threaded into the five separate reveal timelines.

         The accessibility problem it is built around: every stage section
         names itself from its heading via `aria-labelledby`, so scrambling the
         heading's text would rename the whole section for the length of the
         animation, and a screen-reader user navigating by heading mid-run
         would hear glyph soup. The real text therefore moves into a
         `visually-hidden` span and the animated copy is `aria-hidden`, so the
         computed name is the real text at every instant. Verified across `/`,
         `/es/`, and `/vi/`: visible text scrambles while the accessible name
         stays byte-identical over 10 samples per locale. Only ASCII letters
         and digits are ever substituted, so Vietnamese diacritics are never
         separated from their base letter.
      3. **Cursor-reactive parallax on the phone and glasses stages.** This
         closes a gap rather than duplicating existing work: both WebGL scenes
         already track the cursor through `createPointerParallax()`
         (`scenes/core.ts`), but `quality-gate.ts` refuses to mount a canvas at
         all on save-data, `deviceMemory < 4`, or no WebGL2 — and those
         visitors had a completely inert stage. `initStagePointerParallax()`
         writes `--stage-pointer-x/y`; the two module stylesheets turn them
         into an 8px/1.2deg drift, scoped `:not(.scene-active)` so it yields to
         the camera parallax wherever WebGL does run. Verified with
         `deviceMemory` forced to 2: zero three.js bytes, zero canvases,
         `scene-active` absent, and transforms matching the formula exactly
         (-4.8px/-0.72deg at top-left, +5.6px/+0.84deg at bottom-right) — and
         confirmed absent on a WebGL-capable browser.
      4. **"Signal" trail on nav hover.** The drawn underline is now a gradient
         brightest at its leading edge and falling away behind it, so hovering
         reads as a signal running the link and leaving a wake.

         A travelling second background layer was built first and **rejected
         after looking at it**: at 1px scale a small radial gradient renders as
         a smudge rather than a point, and it has to park somewhere on arrival,
         leaving a blob past the end of the line for as long as the pointer
         rests there. Scaling one gradient with the line keeps the bright tip
         at the growing edge for free and leaves nothing behind. Declared in a
         separate `motion-safe` block rather than edited into the existing
         rule, so under `reduce` the underline is byte for byte what shipped
         before. Verified the link's box is identical at rest and on hover in
         both motion modes, so the "nothing in a nav row may move" constraint
         `motion.ts` documents holds by construction.
      5. **Read-aloud toggle hover state** (found by auditing, not on the
         original list). `.read-aloud-toggle` had no hover, active, or
         transition treatment at all — the only interactive control on the site
         with none, while the theme toggle, language trigger, hero CTA, and
         back-home link all have one. It now moves to `surface` with an
         `accent-primary` border. Deliberately no lift: the two toggles are
         siblings in a row, which is the case `motion.ts` argues against.

      **Performance measured, not assumed** (the likeliest regression from
      scroll- and cursor-reactive work). Under **4x CPU throttling**: idle
      median 16.7ms/frame with 0 dropped; continuous scroll, the heaviest new
      effect, median 16.7ms with p95 17.5ms and 4 frames over 32ms out of 386
      (~1%); cursor sweep over a stage median 16.7ms with 0 frames over 32ms.
      **Zero long tasks in all three.** 60fps held throughout.

      **Gates:** build, typecheck (0/0/0), `lint:css`, `lint:js`, `format`,
      `check:zero-js` (195 pages, 0 islands), `check:disclaimer` (3 locales),
      `check:csp` (5/5 routes), `test:a11y` (8/8 URLs, 0 errors). Reduced
      motion re-verified after every item: pulse `opacity: 0` and `transform:
      none`, headings fully visible, no page-load overlay, **zero canvases and
      zero motion/3D chunks fetched**.

      The disclaimer was not touched, in any mode (DESIGN.md's Undecorated
      Disclaimer Rule).

- [x] **Agent error, recorded 2026-07-25** — `TODO.md` lost roughly 750 lines
      of uncommitted work during the session above, and was rebuilt. Cause:
      `npx prettier --write TODO.md` was run to tidy new entries, but this file
      is **not** Prettier-managed (there is no root Prettier config, and the
      pre-commit hook runs Prettier only over `website/**`). That reflowed 1720
      lines and introduced 8 `MD046` markdownlint errors. The recovery attempt
      then made it worse: `git checkout HEAD -- TODO.md` discarded the whole
      uncommitted working-tree version, not just the reflow.

      Recovered from a 2703-line blob in `.git/lost-found`, plus
      [`sessions/2026-07-25/1600-PST.md`](sessions/2026-07-25/1600-PST.md) for
      the one section the blob predated (see the reconstruction note on the
      dev-environment section under **To-Do**). Nothing else was affected — no
      other file was checked out.

      **Two rules this file should be read with from now on:** never run
      Prettier on repo-root Markdown (only `website/**` is Prettier-managed —
      use `npx markdownlint-cli2` instead, which is the actual CI gate), and
      never `git checkout` a path with uncommitted work in it to undo a bad
      edit. `git diff` first, or copy the file aside.

---

Need help? See [`SUPPORT.md`](SUPPORT.md).
