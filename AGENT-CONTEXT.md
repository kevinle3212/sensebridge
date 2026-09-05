# AGENT-CONTEXT.md — SenseBridge

Fast orientation for an agent starting a task here. Read
[`CLAUDE.md`](CLAUDE.md) and [`AGENTS.md`](AGENTS.md) for the rules; this file is
the map and the current state of the ground.

## One-paragraph summary

SenseBridge is a free, open-source, on-device iOS app (Swift / SwiftUI,
VoiceOver-first, serverless) that gives blind and low-vision users spoken
awareness of their surroundings. The chain of trust is: perception runs
on-device, reasoning hedges every claim, and nothing is positioned as a safety
device, and users choose their own output rather than having it chosen for
them. Those four doctrines — awareness-not-safety, on-device-by-default,
accessibility-is-the-product, user-agency-over-gatekeeping — constrain every
change.

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
- **An `app/` with five features on real perception.** A local Swift package
  (`app/Packages/SenseBridgeCore`) with the Sensing/Perception/Reasoning/
  Output/Storage/CloudOptional protocol seams and a hedged `Phrasing`/
  `AwarenessEngine`, plus an Xcode project (`app/SenseBridge.xcodeproj`, whose
  `project.pbxproj` is edited directly and is the single source of truth for
  build settings) with app, unit-test, and UI-test targets. Builds and tests pass (`swift test`, `xcodebuild
  build`/`test`, `swiftlint`, `swiftformat`, Semgrep `p/swift`). Live capture
  is wired behind the seams, not canned: Reading (`CameraSource` +
  `OCRService`, AVFoundation/Vision), Labeling (`ObjectClassificationService`,
  Vision/Core ML), Scene Description (`FoundationModelsSceneComposer`,
  Foundation Models), Obstacle Awareness (`AmbientSensingSource` +
  `DepthGeometry`/`DepthStatistics`, ARKit LiDAR `sceneDepth`), and Sound
  Alerts (`MicrophoneSensingSource` + `CombinedSoundClassifier`, which runs
  `CustomSoundClassifier` and `BuiltInSoundClassifier` concurrently on one
  capture — Sound Analysis/Core ML). Output goes through `SpeechRenderTarget`
  and `HapticRenderTarget` (Core Haptics).
- **One vendored model.** An in-house Create ML sound classifier over
  per-clip-licence-verified training data, cleared by `model-license-audit` on
  2026-08-05 and integrated into Sound Alerts. The `.mlmodel` ships from
  `app/SenseBridge/Resources/`; `models/sound-classifier/` holds the training
  data and retraining scripts.

What does **not** exist yet — do not assume, reference as built, or fabricate:

- **A distributable build.** No TestFlight or App Store artifact exists, and
  `DEVELOPMENT_TEAM` is unset in `project.pbxproj`. The bundle identifier is no
  longer a bare placeholder — it is build-setting-driven
  (`$(BUNDLE_ID_PREFIX:default=com.sensebridge).app`).
- **Device-verified capture.** Lens switching, cross-lens zoom, torch, and
  orientation-corrected capture compile but have been exercised only by the
  compiler; none of them work in Simulator.
- **A caption output channel.** There is no `CaptionRenderTarget`, so the deaf
  output profile is listed in Settings as unavailable, with its reason, rather
  than hidden (AGENTS.md doctrine 4).
- **Further bundled models.** Any addition goes through the
  [model-license-audit](.agents/skills/model-license-audit/SKILL.md) skill;
  AGPL and `apple-amlr` are hard blockers.

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
- Persist review findings via `tools/new-audit.sh` — append-only.
- Never edit `legal/` without owner approval; AGPL and `apple-amlr` are hard
  license blockers.
- Never commit to `main`; branch and open a PR so CI runs.
