# Sound classifier training data

Not run in CI or as part of `npm run app:build` — this produces the training
data for the *offline* Create ML training step, run once by a maintainer,
not per-build.

## History — why this isn't a single ESC-50 clone anymore

The first version of this model trained entirely on
[ESC-50](https://github.com/karoldvl/ESC-50), on the strength of the
compilation's reputation as "CC BY 4.0" rather than a direct check of its own
license file. That was wrong: ESC-50 as a whole is **CC BY-NC 3.0**
(NonCommercial) — only its 10-class **ESC-10** subset is CC BY (3.0, not
4.0). A `model-license-audit` caught this
(`audits/model-license/20260805-000315-esc-50-sound-classifier-training-data-license-verification.md`).
Separately, that same version trained its `fire_alarm` class on ESC-50's
`church_bells` category as a placeholder proxy, which a `safety-framing`
audit flagged as a live defect: the app could announce a fire alarm on
hearing a church bell
(`audits/safety-framing/20260805-000401-alpha-scaffolding-sound-alerts-onboarding-wired-vision-surfaces.md`).

The current version fixes both: `dog_bark` and `baby_cry` still come from
ESC-10 (genuinely CC BY 3.0), and the other five classes —
`fire_alarm`, `car_horn`, `siren`, `glass_shatter`, `knock` — are sourced
clip-by-clip directly from [Freesound](https://freesound.org/), each
verified against **its own** license page rather than trusted from a
compilation's blanket claim. `fire_alarm` is now trained on real fire/smoke
alarm recordings, not a proxy category.

## Steps

### ESC-10 classes (`dog_bark`, `baby_cry`)

1. `git clone https://github.com/karoldvl/ESC-50.git /tmp/ESC-50` (dataset as
   a whole is CC BY-NC 3.0 — do not use categories outside the ESC-10 subset
   without independently re-verifying their license).
2. `swift models/sound-classifier/prepare-training-data.swift /tmp/ESC-50 models/sound-classifier/training-data`
   — this only maps `dog`→`dog_bark` and `crying_baby`→`baby_cry` from
   ESC-10; every other category it maps is **not** commercially clean and
   must not be used (see the script's own comments).

### The other five classes (`fire_alarm`, `car_horn`, `siren`, `glass_shatter`, `knock`)

Sourced individually from Freesound, each clip verified directly against its
own page for an actual CC0 or CC BY license before downloading — never
trust a search result's summary, an aggregator, or a dataset compilation's
stated license without checking the source. The full record of what was
verified and downloaded (author, license, license URL, source URL) is
[`freesound-training-data/MANIFEST.csv`](freesound-training-data/MANIFEST.csv) —
committed even though the audio itself is gitignored, so the provenance
survives independent of the training run that produced it.

To reproduce or extend: find candidate clips on freesound.org filtered to
license `Creative Commons 0` (no attribution needed) or `Attribution` (CC
BY, needs the author credited — see `CREDITS.md`), fetch each candidate's
own page and confirm the license link in the page's HTML points to
`creativecommons.org/publicdomain/zero/1.0/` (CC0) or
`creativecommons.org/licenses/by/<version>/` (CC BY) — not a `by-nc` link,
which is NonCommercial and unusable here — then download the clip via its
public preview URL (`https://cdn.freesound.org/previews/<id-prefix>/<id>_<uploader-id>-hq.mp3`,
found in the page's own HTML; no Freesound account or API key required for
this quality tier). Append a row to `MANIFEST.csv` for every clip used.

### The eighth class: `background`

`fire_alarm`, `car_horn`, `siren`, `glass_shatter`, `knock`, `dog_bark`, and
`baby_cry` are a **closed set with no reject option** — a Create ML sound
classifier must assign every input to one of its trained classes. A
safety-framing audit
(`audits/safety-framing/20260806-064241-custom-sound-classifier-out-of-distribution-false-positives-reach-spoken-output.md`)
measured the consequence on the shipped model: room hiss, white noise, a
1kHz tone, and a frequency sweep all scored `fire_alarm` or `siren` at
**1.000 confidence**, clearing the app's floor and reaching the strongest
spoken hedge tier in a quiet room.

The fix is an eighth `background` class covering exactly that space — see
`gen-background-training-data.swift`, which synthesizes it (noise colors,
tones, hums, sweeps, an ambient chord, a click train) rather than sourcing
it from Freesound: this content has no license to verify, so it needs no
`MANIFEST.csv` row. `background` is **not** listed in
`CustomSoundClassifier.targetClassNames` — the model can predict it, but
`SoundClassificationRunner` filters every prediction against that set, so a
`background` verdict is silently dropped instead of becoming a spoken claim.
`CustomSoundClassifierOODTests`
(`app/SenseBridgeTests/`) pins this: it runs the shipped model against the
same out-of-distribution audio and fails if a future retrain regresses it.

### Training

1. Combine the ESC-10 output (`training-data/`), the Freesound clips
   (`freesound-training-data/`), and the synthetic background clips
   (`swift models/sound-classifier/gen-background-training-data.swift models/sound-classifier/combined-training-data/background`)
   into one directory tree, one subdirectory per class — see
   `combined-training-data/` for the exact layout the bundled model was
   actually trained on.
2. `swift models/sound-classifier/train.swift models/sound-classifier/combined-training-data app/SenseBridge/Resources/SenseBridgeSoundClassifier.mlmodel`

`training-data/`, `freesound-training-data/*` (except `MANIFEST.csv`), and
`combined-training-data/` are all gitignored — only the trained `.mlmodel`
and the attribution manifest are committed, not the raw audio clips. The
trained model is written directly into `app/SenseBridge/Resources/`
(alongside `Assets.xcassets`) rather than kept here, so the app target's
existing folder reference picks it up as a bundled resource automatically —
the same way `Assets.xcassets` already does — with no separate resource entry
in the Xcode project and no second copy to keep in sync after retraining.

## Class coverage

`BuiltInSoundClassifier.targetClassNames` also lists `smoke_detector` and
`telephone_bell_ringing`, which this custom model was never trained on —
those two are only ever detected via `BuiltInSoundClassifier` (Apple's
built-in taxonomy), never via `CustomSoundClassifier`.

## Known limitation: small per-class clip counts

This dataset is intentionally small (8–16 clips per class: 8–15 for the five
Freesound-sourced classes, 10 each for the ESC-10 classes, 16 synthetic clips
for `background`) — good enough for an honest alpha, not a production-scale
classifier. Whole-dataset training/validation error swings widely run to run
on a corpus this small (a prior audit measured a 7.2%–43% spread across three
reruns of the same script on the same data) — treat any single run's number
as one draw, not a stable metric, and see
`audits/safety-framing/20260805-205701-fire-alarm-siren-validation-error-alpha-acceptability-verdict.md`
for why per-class numbers aren't persisted here. Expanding each class's clip
count is real future work, not urgent for alpha.
