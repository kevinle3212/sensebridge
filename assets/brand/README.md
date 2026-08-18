# SenseBridge brand assets — "First Light"

The tracked home for the mark. Everything here is either a master or the script
that turns masters into the rasters the app and the website ship.

## What is tracked, and what is not

| Path | Tracked | Why |
| --- | --- | --- |
| `svg/` | Yes | The masters. Every raster is derived from one of these. |
| `wordmark.json` | Yes | Outlined glyph data for the wordmark, so rebuilding does not need the font installed. |
| `build-*.js`, `build-wordmark.py` | Yes | The generators. |
| PNG/ICO/JPEG output | No | Derived. Only the handful the app and site actually load are committed, in their consuming directory — see below. |

Rasters are regenerated, not archived: keeping 200 PNGs in git would add
megabytes per refresh for files any contributor can rebuild in seconds.

## Where the shipped rasters live

Committed next to whatever loads them, not here — a build step should never
have to reach across the repo for an icon:

- `app/SenseBridge/Resources/Assets.xcassets/AppIcon.appiconset/` — the iOS app icon.
- `website/public/` — `favicon.svg`, `favicon.ico`, `apple-touch-icon.png`,
  `icon-192.png`, `icon-512.png`, and `site.webmanifest`.

## Rebuilding

`sharp` and `puppeteer` come from `website/node_modules`, resolved relative to
this directory — install the site's dependencies first. Neither is duplicated at
the repo root: both are large native packages, and these scripts run a few times
a year.

```sh
npm --prefix website install
node assets/brand/build-svg.js      # wordmark.json -> svg/
node assets/brand/build-raster.js   # svg/ -> png/, ico/, jpeg/, appicon/
node assets/brand/build-sheet.js    # a contact sheet for review
node assets/brand/build-preview.js  # applied mockups (needs puppeteer)
```

`build-raster.js` and the two below it write into this directory. That output is
gitignored; copy only what a consumer needs into the paths listed above.

## Typeface

The wordmark is set in **Fraunces** (SIL OFL 1.1), already vendored under
`website/public/fonts/` with its licence. `wordmark.json` holds outlines rather
than live text, so nothing here depends on the font being installed locally.
