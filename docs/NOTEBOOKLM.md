# NotebookLM — manual setup for project work

There is no automated NotebookLM integration **in this repo's workflow**.
`docs/TOOLING.md`'s tool evaluation assessed the automation path —
`PleasePrompto/notebooklm-skill` — and found it bootstraps a stealth,
anti-bot-evading Chrome instance with `--no-sandbox` and persists your Google
session cookies to disk: a credential-bearing network round-trip, the
sharpest violation of this project's on-device-by-default doctrine
(`docs/PRIVACY.md`) in the current tooling landscape.

**Status update 2026-07-17:** on the owner's explicit override, that skill is
now installed **globally** (`~/.claude/skills/notebooklm/`, files-only — its
pip/Chrome bootstrap runs on the owner's first use) for personal use outside
this project; see `docs/TOOLING.md` → "Global skills — installed 2026-07-17"
(second wave). The project rule is unchanged: SenseBridge work uses the
manual, five-minute browser workflow below — no scraping, no stored
credentials, and the skill is never invoked from a SenseBridge session.

## Setup (manual, ~5 minutes)

1. Go to [notebooklm.google.com](https://notebooklm.google.com) and create a
   notebook named "SenseBridge".
2. Add sources — NotebookLM accepts pasted URLs, uploaded files, and pasted
   text. Use the repo docs below as sources; re-add after major doc changes
   (NotebookLM does not watch a live repo).
3. Ask NotebookLM questions grounded in exactly those sources, or generate its
   study guide / audio overview features from them.

## Recommended sources, by topic

Add this repo's own docs first — they carry the SenseBridge-specific
constraints (safety-framing, on-device doctrine, accessibility gate) that
generic framework docs won't know about:

- `docs/ARCHITECTURE.md`, `docs/PRODUCT.md`, `docs/TESTING.md`,
  `docs/TOOLING.md`, `docs/ENVIRONMENT.md`, `docs/ACCESSIBILITY.md`,
  `docs/SAFETY-FRAMING.md`, `docs/PRIVACY.md`, `AGENTS.md`, `CLAUDE.md`

Then add official docs for whichever part of the stack you're ramping up on —
most of this list describes the **planned** Next.js/React migration, not the
current state (`website/` is still static HTML/CSS; see
`docs/TOOLING.md`'s "Marketing website" row):

| Topic | Source |
| --- | --- |
| Next.js | <https://nextjs.org/docs> |
| React | <https://react.dev/learn> |
| TypeScript | <https://www.typescriptlang.org/docs/handbook/intro.html> |
| typescript-eslint | <https://typescript-eslint.io/getting-started> |
| Tailwind CSS | <https://tailwindcss.com/docs> |
| Sass | <https://sass-lang.com/documentation/> |
| PostCSS | <https://github.com/postcss/postcss#readme> |
| Jest | <https://jestjs.io/docs/getting-started> |
| Lighthouse | <https://developer.chrome.com/docs/lighthouse/overview> |
| Fastlane | <https://docs.fastlane.tools/> |
| React Scan | <https://github.com/aidenybai/react-scan#readme> |
| React Doctor | <https://github.com/mohammadV1srn/react-doctor#readme> |
| Knip | <https://knip.dev/> |
| Stylelint | <https://stylelint.io/user-guide/> |
| EditorConfig | <https://editorconfig.org/> |
| YAML | <https://yaml.org/spec/1.2.2/> |
| Vercel | <https://vercel.com/docs> |
| SEO | <https://developers.google.com/search/docs> |
| Security (OWASP Top 10) | <https://owasp.org/www-project-top-ten/> |

## Why this isn't wired into Claude, Continue, or any agent

NotebookLM has no public API — nothing here (or anywhere) could programmatically
push sources into it without either screen-scraping the web UI (the rejected
path above) or a human doing it by hand. Claude, Continue, and this repo's own
skills already have direct, local access to every doc listed above — reach for
`docs/TOOLING.md`, the `.agents/skills/` skills, or the `documentation` skill
for AI-agent-facing teaching. NotebookLM is a *human* study aid layered on top,
not an agent context source.

---

Need help? See [`SUPPORT.md`](../SUPPORT.md).
