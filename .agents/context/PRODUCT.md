# Product — the marketing website

**Scope: the public marketing site under [`website/`](../../website) only.**
This is the design context the `impeccable` skill loads; it lives here because
impeccable resolves context from the repo root and checks `.agents/context/`
before `docs/`, so this file is what it reads. The **app's** product doc is a
different document with a different scope:
[`docs/PRODUCT.md`](../../docs/PRODUCT.md). Neither supersedes the other — the
app doc owns product strategy, this one owns the website's design brief. See
[`docs/TOOLING.md`](../../docs/TOOLING.md) → "Impeccable project root".

## Register

brand

## Platform

web

## Users

Blind and low-vision people evaluating whether to trust and eventually try
SenseBridge — the same primary audience as the app itself, arriving here
before a build exists. Secondary: sighted family members and accessibility
advocates helping that primary audience evaluate the project on their
behalf.

## Product Purpose

A pre-launch trust-building site for SenseBridge. No downloadable app build
exists yet — `app/` has an early Xcode/Swift scaffold (see
`AGENT-CONTEXT.md`) but nothing distributed to TestFlight or the App Store —
so the site's job is
to explain the project honestly,
demonstrate the accessibility standard the product itself promises, and give
visitors a way to follow progress rather than pretend a download is
available today.

## Positioning

Open-source, on-device, private accessibility — the combination no
competitor occupies, not raw scene-description quality. See
[`docs/PRODUCT.md`](../../docs/PRODUCT.md) for the full wedge.

## Conversion & proof

- Primary and secondary CTA: Follow progress (GitHub repo / watch), with the
  GitHub repo link itself as the fallback for visitors not ready to commit
  to following.
- The line a visitor remembers after 10 seconds: your surroundings never
  leave your phone, and no one can take that away with a policy change.
- Belief ladder: (1) the problem is real — cloud-based accessibility tools
  raise real privacy fears and lock users into one vendor; (2) an
  open-source, on-device, self-hostable approach genuinely solves that,
  not just markets around it; (3) this specific project is credible enough
  to follow before it ships — because it says plainly that it hasn't
  shipped yet.
- Proof on hand: none yet — pre-launch, no testimonials or press. Revisit
  once real blind testers exist (see `docs/PRODUCT.md` success metrics).

## Brand Personality

Trustworthy, plain-spoken, quietly confident. No hype, no urgency
manufactured where none exists — the tone already used in `README.md` and
`docs/PRODUCT.md`.

## Anti-references

Generic SaaS-gradient startup marketing: hero-metric templates, gradient
text, glassmorphism, tiny uppercase eyebrows on every section. This is a
free, no-subscription, pre-launch open-source project — it should not look
or sound like it's selling something.

## Design Principles

Honesty over hype: never imply the app is available today, and never claim
a safety or navigation guarantee (see [`docs/SAFETY-FRAMING.md`](../../docs/SAFETY-FRAMING.md)) —
violating this is worse than any visual defect.

Screen-reader-first is not an afterthought: the site must model the
accessibility standard the product promises, not just describe it.

Restraint over conversion pressure: nothing is being sold, so nothing
should be designed like it is.

Transparency about status: pre-launch is stated plainly, not hidden behind
vague "coming soon" language.

## Accessibility & Inclusion

WCAG 2.2 AA, screen-reader-first. Test with VoiceOver/NVDA directly, not
only automated contrast tooling — the site is itself a demonstration of the
standard the product is built to.
