# PROJECT_OVERVIEW.md

Canonical, token-efficient reference for humans and AI agents: what exists and
where to look. Behavior rules live in `AGENTS.md`; current ground truth for
agents in `AGENT-CONTEXT.md`; the full docs index in `WIKI.md`.

## What SenseBridge is

A free, open-source, **on-device** iOS accessibility app (Swift/SwiftUI,
VoiceOver-first, serverless) giving blind and low-vision users spoken awareness
of their surroundings. Three non-negotiable doctrines constrain every change:
awareness-not-safety, on-device-by-default, accessibility-is-the-product.

## State: five features built on real perception, not yet distributable

`app/` holds a local Swift package (`app/Packages/SenseBridgeCore`) carrying the
`SensingSource` → perception → Reasoning → `RenderTarget` protocol seams and the
hedged `Phrasing`/`AwarenessEngine`, plus an Xcode project with app, unit-test,
and UI-test targets. Builds and tests pass.

The perception layer behind those seams is now real, not canned. Five features
are wired to live capture:

| Feature | Perception | Frameworks |
| --- | --- | --- |
| Reading | `CameraSource` → `OCRService` | AVFoundation, Vision |
| Labeling | `ObjectClassificationService` | Vision, Core ML |
| Scene Description | `ObjectClassificationService` → `FoundationModelsSceneComposer` | Vision, Foundation Models (Apple Intelligence) |
| Obstacle Awareness | `AmbientSensingSource` → `DepthGeometry`/`DepthStatistics` | ARKit (LiDAR `sceneDepth`) |
| Sound Alerts | `MicrophoneSensingSource` → `CombinedSoundClassifier` (`CustomSoundClassifier` + `BuiltInSoundClassifier`, concurrent) | Sound Analysis, Core ML |

Output runs through `SpeechRenderTarget` (AVFoundation) and `HapticRenderTarget`
(Core Haptics). One model is vendored and integrated — an in-house Create ML
sound classifier over per-clip-licence-verified training data, cleared by the
`model-license-audit` skill on 2026-08-05.

What still blocks a release, in order (see `GAPS.md` for the full inventory):
device-only verification of lens switching, zoom, torch, and orientation-correct
capture; the `ObstacleAwarenessView` "check once" button, which still evaluates a
hard-coded depth sample rather than a live one; no `CaptionRenderTarget`, so the
deaf output profile is listed-but-unselectable by design; and the paid Apple
Developer Program, without which no TestFlight or App Store artifact can exist.

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
