# Credits

SenseBridge is built and maintained by Kevin K. Le.

## Maintainers

<img src="docs/assets/kevin-le.jpg" alt="Kevin K. Le, the current sole developer of the project" width="120">

- Kevin K. Le — <kevinle3212@gmail.com>

## Contributors

Thanks to everyone who has contributed. See the full list at
<https://github.com/kevinle3212/sensebridge/graphs/contributors>.

## Acknowledgments

SenseBridge is built primarily on Apple's own frameworks (Vision, Foundation
Models, SpeechAnalyzer/SpeechTranscriber, AVSpeechSynthesizer, Sound Analysis,
ARKit/LiDAR, VisionKit, Core Haptics). Any bundled on-device ML model beyond
Apple's frameworks is recorded with its license in
[`models/README.md`](models/README.md) — see also
[`docs/AI-MODELS.md`](docs/AI-MODELS.md) for why licensing gets this much
attention here (two of the strongest-looking candidate models, Ultralytics
YOLO and Apple FastVLM, are license traps this project deliberately avoids).

The Sound Alerts feature's custom classifier
(`app/SenseBridge/Resources/SenseBridgeSoundClassifier.mlmodel`) is trained
in-house via Create ML — no third-party weights — on individually
license-verified clips from [Freesound](https://freesound.org/) (`dog_bark`
and `baby_cry` come from the CC BY 3.0-licensed
[ESC-10](https://github.com/karoldvl/ESC-50#esc-10) subset of
[ESC-50](https://github.com/karoldvl/ESC-50) by Karol J. Piczak; the other
five classes were sourced clip-by-clip directly from Freesound, each
verified against its own license page rather than trusted from a
compilation's blanket claim — see
[`models/sound-classifier/README.md`](models/sound-classifier/README.md) for
why). The full per-clip record (author, license, source URL) is
[`models/sound-classifier/freesound-training-data/MANIFEST.csv`](models/sound-classifier/freesound-training-data/MANIFEST.csv).
Most clips are [CC0](https://creativecommons.org/publicdomain/zero/1.0/) (no
attribution required); two require it under
[CC BY 3.0](https://creativecommons.org/licenses/by/3.0/):

- "Car Horn Honk" by [etcd_09](https://freesound.org/people/etcd_09/sounds/435497/)
- "sim police siren.wav" by [THE_bizniss](https://freesound.org/people/THE_bizniss/sounds/58375/)

No modifications were made to any clip beyond format conversion for
training.

The marketing site's pre-rendered "natural voice" narration
(`website/public/audio/main.mp3`) was generated with
[elevenlabs.io](https://elevenlabs.io), using the "Janet" voice from its Voice
Library. This applies to the website only — **the iOS app contains no
ElevenLabs audio, code, or network call**, and its speech output is Apple's
on-device `AVSpeechSynthesizer`, as the on-device architecture requires. The
narration was generated on ElevenLabs' free plan, which grants no commercial
licence and requires published content to credit `elevenlabs.io`; that credit
also appears in the site footer on every route that ships the audio, next to
ElevenLabs' own mark (the two bars from their `icon.svg`, redrawn in the
site's own colours). The mark is used for attribution only, and implies no
endorsement or affiliation. See
[`website/README.md`](website/README.md) → "Cost, quota, and licensing".

## Website "Powered by" marks

The site footer names the stack it is built on: Astro, Vercel, GSAP, Three.js,
Lenis, and Sass. Where a brand publishes a glyph that stays legible at 14px,
the name is accompanied by that glyph, taken from
[simple-icons](https://github.com/simple-icons/simple-icons) — the icon data is
CC0-1.0, while each glyph remains the trademark of its owner. The marks are
used to identify the technology, imply no endorsement or affiliation, and are
rendered monochrome in the site's own text colour rather than in brand colours.

Monochrome is a technical necessity, not only a stylistic one: GSAP publishes
its logo in a cream tuned for dark backgrounds that would disappear against the
light theme, and Vercel and Three.js are monochrome by design and publish no
colour vector at all.

GSAP, Three.js, and Lenis appear as text with no glyph. Lenis publishes no
compact mark (only a 1360×384 wordmark); the other two publish marks that
render as a smudge at 14px — GSAP's carries 8.6 kB of path data and still does
not read. Path data lives in
[`website/src/data/powered-by.ts`](website/src/data/powered-by.ts).

## Vendored agentic files

The offline SEO skills below were adapted from
[claude-seo](https://github.com/AgriciDaniel/claude-seo) (v2.2.0), which is MIT
licensed (upstream notice retained as `LICENSE.txt` inside each skill
directory). Only the offline audit slice was vendored — upstream's live
integrations (IndexNow, DataForSEO, Google APIs) and Playwright scripts were
deliberately excluded; see the adaptation header in `seo-technical` and
[`docs/TOOLING.md`](docs/TOOLING.md).

- [`.agents/skills/seo-schema`](.agents/skills/seo-schema/SKILL.md) (canonical,
  shared across harnesses via `.agents/manifest.json`;
  `.claude/skills/seo-schema` is a symlink to it)
- [`.agents/skills/seo-technical`](.agents/skills/seo-technical/SKILL.md)
  (same setup)

The Swift skills and review agents below were adapted from
[ECC](https://github.com/affaan-m/ecc) (v2.0.0, commit `ed38744`), which is MIT
licensed. They are adapted, not verbatim: each was reshaped to this repository's
conventions and annotated with the SenseBridge invariant it serves.

- [`.agents/skills/swift-concurrency-6-2`](.agents/skills/swift-concurrency-6-2/SKILL.md)
- [`.agents/skills/swift-protocol-di-testing`](.agents/skills/swift-protocol-di-testing/SKILL.md)
- [`.agents/skills/swift-actor-persistence`](.agents/skills/swift-actor-persistence/SKILL.md)
- [`.agents/agents/swift-reviewer.md`](.agents/agents/swift-reviewer.md)
- [`.agents/agents/swift-build-resolver.md`](.agents/agents/swift-build-resolver.md)

MIT is compatible with this project's Apache-2.0 license, which requires the
upstream notice be retained:

```text
MIT License

Copyright (c) 2026 Affaan Mustafa

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
```

## Vendored fonts

The website self-hosts three variable fonts as `.woff2` files committed under
[`website/public/fonts/`](website/public/fonts), each alongside its upstream
license text. They are served directly by absolute `/fonts/*.woff2` URLs from
the `@font-face` blocks in `website/src/styles/global/_base.scss` — no build
step, bundler, or npm package is involved at runtime.

Provenance is recorded here because it is no longer recorded anywhere else. The
files were originally extracted from Fontsource packages, which were pinned in
`website/package.json` purely as a version marker; nothing ever imported them,
so React Doctor's `deslop/unused-dev-dependency` rule correctly flagged all
three and they were removed on 2026-07-25. Use the versions below as the
baseline when refreshing a font.

| Font                | Upstream source                                                     | Extracted from                    | Version |
| ------------------- | ------------------------------------------------------------------- | --------------------------------- | ------- |
| Fraunces Variable   | [undercasetype/Fraunces](https://github.com/undercasetype/Fraunces) | `@fontsource-variable/fraunces`   | 5.2.9   |
| Geist Variable      | [vercel/geist-font](https://github.com/vercel/geist-font)           | `@fontsource-variable/geist`      | 5.2.9   |
| Geist Mono Variable | [vercel/geist-font](https://github.com/vercel/geist-font)           | `@fontsource-variable/geist-mono` | 5.2.8   |

All three are licensed under the SIL Open Font License, Version 1.1, which is
compatible with this project's Apache-2.0 license and requires that the
copyright notice be retained with the font files. Each font's notice lives
beside it:

| License file             | Copyright holder                                      |
| ------------------------ | ----------------------------------------------------- |
| `fraunces-LICENSE.txt`   | Copyright 2018 The Fraunces Project Authors           |
| `geist-LICENSE.txt`      | Copyright 2024 The Geist Project Authors              |
| `geist-mono-LICENSE.txt` | Copyright 2024 The Geist Project Authors (Geist Mono) |

When vendoring or refreshing a font, copy its license from that font's own
upstream repository — not from a sibling already in this directory. On
2026-07-25 `fraunces-LICENSE.txt` was found to be byte-identical to
`geist-LICENSE.txt`, so Fraunces had been shipping under Geist's copyright
notice; it was replaced with the real notice from
[undercasetype/Fraunces](https://github.com/undercasetype/Fraunces). The three
files now have three distinct checksums, which is the quickest way to re-check.

## License

SenseBridge is released under the Apache-2.0 license. See
[`LICENSE`](./LICENSE).

---

Need help? See [`SUPPORT.md`](SUPPORT.md).
