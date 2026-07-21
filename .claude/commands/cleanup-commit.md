# cleanup-commit

Clean the working tree, clear every gate, and commit correctly in SenseBridge.
Run when asked to "clean up and commit" or before handing work over.

---

## Phase 0 — survey (never skip)

1. `git status --porcelain` and `git diff` — know exactly what changed and why.
   Every changed line must trace to the task; revert drive-by edits.
2. Confirm you are **not** on `main` (`git branch --show-current`). If you
   are, stop and create `feat/...`, `fix/...`, or `chore/...` first.
3. If anything under `legal/` changed, stop — owner approval is required
   before those files move at all.

## Phase 1 — automated checks

Run in order; fix and re-run until clean:

1. `./scripts/lint.sh` — SwiftFormat + SwiftLint (no-ops until `app/` exists).
2. `node tools/check-sensitive-files.mjs` — no signing/credential material.
3. `gitleaks protect --staged --redact --config .gitleaks.toml` (after
   staging) — no secrets. Never commit around a finding; remove the secret,
   and rotate it if it was real.
4. If Swift code changed: `swift build` / `xcodebuild build` and the relevant
   tests per `docs/TESTING.md`.

## Phase 2 — manual self-review

- Physical-world / spoken output changed? It must hedge — route through the
  safety-framing-reviewer (`.agents/agents/safety-framing-reviewer.md`).
- UI changed? Zero unlabeled elements; an on-device VoiceOver pass is still
  required — say so honestly rather than claiming it happened.
- New dependency or model? Stop and run the `model-license-audit` /
  `dependency-audit` skill first (AGPL and `apple-amlr` are hard blockers).
- Docs in sync? Run the `update-context` skill — nearest `docs/` file,
  `README.md`, and the root docs (`GAPS.md`, `PROJECT_OVERVIEW.md`,
  `WIKI.md`) whenever structure or capability changed.

## Phase 3 — commit

1. Stage narrowly (`git add <paths>`), not `git add -A`, unless the whole
   tree is genuinely one change.
2. Conventional header: `type(scope): subject` — ≤72 chars, imperative, no
   trailing period. `.githooks/commit-msg` enforces this; do not bypass.
3. Let the hooks run. `--no-verify` is for genuine emergencies only, and must
   be disclosed in the PR description.
4. One logical change per commit; split unrelated work.

## Phase 4 — report

State what was committed, which gates ran clean, and which could not run (no
app yet, no device, no blind tester) — never let "hooks passed" imply more
validation than actually happened.
