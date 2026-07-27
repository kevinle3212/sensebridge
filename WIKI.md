# WIKI.md — Documentation Index

Every doc, one line each. Start at `PROJECT_OVERVIEW.md` if you're new.

## Orientation (root)

| File | Purpose |
| --- | --- |
| `PROJECT_OVERVIEW.md` | What exists and where to look |
| `AGENTS.md` | Canonical conventions for humans and agents |
| `AGENT-CONTEXT.md` | Current state of the ground for agents |
| `CLAUDE.md` / `GEMINI.md` / `.github/copilot-instructions.md` | Per-agent pointers into `AGENTS.md` |
| `.codex/` `.gemini/` `.copilot/` `.continue/` `.windsurf/` `.cursor/` `.openclaw/` | Per-agent config (Serena MCP + rules), all deferring to `AGENTS.md` |
| `GAPS.md` | Verified defects, debt, risks, next milestones |
| `MEMORY.md` | Where each kind of knowledge lives |
| `LEARNING.md` | Append-only lessons log |
| `README.md` | Public-facing product summary |

## docs/

Every page below is published at
[GitHub Pages](https://kevinle3212.github.io/sensebridge); `docs/index.md` is
that site's landing page and carries the same list grouped for readers.

### Product and roadmap

| File | Purpose |
| --- | --- |
| `docs/PRODUCT.md` | Product positioning, personas, differentiators, funding |
| `docs/ROADMAP.md` | Five phases, MVP definition, deferred scope and sequencing |
| `docs/FAQ.md` | Common questions |

### Architecture and engineering

| File | Purpose |
| --- | --- |
| `docs/ARCHITECTURE.md` | Module seams: `SensingSource` → perception → Reasoning → `RenderTarget` |
| `docs/CODE-MAP.md` | Where every directory lives, "I want to change X" table, how to contribute |
| `docs/AI-MODELS.md` | Model selection and licensing approach |
| `docs/TESTING.md` | Unit / integration / e2e / AI-eval strategy |
| `docs/CI-CD.md` | Every workflow, the blocking gates, and what CI cannot prove |

### The doctrines

| File | Purpose |
| --- | --- |
| `docs/SAFETY-FRAMING.md` | Awareness-not-safety doctrine (highest-severity surface) |
| `docs/ACCESSIBILITY.md` | VoiceOver bar: zero unlabeled elements |
| `docs/PRIVACY.md` | On-device guarantee, consent rules |
| `docs/SECURITY-MODEL.md` | Trust boundaries, threat model, supply chain, permission surface |

### Setup, distribution, reference

| File | Purpose |
| --- | --- |
| `docs/QUICK-START.md` | Fast path to a running app on your own device, plus the living usage guide |
| `docs/ENVIRONMENT.md` | Toolchain setup (see also `scripts/setup.sh`) |
| `docs/SECRETS.md` | Every CI, deployment, and local credential — and what breaks without it |
| `docs/DISTRIBUTION.md` | TestFlight / App Store path |
| `docs/TOOLING.md` | Global-vs-project tooling decision matrix, MCP inventory |
| `docs/OLLAMA.md` | Local LLM experiments (not an app dependency) |
| `docs/NOTEBOOKLM.md` | Manual NotebookLM setup for project research |
| `docs/GLOSSARY.md` | Project vocabulary, plus reading paths per audience |

`docs/planning/` is gitignored working research, deliberately unpublished — it
is neither in this index nor on the docs site.

## Governance, community, legal

`GOVERNANCE.md`, `MAINTAINERS.md`, `CONTRIBUTING.md`, `CODE_OF_CONDUCT.md`,
`COMMUNITY_GUIDELINES.md`, `SUPPORT.md`, `SECURITY.md`, `CREDITS.md`,
`CHANGELOG.md`, `legal/` (owner-approval only), `security/` (threat model,
checklist), `audits/` (append-only reports; guide in `audits/AGENT-GUIDE.md`),
`models/README.md` (model vendoring approach).

## GitHub platform

This page's rendered form is also published live at
[GitHub Pages](https://kevinle3212.github.io/sensebridge) and the
[GitHub Wiki](https://github.com/kevinle3212/sensebridge/wiki) (auto-synced by
`.github/workflows/pages.yml` and `wiki-sync.yml` on every push to `main`).

| File | Purpose |
| --- | --- |
| `docs/index.md`, `docs/_config.yml` | GitHub Pages site built from `docs/` with `source: docs` |
| `docs/_layouts/`, `docs/_includes/`, `docs/_data/nav.yml`, `docs/assets/` | The site's custom layout, navigation data, vendored fonts, CSS and JS. Markdown stays canonical — this layer only presents it |
| `tools/generate-wiki-home.mjs` | Generates the Wiki's `Home.md` from this file |
| `.github/workflows/codeql.yml` | Code scanning (Swift + JavaScript/TypeScript) |
| `.github/workflows/pages.yml` | Docs site build and deploy |
| `.github/workflows/wiki-sync.yml` | Keeps the Wiki's Home page current |
| `.github/prompts/`, `.github/workflows/github-models.yml` | GitHub Models prompt files and manual-dispatch evaluation |
| `.github/workflows/copilot-setup-steps.yml` | Copilot coding agent environment bootstrap (`website/` only — no macOS/Xcode) |
| `.graphifyignore`, `.github/workflows/graphify.yml` | Knowledge-graph build scope and advisory CI rebuild |

---

Need help? See `SUPPORT.md`.
