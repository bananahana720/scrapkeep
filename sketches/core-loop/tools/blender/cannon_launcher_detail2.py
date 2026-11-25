"""Detail layer 2 for the cannon launcher (wave 12-D RECIPE-WAVE, the DETAIL-CART loop's moving baseline): an additive steel
shell at the body's origin, authored from gap list C (units/rc-cannon_launcher/gaps_C.md), the pass-1 render re-imagined by
FLUX.1 schnell image-to-image (strength 0.55, 6 steps, seed 101). Patch bolts, gauge pivot and quarter ticks, barrel and
boiler rivet rows, the hub plate, pipe nuts, foot bolts, the lip's front rivets, and the Redjaw pinned strap band.
Colours from cannon_launcher.TONES only. Class "detail" (1500 tris, 3000 verts, 1 draw).
  blender -b --threads 2 --python-exit-code 1 -P sketches/core-loop/tools/blender/cannon_launcher_detail2.py [-- --out-dir DIR]
"""
import math
from pathlib import Path
import sys

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
import cannon_launcher as cl
import polish
from cannon_launcher import Frame, frustum, around, ring, slab, tone
from cannon_launcher_detail1 import stud, on_barrel, perp, DETAIL

NAME = "cannon_launcher_detail2"
SIZE = [6.981, 7.898, 10.148]
STRAP = (1.2, .28, .09)


def barrel_r(t):
    rows = cl.BARREL
    for (r0, t0), (r1, t1) in zip(rows, rows[1:]):
        if t0 <= t <= t1:
            return r0 + (r1 - r0) * (t - t0) / (t1 - t0)
    return rows[-1][0]


def build(s):
    b = cl.barrel_frame(s)
    t, (along, around_) = cl.PATCH
    r = barrel_r(t) + .1
    for dt in (-along / 2 + .1, along / 2 - .1):
        for dz in (-around_ / 2 + .1, around_ / 2 - .1):
            p = b.at((r, t + dt, dz))
            stud(s, p, b.u, .07, .06, tone("iron"))
    g = cl.gauge_frame(s)
    frustum(g, .07, .05, .1, .17, 6, tone("patch"), caps=(False, True))
    face = cl.GAUGE[3]
    for a in around(4, 0.0):
        slab(g, ((face - .15) * math.cos(a), .07, (face - .15) * math.sin(a)),
             (.05 + .05 * abs(math.cos(a)), .02, .05 + .05 * abs(math.sin(a))), tone("iron"))
    for side in (math.pi / 2, -math.pi / 2):
        for t in (.0, .5, 1.6, 2.1):
            p, nrm = on_barrel(b, barrel_r(t), t, side)
            stud(s, p, nrm, .09, .08, tone("copper"))
    for a in around(10, .3):
        p, nrm = on_barrel(b, 2.9, -1.78, a)
        stud(s, p, nrm, .09, .08, tone("copper"))
    lr, l0, l1 = cl.LIP
    for a in around(10, .4):
        p, nrm = on_barrel(b, lr, l1 - .12, a)
        stud(s, p, nrm, .11, .09, tone("copper"))
    f = cl.flywheel_frame(s)
    _, ro, ri, hw = cl.FLY
    ring(f, [(.75, hw + .02), (1.05, hw + .02), (1.05, hw + .08), (.75, hw + .08)], 10, tone("copper"))
    for x, z, _, sleeve, _, _ in cl.PIPES:
        rr, y0, y1 = sleeve
        frustum(s, rr + .14, rr + .14, y0 - .02, y0 + .2, 6, tone("iron"), caps=(False, True), at=(x, z))
    zc, pr, (y0, y1), dr, (d0, d1) = cl.PLATE
    for a in around(6, .5):
        p = (2.4 * math.sin(a), d1, zc + 2.4 * math.cos(a))
        frustum(s, .16, .16, d1 - .03, d1 + .16, 6, tone("iron"), caps=(False, True), at=(p[0], p[2]))
    t, w, h = STRAP
    r = barrel_r(t)
    ring(b, [(r - .02, t - w / 2), (r + h, t - w / 2), (r + h, t + w / 2), (r - .02, t + w / 2)], cl.N, tone("iron"))
    p, nrm = on_barrel(b, r + h, t, math.pi / 2 + .5)
    block = Frame(s, p, nrm, b.d)
    slab(block, (0.0, .1, 0.0), (.16, .12, .22), tone("iron"))
    pin = Frame(s, tuple(p[k] + nrm[k] * .12 for k in range(3)), b.d, perp(b.d))
    frustum(pin, .06, .06, -.3, .3, 6, tone("copper"))


def main():
    polish.enable(bevel=.02, bevel_min=.25, **cl.kit.BAKE)
    cl.export(NAME, [("Detail2", "steel", False, build)], {}, cl.out_dir(), budget=DETAIL, tag="CANNON_D2", size=SIZE)


if __name__ == "__main__":
    main()
