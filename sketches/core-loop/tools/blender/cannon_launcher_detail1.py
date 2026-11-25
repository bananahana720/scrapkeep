"""Detail layer 1 for the cannon launcher (wave 12-D RECIPE-WAVE, the DETAIL-CART loop): an additive steel shell at the
body's origin, authored from gap list A (units/rc-cannon_launcher/gaps_A.md) against cannon_launcher_202.png. Bolt and stud
rows on the plate, deck, flange, collar, lip and boiler; collar lugs; the gauge's ticks, needle and elbow; the flywheel's
hub boss and inner rim lip; the side valve; the turntable ring. Colours from cannon_launcher.TONES only. Class "detail"
(1500 tris, 3000 verts, 1 draw); the game drops it by distance (LAYER_RANGE in tools/w12_side_cannon_launcher.gd).
  blender -b --threads 2 --python-exit-code 1 -P sketches/core-loop/tools/blender/cannon_launcher_detail1.py [-- --out-dir DIR]
"""
import math
from pathlib import Path
import sys

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
import cannon_launcher as cl
import polish
from cannon_launcher import Frame, frustum, around, ring, slab, tone, cross, unit

DETAIL = [2300, 3000, 1]
NAME = "cannon_launcher_detail1"
SIZE = [7.271, 7.898, 9.725]
STUD = 6


def perp(n):
    return unit(cross(n, (0.0, 1.0, 0.0) if abs(n[1]) < .9 else (1.0, 0.0, 0.0)))


def stud(s, at, normal, r, h, color, n=STUD):
    f = Frame(s, at, normal, perp(normal))
    frustum(f, r, r * .7, -.05, h, n, color, caps=(False, True))


def on_barrel(b, radius, t, a):
    p = b.at((radius * math.sin(a), t, radius * math.cos(a)))
    nrm = tuple(math.sin(a) * b.u[k] + math.cos(a) * b.w[k] for k in range(3))
    return p, nrm


def build(s):
    b = cl.barrel_frame(s)
    zc, pr, (y0, y1), dr, (d0, d1) = cl.PLATE
    for a in around(12, .1):
        stud(s, (pr * math.sin(a), (y0 + y1) / 2, zc + pr * math.cos(a)), (math.sin(a), 0.0, math.cos(a)), .1, .09, tone("iron"))
    for a in around(12, .26):
        stud(s, (2.62 * math.sin(a), d1, zc + 2.62 * math.cos(a)), (0.0, 1.0, 0.0), .1, .08, tone("copper"))
    ring(s, [(2.55, d1 - .02), (2.55, d1 + .12), (2.3, d1 + .12), (2.3, d1 - .02)], 14, tone("copper"), at=(0.0, zc))
    cr, c0, c1 = cl.COLLAR
    for a in around(4, math.pi / 4):
        p, nrm = on_barrel(b, cr, (c0 + c1) / 2, a)
        lug = Frame(s, p, nrm, b.d)
        slab(lug, (0.0, .08, 0.0), (.32, .13, .26), tone("iron"))
        stud(s, tuple(p[k] + nrm[k] * .2 for k in range(3)), nrm, .09, .08, tone("copper"))
    fr, f0, f1 = cl.FLANGE
    for a in around(10, .2):
        p = b.at(((fr - .22) * math.sin(a), f1, (fr - .22) * math.cos(a)))
        stud(s, p, b.d, .09, .08, tone("copper"))
    lr, l0, l1 = cl.LIP
    br = cl.BARREL[-1][0]
    ring(b, [(br - .02, l0 - .22), (br + .1, l0 - .22), (br + .1, l0), (br - .02, l0)], cl.N, tone("body"))
    for a in around(10, .1):
        p, nrm = on_barrel(b, lr, (l0 + l1) / 2, a)
        stud(s, p, nrm, .08, .07, tone("copper"))
    p, nrm = on_barrel(b, 2.0, 1.2, math.pi)
    stud(s, p, nrm, .16, .14, tone("copper"))
    for a in around(8, .4):
        p, nrm = on_barrel(b, 2.9, -2.4, a)
        stud(s, p, nrm, .08, .07, tone("iron"))
    p, nrm = on_barrel(b, 2.9, -2.0, math.pi / 2 + .45)
    valve = Frame(s, p, nrm, perp(nrm))
    frustum(valve, .16, .16, -.05, .35, 6, tone("copper"), caps=(False, True))
    frustum(valve, .3, .3, .35, .43, 8, tone("copper"))
    frustum(valve, .07, .05, .43, .6, 6, tone("iron"), caps=(False, True))
    g = cl.gauge_frame(s)
    face = cl.GAUGE[3]
    for a in around(10, math.pi):
        slab(g, ((face - .1) * math.cos(a), .06, (face - .1) * math.sin(a)), (.035, .02, .035), tone("iron"))
    slab(g, (.2, .1, 0.0), (.24, .015, .035), tone("iron"))
    frustum(g, .06, .06, .06, .12, 6, tone("copper"), caps=(False, True))
    centre = cl.GAUGE[0]
    frustum(s, .16, .16, cl.GAUGE_ARM[0][1] - .2, cl.GAUGE_ARM[0][1] + .2, 6, tone("copper"),
            at=(cl.PIPES[1][0], cl.PIPES[1][1]))
    stud(s, cl.GAUGE_ARM[1], cl.GAUGE[1], .14, .12, tone("copper"))
    f = cl.flywheel_frame(s)
    _, ro, ri, hw = cl.FLY
    ring(f, [(.42, hw - .05), (.78, hw - .05), (.78, hw + .12), (.42, hw + .12)], 10, tone("copper"))
    ring(f, [(ri + .02, hw - .03), (ri - .16, hw - .03), (ri - .16, hw + .06), (ri + .02, hw + .06)], cl.NF, tone("body"))


def main():
    polish.enable(bevel=.02, bevel_min=.25, **cl.kit.BAKE)
    cl.export(NAME, [("Detail1", "steel", False, build)], {}, cl.out_dir(), budget=DETAIL, tag="CANNON_D1", size=SIZE)


if __name__ == "__main__":
    main()
