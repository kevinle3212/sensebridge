# SenseBridge Plan, Document 5 of 6: Governance, Security & Legal

*This document covers Open Source Strategy, Security Review, Legal & Compliance, and Repository Design. The legal section is informational only and is not legal advice; verify everything with qualified counsel before enabling any biometric feature or shipping.*

---

## 19. Open Source Strategy

### Licensing recommendation: Apache 2.0 for SenseBridge's own code

The license choice matters more than it looks, because it interacts with the model-licensing traps and with the project's possible nonprofit or commercial future.

Comparison of the realistic options:

| License | Effect | Fit for SenseBridge |
|---|---|---|
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
- Architecture docs (the protocol abstractions, the perception-reasoning-output layering from Document 3).
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
|---|---|---|
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
|---|---|---|
| Safety framing | Never claim safety | Built in as a hard rule across all surfaces |
| Biometric (later) | Consent, on-device, deletable, retention policy | Designed; needs counsel before shipping |
| Camera/mic | Clear permission purpose strings | Standard iOS handling |
| Cloud (optional) | Explicit opt-in, disclosure | Off by default, isolated |
| Accessibility | Be accessible (the point) | First-class requirement |
| ToS/disclaimers | Accessible, clear limitations | Required before public release |

---

## 22. Repository Design

A clean, well-documented repository is part of the product for an open-source project: it is how contributors arrive and how the bus-factor problem is mitigated. Recommended monorepo layout (the app is one Swift project; supporting material lives alongside it):

```
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
    architecture.md              # layering, protocols, data flow
    accessibility.md             # VoiceOver testing, labeling standards
    ai-models.md                 # model choices, licenses, the two traps
    safety-framing.md            # the awareness-not-safety doctrine
    roadmap.md                   # phases, deferred scope
    privacy.md                   # data handling, on-device guarantees
  models/
    README.md                    # provenance and licenses of any bundled models
    sound/                       # Create ML classifiers (permissive only)
  scripts/
    setup.sh                     # dev environment bootstrap
    lint.sh
```

Notes on the design:

- **Docs are first-class,** in their own directory, because for this project documentation is adoption and continuity.
- **`docs/safety-framing.md` and `docs/ai-models.md` are not optional.** The safety doctrine and the licensing traps are the two things a new contributor most needs to understand before touching code.
- **`models/README.md`** records provenance and license of every bundled model, so the AGPL/AMLR traps are documented and enforced at the repo level.
- **The infrastructure directories the original prompt imagined** (Docker, Kubernetes, infra) are deliberately absent, because the MVP has no server. If the optional cloud service is ever built, it gets its own directory or its own repo at that time, not before.

*Continued in Document 6 of 6: Miscellaneous & Remarks.*
