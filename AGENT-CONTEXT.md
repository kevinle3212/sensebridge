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

What exists today:

- **Docs** — product, architecture, privacy, accessibility, safety-framing,
  testing, distribution, and environment.
- **Governance and legal** — `GOVERNANCE.md`, `MAINTAINERS.md`,
  `CODE_OF_CONDUCT.md`, `COMMUNITY_GUIDELINES.md`, `SECURITY.md`, and `legal/`.
- **Agent tooling** — reviewer personas (`.agents/agents/`), skills
  (`.agents/skills/`, `.claude/skills/`), and the append-only audit system
  (`audits/`).
- **Community scaffolding** — `CONTRIBUTING.md`, `SUPPORT.md`, `.github/`
  workflows and templates, `CREDITS.md`, `CHANGELOG.md`.
- **An early `app/` scaffold.** A local Swift package
  (`app/Packages/SenseBridgeCore`) with the Sensing/Perception/Reasoning/
  Output/Storage/CloudOptional protocol seams and a hedged `Phrasing`/
  `AwarenessEngine`, plus an Xcode project (`app/SenseBridge.xcodeproj`,
  generated via `xcodegen` from `app/project.yml`) with app, unit-test, and
  UI-test targets. Builds and tests pass (`swift test`, `xcodebuild
  build`/`test`, `swiftlint`, `swiftformat`, Semgrep `p/swift`). This is
  scaffolding, not the product: real perception
  (Vision, Sound Analysis, ARKit, Foundation Models) and most UI are still
  unbuilt, and nothing has been distributed to TestFlight or the App Store.

What does **not** exist yet — do not assume, reference as built, or fabricate:

- **Real perception, reasoning, and feature UI.** The protocols exist; Vision
  OCR/detection, Sound Analysis, ARKit depth, and the Foundation Models scene
  composer are all still real feature work — see [`GAPS.md`](GAPS.md) →
  "Not yet done" → "Application".
- **A distributable build.** No TestFlight or App Store artifact exists; the
  bundle ID and signing team in `app/project.yml` are placeholders.
- **Bundled models.** `models/README.md` describes the intended approach;
  no model is vendored yet. Any addition goes through the
  [model-license-audit](.agents/skills/model-license-audit/SKILL.md) skill.

If a task assumes source that isn't here, say so plainly rather than inventing
it.

## Where to look

| Need | Path |
| --- | --- |
| Product and scope | [`docs/PRODUCT.md`](docs/PRODUCT.md) |
| Architecture and module seams | [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md) |
| Awareness-not-safety doctrine | [`docs/SAFETY-FRAMING.md`](docs/SAFETY-FRAMING.md) |
| Privacy / on-device guarantee | [`docs/PRIVACY.md`](docs/PRIVACY.md) |
| Accessibility bar | [`docs/ACCESSIBILITY.md`](docs/ACCESSIBILITY.md) |
| Testing strategy | [`docs/TESTING.md`](docs/TESTING.md) |
| Setup / toolchain | [`docs/ENVIRONMENT.md`](docs/ENVIRONMENT.md) |
| Model licensing | [`docs/AI-MODELS.md`](docs/AI-MODELS.md), [`models/README.md`](models/README.md) |
| Conventions | [`AGENTS.md`](AGENTS.md) |
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
