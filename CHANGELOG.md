# Changelog

All notable changes to SenseBridge are documented here.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

- **Sentence-level playback on the Read screen.** Recognized text is split
  into sentences and read one at a time, with previous/play/pause/next,
  "read from the beginning", and a "where am I?" control that says the current
  position on demand. Each utterance is awaited before the next begins, so
  every control lands between sentences rather than cutting one off mid-word.
- **Multi-page documents.** Capture adds pages to one document, "Read it all"
  plays the whole thing, and "Discard" throws it away without saving. Pages
  that recognized nothing are kept in the page count rather than silently
  renumbering the ones after them.
- **A scrollable, selectable transcript with a copy button**, for the people
  speech does not reach — a low-vision user magnifying the text, a braille
  display, or anyone who would rather copy a phone number than hear it twice.
- **Live continuous reading.** No capture tap: the Read screen recognizes the
  live feed, speaks aiming guidance as the user moves ("text runs past the
  top", "the text looks small"), and reads a page aloud once its recognized
  text stops changing. Guidance is written about recognition, never about the
  page — the app never claims a page is blank.
- **Perspective correction before recognition.** A page photographed at an
  angle is flattened first; anything that is not plausibly a page is passed
  through untouched, so a pill bottle or a ticket is never cropped to
  something else.
- **An automatic torch in genuinely dark frames.** Brightness is measured from
  the frame itself rather than inferred from recognition failing, needs three
  consecutive dark frames, and is announced when it switches on — a torch is a
  change to the world around the user, including for anyone facing them.
- **Reading history, opt-in and off by default.** Recently read documents can
  be re-heard without re-photographing them. Stored in a file with complete
  data protection, excluded from backup, capped at 25 documents, and deleted
  outright when the setting is switched off. The screen states all of that
  where the user is deciding, not only in the privacy policy.
- **Direction in awareness alerts.** The depth region is split into left,
  centre, and right, and an alert names a side only when one zone is clearly
  nearer than the others — a single measurable zone never names a side, and a
  wall across the frame names none either. The alert threshold itself is
  unchanged: the overall distance is computed from exactly the same pixels as
  before.
- **A proximity-driven haptic pulse**, so the channel that carries no prose can
  still carry urgency. The existing awareness cue repeats faster the nearer the
  measurement, in four coarse bands; the furthest band does not repeat at all.
  No new pattern to learn, and it can be switched off.
- **On-screen awareness controls**: an alert-distance slider and the pulse
  toggle live on the Awareness screen itself, alongside a live per-zone
  reading, the thermal-backoff state, and the battery level — the tunables are
  where the walking happens rather than two screens away.
- **An end-of-session summary** when hands-free awareness stops: alerts raised
  and time run. Facts about what the app did, never about what was out there.
- A description-detail preference (Settings → Descriptions: Brief/Standard/
  Detailed) controlling how many things a spoken description names and how
  much wording it uses — never how certain it sounds. Applies to the
  on-device, Local, and Cloud reasoning backends alike.
- Spanish and Vietnamese names for the objects and sounds the app is most
  likely to recognize. An identifier without a reviewed translation still
  reads as its English noun inside the translated hedge, so an unlisted
  object is named in the wrong language rather than named wrongly.
- Thermal backoff for hands-free awareness: on a warm device the sampling and
  narration cadences stretch, and every change — including the return to
  normal — is announced, because a cadence that quietly degrades is
  indistinguishable from the app having stopped.
- Hands-free awareness now restarts itself when SenseBridge comes back on
  screen, announcing both the stop and the restart. The camera still never
  runs while the app is backgrounded.
- An "Open Settings" button on the Read, Identify, Describe, and Sounds
  screens, shown only after camera or microphone access has actually been
  denied — the previous message named Settings without offering a way there.
- An app icon. The icon set was empty before this.
- `admin/`: a single-owner Next.js dashboard for WakaTime, Sentry, and local
  dev-tooling telemetry. Not part of the product and not deployed with the
  site; see [`admin/README.md`](admin/README.md).

### Changed

- `legal/PRIVACY_POLICY.md` and `legal/SUBPROCESSORS.md` updated to disclose
  the optional, off-by-default Local and Cloud (Anthropic/OpenAI/NVIDIA NIM,
  bring-your-own-key) reasoning backends — only recognized object labels can
  leave the device, and only after explicit opt-in.
- Distance units are now spoken as full words ("feet", "inches") instead of
  abbreviations ("ft", "in"), which a speech synthesizer could misread as
  unrelated words.
- The no-Apple-Intelligence fallback composer now groups descriptions by
  certainty ("it looks like there's a chair and a table.") instead of
  repeating one full hedged sentence per object.
- The Xcode project file is now the single source of truth for build settings.
  The XcodeGen spec (`app/project.yml`) is removed: nothing in the build ever
  invoked `xcodegen`, so it was a second, unverified copy of the truth that had
  already silently dropped a background mode once. The reasoning behind each
  non-obvious build setting is recorded in
  [`docs/ENVIRONMENT.md`](docs/ENVIRONMENT.md).
- The website ships a full icon set (`favicon.ico`, `apple-touch-icon`,
  `icon-192`/`icon-512`, and a web manifest) rather than an SVG favicon alone,
  and the brand masters now live in tracked `assets/brand/`.

- "Check once" now reports what it measured when the nearest reading sits past
  the alert distance ("the nearest distance I could measure is about 4
  meters"), instead of answering a successful measurement with "Nothing
  recognizable was found."
- The per-zone reading on the Awareness screen carries a legend stating that
  zones are thirds of the camera's view, measured from where the camera points
  rather than from the user's body, and that spoken alerts name a side only
  when one zone is clearly nearer.

### Fixed

- A reading could be composed from the previous session's last frame.
  `ARSession.currentFrame` outlives a stop/start pair, so a check taken in one
  room — or hands-free awareness resuming after the app came back to the
  foreground — could narrate the scene the user had already walked away from.
  Frames captured before the current run are now refused outright.
- "Check once" gave up at ARKit's first frame, which carries no depth map —
  `sceneDepth` is populated several frames after the camera opens — so a tap
  could answer "couldn't take a measurement" a fraction of a second before the
  measurement it asked for was available. It now waits for a frame that
  actually carries depth, within the same three-second ceiling.
- Launching under `-uiTestReset` reset settings but left the reading-history
  file in place, so a "clean" UI-test launch inherited the previous run's
  recognized text.
- `AlphaScaffoldingUITests.testSettingsAwarenessSectionPassesAccessibilityAudit`
  had been failing with `Audit failed to complete in time`, asserting nothing.
  The audit now requests only the categories it acts on, and a screen that must
  be scrolled is audited twice — fully at rest, then for the labelling
  categories once scrolled, where contrast measurement is both unaffordable and
  meaningless for rows that are no longer in view.
- OCR read multi-column text out of order and could speak a low-confidence
  guess. Lines are now grouped into visual rows before ordering, and anything
  below a confidence floor is dropped rather than read aloud — the honest
  failure is "no text was found", not a plausible invention.
- Captions rendered hedged sentences starting in lowercase. The templates stay
  lowercase for speech; the screen capitalizes at the display boundary.
- Identify, Describe, and Sound Alerts composed their spoken output in the
  device's locale rather than the language chosen in Settings, so choosing
  Español or Tiếng Việt left those three screens speaking English.
- The read-aloud toggles on the website showed no visible pressed state — the
  change was carried only by the label text and `aria-pressed`.
- The website ignored `prefers-reduced-transparency` and `prefers-contrast`.
- Read-aloud spoke the whole page as one utterance; it now reads section by
  section and announces each heading as it starts.
- The site build emitted a 187kB React DOM client runtime that no page
  referenced, because installing the React integration adds it whether or not
  anything hydrates.
- `tools/archive-completed-todo.mjs` could emit duplicate `###` headings when
  it swept twice in one day, failing the `docs-links` CI job's markdownlint
  gate.

## [0.1.0] - 2026-07-09

### Added

- Initial repository scaffold and AI development environment: governance,
  documentation, security policy, GitHub automation, and AI-agent tooling.
  No app code yet — see [`docs/ROADMAP.md`](docs/ROADMAP.md).

[Unreleased]: https://github.com/kevinle3212/sensebridge/compare/v0.1.0...HEAD
[0.1.0]: https://github.com/kevinle3212/sensebridge/releases/tag/v0.1.0

---

Need help? See [`SUPPORT.md`](SUPPORT.md).
