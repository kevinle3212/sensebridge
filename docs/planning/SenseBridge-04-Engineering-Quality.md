# SenseBridge Plan, Document 4 of 6: Engineering Quality

*This document covers the Accessibility Engineering Review, Testing Strategy, Observability & Reliability, and Scalability Analysis. Read alongside Document 3 (Technical Architecture).*

---

## 15. Accessibility Engineering Review

A blunt framing first: most apps treat accessibility as a layer added near the end. For SenseBridge, the app being accessible is not a quality bar, it is the entire point. A scene-description tool that a blind person cannot operate eyes-free is a failed product, no matter how good the scene description is. So accessibility is a first-class engineering requirement and the first thing built, not the last thing checked.

### Standards to build against

- **WCAG 2.2** as the conceptual baseline (perceivable, operable, understandable, robust). It is web-oriented but its principles translate to mobile.
- **Apple Human Interface Guidelines, Accessibility section** as the concrete, platform-specific guidance. This is the authoritative source for an iOS app.
- **Apple's accessibility APIs** (UIAccessibility, SwiftUI accessibility modifiers) as the implementation surface.

### VoiceOver: the make-or-break channel

The MVP's primary user operates the app entirely through VoiceOver. Requirements:

- **Meaningful labels on every element.** Not "button," but "Read document." A blind user hears the label; if it is unclear or missing, the control does not exist for them.
- **Hints where the action is non-obvious.** A hint explains what happens, sparingly, only when the label is not enough.
- **Correct traits.** Buttons read as buttons, headers as headers, so the rotor works.
- **Deliberate focus management.** After an action completes (a document is read), move VoiceOver focus to the result or announce it, so the user is not stranded.
- **Rotor support.** Let users navigate by headings and elements; structure the screen so the rotor is useful.
- **No gesture conflicts.** VoiceOver claims standard gestures. Do not build custom gestures that fight it.
- **Announcements for async results.** When perception finishes after a delay, post a VoiceOver announcement so the user knows output is ready.

### Low-vision support

- **Dynamic Type.** Never hardcode font sizes; honor the user's chosen text size.
- **Contrast and color.** Do not encode meaning in color alone. Support increased contrast.
- **Reduce Motion and Reduce Transparency.** Respect both.

### Redundant output channels

Where it helps, deliver the same information through more than one sense: spoken plus on-screen text for a low-vision user who has some sight and uses VoiceOver intermittently. This redundancy is also the seed of the multi-sense architecture: the same reasoning output can be rendered as speech, caption, or haptic depending on the user's profile.

### Haptic design (deferred, principles set now)

For the eventual deaf-blind work, haptics must be a designed language, not arbitrary buzzes, and it must be co-designed with deaf-blind users (Protactile users in particular). Grounding facts: established tactile alphabets exist (Lorm, Malossi); useful vibration frequency range is roughly 10 to 200 Hz with resonance around 60 to 70 Hz; the number of reliably distinguishable messages goes up when you combine modalities (squeeze, stretch, vibration) rather than relying on vibration patterns alone. Implementation later uses Core Haptics on iPhone and `WKHapticType` on Apple Watch. None of this is MVP work, but the `RenderTarget` abstraction reserves a clean place for it.

### Accessibility risks and how to catch them

| Risk | Consequence | Mitigation |
| --- | --- | --- |
| Unlabeled or poorly labeled controls | App is unusable via VoiceOver | Label everything; audit each screen with VoiceOver on |
| Focus lost after actions | User stranded after a result | Explicit focus management and announcements |
| Output too verbose or too terse | Cognitive load or missing info | Tune phrasing with real testers; make verbosity configurable |
| Over-confident output | User trusts a wrong reading | Hedged language everywhere ("looks like," "possible") |
| Building features before the shell is accessible | Inaccessible product with nice internals | VoiceOver-first discipline: shell accessible before features |

### Testing requirements specific to accessibility

- Manual VoiceOver navigation of every screen, by you, eyes closed or screen-curtained.
- Accessibility audits in Xcode (the Accessibility Inspector).
- Real blind testers, early and repeatedly. This is the only test that truly counts. Recruit through NFB or ACB chapters or accessibility communities.

The single most important sentence in this document: **if a blind person has not used it eyes-free and found it useful, it is not validated.**

---

## 16. Testing Strategy

Coverage targets below are pragmatic for a solo developer, not enterprise dogma. The aim is confidence where bugs hurt most (perception correctness, accessibility, awareness-not-safety phrasing), not a coverage percentage for its own sake.

### Unit tests

- **What.** Pure logic: reading-order from OCR structure, phrasing and hedging rules, awareness thresholds and hysteresis, output-profile selection.
- **How.** Swift Testing, fast, no device needed. Mock `SensingSource` inputs with fixture perception records.
- **Target.** High coverage on the Reasoning layer specifically (phrasing, awareness logic, profile selection), because that is where a subtle bug produces a confidently wrong or unsafe-sounding statement. Aim high here even if other layers are lower.

### Integration tests

- **What.** Perception services against fixed inputs: feed known images to the OCR and detection services and assert sensible structured output; feed known audio to the sound classifier.
- **How.** Swift Testing with bundled test fixtures (sample documents, sample audio).
- **Target.** Cover each perception service's happy path and key failure modes (blurry image, no text found, ambiguous object).

### Accessibility tests

- **What.** Every screen is VoiceOver-navigable; labels and traits are present; focus behaves.
- **How.** Xcode Accessibility Inspector audits, plus a manual VoiceOver checklist per screen, plus automated checks where feasible.
- **Target.** Zero unlabeled interactive elements. This is a hard gate, not a percentage.

### AI evaluation

- **What.** Quality of OCR reading, object labels, and scene descriptions on a held-out set of real-world images you collect (mail, packaging, rooms). For scene description specifically, check that the composed sentence does not assert things the labels did not support.
- **How.** A small evaluation harness: a folder of images with expected-ish outputs, run periodically, reviewed by hand. This is not automated pass/fail (language output is fuzzy) but a regression check you eyeball.
- **Target.** No regressions in reading accuracy; no new instances of over-confident or hallucinated scene claims. Track these qualitatively across builds.

### End-to-end tests

- **What.** Full flows: open app, choose Read, capture, hear result; choose Awareness, walk a fixture route, hear cautious alerts.
- **How.** XCUITest for UI flows where stable; manual scripted runs for camera and depth flows that are hard to automate.
- **Target.** Each core flow has at least one automated or scripted-manual pass that is run before each beta build.

### Device tests

- **What.** Behavior on the actual iPhone 17 Pro: latency, battery, thermal behavior under sustained camera and depth use, Neural Engine performance.
- **How.** On-device profiling with Instruments. Benchmark the Foundation Models latency and the LiDAR pipeline on your real device rather than trusting published figures.
- **Target.** Responsive enough to feel immediate; no thermal throttling that breaks a normal session; battery drain acceptable for the use pattern.

### Field tests

- **What.** Real blind users, real environments, real tasks.
- **How.** TestFlight beta with recruited testers; structured feedback on task completion and friction.
- **Target.** At least one or two testers completing real tasks unaided and willing to keep using it. This is the validation that matters most.

### Beta testing

- **What.** Wider TestFlight group once the MVP is stable.
- **How.** Public TestFlight, feedback channel, issue triage.
- **Target.** Stable, crash-rare, and generating real usage feedback before any App Store consideration.

### Coverage philosophy

Chase high coverage where wrongness is dangerous (Reasoning/phrasing/awareness) and where regressions are silent (perception). Do not chase coverage on glue code and SwiftUI views where the compiler and manual use already give you confidence. For a solo developer, a test you will maintain beats a test that looks good in a report.

---

## 17. Observability & Reliability

The privacy stance constrains observability hard, and that is intentional: a privacy-first app does not phone home with telemetry by default. So observability for the MVP is mostly local and developer-facing, not a remote analytics pipeline.

### Logging

- **Local, structured logging** via Apple's unified logging (`OSLog` / `Logger`), with privacy-aware redaction (Apple's logging supports marking values private so they are not captured in device logs).
- **No user content in logs.** Never log recognized text, images, or audio. Log events and states, not content.
- **Log levels** so you can turn up detail when debugging on your own device and keep it quiet otherwise.

### Metrics

- **On-device, developer-facing performance metrics** during development (latency per stage, frame rates, model inference time) via Instruments and lightweight in-app counters you can inspect.
- **No remote metrics by default.** If, much later, you want aggregate performance data, it must be opt-in, anonymized, and minimal (see Document 3's scale-up backend notes).

### Tracing

- For a single-device app, "tracing" means following a request through the perception-to-reasoning-to-output pipeline locally. Use signposts (`OSSignposter`) to measure and visualize stage timings in Instruments. This is enough; distributed tracing is a server concept that does not apply.

### Error reporting and crash reporting

- **Xcode Organizer and TestFlight crash reports** give you crash data from beta testers for free, with Apple's privacy handling. This is the right MVP crash pipeline: no third-party SDK, no extra data collection.
- **Graceful degradation over crashing.** If Foundation Models is unavailable, fall back to label lists. If depth confidence is low, say less rather than guessing. If OCR finds nothing, say so plainly. The app should fail safe and quiet, never with a confident wrong statement.

### Performance monitoring

- Watch thermal state (`ProcessInfo.thermalState`) and back off sustained processing if the device is heating, to protect battery and prevent throttling mid-session. This matters because continuous camera plus depth plus inference is demanding.

### Reliability targets

Stated honestly for an MVP, not as enterprise SLOs:

- **Crash-free sessions high enough that testers are not abandoning it.** Track via TestFlight.
- **No confidently-wrong safety-adjacent output.** A single "it is safe to cross" style failure is worse than many crashes. Treat awareness-phrasing bugs as the highest-severity class.
- **Graceful behavior when a capability is unavailable** (no Apple Intelligence, low light, no network for the optional cloud path).

The reliability priority order for this product is unusual and worth stating: **correct hedging first, then not crashing, then performance.** A tool that occasionally crashes is annoying. A tool that confidently says the wrong thing about the physical world can get someone hurt.

---

## 18. Scalability Analysis

The prompt asked for an analysis at 100, 1,000, 10,000, 100,000, and 1,000,000 users. Here is the honest version, because the usual server-scalability framing mostly does not apply to an on-device app.

### The key insight: an on-device app scales trivially on the dimension servers struggle with

Because all processing happens on each user's own phone, adding users adds zero server load. There is no database to shard, no API to rate-limit, no compute to provision. One user and one million users impose the same (near-zero) infrastructure burden on you. This is a direct payoff of the privacy-first, offline-first design, and it inverts the usual scalability conversation.

So the analysis is not about server bottlenecks. It is about the things that actually get harder as the user base grows.

| Users | What is actually hard at this level | Bottleneck | Solution |
| --- | --- | --- | --- |
| 100 | Getting real feedback, fixing core bugs | Your time and attention | Tight tester relationships; triage ruthlessly |
| 1,000 | Support volume, device/iOS-version variety | Your time; edge cases across devices | Good docs, FAQ, issue templates; clear minimum-OS support |
| 10,000 | Sustaining solo effort; contribution management | You as a single point of failure | Recruit contributors; strong CONTRIBUTING docs; automate CI |
| 100,000 | Governance, trust, App Store relationship | Project bus-factor; reputation | Real governance (Document 5); maybe nonprofit/fiscal sponsor |
| 1,000,000 | Sustainability and stewardship of a critical tool | Funding and continuity | Grants, sponsorship, possible nonprofit; succession planning |

### The real bottleneck is you, not infrastructure

At every level above, the constraint is the solo developer's time, attention, and continuity, not compute. This reframes scalability entirely: the way SenseBridge "scales" is by growing a contributor community and a governance and funding structure, not by adding servers. That is why Document 5's open-source strategy and Document 1's funding section are the actual scalability plan, and the infrastructure section is nearly empty.

### The one place server scale could appear

If the optional, opt-in cloud-reasoning service is ever built and somehow attracts heavy use, that service would face conventional scaling questions (and conventional costs). The answer is the same as in Document 3: keep it self-hostable so load distributes across the community's own machines rather than concentrating on you, and only solve large-scale orchestration if real numbers ever demand it. For the app itself, scale is a non-issue by design.

*Continued in Document 5 of 6: Governance, Security & Legal.*
