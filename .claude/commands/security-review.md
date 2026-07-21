---
description: SenseBridge-tuned security review — runs the built-in security-review analysis, then layers project-specific privacy, model-license, and safety-boundary checks on top.
---

# Security Review — SenseBridge

This command **extends** Claude Code's built-in `/security-review`
(`anthropics/claude-code-security-review`); it does not replace it. Run the
standard diff-scoped security analysis first — injection (SQL/command/LDAP/NoSQL/
XXE), auth/authz flaws, data exposure and hardcoded secrets, crypto weaknesses,
input validation, business-logic flaws, XSS, with false-positive filtering — then
add the project-specific checks below. Findings persist through the
[audit-refresh](../skills/audit-refresh/SKILL.md) skill
(`audits/scripts/new-audit.sh security "<title>"`), append-only.

## Standard pass

Perform the full built-in security review over the current git diff. Report those
findings using the built-in severity model before the project layer below.

## Project-specific layer (SenseBridge)

This is an on-device, serverless iOS app plus a static marketing site. The stock
scanner is tuned for web/back-end attack surface; these are the surfaces that
actually matter here:

1. **Data-egress boundary (highest severity).** Flag any code path that sends
   camera/microphone/sensor/derived-perception data — or anything describing the
   user's surroundings — off-device. It is a Critical finding unless it is gated
   behind explicit, revocable user consent **and** accompanied by a
   [`docs/PRIVACY.md`](../../docs/PRIVACY.md) update. "No telemetry by default"
   is an invariant, not a preference. Watch for: analytics SDKs, crash reporters
   that attach payloads, third-party networking libraries, URL sessions to
   non-allowlisted hosts.
2. **Secrets & signing material.** No API keys, provisioning profiles, `.p12`,
   `.mobileprovision`, or entitlements in source or logs. Cross-check against
   `tools/check-sensitive-files.mjs` coverage; if a new sensitive format appears,
   the scanner's allowlist must grow with it.
3. **Model provenance & license.** A newly vendored model or weights file is a
   supply-chain and licensing event: it must clear
   [model-license-audit](../../.agents/skills/model-license-audit/SKILL.md)
   (AGPL and Apple `apple-amlr` are hard blockers) and its source/hash must be
   verifiable. Flag unpinned or unverifiable model downloads.
4. **Dependency supply chain.** New Swift Package / npm (`website/`) dependency →
   pinned version, lockfile updated, provenance noted in
   [`SECURITY.md`](../../SECURITY.md). Route to
   [dependency-auditor](../../.agents/agents/dependency-auditor.md).
5. **Permission scope.** Info.plist usage strings and requested capabilities stay
   least-privilege and match what the code actually uses. An over-broad
   permission request is a finding even absent an exploit.
6. **CI / workflow integrity.** GitHub Actions use pinned refs (no mutable
   `@main`/`@master`); `permissions:` blocks stay least-privilege; no secret is
   echoed into logs.
7. **Website input handling.** The static site takes no user input and ships no
   JS logic today. If a form, script, or third-party embed appears, treat it as
   new attack surface (XSS, CSP, third-party egress) and review accordingly.

## Honesty rule

State which findings a machine confirmed versus which need human/device
validation. On-device runtime behaviour (what actually leaves the phone at
execution time) is not fully provable from static diff review — say so.
