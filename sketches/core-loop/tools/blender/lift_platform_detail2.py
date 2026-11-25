"""Detail layer 2 for the steam lift (wave 12-D RECIPE-WAVE, the DETAIL-CART loop's moving baseline): an additive steel shell
at the pump's origin (the foot), authored from gap list C (units/rc-lift_platform/gaps_C.md), the pass-1 render re-imagined
by FLUX.1 schnell image-to-image (strength 0.55, 6 steps, seed 101). Inner seam bands with rivet rings, studs on the outer
bands, the riser's bolted cap plate, the valve gauge's ticks and needle, bolted bracket feet and the base plate's edge lip.
Colours from lift_platform.TONES only. Class "detail" (1500 tris, 3000 verts, 1 draw).
  blender -b --threads 2 --python-exit-code 1 -P sketches/core-loop/tools/blender/lift_platform_detail2.py [-- --out-dir DIR]
"""
import math
from pathlib import Path
import sys

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
import lift_platform as lp
from lift_platform import frustum, around, ring, slab, tone, pump
from lift_platform_detail1 import stud, band, dome_point, DETAIL

NAME = "lift_platform_detail2"
SIZE = [4.0, 3.75, 6.272]


def build(s):
    for z in lp.TANK_Z:
        f = lp.tank_frame(s, z)
        band(f, 1.27, 1.38, 1.12, 1.3, lp.NT, tone("iron"))
        for a in around(10, .3):
            p, nrm = dome_point(f, .95, 1.71, .51, .86, a)
            stud(s, p, nrm, .09, .1, tone("copper"))
        for a in around(8, .1):
            p, nrm = dome_point(f, 1.38, -1.21, 1.0, 0.0, a)
            stud(s, p, nrm, .07, .06, tone("copper"))
        side = 1.0 if z > 0 else -1.0
        for x in lp.CRADLE_X:
            foot = pump((x, .38, z + side * 1.25))
            slab(s, foot, (.22, .03, .16), tone("iron"))
            stud(s, (foot[0] + .12, .41, foot[2]), (0.0, 1.0, 0.0), .05, .05, tone("copper"))
            stud(s, (foot[0] - .12, .41, foot[2]), (0.0, 1.0, 0.0), .05, .05, tone("copper"))
    rx, rz = lp.PUMP_AT[0] + lp.RISER_AT[0], lp.RISER_AT[1]
    top = lp.RISER[-1][1]
    ring(s, [(.02, top - .05), (.78, top - .05), (.78, top + .07), (.02, top + .07)], 8, tone("iron"), at=(rx, rz))
    for a in around(6, .2):
        stud(s, (rx + .66 * math.sin(a), top + .07, rz + .66 * math.cos(a)), (0.0, 1.0, 0.0), .06, .06, tone("copper"))
    g = lp.GAUGES[1]
    gf = lp.gauge_frame(s, g)
    for a in around(8, math.pi / 8):
        r = g[2] - .05
        slab(gf, (r * math.cos(a), .05, r * math.sin(a)), (.02, .015, .02), tone("iron"))
    slab(gf, (.08, .06, 0.0), (.1, .012, .015), tone("iron"))
    (cx, cy, cz), (hx, hy, hz) = lp.BASE
    y = cy + hy + .04
    for sx in (-1.0, 1.0):
        slab(s, pump((cx + sx * (hx - .05), y, cz)), (.05, .06, hz), tone("iron"))
    for sz in (-1.0, 1.0):
        slab(s, pump((cx, y, cz + sz * (hz - .05))), (hx - .1, .06, .05), tone("iron"))


def main():
    lp.polish_on()
    lp.export(NAME, [("Detail2", "steel", False, build)], lp.out_dir(), lp.pump_clear, budget=DETAIL, tag="LIFT_D2", size=SIZE)


if __name__ == "__main__":
    main()
