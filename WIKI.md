# WIKI.md — documentation index

Every doc, one line each. Start at `PROJECT_OVERVIEW.md` if you're new.

## Orientation (root)

| File | Purpose |
| --- | --- |
| `PROJECT_OVERVIEW.md` | What exists and where to look |
| `AGENTS.md` | Canonical conventions for humans and agents |
| `AGENT-CONTEXT.md` | Current state of the ground for agents |
| `CLAUDE.md` / `GEMINI.md` / `.github/copilot-instructions.md` | Per-agent pointers into `AGENTS.md` |
| `.codex/` `.gemini/` `.copilot/` `.continue/` `.windsurf/` `.cursor/` `.openclaw/` | Per-agent config (Serena MCP + rules), all deferring to `AGENTS.md` |
| `SETUP-STATUS.md` | What is set up vs. pending, next milestones |
| `GAPS.md` | Verified defects, debt, risks |
| `MEMORY.md` | Where each kind of knowledge lives |
| `LEARNING.md` | Append-only lessons log |
| `README.md` | Public-facing product summary |

## docs/

| File | Purpose |
| --- | --- |
| `docs/PRODUCT.md` | Product positioning and scope |
| `docs/architecture.md` | Module seams: `SensingSource` → perception → Reasoning → `RenderTarget` |
| `docs/planning/SenseBridge-01…07`, `-COMPLETE-PLAN.md` | Source research series |
| `docs/safety-framing.md` | Awareness-not-safety doctrine (highest-severity surface) |
| `docs/privacy.md` | On-device guarantee, consent rules |
| `docs/accessibility.md` | VoiceOver bar: zero unlabeled elements |
| `docs/TESTING.md` | Unit / integration / AI-eval strategy |
| `docs/ai-models.md` | Model selection and licensing approach |
| `docs/ENVIRONMENT.md` | Toolchain setup (see also `scripts/setup.sh`) |
| `docs/TOOLING.md` | Global-vs-project tooling decision matrix, MCP inventory |
| `docs/DISTRIBUTION.md` | TestFlight / App Store path |
| `docs/roadmap.md` | Deferred scope and sequencing |
| `docs/FAQ.md` | Common questions |

## Governance, community, legal

`GOVERNANCE.md`, `MAINTAINERS.md`, `CONTRIBUTING.md`, `CODE_OF_CONDUCT.md`,
`COMMUNITY_GUIDELINES.md`, `SUPPORT.md`, `SECURITY.md`, `CREDITS.md`,
`CHANGELOG.md`, `legal/` (owner-approval only), `security/` (threat model,
checklist), `audits/` (append-only reports; guide in `audits/AGENT-GUIDE.md`),
`models/README.md` (model vendoring approach).
