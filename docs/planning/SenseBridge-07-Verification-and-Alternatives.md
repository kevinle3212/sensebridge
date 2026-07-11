# SenseBridge Plan, Document 7 of 7: Verification Log, Free-vs-Paid Alternatives & Licensing/Legal Rationale

*This document was added after independent source verification (June 2026) of the load-bearing claims in Documents 1 through 6. It records what was confirmed and what was corrected, lays out every free-versus-paid choice with the free option set as the default for this project (and pros and cons of each at the end of its section), and states the rationale behind the licensing and legal recommendations. Legal items are factual source verification, not legal advice; confirm the flagged items and consult a licensed attorney before relying on them in a shipped product.*

---

## Part A: Verification Log

### Confirmed (load-bearing claims that held up)

| Claim | Status | Source basis |
|---|---|---|
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
2. **The "VLLO" reference.** An earlier draft implied Apple ships an official sample app demonstrating the Vision-plus-Foundation-Models pattern for accessibility scene description. VLLO is a real third-party video-editing app Apple has showcased that combines those frameworks, but it is not an accessibility scene-description sample, and no canonical Apple sample exists for that use case. You build this pipeline yourself; the frameworks support it. Fixed in Document 3.
3. **MobileCLIP licensing.** An earlier draft stated flatly that MobileCLIP is apple-amlr non-commercial. Verification found its licensing is ambiguous: Apple's repositories mix a restrictive apple-amlr LICENSE file with a permissive Apple Sample Code License weights file and carry dual metadata tags. It is now treated as quarantined (research-only) pending written clarification from Apple, rather than a flat ban. Fixed in Documents 3, 5, and 6.
4. **Whisper speed.** Refined from "around 2x faster" to "about 2.2x faster in one informal single-file test (45 seconds versus 1:41), not a controlled benchmark." Fixed in Document 3.
5. **CUBI penalty detail.** Added the specific statutory figure (up to $25,000 per violation, AG-only enforcement) for precision. Fixed in Document 5.
6. **BIPA recency.** Added the August 2024 amendment (SB 2979, per-person damages cap, electronic consent valid) and the April 2026 Seventh Circuit retroactivity ruling. Fixed in Document 5.

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
|---|---|---|
| Free provisioning (default) | Zero cost; full on-device testing on your own phone; enough to build and validate the entire MVP yourself | Certificates expire about every 7 days (re-run from Xcode to reinstall); limited to devices you physically connect; no TestFlight; no App Store; some entitlements unavailable |
| Apple Developer Program ($99/yr) | TestFlight for real external testers; App Store publishing; full entitlements; the only practical way to put it in blind testers' hands remotely | $99/year; auto-renews; waiver only for nonprofit/education/government legal entities shipping free apps, not solo individuals |
| Sideloading tools (AltStore / SideStore) | Free; can get a build onto another person's device without the App Store | Still tied to free-provisioning style 7-day re-signing; fiddly setup; impractical to ask a blind or low-vision tester to maintain; not a real distribution channel |

**Recommendation for this project:** build and self-test entirely free via free provisioning. When you reach the point of real external blind testers (which Document 4 says is the validation that matters most), that is the moment the $99 becomes worth it. If you incorporate as or partner with a 501(c)(3) and ship only free apps, pursue the fee waiver; otherwise budget the $99.

### B2. Code hosting and CI/CD

**Default (free): GitHub public repository plus GitHub Actions.** Free, with unlimited standard-runner minutes for public repositories. GitHub Pages (free) covers a project website.

| Option | Pros | Cons |
|---|---|---|
| GitHub public repo + Actions + Pages (default) | Free including unlimited CI minutes for public repos; matches the open-source mission; Dependabot and secret scanning included; free project site | Public by definition (fine for open source); macOS runner minutes are the constrained resource if you ever go private |
| Paid CI (e.g., dedicated Mac CI services) | Faster/parallel macOS builds; useful at scale | Recurring cost; unnecessary for a solo MVP |

**Recommendation:** GitHub public repo plus Actions plus Pages, all free, which also happens to be the correct choice for an open-source project regardless of cost.

### B3. Crash and error reporting

**Default (free): Xcode Organizer and TestFlight crash reports.** Free, Apple-native, no extra SDK, no extra data collection (which fits the privacy stance).

| Option | Pros | Cons |
|---|---|---|
| Xcode Organizer / TestFlight (default) | Free; no third-party SDK; respects privacy; sufficient for an MVP | Less rich than dedicated tools; tied to Apple's reporting |
| Open-source self-hosted (e.g., Sentry self-hosted) | Free software; full control; can self-host | You run and maintain a server, which contradicts the no-backend MVP stance; added complexity |
| Hosted error-reporting SaaS | Rich features; easy | Recurring cost and/or data leaving the device; conflicts with privacy-first |

**Recommendation:** Xcode Organizer and TestFlight for the MVP. It is free, private, and enough.

### B4. The optional cloud reasoning provider (not in the MVP)

**Default (free): no cloud at all.** The MVP is fully on-device. If you ever add the opt-in cloud path, the default should still be free or self-hosted.

| Option | Pros | Cons |
|---|---|---|
| No cloud (default for MVP) | Free; private; offline; nothing to run | On-device reasoning quality ceiling (the label-composition limit from Document 3) |
| User self-hosts their own model, or supplies their own provider key | Free to you; user controls their data and cost; fits "configurable provider" | Setup burden on the user; not all users can self-host |
| Free-tier cloud API | More capable scene reasoning | Free tiers are rate-limited and change; data leaves the device; must be opt-in and disclosed |
| Paid cloud API | Best quality | Recurring cost; conflicts with the no-paid-API constraint if ever made default |

**Recommendation:** ship no cloud in the MVP. If a cloud option is added later, make it opt-in, disabled by default, and built so users bring their own provider or self-host, so the project never carries a recurring bill.

### B5. The unavoidable cost: a Mac

There is no free software path around this: iOS development requires Xcode, which requires a Mac. This is the one cost the project cannot design away.

| Option | Pros | Cons |
|---|---|---|
| A Mac you already own (default if you have one) | No new cost | Must be recent enough to run current Xcode |
| Borrowed / institutional / library Mac | Free or low cost | Access and continuity limits |
| Cheapest current Apple Silicon Mac | Runs Xcode well | A real one-time hardware cost |
| Mac in the cloud (rental) | No hardware purchase | Recurring cost; can exceed buying over time |

**Recommendation:** use a Mac you own or can access. If you are reading this, you likely already develop on one. There is no honest free workaround, so it is called out plainly rather than hidden.

### B6. Funding (covered fully in Document 1; the free defaults)

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

*End of Document 7 and of the SenseBridge plan. This addendum supersedes any conflicting detail in Documents 1 through 6 where verification corrected a figure or claim. The legal and licensing content is factual verification, not legal advice; confirm the flagged items and consult a licensed attorney, and clarify the MobileCLIP license with Apple, before relying on any of it in a shipped product.*
