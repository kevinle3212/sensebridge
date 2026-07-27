---
title: "Safety Framing: Awareness, Not Safety"
---

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
[`legal/DISCLAIMER.md`](https://github.com/kevinle3212/sensebridge/blob/main/legal/DISCLAIMER.md)
and
[`legal/TERMS_AND_CONDITIONS.md`](https://github.com/kevinle3212/sensebridge/blob/main/legal/TERMS_AND_CONDITIONS.md).

## Where this framing must appear

- **App copy** — every screen that describes what a feature does.
- **Spoken output** — the actual synthesized speech a user hears, always
  hedged ("looks like," "possible," "might be").
- **Onboarding** — stated plainly before first use, not buried in settings.
- **README and public-facing docs.**
- **Terms of Service.**

If a change adds or edits any of the above, and it doesn't preserve this
hedging, that's a release-blocking defect, not a style nit — see the
accessibility risk table in [`docs/ACCESSIBILITY.md`](ACCESSIBILITY.md), which
lists "over-confident output" as a named risk with the same severity as an
unlabeled control.

## Why this is the hard part, not a footnote

The reliability priority order for this product is unusual: **correct
hedging first, then not crashing, then performance.** A tool that crashes
occasionally is annoying. A tool that confidently says the wrong thing about
the physical world can get someone hurt. Treat any bug that produces
over-confident, safety-adjacent language as the highest-severity class of
bug in the codebase — above crashes, above performance regressions.

## A language model may never write the final sentence

Scene descriptions are composed by an on-device language model
(`FoundationModelsSceneComposer`), and the temptation is to let it produce the
whole sentence. It may not. The model is constrained by `@Generable` to return
a **noun phrase**, and `Phrasing` applies the hedge afterwards.

The reason is that a hedge carried in a prompt is a hedge that survives only
until the next model or prompt change, and no test can prove it survived —
generation is not deterministic, so "the output usually hedges" is the
strongest claim available. Structuring it so the model *cannot* emit the final
wording converts that into a property of the code. The `Certainty` fed to
`Phrasing` also comes from the detector's confidence, not the model's, so
fluent output cannot upgrade a doubtful detection into a stronger hedge.

The same rule applies to any future generative component: a model may supply
*what* is named, never *how certainly* it is asserted.

## Continuous, worn use raises the bar, it does not lower it

Hands-free awareness is meant for a phone worn on the body while walking —
the closest this app comes to the shape of a mobility device. Two consequences
follow, and both are implemented rather than merely stated:

- **Silence must never be mistakable for "clear".** A worn channel that goes
  quiet is indistinguishable from one that has stopped working, so the session
  re-states an unchanged scene periodically (`NarrationThrottle`), and announces
  out loud when it stops because the app left the screen.
- **A "clear" cue is only honest on an observed transition.** `awarenessClear`
  is emitted when a previously reported near reading moved away — a change in
  the app's own measurement — and its prose says exactly that. It is never
  emitted from a single sample, and the app still never says the way ahead is
  clear.

## Real-time navigation guidance is explicitly out of scope

The original concept included real-time navigation guidance. This plan
reframes that permanently as *awareness*, never *guidance*, because
navigation guidance is the most dangerous feature shape this project could
build: it invites exactly the false confidence this doctrine exists to
prevent. See [`docs/ROADMAP.md`](ROADMAP.md) for what's deliberately not
being built and why.

---

Need help? See
[`SUPPORT.md`](https://github.com/kevinle3212/sensebridge/blob/main/SUPPORT.md).
