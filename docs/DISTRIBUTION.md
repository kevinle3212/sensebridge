# Distribution

*(Named "Distribution," not "Deployment" — there is no server to deploy. See
[ARCHITECTURE.md](ARCHITECTURE.md#backend-architecture-there-is-none-and-that-is-correct).)*

## What's free

- **Development and personal-device testing are free.** Building and running
  SenseBridge on your own iPhone with a personal Apple ID costs nothing.
- **CI (GitHub Actions)** is free for a public repository: build, test, and
  lint run on every push and pull request. See
  [`.github/workflows/ci.yml`](../.github/workflows/ci.yml).

## The one unavoidable cost: the Apple Developer Program

Getting the app onto **other people's phones** — TestFlight beta testing or
the App Store — requires enrolling in the **Apple Developer Program**, a
paid annual membership. This is the one place the zero-cost constraint meets
reality, and it collides with it right at the point where real-user
validation happens, which is the most important step in this project.
Verify the current annual cost yourself before budgeting for it; it changes.

Options, in order of preference:

1. **Check for a fee waiver.** Apple has had nonprofit, open-source, or
   accessibility program fee-waiver terms in the past — verify current
   eligibility and terms before assuming one applies.
2. **Budget for the Developer Program at beta.** Decide this before you need
   real testers (see the roadmap's month-four checkpoint in
   [ROADMAP.md](ROADMAP.md)) — don't let it surprise you late.
3. **Limit early testing to your own device and source builds** until either
   of the above is resolved. This is a real fallback, not just a stopgap:
   getting the document-reading feature right on your own device, validated
   by you, is still a genuine milestone.

## Recruiting real testers

TestFlight distribution is necessary but not sufficient — you also need
actual blind testers willing to use it. Resolve this early and treat it as
on the critical path, not a nicety: NFB or ACB local chapters, accessibility
Discord/forum communities, and GitHub's accessibility open-source initiatives
are the likely channels. One real user telling you the app helped them is
worth more to a solo project's survival than additional polish — prioritize
getting that signal over refining a feature no one has tried yet.

## Signing and CI

Signing keys and certificates are the crown jewels of the release pipeline.
Never commit them to the repository. Keep them in GitHub Actions repository
secrets (for CI-driven TestFlight uploads, once that's set up) or in local
secure storage for manual builds. There is no automated TestFlight upload
workflow yet — see [`docs/ROADMAP.md`](ROADMAP.md) for when that becomes
relevant; adding one before there's a Developer Program account to use it
with would be premature.

When that changes: enroll in the Apple Developer Program, set the real
bundle ID and `DEVELOPMENT_TEAM` in `app/project.yml`, and generate signing
certificates/provisioning profiles for the team. Only then does an **App
Store Connect API key** (Users and Access → Integrations → App Store Connect
API in App Store Connect) become relevant, for CI-driven TestFlight
uploads — store it in GitHub Actions repository secrets, never in the repo.
No such CI workflow exists yet.

---

Need help? See [`SUPPORT.md`](../SUPPORT.md).
