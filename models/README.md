# Bundled Model Provenance

Enforcement ledger for every model this repository bundles or plans to bundle.
Full rationale and the license table: [`docs/AI-MODELS.md`](../docs/AI-MODELS.md).
**Do not add a model here without also updating `docs/AI-MODELS.md` in the
same change.**

| Model | License | Source | Verified | Status |
| --- | --- | --- | --- | --- |
| Apple Vision (OCR, detection) | Apple SDK | Apple platform framework | June 2026 | Planned — not yet integrated |
| Apple Foundation Models | Apple SDK | Apple platform framework | June 2026 | Planned — not yet integrated |
| Apple SpeechAnalyzer / SpeechTranscriber | Apple SDK | Apple platform framework | June 2026 | Planned (deaf phase) |
| Apple Sound Analysis | Apple SDK | Apple platform framework | June 2026 | Planned — not yet integrated |

No third-party model weights are bundled yet. When one is added (SmolVLM,
SmolVLM2, Qwen2-VL-2B, Moondream2, whisper.cpp, Tesseract, or YAMNet are the
pre-vetted Apache 2.0/MIT options — see `docs/AI-MODELS.md`), add a row here
with its license, upstream source URL, and the date you personally verified
the license tag on that source.

## sound/

Reserved for Create ML sound classifiers (permissive licenses only — see
`docs/AI-MODELS.md`'s license checklist before adding anything here).

## Forbidden / quarantined (do not add without a written license change)

- **Ultralytics YOLO** — AGPL-3.0. Would force this entire project to AGPL.
- **Apple FastVLM** — `apple-amlr`, non-commercial research only.
- **Apple MobileCLIP** — ambiguous/mixed license signals; quarantined until
  Apple clarifies in writing.

---

Need help? See [`SUPPORT.md`](../SUPPORT.md).
