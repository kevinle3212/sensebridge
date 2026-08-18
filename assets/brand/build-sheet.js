#!/usr/bin/env node
/**
 * Build the reviewer-facing contact sheet: every variant on one page, plus
 * in-situ mockups (browser tab, navbar, GitHub avatar, iOS home screen) so the
 * marks are judged at the size they actually ship at.
 */

const fs = require("fs");
const path = require("path");

const ROOT = __dirname;
const manifest = JSON.parse(fs.readFileSync(path.join(ROOT, "manifest.json"), "utf8"));

const FONTS = "../../website/public/fonts";

/**
 * Colourways that sit on a light field rather than a dark one.
 *
 * `current` is here because an SVG loaded through `<img>` is an isolated
 * document: `currentColor` resolves to that document's own initial colour
 * (black), not the host page's. Showing it on light is the honest preview —
 * it only inherits the site's colour once inlined.
 */
const ON_LIGHT = new Set(["full-color-light", "mono-dark", "black", "current"]);

const tile = (label, src, { pad = 20, h = 120 } = {}) => `
      <figure class="tile ${ON_LIGHT.has(labelKey(label)) ? "on-light" : "on-dark"}">
        <div class="art" style="--pad:${pad}px;--h:${h}px"><img src="${src}" alt="${label}" loading="lazy"></div>
        <figcaption>${label}</figcaption>
      </figure>`;

function labelKey(label) {
  for (const k of ["full-color-light", "mono-dark", "black", "full-color", "mono-light", "white", "current"]) {
    if (label.includes(k)) return k;
  }
  return "full-color";
}

const section = (id, title, blurb, inner) => `
  <section id="${id}">
    <header class="sec">
      <h2>${title}</h2>
      <p>${blurb}</p>
    </header>
    ${inner}
  </section>`;

const grid = (items) => `<div class="grid">${items.join("")}</div>`;

const COLORWAYS = Object.entries(manifest.colorways);

// ── Sections ────────────────────────────────────────────────────────────────

const iconOnly = grid(
  COLORWAYS.map(([k, v]) =>
    tile(`mark-${k}`, k === "current" ? `svg/mark-${k}.svg` : `png/mark-${k}-512.png`, { h: 130 }),
  ),
);

const badges = grid(
  COLORWAYS.filter(([k]) => k !== "current").flatMap(([k]) => [
    tile(`badge-${k}`, `png/badge-${k}-512.png`, { pad: 0, h: 130 }),
    tile(`circle-${k}`, `png/circle-${k}-512.png`, { pad: 0, h: 130 }),
  ]),
);

const horizontal = grid(
  COLORWAYS.map(([k]) =>
    tile(`horizontal-${k}`, k === "current" ? `svg/horizontal-${k}.svg` : `png/horizontal-${k}-1600w.png`, { h: 70 }),
  ),
);

const stacked = grid(
  COLORWAYS.map(([k]) =>
    tile(`stacked-${k}`, k === "current" ? `svg/stacked-${k}.svg` : `png/stacked-${k}-992w.png`, { h: 150 }),
  ),
);

const faviconStrip = `
    <div class="panel dark">
      <div class="row favicons">
        ${[16, 24, 32, 48, 64, 128].map((s) => `
          <div class="fav"><img src="png/favicon-${s}.png" width="${s}" height="${s}" alt="favicon ${s}"><span>${s}px</span></div>`).join("")}
      </div>
      <p class="note">16px drops the bridge chord and 24–32px thicken it — same silhouette, legible weight at each size. 48px and up carry the full mark.</p>
    </div>
    <div class="panel light">
      <div class="row favicons">
        ${[16, 32, 48].map((s) => `
          <div class="fav"><img src="png/favicon-light-${s}.png" width="${s}" height="${s}" alt="favicon light ${s}"><span>${s}px</span></div>`).join("")}
      </div>
      <p class="note">Light-scheme cuts. <code>svg/favicon-adaptive.svg</code> switches between the two on its own via <code>prefers-color-scheme</code>.</p>
    </div>`;

const browserTab = `
    <div class="browser" id="mock-browser-tab">
      <div class="chrome-bar">
        <div class="dots"><i></i><i></i><i></i></div>
        <div class="tabs">
          <div class="tab active"><img src="png/favicon-16.png" width="16" height="16" alt=""><span>SenseBridge — on-device accessibility</span><b>×</b></div>
          <div class="tab"><img src="png/favicon-16.png" width="16" height="16" alt=""><span>Docs</span><b>×</b></div>
          <div class="tab dim"><span class="ph"></span><span>Another site</span><b>×</b></div>
        </div>
      </div>
      <div class="url-bar"><span class="lock">🔒</span><span>sensebridge.vercel.app</span></div>
    </div>`;

const navbarMock = `
    <div class="navbar-mock dark" id="mock-navbar-dark">
      <img class="brand" src="png/navbar-dark-32@3x.png" alt="SenseBridge" height="32">
      <nav><a>Product</a><a>Docs</a><a>Roadmap</a><a class="cta">GitHub</a></nav>
    </div>
    <div class="navbar-mock light" id="mock-navbar-light">
      <img class="brand" src="png/navbar-light-32@3x.png" alt="SenseBridge" height="32">
      <nav><a>Product</a><a>Docs</a><a>Roadmap</a><a class="cta">GitHub</a></nav>
    </div>
    <p class="note">Rendered at 24 / 28 / 32 / 40px nav heights, each at @1x/@2x/@3x — see <code>png/navbar-*</code>.</p>`;

// The avatar's own field is near-black, so on a near-black page the circular
// crop edge is invisible and the mark can't be judged. These sit on GitHub's
// real surface colours with a hairline ring, which is what makes the crop legible.
const avatarMock = `
    <div class="avatars gh-dark" id="mock-avatar">
      <div class="av-item"><img class="circle" src="png/github-avatar-460.png" style="width:280px;height:280px" alt=""><span>280px — profile</span></div>
      <div class="av-item"><img class="circle" src="png/github-avatar-460.png" style="width:80px;height:80px" alt=""><span>80px — org card</span></div>
      <div class="av-item"><img class="circle" src="png/github-avatar-460.png" style="width:40px;height:40px" alt=""><span>40px — comment</span></div>
      <div class="av-item"><img class="circle" src="png/github-avatar-460.png" style="width:20px;height:20px" alt=""><span>20px — inline</span></div>
    </div>
    <div class="avatars gh-light" id="mock-avatar-light">
      <div class="av-item"><img class="circle" src="png/github-avatar-460.png" style="width:140px;height:140px" alt=""><span>on GitHub light</span></div>
      <div class="av-item"><img class="circle" src="png/github-avatar-460.png" style="width:40px;height:40px" alt=""><span>40px</span></div>
      <div class="av-item"><img class="circle" src="png/github-avatar-460.png" style="width:20px;height:20px" alt=""><span>20px</span></div>
    </div>
    <p class="note">Measured: the mark reaches 66.5% of the crop radius, so nothing clips at any size. The soft perception glow is what appears to fill the circle.</p>
    <div class="gh-comment">
      <img class="circle" src="png/github-avatar-460.png" width="40" height="40" alt="">
      <div class="bubble"><b>sensebridge</b> commented 2 minutes ago<p>Circular crop is what GitHub actually renders — the square master keeps the mark inside the inscribed circle so nothing clips.</p></div>
    </div>`;

const appIconMock = `
    <div class="ios" id="mock-appicon">
      <div class="ios-grid">
        ${[["AppIcon-180", "SenseBridge"], ["AppIcon-180", "Settings"], ["AppIcon-180", "Camera"]].map((a, i) => `
          <div class="ios-app ${i > 0 ? "ghost" : ""}">
            <div class="squircle"><img src="appicon/${a[0]}.png" alt=""></div>
            <span>${i === 0 ? a[1] : ""}</span>
          </div>`).join("")}
      </div>
      <p class="note">Masked to iOS's squircle. Source art is full-bleed and fully opaque — App Store artwork rejects alpha.</p>
    </div>`;

const html = `<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<title>SenseBridge — logo system</title>
<link rel="icon" href="svg/favicon-adaptive.svg" type="image/svg+xml">
<style>
  @font-face { font-family:"Fraunces"; src:url("${FONTS}/fraunces-variable-latin.woff2") format("woff2"); font-weight:100 900; font-display:swap }
  @font-face { font-family:"Geist"; src:url("${FONTS}/geist-variable-latin.woff2") format("woff2"); font-weight:100 900; font-display:swap }
  @font-face { font-family:"Geist Mono"; src:url("${FONTS}/geist-mono-variable-latin.woff2") format("woff2"); font-weight:100 900; font-display:swap }

  :root {
    --ink:#080a10; --ink-el:#0f131c; --surface:#161b28; --fog:#e8ebf2;
    --steel:#a7afc2; --signal:#5eb1ff; --glow:#ffb37a; --hairline:#2a3145;
    --light-bg:#f7f8fb; --light-ink:#101422; --light-hairline:#d4d9e4;
  }
  * { box-sizing:border-box }
  body { margin:0; background:var(--ink); color:var(--fog);
         font-family:"Geist",-apple-system,sans-serif; line-height:1.6; }
  .wrap { max-width:1180px; margin:0 auto; padding:64px 24px 128px }

  h1 { font-family:"Fraunces",serif; font-weight:350; letter-spacing:-.02em;
       font-size:clamp(2.5rem,1.3rem+5vw,4.5rem); line-height:1.02; margin:0 0 12px }
  h2 { font-family:"Fraunces",serif; font-weight:500; font-size:1.6rem; margin:0 0 6px; letter-spacing:-.01em }
  .lede { color:var(--steel); font-size:1.15rem; max-width:62ch; margin:0 0 8px }
  code { font-family:"Geist Mono",monospace; font-size:.85em; color:var(--signal);
         background:rgba(94,177,255,.08); padding:.15em .4em; border-radius:5px }
  .note { color:var(--steel); font-size:.9rem; margin:14px 0 0 }
  .panel.light .note { color:#4d5468 }

  section { margin-top:72px; border-top:1px solid var(--hairline); padding-top:32px }
  .sec p { color:var(--steel); margin:0; max-width:70ch }

  .grid { display:grid; grid-template-columns:repeat(auto-fit,minmax(230px,1fr));
          gap:16px; margin-top:24px }
  .tile { margin:0; border:1px solid var(--hairline); border-radius:12px; overflow:hidden;
          background:var(--ink-el) }
  .tile .art { display:grid; place-items:center; padding:var(--pad); height:var(--h) }
  .tile.on-light .art { background:var(--light-bg) }
  .tile.on-dark  .art { background:var(--ink) }
  /* The art box is a grid whose row is content-sized, so a percentage height on
     the image resolves to auto and the marks spilled over the caption. Deriving
     the height from the same custom properties the box uses is exact, and both
     --h and --pad inherit down to the image. */
  .tile .art img { width:100%; height:calc(var(--h) - 2 * var(--pad));
                   object-fit:contain; display:block }
  figcaption { font-family:"Geist Mono",monospace; font-size:.72rem; color:var(--steel);
               padding:9px 12px; border-top:1px solid var(--hairline); letter-spacing:.02em }

  .panel { border:1px solid var(--hairline); border-radius:14px; padding:28px; margin-top:20px }
  .panel.dark { background:var(--ink-el) }
  .panel.light { background:var(--light-bg); color:var(--light-ink); border-color:var(--light-hairline) }
  .row { display:flex; align-items:flex-end; gap:32px; flex-wrap:wrap }
  .fav { display:flex; flex-direction:column; align-items:center; gap:10px }
  .fav span { font-family:"Geist Mono",monospace; font-size:.7rem; color:var(--steel) }
  .panel.light .fav span { color:#4d5468 }
  .fav img { image-rendering:auto }

  /* Browser tab mock */
  .browser { border:1px solid var(--hairline); border-radius:12px 12px 8px 8px; overflow:hidden;
             background:#1c1f26; margin-top:24px; max-width:760px }
  .chrome-bar { display:flex; align-items:flex-end; gap:12px; padding:10px 12px 0; background:#15171d }
  .dots { display:flex; gap:7px; padding:0 6px 12px }
  .dots i { width:11px; height:11px; border-radius:50%; background:#3a3f4b }
  .dots i:first-child { background:#ff5f57 } .dots i:nth-child(2){ background:#febc2e }
  .dots i:nth-child(3){ background:#28c840 }
  .tabs { display:flex; gap:2px; flex:1 }
  .tab { display:flex; align-items:center; gap:8px; padding:9px 12px; border-radius:9px 9px 0 0;
         font-size:.78rem; color:#8b93a5; max-width:250px; background:#1c1f26 }
  .tab.active { background:#262a33; color:var(--fog) }
  .tab span { overflow:hidden; text-overflow:ellipsis; white-space:nowrap }
  .tab b { opacity:.5; font-weight:400 }
  .tab .ph { width:16px; height:16px; border-radius:4px; background:#3a3f4b; flex:none }
  .url-bar { display:flex; align-items:center; gap:9px; padding:11px 18px; background:#262a33;
             font-size:.82rem; color:#b9c0cf }

  /* Navbar mock */
  .navbar-mock { display:flex; align-items:center; justify-content:space-between;
                 padding:16px 26px; border-radius:12px; margin-top:18px; border:1px solid var(--hairline) }
  .navbar-mock.dark { background:var(--ink-el) }
  .navbar-mock.light { background:var(--light-bg); border-color:var(--light-hairline) }
  .navbar-mock .brand { height:32px; width:auto }
  .navbar-mock nav { display:flex; gap:26px; align-items:center; font-size:.92rem }
  .navbar-mock.dark nav a { color:var(--steel) }
  .navbar-mock.light nav a { color:#4d5468 }
  .navbar-mock nav a.cta { color:var(--ink); background:var(--signal); padding:7px 16px; border-radius:9px }
  .navbar-mock.light nav a.cta { background:#145fc4; color:#fff }

  /* Avatar mock */
  .avatars { display:flex; align-items:flex-end; gap:40px; flex-wrap:wrap; margin-top:24px;
             padding:30px; border-radius:14px }
  .avatars.gh-dark  { background:#0d1117; border:1px solid #30363d }
  .avatars.gh-light { background:#ffffff; border:1px solid #d1d9e0 }
  .av-item { display:flex; flex-direction:column; align-items:center; gap:12px }
  .av-item span { font-family:"Geist Mono",monospace; font-size:.7rem; color:var(--steel) }
  .gh-light .av-item span { color:#59636e }
  /* GitHub draws a hairline ring on avatars; without it the near-black field
     bleeds into a dark page and the crop boundary can't be seen. */
  .circle { border-radius:50%; display:block; box-shadow:0 0 0 1px rgba(255,255,255,.14) }
  .gh-light .circle { box-shadow:0 0 0 1px rgba(0,0,0,.16) }
  .gh-comment { display:flex; gap:14px; margin-top:32px; padding:18px; border:1px solid var(--hairline);
                border-radius:12px; background:var(--ink-el); max-width:640px }
  .gh-comment .bubble { font-size:.9rem; color:var(--steel) }
  .gh-comment b { color:var(--fog) } .gh-comment p { margin:8px 0 0 }

  /* iOS mock */
  .ios { margin-top:24px; padding:34px; border-radius:20px;
         background:linear-gradient(160deg,#243b55,#141e30); max-width:560px }
  .ios-grid { display:flex; gap:34px }
  .ios-app { display:flex; flex-direction:column; align-items:center; gap:9px }
  .ios-app.ghost { opacity:.18 }
  .squircle { width:82px; height:82px; overflow:hidden;
              border-radius:23px;
              -webkit-mask-image:radial-gradient(#000,#000); box-shadow:0 8px 22px rgba(0,0,0,.4) }
  .squircle img { width:100%; height:100%; display:block }
  .ios-app span { font-size:.78rem; color:#fff; text-shadow:0 1px 3px rgba(0,0,0,.6) }
  .ios .note { color:rgba(255,255,255,.62) }

  .files { font-family:"Geist Mono",monospace; font-size:.78rem; color:var(--steel);
           columns:2; column-gap:36px; margin-top:20px }
  .files div { break-inside:avoid; padding:2px 0 }
  .files b { color:var(--fog); font-weight:500 }
</style>
</head>
<body>
<div class="wrap">
  <h1>SenseBridge logo system</h1>
  <p class="lede">The <em>&ldquo;First Light&rdquo;</em> mark: a sensing ring broken at the lower right, a warm chord bridging that break, and a core at the point of first light. Derived from the palette and display face already in <code>.agents/context/DESIGN.md</code>.</p>
  <p class="lede">Ring = the sensing horizon. The break = the gap between the sensed world and understanding. The warm chord = the bridge across it. That is the product name, drawn.</p>

  ${section("icon", "Icon only", "The bare mark on a transparent field. <code>mark-current</code> paints in <code>currentColor</code> and inherits the surrounding CSS colour &mdash; but only when inlined; through an <code>&lt;img&gt;</code> tag, as previewed here, it falls back to black.", iconOnly)}
  ${section("badge", "Contained", "Rounded-square badge and circular lockup, for surfaces that need their own field.", badges)}
  ${section("horizontal", "Horizontal lockup", "Mark and wordmark aligned on cap-height centre, not on the ink box — descenders never drag the mark off-axis.", horizontal)}
  ${section("stacked", "Stacked lockup", "Mark scaled up 1.6× so it anchors the full wordmark width.", stacked)}
  ${section("favicon", "Favicon &amp; browser tab", "Three density cuts across the size range, plus a self-switching adaptive SVG.", faviconStrip + browserTab)}
  ${section("navbar", "Navbar", "The horizontal lockup in situ, dark and light.", navbarMock)}
  ${section("avatar", "GitHub avatar", "GitHub crops avatars to a circle. Rendered here at the four sizes it actually uses.", avatarMock)}
  ${section("appicon", "App icon", "iOS and macOS artwork, full-bleed and opaque.", appIconMock)}

  ${section("files", "What is on disk", "Every master is SVG; everything else is rasterized from it, so the system regenerates from three scripts.", `
    <div class="files">
      <div><b>svg/</b> — ${manifest.svg.length} masters (source of truth)</div>
      <div><b>png/</b> — marks, lockups, favicons, navbar, avatar</div>
      <div><b>jpeg/</b> — flattened lockups + badges</div>
      <div><b>ico/favicon.ico</b> — 16/24/32/48/256</div>
      <div><b>appicon/</b> — iOS + macOS sets and <code>Contents.json</code></div>
      <div><b>preview/</b> — rendered mockup screenshots</div>
      <div><b>build-wordmark.py</b> — Fraunces &rarr; vector paths</div>
      <div><b>build-svg.js</b> — geometry, colourways, lockups</div>
      <div><b>build-raster.js</b> — PNG / JPEG / ICO / app icon</div>
      <div><b>build-sheet.js</b> — this page</div>
    </div>`)}
</div>
</body>
</html>
`;

fs.writeFileSync(path.join(ROOT, "index.html"), html);
console.log("wrote index.html");
