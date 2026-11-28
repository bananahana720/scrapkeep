"""Detail layer 1 for the steam lift (wave 12-D RECIPE-WAVE, the DETAIL-CART loop): an additive steel shell at the pump's
origin (the foot), authored from gap list A (units/rc-lift_platform/gaps_A.md) against lift_platform_202.png. Dome rivets,
dome strap bands, the filler cap, the riser collar and flange bolts, corner brackets, base bolts, the elbow valve's
handwheel, the safety valve's bands, the gauge housing drum, the valve block's lever and the U pipe's bend flanges.
Static parts only: the deck rides the lift body, so its rim and column detail stays in lift_platform_deck.glb.
Colours from lift_platform.TONES only. Class "detail" (1500 tris, 3000 verts, 1 draw). No game code loads it yet; its
row in assets/registry.d/lift_platform.json records the draw distance it is meant to get.
  blender -b --threads 2 --python-exit-code 1 -P sketches/core-loop/tools/blender/lift_platform_detail1.py [-- --out-dir DIR]
"""
import math
from pathlib import Path
import sys

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
import lift_platform as lp
from lift_platform import Frame, frustum, around, ring, slab, tone, cross, unit, pump, strut

DETAIL = [1500, 3000, 1]
NAME = "lift_platform_detail1"
SIZE = [3.756, 4.28, 7.059]


def perp(n):
    return unit(cross(n, (0.0, 1.0, 0.0) if abs(n[1]) < .9 else (1.0, 0.0, 0.0)))


def stud(s, at, normal, r, h, color, n=6):
    f = Frame(s, at, normal, perp(normal))
    frustum(f, r, r * .7, -.05, h, n, color, caps=(False, True))


def band(f, r0, r1, t0, t1, n, color):
    ring(f, [(r0, t0), (r1, t0), (r1, t1), (r0, t1), (r0, t0)], n, color)


def dome_point(f, r, t, nr, nt, a):
    p = f.at((r * math.sin(a), t, r * math.cos(a)))
    v = (nr * math.sin(a), nt, nr * math.cos(a))
    nrm = unit(tuple(v[0] * f.u[k] + v[1] * f.d[k] + v[2] * f.w[k] for k in range(3)))
    return p, nrm


def build(s):
    for z in lp.TANK_Z:
        f = lp.tank_frame(s, z)
        for a in around(10, .3):
            p, nrm = dome_point(f, .95, -1.71, .51, -.86, a)
            stud(s, p, nrm, .09, .1, tone("copper"))
        band(f, 1.27, 1.38, -1.3, -1.12, lp.NT, tone("iron"))
        side = 1.0 if z > 0 else -1.0
        for x in lp.CRADLE_X:
            strut(s, pump((x, .35, z + side * 1.25)), pump((x * .9, 1.6, z + side * 1.15)), .16, .16, tone("iron"))
    frustum(s, .24, .2, 3.15, 3.45, 6, tone("iron"), at=(lp.PUMP_AT[0] - .7, lp.TANK_Z[0]))
    rx, rz = lp.PUMP_AT[0] + lp.RISER_AT[0], lp.RISER_AT[1]
    for y in (3.6, 3.78):
        ring(s, [(.58, y), (.72, y), (.72, y + .1), (.58, y + .1), (.58, y)], 6, tone("iron"), at=(rx, rz))
    for a in around(6, .5):
        stud(s, (rx + .8 * math.sin(a), 3.45, rz + .8 * math.cos(a)), (0.0, 1.0, 0.0), .07, .07, tone("copper"))
    (cx, cy, cz), (hx, hy, hz) = lp.BASE
    for x in (-hx + .2, hx - .2):
        for zz in (-hz + .2, -hz / 3, hz / 3, hz - .2):
            stud(s, pump((cx + x, cy + hy, cz + zz)), (0.0, 1.0, 0.0), .09, .08, tone("iron"))
    (vx, vz), (r0, y0, y1), (r1, y2, y3) = lp.ELBOW_VALVE
    at = (lp.PUMP_AT[0] + vx, vz)
    ring(s, [(r0 - .02, 2.2), (r0 + .05, 2.2), (r0 + .05, 2.35), (r0 - .02, 2.35), (r0 - .02, 2.2)], 6, tone("copper"), at=at)
    ring(s, [(.26, y3), (.38, y3), (.38, y3 + .07), (.26, y3 + .07), (.26, y3)], 8, tone("iron"), at=at)
    frustum(s, .05, .05, y3 - .05, y3 + .1, 4, tone("iron"), at=at)
    (hx2, hz2), (pr, p0, p1), _ = lp.CHIMNEY
    for y in (p0 + .2, p0 + .55):
        ring(s, [(pr - .02, y), (pr + .05, y), (pr + .05, y + .08), (pr - .02, y + .08), (pr - .02, y)], 6, tone("copper"),
             at=(lp.PUMP_AT[0] + hx2, hz2))
    g = lp.GAUGES[0]
    gf = lp.gauge_frame(s, g)
    ring(gf, [(.02, -.32), (g[1] * .92, -.32), (g[1] * .92, -.02), (.02, -.02)], 8, tone("iron"))
    (bx, by, bz), (bhx, bhy, bhz) = lp.VALVE_BLOCK
    strut(s, pump((bx + bhx - .05, by + .1, bz)), pump((bx + bhx + .35, by + .55, bz)), .08, .08, tone("iron"))
    stud(s, pump((bx + bhx + .35, by + .55, bz)), (1.0, 0.0, 0.0), .1, .1, tone("iron"))
    frustum(s, .14, .14, by + bhy - .05, by + bhy + .22, 6, tone("copper"), at=(lp.PUMP_AT[0] + bx - .2, bz))
    for p in lp.U_PIPE[1:4]:
        ring(s, [(lp.PIPE_R - .02, p[1] - .2), (lp.PIPE_R + .07, p[1] - .2), (lp.PIPE_R + .07, p[1] - .1),
                 (lp.PIPE_R - .02, p[1] - .1), (lp.PIPE_R - .02, p[1] - .2)], 6, tone("copper"),
             at=(lp.PUMP_AT[0] + p[0], p[2]))


def main():
    lp.polish_on()
    lp.export(NAME, [("Detail1", "steel", False, build)], lp.out_dir(), lp.pump_clear, budget=DETAIL, tag="LIFT_D1", size=SIZE)


if __name__ == "__main__":
    main()
