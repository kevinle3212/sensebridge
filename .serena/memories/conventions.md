# Conventions

- Protocol seams are load-bearing: `SensingSource` -> perception services ->
  Reasoning (pure) -> `RenderTarget`. Reasoning logic must stay
  framework-independent; never import a capture/render framework there.
- **Awareness, not safety**: every spoken/caption/haptic output string must
  hedge and never assert unearned certainty ("looks like a person is
  nearby," never "a person is nearby"). Highest-severity review surface —
  route such changes through the `safety-framing-reviewer` agent. See
  `docs/SAFETY-FRAMING.md`.
- No perception/model inference on the main thread — UI must stay responsive
  to VoiceOver during processing (see the `swift-concurrency-6-2` skill for
  the mechanism).
- Zero unlabeled interactive UI elements is a hard accessibility gate (not a
  percentage) — every changed screen needs a VoiceOver pass.
- AGPL and Apple's `apple-amlr` license are hard blockers for any bundled
  model or dependency — gated by the `model-license-audit` skill.
- Never edit anything under `legal/` (privacy policy, terms, disclaimer)
  without explicit owner approval.
- Branching: `feat/...`, `fix/...`, `chore/...`; never commit directly to
  `main`. Conventional commit headers: `type(scope): subject`.
- No git worktrees unless the user explicitly says "worktree" or the harness
  mandates isolation.
