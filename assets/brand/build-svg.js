#!/usr/bin/env node
/**
 * Generate the SenseBridge "First Light" logo system as SVG masters.
 *
 * Everything downstream (PNG, JPEG, ICO, app icon, previews) is rasterized
 * from these files, so this is the single source of truth for geometry and
 * colour. Palette and type come from `.agents/context/DESIGN.md`.
 */

const fs = require("fs");
const path = require("path");

const OUT = path.join(__dirname, "svg");
const WORDMARK = JSON.parse(
  fs.readFileSync(path.join(__dirname, "wordmark.json"), "utf8"),
);

/** Brand palette, copied from the `DESIGN.md` front-matter colour tokens. */
const C = {
  ink: "#080a10",
  inkElevated: "#0f131c",
  fogWhite: "#e8ebf2",
  signalBlue: "#5eb1ff",
  perceptionGlow: "#ffb37a",
  lightBg: "#f7f8fb",
  lightInk: "#101422",
  lightSignalBlue: "#145fc4",
  lightPerception: "#a8480d",
};

// ── Mark geometry ────────────────────────────────────────────────────────────
// A 64×64 grid centred on (32,32). The ring is the sensing horizon, broken by
// a gap at the lower right; the warm chord bridges that break; the core is the
// point of first light. Ring and chord share a stroke width so the mark reads
// as one continuous instrument.

const CENTER = 32;
const RING_RADIUS = 19;
const GAP_CENTER_DEG = 45; // lower-right in SVG coordinates (y grows downward)
const GAP_HALF_DEG = 32;

const rad = (deg) => (deg * Math.PI) / 180;
const onRing = (deg) => [
  CENTER + RING_RADIUS * Math.cos(rad(deg)),
  CENTER + RING_RADIUS * Math.sin(rad(deg)),
];

const n = (v) => Number(v.toFixed(3));

/**
 * Build the ring arc and the bridging chord for a given stroke weight.
 * The chord is inset from the ring's endpoints so the round caps do not
 * collide and muddy the gap at small sizes.
 */
function markGeometry(stroke) {
  const startDeg = GAP_CENTER_DEG + GAP_HALF_DEG;
  const endDeg = GAP_CENTER_DEG - GAP_HALF_DEG;
  const [sx, sy] = onRing(startDeg);
  const [ex, ey] = onRing(endDeg);

  // Sweep the long way round (296°) so the gap is the short arc.
  const ring = `M ${n(sx)} ${n(sy)} A ${RING_RADIUS} ${RING_RADIUS} 0 1 1 ${n(ex)} ${n(ey)}`;

  const dx = ex - sx;
  const dy = ey - sy;
  const len = Math.hypot(dx, dy);
  const inset = stroke * 0.72;
  const ux = dx / len;
  const uy = dy / len;
  const chord =
    `M ${n(sx + ux * inset)} ${n(sy + uy * inset)} ` +
    `L ${n(ex - ux * inset)} ${n(ey - uy * inset)}`;

  return { ring, chord };
}

/** Visual extent of the mark: the ring's outer edge, not the 64-unit canvas. */
const markExtent = (stroke) => (RING_RADIUS + stroke / 2) * 2;

/**
 * Render the mark's three elements.
 *
 * `density` trades detail for legibility: "regular" is the full mark, "compact"
 * thickens every stroke for 20–24px use, and "micro" drops the chord entirely
 * because below ~20px a 1px diagonal turns to mush. Dropping it keeps the
 * ring-and-core silhouette the brand already ships in `website/public/favicon.svg`.
 */
function mark({ density = "regular", ring, chord, core, chordOpacity = 1, indent = "  " }) {
  const stroke = { regular: 4.5, compact: 6, micro: 7 }[density];
  const coreRadius = { regular: 6.5, compact: 7.5, micro: 8.5 }[density];
  const g = markGeometry(stroke);
  const i = indent;

  const parts = [
    `${i}<path d="${g.ring}" fill="none" stroke="${ring}" stroke-width="${stroke}" stroke-linecap="round"/>`,
  ];
  if (density !== "micro") {
    const op = chordOpacity === 1 ? "" : ` opacity="${chordOpacity}"`;
    parts.push(
      `${i}<path d="${g.chord}" fill="none" stroke="${chord}" stroke-width="${stroke}" stroke-linecap="round"${op}/>`,
    );
  }
  parts.push(`${i}<circle cx="${CENTER}" cy="${CENTER}" r="${coreRadius}" fill="${core}"/>`);
  return parts.join("\n");
}

// ── Wordmark placement ───────────────────────────────────────────────────────
// Fraunces outlines arrive in font units with the baseline at y=0 and y already
// flipped for SVG. Scale so the cap height is a fixed fraction of the mark, then
// align on cap-height centre — never on the full ink box, which descenders
// would drag off-centre.

// Fraunces at this weight has heavy stems, so a cap height much above ~1.9× the
// mark's stroke rhythm lets the wordmark overpower the mark in the horizontal
// lockup. 22 units against a 42.5-unit mark is where the two read as equals.
const CAP_UNITS = 22;

// In the stacked lockup the wordmark spans the full width, so a mark drawn at
// its horizontal-lockup size looks stranded above it. Scaling the mark up keeps
// the block anchored without changing the mark's internal proportions.
const STACK_MARK_SCALE = 1.6;
const WM_SCALE = CAP_UNITS / WORDMARK.capHeight;
const WM_INK_W = (WORDMARK.bounds.xMax - WORDMARK.bounds.xMin) * WM_SCALE;
const WM_ASCENT = -WORDMARK.bounds.yMin * WM_SCALE; // ink above baseline
const WM_DESCENT = WORDMARK.bounds.yMax * WM_SCALE; // ink below baseline

/** Place the wordmark path with its ink-left edge at `x` and baseline at `y`. */
function wordmark(x, y, fill, indent = "  ") {
  const tx = x - WORDMARK.bounds.xMin * WM_SCALE;
  return (
    `${indent}<path transform="translate(${n(tx)} ${n(y)}) scale(${n(WM_SCALE)})" ` +
    `d="${WORDMARK.path}" fill="${fill}"/>`
  );
}

// ── Colourways ───────────────────────────────────────────────────────────────
// `chordOpacity` below 1 is how the single-hue variants keep the ring/chord
// hierarchy that colour carries in the full-colour marks. The pure black and
// white variants deliberately keep it at 1: they must survive 1-bit output
// (engraving, fax, stencil, a thresholded print) where opacity is not available.

const COLORWAYS = {
  "full-color": {
    ring: C.signalBlue, chord: C.perceptionGlow, core: C.signalBlue,
    text: C.fogWhite, bg: C.ink, chordOpacity: 1,
    note: "Primary. Dark surfaces.",
  },
  "full-color-light": {
    ring: C.lightSignalBlue, chord: C.lightPerception, core: C.lightSignalBlue,
    text: C.lightInk, bg: C.lightBg, chordOpacity: 1,
    note: "Primary. Light surfaces.",
  },
  "mono-light": {
    ring: C.fogWhite, chord: C.fogWhite, core: C.fogWhite,
    text: C.fogWhite, bg: C.ink, chordOpacity: 0.55,
    note: "Single-hue, dark surfaces.",
  },
  "mono-dark": {
    ring: C.lightInk, chord: C.lightInk, core: C.lightInk,
    text: C.lightInk, bg: C.lightBg, chordOpacity: 0.55,
    note: "Single-hue, light surfaces.",
  },
  black: {
    ring: "#000000", chord: "#000000", core: "#000000",
    text: "#000000", bg: "#ffffff", chordOpacity: 1,
    note: "1-bit. No opacity, survives thresholding.",
  },
  white: {
    ring: "#ffffff", chord: "#ffffff", core: "#ffffff",
    text: "#ffffff", bg: "#000000", chordOpacity: 1,
    note: "1-bit reversed.",
  },
  current: {
    ring: "currentColor", chord: "currentColor", core: "currentColor",
    text: "currentColor", bg: "transparent", chordOpacity: 0.55,
    note: "Inherits CSS colour. For inline SVG in the site.",
  },
};

// ── Builders ─────────────────────────────────────────────────────────────────

const header = (viewBox, title, extra = "") =>
  `<svg xmlns="http://www.w3.org/2000/svg" viewBox="${viewBox}"${extra} role="img" aria-label="${title}">\n` +
  `  <title>${title}</title>\n`;

/**
 * Icon-only mark.
 * `container` is the shape drawn behind it: none, a rounded square (the badge
 * the site's favicon already uses), a circle, or a full-bleed square for iOS.
 */
function buildIcon(key, cw, { container = "none", density = "regular", glow = false, markScale = 1 } = {}) {
  const title = `SenseBridge mark`;
  let body = "";

  if (container === "badge") {
    body += `  <rect width="64" height="64" rx="14" fill="${cw.bg}"/>\n`;
  } else if (container === "circle") {
    body += `  <circle cx="32" cy="32" r="32" fill="${cw.bg}"/>\n`;
  } else if (container === "square") {
    body += `  <rect width="64" height="64" fill="${cw.bg}"/>\n`;
  }

  let defs = "";
  if (glow) {
    // The "perception glow" from DESIGN.md, used only at large sizes where a
    // soft falloff survives rasterization.
    defs =
      `  <defs>\n` +
      `    <radialGradient id="glow" cx="50%" cy="50%" r="50%">\n` +
      `      <stop offset="0%" stop-color="${cw.chord}" stop-opacity="0.38"/>\n` +
      `      <stop offset="100%" stop-color="${cw.chord}" stop-opacity="0"/>\n` +
      `    </radialGradient>\n` +
      `  </defs>\n`;
  }

  // Scale the mark about the canvas centre. Used by the avatar masters, where
  // the default 66%-of-radius mark leaves too much dead space inside GitHub's
  // circular crop; the glow scales with it so the two stay locked together.
  const scaled = markScale !== 1;
  const open = scaled
    ? `  <g transform="translate(32 32) scale(${markScale}) translate(-32 -32)">\n`
    : "";
  const close = scaled ? `\n  </g>` : "";
  const i = scaled ? "    " : "  ";

  let inner = "";
  if (glow) inner += `${i}<circle cx="32" cy="32" r="22" fill="url(#glow)"/>\n`;
  inner += mark({ density, ring: cw.ring, chord: cw.chord, core: cw.core, chordOpacity: cw.chordOpacity, indent: i });

  body += open + inner + close;
  return header("0 0 64 64", title) + defs + body + "\n</svg>\n";
}

/** Mark and wordmark side by side, aligned on the mark's optical centre. */
function buildHorizontal(key, cw, { withBg = false } = {}) {
  const stroke = 4.5;
  const D = markExtent(stroke); // 42.5
  const GAP = 15;
  const markInset = (64 - D) / 2; // trim the mark's canvas padding
  const wmX = D + GAP;
  const wmBaseline = D / 2 + CAP_UNITS / 2;
  const W = wmX + WM_INK_W;
  const H = D;

  let body = "";
  if (withBg) body += `  <rect x="0" y="0" width="${n(W)}" height="${n(H)}" fill="${cw.bg}"/>\n`;
  body += `  <g transform="translate(${n(-markInset)} ${n(-markInset)})">\n`;
  body += mark({ ring: cw.ring, chord: cw.chord, core: cw.core, chordOpacity: cw.chordOpacity, indent: "    " });
  body += `\n  </g>\n`;
  body += wordmark(wmX, wmBaseline, cw.text) + "\n";

  return header(`0 0 ${n(W)} ${n(H)}`, "SenseBridge") + body + "</svg>\n";
}

/** Mark centred above the wordmark. */
function buildStacked(key, cw, { withBg = false } = {}) {
  const stroke = 4.5;
  const D = markExtent(stroke) * STACK_MARK_SCALE;
  const GAP = 16;
  const markInset = (64 - markExtent(stroke)) / 2;
  const W = Math.max(WM_INK_W, D);
  const wmCapTop = D + GAP;
  const wmBaseline = wmCapTop + CAP_UNITS;
  const H = wmBaseline + WM_DESCENT;
  const markX = (W - D) / 2;

  let body = "";
  if (withBg) body += `  <rect x="0" y="0" width="${n(W)}" height="${n(H)}" fill="${cw.bg}"/>\n`;
  body += `  <g transform="translate(${n(markX)} 0) scale(${STACK_MARK_SCALE}) translate(${n(-markInset)} ${n(-markInset)})">\n`;
  body += mark({ ring: cw.ring, chord: cw.chord, core: cw.core, chordOpacity: cw.chordOpacity, indent: "    " });
  body += `\n  </g>\n`;
  body += wordmark(0, wmBaseline, cw.text) + "\n";

  return header(`0 0 ${n(W)} ${n(H)}`, "SenseBridge") + body + "</svg>\n";
}

/**
 * Theme-adaptive favicon: one file that follows the browser's colour scheme,
 * matching the site's runtime theming. Rasterizers ignore the media query and
 * fall through to the dark default, which is why the PNG favicons are built
 * from the explicit colourways instead of this file.
 */
function buildAdaptiveFavicon() {
  const g = markGeometry(6);
  return (
    `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 64 64" role="img" aria-label="SenseBridge">\n` +
    `  <title>SenseBridge</title>\n` +
    `  <style>\n` +
    `    .bg { fill: ${C.ink}; }\n` +
    `    .ring, .core { stroke: ${C.signalBlue}; fill: ${C.signalBlue}; }\n` +
    `    .chord { stroke: ${C.perceptionGlow}; }\n` +
    `    @media (prefers-color-scheme: light) {\n` +
    `      .bg { fill: ${C.lightBg}; }\n` +
    `      .ring, .core { stroke: ${C.lightSignalBlue}; fill: ${C.lightSignalBlue}; }\n` +
    `      .chord { stroke: ${C.lightPerception}; }\n` +
    `    }\n` +
    `  </style>\n` +
    `  <rect class="bg" width="64" height="64" rx="14"/>\n` +
    `  <path class="ring" d="${g.ring}" fill="none" stroke-width="6" stroke-linecap="round"/>\n` +
    `  <path class="chord" d="${g.chord}" fill="none" stroke-width="6" stroke-linecap="round"/>\n` +
    `  <circle class="core" cx="32" cy="32" r="7.5" stroke="none"/>\n` +
    `</svg>\n`
  );
}

// ── Emit ─────────────────────────────────────────────────────────────────────

fs.mkdirSync(OUT, { recursive: true });
const written = [];
const write = (name, svg) => {
  fs.writeFileSync(path.join(OUT, name), svg);
  written.push(name);
};

for (const [key, cw] of Object.entries(COLORWAYS)) {
  write(`mark-${key}.svg`, buildIcon(key, cw));
  write(`horizontal-${key}.svg`, buildHorizontal(key, cw));
  write(`stacked-${key}.svg`, buildStacked(key, cw));

  // Contained forms only make sense where a background colour exists.
  if (cw.bg !== "transparent") {
    write(`badge-${key}.svg`, buildIcon(key, cw, { container: "badge" }));
    write(`circle-${key}.svg`, buildIcon(key, cw, { container: "circle" }));
    write(`horizontal-${key}-on-bg.svg`, buildHorizontal(key, cw, { withBg: true }));
    write(`stacked-${key}-on-bg.svg`, buildStacked(key, cw, { withBg: true }));
  }
}

// Small-size and application-specific masters.
write("favicon-adaptive.svg", buildAdaptiveFavicon());
write("mark-compact-full-color.svg", buildIcon("c", COLORWAYS["full-color"], { density: "compact" }));
write("mark-micro-full-color.svg", buildIcon("m", COLORWAYS["full-color"], { density: "micro" }));
write("badge-compact-full-color.svg", buildIcon("c", COLORWAYS["full-color"], { container: "badge", density: "compact" }));
write("badge-micro-full-color.svg", buildIcon("m", COLORWAYS["full-color"], { container: "badge", density: "micro" }));
write("badge-compact-full-color-light.svg", buildIcon("c", COLORWAYS["full-color-light"], { container: "badge", density: "compact" }));
write("badge-micro-full-color-light.svg", buildIcon("m", COLORWAYS["full-color-light"], { container: "badge", density: "micro" }));
write("appicon-master.svg", buildIcon("app", COLORWAYS["full-color"], { container: "square", glow: true }));
// GitHub crops to a circle, so the avatar carries a larger mark than the app
// icon does: 1.24× puts the ring at ~82% of the crop radius instead of 66%,
// which is what keeps it readable at the 20px inline size.
const AVATAR_MARK_SCALE = 1.24;
write("avatar-master.svg", buildIcon("av", COLORWAYS["full-color"], { container: "badge", glow: true, markScale: AVATAR_MARK_SCALE }));
write("avatar-circle-master.svg", buildIcon("av", COLORWAYS["full-color"], { container: "circle", glow: true, markScale: AVATAR_MARK_SCALE }));
write("avatar-master-light.svg", buildIcon("av", COLORWAYS["full-color-light"], { container: "badge", glow: true, markScale: AVATAR_MARK_SCALE }));

fs.writeFileSync(
  path.join(__dirname, "manifest.json"),
  JSON.stringify(
    {
      colorways: Object.fromEntries(
        Object.entries(COLORWAYS).map(([k, v]) => [k, { note: v.note, bg: v.bg }]),
      ),
      metrics: {
        markExtent: markExtent(4.5),
        capUnits: CAP_UNITS,
        wordmarkInkWidth: WM_INK_W,
        wordmarkAscent: WM_ASCENT,
        wordmarkDescent: WM_DESCENT,
      },
      svg: written,
    },
    null,
    2,
  ),
);

console.log(`wrote ${written.length} SVG masters to ${path.relative(process.cwd(), OUT)}`);
console.log(`mark extent ${n(markExtent(4.5))}u · wordmark ink ${n(WM_INK_W)}u @ cap ${CAP_UNITS}u`);
