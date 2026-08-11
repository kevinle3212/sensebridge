---
title: Privacy (Engineering Doctrine)
---

# Privacy (Engineering Doctrine)

This is the engineering-facing description of SenseBridge's data handling. For
the legal-facing version, see
[`legal/PRIVACY_POLICY.md`](https://github.com/kevinle3212/sensebridge/blob/main/legal/PRIVACY_POLICY.md)
(informational, requires attorney review before public launch).

## The core guarantee: no server, nothing to breach

SenseBridge's MVP has no backend and no central data store. This is an
architectural fact, not a policy promise — see
[`docs/ARCHITECTURE.md`](ARCHITECTURE.md#backend-architecture-there-is-none-and-that-is-correct). Most classic
privacy attack surfaces (server breach, cross-user data leakage, third-party
data brokering) simply do not exist because there is no server for them to
exist on.

## What happens to user content

- Images and recognized text are **processed and discarded**, not persisted
  without a specific reason the user can see.
- **Never logged.** See the logging rules in
  [`docs/ARCHITECTURE.md`](ARCHITECTURE.md) — no recognized text, images, or
  audio ever goes into application logs, only events and states.
- **Optional settings sync** (iCloud) carries only preferences — never
  content — and rides on Apple's iCloud security model rather than a
  project-run service.
- **Hands-free awareness holds the camera open continuously** for as long as
  the user leaves it running, which is a longer exposure than the one-shot
  screens — but the same guarantee applies unchanged: frames are classified
  on-device by Vision, reduced to labels and a distance, and discarded. No
  frame is written to disk, and none reaches the network. Scene composition
  runs on Apple's on-device model; no prompt or label leaves the device.
- **The app declares the `audio` background mode.** It exists solely so the
  announcement that hands-free awareness *stopped* is audible after the app
  leaves the screen. iOS revokes camera access on backgrounding regardless, so
  this grants no ability to observe surroundings in the background.
- **Sound Alerts is one-shot, like Reading/Identify/Describe, not continuous
  like hands-free awareness.** One tap records a few seconds of audio, held
  only in memory and a temporary file deleted before the capture call
  returns. Both the built-in and bundled classifiers run on that same
  in-memory data on-device; no audio is ever written to durable storage or
  leaves the device.

## Biometric data (facial enrollment — deferred, designed now)

Facial recognition is not in the MVP, but because getting this wrong later is
expensive, the storage model is designed now:

- Face embeddings live **only on the device**, in an encrypted store
  (Keychain-protected keys, data-protection classes requiring device unlock).
- Embeddings **never leave the device** and are **explicitly excluded from
  any sync** by default.
- The user can **view and delete** enrolled data at any time.
- Only **consent-enrolled** people are matched; everyone else is rendered as
  "person." No public or open-ended recognition, ever.

This design is deliberately both the ethical choice and the legally safest
one — biometric law (Illinois BIPA, Texas CUBI, GDPR Article 9, CCPA/CPRA
among others) is a real, fast-moving exposure. See
[`legal/PRIVACY_POLICY.md`](https://github.com/kevinle3212/sensebridge/blob/main/legal/PRIVACY_POLICY.md)
for the full legal notes. **None of this is legal advice — get counsel before
shipping any facial-enrollment feature.**

## Crash reporting (opt-in, off by default)

Added 2026-07-31 by owner decision, deliberately reversing this project's
earlier "no crash reporting, on doctrine" position. It is the **only** thing in
SenseBridge that can send anything off the device, and it is built so that it
cannot happen by accident.

**Two independent gates, both of which must pass:**

1. A DSN was configured at build time (`app/Config/Sentry.local.xcconfig`,
   gitignored). A fresh clone has none, so a contributor's build reports
   nowhere no matter what they tap.
2. The user switched on **Settings → Diagnostics → Send crash reports**, which
   defaults to `false` and stays false through an upgrade — a settings blob
   written before the field existed decodes to `false`, because a missing key
   is silence, not agreement.

**What is sent, when both gates pass:** a crash or main-thread-hang report —
stack frames, exception type and message, device model, OS version, app
version. **What is never sent:** camera frames, recognized text, audio, depth
data, location, IP address, device name, or any breadcrumb trail of what the
user did. Screenshots, view hierarchies, network tracking, performance tracing,
and method swizzling are disabled explicitly rather than left at their
defaults, and `CrashReporting.scrub` strips `user`, `request`, `serverName`,
`breadcrumbs`, the device *name*, and locale/timezone context before anything
leaves. `CrashReportingTests` covers both the consent default and the scrub.

The exception message is **not** scrubbed, because it is what makes a crash
diagnosable. That is only safe because the logging rule above already forbids
recognized text, images, and audio from any message the app constructs. If that
rule is ever relaxed, `CrashReporting.scrub` is where the consequence lands.

Session tracking stays on, which is what produces the crash-free-rate figure.
It sends one event per launch containing no user data — and only ever after the
user has opted in.

Every third party that receives anything, what they get, where it lands, and how
long they keep it is listed in
[`legal/SUBPROCESSORS.md`](https://github.com/kevinle3212/sensebridge/blob/main/legal/SUBPROCESSORS.md).
Adding one is a change to the privacy promise, not an implementation detail, so
it updates that file and the policy in the same change.

## The website

`website/` is a separate surface with its own notice at `/privacy`, published in
English, Spanish, and Vietnamese. Same posture, one step stricter: with no
consent the Sentry SDK is **never downloaded**, because the browser bundle
reaches it only through a dynamic import gated on a stored consent value
(`website/src/scripts/monitoring-consent.ts`). A visitor who has not opted in
pays 431 bytes gzipped for the consent bootstrap and fetches none of the ~27kB
SDK. There is no consent banner, because nothing is stored or sent until the
visitor uses the switch, so there is nothing to ask for on arrival.

A Global Privacy Control signal from the browser is honoured as a hard
override: it outranks a previously stored consent, the switch is not offered,
and the page says why. `website/scripts/check-consent.js` drives a real browser
and asserts all of this against the built site, so the claim is tested rather
than asserted.

## The optional cloud adapter (not built, opt-in when it exists)

If a user ever enables an optional cloud-reasoning provider: explicit opt-in,
clear disclosure of what's sent where, off by default, and any credential the
user supplies is stored in their own Keychain — the project ships no cloud
secrets of its own.

## Secrets

The MVP has essentially no secrets: no backend, no API keys. CI (GitHub
Actions) uses repository secrets only for release-signing credentials, never
committed to the repository.

Sentry adds one real credential and one non-credential, and the difference
matters. A **DSN** is a write-only ingest endpoint: it ships inside the app
bundle and the browser bundle by necessity, and it cannot read anything back
out of a Sentry project — it is kept out of git only so a fork does not report
into this project's issue stream. A **`SENTRY_AUTH_TOKEN`** is a genuine
credential, used at build time to upload source maps; it is environment-only,
never `PUBLIC_`-prefixed, and never committed. Both, and where to obtain each,
are documented in
[`TODO.md`](https://github.com/kevinle3212/sensebridge/blob/main/TODO.md)
under "Sentry — environment variables and how to get each one".

---

Need help? See
[`SUPPORT.md`](https://github.com/kevinle3212/sensebridge/blob/main/SUPPORT.md).
