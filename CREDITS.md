# Credits

SenseBridge is built and maintained by Kevin K. Le.

## Maintainers

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

## Vendored agentic files

The offline SEO skills below were adapted from
[claude-seo](https://github.com/AgriciDaniel/claude-seo) (v2.2.0), which is MIT
licensed (upstream notice retained as `LICENSE.txt` inside each skill
directory). Only the offline audit slice was vendored — upstream's live
integrations (IndexNow, DataForSEO, Google APIs) and Playwright scripts were
deliberately excluded; see the adaptation header in `seo-technical` and
[`docs/TOOLING.md`](docs/TOOLING.md).

- [`.claude/skills/seo-schema`](.claude/skills/seo-schema/SKILL.md) (mirrored
  to all five harness skill dirs via `tools/sync-skills.mjs`)
- [`.claude/skills/seo-technical`](.claude/skills/seo-technical/SKILL.md)
  (mirrored the same way)

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

## License

SenseBridge is released under the Apache-2.0 license. See
[`LICENSE`](./LICENSE).

---

Need help? See [`SUPPORT.md`](SUPPORT.md).
