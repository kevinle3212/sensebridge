# docs/assets

Images referenced by the Markdown documentation.

`kevin-le.jpg` is a deliberate second copy of
`website/public/images/team/kevin-le.jpg`, downscaled to 400px (~22 KB against
~200 KB). Keep both; do not replace either with a symlink.

Two independent reasons:

1. **Different publish roots.** `.github/workflows/pages.yml` builds Jekyll
   with `source: docs`, so a `../website/...` path 404s on the docs site, while
   Astro only serves what is under `website/public/`.
2. **A symlink would be silently dropped.** That workflow runs
   `actions/jekyll-build-pages`, which invokes `github-pages build`; the
   `github/pages-gem` `OVERRIDES` hash forces `safe => true` regardless of
   local config, and Jekyll documents `safe` as "ignore symbolic links." The
   image would vanish from the built docs site with no build error to catch it.

They are also not byte-identical by design — the docs copy is a downscale, so
collapsing them would ship a 200 KB file to render at 120px wide.

Everything outside `website/` — `README.md`, `MAINTAINERS.md`, `CREDITS.md`,
`docs/index.md` — points here; only the Astro site uses the copy under
`website/public/`. Replace both if the photo changes.
