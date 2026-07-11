# Audit & File Governance

The repository cannot enforce true filesystem write-protection. Anyone who can
push can, in principle, edit any file. "Locking" a file at the repository level
is not real security — so this project protects sensitive paths (audit reports,
legal documents, safety-framing doctrine, security policy, CI config) through
**review controls** you configure in GitHub, plus `CODEOWNERS`.

## 1. CODEOWNERS (in-repo)

`.github/CODEOWNERS` maps sensitive paths to their required reviewer. GitHub
automatically requests review from the listed owner on any PR touching those
paths. This is the strongest protection the repository itself can express.

## 2. Branch protection (configure in GitHub — not in-repo)

Enable on `main` under **Settings → Branches → Branch protection rules** (or via
a ruleset under **Settings → Rules**):

- Require a pull request before merging.
- Require approvals: at least **1**.
- **Require review from Code Owners.**
- Require status checks to pass (select the CI checks: build, tests, lint).
- Require branches to be up to date before merging.
- Require conversation resolution before merging.
- Do not allow bypassing the above (including for administrators, if desired).
- Restrict who can push to matching branches.

For a solo maintainer, "require approvals" can feel redundant, but Code Owner
review on `docs/safety-framing.md`, `legal/`, and `docs/ai-models.md` is a
deliberate speed bump on the changes most likely to hurt users — keep it.

## 3. Conventions

- Audit reports are append-only: never rewrite a prior report; supersede it with
  a new one that links back.
- The awareness-not-safety doctrine (`docs/safety-framing.md`) and the legal
  documents under `legal/` must not be edited without explicit owner approval
  (see root `CLAUDE.md`).

## Why not "lock" files?

A claim that a file is "locked" implies an enforcement the repository does not
have and cannot provide. Overstating protection is worse than none, because it
invites misplaced trust. Use review controls, and describe them accurately.
