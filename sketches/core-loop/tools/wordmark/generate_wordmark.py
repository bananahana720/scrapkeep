#!/usr/bin/env python3
"""The Scrapkeep wordmark as SVG, drawn from its own letterforms (no font).

Dot Marrow's lettering is gig poster and record sleeve: thick ink, halftone, stamped
(SIGHT-PERSONA.md section 5). Each letter is one chamfered polygon on a 70 x 100 cell with
24-unit strokes; the ink outline is drawn under the fill so joins never show.

  python3 tools/wordmark/generate_wordmark.py --file assets/ui/wordmark.svg --look poster   (the game's wordmark)
  python3 tools/wordmark/generate_wordmark.py --out <dir>                                   (all three looks)
"""
import argparse
import math
import random
from pathlib import Path

INK = "#161b1a"
BONE = "#e6d9b8"
AMBER = "#e5a044"
COPPER = "#b77843"
RUST = "#9b513a"
OXIDE = "#5a3a2c"
STEEL = "#8d948f"
HAZARD = "#ff5a3c"

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


def path(polys, dx=0.0, dy=0.0, rot=0.0, skew=0.0, scale=1.0):
    cx, cy = 35.0, 50.0
    ca, sa = math.cos(math.radians(rot)), math.sin(math.radians(rot))
    k = math.tan(math.radians(skew))
    out = []
    for poly in polys:
        pts = []
        for x, y in poly:
            x, y = (x - cx) * scale, (y - cy) * scale
            x, y = x * ca - y * sa, x * sa + y * ca
            x -= k * (y + 50 * scale)
            pts.append("%.1f,%.1f" % (x + cx * scale + dx, y + cy * scale + dy))
        out.append("M" + " L".join(pts) + " Z")
    return " ".join(out)


def letters(look, seed=7):
    rng = random.Random(seed)
    rows = []
    for i, ch in enumerate(WORD):
        jitter = look == "poster" or look == "plate"
        rows.append({
            "d": LETTERS[ch],
            "x": i * ADVANCE,
            "y": rng.uniform(-5, 5) if jitter else 0.0,
            "rot": rng.uniform(-3.0, 3.0) if look == "poster" else (rng.uniform(-1.2, 1.2) if look == "plate" else 0.0),
            "skew": 12.0 if look == "splash" else 0.0,
        })
    return rows


def word_paths(rows, ox, oy, scale=1.0):
    return " ".join(path(r["d"], ox + r["x"] * scale, oy + r["y"] * scale, r["rot"], r["skew"], scale) for r in rows)


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
    # Thick ink, a hard ink drop, a halftone drop behind that, letters stamped a little off true.
    rows = letters("poster")
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
        # The poster's second ink pass: a bone cut along each letter's lit top-left edge.
        '<defs><clipPath id="face"><path d="%s" clip-rule="evenodd" fill-rule="evenodd"/></clipPath></defs>' % d,
        '<path d="%s" fill="none" stroke="%s" stroke-width="5" clip-path="url(#face)" transform="translate(4,4)" fill-rule="evenodd"/>' % (word_paths(rows, ox - 4, oy - 4, s), BONE),
    ]
    return W, H, parts


def plate():
    # Bone letters painted on an oxide plate the crew bolted up; rivets, a chipped edge.
    rows = letters("plate")
    W, H = 900, 260
    ox, oy, s = 85, 70, 0.92
    d = word_paths(rows, ox, oy, s)
    plate_pts = [(20, 28), (880, 18), (886, 232), (16, 240)]
    chips = "".join('<path d="M%d,%d l%d,%d l%d,%d Z" fill="%s"/>' % (x, y, a, b, c2, d2, BONE)
                    for x, y, a, b, c2, d2 in [(120, 26, 14, -2, -6, 7), (610, 21, 18, -1, -9, 6), (860, 150, 4, 16, -6, -4),
                                                (300, 237, 16, 0, -10, -5), (22, 90, 5, 14, -5, 2)])
    rivets = "".join('<circle cx="%d" cy="%d" r="9" fill="%s" stroke="%s" stroke-width="4"/><circle cx="%d" cy="%d" r="3" fill="%s"/>'
                     % (x, y, COPPER, INK, x - 2, y - 2, BONE) for x, y in [(48, 52), (852, 44), (856, 208), (46, 214), (450, 34), (452, 222)])
    parts = [
        '<path d="M%s Z" fill="%s" transform="translate(10,12)"/>' % (" L".join("%d,%d" % p for p in plate_pts), INK),
        '<path d="M%s Z" fill="%s" stroke="%s" stroke-width="10" stroke-linejoin="round"/>' % (" L".join("%d,%d" % p for p in plate_pts), OXIDE, INK),
        halftone(30, 120, 840, 115, 8, RUST, fade_from_bottom=True),
        chips,
        '<path d="%s" fill="%s" stroke="%s" stroke-width="12" stroke-linejoin="round" fill-rule="evenodd"/>' % (word_paths(rows, ox + 5, oy + 6, s), INK, INK),
        '<path d="%s" fill="%s" fill-rule="evenodd"/>' % (d, BONE),
        rivets,
    ]
    return W, H, parts


def splash():
    # A comic splash: leaning letters, a hard two-tone fill, a burst behind in hazard red.
    rows = letters("splash")
    W, H = 920, 300
    ox, oy, s = 70, 90, 1.0
    d = word_paths(rows, ox, oy, s)
    rng = random.Random(11)
    burst = []
    cx, cy = 460, 150
    n = 28
    for i in range(n * 2):
        a = math.tau * i / (n * 2)
        r = (150 if i % 2 == 0 else 105) * rng.uniform(0.9, 1.1)
        burst.append("%.1f,%.1f" % (cx + math.cos(a) * r * 2.3, cy + math.sin(a) * r * 0.9))
    clip_lower = '<clipPath id="lower"><rect x="0" y="%d" width="%d" height="%d"/></clipPath>' % (oy + 52, W, H)
    lines = "".join('<path d="M%d,%d L%d,%d" stroke="%s" stroke-width="%d"/>' % (x, 20 + (x % 7) * 3, x - 60, 280 - (x % 5) * 6, BONE, 3 + x % 3)
                    for x in range(40, 900, 37))
    parts = [
        '<defs>%s</defs>' % clip_lower,
        '<g opacity="0.35">%s</g>' % lines,
        '<path d="M%s Z" fill="%s" stroke="%s" stroke-width="10" stroke-linejoin="miter"/>' % (" L".join(burst), HAZARD, INK),
        '<path d="%s" fill="%s" stroke="%s" stroke-width="16" stroke-linejoin="round"/>' % (word_paths(rows, ox + 10, oy + 10, s), INK, INK),
        '<path d="%s" fill="%s" stroke="%s" stroke-width="16" stroke-linejoin="round" fill-rule="evenodd"/>' % (d, INK, INK),
        '<path d="%s" fill="%s" fill-rule="evenodd"/>' % (d, AMBER),
        '<path d="%s" fill="%s" fill-rule="evenodd" clip-path="url(#lower)"/>' % (d, COPPER),
    ]
    return W, H, parts


LOOKS = {"poster": poster, "plate": plate, "splash": splash}


def svg(look):
    w, h, parts = LOOKS[look]()
    return '<svg xmlns="http://www.w3.org/2000/svg" width="%d" height="%d" viewBox="0 0 %d %d">%s</svg>\n' % (w, h, w, h, "".join(parts))


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--out")
    ap.add_argument("--file")
    ap.add_argument("--look", choices=sorted(LOOKS), action="append")
    args = ap.parse_args()
    if args.file:
        Path(args.file).write_text(svg((args.look or ["poster"])[0]))
        print("wrote", args.file)
        return
    out = Path(args.out)
    out.mkdir(parents=True, exist_ok=True)
    for look in args.look or sorted(LOOKS):
        (out / ("wordmark_%s.svg" % look)).write_text(svg(look))
        print("wrote", out / ("wordmark_%s.svg" % look))


if __name__ == "__main__":
    main()
