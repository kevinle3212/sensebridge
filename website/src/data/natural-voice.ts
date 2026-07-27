/**
 * Single source of truth for "does the pre-rendered natural-voice narration
 * ship on this route?". Two components need the same answer and must never
 * disagree: `ReadAloud.astro` renders the playback control, and
 * `Footer.astro` renders the ElevenLabs attribution that the control's audio
 * legally requires (see `website/README.md` → "Cost, quota, and licensing").
 * A credit with no audio would be a false statement; audio with no credit
 * would be a licence breach.
 */
import { existsSync } from "node:fs";
import path from "node:path";

import type { Locale } from "../i18n";

/**
 * Whether `/audio/main.mp3` is both generated and appropriate for `locale`.
 *
 * Resolved against the project root rather than `import.meta.url`: this runs
 * in frontmatter, which Astro bundles into `dist/.prerender/chunks/`, so a
 * module-relative path would resolve to a non-existent `dist/public/...` and
 * the answer would always be `false`. `astro build` runs at the project root,
 * which is where `public/` lives.
 *
 * English-only: the narration is generated from the English page, so offering
 * it on `/es/` or `/vi/` would play English audio to a visitor who chose
 * another language. Lift the locale check once per-locale narration exists
 * (see the follow-up in `TODO.md`).
 */
export function hasNaturalVoice(locale: Locale): boolean {
  return locale === "en" && existsSync(path.join(process.cwd(), "public", "audio", "main.mp3"));
}
