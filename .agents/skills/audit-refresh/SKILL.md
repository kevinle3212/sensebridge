---
name: audit-refresh
description:
    Use when a reviewer needs to persist findings. Generates a timestamped,
    append-only audit report under audits/<category>/ from the shared template.
---

## Tool Fallback <!-- tool-fallback -->

- If a preferred tool, command, or skill is unavailable, failing, or a worse fit
  for the task, use the best available alternative rather than stopping or
  forcing it. Note which tool you used and why. Never fall back to a tool the
  repository or user has explicitly prohibited.

## Clarify Before Acting <!-- clarify-before-acting -->

If the category or scope of the audit is ambiguous, ask before writing a report.
State assumptions first.

# Audit Refresh

Every reviewer persona persists its findings through this skill so reports stay
uniform, timestamped, and append-only. Read
[`audits/AGENT-GUIDE.md`](../../../audits/AGENT-GUIDE.md) for the severity rubric
and honesty rules before writing findings.

## Generate a report

```bash
audits/scripts/new-audit.sh <category> "<short title>"
```

The script writes `audits/<category>/<UTC-timestamp>-<slug>.md`, prefilled with
git metadata and the section structure from
[`audits/templates/audit-template.md`](../../../audits/templates/audit-template.md).

## Categories

Valid categories are listed in [`audits/README.md`](../../../audits/README.md)
and enforced by `VALID_TYPES` in the script: `general`, `accessibility`,
`safety-framing`, `privacy`, `security`, `performance`, `model-license`,
`documentation`, `testing`, `dependencies`. Add a category to both the README
table and `VALID_TYPES` together — they must stay in sync.

## Rules

- **Append-only.** Never rewrite a prior report in place; write a new one that
  supersedes it, per [`audits/GOVERNANCE.md`](../../../audits/GOVERNANCE.md).
- **Evidence per finding.** File:line, impact, and a concrete remediation.
- **Honest severity.** Categorize Critical / High / Medium / Low against the
  rubric; do not inflate or soften. Accessibility and safety-framing defects
  carry extra weight — a confidently-wrong physical-world statement is Critical
  even when nothing crashes.
- **Report, don't silently fix.** An audit surfaces findings; remediation is a
  separate, reviewed change.
