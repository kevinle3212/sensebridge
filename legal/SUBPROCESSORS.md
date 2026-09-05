# Subprocessors

> Informational, not legal advice. Review by qualified counsel before public
> launch.

**Effective date:** 2026-08-12
**Maintainer:** Kevin K. Le
**Contact:** <kevinle3212@gmail.com>

This page lists every third party that processes anything on SenseBridge's
behalf. It exists because the honest answer to "who else can see this?" should
be a list you can read, not a sentence promising there isn't one.

For most SenseBridge users, **this list is empty in practice.** The app is
serverless and processes camera, audio, and depth data entirely on your device.
Nothing below receives that content, ever — including the reasoning backends
below, which can receive recognized object labels only, and only if you turn
one on. What follows is the complete set of parties involved in the narrow
paths that do leave a device — a crash report you switched on, a Local or
Cloud reasoning backend you turned on, or a web page you requested.

## The app

| Party | What they receive | Where | Retention | When |
| --- | --- | --- | --- | --- |
| Functional Software, Inc. (Sentry) | Crash and error reports: stack trace, exception type and message, device model, OS version, app version | United States | 90 days | Only while you have Settings → Diagnostics → "Send crash reports" switched on. Off by default |
| Apple Inc. | App distribution, and — if *you* enable iCloud sync — your app preferences | Per Apple's own infrastructure | Per Apple's terms | Distribution always; preference sync only if you enable iCloud |

Apple is listed for completeness rather than as a subprocessor engaged by this
project: the relationship is between you and Apple under Apple's own terms, and
the maintainer neither controls it nor receives data through it.

**Nobody receives camera frames, photos, raw audio, depth data, or
location.** There is no path in the software that would allow it. The one
exception is recognized object labels, which reach a reasoning backend only
if you explicitly opt into one — see below.

## Optional Local and Cloud reasoning (opt-in, off by default)

| Party | What they receive | Where | Retention | When |
| --- | --- | --- | --- | --- |
| Anthropic PBC | Recognized object labels only | Per Anthropic's own infrastructure | Per Anthropic's own retention policy | Only if *you* switch Settings → Reasoning to Cloud, select Anthropic, and supply your own API key |
| OpenAI, L.L.C. | Recognized object labels only | Per OpenAI's own infrastructure | Per OpenAI's own retention policy | Only if *you* switch Settings → Reasoning to Cloud, select OpenAI, and supply your own API key |
| NVIDIA Corporation (NIM) | Recognized object labels only | Per NVIDIA's own infrastructure | Per NVIDIA's own retention policy | Only if *you* switch Settings → Reasoning to Cloud, select NVIDIA NIM, and supply your own API key |
| Whatever destination you configure | Recognized object labels only | Wherever you pointed it | Whatever that destination does | Only if *you* switch Settings → Reasoning to Local and enter an endpoint yourself |

Anthropic, OpenAI, and NVIDIA are listed for completeness rather than as
subprocessors engaged by this project: each is bring-your-own-key. You call
that provider directly with your own account and API key; the maintainer
never receives, forwards, or has visibility into that traffic, and is not a
party to your relationship with the provider. The Local row is not a named
party at all — it is entirely the destination you yourself typed in, and the
maintainer has no relationship with it whatsoever.

**Nobody receives camera frames, photos, raw audio, depth data, or
location through either reasoning path.** Only recognized object labels can
leave, and only after you explicitly opt in.

## The website

| Party | What they receive | Where | Retention | When |
| --- | --- | --- | --- | --- |
| Vercel Inc. | Ordinary web server request logs: IP address, page requested, timestamp, user-agent | United States | Per Vercel's retention policy | Every page request — this is what serving a page requires |
| Functional Software, Inc. (Sentry) | JavaScript errors: message, stack, page path with query string removed, browser and OS version | United States | 90 days | Only after you opt in on `/privacy`. Until then the monitoring code is never downloaded |

Vercel is named because it is where this project publishes. The repository also
documents a self-hosted container deployment; anyone running their own copy
substitutes their own host here, and this list describes the official site only.

## Build-time only, never in a user's hands

These are used to produce the site, not to run it. They never receive anything
about a visitor or a user.

| Party | Purpose |
| --- | --- |
| ElevenLabs, Inc. | Generates the narration audio file from the site's own page text. Run manually by the maintainer; the resulting `.mp3` is committed and served as a static file |
| GitHub, Inc. | Source hosting and continuous integration |

## International transfers

The processors above are United States entities. Where the GDPR or the UK GDPR
applies, transfers rely on Standard Contractual Clauses, with the UK
International Data Transfer Addendum for UK transfers.

This does not cover the optional Local or Cloud reasoning paths above: those
are transfers you make yourself, directly to a destination you chose, under
that destination's own terms. The maintainer is not a party to them and they
are not covered by these clauses.

## Changes to this list

Adding a subprocessor is a change to what leaves a device, so it is treated as a
change to the privacy promise rather than as an implementation detail. Any
addition is reflected here and in
[`legal/PRIVACY_POLICY.md`](PRIVACY_POLICY.md) in the same change, and noted in
[`CHANGELOG.md`](../CHANGELOG.md).

## Contact

Questions: <kevinle3212@gmail.com>
