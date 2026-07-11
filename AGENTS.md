# AGENTS.md — SenseBridge

Canonical conventions for anyone — human or agent — working in this repository.
Personal/global preferences are not repeated here. When this file and a more
specific skill or persona conflict, the more specific one wins.

## What SenseBridge is

A free, open-source, **on-device** iOS accessibility app that gives blind and
low-vision users spoken awareness of their surroundings. Swift / SwiftUI,
VoiceOver-first, serverless — no backend, no accounts, no telemetry by default.
Product and scope live in [`docs/PRODUCT.md`](docs/PRODUCT.md); architecture in
[`docs/architecture.md`](docs/architecture.md) and
[`docs/planning/`](docs/planning).

## The three doctrines (non-negotiable)

1. **Awareness, not safety.** The app raises awareness of the environment; it is
   never positioned or worded as a mobility- or navigation-safety device.
   Spoken output hedges ("looks like", "appears to be") and never asserts
   certainty the models did not earn. See
   [`docs/safety-framing.md`](docs/safety-framing.md). A confidently-wrong
   physical-world statement is the worst-case bug in this project — worse than a
   crash.
2. **On-device by default.** Perception and reasoning run on-device; nothing
   about the user's surroundings leaves the phone without explicit, revocable
   consent. See [`docs/privacy.md`](docs/privacy.md).
3. **Accessibility is the product, not a feature.** Every screen is fully
   VoiceOver-navigable with zero unlabeled elements before it merges. See
   [`docs/accessibility.md`](docs/accessibility.md).

## Coding conventions

- **Swift / SwiftUI.** Protocol-oriented seams — `SensingSource`, perception
  services, the Reasoning layer, `RenderTarget` — so each stage is replaceable
  and testable with fixtures. Dependencies point inward; reasoning logic stays
  pure and unit-testable. See the [api-design](.agents/skills/api-design/SKILL.md)
  skill.
- **Reliability priority order (unusual, honour it):** correct hedging first,
  then not crashing, then performance.
- **No perception or model work on the main thread**; the UI stays responsive to
  VoiceOver during processing.
- Small, focused types; names reveal intent; no giant files or magic values.

## UI and copy conventions

- Title Case for labels and buttons; sentence case for prose and spoken strings.
- Preserve acronyms exactly: `VoiceOver`, `OCR`, `HIG`, `ANE`, `TestFlight`.
- Spoken output follows the awareness-not-safety framing without exception.
- Store and onboarding copy never claims a safety or navigation guarantee.

## Skills and agents (use, don't reinvent)

- **Skills** — `.agents/skills/*` (accessibility, api-design, ci-green-gate,
  dependency-audit, documentation, legal-compliance, log-markdown,
  model-license-audit, performance, security, testing, update-context) and
  `.claude/skills/audit-refresh`. Invoke the matching skill before hand-rolling a
  workflow.
- **Review agents** — `.agents/agents/*` (accessibility-reviewer,
  safety-framing-reviewer, security-reviewer, dependency-auditor,
  performance-reviewer, documentation-reviewer, ui-reviewer). The
  safety-framing-reviewer owns the highest-severity surface.

## Audits

Reviewers persist findings via the
[audit-refresh](.claude/skills/audit-refresh/SKILL.md) skill
(`audits/scripts/new-audit.sh <category> "<title>"`). Reports are append-only;
read [`audits/AGENT-GUIDE.md`](audits/AGENT-GUIDE.md) for the severity rubric and
honesty rules. Report findings — don't silently fix during an audit.

## Quality gates (blocking)

Before any PR, clear the [ci-green-gate](.agents/skills/ci-green-gate/SKILL.md):
build, tests, zero unlabeled elements + VoiceOver pass, safety-framing review for
physical-world output, and model-license clearance for any new model or
dependency. CI cannot prove on-device latency/battery/thermal or blind-tester
validation — state honestly which gates a machine verified and which still need
device and human validation.

## Licensing

AGPL and Apple's `apple-amlr` research-only license are **hard blockers** for
bundled models and dependencies. See the
[model-license-audit](.agents/skills/model-license-audit/SKILL.md) skill and
[`docs/ai-models.md`](docs/ai-models.md). Never edit anything under
[`legal/`](legal) without explicit owner approval.

## Docs sync (per change)

Update the nearest authoritative doc in the same change: behaviour/build/models/
permissions → the relevant `docs/` file and `README.md`; env → `docs/ENVIRONMENT.md`;
dependencies → `SECURITY.md` and setup steps. When code, screens, or workflows
move, purge stale references everywhere (docs, comments, templates, agent
instructions). The [update-context](.agents/skills/update-context/SKILL.md) skill
drives this pass.
