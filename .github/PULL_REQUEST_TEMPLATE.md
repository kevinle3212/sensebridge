<!-- Thanks for contributing to a free, on-device accessibility tool. -->

## Summary

<!-- What does this change do, and why? -->

## Accessibility impact (required)

<!-- Every PR must answer this. If your change touches any UI: -->

- [ ] Every affected screen is fully VoiceOver-navigable with **zero unlabeled
      elements**.
- [ ] I tested with VoiceOver on (eyes closed or screen-curtained), not just by
      reading the code.
- [ ] Dynamic Type, contrast, and focus order were checked where relevant.
- [ ] Not applicable — this change touches no UI. <!-- keep only if true -->

## Safety-framing (required if this touches spoken output, alerts, captions, haptics, or physical-world language)

- [ ] Output hedges ("looks like", "appears to be") and asserts no certainty the
      models did not earn.
- [ ] No composed claim goes beyond what the underlying labels/detections
      support.
- [ ] Fails safe and quiet when confidence is low or a capability is
      unavailable.
- [ ] Not applicable — no physical-world output changed.

## On-device / privacy

- [ ] No new network round-trip for perception or reasoning.
- [ ] No user surroundings leave the device without explicit, revocable consent
      and a `docs/privacy.md` update.
- [ ] Not applicable.

## Model / dependency licensing

- [ ] No new model or dependency, or all additions clear the
      `model-license-audit` skill (AGPL and Apple's `apple-amlr` are hard
      blockers).

## Checks

- [ ] Build and tests pass locally (`docs/TESTING.md`).
- [ ] Docs updated for any changed behaviour, env, models, or workflows.
- [ ] Conventional commit messages (`type(scope): subject`).

## Notes for the reviewer

<!-- Anything a machine can't verify: device testing done, blind-tester feedback,
     known gaps. Be honest about what still needs human or on-device validation. -->
