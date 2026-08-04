# SenseBridge — Core

On-device iOS accessibility app (VoiceOver-first, blind/low-vision users). No
backend, no accounts, no telemetry by default — a network round-trip for
perception/reasoning requires explicit opt-in.

Pipeline (protocol seams, dependencies point inward):
`SensingSource` (capture) -> perception services -> Reasoning (pure,
framework-independent) -> `RenderTarget` (output). Never couple reasoning
code to a specific capture/render framework.

Two Swift build units:

- `app/SenseBridge` — Xcode app target (`App/`, `Features/*`,
  `Accessibility/`, `Resources/`).
- `app/Packages/SenseBridgeCore` — SPM library package, swift-tools 6.2.

`website/` is a separate, unrelated Astro/TypeScript marketing site (Node
stack) — pre-launch, no backend, but still governed by the app's
safety-framing doctrine for copy.

`AGENTS.md` at repo root is the canonical instruction file; `CLAUDE.md`,
`GEMINI.md`, per-harness configs are thin pointers to it, never duplicates.

See `mem:tech_stack`, `mem:suggested_commands`, `mem:conventions`,
`mem:task_completion`.
