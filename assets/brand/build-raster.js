#!/usr/bin/env node
/**
 * Rasterize the SVG masters into every delivery format.
 *
 * `sharp` lives in the main checkout's `website/node_modules` — this script is
 * throwaway tooling under `tmp/`, so it borrows that install rather than adding
 * a dependency to the project.
 */

const fs = require("fs");
const path = require("path");

// Resolved relative to this file rather than the repo's absolute path on one
// machine. `sharp` and `puppeteer` are dev dependencies of `website/`, and
// duplicating either at the repo root just to shorten this line would add a
// second copy of a large native binary for a script that runs a few times a
// year.
const REPO_ROOT = path.resolve(__dirname, "..", "..");
const sharp = require(path.join(REPO_ROOT, "website", "node_modules", "sharp"));

const ROOT = __dirname;
const SVG = path.join(ROOT, "svg");
const PNG = path.join(ROOT, "png");
const JPEG = path.join(ROOT, "jpeg");
const ICO = path.join(ROOT, "ico");
const APPICON = path.join(ROOT, "appicon");

for (const d of [PNG, JPEG, ICO, APPICON]) fs.mkdirSync(d, { recursive: true });

const INK = { r: 8, g: 10, b: 16 };
const LIGHT_BG = { r: 247, g: 248, b: 251 };

const report = [];

/** Intrinsic viewBox size, used to pick a render density that avoids upscaling. */
function viewBox(name) {
  const svg = fs.readFileSync(path.join(SVG, `${name}.svg`), "utf8");
  const m = svg.match(/viewBox="([\d.\s-]+)"/);
  const [, , w, h] = m[1].trim().split(/\s+/).map(Number);
  return { w, h };
}

/**
 * Render an SVG master at an exact pixel width.
 *
 * sharp treats SVG user units as CSS px at 96dpi, so the density is derived
 * from the target rather than fixed: a constant density silently upscales a
 * 64-unit mark once the target passes ~800px, which softens every edge.
 */
function render(name, width) {
  const vb = viewBox(name);
  const density = Math.min(50000, Math.ceil((96 * width) / vb.w) + 8);
  const buf = fs.readFileSync(path.join(SVG, `${name}.svg`));
  return sharp(buf, { density }).resize({ width, fit: "contain" });
}

async function png(name, width, outName, dir = PNG) {
  const file = path.join(dir, `${outName}.png`);
  await render(name, width).png({ compressionLevel: 9 }).toFile(file);
  report.push(file);
  return file;
}

/** JPEG has no alpha, so every JPEG is flattened onto its colourway's background. */
async function jpeg(name, width, outName, bg) {
  const file = path.join(JPEG, `${outName}.jpg`);
  await render(name, width).flatten({ background: bg }).jpeg({ quality: 92, chromaSubsampling: "4:4:4" }).toFile(file);
  report.push(file);
  return file;
}

/**
 * Pack PNGs into a Windows .ico.
 *
 * PNG-compressed ICO entries are understood by every browser still shipping,
 * and keep the file a fraction of the size of BMP entries. A size byte of 0
 * encodes 256 per the format.
 */
function packIco(pngBuffers) {
  const count = pngBuffers.length;
  const header = Buffer.alloc(6);
  header.writeUInt16LE(0, 0); // reserved
  header.writeUInt16LE(1, 2); // type: icon
  header.writeUInt16LE(count, 4);

  const entries = Buffer.alloc(16 * count);
  let offset = 6 + 16 * count;
  pngBuffers.forEach(({ size, buf }, i) => {
    const e = i * 16;
    entries.writeUInt8(size >= 256 ? 0 : size, e + 0);
    entries.writeUInt8(size >= 256 ? 0 : size, e + 1);
    entries.writeUInt8(0, e + 2); // palette size
    entries.writeUInt8(0, e + 3); // reserved
    entries.writeUInt16LE(1, e + 4); // colour planes
    entries.writeUInt16LE(32, e + 6); // bits per pixel
    entries.writeUInt32LE(buf.length, e + 8);
    entries.writeUInt32LE(offset, e + 12);
    offset += buf.length;
  });

  return Buffer.concat([header, entries, ...pngBuffers.map((p) => p.buf)]);
}

async function main() {
  // ── Icon-only marks, transparent ──────────────────────────────────────────
  const MARK_SIZES = [16, 24, 32, 48, 64, 128, 256, 512, 1024];
  const MARK_COLORWAYS = [
    "full-color", "full-color-light", "mono-light", "mono-dark", "black", "white",
  ];
  for (const cw of MARK_COLORWAYS) {
    for (const s of MARK_SIZES) await png(`mark-${cw}`, s, `mark-${cw}-${s}`);
  }

  // ── Badged / circular icons ───────────────────────────────────────────────
  for (const cw of ["full-color", "full-color-light", "mono-light", "mono-dark", "black", "white"]) {
    for (const s of [64, 128, 256, 512, 1024]) {
      await png(`badge-${cw}`, s, `badge-${cw}-${s}`);
      await png(`circle-${cw}`, s, `circle-${cw}-${s}`);
    }
  }

  // ── Lockups ───────────────────────────────────────────────────────────────
  const LOCKUP_WIDTHS = [400, 800, 1600, 2400];
  for (const cw of MARK_COLORWAYS) {
    for (const w of LOCKUP_WIDTHS) {
      await png(`horizontal-${cw}`, w, `horizontal-${cw}-${w}w`);
      await png(`stacked-${cw}`, Math.round(w * 0.62), `stacked-${cw}-${Math.round(w * 0.62)}w`);
    }
  }

  // ── JPEG (flattened; only the backed variants make sense) ─────────────────
  for (const [cw, bg] of [
    ["full-color", INK],
    ["full-color-light", LIGHT_BG],
    ["mono-light", INK],
    ["mono-dark", LIGHT_BG],
    ["black", { r: 255, g: 255, b: 255 }],
    ["white", { r: 0, g: 0, b: 0 }],
  ]) {
    for (const w of [800, 1600, 2400]) {
      await jpeg(`horizontal-${cw}-on-bg`, w, `horizontal-${cw}-${w}w`, bg);
      await jpeg(`stacked-${cw}-on-bg`, Math.round(w * 0.62), `stacked-${cw}-${Math.round(w * 0.62)}w`, bg);
    }
    for (const s of [512, 1024]) {
      await jpeg(`badge-${cw}`, s, `badge-${cw}-${s}`, bg);
    }
  }

  // ── Favicons ──────────────────────────────────────────────────────────────
  // Density steps down with pixel size: the full mark at 16px turns the chord
  // into a smudge, so 16px uses the chordless "micro" cut and 24–32px the
  // thickened "compact" cut. Same silhouette, legible weight at each size.
  const faviconMaster = (size) =>
    size <= 16 ? "badge-micro-full-color"
      : size <= 32 ? "badge-compact-full-color"
        : "badge-full-color";

  const icoParts = [];
  for (const s of [16, 24, 32, 48, 64, 128, 256]) {
    const f = await png(faviconMaster(s), s, `favicon-${s}`);
    if ([16, 24, 32, 48, 256].includes(s)) icoParts.push({ size: s, buf: fs.readFileSync(f) });
  }
  const icoFile = path.join(ICO, "favicon.ico");
  fs.writeFileSync(icoFile, packIco(icoParts));
  report.push(icoFile);

  // Light-theme favicon PNGs, for anyone wiring per-scheme <link> tags.
  for (const s of [16, 32, 48]) {
    const master = s <= 16 ? "badge-micro-full-color-light"
      : s <= 32 ? "badge-compact-full-color-light" : "badge-full-color-light";
    await png(master, s, `favicon-light-${s}`);
  }

  // ── Web app / touch icons ─────────────────────────────────────────────────
  await png("badge-full-color", 180, "apple-touch-icon-180");
  await png("badge-full-color", 192, "icon-192");
  await png("badge-full-color", 512, "icon-512");
  // Maskable icons are cropped to a circle inscribed in the middle 80%, so the
  // full-bleed square master is used — a rounded badge would show clipped corners.
  await png("appicon-master", 512, "icon-maskable-512");
  await png("appicon-master", 1024, "icon-maskable-1024");

  // ── iOS / macOS app icon ──────────────────────────────────────────────────
  // App Store artwork must be fully opaque with no alpha channel, so the square
  // master is used and alpha is stripped explicitly.
  const IOS_SIZES = [20, 29, 40, 58, 60, 76, 80, 87, 120, 152, 167, 180, 1024];
  for (const s of IOS_SIZES) {
    const file = path.join(APPICON, `AppIcon-${s}.png`);
    await render("appicon-master", s).flatten({ background: INK }).removeAlpha()
      .png({ compressionLevel: 9 }).toFile(file);
    report.push(file);
  }
  const MAC_SIZES = [16, 32, 64, 128, 256, 512, 1024];
  for (const s of MAC_SIZES) {
    const file = path.join(APPICON, `mac-AppIcon-${s}.png`);
    await render("appicon-master", s).flatten({ background: INK }).removeAlpha()
      .png({ compressionLevel: 9 }).toFile(file);
    report.push(file);
  }

  // Modern Xcode takes a single 1024 source and derives the rest.
  const contents = {
    images: [{ filename: "AppIcon-1024.png", idiom: "universal", platform: "ios", size: "1024x1024" }],
    info: { author: "xcode", version: 1 },
  };
  const cFile = path.join(APPICON, "Contents.json");
  fs.writeFileSync(cFile, JSON.stringify(contents, null, 2) + "\n");
  report.push(cFile);

  // ── GitHub avatar ─────────────────────────────────────────────────────────
  // GitHub renders avatars in a circle, so the master carries a square field and
  // keeps the mark well inside the inscribed circle.
  for (const s of [460, 1024]) {
    await png("avatar-master", s, `github-avatar-${s}`);
    await png("avatar-circle-master", s, `github-avatar-circle-${s}`);
    await png("avatar-master-light", s, `github-avatar-light-${s}`);
    await jpeg("avatar-master", s, `github-avatar-${s}`, INK);
    await jpeg("avatar-master-light", s, `github-avatar-light-${s}`, LIGHT_BG);
  }

  // ── Navbar lockups at real render heights ─────────────────────────────────
  const vbH = viewBox("horizontal-full-color");
  for (const h of [24, 28, 32, 40]) {
    for (const dpr of [1, 2, 3]) {
      const w = Math.round((vbH.w / vbH.h) * h * dpr);
      const suffix = dpr === 1 ? "" : `@${dpr}x`;
      await png("horizontal-full-color", w, `navbar-dark-${h}${suffix}`);
      await png("horizontal-full-color-light", w, `navbar-light-${h}${suffix}`);
    }
  }

  console.log(`wrote ${report.length} raster files`);
  fs.writeFileSync(path.join(ROOT, "raster-manifest.json"),
    JSON.stringify(report.map((f) => path.relative(ROOT, f)), null, 2));
}

main().catch((e) => { console.error(e); process.exit(1); });
