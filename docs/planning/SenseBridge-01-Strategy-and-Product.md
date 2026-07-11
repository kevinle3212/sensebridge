# SenseBridge Plan, Document 1 of 6: Strategy & Product

*This document covers the Executive Review, Product Vision, User Personas, Funding & Sustainability, and the Final Recommendation. It is written to be combined with Documents 2 through 6. This is strategic and technical analysis, not legal or financial advice.*

---

## 1. Executive Review

Before anything else: the core idea is worth building, but the proposal as written describes roughly five products wearing one name. The single most important thing this review does is separate the part that one developer can ship in six months from the part that is a multi-year, multi-person vision. If you take nothing else from this document, take that distinction seriously.

### What is strong

The strongest parts of the proposal are the principles, not the feature list.

- **Privacy-first, on-device-by-default is a real, defensible position.** It is not marketing. Every leading scene-understanding competitor (Be My AI, the richest parts of Seeing AI, Envision, Aira) depends on the cloud and sends user images to a third party. Be My AI routes images through OpenAI. Security guidance for blind users already tells them to prefer on-device tools when handling confidential documents like bank statements or medical letters. Building offline-first is both an ethical stance and the clearest product wedge you have.
- **"Awareness, not safety" is the correct framing and you arrived at it early.** This single decision protects you legally, sets honest user expectations, and distinguishes you from anyone who over-promises. Keep it as a hard rule, not a guideline.
- **Open-source auditability genuinely matters for an assistive tool.** Blind users are asked to trust a tool with their physical environment and their camera. "You can read the code, you can self-host, the company cannot quietly change the deal" is a real answer to a real fear. Closed competitors cannot make that claim.
- **The unified multi-sense concept is a legitimate insight.** The observation that a person often needs several accessibility services at once, and that switching between single-purpose apps is a daily tax, is correct and under-served. The mistake is trying to deliver all of it at once.

### What is weak

- **The scope is the central weakness and it is severe.** "Blind and deaf and deaf-blind, across phone and watch and AR glasses, with object detection and OCR and speech-to-text and sound detection and navigation and facial recognition" is not a product, it is a category. As written, it is not achievable by one person, and arguably not by a small team in a year. The proposal does not contain a mechanism for saying no, and a solo project that cannot say no will stall.
- **The proposal treats accessibility groups as a list to be served in parallel rather than fundamentally different products.** A blind user's primary channel is audio and the camera points outward at the world. A deaf user's primary channel is visual and the microphone listens to speech. A deaf-blind user needs structured haptics and often a wearable. These are not three output modes of one pipeline. They are three different sensing-and-rendering problems that happen to share infrastructure. Sharing infrastructure is good. Pretending they are one feature is not.
- **React Native is assumed without justification, and it is the wrong call for this specific project** (full reasoning in Document 3). The short version: the hardest and most valuable code here is native Apple-framework code regardless, so React Native adds a layer without buying you anything in a six-month iPhone-only MVP.
- **"Navigation assistance" appears repeatedly and is the most dangerous feature in the document.** Real-time navigation guidance for a blind person is a safety-critical, liability-heavy, technically enormous problem. It sits uneasily next to your own "never claim safety" principle. It should be reframed as obstacle and landmark *awareness*, never as turn-by-turn guidance.

### What is unrealistic

- **The six-month timeline against the full feature list.** The timeline is fine. The feature list attached to it is not.
- **Facial recognition as an MVP feature.** Even consent-based, on-device facial enrollment carries biometric-privacy legal exposure (BIPA, CUBI, Washington's law, GDPR Article 9). The engineering is also nontrivial. This belongs after the MVP, behind a careful consent flow, not in the first build.
- **Wearables and AR glasses in early phases.** Meta glasses run their own SDK and model stack, Apple Vision Pro is visionOS, and Apple Watch is a constrained haptic-and-glance device. Each is a separate integration effort. None should touch the MVP.
- **A backend with authentication, analytics, and configuration services.** For a privacy-first, offline-first app, the MVP needs no backend at all. Proposing one this early contradicts the privacy stance and creates cost and maintenance burden you explicitly want to avoid.

### What is missing

- **A definition of done.** There are no success metrics, no "the MVP is finished when X." Document 2 and the Product Vision section below fix this.
- **A real-user testing plan.** An accessibility tool that has not been used eyes-free by an actual blind person is unvalidated, no matter how clean the code is. This is missing and it is critical.
- **A model-licensing analysis.** This turns out to be the highest-impact technical finding in the entire research effort. Two of the most attractive models are legal traps (see below and Document 3). The proposal does not mention licensing at all.
- **A statement of who the MVP is for.** "Everyone" is not a target user. The MVP target is: blind and low-vision people, on iPhone, using on-device processing.
- **Personal sustainability for the solo developer.** Burnout is the most likely cause of death for a solo open-source project. Nothing in the proposal addresses how you keep going. Document 6 addresses it.

### What should be removed (from the MVP, not necessarily forever)

| Item | Action | Reason |
|---|---|---|
| React Native | Remove | Native Swift is the stronger path for an iPhone-only on-device MVP (Document 3) |
| Real-time navigation guidance | Remove and reframe | Safety-critical, contradicts the awareness principle; reframe as obstacle/landmark awareness |
| Facial recognition | Defer | Biometric legal exposure; not MVP-critical |
| Deaf mode and deaf-blind mode | Defer | Different sensing/rendering problems; dilute a six-month blind-user MVP |
| Wearables and AR glasses | Defer | Separate SDKs and integration efforts each |
| Backend with auth and analytics | Remove for MVP | Offline-first means no server is needed; contradicts privacy stance |
| Ultralytics YOLO | Avoid | AGPL-3.0 license would force your whole project to AGPL (Document 3) |

### What should be added

- A hard model-licensing policy (Apache 2.0 / MIT components only for anything bundled; see Document 5).
- A VoiceOver-first development discipline: the app must be navigable eyes-free before features are added.
- A `SensingSource` / `RenderTarget` protocol abstraction so the deferred multi-sense and wearable work has a real architectural home (Document 3).
- A field-testing relationship with at least one or two blind users, ideally through a local chapter of the National Federation of the Blind or American Council of the Blind.

### Bottom line of the review

The principles are right, the wedge (open + offline + multi-sense) is real, and the timeline is fine. The scope will sink the project unless it is cut hard. The rest of this plan is built around one cut: **blind users, iPhone, on-device, two three-month increments,** with everything else preserved as a credible architectural path rather than an MVP commitment.

---

## 2. Product Vision Review

### Mission statement (refined)

SenseBridge is a free, open-source iPhone app that translates a blind or low-vision person's surroundings into clear spoken information, processing everything on the device by default so the user's camera and surroundings never have to leave their phone.

That is deliberately narrower than the original. It names the user (blind and low-vision), the device (iPhone), the output (spoken), and the wedge (on-device by default). A mission you can hold in one sentence is a mission you can ship against.

### Vision statement (the larger ambition, kept honest)

Over the long term, SenseBridge aims to become an open, auditable sensory-translation layer that adapts its output to the person using it: speech for blind users, captions for deaf users, structured haptics for deaf-blind users, across phones, watches, and glasses. The MVP is the first and smallest true slice of that layer, not a demo of all of it.

Stating the large vision is fine. The discipline is in refusing to build it all at once.

### Long-term goals

1. A blind-user iPhone app that people use daily and prefer to alternatives for at least one concrete task (likely reading mail and documents).
2. A clean enough architecture that adding deaf-user captioning later is a new `RenderTarget`, not a rewrite.
3. A small but real contributor community, enabled by genuinely good documentation and a welcoming contribution process.
4. A sustainable funding base (grants plus sponsorship) that does not compromise the open-source, no-paid-API promise.
5. Optional expansion to Apple Watch (haptic glances), Vision Pro, and eventually Meta glasses, each as a deliberate, separately-scoped effort.

### Success metrics

Vanity metrics (GitHub stars, downloads) are not success here. Use these instead.

| Metric | What it tells you | MVP-stage target |
|---|---|---|
| Eyes-free task completion rate | Can a blind user actually finish a task without sighted help | A blind tester can read a document and identify common objects unaided |
| Repeat usage by real blind testers | Whether it is useful, not just functional | At least 1 to 2 testers choosing to use it in real life |
| On-device processing share | Whether the privacy promise holds | 100% of MVP features run with no network call |
| VoiceOver navigability | Whether the app itself is accessible | Every screen and control fully operable via VoiceOver |
| Time-to-first-useful-output | Latency from camera to spoken result | Fast enough to feel responsive on iPhone 17 Pro (benchmark on device) |
| Crash-free sessions | Basic reliability | High enough that testers are not abandoning it |

### North-star metric

**Number of real-world tasks a blind user completes per week using SenseBridge without sighted assistance.**

This single metric resists gaming, ignores hype, and points directly at the mission. If it goes up, the product is working. If it is flat, more features will not save it.

---

## 3. User Personas

These are written to keep development honest about who you are actually serving. The MVP serves the first persona. The others document why the deferred work matters and what it will need, so the architecture does not paint itself into a corner.

### Persona 1: Blind user (the MVP target)

**Who.** A working-age adult, fully blind or with very limited vision, fluent with VoiceOver, who already uses an iPhone competently. Possibly employed or seeking employment (affordability of tools is not abstract: only roughly a third to 44% of working-age blind and visually impaired US adults are employed, per AFB/Cornell and NHIS data). Uses a cane or guide dog for mobility and is not looking for the app to replace either.

> **Accuracy note (verified June 2026):** The widely repeated "70% of blind people are unemployed" figure is imprecise. It actually refers to the share *not employed* (the employment-population gap), not the formal BLS unemployment rate, which for people with vision difficulty was about 10% in 2024 versus about 4% for those without. The honest, defensible framing is "a majority of working-age blind adults are not employed," not "70% unemployment." See Document 7 for sources.

**Daily workflows.** Reads physical mail and packaging. Identifies objects when sorting or shopping. Wants quick descriptions of unfamiliar spaces ("what is in front of me right now"). Navigates known routes with existing mobility skills and wants awareness of unexpected obstacles, not turn-by-turn directions.

**Pain points.** Cloud apps feel slow and raise privacy worries for sensitive documents. Subscription costs add up. Switching between single-purpose apps is friction. Existing free tools (Apple's own) are good but capped and closed, and explicitly warn they are not for navigation.

**Accessibility needs.** Everything spoken, clearly and concisely. Full VoiceOver operability of the app itself. Output that is honest about uncertainty ("possible stairs ahead," never "safe to cross"). Low latency. Works offline.

### Persona 2: Deaf user (deferred, Phase 3+)

**Who.** A deaf or hard-of-hearing adult who reads text fluently and relies on visual information.

**Daily workflows.** Wants live captions of in-person conversations and awareness of sounds they cannot hear (a name being called, an alarm, a knock).

**Pain points.** Captioning apps are largely cloud-based (Ava) or platform-locked (Google Live Transcribe is strong but Android-centric). Apple Live Captions exist on-device but are closed and limited.

**Accessibility needs.** Accurate on-device speech-to-text (iOS 26 SpeechAnalyzer makes this feasible later), clear visual presentation, sound-event alerts. This is a different sensing problem (microphone in, text out) than the blind use case, which is why it is deferred rather than bundled.

### Persona 3: Deaf-blind user (deferred, later phase, needs co-design)

**Who.** A person with combined significant hearing and vision loss, possibly a Protactile user.

**Daily workflows.** Relies on touch and structured haptic information. May use a smartwatch or wearable for vibration cues.

**Pain points.** Almost nothing in mainstream tech is designed for this group. Haptic vocabularies are ad hoc.

**Accessibility needs.** A designed haptic language, not arbitrary buzzes. This cannot be designed *for* deaf-blind users in isolation; it must be designed *with* them. Established tactile systems (Lorm, Malossi) and the perceptual realities of vibration (useful range roughly 10 to 200 Hz, resonance around 60 to 70 Hz, more distinguishable messages when you combine squeeze, stretch, and vibration) are the starting point. This is real research work and is correctly deferred.

### Persona 4: Caregiver

**Who.** A family member, friend, or professional who supports a user.

**Role in the product.** Mostly: should be able to help set the app up and then get out of the way. The product should never require a caregiver to function. A caregiver-facing feature worth considering much later is consent-based assistance (for example, helping enroll a known face), but the user must always own the decision.

### Persona 5: Family member

**Who.** Someone the user wants the app to be able to recognize by name, with that person's consent.

**Role in the product.** This persona exists to justify the consent-based enrollment design: enrollment is opt-in, the enrolled person should consent, the data stays on-device and encrypted, and unknown people are only ever labeled "person." This persona is the reason the facial feature is deferred and handled carefully, not dropped.

### Persona 6: Accessibility advocate

**Who.** A member of the blindness or Deaf community, a chapter organizer, an accessibility professional, or an open-source contributor who cares about this space.

**Role in the product.** Early testers, credibility, distribution, and contribution. This persona is your path to real-user validation and to the contributor community. Engaging advocates early (NFB, ACB, Deaf community organizations, GitHub's accessibility open-source initiatives) is worth more than any amount of solo polishing.

---

## 4. Funding & Sustainability

The constraint is firm: free to build, no paid APIs, nothing beyond your Claude subscription. That rules out infrastructure-heavy funding needs, which is convenient, because an offline-first app barely has running costs. The funding question is therefore less "how do I pay server bills" and more "how do I sustain effort and maybe grow."

### Grants (the most promising path, no equity, mission-aligned)

- **Microsoft AI for Accessibility.** Has historically offered Azure credits (reported in the $10,000 to $20,000 range) plus mentorship to accessibility projects. Azure credits do not fit a no-cloud app directly, but the mentorship, credibility, and any unrestricted component are valuable. Worth an application once you have a working demo.
- **NSF-adjacent accessibility ecosystems** (AccessComputing, CREATE at the University of Washington) are more research-oriented but are strong network and credibility sources, and sometimes funding.
- **Disability-focused foundations and tech-for-good programs.** These vary year to year; the pattern that works is: have a working artifact and real users first, then apply.

Reality check: grants reward traction, not ideas. Do not wait for a grant to start, and do not build features speculatively to chase one. Build the MVP, get real blind testers, then apply with evidence.

### Community funding (low overhead, fits open-source)

- **GitHub Sponsors.** Zero platform fees, integrates with the repo, lowest-friction way to accept recurring support. Set this up once the repo is public and has something to show.
- **Open Collective.** Transparent, good for accountability, and can route tax-deductible donations if you attach a fiscal sponsor (Software Freedom Conservancy, NumFOCUS, and similar). Useful if the project grows beyond you.

### Precedents worth studying

Open-source assistive tech has sustained itself before. NVDA (the free Windows screen reader) runs on donations and grants through NV Access. OptiKey and EyeMine (eye-control software) grew from solo or tiny-team open-source efforts. The lesson is consistent: usefulness and community come first, money follows, and the projects that survive are the ones that solved a real problem for real people before asking for support.

### Optional premium services (only if you ever want them, without breaking the promise)

If sustainability ever demands revenue, the open-source-safe pattern is to keep the app and all core features free and open, and offer optional *services* on top: a hosted optional cloud-reasoning endpoint for users who opt in and want heavier scene analysis, paid support or integration for organizations, or a managed self-hosting offering. The core promise (free, open, offline-capable) stays intact. This is a far-future consideration and should not shape the MVP.

### The honest funding verdict

For the MVP, you need no money, and that is a strength, not a limitation. Treat funding as something you pursue *after* you have a working app and real users, never as a prerequisite. The most dangerous funding mistake a solo project makes is building for funders instead of users.

---

## 5. Final Recommendation

This section is written as if approving or rejecting the project for development effort. The verdict is a qualified yes, conditional on the scope cut.

### What should be built first

In order:

1. The VoiceOver-first app shell. Nothing else until a blind user can navigate the empty app cleanly.
2. Document and text reading: Apple Vision OCR (including iOS 26 document and table recognition) feeding AVSpeechSynthesizer and VoiceOver. This is the feature most likely to earn daily use.
3. Object and scene labeling using Apple's Vision framework.
4. Then, in the second increment: LiDAR-based obstacle *awareness*, on-device sound-event alerts, and natural-language scene description via the two-stage Vision-to-Foundation-Models pipeline (Document 3 explains why it must be two stages).

### What should be delayed

Deaf captioning, deaf-blind haptic language, facial enrollment, Apple Watch, Apple Vision Pro, Meta glasses, and any backend. All preserved as architecture, none built in the first six months.

### Biggest risks

1. **Scope re-expansion.** The most likely failure mode. The plan cuts hard; the temptation to add "just one more group" or "just the watch" will be constant. Resist it.
2. **No real-user validation.** Building in isolation produces a technically clean tool that blind people do not find useful. Get testers early.
3. **The on-device quality ceiling.** Apple Foundation Models is text-only with a small context window, so rich scene reasoning is composed from labels rather than true image understanding. This is a real quality gap versus cloud competitors, and you must design around it honestly rather than pretend it is closed.
4. **Solo-developer burnout.** Addressed in Document 6, but it is a top-tier risk, not a footnote.
5. **Licensing missteps.** Pulling in an AGPL model (Ultralytics YOLO) or a non-commercial Apple research model (FastVLM, MobileCLIP) would poison the project. Document 3 and Document 5 cover this.

### Biggest opportunities

1. **Being the only open-source, offline-first, multi-sense-capable option.** No competitor occupies this space. That is a durable position.
2. **Privacy as a feature blind users can feel,** not a compliance checkbox: their sensitive mail never leaves the phone.
3. **A credible architecture for the larger vision** that lets the project grow into deaf and deaf-blind support and wearables without a rewrite, which is rare and valuable.
4. **Community and grant momentum** in a space where genuinely good open tools are scarce.

### Probability of success

It depends entirely on how success is defined.

- Probability of shipping a useful, VoiceOver-accessible, on-device blind-user iPhone MVP in roughly six months, solo: **moderate to good, perhaps 60 to 70%,** if and only if the scope cut holds and real testers are involved.
- Probability of delivering the full original vision (all disability groups, all devices) solo in that window: **near zero.** Not a knock on you; it is true of anyone.
- Probability of the project becoming a sustained, funded, multi-sense platform: **low but nonzero, and entirely downstream of nailing the narrow MVP first.**

### Final verdict

**Approved, conditional on the scope cut.** The idea is sound, the wedge is real, the principles are right, and the timeline is fine for the *narrowed* MVP. The project should proceed as a blind-user, iPhone, on-device, two-increment build, with the broader vision preserved in the architecture and explicitly deferred in the roadmap. Reject the project as originally scoped (all groups, all devices, with backend and facial recognition in the MVP); approve it as scoped here.

The harshest and most useful thing to say: the difference between this project succeeding and stalling is almost entirely about what you refuse to build in the first six months.

*Continued in Document 2 of 6: Features & Scope.*
