# Roadmap

Source research: [`planning/SenseBridge-02-Features-and-Scope.md`](planning/SenseBridge-02-Features-and-Scope.md)
and [`planning/SenseBridge-06-Miscellaneous-and-Remarks.md`](planning/SenseBridge-06-Miscellaneous-and-Remarks.md).

Five phases. The first two are the MVP, funded by the maintainer's own time.
The rest are a credible direction, each gated on the previous phase actually
landing and on real-user validation — not on a calendar. Treat any pressure
to pull Phase 3+ work into the MVP as the single biggest threat to shipping
at all.

## MVP definition

A free, open-source, native iPhone app for blind and low-vision users that
runs entirely on-device and is itself fully accessible via VoiceOver.
Intentionally excludes: deaf/deaf-blind features, wearables/AR output,
facial recognition, any cloud processing or backend, turn-by-turn
navigation, and Android. See [`architecture.md`](architecture.md) for why
there is no backend and [`safety-framing.md`](safety-framing.md) for why
navigation is refused permanently, not just deferred.

### Phase 1 — MVP increment 1 (months 1–3): prove the core

- Native Swift/SwiftUI project, Apache 2.0 license, public GitHub repo,
  GitHub Actions CI from day one.
- VoiceOver-first app shell: every screen and control operable eyes-free
  before any feature lands.
- Camera capture module; document/text reading end to end; object and scene
  labeling end to end.
- `SensingSource` / `RenderTarget` protocols defined (camera-in, speech-out
  only for now — see [`architecture.md`](architecture.md)).
- **Done when:** a blind tester can navigate the app entirely via VoiceOver,
  point the camera at a letter and hear it read, and point it at a table and
  hear what is on it.
- **Risk:** underestimating how much work VoiceOver-first accessibility is.
  Mitigate by doing it first, not last.

### Phase 2 — MVP increment 2 / public beta (months 4–6): differentiate

- Natural-language scene description via the Vision-to-Foundation-Models
  pipeline, with availability checks and graceful fallback to label lists
  when Apple Intelligence is unavailable.
- LiDAR obstacle awareness with strict awareness-not-safety phrasing.
- Sound-event detection with a small custom Create ML classifier for a few
  high-value sounds.
- The consent-based enrollment *framework* (consent flow + on-device storage
  design) even if recognition itself stays minimal, so the legally-safe
  pattern is established before the feature grows.
- **Done when:** a blind tester gets a spoken scene description, receives
  cautious obstacle awareness while walking a known indoor route
  (supplementing their cane, never replacing it), and is alerted to a
  sounding alarm — all offline.
- **Risk:** Apple Foundation Models' quality ceiling and context limit;
  LiDAR framing discipline. Mitigate with honest hedged output and graceful
  fallbacks.

### Phase 3 — the deaf-user dimension (post-MVP)

- **Goal:** live captioning and richer sound awareness as a second output
  profile, proving the multi-sense architecture actually generalizes.
- **Features:** SpeechAnalyzer live captions, visual caption presentation,
  expanded sound detection.
- **Dependencies:** a stable visual/caption `RenderTarget`, iOS
  SpeechAnalyzer.
- **Risk:** a new user group with different expectations — validate with
  deaf testers directly, do not assume blind-user lessons transfer.

### Phase 4 — wearables (post-MVP)

- **Goal:** Apple Watch as a haptic/glanceable `RenderTarget` first (shares
  frameworks, lowest effort), then Vision Pro (visionOS shares frameworks
  with iOS), then, separately, Meta glasses (own SDK and model stack).
- **Risk:** each device is a separate integration project — never treat
  "wearables" as one item. Co-designed deaf-blind haptic language work
  likely lands here too, and must be designed *with* deaf-blind users, not
  for them in isolation.

### Phase 5 — platform and scale (long-term, conditional)

- **Goal:** a genuine open sensory-translation layer — configurable AI
  providers, optional self-hosted cloud reasoning for opt-in users, possible
  Android via a shared core, a real contributor community, grant-funded
  sustainability.
- **Risk:** this is where the original all-groups, all-devices vision
  lives. It is reachable only by climbing the earlier phases in order —
  attempting it early is the exact failure mode this roadmap exists to
  prevent.

## Open questions worth resolving before or during the build

Genuine forks where the right answer depends on testing or values, not more
planning:

1. **Is Apple Vision + Foundation Models good enough for scene description,
   or is bundling SmolVLM necessary?** Only on-device benchmarking will
   tell. Start with the license-clean Apple path (see
   [`ai-models.md`](ai-models.md)); reach for SmolVLM only if quality is
   genuinely insufficient and the RAM/latency cost is acceptable.
2. **How to recruit blind testers?** On the critical path, not a nicety —
   NFB/ACB local chapters, accessibility Discord/forum communities, and
   GitHub's accessibility open-source initiatives are the likely channels.
3. **Apple Developer Program budget or fee-waiver?** Needed before
   TestFlight distribution at the end of Phase 2 — see
   [`DISTRIBUTION.md`](DISTRIBUTION.md). Decide before month four.
4. **Apache 2.0 vs. AGPL for SenseBridge's own code?** Apache 2.0 is
   recommended (see [`ai-models.md`](ai-models.md) and
   [`../GOVERNANCE.md`](../GOVERNANCE.md)), but if preventing closed forks
   matters more than flexibility, AGPL is a defensible, values-driven
   alternative choice.
5. **How much verbosity do blind users actually want from spoken output?**
   A tuning question only real testers can answer — verbosity should be
   configurable from the start rather than guessed at.
