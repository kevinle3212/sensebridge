"""Extract a "SenseBridge" wordmark from the self-hosted Fraunces variable font.

Fraunces ships as a woff2 variable font under `website/public/fonts/`. The
logo must not depend on that font being installed or loaded, so the glyphs are
instantiated at the display axis values used by the site and flattened to plain
SVG path data.

Writes `wordmark.json`: the path `d`, the advance width, and the vertical
extents, all in font units, for `build-svg.js` to place.
"""

import json
import pathlib

from fontTools.pens.boundsPen import BoundsPen
from fontTools.pens.svgPathPen import SVGPathPen
from fontTools.pens.transformPen import TransformPen
from fontTools.ttLib import TTFont
from fontTools.varLib.instancer import instantiateVariableFont

REPO = pathlib.Path(__file__).resolve().parents[2]
FONT = REPO / "website/public/fonts/fraunces-variable-latin.woff2"
OUT = pathlib.Path(__file__).resolve().parent / "wordmark.json"

WORD = "SenseBridge"

# Matches the site's display voice (DESIGN.md `typography.display`): Fraunces at
# weight 350. `opsz` is pinned to the display end of the optical-size axis
# because a logo is always set large, and WONK is off so the wordmark stays
# calm next to the geometric mark.
AXES = {"wght": 400, "opsz": 144, "SOFT": 0, "WONK": 0}


def main() -> None:
    font = TTFont(FONT)
    print("axes available:", {a.axisTag: (a.minValue, a.defaultValue, a.maxValue)
                              for a in font["fvar"].axes})

    pinned = {k: v for k, v in AXES.items()
              if k in {a.axisTag for a in font["fvar"].axes}}
    font = instantiateVariableFont(font, pinned, inplace=True, updateFontNames=False)

    upem = font["head"].unitsPerEm
    glyph_set = font.getGlyphSet()
    cmap = font.getBestCmap()
    hmtx = font["hmtx"]
    kern = _kern_table(font)

    pen_target = SVGPathPen(glyph_set, ntos=lambda v: f"{v:.2f}")
    # BoundsPen walks curve extrema, so these are true ink bounds rather than
    # the looser control-point box. The lockups align on ink, not on sidebearings.
    bounds_pen = BoundsPen(glyph_set)
    x = 0.0
    prev = None
    for char in WORD:
        name = cmap.get(ord(char))
        if name is None:
            raise SystemExit(f"glyph missing for {char!r}")
        if prev is not None:
            x += kern.get((prev, name), 0)
        # Flip the y axis: fonts are y-up, SVG is y-down.
        glyph_set[name].draw(TransformPen(pen_target, (1, 0, 0, -1, x, 0)))
        glyph_set[name].draw(TransformPen(bounds_pen, (1, 0, 0, -1, x, 0)))
        x += hmtx[name][0]
        prev = name

    path = pen_target.getCommands()
    if not path:
        raise SystemExit("empty wordmark path")
    if bounds_pen.bounds is None:
        raise SystemExit("wordmark has no ink bounds")
    x_min, y_min, x_max, y_max = bounds_pen.bounds

    ascent = font["hhea"].ascent
    descent = font["hhea"].descent
    cap = font["OS/2"].sCapHeight if hasattr(font["OS/2"], "sCapHeight") else ascent

    OUT.write_text(json.dumps({
        "word": WORD,
        "path": path,
        "advance": x,
        "unitsPerEm": upem,
        "ascent": ascent,
        "descent": descent,
        "capHeight": cap,
        "axes": pinned,
        "bounds": {"xMin": x_min, "yMin": y_min, "xMax": x_max, "yMax": y_max},
    }, indent=2))
    print(f"wrote {OUT.name}: advance={x:.0f} upem={upem} cap={cap} "
          f"path={len(path)} chars")
    print(f"ink bounds: x {x_min:.0f}..{x_max:.0f} (w {x_max - x_min:.0f})  "
          f"y {y_min:.0f}..{y_max:.0f} (h {y_max - y_min:.0f})")


def _kern_table(font: TTFont) -> dict:
    """Pull pair kerning out of GPOS lookup type 2, format 1 (pair-by-pair).

    Fraunces' kerning for this short a string lives in explicit pairs, so the
    class-based format-2 subtables are not needed here. Returns an empty dict
    when the font has no GPOS, which just means the wordmark sets unkerned.
    """
    pairs: dict = {}
    if "GPOS" not in font:
        return pairs
    for lookup in font["GPOS"].table.LookupList.Lookup:
        if lookup.LookupType != 2:
            continue
        for sub in lookup.SubTable:
            if getattr(sub, "Format", None) != 1:
                continue
            for first, pair_set in zip(sub.Coverage.glyphs, sub.PairSet):
                for record in pair_set.PairValueRecord:
                    value = getattr(record.Value1, "XAdvance", 0)
                    if value:
                        pairs[(first, record.SecondGlyph)] = value
    return pairs


if __name__ == "__main__":
    main()
