# Privacy Policy

> This is informational, written to be genuinely readable by screen-reader
> users, and is **not legal advice**. It must be reviewed by qualified counsel
> before public launch — especially before enabling any facial-recognition or
> other biometric feature. Biometric and accessibility law is a fast-moving
> patchwork that varies by jurisdiction.

**Effective date:** 2026-07-09
**Maintainer:** Kevin Khanh Le
**Contact:** kevinle3212@gmail.com

## The short version

SenseBridge processes your camera, photos, and audio **on your device**. There
is no server. Nothing you point the camera at is sent anywhere unless you
explicitly turn on an optional cloud feature yourself.

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
  [`docs/privacy.md`](docs/privacy.md) for the engineering detail.

## What SenseBridge does not do

- It does not run a server that stores your data.
- It does not sell or share your data — there is no data to sell.
- It does not collect analytics or telemetry by default.
- It does not use cloud AI providers unless you explicitly turn one on
  yourself in settings.

## If you turn on an optional cloud AI provider

Some future version may let you optionally connect your own account with a
third-party AI provider. If you do this: SenseBridge tells you clearly what
would be sent and to whom, it stays off unless you turn it on, and any
credential you provide is stored securely on your device, not on any
SenseBridge server (there isn't one).

## Your rights

Because there is no server-side account or stored personal data for the MVP,
most data-subject requests (access, deletion, portability) are already
satisfied by the fact that nothing leaves your device. If a future feature
changes this, this policy will be updated first, and this section will list
concrete steps to exercise your rights.

## Children's privacy

SenseBridge is not directed at children and is not designed to collect
personal information from anyone, regardless of age, given its on-device,
no-account design.

## Changes to this policy

Updates will be noted in [`CHANGELOG.md`](../CHANGELOG.md) and reflected here
with a new effective date.

## Contact

Privacy questions: kevinle3212@gmail.com
