# LEARNING.md — lessons that changed how we work

Append-only. One entry per lesson, newest first, absolute dates. If a lesson
changes a rule, update the rule's home (`AGENTS.md`, `docs/`) and link it —
don't restate the rule here.

## 2026-07-11 — Tool fit beats tool count

Cross-referencing TrustLedger showed most of its toolchain (ESLint, Jest,
Docker, K8s, Vercel, CodeRabbit) exists because it is a web3/TypeScript
monorepo. SenseBridge is a serverless Swift app; importing that stack would
have added maintenance surface with zero coverage. What transferred was
*patterns* — agent-instruction layout, append-only audits, root orientation
docs, secret scanning — not packages. Decisions recorded in `docs/TOOLING.md`.

## 2026-07-11 — Quality gates without a package manager

Conventional commits and pre-commit secret scanning don't need Husky or
commitlint: `core.hooksPath` + two small shell scripts (`.githooks/`) do it
with zero dependencies in a repo that has no `package.json`.

## 2026-07-10 — CI that no-ops beats CI that lies

Build/test jobs detect the absence of `app/` and no-op with a message instead
of failing or fake-passing. `main` stays green pre-scaffold, and the jobs
activate automatically when code lands. Same honesty rule as the audit system:
never let a green pipeline imply validation that didn't happen.
