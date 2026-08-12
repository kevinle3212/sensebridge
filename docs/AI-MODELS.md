---
title: AI Models
---

# AI Models

**Read this before adding any model to the project.** Model licensing is the
highest-liability area in this repository — two of the most technically
attractive models available are legally unusable here, and getting this wrong
poisons the whole codebase's license. Enforcement ledger (provenance/date per
bundled model):
[`models/README.md`](https://github.com/kevinle3212/sensebridge/blob/main/models/README.md).

## The standing rule

**Vet every model's and every dependency's license before adding it, every
time — a permissive tag in a blog post or a README is not the license.** Check
the license tag directly on the model's own repository (Hugging Face, GitHub).
Prefer MIT and Apache 2.0. If a license is ambiguous or mixed, quarantine it
(research/local-experimentation only, never bundled in a shipped build) until
the vendor clarifies in writing.

## Pipeline

Two-stage, on-device, filtered through three constraints: free, on-device,
and license-clean.

1. **Perception** — Apple Vision (OCR, object/scene detection, no model to
   bundle, no license risk) + Apple Sound Analysis for sound events.
   Object naming runs two Vision passes rather than one, because a single
   whole-frame `ClassifyImageRequest` averages a cluttered room into one label
   and tends to answer with the wall:
   `GenerateObjectnessBasedSaliencyImageRequest` proposes the regions that look
   like discrete things, then each region is classified on its own via
   `ClassifyImageRequest.regionOfInterest`. Regions no identifier describes
   precisely enough are dropped rather than reported as a weak guess. The
   bounding boxes fall out of the same pass, which is what lets the awareness
   screen outline exactly what it is talking about. Whole-frame classification
   stays as the fallback for scenes with no discrete object in them.
2. **Reasoning** — Apple Foundation Models composes a hedged natural-language
   sentence from Vision's structured output via guided generation
   (`@Generable`). Text-only, on-device, Apple SDK license.

Reach for a bundled VLM (SmolVLM-class) only if on-device benchmarking on
real hardware shows Vision + Foundation Models is genuinely insufficient —
don't reach for it by default. See [ARCHITECTURE.md](ARCHITECTURE.md).

## License ledger

| Model / need | License | Status | Notes |
| --- | --- | --- | --- |
| Apple Vision (OCR, detection) | Apple SDK | **Primary — use** | No model to bundle, no license risk |
| Apple Foundation Models (scene reasoning) | Apple SDK | **Primary — use** | Text-only, ~4,096-token context window; two-stage with Vision |
| Apple SpeechAnalyzer / SpeechTranscriber (deaf phase STT) | Apple SDK | **Primary — use** | On-device, reported faster than Whisper Large V3 Turbo |
| Apple Sound Analysis (+ Create ML) | Apple SDK | **Primary — use** | Built-in classifier plus custom models |
| SenseBridge sound classifier training data (`models/sound-classifier/`) | CC0 + CC BY 3.0, per-clip | **Bundled — verified per clip** | The *framework* row above only clears Apple's SDK; this row is the actual bundled `.mlmodel`'s training-data provenance, tracked separately per `models/README.md`'s own cross-reference rule. `dog_bark`/`baby_cry`: ESC-10 subset of ESC-50 (CC BY 3.0 — **not** the ESC-50 compilation as a whole, which is CC BY-**NC** 3.0 and unusable here). The other five classes: individually verified against each clip's own Freesound page, not a compilation's blanket license claim — see `audits/model-license/20260805-000315-esc-50-sound-classifier-training-data-license-verification.md` for the audit that caught the original CC BY 4.0 mistake, and `models/sound-classifier/freesound-training-data/MANIFEST.csv` for the per-clip record. |
| SmolVLM / SmolVLM2 (256M–2.2B) | Apache 2.0 | **Safe to bundle** | Only if Vision + Foundation Models proves too weak; benchmark on device first |
| Qwen2-VL-2B | Apache 2.0 | **Safe to bundle** | Alternative richer-scene VLM option |
| Moondream2 | Apache 2.0 | **Safe to bundle** | Alternative richer-scene VLM option |
| whisper.cpp | MIT | **Safe to bundle** | STT fallback for older/cross-platform devices; thermally demanding under sustained real-time use |
| Tesseract | Apache 2.0 | **Safe to bundle** | OCR fallback, only if leaving Apple frameworks (cross-platform later) |
| YAMNet (521 sound classes) | Apache 2.0 | **Safe to bundle** | Sound detection for non-Apple targets, cross-platform later |
| llama.cpp (runtime, for future configurable on-device LLM provider) | MIT | **Safe to use** | Use Apache/MIT model weights only with it |
| **Ultralytics YOLO (v8, v11, newer)** | **AGPL-3.0** | **Do not bundle** | Confirmed AGPL. Forces the entire project (code, configs, weights) to AGPL or an Enterprise License. Use Apple Vision detection instead. |
| **Apple FastVLM** (0.5B / 1.5B / 7B) | **apple-amlr (non-commercial research only)** | **Do not bundle** | Confirmed across all variants (verified June 2026). Technically excellent, not usable in a shipping app. `apple-amlr` explicitly limits use to non-commercial research and excludes any commercial product or service. |
| **Apple MobileCLIP** | **Ambiguous / mixed** | **Quarantine — research only, do not ship** | Apple's own repos mix a restrictive `apple-amlr` LICENSE file with a permissive Apple Sample Code License weights file and dual metadata tags (verified June 2026). Do not ship in anything you might monetize until Apple clarifies in writing. |
| Anthropic / OpenAI / NVIDIA NIM (BYOK cloud reasoning) | Third-party service | **N/A — not a bundled model** | Opt-in only, disabled by default; the app calls the user's own account directly (BYOK), never a SenseBridge-run relay — no license-bundling question applies, since no model weights or SDK code ship in the app. The per-provider ToS-acceptance requirement lives in the app's consent UI (`ReasoningBackendSettingsView`), not in this checklist — see [PRIVACY.md](PRIVACY.md). |

## Adding a new model — checklist

1. Find the license tag directly on the model's own repository — not a blog
   post, not a secondary source.
2. If MIT or Apache 2.0 (or an equivalent permissive license): safe to add.
   Record it in
   [`models/README.md`](https://github.com/kevinle3212/sensebridge/blob/main/models/README.md)
   with source and verification date.
3. If AGPL, GPL, or a "research/non-commercial" tag (including `apple-amlr`):
   do not bundle it in anything shipped. Quarantine for local experimentation
   only, and say so explicitly in code comments and in `models/README.md`.
4. If the license is mixed, unclear, or undocumented: treat it as
   non-commercial/research-only until the vendor confirms otherwise in
   writing. Do not ship it "provisionally."
5. Update this table and `models/README.md` in the same change — an
   unrecorded model is an unaudited license risk.

## Resource and privacy notes

- Apple frameworks run on the Neural Engine/GPU and add nothing to bundle
  size for system-managed models (e.g. SpeechAnalyzer assets are downloaded
  and managed by the OS).
- Everything above is on-device and private by default. The only path
  off-device is the opt-in Local (self-hosted) or Cloud (BYOK) reasoning
  backend, each disabled until the user explicitly turns it on — see
  [PRIVACY.md](PRIVACY.md).
- Published on-device latency figures (for FastVLM and others) come from
  secondary sources and different devices — benchmark on your own hardware,
  don't trust a number you didn't measure.

---

Need help? See
[`SUPPORT.md`](https://github.com/kevinle3212/sensebridge/blob/main/SUPPORT.md).
