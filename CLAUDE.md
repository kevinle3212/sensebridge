# CLAUDE.md — SenseBridge

Project rules only. Personal preferences (communication style, simplicity,
surgical changes, git permission rules, tooling) live in the global
`~/.claude/CLAUDE.md` and are never repeated here — a rule stated twice drifts
into two rules. When this file and the global file conflict, this file wins for
SenseBridge work.

## Orientation (read before exploring)

- What the product is, and the three doctrines that constrain every change:
  [`AGENTS.md`](AGENTS.md). Read it first.
- Product and scope: [`docs/PRODUCT.md`](docs/PRODUCT.md). Architecture:
  [`docs/architecture.md`](docs/architecture.md) and
  [`docs/planning/`](docs/planning).
- Setup and toolchain: [`docs/ENVIRONMENT.md`](docs/ENVIRONMENT.md). Testing:
  [`docs/TESTING.md`](docs/TESTING.md).

## Architecture invariants

- **Serverless, on-device.** There is no backend, no accounts, and no telemetry
  by default. Do not introduce a network round-trip for perception or reasoning;
  anything leaving the device needs explicit, revocable user consent and a
  privacy-doc update. See [`docs/privacy.md`](docs/privacy.md).
- **Protocol seams.** The pipeline is `SensingSource` → perception services →
  Reasoning → `RenderTarget`. Dependencies point inward; reasoning logic stays
  pure and framework-independent. Never couple reasoning to a specific capture or
  render framework. See the [api-design](.agents/skills/api-design/SKILL.md) skill.
- **Awareness, not safety.** Every spoken/caption/haptic string hedges and never
  asserts unearned certainty. This is the highest-severity review surface —
  route such changes through the
  [safety-framing-reviewer](.agents/agents/safety-framing-reviewer.md). See
  [`docs/safety-framing.md`](docs/safety-framing.md).
- **Main thread stays free.** No perception or model inference on the main
  thread; the UI must stay responsive to VoiceOver during processing.

## Quality gates (blocking)

Clear the [ci-green-gate](.agents/skills/ci-green-gate/SKILL.md) before any PR:

- Build (`xcodebuild build`, and `swift build` where a package target exists).
- Tests pass (unit / integration / AI-eval per [`docs/TESTING.md`](docs/TESTING.md)).
- **Zero unlabeled elements** on every screen + a VoiceOver pass on changed UI.
  This is a hard gate, not a percentage.
- Safety-framing review for any physical-world output.
- Model-license clearance — AGPL and Apple's `apple-amlr` are hard blockers.

CI cannot prove on-device latency/battery/thermal or blind-tester validation.
State plainly which gates a machine verified and which still need device and
human validation; never let a green pipeline imply the app was validated by the
people it is for.

## Skills and agents (use, don't reinvent)

- Skills: `.agents/skills/*` and `.claude/skills/audit-refresh`. Invoke the
  matching skill before hand-rolling a workflow. After repo changes, run the
  [update-context](.agents/skills/update-context/SKILL.md) skill to keep docs and
  agent instructions current.
- Review agents: `.agents/agents/*`. Dependency and vulnerability reviews use
  [dependency-auditor](.agents/agents/dependency-auditor.md).
- Audits are append-only via `audits/scripts/new-audit.sh`; read
  [`audits/AGENT-GUIDE.md`](audits/AGENT-GUIDE.md) first. Report findings — don't
  silently fix during an audit.

## Legal and licensing

Never edit anything under [`legal/`](legal) (privacy policy, terms, disclaimer)
without explicit owner approval. Model and dependency licenses are gated by the
[model-license-audit](.agents/skills/model-license-audit/SKILL.md) skill; the
[legal-compliance](.agents/skills/legal-compliance/SKILL.md) skill flags when a
change needs legal review.

## Branching and committing

- Never commit to `main`; branch as `feat/...`, `fix/...`, `chore/...`.
- Conventional commit headers `type(scope): subject`.
- Keep `main` deployable; prefer a PR so CI runs.

## Docs sync (per change)

Update whatever the change touches: behaviour/models/permissions → the relevant
`docs/` file + `README.md`; env vars/toolchain → `docs/ENVIRONMENT.md`;
dependencies → `SECURITY.md` + setup steps; moved/renamed files → purge stale
references everywhere (docs, comments, templates, agent instructions).
