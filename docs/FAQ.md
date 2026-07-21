# FAQ

For the full reasoning behind these answers, see
[`PRODUCT.md`](PRODUCT.md), [`ROADMAP.md`](ROADMAP.md), and
[`planning/SENSEBRIDGE-06-MISCELLANEOUS-AND-REMARKS.md`](planning/SENSEBRIDGE-06-MISCELLANEOUS-AND-REMARKS.md).

**Why "SenseBridge"?**
It says what the project does (bridges senses) without overclaiming safety,
and it doesn't box the project into "blind" or "deaf" — which fits the
long-term multi-sense vision described in [`PRODUCT.md`](PRODUCT.md).

**Why offline-first instead of cloud AI, like Be My AI?**
Cloud scene-description apps are excellent but send your camera images to a
third party (Be My AI routes through OpenAI). For sensitive material —
mail, medical letters, financial documents — on-device processing is both
an ethical stance and a real product wedge no closed competitor can match.
See [`PRIVACY.md`](PRIVACY.md) and [`AI-MODELS.md`](AI-MODELS.md).

**Why free, with no subscription?**
Affordability is a real constraint for the people this app serves — only
about a third of working-age blind and low-vision US adults are employed
(AFB/Cornell). The MVP has no backend and no cloud API costs, so there is
nothing to charge for to begin with. See the funding section of
[`PRODUCT.md`](PRODUCT.md) for how the project sustains itself without a
subscription.

**Why native Swift instead of React Native or a cross-platform framework?**
The hardest and most valuable code here — Vision, ARKit/LiDAR, Foundation
Models, Sound Analysis — is native Apple-framework code regardless of UI
layer. React Native would add a layer without buying back any of the
cross-platform reach an iPhone-only, on-device MVP doesn't need. See
[`ARCHITECTURE.md`](ARCHITECTURE.md).

**How is this different from Apple's built-in accessibility features
(VoiceOver, Magnifier, Live Recognition)?**
Apple's own features are good but closed and capped, and Apple explicitly
disclaims them as not for navigation. SenseBridge is open-source (auditable,
self-hostable, cannot silently change terms) and aims to unify multiple
accessibility needs behind one consistent, on-device architecture rather
than a set of separate closed features.

**Does this replace a cane, guide dog, or orientation-and-mobility
training?**
No, and it says so repeatedly in the app itself. See
[`SAFETY-FRAMING.md`](SAFETY-FRAMING.md) for why "awareness, not safety" is
a hard rule, not a guideline.

**Will there be an Android version?**
Not in the MVP or the near-term roadmap. See [`ROADMAP.md`](ROADMAP.md)
Phase 5 — a shared core enabling Android is a long-term, conditional goal,
reachable only after the iPhone MVP and later phases land.

---

Need help? See [`SUPPORT.md`](../SUPPORT.md).
