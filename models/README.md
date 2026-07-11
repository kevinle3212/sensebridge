# Bundled Model Provenance

Enforcement ledger for every model this repository bundles or plans to bundle.
Full rationale and the license table: [`docs/ai-models.md`](../docs/ai-models.md).
**Do not add a model here without also updating `docs/ai-models.md` in the
same change.**

| Model | License | Source | Verified | Status |
|---|---|---|---|---|
| Apple Vision (OCR, detection) | Apple SDK | Apple platform framework | June 2026 | In use |
| Apple Foundation Models | Apple SDK | Apple platform framework | June 2026 | In use |
| Apple SpeechAnalyzer / SpeechTranscriber | Apple SDK | Apple platform framework | June 2026 | Planned (deaf phase) |
| Apple Sound Analysis | Apple SDK | Apple platform framework | June 2026 | In use |

No third-party model weights are bundled yet. When one is added (SmolVLM,
SmolVLM2, Qwen2-VL-2B, Moondream2, whisper.cpp, Tesseract, or YAMNet are the
pre-vetted Apache 2.0/MIT options — see `docs/ai-models.md`), add a row here
with its license, upstream source URL, and the date you personally verified
the license tag on that source.

## sound/

Reserved for Create ML sound classifiers (permissive licenses only — see
`docs/ai-models.md`'s license checklist before adding anything here).

## Forbidden / quarantined (do not add without a written license change)

- **Ultralytics YOLO** — AGPL-3.0. Would force this entire project to AGPL.
- **Apple FastVLM** — `apple-amlr`, non-commercial research only.
- **Apple MobileCLIP** — ambiguous/mixed license signals; quarantined until
  Apple clarifies in writing.
