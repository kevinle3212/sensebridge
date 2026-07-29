---
title: SenseBridge Documentation
---

# SenseBridge Documentation

Open-source, on-device, private accessibility for blind and low-vision iPhone
users. SenseBridge translates a person's surroundings into clear spoken
information, and processes all of it on the phone by default — the camera feed
and what it sees never have to leave the device.

The app is **pre-launch**: there is no download yet, and nothing here should be
read as a claim that there is. What follows is the complete public engineering
record. The canonical source is
[`docs/`](https://github.com/kevinle3212/sensebridge/tree/main/docs) on GitHub,
mirrored to the [Wiki](https://github.com/kevinle3212/sensebridge/wiki) and
summarized in the
[README](https://github.com/kevinle3212/sensebridge#readme).

New here? [Glossary and reading paths](GLOSSARY.md) routes you through these
pages in the right order for who you are — curious user, contributor, reviewer,
or accessibility specialist.

## Product and roadmap

- [Product](PRODUCT.md) — mission, the wedge, who the MVP is for, success
  metrics, funding and sustainability
- [Roadmap](ROADMAP.md) — five phases, what the MVP includes, and what is
  deliberately deferred
- [FAQ](FAQ.md) — the questions people actually ask

## Architecture and engineering

- [Architecture](ARCHITECTURE.md) — the `SensingSource` → perception →
  Reasoning → `RenderTarget` pipeline, the two-stage on-device AI path, and why
  there is no backend
- [Code map](CODE-MAP.md) — what lives in which directory, an "I want to change
  X, where do I look" table, and how to contribute
- [AI models](AI-MODELS.md) — model choices and the license ledger; AGPL and
  Apple's `apple-amlr` are hard blockers
- [Testing strategy](TESTING.md) — unit, integration, e2e, and AI-eval layers,
  and the three-test-per-feature e2e floor
- [CI/CD and release engineering](CI-CD.md) — every workflow, the blocking
  quality gates, and an honest account of what CI cannot prove
- [GitHub Models prompts](GITHUB_MODELS.md) — `.prompt.yml` copy-review aids
  that map to the four doctrines, how they run in CI, and how to add one

## The doctrines

These four constrain every change. The first is the most important document in
the repository.

- [Safety framing](SAFETY-FRAMING.md) — **awareness, not safety.** Every spoken,
  captioned, and haptic string hedges and never asserts certainty it has not
  earned
- [Accessibility standards](ACCESSIBILITY.md) — VoiceOver testing and labeling
  standards; zero unlabeled elements is a hard gate, not a percentage
- [Privacy](PRIVACY.md) — the on-device guarantee and the consent rules for
  anything that would ever leave the phone
- [Security model](SECURITY-MODEL.md) — trust boundaries, threat model, supply
  chain, and the permission surface

## Setup and distribution

- [Quick start](QUICK-START.md) — the fastest path from clone to a running app
  on your own device, plus the living usage guide for what each feature does
  today
- [Environment](ENVIRONMENT.md) — toolchain and development environment setup
- [Secrets and tokens](SECRETS.md) — every CI, deployment, and local credential,
  and what breaks without it. The shipped app holds no keys at all
- [Distribution](DISTRIBUTION.md) — the TestFlight and App Store path, and the
  one real cost involved

## Reference

- [Glossary and reading paths](GLOSSARY.md) — project vocabulary, and a starting
  route through these docs for each kind of reader
- [Tooling](TOOLING.md) — the global-vs-project tooling decision matrix and MCP
  inventory
- [Local AI (Ollama)](OLLAMA.md) — local LLM experiments; not an app dependency
- [NotebookLM](NOTEBOOKLM.md) — manual setup for project research

## Maintainer

<img src="assets/kevin-le.jpg" alt="Kevin K. Le, the current sole developer of the project" width="120">

**Kevin K. Le** — sole maintainer. Contact details are in
[`MAINTAINERS.md`](https://github.com/kevinle3212/sensebridge/blob/main/MAINTAINERS.md);
acknowledgments and third-party credits are in
[`CREDITS.md`](https://github.com/kevinle3212/sensebridge/blob/main/CREDITS.md);
governance and how decisions get made are in
[`GOVERNANCE.md`](https://github.com/kevinle3212/sensebridge/blob/main/GOVERNANCE.md).

---

Need help? See [`SUPPORT.md`](https://github.com/kevinle3212/sensebridge/blob/main/SUPPORT.md).
