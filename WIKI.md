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

| File | Purpose |
| --- | --- |
| `docs/PRODUCT.md` | Product positioning and scope |
| `docs/ARCHITECTURE.md` | Module seams: `SensingSource` → perception → Reasoning → `RenderTarget` |
| `docs/SAFETY-FRAMING.md` | Awareness-not-safety doctrine (highest-severity surface) |
| `docs/PRIVACY.md` | On-device guarantee, consent rules |
| `docs/ACCESSIBILITY.md` | VoiceOver bar: zero unlabeled elements |
| `docs/TESTING.md` | Unit / integration / e2e / AI-eval strategy |
| `docs/AI-MODELS.md` | Model selection and licensing approach |
| `docs/ENVIRONMENT.md` | Toolchain setup (see also `scripts/setup.sh`) |
| `docs/TOOLING.md` | Global-vs-project tooling decision matrix, MCP inventory |
| `docs/DISTRIBUTION.md` | TestFlight / App Store path |
| `docs/ROADMAP.md` | Deferred scope and sequencing |
| `docs/FAQ.md` | Common questions |

## Governance, community, legal

`GOVERNANCE.md`, `MAINTAINERS.md`, `CONTRIBUTING.md`, `CODE_OF_CONDUCT.md`,
`COMMUNITY_GUIDELINES.md`, `SUPPORT.md`, `SECURITY.md`, `CREDITS.md`,
`CHANGELOG.md`, `legal/` (owner-approval only), `security/` (threat model,
checklist), `audits/` (append-only reports; guide in `audits/AGENT-GUIDE.md`),
`models/README.md` (model vendoring approach).

---

Need help? See [`SUPPORT.md`](SUPPORT.md).
