# sensebridge ground-up readiness audit

| Field           | Value         |
| --------------- | ------------- |
| Audit type      | general      |
| Timestamp (UTC) | 2026-07-11T03:56:26Z |
| Git branch      | main    |
| Commit hash     | 1d4eacf    |
| Auditor         | Kevin Khanh Le    |

## Scope

Readiness of the SenseBridge repository to be worked on "from the ground up":
agent tooling, governance, CI/CD, issue/PR templates, root instruction files,
and the audit system. Confirms these are present, internally consistent, and
free of content carried over from the unrelated source project they were adapted
from.

Explicitly **out of scope**: the Swift application itself (not yet scaffolded),
model licensing of specific models (none vendored yet), and any on-device or
blind-tester validation (not possible without the app).

## Files Inspected

- `CLAUDE.md`, `AGENTS.md`, `AGENT-CONTEXT.md`, `SETUP-STATUS.md`
- `.agents/agents/*.md` (7 reviewer personas)
- `.agents/skills/*/SKILL.md` (12 skills), `.claude/skills/audit-refresh/SKILL.md`
- `audits/AGENT-GUIDE.md`, `audits/GOVERNANCE.md`, `audits/README.md`,
  `audits/templates/audit-template.md`, `audits/scripts/new-audit.sh`
- `.github/workflows/{ci,security,claude,claude-code-review,dependabot-automerge}.yml`
- `.github/{dependabot.yml,CODEOWNERS,PULL_REQUEST_TEMPLATE.md}`
- `.github/ISSUE_TEMPLATE/{config,accessibility,bug,feature}.yml`

## Issues Found

| #   | Severity | Issue | Location | Status |
| --- | -------- | ----- | -------- | ------ |
| 1   | Medium   | `ci-green-gate` skill directory existed but was empty (write had failed on a transient error) | `.agents/skills/ci-green-gate/` | Fixed |
| 2   | Low      | Adapted CI/dependabot comments named source-project tech (`smart contracts`, `Solidity`) as exclusions, which could confuse a reader of an iOS repo | `.github/workflows/security.yml`, `.github/dependabot.yml` | Fixed |
| 3   | Info     | Swift app is not scaffolded; CI build/test jobs cannot exercise real code yet | `app/` (absent) | Deferred |
| 4   | Info     | `ANTHROPIC_API_KEY` secret not configured; Claude workflows will fail until set | repo settings | Deferred |

## Fixes Applied

- **#1** — Authored the `ci-green-gate` skill: blocking gates (build, tests,
  zero-unlabeled-elements + VoiceOver pass, safety-framing review, model-license
  clearance) plus an explicit honesty section on what CI cannot prove.
- **#2** — Reworded both comments to state the positive scope (what ecosystems /
  attack surface actually apply) instead of naming the source project's tech.

## Files Modified

- `.agents/skills/ci-green-gate/SKILL.md` (created)
- `.github/workflows/security.yml`, `.github/dependabot.yml`

## Rationale

The instruction/tooling layer was adapted from an unrelated web3 project; the
audit's priority was ensuring zero conceptual bleed-through (no blockchain, web,
or backend assumptions) and that every doctrine unique to SenseBridge —
awareness-not-safety, on-device-by-default, accessibility-first — is encoded
consistently across personas, skills, CI review prompts, and templates. CI was
written to no-op until `app/` exists rather than fail, keeping `main` green while
remaining correct once code lands.

## Recommendations

- Scaffold `app/` against the seams in
  `docs/planning/SenseBridge-03-Technical-Architecture.md`; CI, dependabot, and
  CONTRIBUTING already point at it.
- Enable branch protection on `main` and "Allow auto-merge" so
  `dependabot-automerge.yml` functions.
- Configure `ANTHROPIC_API_KEY` before relying on the Claude workflows.

## Follow-up Actions

- [ ] Scaffold the Swift app under `app/` (top milestone; see `SETUP-STATUS.md`).
- [ ] Set repository secret `ANTHROPIC_API_KEY`.
- [ ] Enable branch protection + auto-merge in repo settings.
- [ ] Vendor the first on-device model through the `model-license-audit` skill.

## Remaining Work

The application, its tests, and any bundled model are intentionally absent — this
audit covers only the surrounding scaffolding. On-device latency/battery/thermal
and blind-tester validation remain impossible until the app exists and are called
out as such in `SETUP-STATUS.md` and the `ci-green-gate` skill.

## Verification Performed

Static review plus mechanical checks below. No device, simulator, or blind tester
was involved — there is no app to run, and this audit does not claim otherwise.

### Commands Executed

```bash
# YAML validity of every workflow, dependabot config, and issue form
for f in .github/workflows/*.yml .github/dependabot.yml .github/ISSUE_TEMPLATE/*.yml; do
  python3 -c "import yaml; yaml.safe_load(open('$f'))"; done   # all OK

# source-project leak grep across docs, workflows, scripts
grep -rniE "trustledger|solidity|escrow|wagmi|prisma|foundry|slither|hardhat|blockchain" \
  --include="*.md" --include="*.yml" --include="*.yaml" --include="*.sh" \
  --exclude-dir=.git --exclude-dir=.serena .                   # CLEAN
```

### Test Results

Not applicable — no test targets exist yet.

### Build Status

Not run — no Swift package or Xcode project present. CI is configured to build
automatically once `app/` contains one.

## Sign-off

- Auditor: Kevin Khanh Le
- Reviewed by:
- Date: 2026-07-10
