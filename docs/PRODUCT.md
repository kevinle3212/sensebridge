---
title: Product
---

# Product

Source research: [`planning/SENSEBRIDGE-01-STRATEGY-AND-PRODUCT.md`](planning/SENSEBRIDGE-01-STRATEGY-AND-PRODUCT.md)
and [`planning/SENSEBRIDGE-06-MISCELLANEOUS-AND-REMARKS.md`](planning/SENSEBRIDGE-06-MISCELLANEOUS-AND-REMARKS.md).
This document summarizes the product decisions; see those files for full
reasoning and evidence.

## Mission

SenseBridge is a free, open-source iPhone app that translates a blind or
low-vision person's surroundings into clear spoken information, processing
everything on the device by default so the user's camera and surroundings
never have to leave their phone.

## Vision (long-term, kept honest)

An open, auditable sensory-translation layer that adapts its output to the
person using it: speech for blind users, captions for deaf users, structured
haptics for deaf-blind users, across phones, watches, and glasses. The MVP is
the first true slice of that layer, not a demo of all of it — see
[`ROADMAP.md`](ROADMAP.md) for how the phases build toward this without
committing to it early.

## Why this, why now (the wedge)

You will not out-describe Be My AI or Apple's built-in features on raw
scene-description quality — they have cloud models and large teams. What no
competitor occupies is the combination of:

| Differentiator | Pain point it answers |
| --- | --- |
| Offline by default | Cloud apps raise privacy fears for sensitive documents (mail, medical letters); Be My AI sends images to OpenAI |
| Open-source and auditable | Every leading competitor is closed; users have no recourse if terms change |
| Self-hostable | Trust and continuity for a tool people depend on |
| Configurable AI providers | Competitors hardwire one cloud vendor's model and pricing |
| Unified multi-sense output (eventually) | No product unifies blind, deaf, and deaf-blind support |
| Consent-based, on-device-only face enrollment | "Who is that" without surveillance |
| Cautious LiDAR obstacle awareness | A heads-up without a false sense of safety |
| Free, with no subscription | Cost is a real barrier — only about a third of working-age blind/low-vision US adults are employed (AFB/Cornell) |

Lead with "open, on-device, private accessibility," not the feature list —
the feature list is what every competitor also has.

## Who the MVP is for

**Blind and low-vision people, on iPhone, using on-device processing.** Not
"everyone." Five other personas (deaf user, deaf-blind user, caregiver,
family member enrolled by consent, accessibility advocate) inform the
architecture and are documented in full in
[`planning/SENSEBRIDGE-01-STRATEGY-AND-PRODUCT.md`](planning/SENSEBRIDGE-01-STRATEGY-AND-PRODUCT.md#3-user-personas)
so deferred work has a real home — see
[`ARCHITECTURE.md`](ARCHITECTURE.md) for the `SensingSource`/`RenderTarget`
abstractions that keep that door open without building through it now.

## Success metrics

Vanity metrics (stars, downloads) are not success here.

| Metric | MVP-stage target |
| --- | --- |
| Eyes-free task completion | A blind tester reads a document and identifies common objects unaided |
| Repeat usage by real blind testers | At least 1–2 testers choosing to use it in real life |
| On-device processing share | 100% of MVP features run with no network call |
| VoiceOver navigability | Every screen and control fully operable via VoiceOver |
| Time-to-first-useful-output | Fast enough to feel responsive on the newest iPhone (benchmark on-device) |
| Crash-free sessions | High enough that testers are not abandoning it |

**North-star metric:** number of real-world tasks a blind user completes per
week using SenseBridge without sighted assistance.

## Funding and sustainability

No money is needed to build the MVP, and that is a strength: the
zero-backend, zero-cloud-API architecture has no running costs. Funding is
pursued *after* a working app and real users exist, never as a prerequisite
— building for funders instead of users is the most dangerous funding
mistake a solo project can make.

- **Grants over equity.** Microsoft AI for Accessibility, NSF-adjacent
  accessibility ecosystems (AccessComputing, CREATE), and disability-focused
  foundations reward traction, not ideas — apply once there is a working
  demo and real testers.
- **Community funding.** GitHub Sponsors (zero platform fees) once the repo
  is public; Open Collective with a fiscal sponsor (Software Freedom
  Conservancy, NumFOCUS) if the project outgrows one maintainer.
- **Precedents.** NVDA, OptiKey, and EyeMine sustained themselves as
  open-source assistive tech through donations and grants — usefulness and
  community come first, money follows.
- **If revenue is ever needed:** keep the app and all core features free and
  open; offer optional paid *services* on top (hosted opt-in cloud
  reasoning, paid organizational support). This is Phase 5 territory (see
  [`ROADMAP.md`](ROADMAP.md)), not an MVP consideration.

## Final recommendation (from the strategy review)

Approved, conditional on the scope cut: blind users, iPhone, on-device, two
three-month increments, with the broader vision preserved in the
architecture and explicitly deferred in the roadmap. Probability of shipping
a useful, VoiceOver-accessible, on-device blind-user MVP solo in ~6 months
is estimated at moderate-to-good (60–70%) *if and only if* the scope cut
holds and real testers are involved; probability of the full original
multi-group, multi-device vision shipping solo in that window is near zero.
The single biggest determinant of success is what gets refused, not what
gets built — see the "things not to build" list in
[`planning/SENSEBRIDGE-06-MISCELLANEOUS-AND-REMARKS.md`](planning/SENSEBRIDGE-06-MISCELLANEOUS-AND-REMARKS.md).

---

Need help? See [`SUPPORT.md`](../SUPPORT.md).
