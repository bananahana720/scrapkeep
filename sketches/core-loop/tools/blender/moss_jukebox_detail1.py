"""Detail layer 1 for Moss's bay jukebox: an additive enamel shell at the base's origin, authored from gap list A
(artifacts/local/alpha/push/w12/units/rc-moss_jukebox/gaps_A.md): band rivets, dome screw dots, speaker mesh, the
drawer knob, window and drawer frames, the cream arch liner, the keystone's arched cap, foot groove bands, kick-strip
bolts, wear flecks, a smooth oval bezel ring and the service hatch's thumb screws (the Switchback Enclaves habit).
Class "detail" (1500 tris, 3000 verts, 1 draw). Colours are TONES rows of moss_jukebox.py; no state key is painted.

  blender -b --threads 2 --python-exit-code 1 -P sketches/core-loop/tools/blender/moss_jukebox_detail1.py [-- --out-dir DIR]
"""
import math
from pathlib import Path
import sys

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
import moss_jukebox as j
from moss_jukebox import bead, bar, tone

DETAIL = [1500, 3000, 1]
SIZE = [1.82, 2.454, 1.22]
FLECKS = [(-.8, .52, -.455), (.79, 1.02, -.455), (-.55, 2.3, -.455), (.45, .3, -.505), (-.5, .55, -.505),
          (.3, .33, -.505), (-.83, 1.25, -.455), (.52, 2.2, -.455)]


def arc(s, cy, r0, r1, a0, a1, segs, z0, z1, color, sy=1.0):
    for i in range(segs):
        b0, b1 = a0 + (a1 - a0) * i / segs, a0 + (a1 - a0) * (i + 1) / segs
        p = [(r * math.sin(b), cy + r * sy * math.cos(b)) if sy != 1.0 else (r * math.cos(b), cy + r * math.sin(b))
             for r in (r0, r1) for b in (b0, b1)]
        v = [(x, y, z) for z in (z0, z1) for x, y in p]
        s.add(v, [(0, 1, 3, 2), (2, 3, 7, 6), (1, 0, 4, 5)], color)


def ellipse_ring(s, cy, inner, outer, n, z0, z1, color):
    for i in range(n):
        a0, a1 = math.tau * i / n, math.tau * (i + 1) / n
        p = [(hw * math.sin(a), cy - hh * math.cos(a)) for hw, hh in (inner, outer) for a in (a0, a1)]
        v = [(x, y, z) for z in (z0, z1) for x, y in p]
        s.add(v, [(0, 1, 3, 2), (2, 3, 7, 6), (1, 0, 4, 5)], color)


def frame(s, x0, x1, y0, y1, w, z0, z1, color):
    bar(s, (x0 - w, y0 - w / 2), (x1 + w, y0 - w / 2), w, z0, z1, color)
    bar(s, (x0 - w, y1 + w / 2), (x1 + w, y1 + w / 2), w, z0, z1, color)
    bar(s, (x0 - w / 2, y0), (x0 - w / 2, y1), w, z0, z1, color)
    bar(s, (x1 + w / 2, y0), (x1 + w / 2, y1), w, z0, z1, color)


def build(s):
    copper, dark, cream = tone("copper"), tone("speaker"), tone("arch")
    for y in j.BANDS:
        for x in (-.86, -.62, .62, .86):
            bead(s, (x, y, -.535), .022, .015, copper)
    cy, r, bulge = j.DOME
    z_rim = j.Z_FRONT - .005
    for f, deg in [(.75, 30), (.75, 60), (.75, 120), (.75, 150), (.45, 45), (.45, 135), (.85, 12), (.85, 168)]:
        a = math.radians(deg)
        z = z_rim - .8 * bulge * (1 - f) / .4 if f >= .6 else z_rim - .8 * bulge - .2 * bulge * (.6 - f) / .6
        bead(s, (f * r * math.cos(a), cy + f * r * math.sin(a), z - .003), .02, .012, dark)
    sx0, sx1, sy0, sy1 = j.SPEAKER
    mesh = tone("mesh")
    for k in (-1, 1):
        for t in (.25, .5, .75):
            x = k * (sx0 + (sx1 - sx0) * t)
            bar(s, (x, sy0 + .02), (x, sy1 - .02), .012, -.548, -.54, mesh, ends=False)
            y = sy0 + (sy1 - sy0) * t
            bar(s, (k * (sx0 + .02), y), (k * (sx1 - .02), y), .012, -.548, -.54, mesh, ends=False)
    hw, w0, w1 = j.WINDOW
    frame(s, -hw, hw, w0, w1, .025, -.56, -.54, copper)
    hw, d0, d1 = j.DRAWER
    frame(s, -hw, hw, d0, d1, .02, -.56, -.54, copper)
    bead(s, (0.0, (d0 + d1) / 2, -.55), .022, .02, copper)
    arc(s, j.ARCH_C, j.FRONT_R, j.FRONT_R + .025, 0.0, math.pi, 8, -.495, -.48, cream)
    arc(s, j.ARCH_C, .82, .87, math.radians(76), math.radians(104), 3, -.56, -.5, copper)
    cx, fhw, fhd, top = j.FOOT
    for k in (-1, 1):
        s.box((2 * fhw + .02, .035, 2 * fhd + .02), (k * cx, top - .07, 0.0), tone("groove"))
    for x in (-.42, -.2, .2, .42):
        bead(s, (x, (j.KICK[1] + j.KICK[2]) / 2, -.565), .02, .012, copper)
    rust = tone("keystone")
    for i, (x, y, z) in enumerate(FLECKS):
        w, h = (.035, .022) if i % 2 else (.026, .04)
        j.prism(s, [(x - w, y - h * .6), (x + w * .8, y - h), (x + w, y + h * .7), (x - w * .7, y + h)], z - .006, z + .004,
                rust, back=False)
    ocy, ohw, ohh, bez = j.OVAL
    ellipse_ring(s, ocy, (ohw - .02, ohh - .02), (ohw + bez, ohh + bez), 20, -.55, -.52, cream)
    for deg in (45, 135, 225, 315):
        a = math.radians(deg)
        bead(s, ((ohw + .015) * math.sin(a), ocy - (ohh + .015) * math.cos(a), -.555), .022, .02, copper)


def main():
    j.polish_on()
    j.export(j.NAME + "_detail1", "Detail1", "enamel", build, SIZE, {}, j.out_dir(), budget=DETAIL, tag="JUKEBOX_D1")


if __name__ == "__main__":
    main()
