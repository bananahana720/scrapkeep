"""Detail layer 1 for the trebuchet launcher (wave 12-D RECIPE-WAVE, the DETAIL-CART loop): an additive steel shell at the
frame's origin, authored from gap list A (units/rc-trebuchet_launcher/gaps_A.md) against trebuchet_launcher_202.png. Rivet
rows on the girders and the top beam (A1, A2), oxide foot plates (A3), gear and flywheel teeth (A4, A5), the sphere's
cradle ring (A7), plinth feet (A8), the guy cables' turnbuckles and anchor plates (A12, the Highdraft habit), base-beam
bolts (A13) and the piston collar (A14). Colours from trebuchet_launcher.TONES only. Frame only: the arm moves, so nothing
here sits on it. Class "detail" (1500 tris, 3000 verts, 1 draw). No game code loads it yet; its row in
assets/registry.d/trebuchet_launcher.json records the draw distance it is meant to get.
  blender -b --threads 2 --python-exit-code 1 -P sketches/core-loop/tools/blender/trebuchet_launcher_detail1.py [-- --out-dir DIR]
"""
import math
from pathlib import Path
import sys

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
import trebuchet_launcher as tl
from trebuchet_launcher import Frame, frustum, ring, box, torus, tone, along_x, along_z, FZ, GROUND

DETAIL = [1500, 3000, 1]
NAME = "trebuchet_launcher_detail1"
SIZE = [12.0, 13.065, 4.82]


def rivet(s, at, normal=(0.0, 0.0, 1.0), r=.11, h=.07, color=None):
    f = Frame(s, at, normal, (1.0, 0.0, 0.0) if abs(normal[0]) < .9 else (0.0, 0.0, 1.0))
    frustum(f, r, r * .55, -.03, h, 4, color or tone("copper"), caps=(False, True))


def girder_rivets(s):
    px, top, w = tl.POST
    (fx, fy), (hx, hy) = tl.OUTER
    for sx in (-1.0, 1.0):
        for k in range(9):
            y = GROUND + .9 + k * 1.35
            rivet(s, (sx * px, y, FZ + w / 2))
            t = (y - fy) / (hy - fy)
            rivet(s, (sx * (fx + (hx - fx) * t), y + .5, FZ + w * .85 / 2))
    hl, b0, b1, hd = tl.BEAM
    for k in range(11):
        rivet(s, (-hl + .45 + k * (2 * hl - .9) / 10, (b0 + b1) / 2, FZ + hd), r=.12)


def build(s):
    girder_rivets(s)
    for x in (tl.OUTER[0][0], tl.POST[0]):
        for sx in (-1.0, 1.0):
            box(s, (sx * x - .6, GROUND, FZ - .62), (sx * x + .6, GROUND + .14, FZ + .62), tone("beam"))
    g0, g1, gy0, gy1, teeth = tl.GEAR
    ring(s, [(g0 - .03, gy0 + .03), (g1, gy0 + .03), (g1, gy1 - .03), (g0 - .03, gy1 - .03)], 24, tone("iron"), at=(0.0, FZ),
         radius=lambda r, i: r if r < g0 else (g1 if i % 2 == 0 else g0 - .03))
    f = along_x(s, (tl.FLY[0], tl.PIVOT[1], FZ))
    fr, fh = tl.FLY[1], tl.FLY[2] * .7
    ring(f, [(fr - .04, -fh), (fr + .17, -fh), (fr + .17, fh), (fr - .04, fh)], 32, tone("copper"),
         radius=lambda r, i: r if r < fr else (fr + .17 if i % 2 == 0 else fr - .04))
    pr = tl.PLATE[0]
    ring(s, [(pr - .1, tl.PLATE[2] - .02), (pr, tl.PLATE[2] - .02), (1.45, .5), (1.3, .5), (pr - .25, tl.PLATE[2] - .02)], 12,
         tone("iron"), at=(0.0, FZ))
    ring(s, [(tl.PISTON[0] - .02, tl.GEAR[3] - .02), (.5, tl.GEAR[3] - .02), (.5, tl.GEAR[3] + .3), (tl.PISTON[0] - .02, tl.GEAR[3] + .3)],
         8, tone("copper"), at=(0.0, FZ))
    hx, hz, (p0, _) = tl.PLINTH
    for sx in (-1.0, 1.0):
        for sz in (-1.0, 1.0):
            box(s, (sx * (hx - .25) - .18, GROUND, FZ + sz * (hz - .25) - .18), (sx * (hx - .25) + .18, p0 + .02, FZ + sz * (hz - .25) + .18), tone("iron"))
    for a, b in tl.CABLES:
        d = tuple(a[k] - b[k] for k in range(3))
        n = math.sqrt(sum(c * c for c in d))
        at = tuple(b[k] + d[k] / n * 1.6 for k in range(3))
        t = Frame(s, at, d, (1.0, 0.0, 0.0))
        ring(t, [(.02, -.32), (.13, -.32), (.16, 0.0), (.13, .32), (.02, .32)], 6, tone("copper"))
        box(s, (b[0] - .3, b[1] - .02, b[2] - .3), (b[0] + .3, b[1] + .08, b[2] + .3), tone("iron"))
    bl, _, y1, bd = tl.BASE
    for x in (-4.6, -3.9, -2.7, 2.7, 3.9, 4.6):
        rivet(s, (x, y1, FZ + bd * .55), (0.0, 1.0, 0.0), r=.12, h=.1, color=tone("iron"))


def main():
    tl.polish_on()
    tl.export(NAME, [("Detail1", "steel", False, build)], {}, tl.out_dir(), budget=DETAIL, tag="TREBUCHET_D1", size=SIZE)


if __name__ == "__main__":
    main()
