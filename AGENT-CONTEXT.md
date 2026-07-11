# AGENT-CONTEXT.md — SenseBridge

Fast orientation for an agent starting a task here. Read
[`CLAUDE.md`](CLAUDE.md) and [`AGENTS.md`](AGENTS.md) for the rules; this file is
the map and the current state of the ground.

## One-paragraph summary

SenseBridge is a free, open-source, on-device iOS app (Swift / SwiftUI,
VoiceOver-first, serverless) that gives blind and low-vision users spoken
awareness of their surroundings. The chain of trust is: perception runs
on-device, reasoning hedges every claim, and nothing is positioned as a safety
device. Those three doctrines — awareness-not-safety, on-device-by-default,
accessibility-is-the-product — constrain every change.

## Current repo state (read before assuming code exists)

This repository is **planning- and governance-complete but pre-implementation**.
What exists today:

- **Docs** — product, architecture, privacy, accessibility, safety-framing,
  testing, distribution, environment, and the full `docs/planning/` set.
- **Governance and legal** — `GOVERNANCE.md`, `MAINTAINERS.md`,
  `CODE_OF_CONDUCT.md`, `COMMUNITY_GUIDELINES.md`, `SECURITY.md`, and `legal/`.
- **Agent tooling** — reviewer personas (`.agents/agents/`), skills
  (`.agents/skills/`, `.claude/skills/`), and the append-only audit system
  (`audits/`).
- **Community scaffolding** — `CONTRIBUTING.md`, `SUPPORT.md`, `.github/`
  workflows and templates, `CREDITS.md`, `CHANGELOG.md`.

What does **not** exist yet — do not assume, reference as built, or fabricate:

- **The Swift app itself.** There is no `app/` Xcode project or Swift source
  tree yet. `CONTRIBUTING.md` and `docs/` reference `app/` as the intended
  location; treat that as a target, not an existing artifact. Scaffolding the app
  is the next major milestone — see [`SETUP-STATUS.md`](SETUP-STATUS.md).
- **Bundled models.** `models/README.md` describes the intended approach;
  no model is vendored yet. Any addition goes through the
  [model-license-audit](.agents/skills/model-license-audit/SKILL.md) skill.

If a task assumes source that isn't here, say so plainly rather than inventing
it.

## Where to look

| Need | Path |
| --- | --- |
| Product and scope | [`docs/PRODUCT.md`](docs/PRODUCT.md) |
| Architecture and module seams | [`docs/architecture.md`](docs/architecture.md), [`docs/planning/SenseBridge-03-Technical-Architecture.md`](docs/planning/SenseBridge-03-Technical-Architecture.md) |
| Awareness-not-safety doctrine | [`docs/safety-framing.md`](docs/safety-framing.md) |
| Privacy / on-device guarantee | [`docs/privacy.md`](docs/privacy.md) |
| Accessibility bar | [`docs/accessibility.md`](docs/accessibility.md) |
| Testing strategy | [`docs/TESTING.md`](docs/TESTING.md) |
| Setup / toolchain | [`docs/ENVIRONMENT.md`](docs/ENVIRONMENT.md) |
| Model licensing | [`docs/ai-models.md`](docs/ai-models.md), [`models/README.md`](models/README.md) |
| Conventions | [`AGENTS.md`](AGENTS.md) |
| What's set up vs. pending | [`SETUP-STATUS.md`](SETUP-STATUS.md) |
| Tooling decisions, MCP inventory | [`docs/TOOLING.md`](docs/TOOLING.md) |
| Known defects and debt | [`GAPS.md`](GAPS.md) |
| Where knowledge lives (repo vs. vault) | [`MEMORY.md`](MEMORY.md) |

## Working here

- Invoke the matching skill before hand-rolling a workflow; route physical-world
  output changes through the safety-framing-reviewer.
- Persist review findings via `audits/scripts/new-audit.sh` — append-only.
- Never edit `legal/` without owner approval; AGPL and `apple-amlr` are hard
  license blockers.
- Never commit to `main`; branch and open a PR so CI runs.
