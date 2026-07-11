# SenseBridge

Open-source, on-device, private accessibility.

SenseBridge is a free, open-source iPhone app that translates a blind or
low-vision person's surroundings into clear spoken information, processing
everything on the device by default so the user's camera and surroundings
never have to leave their phone.

No competitor combines **open source + offline-by-default + user-controlled +
multi-sense architecture**. That combination — not raw scene-description
quality — is the wedge. See [`docs/PRODUCT.md`](docs/PRODUCT.md) for the full
positioning and [`docs/planning/`](docs/planning/) for the source research
this project is built from.

## Scope (MVP)

The current build targets **blind and low-vision users, on iPhone, on-device,
via VoiceOver**:

- Reading printed text and documents aloud.
- Identifying common objects and surfaces.
- Describing a scene in a natural sentence.
- Cautious obstacle awareness using LiDAR (never navigation — see
  [`docs/safety-framing.md`](docs/safety-framing.md)).
- Awareness of important sound events.

## Explicitly out of scope for now

Deferred by design, not by oversight — see
[`docs/roadmap.md`](docs/roadmap.md) for when and why:

- Deaf and deaf-blind user support (different sensing/rendering problems;
  later phases).
- Wearables and AR glasses (Apple Watch, Vision Pro, Meta glasses).
- Facial recognition and enrollment (deferred behind a careful consent flow;
  biometric law exposure).
- Any backend, account system, or cloud processing. There is no server, and
  that absence is deliberate.
- Real-time turn-by-turn navigation guidance. SenseBridge provides cautious,
  probabilistic *awareness*, never safety or navigation guarantees.

## Build and run

The Xcode project lives under [`app/`](app/) (native Swift/SwiftUI, no
external framework dependencies for the MVP — see
[`docs/architecture.md`](docs/architecture.md)). Development and on-device
testing require a Mac and Xcode; a LiDAR-equipped iPhone (12 Pro or later) is
needed to exercise obstacle awareness, and model-latency benchmarking should
be done on the newest iPhone you have access to. See
[`docs/ENVIRONMENT.md`](docs/ENVIRONMENT.md) for setup and
[`scripts/setup.sh`](scripts/setup.sh) for the bootstrap script. Distributing
builds to other testers (TestFlight/App Store) requires the paid Apple
Developer Program — see [`docs/DISTRIBUTION.md`](docs/DISTRIBUTION.md).

## Documentation

| Doc | Covers |
| --- | --- |
| [`docs/PRODUCT.md`](docs/PRODUCT.md) | Vision, personas, funding, differentiators |
| [`docs/roadmap.md`](docs/roadmap.md) | Five-phase roadmap, MVP definition, open questions |
| [`docs/architecture.md`](docs/architecture.md) | System design, protocols, data flow |
| [`docs/ai-models.md`](docs/ai-models.md) | On-device model choices and licenses |
| [`docs/safety-framing.md`](docs/safety-framing.md) | The awareness-not-safety doctrine |
| [`docs/accessibility.md`](docs/accessibility.md) | VoiceOver testing and labeling standards |
| [`docs/privacy.md`](docs/privacy.md) | On-device data handling guarantees |
| [`docs/TESTING.md`](docs/TESTING.md) | Test strategy, including field testing with blind users |
| [`docs/ENVIRONMENT.md`](docs/ENVIRONMENT.md) | Dev environment setup |
| [`docs/DISTRIBUTION.md`](docs/DISTRIBUTION.md) | TestFlight / App Store distribution |
| [`docs/FAQ.md`](docs/FAQ.md) | Common questions |
| [`docs/TOOLING.md`](docs/TOOLING.md) | Tooling decisions (global vs. project) |
| [`docs/planning/`](docs/planning/) | The original research and planning documents |

The full index, including root orientation docs (`PROJECT_OVERVIEW.md`,
`GAPS.md`, `MEMORY.md`, `LEARNING.md`), lives in [`WIKI.md`](WIKI.md).

## Contributing

See [`CONTRIBUTING.md`](CONTRIBUTING.md) for setup, build, test, and PR
process, and [`CODE_OF_CONDUCT.md`](CODE_OF_CONDUCT.md) for community
standards. Accessibility regressions are treated as the most serious kind of
bug — every PR must state its accessibility impact.

## License

Apache 2.0 — see [`LICENSE`](LICENSE). Every bundled model's license is vetted
and recorded in [`models/README.md`](models/README.md); SenseBridge never
bundles AGPL or non-commercial-research-only components (see
[`docs/ai-models.md`](docs/ai-models.md)).

## Governance and security

This is currently a solo-maintained project — see
[`GOVERNANCE.md`](GOVERNANCE.md). Report vulnerabilities privately per
[`SECURITY.md`](SECURITY.md).
