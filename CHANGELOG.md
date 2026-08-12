# Changelog

All notable changes to SenseBridge are documented here.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

- A description-detail preference (Settings → Descriptions: Brief/Standard/
  Detailed) controlling how many things a spoken description names and how
  much wording it uses — never how certain it sounds. Applies to the
  on-device, Local, and Cloud reasoning backends alike.

### Changed

- `legal/PRIVACY_POLICY.md` and `legal/SUBPROCESSORS.md` updated to disclose
  the optional, off-by-default Local and Cloud (Anthropic/OpenAI/NVIDIA NIM,
  bring-your-own-key) reasoning backends — only recognized object labels can
  leave the device, and only after explicit opt-in.
- Distance units are now spoken as full words ("feet", "inches") instead of
  abbreviations ("ft", "in"), which a speech synthesizer could misread as
  unrelated words.
- The no-Apple-Intelligence fallback composer now groups descriptions by
  certainty ("it looks like there's a chair and a table.") instead of
  repeating one full hedged sentence per object.

### Fixed

## [0.1.0] - 2026-07-09

### Added

- Initial repository scaffold and AI development environment: governance,
  documentation, security policy, GitHub automation, and AI-agent tooling.
  No app code yet — see [`docs/ROADMAP.md`](docs/ROADMAP.md).

[Unreleased]: https://github.com/kevinle3212/sensebridge/compare/v0.1.0...HEAD
[0.1.0]: https://github.com/kevinle3212/sensebridge/releases/tag/v0.1.0

---

Need help? See [`SUPPORT.md`](SUPPORT.md).
