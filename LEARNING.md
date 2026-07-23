# LEARNING.md — Lessons That Changed How We Work

Append-only. One entry per lesson, newest first, absolute dates. If a lesson
changes a rule, update the rule's home (`AGENTS.md`, `docs/`) and link it —
don't restate the rule here.

## 2026-07-23 — "strict" enforcement needs CI, not just a local hook

The 2026-07-11 entry below chose a dependency-free bash regex over commitlint
because local hooks were the only enforcement layer in play. That reasoning
breaks once the goal is catching a manually-typed commit for consistency:
local hooks are always escapable (`--no-verify`, or a machine with Node
never installed), so only a blocking CI check is actually inescapable.
Resolution: keep the bash regex as the zero-dependency local fallback, add
real commitlint (`commitlint.config.js`, root `package.json`) as the
CI-enforced source of truth (`.github/workflows/commitlint.yml`, lints every
PR commit plus the PR title), and do the same for actionlint
(`.github/workflows/actionlint.yml`, checksum-verified pinned binary rather
than a third-party action). This is the repo's first root-level Node
surface — deliberately minimal (no scripts, no runtime deps) so it stays a
policy tool. Decisions recorded in `docs/TOOLING.md`.

## 2026-07-11 — tool fit beats tool count

Cross-referencing TrustLedger showed most of its toolchain (ESLint, Jest,
Docker, K8s, Vercel, CodeRabbit) exists because it is a web3/TypeScript
monorepo. SenseBridge is a serverless Swift app; importing that stack would
have added maintenance surface with zero coverage. What transferred was
*patterns* — agent-instruction layout, append-only audits, root orientation
docs, secret scanning — not packages. Decisions recorded in `docs/TOOLING.md`.

## 2026-07-11 — quality gates without a package manager

Conventional commits and pre-commit secret scanning don't need Husky or
commitlint: `core.hooksPath` + two small shell scripts (`.githooks/`) do it
with zero dependencies in a repo that has no `package.json`.

## 2026-07-10 — CI that no-ops beats CI that lies

Build/test jobs detect the absence of `app/` and no-op with a message instead
of failing or fake-passing. `main` stays green pre-scaffold, and the jobs
activate automatically when code lands. Same honesty rule as the audit system:
never let a green pipeline imply validation that didn't happen.

---

Need help? See [`SUPPORT.md`](SUPPORT.md).
