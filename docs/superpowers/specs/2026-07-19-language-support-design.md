# Language support: English, Spanish, Vietnamese — design spec

Date: 2026-07-19 · Status: approved (owner, in-session) · Scope: iOS app + website

## Decisions (owner-approved)

- Surfaces: **app and website**.
- Language selection: **both** iOS per-app language (free once localizations are
  declared) **and** an in-app picker (`Settings.language`, default `system`).
- Mechanisms: Apple String Catalogs + `String(localized:locale:)` in the app;
  Astro built-in i18n routing + `t()` dictionary modules on the website. No new
  dependencies on either surface.
- Translations drafted by agents; **native-speaker validation is a tracked
  follow-up in `TODO.md`** (machine-verifiable gates cannot prove translation
  quality).

## Doctrine-pinned strings (safety-framing enforcement point)

`Phrasing` hedge templates are format strings (never concatenation) so target
grammars can reorder. Pinned baseline — reviewers verify, native speakers
validate later:

| Certainty | en | es | vi |
|---|---|---|---|
| low | `there might be %@.` | `puede que haya %@.` | `có thể có %@.` |
| medium | `it looks like there's %@.` | `parece que hay %@.` | `hình như có %@.` |
| high | `it looks like there's likely %@.` | `parece que probablemente hay %@.` | `rất có thể có %@.` |

Fallback (composer, no detections): en `Nothing recognizable was found.` ·
es `No se reconoció nada.` · vi `Không nhận ra được gì.`

Invariant preserved: **no language ever gets an unhedged assertion**, including
`high` certainty.

## Unit A — SenseBridgeCore localization

- `Package.swift`: `defaultLocalization: "en"`, package String Catalog resource.
- `Phrasing.describe(subject:certainty:locale:)` — locale-parameterized, pure,
  loads templates via `String(localized:...locale:)`.
- `LabelListSceneComposer` takes a locale; fallback string localized.
- `SpeechRenderTarget`: voice selection by BCP-47 fallback chain — exact locale
  → any same-language voice → system default. `RenderTarget` protocol stays
  free of AVFoundation types.
- `AppLanguage` enum (`system`, `en`, `es`, `vi`) + `Settings.language`
  (default `.system`); Codable round-trip stays backward-compatible with
  previously persisted settings (missing key → `.system`).
- Tests: per-language hedge presence (all three certainties × three languages),
  fallback-string localization, settings round-trip + legacy decode, voice
  fallback chain.

## Unit B — App UI (depends on A)

- `Localizable.xcstrings` covering all view literals, accessibility labels, and
  hints; `InfoPlist.xcstrings` for camera/mic usage descriptions; `project.yml`
  updated so localizations build (dev region en; es, vi).
- New `SettingsView`: single language picker, every element labeled for
  VoiceOver; reachable from `HomeView`. Selection persists via `SettingsStore`
  and drives `\.locale` (live switch, no relaunch) and the speech voice.
- Declaring es/vi localizations lights up the iOS per-app language setting.
- e2e floor (3): switch to Spanish → UI + labels update (happy); language whose
  voice is uninstalled → speech still renders via fallback (error); `.system`
  with device set to Vietnamese → vi output (edge).

## Unit C — Website i18n (independent)

- `astro.config`: `i18n { defaultLocale: "en", locales: ["en","es","vi"] }` →
  `/`, `/es/`, `/vi/`.
- Copy extracted from components into `src/i18n/{en,es,vi}.ts`; components
  receive strings via a small `t()` helper on `Astro.currentLocale`.
- `BaseLayout`: per-locale `lang` attribute, `hreflang` alternate links.
- Header language switcher: keyboard- and screen-reader-accessible, current
  language indicated non-visually too (site doctrine: screen-reader-first,
  honesty over hype — translated copy must not drift from safety framing).
- Verification: `astro build` + `astro check` green; all three routes render.

## Review gates

- `safety-framing-reviewer`: every es/vi output string (hedges, fallback,
  permission strings, website disclaimer/safety copy).
- `accessibility-reviewer`: `SettingsView` picker + website switcher; zero
  unlabeled elements.
- Build + full test suite green (`swift test` for Core; xcodegen + xcodebuild
  for app; `astro build` for website).

## Known limitation (documented, deferred)

Vision detector labels arrive in English; the fallback composer may localize
the hedge around an English noun until the Foundation-Models composer exists.
Tracked in `TODO.md`; not solved in this change.

---

Need help? See [`SUPPORT.md`](../../../SUPPORT.md).
