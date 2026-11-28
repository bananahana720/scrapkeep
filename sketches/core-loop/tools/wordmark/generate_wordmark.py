#!/usr/bin/env python3
"""The Scrapkeep wordmark as SVG, drawn from its own letterforms (no font).

Dot Marrow's lettering is gig poster and record sleeve: thick ink, halftone, stamped
(SIGHT-PERSONA.md section 5). Each letter is one chamfered polygon on a 70 x 100 cell with
24-unit strokes; the ink outline is drawn under the fill so joins never show.

  python3 tools/wordmark/generate_wordmark.py --file assets/ui/wordmark.svg

The poster look is the one Andrew picked on 13 November 2026 (W1-47 taste page); the crew-plate and
comic-splash candidates are in git history at fb30e3f9.
"""
import argparse
import math
import random
from pathlib import Path

INK = "#161b1a"
BONE = "#e6d9b8"
AMBER = "#e5a044"
RUST = "#9b513a"

T = 24
C = 12
LETTERS = {
    "S": [[(C, 0), (70, 0), (70, T), (T, T), (T, 38), (70 - C, 38), (70, 38 + C), (70, 100 - C), (70 - C, 100),
           (0, 100), (0, 100 - T), (70 - T, 100 - T), (70 - T, 62), (C, 62), (0, 62 - C), (0, C)]],
    "C": [[(C, 0), (70, 0), (70, T), (T, T), (T, 100 - T), (70, 100 - T), (70, 100), (C, 100), (0, 100 - C), (0, C)]],
    "R": [[(0, 0), (58, 0), (70, 12), (70, 50), (60, 60), (74, 100), (49, 100), (38, 64), (T, 64), (T, 100), (0, 100)],
          [(T, T), (46, T), (46, 42), (T, 42)]],
    "A": [[(0, 100), (0, 20), (20, 0), (50, 0), (70, 20), (70, 100), (46, 100), (46, 70), (T, 70), (T, 100)],
          [(T, 26), (46, 26), (46, 48), (T, 48)]],
    "P": [[(0, 0), (58, 0), (70, 12), (70, 52), (58, 64), (T, 64), (T, 100), (0, 100)],
          [(T, T), (46, T), (46, 42), (T, 42)]],
    "K": [[(0, 0), (T, 0), (T, 38), (46, 0), (74, 0), (40, 50), (74, 100), (46, 100), (T, 62), (T, 100), (0, 100)]],
    "E": [[(C, 0), (70, 0), (70, T), (T, T), (T, 38), (60, 38), (60, 62), (T, 62), (T, 100 - T), (70, 100 - T),
           (70, 100), (C, 100), (0, 100 - C), (0, C)]],
}
WORD = "SCRAPKEEP"
GAP = 10
ADVANCE = 70 + GAP


def path(polys, dx=0.0, dy=0.0, rot=0.0, scale=1.0):
    cx, cy = 35.0, 50.0
    ca, sa = math.cos(math.radians(rot)), math.sin(math.radians(rot))
    out = []
    for poly in polys:
        pts = []
        for x, y in poly:
            x, y = (x - cx) * scale, (y - cy) * scale
            x, y = x * ca - y * sa, x * sa + y * ca
            pts.append("%.1f,%.1f" % (x + cx * scale + dx, y + cy * scale + dy))
        out.append("M" + " L".join(pts) + " Z")
    return " ".join(out)


def letters(seed=7):
    rng = random.Random(seed)
    rows = []
    for i, ch in enumerate(WORD):
        rows.append({"d": LETTERS[ch], "x": i * ADVANCE, "y": rng.uniform(-5, 5), "rot": rng.uniform(-3.0, 3.0)})
    return rows


def word_paths(rows, ox, oy, scale=1.0):
    return " ".join(path(r["d"], ox + r["x"] * scale, oy + r["y"] * scale, r["rot"], scale) for r in rows)


def halftone(x0, y0, w, h, step, color, fade_from_bottom=True, rng=None):
    dots = []
    y = y0
    row = 0
    while y < y0 + h:
        x = x0 + (step * 0.5 if row % 2 else 0.0)
        while x < x0 + w:
            t = (y - y0) / h if fade_from_bottom else 1.0 - (y - y0) / h
            r = step * 0.48 * t
            if r > 0.6:
                dots.append('<circle cx="%.1f" cy="%.1f" r="%.1f"/>' % (x, y, r))
            x += step
        y += step * 0.866
        row += 1
    return '<g fill="%s">%s</g>' % (color, "".join(dots))


def poster():
    rows = letters()
    W, H = 900, 240
    ox, oy, s = 40, 50, 1.0
    d = word_paths(rows, ox, oy, s)
    far = word_paths(rows, ox + 26, oy + 24, s)
    parts = [
        '<defs><clipPath id="far"><path d="%s" fill-rule="nonzero"/></clipPath></defs>' % far,
        '<path d="%s" fill="none" stroke="%s" stroke-width="16" stroke-linejoin="round" clip-path="url(#far)"/>' % (far, RUST),
        '<g clip-path="url(#far)">%s</g>' % halftone(0, 0, W, H, 7, RUST, fade_from_bottom=True),
        '<path d="%s" fill="%s" stroke="%s" stroke-width="16" stroke-linejoin="round"/>' % (word_paths(rows, ox + 11, oy + 11, s), INK, INK),
        '<path d="%s" fill="%s" stroke="%s" stroke-width="16" stroke-linejoin="round" fill-rule="evenodd"/>' % (d, INK, INK),
        '<path d="%s" fill="%s" fill-rule="evenodd"/>' % (d, AMBER),
        '<defs><clipPath id="face"><path d="%s" clip-rule="evenodd" fill-rule="evenodd"/></clipPath></defs>' % d,
        '<path d="%s" fill="none" stroke="%s" stroke-width="5" clip-path="url(#face)" transform="translate(4,4)" fill-rule="evenodd"/>' % (word_paths(rows, ox - 4, oy - 4, s), BONE),
    ]
    return W, H, parts


def svg():
    w, h, parts = poster()
    return '<svg xmlns="http://www.w3.org/2000/svg" width="%d" height="%d" viewBox="0 0 %d %d">%s</svg>\n' % (w, h, w, h, "".join(parts))


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--file", required=True)
    args = ap.parse_args()
    Path(args.file).write_text(svg())
    print("wrote", args.file)


if __name__ == "__main__":
    main()
