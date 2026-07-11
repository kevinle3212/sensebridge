# Safety Framing: Awareness, Not Safety

This is the single most important design doctrine in SenseBridge, and the
project's primary liability shield. Read this before touching any spoken
output, alert, UI copy, or onboarding text.

## The rule

**SenseBridge never claims safety.** It never guarantees obstacle detection,
never guarantees crosswalk detection, and never says or implies "safe to
cross." It provides cautious, probabilistic *awareness* — "possible stairs
ahead," "something may be in front of you" — and explicitly, repeatedly tells
users that it is **not a mobility or safety device** and does **not replace**
a cane, a guide dog, or orientation-and-mobility training.

This mirrors how Apple itself disclaims its own detection features, and it is
not just an ethical stance — it is the legal foundation the project's
disclaimers and Terms of Service depend on. See
[`legal/DISCLAIMER.md`](../legal/DISCLAIMER.md) and
[`legal/TERMS_AND_CONDITIONS.md`](../legal/TERMS_AND_CONDITIONS.md).

## Where this framing must appear

- **App copy** — every screen that describes what a feature does.
- **Spoken output** — the actual synthesized speech a user hears, always
  hedged ("looks like," "possible," "might be").
- **Onboarding** — stated plainly before first use, not buried in settings.
- **README and public-facing docs.**
- **Terms of Service.**

If a change adds or edits any of the above, and it doesn't preserve this
hedging, that's a release-blocking defect, not a style nit — see the
accessibility risk table in [`docs/accessibility.md`](accessibility.md), which
lists "over-confident output" as a named risk with the same severity as an
unlabeled control.

## Why this is the hard part, not a footnote

The reliability priority order for this product is unusual: **correct
hedging first, then not crashing, then performance.** A tool that crashes
occasionally is annoying. A tool that confidently says the wrong thing about
the physical world can get someone hurt. Treat any bug that produces
over-confident, safety-adjacent language as the highest-severity class of
bug in the codebase — above crashes, above performance regressions.

## Real-time navigation guidance is explicitly out of scope

The original concept included real-time navigation guidance. This plan
reframes that permanently as *awareness*, never *guidance*, because
navigation guidance is the most dangerous feature shape this project could
build: it invites exactly the false confidence this doctrine exists to
prevent. See [`docs/roadmap.md`](roadmap.md) for what's deliberately not
being built and why.
