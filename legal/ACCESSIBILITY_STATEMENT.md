# Accessibility Statement

> Informational, not legal advice. Review by qualified counsel before public
> launch.

**Effective date:** 2026-08-01
**Applies to:** the SenseBridge website (<https://github.com/kevinle3212/sensebridge>)
and the SenseBridge iOS app
**Contact:** <kevinle3212@gmail.com>
**Assessment basis:** self-assessment by the maintainer, supported by the
automated gates described below
**Published version:** this statement is also published on the site itself at
`/accessibility`, in English, Spanish, and Vietnamese — the European
Accessibility Act and EN 301 549 require the statement and its feedback route
to be reachable from the service, not only from this repository. The two are
kept consistent, and neither may claim a check the other does not.

SenseBridge is an accessibility product. That raises the standard it should be
held to rather than lowering it, and it makes an overclaim here worse than an
overclaim anywhere else: the people most harmed by a false accessibility promise
are exactly the people this project is for.

So this statement is written to be checkable. Where something is verified, it
says what verified it. Where something is not, it says so.

## The standards we build against

- **WCAG 2.2 Level AA** — the binding baseline for both surfaces. Every gate
  described below enforces it.
- **WCAG 2.2 Level AAA** — an aspiration, met in specific places and not
  claimed as conformance. See "Where we exceed Level AA" and "Why we do not
  claim Level AAA" below. The W3C itself advises that Level AAA conformance is
  not achievable for entire sites as a general policy, and we agree.
- **EN 301 549 v3.2.1** — the European harmonised standard, whose web and
  software clauses incorporate WCAG 2.2 Level AA. This is the standard the
  European Accessibility Act is assessed against.
- **Apple's Human Interface Guidelines** for the iOS app, where the platform's
  own accessibility conventions outrank generic web guidance.

Contributor-facing detail is in
[`docs/ACCESSIBILITY.md`](../docs/ACCESSIBILITY.md).

## The laws this statement is written for

We do not assert which of these apply to a free, pre-launch, solo-maintained
project — that is a question for counsel, and it changes with distribution and
with where a user is. We build to the strictest reading rather than argue about
scope:

- **United States — Americans with Disabilities Act (ADA).** Titles II and III.
  The Department of Justice's 2024 web rule (28 C.F.R. Part 35) adopts WCAG 2.1
  Level AA for state and local government entities; courts have widely treated
  WCAG Level AA as the practical benchmark for public accommodations. We build
  to WCAG 2.2 Level AA, which is a superset of 2.1 Level AA.
- **United States — Section 508 of the Rehabilitation Act** (36 C.F.R. Part
  1194), which incorporates WCAG 2.0 Level AA as a floor, and **Section 504**.
- **United States — the Twenty-First Century Communications and Video
  Accessibility Act (CVAA)** where it reaches app functionality.
- **European Union — the European Accessibility Act**, Directive (EU) 2019/882,
  applicable from 28 June 2025, together with its national implementations and
  the **Web Accessibility Directive** (EU) 2016/2102 where a public-sector body
  is involved.
- **United Kingdom — the Equality Act 2010** and the Public Sector Bodies
  (Websites and Mobile Applications) Accessibility Regulations 2018.
- **Canada — the Accessible Canada Act** and provincial regimes including the
  AODA.
- **Australia — the Disability Discrimination Act 1992.**

Nothing in this statement limits any right you have under any of them.

## Conformance status

**The website: partially conformant with WCAG 2.2 Level AA and EN 301 549
v3.2.1**, in the specific sense that automated testing finds no violations and
no manual audit has been performed by an independent party. "Partially
conformant" is used here in the sense the EN 301 549 and W3C statement templates
use it, and the gap is described under "What has not been done".

What is actually verified, on every change:

- Every published page is checked with **pa11y** against the **WCAG2AA**
  ruleset, and with **axe-core**, in a browser forced into
  `prefers-reduced-motion: reduce`. The gate fails the build on a single error.
  Results axe reports as *needs review* rather than as violations — it declines
  to compute a ratio behind this site's gradient link underline — are surfaced
  as warnings rather than silently promoted to errors or silently dropped.
- Every published page is additionally checked against the **WCAG2AAA** ruleset.
  That check reports rather than blocks — see "Why we do not claim Level AAA".
- Every colour token that carries text is checked against the **7:1** ratio of
  WCAG 2.2 **1.4.6**, computed against the darkest background it is ever placed
  on. This is a separate gate (`npm run check:contrast`) precisely because the
  page-level tools above cannot prove that ratio through a gradient: the claim
  under "Where we exceed Level AA" would otherwise be unenforced.
- Every page is a complete, readable static document **with JavaScript
  disabled**. Motion is opt-in via `prefers-reduced-motion` and instantiates
  nothing when reduced motion is requested.
- The site is published in English, Spanish, and Vietnamese, with the language
  switcher built from native `<details>`/`<summary>` so it is keyboard-operable
  and screen-reader-labeled without ARIA state management.
- A narrated audio version of the main page content is offered.
- The production Content-Security-Policy is exercised against the built site, so
  a policy that silently strips a stylesheet cannot ship and leave the site
  unstyled and unreadable.

**The iOS app: conformance not yet claimed.** The app is pre-launch and has not
been publicly released. Its internal gate is stricter than a percentage —
**zero unlabeled interactive elements on every screen**, with a VoiceOver pass
required on any changed UI before a change can merge — but a gate is not a
conformance audit, and this statement will not pretend otherwise.

## Where we exceed Level AA

Named individually rather than claimed as a level, because a AAA success
criterion met on one page is not AAA conformance:

- **1.4.6 Contrast (Enhanced)** — the site's text palette is built to the 7:1
  ratio, not the 4.5:1 Level AA floor, and holds it against the worst
  background each colour is placed on rather than only against the page
  background. Enforced on every change by the contrast gate above.
- **2.2.3 No Timing** — nothing on the site is time-limited.
- **2.3.2 Three Flashes** — nothing flashes at all.
- **2.4.9 Link Purpose (Link Only)** — links are written to make sense read out
  of context, which is how a screen-reader rotor presents them.
- **3.3.5 Help** — the accessibility contact route is on every page, not buried
  in a support section.
- **1.4.8 Visual Presentation**, in part — text is not justified, line length is
  constrained, and colours are author-set without forcing a background the
  reader cannot override.

## Why we do not claim Level AAA

Claiming Level AAA site-wide would be an overclaim of exactly the kind this
statement exists to avoid. Specifically:

- **1.2.6 Sign Language (Prerecorded)** would require a signed version of the
  narrated audio, which does not exist.
- **1.4.9 Images of Text (No Exception)** and **3.1.3–3.1.6** (unusual words,
  abbreviations, reading level, pronunciation) impose obligations on translated
  content that a three-locale site maintained by one person cannot honestly
  guarantee on every change.
- **2.4.12 Focus Not Obscured (Enhanced)** and **2.5.5 Target Size (Enhanced)**
  are met in most places but have not been verified exhaustively across all
  three locales and all viewport sizes.

Where a AAA criterion is cheap and durable, we take it. Where meeting it would
require a promise we cannot keep on every change, we say so here instead of
claiming it.

## What has not been done

State this plainly, because the gap is the useful part of an accessibility
statement:

- **No independent third-party accessibility audit** has been carried out on
  either surface.
- **No formal validation with blind and low-vision testers** has been completed.
  Automated checks cannot tell you whether a screen makes sense to someone
  navigating it by ear; only those users can. This is the project's largest
  open accessibility risk and it is tracked as such.
- **Automated testing has limits.** pa11y, axe-core, and similar tools catch a
  minority of real barriers — commonly cited as roughly a third. A page can pass
  every automated rule and still be confusing, mislabeled, or unusable in
  practice.
- **No VPAT or Accessibility Conformance Report** has been produced.

A green pipeline is not validation by the people this is for, and this project
does not let one stand in for the other.

## Known limitations

- **Third-party and platform content.** Where iOS system controls or a
  third-party component appear, their accessibility is governed by their
  provider.
- **The narrated audio** is generated from the page text at build time. If page
  text changes and the audio has not been regenerated, a build-time check fails
  rather than silently serving stale narration — but the narration covers the
  main content region only, not navigation or footer.
- **Visual design under forced high contrast** has been implemented against the
  platform's increased-contrast settings but has not been audited by an outside
  party.
- **Translated content** is reviewed for accuracy of meaning, not for reading
  level, and the Spanish and Vietnamese pages have not been tested with a screen
  reader in those languages.

## Disproportionate burden

We claim no disproportionate-burden exemption under the European Accessibility
Act or any other regime. Nothing in the list above is withheld on cost grounds;
each item is either not yet done or not yet verified, and each is tracked in
[`TODO.md`](../TODO.md) rather than excused here.

## Feedback, and how to report a barrier

If any part of SenseBridge is not usable for you, that is a defect, and it is
treated with the same priority as a crash — not as a feature request.

Write to <kevinle3212@gmail.com>. Please describe what you were trying to do,
what assistive technology you were using (including version, if you know it),
and what happened instead. You do not need to know the technical cause, and you
do not need to phrase it in accessibility terminology.

We aim to acknowledge reports within 5 working days and to give a substantive
answer, including a fix or a timeline, within 30 days. This is the feedback
mechanism the European Accessibility Act and EN 301 549 require a statement to
name, and it is monitored by the maintainer directly.

If you would rather report it publicly, the project's issue tracker is at
<https://github.com/kevinle3212/sensebridge>.

## Enforcement, and what to do if we do not fix it

This project is pre-launch, solo-maintained, and free. There is no formal
enforcement body engaged with it. If we do not resolve your report, you keep
every escalation route the law where you live gives you, including:

- **European Union** — the market-surveillance or enforcement authority
  designated by your Member State under the European Accessibility Act.
- **United Kingdom** — the Equality Advisory and Support Service, and the
  enforcement route under the Equality Act 2010.
- **United States** — a complaint to the Department of Justice under the ADA, or
  to the relevant federal agency under Section 508, and any right of action your
  state law gives you.
- **Canada** — the Accessibility Commissioner under the Accessible Canada Act,
  or the applicable provincial body.
- **Australia** — the Australian Human Rights Commission.

Nothing in this statement, and nothing in
[`legal/TERMS_AND_CONDITIONS.md`](TERMS_AND_CONDITIONS.md), limits any of those
routes.

## How this statement is maintained

It is reviewed on every change that touches an accessibility gate, and at
minimum whenever the effective date above is more than twelve months old. It was
last reviewed on the effective date at the top of this page.

## Contact

Accessibility questions and barrier reports: <kevinle3212@gmail.com>
