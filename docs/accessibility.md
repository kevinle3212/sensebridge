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
  delay, post a VoiceOver announcement.

## Low-vision support

- **Dynamic Type** — never hardcode font sizes.
- **Contrast and color** — never encode meaning in color alone; support
  increased contrast.
- **Reduce Motion and Reduce Transparency** — respect both.

## Redundant output channels

Where it helps, deliver the same information through more than one sense
(spoken plus on-screen text). This is also the seed of the multi-sense
architecture described in [`docs/architecture.md`](architecture.md): the same
reasoning output can render as speech, caption, or haptic depending on the
user's profile.

## Accessibility risks and mitigations

| Risk | Consequence | Mitigation |
|---|---|---|
| Unlabeled or poorly labeled controls | App is unusable via VoiceOver | Label everything; audit each screen with VoiceOver on |
| Focus lost after actions | User stranded after a result | Explicit focus management and announcements |
| Output too verbose or too terse | Cognitive load or missing info | Tune phrasing with real testers; make verbosity configurable |
| Over-confident output | User trusts a wrong reading | Hedged language everywhere — see [`docs/safety-framing.md`](safety-framing.md) |
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
statement in [`.github/PULL_REQUEST_TEMPLATE.md`](../.github/PULL_REQUEST_TEMPLATE.md).
"No accessibility impact" is a valid answer for a pure-logic change — but it
must be stated, not assumed.
