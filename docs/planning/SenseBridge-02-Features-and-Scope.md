# SenseBridge Plan, Document 2 of 6: Features & Scope

*This document covers the Feature Audit, Feature Decomposition, MVP Definition, and Roadmap. Read alongside Document 1 (Strategy) and Document 3 (Technical Architecture).*

---

## 6. Feature Audit

Each proposed feature is evaluated on purpose, user value, technical complexity, risk, dependencies, and priority. Priority uses MoSCoW: Must Have, Should Have, Nice To Have, Future Research. "Must Have" here means must have *for the MVP*, which is blind users on iPhone, on-device.

A blunt note before the table: the original proposal's feature list spans three disability groups and three device classes. The audit below reclassifies most of it as deferred. That is the point of the audit.

### Reading and text (the MVP's strongest bet)

| Field | Detail |
| --- | --- |
| Feature | Document and text reading (OCR to speech) |
| Purpose | Read physical mail, packaging, signs, and documents aloud |
| User value | Very high. This is the feature most likely to earn daily use. Reading mail unaided is a concrete independence win |
| Technical complexity | Low to moderate. Apple Vision OCR is mature; iOS 26 adds document and table structure recognition |
| Risks | Low. Worst case is a misread word. No safety implications |
| Dependencies | Apple Vision framework, AVSpeechSynthesizer, VoiceOver |
| Priority | **Must Have** |

### Object and scene labeling

| Field | Detail |
| --- | --- |
| Feature | Identify objects and surfaces in view |
| Purpose | "What am I holding," "what is on this table" |
| User value | High |
| Technical complexity | Low to moderate using Apple Vision built-in classification and detection |
| Risks | Low to moderate. Misidentification is possible; phrase output with appropriate hedging |
| Dependencies | Apple Vision framework |
| Priority | **Must Have** |

### Natural-language scene description

| Field | Detail |
| --- | --- |
| Feature | A spoken sentence describing the scene, not just a label list |
| Purpose | "There appears to be a kitchen counter with a mug and a phone on it" |
| User value | High, and a clear differentiator over bare labels |
| Technical complexity | Moderate. Must be a two-stage pipeline: Apple Vision produces labels and text, Apple Foundation Models composes a sentence (Foundation Models is text-only, cannot take an image). See Document 3 |
| Risks | Moderate. The composed sentence is only as good as the labels feeding it; it can sound confident while being wrong. Must hedge language |
| Dependencies | Apple Vision, Apple Foundation Models (Apple Intelligence required; availability checks needed) |
| Priority | **Should Have** (target the second increment) |

### Obstacle awareness (LiDAR)

| Field | Detail |
| --- | --- |
| Feature | Awareness of nearby obstacles using LiDAR depth |
| Purpose | "Possible obstacle ahead, roughly one meter" |
| User value | High if framed honestly, dangerous if oversold |
| Technical complexity | Moderate. ARKit `sceneDepth` is available; the hard part is using the confidence map and degrading gracefully |
| Risks | High on the framing axis. This must never be presented as navigation or safety. Cautious, probabilistic language only. It supplements a cane, never replaces it |
| Dependencies | ARKit, LiDAR (present on iPhone 17 Pro) |
| Priority | **Should Have** (second increment), with the awareness-not-safety rule enforced in copy |

### Sound event detection

| Field | Detail |
| --- | --- |
| Feature | Alert the user to sounds (alarms, doorbells, a name being called) |
| Purpose | Awareness of audio events |
| User value | Moderate to high. More central to the deaf use case, but useful for blind users too (for example, an alarm behind them) |
| Technical complexity | Low to moderate. Apple Sound Analysis has a built-in classifier plus custom Create ML models |
| Risks | Low. False positives are an annoyance, not a danger |
| Dependencies | Apple Sound Analysis framework |
| Priority | **Should Have** (second increment) |

### Live speech captioning

| Field | Detail |
| --- | --- |
| Feature | Real-time speech-to-text captions |
| Purpose | Core deaf-user feature |
| User value | High for deaf users, marginal for the blind MVP |
| Technical complexity | Moderate. iOS 26 SpeechAnalyzer/SpeechTranscriber is on-device and fast |
| Risks | Low technically; the risk is scope creep into the deaf product before the blind one is done |
| Dependencies | Apple SpeechAnalyzer (iOS 26) |
| Priority | **Future Research** for MVP; first real feature of the deaf phase |

### Haptic notification language

| Field | Detail |
| --- | --- |
| Feature | Structured vibration patterns conveying meaning |
| Purpose | Core deaf-blind feature |
| User value | High for deaf-blind users, low for the blind MVP |
| Technical complexity | Moderate to build, hard to design *well*. Requires co-design with deaf-blind users |
| Risks | Designing in isolation produces a vocabulary no one can use. Must be participatory |
| Dependencies | Core Haptics, and later WatchKit haptics; real deaf-blind collaborators |
| Priority | **Future Research** |

### Facial recognition and enrollment

| Field | Detail |
| --- | --- |
| Feature | Recognize consent-enrolled known people by name; label everyone else "person" |
| Purpose | "Your friend Sam is approaching" for enrolled, consented contacts only |
| User value | Moderate. Pleasant, not essential |
| Technical complexity | Moderate (on-device face embedding and matching) |
| Risks | High on the legal axis. Biometric-privacy laws (BIPA, CUBI, Washington, GDPR Article 9) apply even on-device. Requires a careful consent flow and on-device-only, encrypted, deletable storage. See Document 5 |
| Dependencies | Apple Vision face detection, secure on-device storage, a consent UX |
| Priority | **Nice To Have**, deferred well past MVP, behind consent design |

### Real-time navigation guidance

| Field | Detail |
| --- | --- |
| Feature | Turn-by-turn guidance for a blind person |
| Purpose | Get from A to B |
| User value | Would be high if it worked safely; it largely cannot at this scope |
| Technical complexity | Very high. This is a research-grade, safety-critical problem |
| Risks | The highest in the document. Directly conflicts with "never claim safety." A wrong instruction can put someone in a street |
| Dependencies | Far beyond MVP scope |
| Priority | **Removed.** Reframe permanently as obstacle and landmark *awareness*, never guidance |

### Wearable and AR-glasses output

| Field | Detail |
| --- | --- |
| Feature | Output on Apple Watch, Vision Pro, Meta glasses |
| Purpose | Hands-free and glanceable delivery |
| User value | High eventually |
| Technical complexity | High; each device is a separate integration |
| Risks | Massive scope expansion if attempted early |
| Dependencies | Per-device SDKs; a stable `RenderTarget` abstraction first |
| Priority | **Future Research**, architecture-only in MVP |

### Feature audit summary

| Priority | Features |
| --- | --- |
| Must Have (MVP increment 1) | Document/text reading, object/scene labeling, VoiceOver-accessible app shell |
| Should Have (MVP increment 2) | Natural-language scene description, LiDAR obstacle awareness, sound-event detection |
| Nice To Have (post-MVP) | Consent-based facial enrollment |
| Future Research (deferred phases) | Live speech captioning, haptic language, wearables, AR glasses |
| Removed | Real-time navigation guidance (reframed as awareness), React Native, MVP backend, Ultralytics YOLO |

---

## 7. Feature Decomposition

Each feature breaks into independently buildable, independently testable modules. This is what makes a solo build tractable: you ship and verify one module at a time, and every module has a clear input and output. The shared abstraction beneath all of them is a `SensingSource` (something that produces perception data) and a `RenderTarget` (something that delivers output to the user). Document 3 details these.

### Document and text reading

- **Camera capture module.** Owns the `AVCaptureSession`, frame delivery, and capture lifecycle. Input: camera. Output: image buffers.
- **OCR module.** Wraps Apple Vision text recognition (`RecognizeTextRequest`, and iOS 26 `RecognizeDocumentsRequest` for structure). Input: image buffer. Output: recognized text with layout.
- **Reading-order and structure module.** Orders text sensibly (columns, tables) for linear speech. Input: structured OCR result. Output: an ordered string.
- **Speech output module (a `RenderTarget`).** Wraps AVSpeechSynthesizer and coordinates with VoiceOver. Input: text. Output: audio.

### Object and scene labeling

- **Camera capture module** (shared with above).
- **Detection module.** Wraps Apple Vision classification/detection. Input: image buffer. Output: labels with confidence.
- **Phrasing module.** Turns labels into hedged, spoken-friendly phrases ("looks like a mug"). Input: labels. Output: text.
- **Speech output module** (shared).

### Natural-language scene description

- **Perception aggregation module.** Collects labels, detected text, and (optionally) depth into a structured summary. Input: outputs of detection, OCR, depth. Output: a structured perception record.
- **Language composition module.** Feeds the structured record to Apple Foundation Models with a careful prompt and guided generation, producing a hedged sentence. Input: perception record. Output: a sentence. (Two-stage by necessity; see Document 3.)
- **Speech output module** (shared).

### Obstacle awareness

- **Depth capture module (a `SensingSource`).** Wraps ARKit `sceneDepth` and the confidence map. Input: ARKit session. Output: filtered depth readings.
- **Awareness logic module.** Converts depth into cautious, thresholded awareness events, with hysteresis to avoid chattering. Input: depth readings. Output: awareness events with distance estimates.
- **Output module.** Renders events as cautious speech (and later haptics). Enforces awareness-not-safety phrasing.

### Sound event detection

- **Audio capture module (a `SensingSource`).** Owns the microphone stream.
- **Classification module.** Wraps Apple Sound Analysis plus any custom Create ML classifier. Input: audio. Output: detected sound events.
- **Alert module (a `RenderTarget`).** Surfaces events as speech or visual or haptic, per the active output profile.

### The point of decomposing this way

Every module above can be built and verified on its own. The camera and speech modules are shared across features, so they are written once. The deferred features (captioning, haptics, wearables) slot in as new `SensingSource` or `RenderTarget` implementations without disturbing the reasoning core. This is the difference between a six-month plan that converges and one that thrashes.

---

## 8. MVP Definition

### Scope

The MVP is a free, open-source, native iPhone app for blind and low-vision users that runs entirely on-device and is itself fully accessible via VoiceOver. It delivers, by the end of six months:

- Reading printed text and documents aloud.
- Identifying common objects and surfaces.
- Describing a scene in a natural sentence.
- Cautious obstacle awareness using LiDAR.
- Awareness of important sound events.

### What is intentionally excluded

- Any deaf-user or deaf-blind-user features.
- Any wearable or AR-glasses output.
- Facial recognition or enrollment.
- Any cloud processing or backend.
- Turn-by-turn navigation of any kind.
- Android.

Excluding these is not a gap. It is the plan working.

### Increment 1 (months 1 to 3): prove the core

- Native Swift/SwiftUI project, Apache 2.0 license, public GitHub repo, GitHub Actions CI from day one.
- VoiceOver-first app shell: every screen and control operable eyes-free before any feature lands.
- Camera capture module.
- Document and text reading, end to end.
- Object and scene labeling, end to end.
- `SensingSource` and `RenderTarget` protocols defined, even with only camera-in and speech-out implemented.

**Increment 1 is done when** a blind tester can open the app, navigate it entirely via VoiceOver, point the camera at a letter and hear it read, and point it at a table and hear what is on it.

### Increment 2 (months 4 to 6): differentiate

- Natural-language scene description via the Vision-to-Foundation-Models pipeline, with availability checks and a graceful fallback to label lists when Apple Intelligence is unavailable.
- LiDAR obstacle awareness with strict awareness-not-safety phrasing.
- Sound-event detection with a small custom Create ML classifier for a few high-value sounds.
- The consent-based enrollment *framework* (the consent flow and on-device storage design) even if recognition itself is minimal, so the legal-safe pattern is established before the feature grows.

**Increment 2 is done when** a blind tester can get a spoken scene description, receive cautious obstacle awareness while walking a known indoor route (supplementing their cane), and be alerted to a sounding alarm, all offline.

### Success criteria for the MVP overall

Tie back to Document 1's metrics: 100% on-device, full VoiceOver navigability, at least one or two blind testers using it for real tasks, and a measurable count of tasks completed without sighted help. If those hold, the MVP succeeded regardless of star count.

---

## 9. Roadmap

Five phases. The first two are the funded-by-your-own-time MVP. The rest are the credible future, each gated on the previous one actually landing and on real-user validation, not on a calendar.

### Phase 1: MVP increment 1 (months 1 to 3)

- **Goals.** A VoiceOver-accessible app that reads text and labels objects, fully on-device.
- **Features.** App shell, camera capture, OCR reading, object/scene labeling.
- **Dependencies.** Apple Vision, AVSpeechSynthesizer, VoiceOver, the protocol abstractions.
- **Risks.** Underestimating how much work VoiceOver-first accessibility is. Mitigate by doing it first, not last.

### Phase 2: MVP increment 2 / public beta (months 4 to 6)

- **Goals.** Differentiated, still on-device: scene description, obstacle awareness, sound alerts. A public TestFlight beta.
- **Features.** Foundation Models scene description, LiDAR awareness, sound-event detection, the consent-enrollment framework.
- **Dependencies.** Apple Foundation Models (Apple Intelligence), ARKit/LiDAR, Sound Analysis, Create ML.
- **Risks.** Foundation Models quality ceiling and context limit; LiDAR framing discipline. Mitigate with honest hedged output and graceful fallbacks.

### Phase 3: the deaf-user dimension (post-MVP)

- **Goals.** Add live captioning and richer sound awareness as a second output profile, proving the multi-sense architecture.
- **Features.** SpeechAnalyzer live captions, visual caption presentation, expanded sound detection.
- **Dependencies.** A stable `RenderTarget` abstraction (a visual/caption target), iOS 26 SpeechAnalyzer.
- **Risks.** This is a new user group with different expectations. Validate with deaf testers, do not assume the blind-user lessons transfer.

### Phase 4: wearables (post-MVP)

- **Goals.** Apple Watch as a haptic and glanceable `RenderTarget` first (lowest-effort, shares frameworks), then explore Vision Pro (visionOS shares frameworks with iOS) and, separately, Meta glasses (their own SDK and model stack).
- **Features.** Watch haptic alerts, glanceable summaries; eventually glasses-based capture and output.
- **Dependencies.** Mature `SensingSource`/`RenderTarget` abstractions, WatchKit (`WKHapticType`), per-device SDKs.
- **Risks.** Each device is a separate project. Do not treat "wearables" as one item. The deaf-blind haptic language work (co-designed) likely lands here too.

### Phase 5: platform and scale (long-term, conditional)

- **Goals.** Become a genuine open sensory-translation layer: configurable AI providers, optional self-hosted cloud reasoning for users who opt in, possible Android via a shared core, a real contributor community, and grant-funded sustainability.
- **Features.** Provider configuration, optional cloud layer, broader device support.
- **Dependencies.** Everything above, plus funding and contributors.
- **Risks.** This is where the original vision lives. It is reachable only by climbing the earlier phases. Attempting it early is the failure mode the whole plan is designed to prevent.

### Roadmap reality check

Phases 1 and 2 are a commitment. Phases 3 through 5 are a direction, not a schedule. Treat any pressure to pull Phase 3+ work into the MVP as the single biggest threat to shipping at all.

*Continued in Document 3 of 6: Technical Architecture.*
