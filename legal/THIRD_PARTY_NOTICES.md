# Third-Party Notices

> Informational, not legal advice. Review by qualified counsel before public
> launch.

**Effective date:** 2026-08-01
**Applies to:** the SenseBridge iOS app and the SenseBridge website

SenseBridge itself is licensed under Apache-2.0 (see [`LICENSE`](../LICENSE)).
It also distributes third-party code, and most of those licenses require their
copyright and permission notices to travel with the distribution. This file is
where they travel.

Licenses are verified against the copy actually resolved into the build, not
against what a package's marketing page claims. AGPL and Apple's `apple-amlr`
research-only license are hard blockers for anything shipped — see the
[model-license-audit](../.agents/skills/model-license-audit/SKILL.md) skill and
[`docs/AI-MODELS.md`](../docs/AI-MODELS.md).

## Distributed in the iOS app binary

| Component | Version | License | Copyright |
| --- | --- | --- | --- |
| [sentry-cocoa](https://github.com/getsentry/sentry-cocoa) | 9.24.0 | MIT | Copyright (c) 2015 Sentry |

This is the only third-party code linked into the shipped app. Everything else
in the app is either first-party (`SenseBridgeCore`) or an Apple system
framework covered by the Apple SDK license, which requires no redistribution
notice here.

Note that sentry-cocoa is compiled into the binary whether or not you ever turn
crash reporting on — the *code* ships; the *sending* is what you control. That
is why it is listed unconditionally.

## Distributed in the website's browser bundles

| Component | Version | License | Copyright |
| --- | --- | --- | --- |
| [three.js](https://github.com/mrdoob/three.js) | 0.182.0 | MIT | Copyright © 2010-2025 three.js authors |
| [GSAP](https://gsap.com) | 3.15.x | GreenSock Standard "no charge" license | © GreenSock, Inc. |
| [Lenis](https://github.com/darkroomengineering/lenis) | 1.3.x | MIT | Copyright (c) 2024 darkroom.engineering |
| [@sentry/astro](https://github.com/getsentry/sentry-javascript) | 10.69.x | MIT | Copyright (c) 2023 Functional Software, Inc. dba Sentry |
| [@sentry/browser](https://github.com/getsentry/sentry-javascript) | (transitive) | MIT | Copyright (c) 2019 Functional Software, Inc. dba Sentry |

The two Sentry packages are only present in a build made with
`PUBLIC_SENTRY_DSN` set, and even then are downloaded only by a visitor who has
opted in — see [`legal/PRIVACY_POLICY.md`](PRIVACY_POLICY.md). They are listed
because a configured deployment does distribute them.

**GSAP is not MIT, and that distinction matters.** It ships under GreenSock's
Standard "no charge" license (<https://gsap.com/standard-license>), which
permits use in projects where end users are not charged for access to the GSAP
features. SenseBridge's website is free and charges nothing for anything, so
this condition is met. If a future version of this project ever puts the site or
its animations behind a payment, this license has to be re-examined before that
ships — it is the one dependency here whose terms depend on the business model.

## Build-time only

Astro (MIT, Copyright (c) 2021 Fred K. Schott), React, Sass, and the various
lint, test, and check tools are used to produce the site and are not
redistributed as third-party code in a user-facing artifact. They are recorded
in `website/package.json` and `website/package-lock.json` rather than here.

## The MIT License

Each MIT-licensed component above is distributed under the following terms, with
that component's own copyright notice as listed:

```text
Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
```

## Keeping this accurate

A stale attribution file is a license violation wearing a helpful disguise. Any
change to a shipped dependency updates this file in the same change — the
[dependency-auditor](../.agents/agents/dependency-auditor.md) review path covers
it, and the version numbers above are the ones to reconcile against
`app/SenseBridge.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved`
and `website/package-lock.json`.

## Contact

Questions: <kevinle3212@gmail.com>
