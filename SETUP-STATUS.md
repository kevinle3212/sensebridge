# SETUP-STATUS.md — SenseBridge

Where the repository stands and what to do next. Honest by design: it
distinguishes what is set up from what is planned but not yet built. Last
reviewed 2026-07-10.

## Set up and ready

- **Governance and community** — `GOVERNANCE.md`, `MAINTAINERS.md`,
  `CODE_OF_CONDUCT.md`, `COMMUNITY_GUIDELINES.md`, `CONTRIBUTING.md`,
  `SUPPORT.md`, `CREDITS.md`, `CHANGELOG.md`, `FUNDING.yml`.
- **Legal and security posture** — `legal/` (privacy policy, terms, disclaimer),
  `SECURITY.md`, `security/`.
- **Documentation** — full `docs/` set (product, architecture, privacy,
  accessibility, safety-framing, testing, distribution, environment, AI models,
  FAQ, roadmap) plus the `docs/planning/` series.
- **Agent tooling** — reviewer personas (`.agents/agents/`), skills
  (`.agents/skills/`, `.claude/skills/audit-refresh`), and root instruction
  files (`CLAUDE.md`, `AGENTS.md`, `AGENT-CONTEXT.md`).
- **Audit system** — append-only reports via `audits/scripts/new-audit.sh`;
  rubric and rules in `audits/AGENT-GUIDE.md` and `audits/GOVERNANCE.md`.
- **CI/CD and repo hygiene** — `.github/workflows/` (CI, security, Claude review),
  `dependabot.yml`, auto-merge, `CODEOWNERS`, PR template, issue forms.

## Pending — the real next steps

1. **Scaffold the Swift app under `app/`.** This is the top milestone. No Xcode
   project or Swift source exists yet; `CONTRIBUTING.md`, `docs/`, `ci.yml`, and
   `dependabot.yml` already point at `app/` so they activate the moment the
   project lands. Follow the module seams in
   `docs/planning/SenseBridge-03-Technical-Architecture.md`:
   `SensingSource` → perception services → Reasoning → `RenderTarget`.
2. **Vendor the first on-device model** through the `model-license-audit` skill.
   `models/README.md` describes the approach; nothing is vendored yet. AGPL and
   Apple's `apple-amlr` are hard blockers.
3. **Stand up the test targets** described in `docs/TESTING.md` — start with the
   reasoning/hedging unit tests, where a subtle bug is most dangerous.

## Repository secrets to configure (GitHub → Settings → Secrets → Actions)

- `ANTHROPIC_API_KEY` — required by `claude.yml` and `claude-code-review.yml`.
  Until it is set, those workflows will fail; the core CI and security workflows
  do not need it.

## Repository settings to enable

- Branch protection on `main`: require the CI checks and at least one review.
- "Allow auto-merge" (needed by `dependabot-automerge.yml`).
- Enable Discussions if you want the issue-template support link to resolve.

## Honest gaps

- CI's build/test jobs **no-op until `app/` exists** — they are wired correctly
  but cannot prove anything about an app that isn't there yet.
- On-device latency/battery/thermal and blind-tester (TestFlight) validation are
  **not** provable in CI and must be done on real devices with real users before
  any release. See the `ci-green-gate` skill.
