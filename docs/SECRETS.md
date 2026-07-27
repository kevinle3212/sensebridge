---
title: Secrets and Tokens
---

# Secrets and tokens

Every credential this repository needs, where it is configured, and what breaks
without it. Nothing here is required to *build or run the app* — SenseBridge is
serverless and on-device, so the shipped product holds no keys at all (see
[`docs/PRIVACY.md`](PRIVACY.md)). Everything below serves CI, deployment, or
local developer tooling.

**Ground rules.** Secrets live in GitHub Actions secrets (CI), your account
settings (personal credentials), or an untracked local `.env` (developer
tooling). Never in the repository, a log, a built artifact, or a client bundle.
Three independent scanners enforce this — `gitleaks` and
`tools/check-sensitive-files.mjs` pre-commit, TruffleHog and GitGuardian in CI
(see [`docs/TOOLING.md`](TOOLING.md)).

---

## 1. Repository secrets (GitHub Actions)

Set at **Settings → Secrets and variables → Actions → New repository secret**.

| Secret | Used by | Required? | Effect if unset |
| --- | --- | --- | --- |
| `ANTHROPIC_API_KEY` | `claude.yml`, `claude-code-review.yml` | Only to re-enable those workflows | Nothing today — **both workflows are intentionally paused** (`on: workflow_dispatch`, disabled 2026-07-17 pending API budget) |
| `RAILWAY_TOKEN` | `railway-preview-deploy.yml` | For preview deploys | The preview deploy job fails. Production is unaffected — it deploys via Railway's own GitHub App watching `main`, with no Actions involvement |
| `GITGUARDIAN_API_KEY` | `security.yml` → `ggshield` job | For the GitGuardian scan | The job **fails closed** (`exit_zero: false`). This is the one unset secret that actively breaks a check |
| `GITHUB_TOKEN` | `dependabot-automerge.yml`, `github-models.yml`, `wiki-sync.yml`, `pages.yml` | **Never set manually** | n/a — injected automatically by Actions per run |

### Notes per secret

- **`GITHUB_TOKEN` is not yours to create.** GitHub mints it per workflow run.
  Scope is granted through each workflow's `permissions:` block, not through
  settings — `wiki-sync.yml` needs `contents: write`, `github-models.yml` needs
  `models: read`, `pages.yml` needs `pages: write` + `id-token: write`. Widen a
  `permissions:` block only with a reason.
- **`RAILWAY_TOKEN` must be a project token, not a personal account token.**
  Railway dashboard → Project → Settings → Tokens → Create Token; scope it to
  the `preview` environment if offered. A personal token grants far more than
  this workflow needs.
- **`GITGUARDIAN_API_KEY`** comes from the GitGuardian dashboard → API →
  Personal access tokens, with the `scan` scope.
- **`ANTHROPIC_API_KEY`** from <https://console.anthropic.com>. Re-enabling
  those workflows also means restoring the commented-out triggers in each file,
  not just setting the secret.

---

## 2. Account-level settings (not repository secrets)

These live on your GitHub account or your machine, so they follow *you* across
repositories and are invisible to anyone cloning this one.

### Verified commits (signing key)

**This repository's commits are signed with a local signing key** (confirmed by
the owner, 2026-07-25). That is a *key*, not a token: there is nothing to add to
repository secrets, CI never sees it, and no workflow depends on it. It is
listed here because it is a credential the project relies on and it lives
entirely in account and machine settings, where nothing in the repository would
otherwise record it.

- **Where:** GitHub → Settings → **SSH and GPG keys** → the public key is
  registered as a *signing* key. SSH signing keys and GPG keys are separate
  lists on that page; whichever list holds the key must match `gpg.format`
  below, or GitHub shows the commit as `Unverified`.
- **Locally:** `user.signingkey`, `gpg.format` (`ssh` or `openpgp`), and
  `commit.gpgsign = true`. To check the current setup:

  ```bash
  git config --get user.signingkey
  git config --get gpg.format      # "ssh", or empty/"openpgp" for GPG
  git config --get commit.gpgsign  # should be "true"
  ```

- **The private key never leaves your machine.** Treat it like an SSH private
  key: never commit it, never paste it, and never add it to a secret store for
  CI. Losing control of it means someone else can produce commits that GitHub
  marks as verified under your name.
- **Vigilant mode: enabled** (confirmed by the owner, 2026-07-25). GitHub's
  "Flag unsigned commits as unverified" setting is on, so any commit attributed
  to this account that is *not* signed is displayed `Unverified` instead of
  shown neutrally. Without it, an unsigned commit forged under this name would
  be indistinguishable from a genuine one at a glance.
  Practical consequence worth knowing before it surprises someone: this applies
  to **every** commit attributed to the account, including ones authored through
  the GitHub web UI or by tooling that does not sign. If an `Unverified` badge
  appears on a commit you made, the signing setup has stopped working — treat
  it as a real signal, not noise, and re-check the three `git config` values
  above.
- **Losing the key** costs nothing already merged — existing commits keep their
  signatures. Generate a new key, register it, and remove the old one; only
  revoke the old key if you believe it was compromised, since revoking marks
  previously signed commits as unverified.

> **Note:** not used here — a bot or fine-grained PAT with
> `Contents: read and write` also yields verified commits, but only for commits
> created *through the GitHub API* (which signs server-side). This project does
> not sign that way — the key above covers commits pushed from the machine.

### Other account-scoped credentials

| Credential | Where | Purpose | Status |
| --- | --- | --- | --- |
| `gh auth token` | `gh auth login` on your machine | Reused by the user-global `github` MCP server | Per-developer; unrelated to CI |
| `PERPLEXITY_API_KEY` | user-global MCP config | Optional research MCP — every query is egress | Not installed |
| `CONTEXT7_API_KEY` | user-global MCP config | Optional; only raises a rate limit (server works unauthenticated) | Installed unauthenticated |
| `APIFY_API_TOKEN`, `GOOGLE_AI_API_KEY` | user-global | Would activate two social-media skills | Deliberately unset — leave inert |

Never register any of these at project scope; see
[`docs/TOOLING.md`](TOOLING.md) for the reasoning.

---

## 3. Local developer environment

| Variable | File | Purpose |
| --- | --- | --- |
| `ELEVENLABS_API_KEY` | `website/.env` (untracked) | Only for `npm run generate:audio`, which regenerates the narration audio. Scope it to text-to-speech only |
| `ELEVENLABS_VOICE_ID` | `website/.env` | Optional override (default: `eLDc7xhWxG2FElT3kUTj`, the owner-approved "Janet" voice) |
| `ELEVENLABS_MODEL_ID` | `website/.env` | Optional override (default: `eleven_turbo_v2_5`) |

Copy
[`website/.env.example`](https://github.com/kevinle3212/sensebridge/blob/main/website/.env.example)
to `website/.env` and fill it in — into `.env`, never into the tracked
`.env.example`. This key is **never** needed by CI and never deployed:
narration is generated locally and the resulting audio is committed.
`npm run check:audio` runs in CI with no key and exits 0 when narration is
absent.

Quota, cost per regeneration, the voice-ID pin, and the free-plan
commercial-licensing constraint are documented in
[`website/README.md`](https://github.com/kevinle3212/sensebridge/blob/main/website/README.md)
→ "Cost, quota, and licensing".

---

## 4. Adding a new secret

1. Prefer not to. A new credential is new attack surface and a new rotation
   obligation — confirm the work cannot be done without egress first.
2. Add it to the correct scope (repository secret for CI; `.env` for local
   tooling), never to both.
3. Document it in the right table above **in the same change**, including what
   breaks when it is missing.
4. If it is consumed by a workflow, make the failure mode explicit — fail
   closed for anything security-relevant.
5. If it involves data leaving the device, it also needs a
   [`docs/PRIVACY.md`](PRIVACY.md) update and explicit, revocable user consent.

## 5. Rotation and exposure

- Rotate immediately if a key is pasted into an issue, a log, a screenshot, or
  any commit — assume public the moment it lands, even if the commit is
  amended, force-pushed, or deleted. Git history and CI logs both persist.
- Rotate at the provider first, then update the GitHub secret; the old value
  stays valid until revoked upstream.
- Report suspected exposure per
  [`SECURITY.md`](https://github.com/kevinle3212/sensebridge/blob/main/SECURITY.md).
- Run `node tools/check-sensitive-files.mjs` before publishing any change that
  touches signing or credential material.

---

Need help? See
[`SUPPORT.md`](https://github.com/kevinle3212/sensebridge/blob/main/SUPPORT.md).
