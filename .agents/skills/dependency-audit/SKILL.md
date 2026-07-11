---
name: dependency-audit
description:
    Use when adding or updating a SwiftPM dependency or bundled model. Checks
    freshness, provenance, vulnerabilities, and license compatibility.
---

## Tool Fallback <!-- tool-fallback -->

- If a preferred tool, command, or skill is unavailable, failing, or a worse fit
  for the task, use the best available alternative rather than stopping or
  forcing it. Note which tool you used and why. Never fall back to a tool the
  repository or user has explicitly prohibited.

## Clarify Before Acting <!-- clarify-before-acting -->

If the need for a dependency or its provenance is unclear, interview the user or
surface assumptions before adding it.

# Dependency Audit

Pairs with the [dependency-auditor](../../agents/dependency-auditor.md) agent.
Every new dependency is a liability to justify against the "boring proven
solution" bar.

## Checklist

1. **License first.** Run the `model-license-audit` skill for any model; for
   packages, confirm the license permits App Store distribution (AGPL is a hard
   block).
2. **Provenance.** Trusted source, credible maintainer, real release history.
3. **Pinning.** Exact versions in `Package.resolved`; no floating ranges.
4. **Vulnerabilities.** Check OSV advisories for the pinned version.
5. **Tree size.** Prefer the standard library / an existing dependency over a new
   one; minimise transitive additions.
6. **Record** models in [`models/README.md`](../../../models/README.md).

## Validation

Resolve and build (`swift build` / `xcodebuild build`) after any dependency
change; record the audit via `audits/scripts/new-audit.sh dependencies "<title>"`.
