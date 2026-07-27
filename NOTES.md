# Notes

Shared, committed project notes — the public half of a deliberate two-file
split:

| File | Visibility | Contents |
| --- | --- | --- |
| **`NOTES.md`** (this file) | **Public** — committed, linted, secret-scanned | A curated digest: durable, contributor-facing findings, each pointing at the canonical doc |
| **`NOTES.local.md`** | **Private** — gitignored, never committed | The user's own personal setup and machine-specific notes (not written by `/handoff` — see `tmp/handoff.md` below) |

Anything committed here is public the moment the repo is pushed, and stays in
git history even if deleted later. When in doubt, put it in `NOTES.local.md` —
moving a note from private to public is easy, the reverse is not.

## What belongs here

A **digest, not a duplicate**. Each entry is a few lines that say what was
learned and link to the doc that owns the detail. If a finding has a
purpose-built home, it goes there and gets a pointer here — never a second copy:
[`docs/`](docs) for anything durable and structured, [`GAPS.md`](GAPS.md) for
tracked defects, debt, and risks, [`TODO.md`](TODO.md) for the short
come-back-to-it list, [`audits/`](audits) for filed findings.

Write an entry when a session produces something a *future contributor* would
want and would otherwise rediscover the hard way. Most sessions produce nothing
that qualifies; that is fine and expected.

## What must not

- Secrets, credentials, tokens, or signing material — see
  [`docs/ENVIRONMENT.md`](docs/ENVIRONMENT.md).
- Absolute machine paths (`/Users/<name>/…`), local hostnames, or ports.
- Session mechanics: what stalled, tool/account state, half-formed reasoning.
  That is what `NOTES.local.md` is for.

The first two are enforced, not merely requested:
[`tools/check-sensitive-files.mjs`](tools/check-sensitive-files.mjs) runs on
every commit via [`.githooks/pre-commit`](.githooks/pre-commit) and blocks
staged files containing credential material or hardcoded home-directory paths.
It scans staged and tracked files only, so it never sees — and never protects —
`NOTES.local.md`. That file's safety comes from being gitignored.

## Private notes (`NOTES.local.md`)

Gitignored via [`.gitignore`](.gitignore), excluded from markdownlint via
[`.markdownlintignore`](.markdownlintignore), and never committed. It holds the
user's own personal setup and machine-specific configuration — **not** written
to by [`/handoff`](.claude/commands/handoff.md), which writes only to
`tmp/handoff.md` (also gitignored, auto-loads on the next `/clear`).

Full handoffs go there, never here: they routinely carry absolute job paths and
machine state. This file gets only the curated digest distilled from them.

---

## Digest

### 2026-07-16 — Impeccable: one root, one context

- **The five `impeccable` skill copies are not duplicates.**
  `.agents|.claude|.cursor|.gemini|.github/skills/impeccable/` are a
  multi-provider build produced by `npx impeccable install` — the content is
  *supposed* to differ per target (invocation prefix, script paths, model name,
  `AGENTS.md` vs `CLAUDE.md`, Codex-only sections). A pairwise diff of all 102
  shared files found zero accidental drift. **Never hand-edit one copy**; use
  `npx impeccable check` / `update`. An earlier audit spot-checked two files and
  mistook the build for drift — don't repeat that. See
  [`docs/TOOLING.md`](docs/TOOLING.md) → "Impeccable design-QA".
- **Impeccable roots its state at the current working directory.** With no
  monorepo marker (this repo has none), its project root is just the cwd, so
  running it from a subdirectory silently creates a stray `.impeccable/`. The
  repo root is the only supported root — the editor hook hard-keys there via the
  `.git` marker. CI must run it from the root and pass `website` as a target.
  See [`docs/TOOLING.md`](docs/TOOLING.md) → "Impeccable project root".
- **The site's design context lives in `.agents/context/`, not `website/`.**
  Impeccable resolves context as project root → `.agents/context/` → `docs/`,
  so context left in `website/` was never found: it silently loaded
  [`docs/PRODUCT.md`](docs/PRODUCT.md) (the *app's* strategy doc) with no
  `DESIGN.md` at all, leaving the detector's design-system rules inert. Two
  files are named `PRODUCT.md` on purpose, with different scopes. Do not "tidy"
  the context back next to the site it describes. See
  [`docs/TOOLING.md`](docs/TOOLING.md) → "Impeccable design context".

### 2026-07-26 — Building the docs site locally needs the `github-pages` gem

- **Do not verify `docs/` with the `jekyll/jekyll` Docker image.** That is
  plain Jekyll, and it does *not* carry `jekyll-relative-links` — the plugin
  that rewrites in-docs markdown links to their built `.html` paths. GitHub
  Pages runs the `github-pages` gem bundle, which enables that plugin
  automatically and pins Jekyll to 3.10. Building in the wrong image shows
  every in-docs link unrewritten, which looks like a bug in the docs and
  invites a "fix" that breaks the real build. Use a Gemfile containing
  `gem "github-pages", group: :jekyll_plugins` under a Ruby image instead —
  and install `build-essential` first, or the native extensions for `nokogiri`
  and `eventmachine` fail to compile. Two further consequences of the 3.10 pin:
  Jekyll-4-only Liquid (such as `where_exp` with certain expressions) raises a
  syntax error, and `jekyll-last-modified-at` is not on the Pages plugin
  allowlist. See [`docs/CI-CD.md`](docs/CI-CD.md).

### 2026-07-26 — A green build says the site compiled, not that it works

- **`docs/assets/js/docs.js` shipped completely unparseable and nothing caught
  it.** A block comment began
  `/* Callouts — blockquotes starting with **Note**/**Warning**/...`, where the
  `**` immediately before `/` forms a `*/` that closes the comment early; the
  rest of the line became code and the whole file failed to parse. Every
  interactive feature on all 21 pages was dead — theme switch, search, table of
  contents, copy buttons, heading anchors, reading progress. The file ships
  unbundled and unminified, so no build step ever parses it and Jekyll copies
  it as a static asset; a green Jekyll build and a passing byte budget both
  say nothing about it. `ci.yml`'s `docs-links` job now runs
  `node --check docs/assets/js/docs.js`. **Beware `**bold**/` in any block
  comment** — the markdown habit of bolding words produces `*/` by accident.
- **Loading one built page in a browser is worth more than every static check
  combined.** Build exit codes, byte counts, and greps had all passed. Opening
  a page in Puppeteer and reading the `pageerror` event found a total feature
  outage in seconds. Do that before calling a static site verified.
- **A bundled Jekyll plugin stays inert until it is named in `plugins:`.** The
  `github-pages` gem *ships* `jekyll-seo-tag`, but the layout's `{% seo %}`
  still failed with `Liquid syntax error: Unknown tag 'seo'` until
  `docs/_config.yml` declared it. See [`docs/CI-CD.md`](docs/CI-CD.md) →
  "Docs publishing".

---

Need help? See [`SUPPORT.md`](SUPPORT.md).
