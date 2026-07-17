# SenseBridge Plan, Document 3 of 6: Technical Architecture

*This document covers System Architecture, AI Architecture, Mobile Architecture, Backend Architecture, and Infrastructure. This is the technical core. Read alongside Document 2 (Features) and Document 5 (Security & Legal, which covers model licensing in depth).*

---

## The framework decision, stated up front

The original proposal assumed React Native. This plan recommends **native Swift with Apple frameworks** instead, and the reasoning drives everything below, so it comes first.

The hardest, most valuable code in SenseBridge is on-device perception and output: Vision OCR, object detection, ARKit depth, Sound Analysis, Foundation Models, AVSpeechSynthesizer, and deep VoiceOver and Core Haptics integration. All of that is native Apple-framework code. React Native cannot reach those frameworks except through native Swift modules you would have to write anyway. So React Native would mean writing the hard Swift code *and* a JavaScript layer *and* the bridge between them: three layers to maintain, for a solo developer, on a six-month clock, to reach a cross-platform audience the MVP explicitly does not target (iPhone only).

The cross-platform argument for React Native is real in general. It is close to worthless here, because:

- The MVP is iPhone-only by design.
- The on-device ML quality you want is best on Apple's own frameworks.
- VoiceOver and haptics support is deepest in native code.
- Tooling, profiling, and on-device debugging are cleaner in native.

The legitimate worry is lock-in: does going native trap you on iPhone forever and block the wearable and Android future? No, and the reason is architectural, not framework-level. You isolate the device-specific perception and output behind protocols (`SensingSource`, `RenderTarget`) and keep the reasoning core device-agnostic. visionOS and watchOS already share frameworks with iOS, so those expansions are natural. Meta glasses and Android would require new platform integrations regardless of whether you started in React Native or Swift, because their ML stacks are entirely different. React Native would not have saved you there.

**Recommendation: native Swift / SwiftUI core for the MVP, with protocol-based abstractions that keep the future open. Revisit a shared Rust or C++ core only if and when Android becomes a funded, near-term requirement (a Phase 5 question).**

---

## 10. System Architecture

### High-level view

```text
+-------------------------------------------------------------+
|                      SenseBridge App                         |
|                  (native Swift / SwiftUI)                    |
|                                                              |
|   +-----------------+        +---------------------------+   |
|   |  Sensing Layer  |        |      Output Layer         |   |
|   | (SensingSource) |        |     (RenderTarget)        |   |
|   |                 |        |                           |   |
|   | - Camera        |        | - Speech (AVSpeech)       |   |
|   | - Depth (LiDAR) |        | - VoiceOver announce      |   |
|   | - Microphone    |        | - Visual captions (later) |   |
|   |                 |        | - Haptics (later)         |   |
|   +--------+--------+        +-------------+-------------+   |
|            |                               ^                 |
|            v                               |                 |
|   +-------------------------------------------------------+ |
|   |               Perception Layer                         | |
|   |  Vision OCR | Vision detect | Sound Analysis | depth   | |
|   |  -> produces structured "perception records"           | |
|   +----------------------------+--------------------------+ |
|                                |                            |
|                                v                            |
|   +-------------------------------------------------------+ |
|   |               Reasoning Layer (device-agnostic)        | |
|   |  - phrasing / hedging rules                            | |
|   |  - scene composition via Foundation Models (2-stage)   | |
|   |  - awareness logic (thresholds, hysteresis)            | |
|   |  - output-profile selection (blind / deaf / db)        | |
|   +----------------------------+--------------------------+ |
|                                |                            |
|                                v                            |
|   +-------------------------------------------------------+ |
|   |        Local Storage (no server required)              | |
|   |  UserDefaults (settings) | optional CloudKit sync      | |
|   |  encrypted enrollment store (later, on-device only)    | |
|   +-------------------------------------------------------+ |
|                                                              |
|   (Optional, opt-in only) -----------------------------+     |
|   | Cloud Reasoning Adapter (disabled by default)       |     |
|   | user-configured provider, explicit consent required |     |
|   +-----------------------------------------------------+     |
+-------------------------------------------------------------+
```

### Data flow for "read this document"

```text
Camera --frame--> Perception(Vision OCR + structure)
   --recognized text + layout--> Reasoning(reading-order)
   --ordered text--> Output(Speech RenderTarget) --audio--> User
```

No network. No server. Everything between camera and ear stays on the phone.

### Data flow for "describe this scene"

```text
Camera --frame--> Perception(Vision detect + OCR)
                       |
                       v
              structured perception record
                       |
                       v
        Reasoning(Foundation Models composes a hedged sentence)
                       |
                       v
              Output(Speech RenderTarget) --audio--> User
```

The Foundation Models step is local and text-only. It never sees the image; it sees the labels and text the Vision layer extracted. This is a hard constraint of the framework, not a design choice (see AI Architecture below).

### Component responsibilities

- **Sensing Layer.** Owns hardware: camera session, ARKit depth session, microphone. Each concrete source conforms to a `SensingSource` protocol. Swappable; a future glasses camera is a new `SensingSource`.
- **Perception Layer.** Turns raw sensor data into structured facts: text, labels, sound events, depth readings. Pure transformation, no UI.
- **Reasoning Layer.** Device-agnostic. Applies hedging rules, composes language, runs awareness thresholds, and selects the output profile (blind = speech, deaf = captions, deaf-blind = haptics). This is the part you protect from device specifics so it survives expansion.
- **Output Layer.** Delivers to the user via a `RenderTarget`. Speech and VoiceOver announcements for the MVP; captions and haptics later; watch and glasses later.
- **Local Storage.** Settings in UserDefaults, optional iCloud/CloudKit sync at no cost, and (later) an encrypted on-device enrollment store. No server.
- **Optional Cloud Reasoning Adapter.** Disabled by default, opt-in only, user-configured. Exists so the "configurable provider" promise is real without ever being required.

---

## 11. AI Architecture

Every recommendation here is filtered through three constraints: it must be free, it should run on-device, and its license must not poison an open-source project. The licensing point is not a footnote; it eliminates two of the most attractive models outright. Document 5 covers licensing law; this section covers the engineering choice.

### The central pipeline: Vision first, then Foundation Models

Apple Foundation Models (the on-device LLM available to developers as of iOS 26) is the right reasoning engine: free, on-device, license-clean, and accessible via a clean Swift API (`SystemLanguageModel`, `LanguageModelSession`). But it has two limits that shape the whole architecture:

1. **It is text-only.** It cannot accept an image. So it cannot "look at" a scene.
2. **Its context window is small (around 4,096 tokens).** iOS 26.4 added tooling to measure and manage this (`contextSize`, `tokenCount(for:)`, and an `.exceededContextWindowSize` error), but you must keep prompts and perception summaries compact.

The consequence: scene understanding must be two-stage. Apple Vision extracts labels, detected objects, and text. Foundation Models composes those into a natural sentence using guided generation (`@Generable`) to return a typed Swift struct rather than free text you have to parse. This combination of Vision plus Foundation Models is supported, license-clean, and zero-cost.

> **Accuracy note (verified June 2026):** An earlier draft implied Apple ships an official sample app that demonstrates this exact pattern for accessibility scene description. That is not accurate. VLLO is a real third-party *video-editing* app Apple has showcased that combines Vision and Foundation Models, but it is not a scene-description-for-accessibility sample, and there is no canonical Apple sample for the accessibility use case. You will be building this pipeline yourself. The frameworks support it; the specific application is yours to write.

Be honest about the ceiling: composing from a "bag of labels" is weaker than a true vision-language model that reasons over the pixels. It can miss spatial relationships and can sound confident while wrong. This is the on-device quality gap versus cloud competitors, and the design answer is hedged language plus an optional (opt-in) cloud path for users who want more, never a default cloud dependency.

### On-device perception models (all free, on-device)

| Need | Recommended | Why | License | Notes |
| --- | --- | --- | --- | --- |
| OCR | Apple Vision text recognition | Best on-device quality, iOS 26 adds document/table structure | Apple SDK | Primary |
| OCR fallback (cross-platform later) | Tesseract | Mature, portable | Apache 2.0 | Only if leaving Apple frameworks |
| Object detection/classification | Apple Vision built-in | No model to bundle, no license risk | Apple SDK | Primary; avoid Ultralytics YOLO (AGPL) |
| Scene reasoning (language) | Apple Foundation Models | Free, on-device, clean license | Apple SDK | Two-stage with Vision |
| Richer scene VLM (if needed) | SmolVLM / SmolVLM2 (256M to 2.2B) | MLX-ready, ~1 to 5 GB RAM, permissive | Apache 2.0 | Only if Vision-plus-FM proves too weak; benchmark on device |
| Speech-to-text (deaf phase) | Apple SpeechAnalyzer / SpeechTranscriber | On-device, fast, iOS 26 | Apple SDK | Reported ~2x faster than Whisper Large V3 Turbo |
| STT fallback (older devices / cross-platform) | whisper.cpp | On-device, portable | MIT | Heats the device under continuous real-time use; Apple's SpeechAnalyzer ran ~2.2x faster in one informal single-file test (45s vs 1:41), not a controlled benchmark |
| Sound event detection | Apple Sound Analysis (+ Create ML) | Built-in classifier plus custom models | Apple SDK | Primary |
| Sound detection (cross-platform later) | YAMNet | 521 classes | Apache 2.0 | For non-Apple targets |
| On-device LLM (provider option) | llama.cpp or MLX with small permissive models | "Configurable provider" path | MIT (llama.cpp), Apple (MLX) | Use Apache/MIT model weights only |

### The two licensing traps (critical, expanded in Document 5)

- **Ultralytics YOLO (v8, v11, and newer) is AGPL-3.0.** Bundling it forces your entire project, code, configs, and weights, to AGPL, or to buy an Enterprise License. For an open-source project that wants permissive licensing and future flexibility, this is a poison pill. Use Apple Vision detection instead.
- **Apple FastVLM is released under the `apple-amlr` non-commercial research license** (verified across its 0.5B, 1.5B, and 7B variants on Hugging Face, June 2026). It is technically excellent and tempting. It is not usable in a shipping app. Do not bundle it. (One secondary blog described FastVLM as "permissive." The authoritative Hugging Face license tag and the AMLR terms say non-commercial. The AMLR license explicitly limits use to "Research Purposes," defined as non-commercial scientific research, and excludes any commercial product or service.)
- **Apple MobileCLIP has mixed, unsettled licensing and should be quarantined, not bundled.** Verification (June 2026) found Apple's own MobileCLIP repositories mix license signals: the LICENSE file inside the repo is the restrictive `apple-amlr` (non-commercial research only), while a separate weights/data license file is the permissive Apple Sample Code License, and the repo metadata carries both tags. Until Apple clarifies in writing, treat MobileCLIP as non-commercial/research-only and do not ship it in anything you might monetize. An earlier draft stated flatly that MobileCLIP is `apple-amlr`; the honest position is that its license is ambiguous and must be confirmed with Apple before any product use.

### Resource and privacy notes

- Apple frameworks run on the Neural Engine and GPU, are tuned for the device, and add nothing to your bundle size for system-managed models (SpeechAnalyzer assets, for example, are downloaded and managed by the OS).
- Foundation Models requires Apple Intelligence (iPhone 15 Pro and later), so you must implement availability checks and a graceful fallback (label lists instead of composed sentences) for unsupported devices.
- Everything above is on-device and private by default. The only path off-device is the optional, opt-in cloud adapter.

### Face recognition architecture (deferred, designed now)

When it arrives: Apple Vision detects faces; you compute embeddings on-device; you match only against people the user has explicitly enrolled with consent; embeddings live in an encrypted on-device store and never leave the phone; unknown faces are only ever labeled "person." No cloud, no public recognition, ever. The legal framing is in Document 5.

---

## 12. Mobile Architecture

### Project shape (native Swift / SwiftUI)

```text
SenseBridge/
  App/
    SenseBridgeApp.swift          # entry point
    AppEnvironment.swift          # dependency container
  Core/
    Sensing/
      SensingSource.swift         # protocol
      CameraSource.swift
      DepthSource.swift           # ARKit/LiDAR
      AudioSource.swift
    Perception/
      OCRService.swift            # Apple Vision text
      DetectionService.swift      # Apple Vision detect
      SoundService.swift          # Sound Analysis
      DepthService.swift          # depth -> readings
      PerceptionRecord.swift      # structured output type
    Reasoning/
      SceneComposer.swift         # Foundation Models, 2-stage
      AwarenessEngine.swift       # thresholds, hysteresis
      Phrasing.swift              # hedging rules, awareness-not-safety
      OutputProfile.swift         # blind / deaf / deaf-blind selection
    Output/
      RenderTarget.swift          # protocol
      SpeechTarget.swift          # AVSpeechSynthesizer + VoiceOver
      CaptionTarget.swift         # later
      HapticTarget.swift          # later (Core Haptics)
    Storage/
      Settings.swift              # UserDefaults
      CloudSyncService.swift      # optional CloudKit
      EnrollmentStore.swift       # later, encrypted, on-device
    CloudOptional/
      CloudReasoningAdapter.swift # opt-in only, disabled by default
  Features/
    Reading/                      # OCR-to-speech UI + logic
    Labeling/                     # object/scene UI + logic
    SceneDescription/             # natural-language scene UI
    ObstacleAwareness/            # LiDAR UI + cautious output
    SoundAlerts/                  # sound-event UI
  Accessibility/
    VoiceOver+Helpers.swift       # labels, hints, traits, focus
    DynamicType+Helpers.swift
    HapticPatterns.swift          # later
  Resources/
    Localizable.strings
    SoundModels/                  # Create ML classifiers (permissive)
  Tests/
    ...                           # mirrors structure (see Document 4)
```

### State management

For a solo SwiftUI project, keep it boring and native. Use the Observation framework (`@Observable`) or `ObservableObject` view models, with a small dependency container (`AppEnvironment`) injected at the root. Resist reaching for a heavy third-party state library; the app's state is mostly transient perception data plus a small settings object. Simplicity here is a feature, because you will be maintaining this alone.

### Navigation

SwiftUI `NavigationStack` with a small, flat hierarchy. Blind users navigate by VoiceOver, not by visual layout, so the structure should be shallow and predictable: a main screen with clearly labeled mode buttons (Read, Identify, Describe, Awareness, Sounds), each leading to a focused single-purpose screen. Avoid deep nesting and avoid gesture-only navigation that conflicts with VoiceOver gestures.

### Accessibility layer (this is not optional; it is the product)

- Every control has a meaningful `accessibilityLabel`, a `hint` where the action is not obvious, and correct `traits`.
- Manage VoiceOver focus deliberately after actions (for example, move focus to a result when reading completes) using `accessibilityFocused` or `UIAccessibility.post(notification:)`.
- Support Dynamic Type for low-vision users; never hardcode font sizes.
- Respect Reduce Motion and Reduce Transparency.
- Provide results through more than one channel where it helps (spoken plus on-screen text).
- Use VoiceOver announcements for asynchronous results so the user is told when something is ready.

Build the empty shell to this standard before adding any feature. If the empty app is not cleanly VoiceOver-navigable, no feature on top of it will be either.

### Offline-first design

There is no online mode to fall back to in the MVP, which simplifies everything. Every feature must function with the network off. The only network-touching code is the optional cloud adapter, which is disabled by default and isolated behind a protocol so the rest of the app never assumes connectivity.

### Caching strategy

Minimal by design. Perception results are transient and do not need persistent caching for the MVP. Model assets that the OS manages (SpeechAnalyzer) are cached by the system. Any custom Create ML models are bundled in Resources. The one thing worth caching is user-facing results the person may want to revisit in a session (the last document read), held in memory, cleared on exit, never written to disk without a reason. Less caching means less to leak.

### Synchronization strategy

For the MVP: settings only, via optional iCloud key-value or CloudKit, which is free and requires no server. Sync is opt-in and limited to preferences (voice speed, enabled features, output profile). User content (images, recognized text) is never synced. When enrollment arrives later, it stays local and is explicitly excluded from any sync by default.

---

## 13. Backend Architecture

### MVP backend: there is none, and that is correct

A privacy-first, offline-first app has nothing to put on a server. Settings live on the device. Optional sync uses iCloud at no cost. There is no user content to store, no auth to manage, no analytics being collected. Proposing a backend with authentication, configuration, and analytics (as the original did) would contradict the privacy stance, add recurring cost you want to avoid, and create an attack surface and a maintenance burden for zero MVP benefit.

State this as a feature: nothing to breach, nothing to fund, nothing to maintain.

### Scale-up backend: only if a concrete need appears, and chosen to preserve the promise

A backend becomes worth considering only when a real need shows up, such as:

- An optional, opt-in cloud-reasoning endpoint for users who want heavier scene analysis than on-device allows.
- Opt-in, anonymized, aggregate telemetry that the user explicitly enables (never on by default).
- Shared configuration or community model distribution.

If that day comes, the design principles are: opt-in only, minimal data, self-hostable so users and the community can run their own, and built on free or free-tier infrastructure first. Authentication, if ever needed, should lean on platform identity (Sign in with Apple) rather than rolling your own credential store. None of this is MVP work.

---

## 14. Infrastructure Architecture

The original prompt asked for Docker, Docker Compose, Kubernetes, and a cloud-hosting and migration plan. Here is the honest assessment: **for a solo-developer, on-device, offline-first iPhone MVP, none of that applies, and adding it would be cargo-culting infrastructure for a system that has no server.** Kubernetes orchestrates containers across machines; you have no containers and no machines. Pretending otherwise would pad the plan and waste your time.

What you actually need:

- **Local development.** Xcode on a Mac, the iPhone 17 Pro for on-device testing. That is the entire toolchain for the MVP.
- **CI/CD.** GitHub Actions, free tier for public repositories, running build, test, and lint on each push and pull request. This is the only "infrastructure" the MVP needs, and it is free.
- **Distribution.** TestFlight for beta testing (free, requires an Apple Developer account, which is the one cost worth flagging: the Apple Developer Program is a paid annual membership required to ship to TestFlight or the App Store; if even that is out of scope, distribution is limited to your own device and source builds). Verify the current Developer Program terms and cost; this is the single place the "zero cost" constraint meets reality.
- **Self-hosting / Docker / cloud.** Relevant only to the optional, far-future cloud-reasoning service, not the app. If that service is ever built, a single small container with Docker and a free-tier host is the starting point, and Kubernetes is a "if you somehow have hundreds of thousands of opt-in cloud users" problem, which is a Phase 5 fantasy to be solved if it ever becomes real, not designed for now.

### Migration path (stated honestly)

```text
MVP:        Xcode + iPhone + GitHub Actions  (no server)
                         |
                         v  (only if optional cloud reasoning is ever added)
Optional:   single Docker container on a free-tier host, self-hostable
                         |
                         v  (only if opt-in cloud users somehow reach large scale)
Scale:      container orchestration, revisited then with real numbers
```

The discipline: do not build infrastructure for problems you do not have. The MVP's correct infrastructure footprint is close to nothing, and that is a direct result of the privacy-first design paying off.

*Continued in Document 4 of 6: Engineering Quality.*
