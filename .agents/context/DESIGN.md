---
name: SenseBridge
description: Open-source, on-device, private accessibility.
colors:
  ink: "#080a10"
  ink-elevated: "#0f131c"
  surface-slate: "#161b28"
  glass-slate: "rgba(15, 19, 28, 0.6)"
  fog-white: "#e8ebf2"
  muted-steel-blue-gray: "#a7afc2"
  signal-blue: "#5eb1ff"
  perception-glow: "#ffb37a"
  hairline-navy: "#2a3145"
  light-bg: "#f7f8fb"
  light-surface: "#eef1f7"
  light-ink: "#101422"
  light-muted: "#4d5468"
  light-signal-blue: "#145fc4"
  light-perception: "#a8480d"
  light-hairline: "#d4d9e4"
typography:
  display:
    fontFamily: "'Fraunces Variable', ui-serif, Georgia, serif"
    fontSize: "clamp(2.75rem, 1.3rem + 6.4vw, 6rem)"
    fontWeight: 350
    lineHeight: 1.02
    letterSpacing: "-0.02em"
  display-secondary:
    fontFamily: "'Fraunces Variable', ui-serif, Georgia, serif"
    fontSize: "clamp(2rem, 1.35rem + 2.9vw, 3.25rem)"
    fontWeight: 400
    lineHeight: 1.08
  heading-tertiary:
    fontFamily: "'Fraunces Variable', ui-serif, Georgia, serif"
    fontSize: "clamp(1.375rem, 1.18rem + 0.9vw, 1.75rem)"
    fontWeight: 500
    lineHeight: 1.18
  lede:
    fontFamily: "'Geist Variable', -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif"
    fontSize: "clamp(1.125rem, 1.02rem + 0.5vw, 1.375rem)"
    fontWeight: 400
    lineHeight: 1.55
  body:
    fontFamily: "'Geist Variable', -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif"
    fontSize: "clamp(1rem, 0.97rem + 0.15vw, 1.0625rem)"
    fontWeight: 400
    lineHeight: 1.6
  label:
    fontFamily: "'Geist Mono Variable', ui-monospace, SFMono-Regular, Menlo, monospace"
    fontSize: "0.8125rem"
    fontWeight: 500
    lineHeight: 1.4
rounded:
  sm: "8px"
  md: "12px"
  lg: "20px"
spacing:
  1: "8px"
  2: "16px"
  3: "24px"
  4: "40px"
  5: "64px"
  6: "96px"
  7: "128px"
components:
  nav-link:
    textColor: "{colors.signal-blue}"
    typography: "{typography.body}"
  callout:
    backgroundColor: "{colors.surface-slate}"
    textColor: "{colors.fog-white}"
    typography: "{typography.body}"
    rounded: "{rounded.sm}"
    padding: "16px 24px"
  cta-ghost:
    textColor: "{colors.fog-white}"
    borderColor: "{colors.signal-blue}"
    rounded: "{rounded.md}"
    padding: "8px 24px"
---

# Design System: SenseBridge

**Scope: the public marketing site under [`website/`](../../website) only** —
not the iOS app's SwiftUI UI, which this system does not govern. It lives here
rather than in `website/` because the `impeccable` skill resolves its context
from the repo root and checks `.agents/context/` before `docs/`. Its strategic
half is [`PRODUCT.md`](PRODUCT.md); see
[`docs/TOOLING.md`](../../docs/TOOLING.md) → "Impeccable project root".

Implementation source of truth: the SCSS token maps in
`website/src/styles/abstracts/` (`_tokens.scss`, `_typography.scss`,
`_motion.scss`). This document mirrors them for design review; if the two ever
disagree, the SCSS is what ships — fix the drift in the same change.

## 0. Doctrine status (2026-07-18 owner directive)

The owner voided the earlier visual-restraint doctrines for this site: the
WebGL ban, the Two-Accent Rule, the One Display Face Rule, the
no-box-shadow/Flat-By-Default rule, and the no-filled-CTA rule are **no longer
constraints**. What ships is governed by craft, not by those rules — this doc
describes the system actually built under that directive.

Three bars did **not** move and never will without an explicit owner decision:

- **Honesty.** Pre-launch is stated plainly; nothing implies a download
  exists; all physical-world language stays hedged ("awareness, not safety");
  the disclaimer is never decorated or animated.
- **Accessibility.** WCAG 2.2 AA, screen-reader-first, and the Two-Layer
  Reduced-Motion Rule (§5) are hard gates.
- **Security.** No telemetry, no network calls, no CDN runtime loads,
  self-hosted assets only, exact-pinned well-known dependencies.

## 1. Overview

### Creative North Star: "First Light," realized

The moment perception happens — sensing emerging from darkness. The 2026-07-19
build completes the earlier CSS-only "First Light" system with a real 3D
layer: the whole site now speaks one visual language, **"light through
structure"** — wireframe structures (the things) and traveling light (the
signal moving through them). A near-black field, one clear blue signal, and a
single warm glow wherever understanding arrives.

**Key characteristics:**

- Runtime theming: dark (default), light, and system, switchable at any time
  (§2). Every surface, scene, and shadow is tokenized per theme.
- One serif display voice (Fraunces) over a neutral grotesk body (Geist),
  with a mono annotation voice (Geist Mono) for technical labels.
- Five lazy-loaded three.js scenes sharing one engine and one palette (§6).
  The 3D layer is progressive enhancement in the strictest sense: under
  reduced motion, no WebGL2, save-data, or low memory, not one byte of it is
  downloaded, and the static page is the complete finished design.
- Motion is choreographed (GSAP + ScrollTrigger + Lenis) but never
  load-bearing: the no-JS/reduced-motion page is complete, not degraded.

## 2. Color and theming

Two palettes with identical key sets (an `@error` guard in `_tokens.scss`
enforces parity), emitted as CSS custom properties — dark under `:root`,
light under `[data-theme="light"]`. `color()`/`shadow()` in SCSS resolve to
`var(--…)`, so every component is themed by construction. A no-flash script
in `BaseLayout.astro` sets `data-theme` before first paint from
`localStorage("sb-theme")` (validated allowlist) or `prefers-color-scheme`;
the Header toggle cycles Light → Dark → System.

Dark (default): bg `#080a10` · bg-elevated `#0f131c` · surface `#161b28` ·
hairline `#2a3145` · text `#e8ebf2` (~17.9:1) · secondary `#a7afc2` (~8.6:1) ·
**Signal Blue** `#5eb1ff` (~8.1:1) · **Perception Glow** `#ffb37a`.

Light: bg `#f7f8fb` · bg-elevated `#ffffff` · surface `#eef1f7` · hairline
`#d4d9e4` · text `#101422` (~17.4:1) · secondary `#4d5468` (~7.5:1) · Signal
Blue `#145fc4` (~6.2:1) · Perception `#a8480d`.

The two accents keep their *jobs* as a convention (blue = the signal/meaning,
warm = arrival/understanding — in 3D, the traveling light literally turns
from blue to warm at the moment of arrival), but this is now vocabulary, not
a rule with a ban attached. Warm never carries text in either theme; it is
not held to the text-contrast floor.

Theme changes cross-fade via the `theme-transition` mixin (~400ms,
color/background/border only); the 3D scenes lerp their palettes over the
same ~400ms (`THEME_LERP_SECONDS` in `scenes/core.ts`).

## 3. Typography

Three self-hosted variable families (latin-subset woff2 in `public/fonts/`,
`font-display: swap`, all three preloaded):

- **Display — Fraunces Variable.** h1 (weight 350, optical sizing auto,
  `clamp(2.75rem, …, 6rem)`, 1.02, −0.02em, balanced), h2
  (`clamp(2rem, …, 3.25rem)`), h3 (`clamp(1.375rem, …, 1.75rem)`). A warm
  serif against cold wireframes is the identity pairing.
- **Body — Geist Variable.** Fluid body (`clamp(1rem, …, 1.0625rem)`, 1.6)
  and lede (`clamp(1.125rem, …, 1.375rem)`).
- **Annotation — Geist Mono Variable.** The `type-label` mixin (uppercase,
  tracked, 0.8125rem): technical annotations tied to the 3D hardware scenes
  (e.g. `01 · SENSING`). This is a deliberate, single-purpose voice — used
  only where the content genuinely is an ordered technical sequence, never
  as generic section eyebrows.

Body/lede line length stays capped near 65–70ch (`max-width` on ledes and
paragraph blocks).

## 4. Elevation & depth

- One-step surface lift (bg → surface) + 1px hairline for raised cards.
- Shadow tokens per theme: `glow-hero` (warm bloom), `glow-signal` (blue
  bloom), `card` (soft lift shadow, used by e.g. the Features hover lift).
- Real depth now comes primarily from the 3D layer: parallax point fields,
  camera dollies, and bloom (dark theme only) — not from stacked shadows.

## 5. Motion

Tokens in `_motion.scss`: durations 120/240/400/700/1200ms
(`fast/base/slow/reveal/cinema`); easings `ease-out-expo` (reveals),
`standard` (micro-interactions), `in-out` (ambient). Engine: GSAP +
ScrollTrigger + Lenis in `src/scripts/motion.ts`, idle-loaded after `load`
and only when reduced motion is off.

### Named rules (still absolute)

**The Two-Layer Reduced-Motion Rule.** Every CSS animation/transition lives
inside the `motion-safe` mixin (`@media (prefers-reduced-motion:
no-preference)`), with the no-query default being the final resting state;
every JS animation lives inside
`gsap.matchMedia("(prefers-reduced-motion: no-preference)")`. Under `reduce`
or no-JS the page is complete: nothing hidden, nothing half-animated, no 3D
bytes downloaded.

**The Undecorated Disclaimer Rule.** The safety-framing disclaimer callout
never animates, in any mode, and its files
(`Disclaimer.astro`/`Disclaimer.module.scss`) are untouchable without owner
approval.

### Vocabulary

Scroll-scrubbed construction (bridge builds, phone explodes, as you scroll);
one-shot ignitions (hero "first light" arc); traveling signals (blue point →
warm arrival pulse, the shared story beat across hero/bridge/glasses);
magnetic micro-pulls (CTA ±6px, nav links ≤3px — fine-pointer hover only);
section reveals (fade/rise staggers, each gated visible-by-default);
scroll-progress bar (2px Signal Blue under the header); Lenis smoothing.

## 6. The 3D layer

Five scenes, one engine (`src/scripts/scenes/`):

- **`quality-gate.ts`** — dependency-free `webglAllowed()`: reduced motion,
  `saveData`, `deviceMemory < 4`, or no WebGL2 → the loader never imports
  three.js at all.
- **`core.ts`** — shared engine: `mountScene()` (aria-hidden canvas,
  `pointer-events: none`, DPR ≤ 2, ResizeObserver, IntersectionObserver +
  `visibilitychange` rAF pausing, `scene-active` class on mount,
  context-loss → static art restored), `ThemeAdapter` (watches `data-theme`,
  ~400ms palette lerp), `createPointField` (custom-shader Points),
  `createPointerParallax` (0.04 amplitude, `(hover: hover) and
  (pointer: fine)` only).
- **`index.ts`** — the only eagerly-loaded module: gates via `webglAllowed()`,
  then lazily imports a scene per `[data-scene]` container on approach
  (IntersectionObserver, 200px rootMargin).
- **Scenes** — `hero` (4000-pt drifting field, wireframe icosahedron, warm
  core ignition + breathing), `ambient` (600-pt fixed page-depth field),
  `phone` (three wireframe plates — sensing/reasoning/rendering — exploded by
  scroll), `glasses` (wireframe frames, 5s blue→warm signal traveler along
  the frame path), `bridge` (wireframe suspension bridge constructing on
  scroll, traveler crossing on completion, lateral camera dolly).

Palette per theme (in `core.ts`): dark = additive/emissive + UnrealBloomPass
(0.8/0.4/0.85); light = ink line-art (`#145fc4`/`#a8480d`), bloom off,
emissive ~0.15, particle opacity halved. Camera fov 32.

**Static-fallback rule.** Every scene container holds finished static art
(SVG line-art or the hero's CSS/SVG composition) that *is* the design when 3D
doesn't run; `scene-active` fades it to 0.15 only after a live canvas mounts.
Every 3D stage is `aria-hidden="true"` with a visually-hidden prose narrative
alongside for screen-reader parity.

**Budget.** three.js lives in one lazy ~698KB chunk (+1–5KB per scene,
bloom 15KB) that the initial HTML never references; GSAP is a separate lazy
134KB chunk. First paint ships zero JS beyond two ~400B loaders.

## 7. Components

### Navigation

Sticky header: text logo, four plain links (Features / Privacy /
Accessibility / GitHub) with underline-draw hover and ≤3px magnetic pull,
theme toggle (44px, cycles Light→Dark→System, aria-label announces current +
next mode), 2px scroll-progress bar. Below 34rem the nav drops to its own
full-width second row (logo + toggle stay on row one) — the sticky header is
never more than two rows on mobile. Every anchored section carries
`scroll-margin-top: space("7")`.

### Hero

Fraunces h1 over a 3D "first light" scene (`data-scene="hero"`), static
layered CSS/SVG art as the resting design. Ghost CTA "Follow progress on
GitHub" (bordered, magnetic on fine pointers). Visually-hidden
narrated-illustration paragraph for screen-reader parity.

### Signal Bridge

The signature motif section (`#bridge`): copy states the real pipeline
(`SensingSource` → perception → Reasoning → `RenderTarget`); the visual is
the 3D suspension-bridge scene over the original SVG line-art fallback.
Click-to-replay easter egg (motion-enabled, pointer-only, no tab stop).

### Phone exploded view (`#device`)

Scrollytelling hardware showcase: sticky 3D stage (wireframe iPhone pulling
apart into sensing/reasoning/rendering plates, scroll-scrubbed) beside three
annotation blocks (`01 · SENSING` Camera + LiDAR, `02 · REASONING` Neural
Engine, `03 · RENDERING` Speaker + Taptic Engine) — mono label, Fraunces h3,
hedged body copy. ≥900px: two-column grid, stage pinned left
(`grid-row: 1 / span 3`), annotations in column 2, each a 70vh
vertically-centered beat. <900px: surface cards scrolling over the stage.
Reduced motion: static SVG exploded diagram, then the three blocks, nothing
pinned. The numbered labels are sanctioned: the pipeline genuinely is an
ordered sequence.

### Spatial future (`#future`)

Epilogue band (bg-elevated) after the pipeline: wireframe-glasses 3D scene
(SVG fallback) beside copy that is explicitly hedged — kicker "A future
direction — not a product," body all conditional ("could one day," "Nothing
about that future is promised"). This section's copy register is the model
for any future speculative content.

### Callout (disclaimer)

Surface background, 1px hairline, 8px radius, body-size text, exactly one
per page, never animated, verbatim doctrine text in
`<aside role="note" aria-label="Safety disclaimer">`. Untouchable.

### Skip link & focus

Skip link appears top-left on focus (Signal Blue fill, bg-elevated text —
5.7:1 in light mode). Global 2px `:focus-visible` outline, never suppressed.

## 8. Quality gates (blocking, machine-verified per change)

1. `npm run build && npm run typecheck && npm run lint:css && npm run
   lint:js && npm run format` — all exit 0.
2. `npm run test:a11y` (pa11y, WCAG2AA) — 0 errors. The site is multi-locale
   since 2026-07-20 (`/`, `/es/`, `/vi/` via Astro's built-in i18n routing —
   see `docs/superpowers/specs/2026-07-19-language-support-design.md`), but
   `website/.pa11yci.json` currently only lists `http://localhost:4321/` —
   this gate does not yet cover the `/es/`/`/vi/` routes (tracked in
   `TODO.md`).
3. Visual matrix when layout/theme/motion changes: 1440/768/390 × dark/light
   × motion/reduced-motion. Reduced motion must show the complete design,
   download zero three.js bytes, and mount zero canvases; no horizontal
   overflow at any width.
4. Safety-framing read of any new user-facing copy against the honesty bar
   (§0) before merge.

## 9. Do's and Don'ts

### Do

- **Do** keep blue = signal, warm = arrival as the shared story vocabulary
  across CSS, SVG, and 3D.
- **Do** keep every animation behind both reduced-motion layers with the
  resting state as the default, and every 3D stage behind `webglAllowed()`.
- **Do** ship finished static art as the base layer of every scene.
- **Do** keep the pre-launch status in plain visible copy; the only CTA is
  "follow progress."

### Don't

- **Don't** decorate or animate the disclaimer, ever.
- **Don't** add network calls, telemetry, CDN-loaded assets, or unpinned
  dependencies.
- **Don't** let any text ride on `accent-warm`, in either theme.
- **Don't** spread the mono label voice beyond genuine ordered technical
  sequences — it is an annotation voice, not a section-eyebrow system.
