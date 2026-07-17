# SenseBridge: Complete Technical & Strategic Plan

*A consolidated planning document for SenseBridge, a free, open-source, privacy-first iPhone accessibility app for blind and low-vision users, with a credible architectural path to deaf, deaf-blind, and wearable support over time. Compiled from seven working documents into one file. Strategic and technical analysis, not legal or financial advice; the legal and licensing content is factual source verification and should be confirmed with a licensed attorney before any biometric feature ships.*

*Last verified: June 2026. Where a claim was independently checked against primary sources, an accuracy note appears inline and the source is listed in the References section at the end.*

---

## How to read this document

This plan deliberately narrows an ambitious brief. The original concept aimed to serve blind, deaf, and deaf-blind users across phones, watches, and AR glasses at once. That is not buildable by one developer in six months, so the plan scopes the MVP to **blind users, on iPhone, fully on-device, in two three-month increments**, and preserves everything else as architecture and roadmap rather than as a commitment. If you read only one thing, read the Executive Review (Section 1) and the Final Recommendation (Section 22).

The document is organized in three parts:

- **Part One (Sections 1 to 22):** the full plan, from strategy through architecture, engineering, governance, security, and legal.
- **Part Two (Verification, Alternatives & Rationale):** what was independently verified and corrected, every free-versus-paid choice with the free option set as the default, and the reasoning behind the licensing and legal recommendations.
- **References:** linked primary sources, grouped by topic, so the research behind the claims is visible and checkable.

---

## Table of contents

**[Part One: The Plan](#part-one-the-plan)**

1. [Executive Review](#1-executive-review)
2. [Product Vision Review](#2-product-vision-review)
3. [User Personas](#3-user-personas)
4. [Funding & Sustainability](#4-funding--sustainability)
5. [Final Recommendation](#5-final-recommendation)
6. [Feature Audit](#6-feature-audit)
7. [Feature Decomposition](#7-feature-decomposition)
8. [MVP Definition](#8-mvp-definition)
9. [Roadmap](#9-roadmap)
10. [System Architecture](#10-system-architecture)
11. [AI Architecture](#11-ai-architecture)
12. [Mobile Architecture](#12-mobile-architecture)
13. [Backend Architecture](#13-backend-architecture)
14. [Infrastructure Architecture](#14-infrastructure-architecture)
15. [Accessibility Engineering Review](#15-accessibility-engineering-review)
16. [Testing Strategy](#16-testing-strategy)
17. [Observability & Reliability](#17-observability--reliability)
18. [Scalability Analysis](#18-scalability-analysis)
19. [Open Source Strategy](#19-open-source-strategy)
20. [Security Review](#20-security-review)
21. [Legal & Compliance Review](#21-legal--compliance-review)
22. [Repository Design](#22-repository-design)

Other notes in Part One: [The framework decision](#the-framework-decision-stated-up-front) and [Miscellaneous & Remarks](#miscellaneous--remarks).

**[Part Two: Verification, Alternatives & Rationale](#part-two-verification-alternatives--rationale)**

- [Part A: Verification Log](#part-a-verification-log) (confirmed, corrected, and items needing your check)
- [Part B: Free-vs-Paid Alternatives](#part-b-free-vs-paid-alternatives) (free set as default, with pros and cons)
- [Part C: Licensing & Legal Rationale](#part-c-licensing--legal-rationale)

**[References](#references)** (linked primary sources, grouped by topic)

> **Note on the links (please read before converting to PDF):** the entries above are clickable anchors that use GitHub-style heading IDs. They work out of the box when the file is viewed as a web page on GitHub, in VS Code's markdown preview, and in most static-site renderers. Two caveats for PDF:
>
> - **Browser "print to PDF":** open the rendered page (for example on GitHub) and print to PDF. Internal anchor links are preserved by most current browsers, so the TOC stays clickable.
> - **Pandoc:** Pandoc computes heading IDs differently from GitHub (it strips the leading section number, so its ID for "1. Executive Review" is `executive-review`, not `1-executive-review`). Because of that, the manual links above will not all resolve under Pandoc. The reliable fix is to let Pandoc build its own clickable table of contents and PDF bookmarks: `pandoc SENSEBRIDGE-COMPLETE-PLAN.md -o SenseBridge.pdf --toc --pdf-engine=xelatex`. That generates a navigable PDF regardless of the manual TOC.
>
> If you would like, I can generate the PDF for you directly with a working clickable contents, so you do not have to install anything.

---

# Part One: The Plan

## Strategy & Product (Sections 1 to 5)

*This group of sections covers the Executive Review, Product Vision, User Personas, Funding & Sustainability, and the Final Recommendation. This is strategic and technical analysis, not legal or financial advice.*

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
- **React Native is assumed without justification, and it is the wrong call for this specific project** (full reasoning in the Technical Architecture sections). The short version: the hardest and most valuable code here is native Apple-framework code regardless, so React Native adds a layer without buying you anything in a six-month iPhone-only MVP.
- **"Navigation assistance" appears repeatedly and is the most dangerous feature in the document.** Real-time navigation guidance for a blind person is a safety-critical, liability-heavy, technically enormous problem. It sits uneasily next to your own "never claim safety" principle. It should be reframed as obstacle and landmark *awareness*, never as turn-by-turn guidance.

### What is unrealistic

- **The six-month timeline against the full feature list.** The timeline is fine. The feature list attached to it is not.
- **Facial recognition as an MVP feature.** Even consent-based, on-device facial enrollment carries biometric-privacy legal exposure (BIPA, CUBI, Washington's law, GDPR Article 9). The engineering is also nontrivial. This belongs after the MVP, behind a careful consent flow, not in the first build.
- **Wearables and AR glasses in early phases.** Meta glasses run their own SDK and model stack, Apple Vision Pro is visionOS, and Apple Watch is a constrained haptic-and-glance device. Each is a separate integration effort. None should touch the MVP.
- **A backend with authentication, analytics, and configuration services.** For a privacy-first, offline-first app, the MVP needs no backend at all. Proposing one this early contradicts the privacy stance and creates cost and maintenance burden you explicitly want to avoid.

### What is missing

- **A definition of done.** There are no success metrics, no "the MVP is finished when X." the Features and Scope sections and the Product Vision section below fix this.
- **A real-user testing plan.** An accessibility tool that has not been used eyes-free by an actual blind person is unvalidated, no matter how clean the code is. This is missing and it is critical.
- **A model-licensing analysis.** This turns out to be the highest-impact technical finding in the entire research effort. Two of the most attractive models are legal traps (see below and the Technical Architecture sections). The proposal does not mention licensing at all.
- **A statement of who the MVP is for.** "Everyone" is not a target user. The MVP target is: blind and low-vision people, on iPhone, using on-device processing.
- **Personal sustainability for the solo developer.** Burnout is the most likely cause of death for a solo open-source project. Nothing in the proposal addresses how you keep going. the Miscellaneous and Remarks section addresses it.

### What should be removed (from the MVP, not necessarily forever)

| Item | Action | Reason |
| --- | --- | --- |
| React Native | Remove | Native Swift is the stronger path for an iPhone-only on-device MVP (the Technical Architecture sections) |
| Real-time navigation guidance | Remove and reframe | Safety-critical, contradicts the awareness principle; reframe as obstacle/landmark awareness |
| Facial recognition | Defer | Biometric legal exposure; not MVP-critical |
| Deaf mode and deaf-blind mode | Defer | Different sensing/rendering problems; dilute a six-month blind-user MVP |
| Wearables and AR glasses | Defer | Separate SDKs and integration efforts each |
| Backend with auth and analytics | Remove for MVP | Offline-first means no server is needed; contradicts privacy stance |
| Ultralytics YOLO | Avoid | AGPL-3.0 license would force your whole project to AGPL (the Technical Architecture sections) |

### What should be added

- A hard model-licensing policy (Apache 2.0 / MIT components only for anything bundled; see the Governance and Legal sections).
- A VoiceOver-first development discipline: the app must be navigable eyes-free before features are added.
- A `SensingSource` / `RenderTarget` protocol abstraction so the deferred multi-sense and wearable work has a real architectural home (the Technical Architecture sections).
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
| --- | --- | --- |
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

> **Accuracy note (verified June 2026):** The widely repeated "70% of blind people are unemployed" figure is imprecise. It actually refers to the share *not employed* (the employment-population gap), not the formal BLS unemployment rate, which for people with vision difficulty was about 10% in 2024 versus about 4% for those without. The honest, defensible framing is "a majority of working-age blind adults are not employed," not "70% unemployment." See Part Two for sources.

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
4. Then, in the second increment: LiDAR-based obstacle *awareness*, on-device sound-event alerts, and natural-language scene description via the two-stage Vision-to-Foundation-Models pipeline (the Technical Architecture sections explains why it must be two stages).

### What should be delayed

Deaf captioning, deaf-blind haptic language, facial enrollment, Apple Watch, Apple Vision Pro, Meta glasses, and any backend. All preserved as architecture, none built in the first six months.

### Biggest risks

1. **Scope re-expansion.** The most likely failure mode. The plan cuts hard; the temptation to add "just one more group" or "just the watch" will be constant. Resist it.
2. **No real-user validation.** Building in isolation produces a technically clean tool that blind people do not find useful. Get testers early.
3. **The on-device quality ceiling.** Apple Foundation Models is text-only with a small context window, so rich scene reasoning is composed from labels rather than true image understanding. This is a real quality gap versus cloud competitors, and you must design around it honestly rather than pretend it is closed.
4. **Solo-developer burnout.** Addressed in the Miscellaneous and Remarks section, but it is a top-tier risk, not a footnote.
5. **Licensing missteps.** Pulling in an AGPL model (Ultralytics YOLO) or a non-commercial Apple research model (FastVLM, MobileCLIP) would poison the project. the Technical Architecture sections and the Governance and Legal sections cover this.

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

---

## Features & Scope (Sections 6 to 9)

*This group of sections covers the Feature Audit, Feature Decomposition, MVP Definition, and Roadmap.*

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
| Technical complexity | Moderate. Must be a two-stage pipeline: Apple Vision produces labels and text, Apple Foundation Models composes a sentence (Foundation Models is text-only, cannot take an image). See the Technical Architecture sections |
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
| Risks | High on the legal axis. Biometric-privacy laws (BIPA, CUBI, Washington, GDPR Article 9) apply even on-device. Requires a careful consent flow and on-device-only, encrypted, deletable storage. See the Governance and Legal sections |
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

Each feature breaks into independently buildable, independently testable modules. This is what makes a solo build tractable: you ship and verify one module at a time, and every module has a clear input and output. The shared abstraction beneath all of them is a `SensingSource` (something that produces perception data) and a `RenderTarget` (something that delivers output to the user). the Technical Architecture sections details these.

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
- **Language composition module.** Feeds the structured record to Apple Foundation Models with a careful prompt and guided generation, producing a hedged sentence. Input: perception record. Output: a sentence. (Two-stage by necessity; see the Technical Architecture sections.)
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

Tie back to the Strategy sections' metrics: 100% on-device, full VoiceOver navigability, at least one or two blind testers using it for real tasks, and a measurable count of tasks completed without sighted help. If those hold, the MVP succeeded regardless of star count.

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

---

## Technical Architecture (Sections 10 to 14)

*This group of sections covers System Architecture, AI Architecture, Mobile Architecture, Backend Architecture, and Infrastructure. This is the technical core. The Governance, Security & Legal sections cover model licensing law in more depth.*

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

Every recommendation here is filtered through three constraints: it must be free, it should run on-device, and its license must not poison an open-source project. The licensing point is not a footnote; it eliminates two of the most attractive models outright. the Governance and Legal sections covers licensing law; this section covers the engineering choice.

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

### The two licensing traps (critical; rationale in Sections 19 and 21, sources under References: Model licenses)

- **Ultralytics YOLO (v8, v11, and newer) is AGPL-3.0.** Bundling it forces your entire project, code, configs, and weights, to AGPL, or to buy an Enterprise License. For an open-source project that wants permissive licensing and future flexibility, this is a poison pill. Use Apple Vision detection instead.
- **Apple FastVLM is released under the `apple-amlr` non-commercial research license** (verified across its 0.5B, 1.5B, and 7B variants on Hugging Face, June 2026). It is technically excellent and tempting. It is not usable in a shipping app. Do not bundle it. (One secondary blog described FastVLM as "permissive." The authoritative Hugging Face license tag and the AMLR terms say non-commercial. The AMLR license explicitly limits use to "Research Purposes," defined as non-commercial scientific research, and excludes any commercial product or service.)
- **Apple MobileCLIP has mixed, unsettled licensing and should be quarantined, not bundled.** Verification (June 2026) found Apple's own MobileCLIP repositories mix license signals: the LICENSE file inside the repo is the restrictive `apple-amlr` (non-commercial research only), while a separate weights/data license file is the permissive Apple Sample Code License, and the repo metadata carries both tags. Until Apple clarifies in writing, treat MobileCLIP as non-commercial/research-only and do not ship it in anything you might monetize. An earlier draft stated flatly that MobileCLIP is `apple-amlr`; the honest position is that its license is ambiguous and must be confirmed with Apple before any product use.

### Resource and privacy notes

- Apple frameworks run on the Neural Engine and GPU, are tuned for the device, and add nothing to your bundle size for system-managed models (SpeechAnalyzer assets, for example, are downloaded and managed by the OS).
- Foundation Models requires Apple Intelligence (iPhone 15 Pro and later), so you must implement availability checks and a graceful fallback (label lists instead of composed sentences) for unsupported devices.
- Everything above is on-device and private by default. The only path off-device is the optional, opt-in cloud adapter.

### Face recognition architecture (deferred, designed now)

When it arrives: Apple Vision detects faces; you compute embeddings on-device; you match only against people the user has explicitly enrolled with consent; embeddings live in an encrypted on-device store and never leave the phone; unknown faces are only ever labeled "person." No cloud, no public recognition, ever. The legal framing is in the Governance and Legal sections.

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
    ...                           # mirrors structure (see the Engineering Quality sections)
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

---

## Engineering Quality (Sections 15 to 18)

*This group of sections covers the Accessibility Engineering Review, Testing Strategy, Observability & Reliability, and Scalability Analysis. Read alongside the Technical Architecture sections (Technical Architecture).*

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
- **No remote metrics by default.** If, much later, you want aggregate performance data, it must be opt-in, anonymized, and minimal (see the Technical Architecture sections' scale-up backend notes).

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
| 100,000 | Governance, trust, App Store relationship | Project bus-factor; reputation | Real governance (the Governance and Legal sections); maybe nonprofit/fiscal sponsor |
| 1,000,000 | Sustainability and stewardship of a critical tool | Funding and continuity | Grants, sponsorship, possible nonprofit; succession planning |

### The real bottleneck is you, not infrastructure

At every level above, the constraint is the solo developer's time, attention, and continuity, not compute. This reframes scalability entirely: the way SenseBridge "scales" is by growing a contributor community and a governance and funding structure, not by adding servers. That is why the Governance and Legal sections' open-source strategy and the Strategy sections' funding section are the actual scalability plan, and the infrastructure section is nearly empty.

### The one place server scale could appear

If the optional, opt-in cloud-reasoning service is ever built and somehow attracts heavy use, that service would face conventional scaling questions (and conventional costs). The answer is the same as in the Technical Architecture sections: keep it self-hostable so load distributes across the community's own machines rather than concentrating on you, and only solve large-scale orchestration if real numbers ever demand it. For the app itself, scale is a non-issue by design.

---

## Governance, Security & Legal (Sections 19 to 22)

*This group of sections covers Open Source Strategy, Security Review, Legal & Compliance, and Repository Design. The legal section is informational only and is not legal advice; verify everything with qualified counsel before enabling any biometric feature or shipping.*

---

## 19. Open Source Strategy

### Licensing recommendation: Apache 2.0 for SenseBridge's own code

The license choice matters more than it looks, because it interacts with the model-licensing traps and with the project's possible nonprofit or commercial future.

Comparison of the realistic options:

| License | Effect | Fit for SenseBridge |
| --- | --- | --- |
| MIT | Permissive, minimal, no explicit patent grant | Good, but Apache's patent grant is worth having for an AI project |
| Apache 2.0 | Permissive, explicit patent grant, contributor terms | **Recommended.** Permissive enough for adoption and future flexibility; patent grant protects users and contributors |
| GPL-3.0 | Copyleft; derivatives must be GPL | Possible if you want to force openness, but limits flexibility |
| AGPL-3.0 | Strong copyleft including network use | Only if you specifically want to prevent proprietary forks, including SaaS; sacrifices flexibility and scares off some contributors |

**Recommendation: Apache 2.0.** It is permissive, includes a patent grant (valuable when AI and patents intersect), is compatible with bundling MIT and Apache-licensed models (whisper.cpp, SmolVLM, YAMNet, Tesseract), and preserves every future path: nonprofit, community, or eventual commercial services. Choose AGPL only if your priority is preventing anyone from making a closed fork or closed SaaS, and accept that this reduces flexibility and contributor appeal.

Hard rules that follow from the license choice:

- **Do not bundle AGPL components** (Ultralytics YOLO), because they would force the whole project to AGPL or an Enterprise License. Use Apple Vision detection instead.
- **Do not bundle FastVLM** (`apple-amlr`, confirmed non-commercial research only across all variants).
- **Quarantine MobileCLIP** until Apple clarifies its license in writing. Apple's MobileCLIP repositories carry conflicting license signals (a restrictive `apple-amlr` LICENSE file alongside a permissive Apple Sample Code License weights file and dual metadata tags), so its commercial usability is ambiguous. Do not ship it in anything you might monetize until that is resolved.
- **Vet any Apple research model's license tag directly** before use; `apple-amlr` means non-commercial research only.
- **Vet every dependency's license** before adding it. Prefer MIT and Apache 2.0.

### Governance model

For a solo project, "governance" sounds premature, but lightweight governance from day one is what lets the project survive your eventually needing help.

- **Start as Benevolent Dictator (you), documented openly.** State that you are the maintainer and decision-maker for now, and that this is expected to evolve.
- **Define how decisions get made and how that changes** as contributors arrive (for example, moving toward a small maintainer group once there are sustained contributors).
- **Plan for bus-factor early.** The single biggest governance risk in a solo project is that it dies if you stop. Document everything well enough that someone else could pick it up, and consider a fiscal sponsor (Software Freedom Conservancy, NumFOCUS) if the project grows, both for funding and for institutional continuity.

### Contribution process

- A clear `CONTRIBUTING.md` explaining how to set up, build, test, and submit changes.
- A `CODE_OF_CONDUCT.md` (the Contributor Covenant is the standard choice).
- Issue templates (bug, feature, accessibility issue) and a pull request template (what changed, how tested, accessibility impact).
- A required accessibility check in the PR template, since accessibility regressions are the most damaging kind here.
- Good "first issue" labels to welcome newcomers, especially accessibility-minded ones.

### Documentation requirements

Documentation is not optional for an open-source accessibility project; it is how you get contributors and how you survive. At minimum:

- A `README` that explains the mission, the scope (and the deliberate non-scope), and how to build and run.
- Architecture docs (the protocol abstractions, the perception-reasoning-output layering from the Technical Architecture sections).
- An accessibility guide for contributors (how to test with VoiceOver, the labeling standards).
- A clear statement of the awareness-not-safety principle and why it shapes the code.

### Security policy

A `SECURITY.md` with how to report vulnerabilities privately, expected response, and scope. For an app handling cameras and (later) biometric data, this is essential trust infrastructure.

### Community guidelines

Set the tone early: this is an accessibility project, accessibility regressions are taken seriously, and the community includes disabled people whose lived expertise outranks abstract opinions. Lead with that.

### GitHub's accessibility open-source on-ramps

GitHub has run accessibility-focused open-source initiatives (a GAAD pledge, accessibility summits, and assistive-technology hackathons). These are worth engaging for visibility, contributors, and credibility once the repo is public and has something to show.

---

## 20. Security Review

The security posture is unusually favorable because of the privacy-first design: with no backend and no data leaving the device, most classic attack surfaces simply do not exist for the MVP. The security work concentrates on the device, the (later) biometric data, the supply chain, and the optional cloud path.

### Data protection

- **No server, no central data store, nothing to breach.** This is the strongest security property the project has, and it is a direct result of the architecture.
- **User content stays on-device and transient.** Images and recognized text are processed and discarded, not persisted without reason.
- **Settings sync (optional) carries only preferences,** never content, and uses Apple's iCloud security model.

### Face recognition storage (deferred, designed securely now)

When enrollment is built:

- Face embeddings live only on the device, in an **encrypted store** (Keychain-protected keys; data protection classes that require device unlock).
- Embeddings **never leave the device** and are **explicitly excluded from any sync** by default.
- The user can **view and delete** enrolled data at any time.
- Only **consent-enrolled** people are matched; everyone else is "person." No public or open-ended recognition, ever.

### Encryption

- Use iOS Data Protection (file protection classes) for anything sensitive at rest.
- Use the Keychain for secrets and keys.
- If the optional cloud adapter is enabled by a user, any provider credentials they supply go in the Keychain, never in plain files or logs.

### Secrets management

- The MVP has essentially no secrets (no backend, no API keys).
- The optional cloud adapter, if a user configures a provider, stores that user's own credential in the Keychain. The project ships no secrets of its own.
- CI (GitHub Actions) uses repository secrets for any signing credentials; never commit signing keys or certificates.

### Authentication

- The MVP needs none (no accounts, no server).
- If anything ever does, prefer Sign in with Apple over a custom credential store, to avoid handling passwords at all.

### Supply chain security

This is where a solo open-source project is most exposed, because dependencies are trust.

- **Minimize dependencies.** Every dependency is attack surface and a license risk. The Apple-frameworks-first approach helps here: most capability comes from the OS, not third-party packages.
- **Pin and review dependencies;** vet licenses and provenance before adding.
- **Enable GitHub's supply-chain features** (Dependabot alerts, secret scanning) on the repo, all free.
- **Verify model provenance and license** for any bundled model (the AGPL and AMLR traps are supply-chain issues as much as legal ones).
- **Protect the release pipeline.** Signing keys are the crown jewels; keep them out of the repo and in CI secrets or local secure storage.

### Security review summary

| Area | MVP risk | Control |
| --- | --- | --- |
| Backend breach | None (no backend) | Architectural; keep it that way |
| User content leak | Low (transient, on-device) | Do not persist or log content |
| Biometric data (later) | High if mishandled | Encrypted, on-device-only, deletable, consent-gated |
| Secrets | Low (almost none) | Keychain; CI secrets; no committed keys |
| Supply chain | Moderate (the real risk) | Minimize deps, vet licenses, Dependabot, verify models |
| Cloud adapter (opt-in) | User-controlled | Off by default, isolated, user's own credentials in Keychain |

---

## 21. Legal & Compliance Review

**This is informational, not legal advice. Biometric and accessibility law is a fast-moving patchwork and varies by jurisdiction. Consult qualified counsel before enabling any facial feature or shipping publicly.**

### The single most important legal-design decision: awareness, not safety

The strongest legal protection the project has is honest framing. The system must never claim safety, never guarantee obstacle or crosswalk detection, never say "safe to cross." It provides cautious, probabilistic awareness ("possible stairs ahead") and explicitly tells users it is not a mobility or safety device and does not replace a cane, guide dog, or orientation-and-mobility training. This framing should appear in the app copy, the spoken output, onboarding, the README, and the terms of service. It mirrors how Apple itself disclaims its own detection features. This is not just ethics; it is the primary liability shield.

### Biometric privacy (facial enrollment, deferred)

Even though enrollment is on-device, consent-based, and never transmitted, biometric law can still apply, and the penalties are severe.

- **Illinois BIPA.** Has a private right of action and has produced very large settlements (the Facebook/Meta settlement was $650 million, approved 2021). Even on-device face templates can fall within its scope. Requires informed, written consent and a retention/deletion policy. Note two recent shifts that soften but do not neutralize it: an August 2024 amendment (SB 2979) capped statutory damages on a per-person rather than per-violation basis and confirmed electronic consent is valid, and an April 2026 Seventh Circuit ruling (Clay v. Union Pacific) addressed retroactivity of damages. BIPA remains the most potent biometric statute in the US because of its private right of action; the recent changes reduce the worst-case exposure but do not remove the consent and retention obligations.
- **Texas CUBI.** Enforced solely by the Attorney General, with no private right of action. The statute (Tex. Bus. & Com. Code 503.001) provides a civil penalty of up to $25,000 per violation, which scales into the billions across millions of users: the Meta settlement was $1.4 billion (July 2024) and the Google settlement was $1.375 billion (announced May 2025, finalized October 31, 2025). Texas's broader AI law landscape (TRAIGA) is also evolving with provisions taking effect in 2026; verify the exact effective date and biometric provisions against the enrolled bill.
- **Washington's biometric law** and a growing list of other state laws (20-plus states have or are developing relevant statutes).
- **GDPR Article 9** treats biometric data used for identification as a special category requiring explicit consent and strong justification.
- **CCPA/CPRA** treats biometric information as sensitive personal information.

Design consequences (all already in the plan): opt-in only, informed written consent at enrollment, on-device-only encrypted storage, never transmitted, user-viewable and user-deletable, only consented individuals matched, everyone else "person," no public recognition. This is both the ethical design and the legally safest one. Still: get counsel before shipping any of it.

### Accessibility law (ADA and best practice)

- The ADA and related accessibility expectations generally push toward making things *more* accessible, which is the project's entire purpose, so it is largely a tailwind rather than a compliance burden for an assistive tool.
- The liability concern is the inverse: an assistance tool that is mistaken for a safety device. The awareness-not-safety framing is the answer. Make the limitation prominent and repeated.

### Consent requirements (summary)

- **Camera and microphone:** standard iOS permission prompts with clear purpose strings.
- **Facial enrollment (later):** explicit, informed, written-style consent, ideally from the person being enrolled, with easy deletion.
- **Optional cloud processing:** explicit opt-in, clear disclosure of what is sent where, off by default.

### Terms of service and disclaimers

A plain-language ToS and disclaimer should: state it is not a safety or medical device, disclaim warranties to the extent allowed, explain that outputs may be inaccurate, and reinforce that it supplements and never replaces mobility aids and training. Plain language matters here because the users include people relying on screen readers; the legal text must itself be accessible.

### Compliance summary

| Area | Obligation | Status in plan |
| --- | --- | --- |
| Safety framing | Never claim safety | Built in as a hard rule across all surfaces |
| Biometric (later) | Consent, on-device, deletable, retention policy | Designed; needs counsel before shipping |
| Camera/mic | Clear permission purpose strings | Standard iOS handling |
| Cloud (optional) | Explicit opt-in, disclosure | Off by default, isolated |
| Accessibility | Be accessible (the point) | First-class requirement |
| ToS/disclaimers | Accessible, clear limitations | Required before public release |

---

## 22. Repository Design

A clean, well-documented repository is part of the product for an open-source project: it is how contributors arrive and how the bus-factor problem is mitigated. Recommended monorepo layout (the app is one Swift project; supporting material lives alongside it):

```text
sensebridge/
  README.md                      # mission, scope, non-scope, build/run
  LICENSE                        # Apache 2.0
  CONTRIBUTING.md                # setup, build, test, PR process
  CODE_OF_CONDUCT.md             # Contributor Covenant
  SECURITY.md                    # private vulnerability reporting
  GOVERNANCE.md                  # decision-making, bus-factor plan
  CHANGELOG.md
  .github/
    workflows/
      ci.yml                     # build + test + lint (GitHub Actions, free)
    ISSUE_TEMPLATE/
      bug_report.md
      feature_request.md
      accessibility_issue.md
    PULL_REQUEST_TEMPLATE.md     # includes accessibility-impact check
    dependabot.yml               # supply-chain alerts
  app/
    SenseBridge/                 # the Swift/SwiftUI app (structure in Doc 3)
    SenseBridge.xcodeproj
    Tests/
  docs/
    ARCHITECTURE.md              # layering, protocols, data flow
    ACCESSIBILITY.md             # VoiceOver testing, labeling standards
    AI-MODELS.md                 # model choices, licenses, the two traps
    SAFETY-FRAMING.md            # the awareness-not-safety doctrine
    ROADMAP.md                   # phases, deferred scope
    PRIVACY.md                   # data handling, on-device guarantees
  models/
    README.md                    # provenance and licenses of any bundled models
    sound/                       # Create ML classifiers (permissive only)
  scripts/
    setup.sh                     # dev environment bootstrap
    lint.sh
```

Notes on the design:

- **Docs are first-class,** in their own directory, because for this project documentation is adoption and continuity.
- **`docs/SAFETY-FRAMING.md` and `docs/AI-MODELS.md` are not optional.** The safety doctrine and the licensing traps are the two things a new contributor most needs to understand before touching code.
- **`models/README.md`** records provenance and license of every bundled model, so the AGPL/AMLR traps are documented and enforced at the repo level.
- **The infrastructure directories the original prompt imagined** (Docker, Kubernetes, infra) are deliberately absent, because the MVP has no server. If the optional cloud service is ever built, it gets its own directory or its own repo at that time, not before.

---

## Miscellaneous & Remarks

*This document holds everything that did not fit cleanly into the five structured documents: differentiating features, honest remarks and warnings, the things the original prompt asked for that should not be built, solo-developer sustainability, open questions, and consolidated caveats and sources. This is the document where I tell you what I actually think, plainly.*

---

## Differentiating features (mapped to real pain points)

The structured documents kept feature discussion tied to the MVP. Here is the standalone case for what makes SenseBridge different, and the evidence behind each, because "what makes this stand out" was one of your direct questions.

| Differentiator | The pain point it answers | Evidence |
| --- | --- | --- |
| Offline by default | Cloud apps feel slow and raise privacy fears for sensitive documents | Be My AI sends images to OpenAI; security guidance tells blind users to prefer on-device tools for confidential material |
| Open-source and auditable | "This tool could change its terms, raise prices, or disappear" | Every leading competitor is closed; users have no recourse or insight |
| Self-hostable | Trust and continuity for a tool people depend on | No competitor offers this |
| Configurable AI providers | Lock-in to one vendor's model and pricing | Competitors hardwire one cloud model |
| Unified multi-sense output (eventually) | Switching between single-purpose apps is a daily tax | No product unifies blind, deaf, and deaf-blind support |
| Consent-based, on-device-only face enrollment | Wanting "who is that" without surveillance or privacy loss | Competitors either avoid it or do it via cloud |
| Cautious LiDAR obstacle awareness | Wanting a heads-up without a false sense of safety | Apple's own features exist but are closed and capped; honest hedging is rare |
| Free, with no subscription | Cost stacks up; only about a third of working-age blind and visually impaired US adults are employed (AFB/Cornell), so affordability is a real barrier | Aira and premium glasses are expensive; affordability is a real barrier |

The honest version of the differentiation story: **you are not going to out-describe Be My AI or Apple on raw scene-description quality, because they have cloud models and large teams.** What you can own, and what no one else occupies, is the combination of open + offline + user-controlled + multi-sense. Lead with that. Do not try to win the "best AI description" race; win the "the tool that respects you and works without the cloud" race.

---

## Things the original prompt asked for that you should not build (and why)

You asked for brutal honesty, so here is a consolidated list of requested items this plan deliberately refuses, with the reason. None of these is a knock on the ambition; they are about what one person can ship in six months without the project collapsing.

1. **A 22-section enterprise document treated as 22 equal commitments.** Several sections (Kubernetes, million-user scaling, a full backend) describe a system that does not exist in an on-device MVP. Writing them as "here is why this does not apply yet" is more useful than inventing content to fill them.
2. **React Native.** Wrong tool for an iPhone-only, on-device-ML MVP (the Technical Architecture sections). It adds layers without buying you the cross-platform reach the MVP does not need.
3. **A backend with authentication and analytics.** The privacy-first design means the MVP has no server. Building one contradicts the stance and adds cost.
4. **Kubernetes, Docker Compose, and cloud orchestration.** There is nothing to orchestrate. This is infrastructure for a problem you do not have.
5. **Million-user scalability engineering.** An on-device app imposes near-zero server load regardless of user count; the real scaling constraint is your time and the contributor community, not compute.
6. **Real-time navigation guidance.** The most dangerous feature in the original document. Reframe permanently as awareness, never guidance.
7. **Facial recognition in the MVP.** Deferred behind a careful consent flow due to biometric legal exposure.
8. **Deaf and deaf-blind modes in the MVP.** Different sensing/rendering problems; they dilute a six-month blind-user build and belong in later phases.
9. **Wearables and AR glasses in early phases.** Each is a separate integration; architecture-only in the MVP.

If you read this list and feel the urge to keep some of them in anyway, that urge is the project's single biggest risk. The plan works because of what it refuses.

---

## The one place "free" meets reality: the Apple Developer Program

You said no spending beyond your Claude subscription. One thing to flag honestly: distributing to other people via TestFlight or the App Store requires the Apple Developer Program, which is a paid annual membership. Building and running on your own iPhone 17 Pro is free with a personal Apple ID. So:

- **Development and personal-device testing: free.**
- **Getting the app onto real blind testers' phones (TestFlight) or the App Store: requires the paid Developer Program.**

This collides with the zero-cost constraint at exactly the point where real-user validation happens, which is the most important step. Options: budget for the Developer Program when you reach beta (verify the current annual cost, as it changes), see whether any fee waiver exists for nonprofits or open-source or accessibility projects (Apple has had nonprofit fee-waiver programs; verify current terms), or limit early testing to your own device and source builds until you can cover it. I am flagging this rather than pretending the whole path is free, because you asked me not to hallucinate and this is the one unavoidable cost.

---

## Solo-developer sustainability (the risk nobody writes down)

The most likely way this project dies is not a technical failure. It is you running out of energy, and the plan should say so.

- **Ship the smallest useful thing fast.** The document-reading feature alone, done well and validated by a real blind user, is a real win that will keep you going. Do not wait for the whole MVP to feel real.
- **Get a real user early.** Nothing sustains a solo project like one person telling you it helped them. This is motivational fuel and validation at once. Prioritize it over polish.
- **Two three-month increments is a good rhythm; keep them.** A visible milestone at month three prevents the open-ended drift that kills solo projects.
- **Let the architecture say no for you.** When you are tempted to add the watch or the deaf mode, the `RenderTarget` stub is there to absorb the idea without you having to build it now. Write the stub, note the idea, move on.
- **Documentation is also for future-you.** The you of month five will not remember why month-one you made a decision. Write it down. This is also how you eventually get help.
- **It is fine to rest.** An open-source project with no deadline is a marathon. Pace accordingly.

---

## A naming and positioning note

"SenseBridge" is a good name: it says what it does (bridges senses) without overclaiming safety. It does not box you into "blind" or "deaf," which fits the long-term multi-sense vision. Keep it. When you describe the project publicly, lead with the wedge ("open-source, on-device, private accessibility") rather than the feature list, because the wedge is what is memorable and the feature list is what every competitor also has.

---

## Open questions worth resolving before or during the build

These are genuine forks where the right answer depends on things only you or testing can determine:

1. **Is Apple Vision plus Foundation Models good enough for scene description, or do you need to bundle SmolVLM?** Only on-device benchmarking on your iPhone 17 Pro will tell you. Start with the license-clean Apple path; reach for SmolVLM only if the quality is genuinely insufficient and the RAM/latency cost is acceptable.
2. **How will you recruit blind testers?** Resolve this early. NFB or ACB local chapters, accessibility Discord/forum communities, and GitHub accessibility initiatives are the likely channels. This is on the critical path, not a nicety.
3. **Will you budget for the Apple Developer Program at beta, or seek a waiver?** Decide before month four.
4. **AGPL vs Apache for your own code:** the plan recommends Apache 2.0, but if preventing closed forks matters more to you than flexibility, AGPL is a defensible choice. This is a values decision only you can make.
5. **How much verbosity do blind users actually want?** This is a tuning question that only real testers answer. Build verbosity as configurable from the start.

---

## Consolidated caveats (read these as firm constraints, not fine print)

- **This is not legal or financial advice.** The biometric, ADA, GDPR, and licensing discussions are informational. Get qualified counsel before enabling any facial feature or shipping publicly.
- **APIs are moving fast.** iOS 26.x evolved during its cycle (context-window tooling arrived in 26.4), and later iOS versions continue to add AI-powered accessibility. Re-verify Foundation Models limits (context window, availability), SpeechAnalyzer features, and Vision capabilities against current Apple documentation before you build on them.
- **The model-licensing findings are the highest-impact legal items here, and they are now verified.** FastVLM is confirmed `apple-amlr` (non-commercial research only) across all variants and cannot ship in a real app. MobileCLIP is ambiguous: Apple's own repositories mix a restrictive `apple-amlr` license file with a permissive Apple Sample Code License file and dual metadata tags, so it should be quarantined (research-only) until Apple clarifies in writing. Ultralytics YOLO is confirmed AGPL-3.0, which would force your entire project to AGPL. Safe to bundle (all verified permissive): SmolVLM and SmolVLM2 (Apache 2.0), Qwen2-VL-2B (Apache 2.0), Moondream2 (Apache 2.0), whisper.cpp (MIT), Tesseract (Apache 2.0), YAMNet (Apache 2.0). Apple's frameworks themselves are usable in App Store apps regardless of these model licenses.
- **On-device performance figures should be measured, not trusted.** Published latency numbers (for FastVLM and others) come from secondary sources and different devices. Benchmark on your own iPhone 17 Pro.
- **The Ultralytics YOLO AGPL trap is real.** Bundling it forces your whole project to AGPL or an Enterprise License. Use Apple Vision detection instead.
- **The biggest project risk is scope, and the plan repeatedly chooses to cut.** Resist re-expanding the MVP. One developer can build a credible blind-user iPhone MVP in six months. One developer cannot build the full multi-disability, multi-device platform in that window, only the architecture that could grow into it.

---

## Source notes

These documents draw on research into Apple's developer documentation and frameworks (Foundation Models, Vision, SpeechAnalyzer/SpeechTranscriber, AVSpeechSynthesizer, Sound Analysis, ARKit/LiDAR, VisionKit, Core Haptics, WatchKit), model repositories and their license tags (Ultralytics YOLO AGPL-3.0 confirmed; Apple FastVLM confirmed apple-amlr non-commercial; Apple MobileCLIP confirmed ambiguous/mixed-license and quarantined; SmolVLM/SmolVLM2, Qwen2-VL-2B, Moondream2, YAMNet, Tesseract confirmed Apache 2.0; whisper.cpp confirmed MIT, all verified June 2026), the competitive landscape (Be My Eyes and Be My AI, Microsoft Seeing AI, Envision app and glasses, Aira, Google Lookout, OrCam, Ava, Google Live Transcribe, and Apple's built-in VoiceOver, Magnifier, Live Recognition, Sound Recognition, and Live Captions), accessibility standards (WCAG 2.2, Apple Human Interface Guidelines), biometric and privacy law (Illinois BIPA and its settlement history, Texas CUBI and related settlements, Washington's biometric law, GDPR Article 9, CCPA/CPRA), funding sources (Microsoft AI for Accessibility, NSF-adjacent accessibility ecosystems, GitHub Sponsors, Open Collective, fiscal sponsors such as Software Freedom Conservancy and NumFOCUS), open-source assistive-tech precedents (NVDA, OptiKey, EyeMine), and disability-employment context (National Federation of the Blind figures).

A few specifics worth re-verifying yourself given how fast this space moves: the exact Apple Foundation Models context window and device requirements at the iOS version you target; current Apple Developer Program cost and any nonprofit or accessibility fee-waiver terms; the current license tags on any model before you bundle it; and current biometric-privacy law in any jurisdiction where you plan to enable facial enrollment. Whisper.cpp on iOS is documented in the project's own discussions as workable for real-time transcription but thermally demanding under sustained use, which is why Apple's SpeechAnalyzer is the recommended primary for the deaf phase. Small-language-model feasibility on phones (the SmolVLM-class option) is an active, fast-moving area; treat any specific RAM or speed figure as a starting estimate to confirm on your own device.

---

## Final word

You came in with a strong instinct (open, private, multi-sense accessibility) wrapped in a scope that would have buried a team, let alone one person. The plan keeps the instinct and cuts the scope to something you can actually ship: a blind-user, iPhone, on-device, two-increment MVP, with the larger vision preserved as architecture and roadmap rather than as a six-month promise. If you hold that line, you have a real shot at building something genuinely useful that no one else currently offers. If you let the scope creep back, you will have an impressive architecture diagram and no shipped app. The whole plan comes down to that one discipline.

*This concludes Part One, the plan itself. Part Two follows: an independent verification log, the free-versus-paid alternatives, and the licensing and legal rationale. Where Part Two corrects a figure or claim from Part One, those corrections have already been folded into the relevant sections above as inline accuracy notes.*

# Part Two: Verification, Alternatives & Rationale

*This part was produced after independent source verification (June 2026) of the load-bearing claims in Part One. It records what was confirmed and corrected, lays out every free-versus-paid choice with the free option set as the default for this project, and states the reasoning behind the licensing and legal recommendations.*

*This document was added after independent source verification (June 2026) of the load-bearing claims in Part One's sections. It records what was confirmed and what was corrected, lays out every free-versus-paid choice with the free option set as the default for this project (and pros and cons of each at the end of its section), and states the rationale behind the licensing and legal recommendations. Legal items are factual source verification, not legal advice; confirm the flagged items and consult a licensed attorney before relying on them in a shipped product.*

---

## Part A: Verification Log

### Confirmed (load-bearing claims that held up)

| Claim | Status | Source basis |
| --- | --- | --- |
| Apple Foundation Models on-device LLM is ~3B parameters, 2-bit quantized, with a 4,096-token context window shared across input and output | Confirmed | Apple WWDC25 session 286; Apple 2025 tech report |
| It requires Apple Intelligence (iPhone 15 Pro and later), is text-only (cannot take images), and uses SystemLanguageModel / LanguageModelSession with @Generable guided generation | Confirmed | Apple Developer documentation |
| iOS 26.4 added contextSize, tokenCount(for:), and the .exceededContextWindowSize error | Confirmed | Apple technical note; iOS 26.4 release |
| Apple Vision RecognizeTextRequest (OCR) and the new iOS 26 RecognizeDocumentsRequest with table/row/column detection | Confirmed | Apple Developer documentation |
| SpeechAnalyzer / SpeechTranscriber are new on-device, AsyncSequence-based, long-form STT in iOS 26 with system-managed model assets; legacy SFSpeechRecognizer still has custom vocabulary that SpeechAnalyzer lacks | Confirmed | Apple Developer documentation |
| Sound Analysis: SNClassifySoundRequest with a built-in classifier covering over 300 sound types, plus custom Create ML models | Confirmed | Apple WWDC21 session 10036 |
| ARKit sceneDepth / ARDepthData with a depth map and confidenceMap via ARSession; iPhone 17 Pro has LiDAR; no raw-LiDAR-only public API | Confirmed | Apple Developer documentation |
| Core Haptics on iPhone; WKHapticType on Apple Watch; visionOS 26 shares Vision and Foundation Models with iOS | Confirmed | Apple Developer documentation |
| Ultralytics YOLO (v8, v11, YOLO26) is AGPL-3.0; using it forces the entire project (code, configs, scripts, weights) to AGPL or an Enterprise License, even for internal/non-commercial use | Confirmed | Ultralytics official licensing pages and docs |
| Apple FastVLM is apple-amlr (non-commercial research only) across 0.5B, 1.5B, 7B variants | Confirmed | Hugging Face license tags on apple/FastVLM repos |
| The apple-amlr license restricts use to non-commercial "Research Purposes" and excludes any commercial product or service | Confirmed | Apple Machine Learning Research Model license text |
| SmolVLM and SmolVLM2 are Apache 2.0; Qwen2-VL-2B and Moondream2 are Apache 2.0; whisper.cpp is MIT; YAMNet is Apache 2.0 (521 classes); Tesseract is Apache 2.0 | Confirmed | Respective repository license files |
| Illinois BIPA has a private right of action; Meta settled for $650 million (2021) | Confirmed | Court records; legal coverage |
| Texas CUBI is AG-enforced with no private right of action; up to $25,000 per violation; Meta $1.4 billion (July 2024); Google $1.375 billion (finalized Oct 31, 2025) | Confirmed | Texas statute 503.001; Texas AG releases |
| GDPR Article 9 treats identifying biometric data as a special category; CCPA/CPRA treats biometric information as sensitive | Confirmed | Primary legal texts |
| Apple Developer Program is $99/year, required for TestFlight and App Store; free Apple ID allows on-device builds via free provisioning with ~7-day certificate expiry and no TestFlight/App Store; fee waiver only for nonprofit/education/government legal entities distributing free apps; Xcode is free | Confirmed | Apple Developer program and fee-waiver pages |
| GitHub public repositories and GitHub Actions are free with unlimited standard-runner minutes for public repos; GitHub Pages is free; TestFlight crash reports are free | Confirmed | GitHub documentation |
| Microsoft AI for Accessibility offers Azure credits (tiers around $10k/$15k/$20k) plus mentorship; GitHub Sponsors has zero platform fees; Open Collective works via fiscal hosts | Confirmed | Program pages |

### Corrected (claims from earlier drafts that were wrong or imprecise, now fixed in the documents)

1. **Employment statistic.** The earlier "around 70% blind unemployment" was imprecise. The accurate picture: only roughly a third to 44% of working-age blind and visually impaired US adults are employed; the formal BLS unemployment rate for people with vision difficulty was about 10% in 2024 (versus about 4% without). The honest framing is "a majority of working-age blind adults are not employed," not "70% unemployment." Fixed in Documents 1 and 6.
2. **The "VLLO" reference.** An earlier draft implied Apple ships an official sample app demonstrating the Vision-plus-Foundation-Models pattern for accessibility scene description. VLLO is a real third-party video-editing app Apple has showcased that combines those frameworks, but it is not an accessibility scene-description sample, and no canonical Apple sample exists for that use case. You build this pipeline yourself; the frameworks support it. Fixed in the Technical Architecture sections.
3. **MobileCLIP licensing.** An earlier draft stated flatly that MobileCLIP is apple-amlr non-commercial. Verification found its licensing is ambiguous: Apple's repositories mix a restrictive apple-amlr LICENSE file with a permissive Apple Sample Code License weights file and carry dual metadata tags. It is now treated as quarantined (research-only) pending written clarification from Apple, rather than a flat ban. Fixed in Documents 3, 5, and 6.
4. **Whisper speed.** Refined from "around 2x faster" to "about 2.2x faster in one informal single-file test (45 seconds versus 1:41), not a controlled benchmark." Fixed in the Technical Architecture sections.
5. **CUBI penalty detail.** Added the specific statutory figure (up to $25,000 per violation, AG-only enforcement) for precision. Fixed in the Governance and Legal sections.
6. **BIPA recency.** Added the August 2024 amendment (SB 2979, per-person damages cap, electronic consent valid) and the April 2026 Seventh Circuit retroactivity ruling. Fixed in the Governance and Legal sections.

### Still needs your verification before you rely on it

These are accurate as far as the research went, but should be confirmed at the point you act on them, because they are either empirical (not vendor-published) or fast-changing:

- **The LiDAR usable range** (commonly cited around 0.26 to 5 or 6 meters) is community/empirical, not an Apple-published spec. Apple documents only that depth degrades at distance and on dark or reflective surfaces and under motion. Attribute it as empirical.
- **Texas TRAIGA** (the Responsible AI Governance Act): confirm the exact 2026 effective date and its biometric provisions against the enrolled bill text.
- **Apple's Magnifier Detection Mode disclaimer wording.** The "awareness, not safety" rationale mirrors Apple's own practice, but quote Apple's current disclaimer verbatim from the live support page before you publish your own.
- **Washington biometric law citations** (RCW 19.375 and the My Health My Data Act both exist; confirm exact section references). Reframe "20+ biometric laws" as "20+ comprehensive state privacy laws that classify biometrics as sensitive."
- **Free-tier specifics that drift:** exact GitHub Actions minute policies, Open Collective fiscal-host fee percentages, GitHub Sponsors fee wording, and whether Microsoft AI for Accessibility applications are currently open (they showed as closed during this review). Re-check at point of use.
- **SmolVLM2 RAM:** the often-cited "under 1 GB" applies to the 256M model for single-image inference; 256M video inference is officially around 1.38 GB. Benchmark on your own device regardless.

---

## Part B: Free-vs-Paid Alternatives

You asked that for anything potentially paid, the free option be the default for this project and the paid one be listed as the fallback, with pros and cons. That is exactly how this is structured. The short version: SenseBridge can be built and run entirely free; the only places money becomes relevant are getting the app onto other people's phones, a Mac to develop on, and an optional cloud feature you are not building for the MVP.

### B1. Getting the app onto devices

**Default (free): free provisioning to your own iPhone.** Sign into Xcode with a free Apple ID, connect your iPhone 17 Pro, build and run. No cost.

**Fallback (paid): Apple Developer Program, $99/year.** Required for TestFlight beta distribution and App Store publishing.

| Option | Pros | Cons |
| --- | --- | --- |
| Free provisioning (default) | Zero cost; full on-device testing on your own phone; enough to build and validate the entire MVP yourself | Certificates expire about every 7 days (re-run from Xcode to reinstall); limited to devices you physically connect; no TestFlight; no App Store; some entitlements unavailable |
| Apple Developer Program ($99/yr) | TestFlight for real external testers; App Store publishing; full entitlements; the only practical way to put it in blind testers' hands remotely | $99/year; auto-renews; waiver only for nonprofit/education/government legal entities shipping free apps, not solo individuals |
| Sideloading tools (AltStore / SideStore) | Free; can get a build onto another person's device without the App Store | Still tied to free-provisioning style 7-day re-signing; fiddly setup; impractical to ask a blind or low-vision tester to maintain; not a real distribution channel |

**Recommendation for this project:** build and self-test entirely free via free provisioning. When you reach the point of real external blind testers (which the Engineering Quality sections says is the validation that matters most), that is the moment the $99 becomes worth it. If you incorporate as or partner with a 501(c)(3) and ship only free apps, pursue the fee waiver; otherwise budget the $99.

### B2. Code hosting and CI/CD

**Default (free): GitHub public repository plus GitHub Actions.** Free, with unlimited standard-runner minutes for public repositories. GitHub Pages (free) covers a project website.

| Option | Pros | Cons |
| --- | --- | --- |
| GitHub public repo + Actions + Pages (default) | Free including unlimited CI minutes for public repos; matches the open-source mission; Dependabot and secret scanning included; free project site | Public by definition (fine for open source); macOS runner minutes are the constrained resource if you ever go private |
| Paid CI (e.g., dedicated Mac CI services) | Faster/parallel macOS builds; useful at scale | Recurring cost; unnecessary for a solo MVP |

**Recommendation:** GitHub public repo plus Actions plus Pages, all free, which also happens to be the correct choice for an open-source project regardless of cost.

### B3. Crash and error reporting

**Default (free): Xcode Organizer and TestFlight crash reports.** Free, Apple-native, no extra SDK, no extra data collection (which fits the privacy stance).

| Option | Pros | Cons |
| --- | --- | --- |
| Xcode Organizer / TestFlight (default) | Free; no third-party SDK; respects privacy; sufficient for an MVP | Less rich than dedicated tools; tied to Apple's reporting |
| Open-source self-hosted (e.g., Sentry self-hosted) | Free software; full control; can self-host | You run and maintain a server, which contradicts the no-backend MVP stance; added complexity |
| Hosted error-reporting SaaS | Rich features; easy | Recurring cost and/or data leaving the device; conflicts with privacy-first |

**Recommendation:** Xcode Organizer and TestFlight for the MVP. It is free, private, and enough.

### B4. The optional cloud reasoning provider (not in the MVP)

**Default (free): no cloud at all.** The MVP is fully on-device. If you ever add the opt-in cloud path, the default should still be free or self-hosted.

| Option | Pros | Cons |
| --- | --- | --- |
| No cloud (default for MVP) | Free; private; offline; nothing to run | On-device reasoning quality ceiling (the label-composition limit from the Technical Architecture sections) |
| User self-hosts their own model, or supplies their own provider key | Free to you; user controls their data and cost; fits "configurable provider" | Setup burden on the user; not all users can self-host |
| Free-tier cloud API | More capable scene reasoning | Free tiers are rate-limited and change; data leaves the device; must be opt-in and disclosed |
| Paid cloud API | Best quality | Recurring cost; conflicts with the no-paid-API constraint if ever made default |

**Recommendation:** ship no cloud in the MVP. If a cloud option is added later, make it opt-in, disabled by default, and built so users bring their own provider or self-host, so the project never carries a recurring bill.

### B5. The unavoidable cost: a Mac

There is no free software path around this: iOS development requires Xcode, which requires a Mac. This is the one cost the project cannot design away.

| Option | Pros | Cons |
| --- | --- | --- |
| A Mac you already own (default if you have one) | No new cost | Must be recent enough to run current Xcode |
| Borrowed / institutional / library Mac | Free or low cost | Access and continuity limits |
| Cheapest current Apple Silicon Mac | Runs Xcode well | A real one-time hardware cost |
| Mac in the cloud (rental) | No hardware purchase | Recurring cost; can exceed buying over time |

**Recommendation:** use a Mac you own or can access. If you are reading this, you likely already develop on one. There is no honest free workaround, so it is called out plainly rather than hidden.

### B6. Funding (covered fully in the Strategy sections; the free defaults)

GitHub Sponsors (zero platform fees) and Open Collective (via a fiscal host) are the free, low-overhead ways to accept support. Microsoft AI for Accessibility (Azure credits plus mentorship) is the most aligned grant, pursued once you have a working demo and real testers. None of these is required to build the MVP.

---

## Part C: Licensing & Legal Rationale

This part states the reasoning behind the recommendations, not just the conclusions, since you asked for the rationale.

### C1. Why Apache 2.0 for SenseBridge's own code

The choice is between permissive (MIT, Apache 2.0) and copyleft (GPL, AGPL). The reasoning:

- **Apache 2.0 over MIT:** both are permissive and both allow broad reuse, but Apache 2.0 includes an express patent grant that MIT lacks. For an AI project, where patent questions are live and contributors and users benefit from explicit patent protection, that grant is worth having. Apache 2.0 also has clear contribution terms.
- **Permissive over copyleft (why not GPL/AGPL):** the project wants the widest possible adoption, the ability to bundle permissively licensed models (SmolVLM, Qwen2-VL, Moondream2, whisper.cpp, YAMNet, Tesseract are all MIT or Apache 2.0), and the freedom to support future nonprofit or commercial-service paths. Copyleft, especially AGPL's network-use provision, would constrain all of that.
- **The one reason you might choose AGPL instead:** if your priority is to prevent anyone from making a closed-source fork or closed SaaS of SenseBridge, AGPL does that. The cost is reduced adoption and contributor friction, and it would also then permit you to use AGPL components like YOLO. This is a values decision; the default recommendation is Apache 2.0 for flexibility.

### C2. Why the model licenses matter so much (the two traps)

- **Ultralytics YOLO (AGPL-3.0) is a poison pill for a permissive project.** AGPL's copyleft means that if you incorporate YOLO code or weights, your entire derivative work, including all your own code, configs, training scripts, and model weights, must be released under AGPL, or you must buy an Ultralytics Enterprise License. This applies even to internal or non-commercial use. Bundling it would forcibly convert SenseBridge from Apache 2.0 to AGPL. The fix is to use Apple's built-in Vision detection instead, which carries no such obligation.
- **Apple FastVLM (apple-amlr) cannot ship in a product.** The Apple Machine Learning Research Model license limits use to non-commercial "Research Purposes" and explicitly excludes any commercial product or service. A shipping app, even a free one, is a product or service, so FastVLM is out despite being technically excellent. MobileCLIP is ambiguous (mixed license signals in Apple's own repos) and is quarantined until Apple clarifies.
- **The safe set,** all verified permissive and bundleable: SmolVLM, SmolVLM2, Qwen2-VL-2B, Moondream2 (all Apache 2.0), whisper.cpp (MIT), YAMNet (Apache 2.0), Tesseract (Apache 2.0). Apple's frameworks (Vision, Foundation Models, Speech, Sound Analysis) are usable in App Store apps regardless of these model-license questions, because you are calling Apple's APIs, not redistributing third-party weights.

### C3. Why "awareness, not safety" is the core legal design, not just ethics

The rationale is product-liability exposure. An assistive tool that could be read as a safety or mobility device invites liability if someone is harmed relying on it. The protective design has three parts, and it mirrors how Apple disclaims its own Magnifier detection features:

1. **Probabilistic language in the product itself** ("possible stairs ahead," never "safe to cross"), so the tool never asserts certainty about the physical world.
2. **A prominent, repeated disclaimer** that SenseBridge is not a mobility or safety device and does not replace a cane, guide dog, or orientation-and-mobility training, surfaced in onboarding, the terms of service, and the documentation.
3. **No accuracy or safety guarantees** anywhere in copy or marketing.

This framing is the cheapest, highest-leverage liability reduction available, and it aligns with the ethical commitment to honesty with users.

### C4. Why consent-based, on-device-only biometrics is the legally safest design

The reasoning is that biometric-identification law (BIPA, CUBI, Washington, GDPR Article 9, CCPA/CPRA) attaches serious obligations and penalties to collecting and using biometric identifiers, and on-device storage alone does not exempt you. The safest posture is to avoid creating biometric templates at all unless a feature truly needs identification. If facial enrollment is built later, the design must be: opt-in, informed written consent (electronic consent is valid under the 2024 BIPA amendment), on-device-only encrypted storage that is never transmitted, user-viewable and user-deletable, a published retention and destruction policy, only consented individuals matched, and everyone else labeled only "person." "Describe the scene" does not require identifying anyone, so the MVP avoids the entire category. That avoidance is itself the strategy.

---

*End of the SenseBridge plan. Part Two supersedes any conflicting detail in Part One where verification corrected a figure or claim. The legal and licensing content is factual verification, not legal advice; confirm the flagged items and consult a licensed attorney, and clarify the MobileCLIP license with Apple, before relying on any of it in a shipped product. Linked primary sources for the verified claims follow in the References section below.*

---

# References

*Primary and authoritative sources behind the verified claims, grouped by topic. Apple framework links are canonical documentation entry points. A few legal and program pages change frequently or have long deep-link slugs; where noted, confirm at the live page. This list reflects sources reviewed during verification (June 2026); it is a research trail, not an exhaustive bibliography.*

## Apple frameworks and on-device AI

- Apple Foundation Models, official documentation: <https://developer.apple.com/documentation/foundationmodels>
- Apple, "Foundation Models framework unlocks new intelligent app experiences" (newsroom, Sept 2025): <https://www.apple.com/newsroom/2025/09/apples-foundation-models-framework-unlocks-new-intelligent-app-experiences/>
- WWDC25 session 286, "Meet the Foundation Models framework": <https://developer.apple.com/videos/play/wwdc2025/286/>
- Independent analysis of the on-device model (~3B parameters, 2-bit quantized): <https://github.com/fguzman82/apple-foundation-model-analysis>
- Apple Vision framework (OCR, document and object recognition): <https://developer.apple.com/documentation/vision>
- Apple Speech framework (SpeechAnalyzer, SpeechTranscriber): <https://developer.apple.com/documentation/speech>
- Whisper-vs-Apple speed comparison (one informal single-file test): <https://www.macstories.net/stories/hands-on-how-apples-new-speech-apis-outpace-whisper-for-lightning-fast-transcription/> and <https://www.macrumors.com/2025/06/18/apple-transcription-api-faster-than-whisper/>
- Apple Sound Analysis framework: <https://developer.apple.com/documentation/soundanalysis>
- WWDC21 session 10036, Sound Analysis (300+ built-in classes): <https://developer.apple.com/videos/play/wwdc2021/10036/>
- Sound Analysis with a custom Create ML model, worked example: <https://medium.com/@narner/classification-of-sound-files-on-ios-with-the-soundanalysis-framework-and-esc-10-coreml-model-3a5154db903f>
- ARKit and scene depth / LiDAR: <https://developer.apple.com/documentation/arkit>
- Core Haptics: <https://developer.apple.com/documentation/corehaptics>

## Model licenses (the load-bearing licensing claims)

- Ultralytics licensing (AGPL-3.0 and Enterprise License): <https://www.ultralytics.com/license> and the repository <https://github.com/ultralytics/ultralytics>
- Apple FastVLM (apple-amlr, non-commercial research): <https://huggingface.co/apple/FastVLM-0.5B> and the project <https://github.com/apple/ml-fastvlm>
- Apple MobileCLIP, mixed/ambiguous license signals (apple-amlr LICENSE alongside Apple Sample Code License): <https://huggingface.co/apple/MobileCLIP-S1/blob/main/README.md> and <https://huggingface.co/apple/coreml-mobileclip>
- SmolVLM and SmolVLM2 (Apache 2.0): <https://huggingface.co/HuggingFaceTB/SmolVLM-Instruct> and <https://huggingface.co/HuggingFaceTB/SmolVLM2-2.2B-Instruct>
- whisper.cpp (MIT): <https://github.com/ggml-org/whisper.cpp> ; iOS real-time usage discussion: <https://github.com/ggml-org/whisper.cpp/discussions/1093>
- YAMNet (Apache 2.0, 521 classes): <https://github.com/tensorflow/models/tree/master/research/audioset/yamnet>
- Tesseract OCR (Apache 2.0): <https://github.com/tesseract-ocr/tesseract>
- Small on-device model landscape (context for RAM/feasibility): <https://localaimaster.com/blog/small-language-models-guide-2026>

## Biometric and privacy law

- Texas CUBI statute, Tex. Bus. & Com. Code 503.001 ($25,000 per violation, AG enforcement): <https://codes.findlaw.com/tx/business-and-commerce-code/bus-com-sect-503-001/>
- Texas biometric privacy overview (consent, penalties, 2026 context): <https://www.recordinglaw.com/us-laws/data-privacy-laws/texas-data-privacy-laws/biometric-privacy/>
- Texas Attorney General (Google $1.375B settlement, finalized Oct 31, 2025; confirm the specific release at the live site): <https://www.texasattorneygeneral.gov>
- Illinois BIPA: the $650M Meta/Facebook settlement (2021) and the August 2024 SB 2979 amendment are widely documented; confirm current status with primary court records and the Illinois statute (740 ILCS 14). Texas Meta $1.4B settlement (July 2024) reported by Vinson & Elkins and others.
- GDPR Article 9 (special-category biometric data): <https://gdpr-info.eu/art-9-gdpr/>

## Apple Developer Program and free tooling

- Apple Developer Program: <https://developer.apple.com/programs/>
- Fee waivers (nonprofit, education, government only): <https://developer.apple.com/help/account/membership/fee-waivers/>
- GitHub Actions free minutes for public repositories (community discussion): <https://github.com/orgs/community/discussions/156389>
- GitHub Pages: <https://pages.github.com>

## Funding and open-source sustainability

- Microsoft AI for Accessibility: <https://www.microsoft.com/en-us/ai/ai-for-accessibility>
- GitHub Sponsors (zero platform fees): <https://github.com/sponsors>
- Open Collective (fiscal-host model): <https://opencollective.com>
- Open Source Collective (fiscal host): <https://oscollective.org>
- Software Freedom Conservancy: <https://sfconservancy.org>
- NumFOCUS: <https://numfocus.org>
- NV Access / NVDA (donations-and-services precedent): <https://www.nvaccess.org>

## Disability employment context

- American Foundation for the Blind, employment statistics (only roughly a third of working-age blind/visually impaired adults employed; correcting the "70% unemployment" framing): <https://www.afb.org/research-and-initiatives/statistics>
- Peer-reviewed employment-rate data on visual impairment is available via PubMed Central: <https://pmc.ncbi.nlm.nih.gov> (search visual impairment employment rate)

## Accessibility standards

- WCAG 2.2: <https://www.w3.org/TR/WCAG22/>
- Apple Human Interface Guidelines, Accessibility: <https://developer.apple.com/design/human-interface-guidelines/accessibility>

---

*Note on the references: the Apple documentation, major repository, and organization links above are stable canonical entry points. For the legal items (BIPA settlement amounts and amendment status, the specific Texas AG release, Texas TRAIGA effective dates) and for Apple's verbatim Magnifier detection disclaimer, confirm against the live primary source before relying on them in anything published, consistent with the "needs your verification" flags in Part Two.*
