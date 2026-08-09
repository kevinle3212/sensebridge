# Privacy Policy

> This is informational, written to be genuinely readable by screen-reader
> users, and is **not legal advice**. It must be reviewed by qualified counsel
> before public launch — especially before enabling any facial-recognition or
> other biometric feature. Biometric and accessibility law is a fast-moving
> patchwork that varies by jurisdiction.

**Effective date:** 2026-08-01
**Previous version:** 2026-07-09
**Maintainer:** Kevin K. Le, an individual residing in the State of Oregon,
United States of America
**Contact:** <kevinle3212@gmail.com>

For the purposes of the GDPR and the UK GDPR, the maintainer is the **data
controller**. There is no EU or UK representative appointed, because the
processing described below is limited to optional crash reports and does not
meet the threshold in Article 27; if that changes, this section changes with it.

## What changed in this version

The earlier version of this policy said SenseBridge collects no telemetry at
all. That is no longer strictly true, and this update exists to say so plainly
rather than to bury it.

SenseBridge can now send **crash and error reports** — and only crash and error
reports — to Sentry, a third-party error-monitoring service. It is **off until
you turn it on**, in the app and on the website alike. If you never turn it on,
nothing changes for you: the app sends nothing, and the website does not even
download the monitoring code.

Nothing else about how SenseBridge handles your data has changed. Camera,
photo, and audio content is still processed on your device and discarded, and
still never leaves it.

## The short version

SenseBridge processes your camera, photos, and audio **on your device**. There
is no server. Nothing you point the camera at is sent anywhere unless you
explicitly turn on an optional cloud feature yourself.

The one thing that can leave your device is a crash report, and only if you
switch it on. It contains diagnostic information about the failure — never
camera frames, recognized text, audio, or location.

## What SenseBridge does with your data

- **Camera, photo, and microphone input** is processed on-device to produce
  spoken descriptions, read text, or sound alerts, then **discarded**. It is
  not saved or transmitted unless a feature explicitly says otherwise.
- **App preferences** (like verbosity settings) may sync across your own
  devices via your Apple iCloud account, if you have iCloud sync enabled.
  Only preferences sync — never camera, photo, or audio content.
- **Facial recognition (a future, opt-in feature, not in the app yet):** if
  and when this ships, enrolling a face requires your explicit, informed
  consent. Face data would be stored only on your device, encrypted, never
  transmitted, and you would be able to view and delete it at any time. See
  [`docs/PRIVACY.md`](../docs/PRIVACY.md) for the engineering detail.

## Optional crash and error reporting

This is off by default. You choose whether to turn it on, and you can turn it
back off at any time with the same control.

**In the app:** Settings → Diagnostics → "Send crash reports". While it is on, a
crash or a frozen app sends a report containing the stack trace, the exception
type and message, your device model, your iOS version, and the app version.

**On the website:** the switch on the site's own privacy page. While it is on, a
JavaScript error sends the error and its stack, the page address with any query
string removed, and your browser and operating-system version. Until you turn it
on, the monitoring code is never downloaded at all — so this is not a matter of
a disabled feature sitting idle in your browser.

**What is never sent, in either place:** camera frames, photos, recognized text,
audio, depth data, your location, your IP address, your device's name, your name
or email, cookies, or a record of what you did before the failure. Screenshots,
view hierarchies, session recording, performance tracing, and behavioral
analytics are all switched off in code, not merely left unused.

**Who receives it:** Functional Software, Inc. (trading as Sentry), acting as a
processor on the maintainer's behalf, on servers in the United States. Reports
are retained for 90 days and then deleted. The full list of everyone who
processes anything on our behalf is in
[`legal/SUBPROCESSORS.md`](SUBPROCESSORS.md).

**Why we may lawfully do this:** your consent. Under the GDPR that is Article
6(1)(a), and under the ePrivacy Directive the storage of the choice on your own
device is Article 5(3) consent. Under the CCPA/CPRA this is not a sale or a
share of personal information, and it is not used for cross-context behavioral
advertising. A Global Privacy Control signal from your browser is honoured as a
refusal, and it overrides any earlier choice.

**How to withdraw:** switch it off. Withdrawing is exactly as easy as granting,
takes effect immediately, and costs you nothing — no feature of SenseBridge
depends on it.

**Transfers out of the EEA and the UK:** reports reach servers in the United
States under Standard Contractual Clauses, with the UK International Data
Transfer Addendum where the UK GDPR applies. Where a transfer relies on the EU–US
Data Privacy Framework instead, that is noted in
[`legal/SUBPROCESSORS.md`](SUBPROCESSORS.md).

## The website

The SenseBridge website is a static, pre-launch information site. It sets no
cookies, has no accounts, and runs no advertising or analytics. The web host
processes ordinary server request logs — IP address, page requested, timestamp,
user-agent — as is technically necessary to serve the page to you at all.

The site publishes its own full, per-jurisdiction notice at `/privacy`, in
English, Spanish, and Vietnamese. Where a translation and the English text
disagree, the English text governs.

Because the site stores nothing on your device until you answer the crash-report
question, no cookie banner is shown: there is nothing to consent to under
Article 5(3) of the ePrivacy Directive until you act.

## What SenseBridge does not do

- It does not run a server that stores your data.
- It does not sell or share your data — there is no data to sell. We have never
  sold or shared personal information, and we do not use it for targeted
  advertising or for cross-context behavioral advertising.
- It does not collect product analytics, usage telemetry, or session
  recordings. The only thing it can send is the optional crash and error report
  described above, and only after you switch it on.
- It does not use your data to train any machine-learning model.
- It does not profile you, score you, or make any automated decision that
  produces legal or similarly significant effects.
- It does not use cloud AI providers unless you explicitly turn one on
  yourself in settings.

## Biometric information

SenseBridge does not currently collect, capture, store, or use biometric
identifiers or biometric information of any kind.

The camera sees faces because cameras see what is in front of them, but nothing
in the shipping app extracts a face template, a fingerprint, a voiceprint, a
retina or iris scan, or a scan of hand or face geometry, and nothing is retained
after a frame is processed.

If the opt-in facial-recognition feature described above is ever built, it will
be governed by a separate, explicit, written consent flow designed against the
strictest of the biometric-privacy laws that apply — including the **Illinois
Biometric Information Privacy Act (BIPA)**, which carries a private right of
action, **Texas CUBI**, **Washington's HB 1493**, the biometric provisions of
the US state privacy laws listed below, and **Article 9 of the GDPR**. It will
not ship before that flow, its retention-and-destruction schedule, and this
policy are updated together. See
[`docs/PRIVACY.md`](../docs/PRIVACY.md).

## Security

Crash reports travel over TLS and are held by Sentry under its own security
program. Access is limited to the maintainer. There is no SenseBridge server, no
database, and no account system, which is the strongest security property this
project has: most of what could be breached does not exist.

If a breach ever affects data we hold, we will notify affected people and the
relevant supervisory authorities as the applicable law requires — under the GDPR
and UK GDPR that is without undue delay and, where feasible, within 72 hours of
becoming aware. Security reporting is covered by [`SECURITY.md`](../SECURITY.md).

## Retention

- **Camera, photo, audio, and depth input:** processed in memory and discarded.
  Not retained at all.
- **Preferences:** kept on your device (and in your own iCloud, if you enabled
  iCloud sync) until you delete the app or change them.
- **Website choices** (crash-report answer, theme, debug flag): kept in your
  browser's local storage on your own device until you clear it. They are not
  sent anywhere.
- **Crash reports:** 90 days at Sentry, then deleted.

## Your rights

Because there is no server-side account or stored personal data for the MVP,
most data-subject requests (access, deletion, portability) are already
satisfied by the fact that nothing leaves your device.

If you turned on crash reporting, there may be reports held for up to 90 days.
Write to <kevinle3212@gmail.com> to ask what is held, to have it deleted, to
receive a copy, or to object; we aim to answer within 30 days, and within 45
days where a US state law sets that period. Because reports carry no identifier
for you, please say roughly when the failure happened and on what device, or we
may not be able to find them.

We will not discriminate against you for exercising any of these rights, and we
do not charge for a request unless it is manifestly unfounded or excessive.

### If you are in the European Economic Area or the United Kingdom

You have the rights of access, rectification, erasure, restriction, portability,
and objection, and the right to withdraw consent at any time without affecting
processing already carried out. You may complain to your national data
protection authority — in the UK, the Information Commissioner's Office.

### If you are in the United States

Your state may give you rights of access, correction, deletion, portability, and
opt-out. We honour these for every US resident regardless of whether their state
has passed such a law, because the underlying answer is the same everywhere:
almost nothing is held.

This includes, without limitation, the **California** CCPA/CPRA (including your
right to know, delete, correct, and limit use of sensitive personal information,
and your right not to be discriminated against), **Virginia** VCDPA,
**Colorado** CPA, **Connecticut** CTDPA, **Utah** UCPA, **Texas** TDPSA,
**Oregon** OCPA, **Montana** MCDPA, **Florida** FDBR, **Delaware**, **Iowa**,
**Nebraska**, **New Hampshire**, **New Jersey**, **Tennessee**, **Minnesota**,
**Maryland**, **Indiana**, **Kentucky**, and **Rhode Island**, together with the
**Washington My Health My Data Act** and **Nevada SB 370** for consumer health
data — of which SenseBridge collects none.

We recognise **Global Privacy Control** as a valid opt-out signal. We have no
"sale" or "share" to opt out of, and no targeted advertising, but the signal is
honoured as a refusal of crash reporting regardless.

You may use an authorised agent to make a request. We may ask you to verify the
request to the extent the applicable law allows.

### If you are elsewhere

We aim to honour equivalent rights under **Canada's PIPEDA** and **Quebec's Law
25**, **Brazil's LGPD**, **Australia's Privacy Act 1988**, **Japan's APPI**,
**South Korea's PIPA**, **South Africa's POPIA**, **India's DPDP Act 2023**, and
**Switzerland's revised FADP**, at the same address and on the same timelines.

## Children's privacy

SenseBridge is not directed at children and is not designed to collect
personal information from anyone, regardless of age, given its on-device,
no-account design. Crash reporting is off by default and carries no identifier,
so no child's personal information is knowingly collected.

We do not knowingly collect personal information from a child under 13 in the
United States (COPPA), under 16 in the EEA or as your Member State provides, or
under the age your own law sets. If you believe a child's information has
somehow reached us, write to <kevinle3212@gmail.com> and we will delete it.

We do not sell or share the personal information of anyone under 16, because we
do not sell or share anyone's.

## Do Not Track

There is no industry consensus on how to respond to a Do Not Track browser
signal, so we do not respond to it specifically. It does not matter here: we run
no tracking to disable. We do honour Global Privacy Control, as described above.

## Changes to this policy

Updates will be noted in [`CHANGELOG.md`](../CHANGELOG.md) and reflected here
with a new effective date. Where a change materially reduces your protection, we
will say so at the top of this document rather than letting it pass silently.

## Contact

Privacy questions: <kevinle3212@gmail.com>
