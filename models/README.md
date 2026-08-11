# Bundled Model Provenance

Enforcement ledger for every model this repository bundles or plans to bundle.
Full rationale and the license table: [`docs/AI-MODELS.md`](../docs/AI-MODELS.md).
**Do not add a model here without also updating `docs/AI-MODELS.md` in the
same change.**

| Model | License | Source | Verified | Status |
| --- | --- | --- | --- | --- |
| Apple Vision (OCR, detection) | Apple SDK | Apple platform framework | June 2026 | Integrated — Reading, Identify, Describe |
| Apple Foundation Models | Apple SDK | Apple platform framework | June 2026 | Integrated — Describe (`FoundationModelsSceneComposer`) |
| Apple SpeechAnalyzer / SpeechTranscriber | Apple SDK | Apple platform framework | June 2026 | Planned (deaf phase) |
| Apple Sound Analysis | Apple SDK | Apple platform framework | June 2026 | Integrated — Sound Alerts (`BuiltInSoundClassifier`) |
| SenseBridge sound classifier (`sound-classifier/`) | CC0 + CC BY 3.0, per-clip (training data) — see [`freesound-training-data/MANIFEST.csv`](sound-classifier/freesound-training-data/MANIFEST.csv) | Trained in-house via Create ML — not third-party weights. `dog_bark`/`baby_cry`: ESC-10 subset of [ESC-50](https://github.com/karoldvl/ESC-50) (CC BY 3.0). `fire_alarm`/`car_horn`/`siren`/`glass_shatter`/`knock`: individually verified clips from [Freesound](https://freesound.org/) | 2026-08-05 | Integrated — Sound Alerts (`CustomSoundClassifier`). Retrained after a `model-license-audit` FAIL on the first version (ESC-50's dataset-wide license is CC BY-**NC** 3.0, not CC BY 4.0 as first assumed) — see `audits/model-license/20260805-000315-esc-50-sound-classifier-training-data-license-verification.md` |

No other third-party model weights are bundled yet. When one is added
(SmolVLM, SmolVLM2, Qwen2-VL-2B, Moondream2, whisper.cpp, Tesseract, or
YAMNet are the pre-vetted Apache 2.0/MIT options — see `docs/AI-MODELS.md`),
add a row here with its license, upstream source URL, and the date you
personally verified the license tag on that source.

## sound-classifier/

The bundled Create ML sound classifier: [`sound-classifier/README.md`](sound-classifier/README.md)
documents the per-clip-verified training data (ESC-10 for two classes,
individually-sourced Freesound clips for the other five), why it isn't a
single ESC-50 clone, and how to retrain it. The trained `.mlmodel` itself
ships from `app/SenseBridge/Resources/`, not from this directory — see that
README for why. Attribution lives in [`CREDITS.md`](../CREDITS.md) and
[`sound-classifier/freesound-training-data/MANIFEST.csv`](sound-classifier/freesound-training-data/MANIFEST.csv).

## Forbidden / quarantined (do not add without a written license change)

- **Ultralytics YOLO** — AGPL-3.0. Would force this entire project to AGPL.
- **Apple FastVLM** — `apple-amlr`, non-commercial research only.
- **Apple MobileCLIP** — ambiguous/mixed license signals; quarantined until
  Apple clarifies in writing.

---

Need help? See [`SUPPORT.md`](../SUPPORT.md).
