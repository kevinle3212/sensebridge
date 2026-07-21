# PROJECT_OVERVIEW.md

Canonical, token-efficient reference for humans and AI agents: what exists and
where to look. Behavior rules live in `AGENTS.md`; current ground truth for
agents in `AGENT-CONTEXT.md`; the full docs index in `WIKI.md`.

## What SenseBridge is

A free, open-source, **on-device** iOS accessibility app (Swift/SwiftUI,
VoiceOver-first, serverless) giving blind and low-vision users spoken awareness
of their surroundings. Three non-negotiable doctrines constrain every change:
awareness-not-safety, on-device-by-default, accessibility-is-the-product.

## State: early `app/` scaffold, no feature work yet

`app/` holds a local Swift package (`app/Packages/SenseBridgeCore`) with the
`SensingSource` → perception → Reasoning → `RenderTarget` protocol seams and a
hedged `Phrasing`/`AwarenessEngine`, plus an Xcode project with app,
unit-test, and UI-test targets. Builds and tests pass. This is scaffolding,
not the product: real perception (Vision, Sound Analysis, ARKit, Foundation
Models) and most UI are still unbuilt. Next milestones, in order (see
`GAPS.md`): vendor the first model through the `model-license-audit`
skill, then build the real perception/reasoning implementations behind the
scaffolded protocols.

## Layout

| Area | Where |
| --- | --- |
| Product, architecture, privacy, safety framing, accessibility, testing | `docs/` (index: `WIKI.md`) |
| Agent instructions | `AGENTS.md` (canonical) + `CLAUDE.md`, `GEMINI.md`, `.cursor/rules/`, `.github/copilot-instructions.md` (pointers) |
| Skills and reviewer personas | `.agents/`, `.claude/skills/` |
| Append-only audits | `audits/` (generate via `audits/scripts/new-audit.sh`) |
| CI/CD and security scanning | `.github/workflows/` |
| Git hooks (secret scan, lint, commit format) | `.githooks/` (enabled by `scripts/setup.sh`) |
| Tooling decisions (global vs. project) | `docs/TOOLING.md` |
| Known defects and debt | `GAPS.md` |
| Memory architecture | `MEMORY.md`; lessons in `LEARNING.md` |
| Legal (owner-approval only) | `legal/` |

## Working here

Run `scripts/setup.sh` once (checks toolchain, enables hooks). Branch as
`feat/...`/`fix/...`/`chore/...`, conventional commits, PR into `main` so CI
runs. Clear the `ci-green-gate` skill before any PR.

---

Need help? See [`SUPPORT.md`](SUPPORT.md).
