---
title: Accessibility Standards for Contributors
---

# Accessibility Standards for Contributors

For SenseBridge, an app being accessible is not a quality bar — it is the
entire point. A scene-description tool a blind person cannot operate
eyes-free is a failed product, no matter how good the description is.
Accessibility is the first thing built, not the last thing checked.

## Standards this project builds against

- **WCAG 2.2** as the conceptual baseline (perceivable, operable,
  understandable, robust) — web-oriented, but its principles translate.
- **Apple Human Interface Guidelines, Accessibility section** as the
  concrete, platform-specific, authoritative guidance for an iOS app.
- **Apple's accessibility APIs** (`UIAccessibility`, SwiftUI accessibility
  modifiers) as the implementation surface.

## VoiceOver: the make-or-break channel

The primary user operates this app entirely through VoiceOver.

- **Meaningful labels on every element.** Not "button" — "Read document." An
  unclear or missing label means the control does not exist for that user.
- **Hints where the action is non-obvious**, sparingly, only when the label
  alone isn't enough.
- **Correct traits.** Buttons read as buttons, headers as headers, so the
  rotor works.
- **Deliberate focus management.** After an action completes, move VoiceOver
  focus to the result or announce it — never strand the user.
- **Rotor support.** Structure screens so navigation by heading/element is
  useful.
- **No gesture conflicts.** VoiceOver claims standard gestures; don't build
  custom gestures that fight it.
- **Announcements for async results.** When perception finishes after a
  delay, post a VoiceOver announcement — but only when the active
  `OutputProfile` has no `.speech` channel. Under the blind profile the
  result is already being spoken, and an announcement would interrupt that
  speech to repeat it. `announceIfUnspoken(_:profile:)` in
  `app/SenseBridge/Accessibility/VoiceOverAnnouncement.swift` is the only
  correct entry point; call it rather than `announceToVoiceOver` directly.
- **Say why a control is disabled.** A control that dims with no explanation
  is a dead end for a VoiceOver user, who has no visual cue for the cause.
  Disabled controls carry a hint naming the condition ("Unavailable while
  haptics are switched off"), and a control that would silently do nothing
  is disabled rather than left tappable.
- **Post `.layoutChanged` when controls appear mid-session.** Camera controls
  only exist once a device is resolved, which is after the screen has already
  been read out.

## Low-vision support

- **Dynamic Type** — never hardcode font sizes, and check accessibility sizes
  specifically. Segmented pickers divide a fixed width by their option count,
  so at `dynamicTypeSize.isAccessibilitySize` they truncate labels and drop
  below the 44pt minimum tap target; switch to `.menu` there
  (`CameraControlsView` is the worked example).
- **Spell out symbols in accessibility values.** VoiceOver reads `×` as "x",
  so `2.0×` becomes "two point oh ex"; write "2.0 times".
- **Contrast and color** — never encode meaning in color alone; support
  increased contrast. The awareness screen's yellow outlines are the worked
  example: each one carries a black-on-yellow caption naming the object and the
  classifier's confidence, so the highlight is never the only thing saying what
  was found — and the confidence is never dropped, because an unqualified box
  asserts more certainty than the spoken channel is allowed to
  ([SAFETY-FRAMING.md](SAFETY-FRAMING.md)).
- **Live camera feeds are `accessibilityHidden`.** A video preview has no
  accessible content, and outlines that move several times a second would talk
  over the narration that is the actual channel. `ReadingView` and
  `AwarenessPreviewView` both hide theirs; in both cases the content reaches
  VoiceOver as speech and as on-screen text beneath the preview.
- **Reduce Motion and Reduce Transparency** — respect both.

## Redundant output channels

Where it helps, deliver the same information through more than one sense
(spoken plus on-screen text). This is also the seed of the multi-sense
architecture described in [`docs/ARCHITECTURE.md`](ARCHITECTURE.md): the same
reasoning output can render as speech, caption, or haptic depending on the
user's profile.

## Accessibility risks and mitigations

| Risk | Consequence | Mitigation |
| --- | --- | --- |
| Unlabeled or poorly labeled controls | App is unusable via VoiceOver | Label everything; audit each screen with VoiceOver on |
| Focus lost after actions | User stranded after a result | Explicit focus management and announcements |
| Output too verbose or too terse | Cognitive load or missing info | Tune phrasing with real testers; make verbosity configurable |
| Over-confident output | User trusts a wrong reading | Hedged language everywhere — see [`docs/SAFETY-FRAMING.md`](SAFETY-FRAMING.md) |
| Building features before the shell is accessible | Inaccessible product with nice internals | VoiceOver-first discipline: shell accessible before features |

**The single most important sentence in this project: if a blind person has
not used a feature eyes-free and found it useful, it is not validated.**

## How to test

- **Manual VoiceOver navigation of every screen**, eyes closed or
  screen-curtained, before opening a PR.
- **Xcode Accessibility Inspector audits.** Zero unlabeled interactive
  elements is a hard gate, not a percentage — see
  [`docs/TESTING.md`](TESTING.md).
- **Real blind testers, early and repeatedly.** This is the test that
  actually counts. Recruit through NFB or ACB local chapters, or accessibility
  Discord/forum communities.

## PR requirement

Every pull request that touches UI must include the accessibility-impact
statement in
[`.github/PULL_REQUEST_TEMPLATE.md`](https://github.com/kevinle3212/sensebridge/blob/main/.github/PULL_REQUEST_TEMPLATE.md).
"No accessibility impact" is a valid answer for a pure-logic change — but it
must be stated, not assumed.

---

Need help? See
[`SUPPORT.md`](https://github.com/kevinle3212/sensebridge/blob/main/SUPPORT.md).
