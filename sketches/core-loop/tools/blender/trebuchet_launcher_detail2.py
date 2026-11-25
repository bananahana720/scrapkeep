"""Detail layer 2 for the trebuchet launcher (wave 12-D RECIPE-WAVE, the DETAIL-CART loop's moving baseline): an additive
steel shell at the frame's origin, authored from gap list C (units/rc-trebuchet_launcher/gaps_C.md), the re-imagined
picture against the pass-1 render. Gauge needles, ticks and rims (C1, C2), the box's panel border and knob plate (C3, C4),
the pulley hub (C6), cable clamps (C7), a second beam rivet row (C8), the piston gland (C9), the valve hand wheel (C11), the
lamp cup (C12), a bolted patch plate (C13) and hose clamps (C14). Colours from trebuchet_launcher.TONES only. Class
"detail" (1500 tris, 3000 verts, 1 draw).
  blender -b --threads 2 --python-exit-code 1 -P sketches/core-loop/tools/blender/trebuchet_launcher_detail2.py [-- --out-dir DIR]
"""
import math
from pathlib import Path
import sys

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
import trebuchet_launcher as tl
from trebuchet_launcher import frustum, ring, box, torus, tone, along_x, along_z, FZ
from trebuchet_launcher_detail1 import rivet
from ore_cart import strut

DETAIL = [1500, 3000, 1]
NAME = "trebuchet_launcher_detail2"
SIZE = [8.954, 12.787, 4.687]


def gauge(s, cx, cy, br, zf):
    rim = along_z(s, (cx, cy, zf - .13))
    ring(rim, [(br - .03, .0), (br + .08, .0), (br + .08, .17), (br - .03, .17), (br - .03, .0)], 10, tone("copper"))
    for k in range(7):
        a = -2.1 + 4.2 * k / 6
        r0, r1 = br * .5, br * .7
        strut(s, (cx + r0 * math.sin(a), cy + r0 * math.cos(a), zf), (cx + r1 * math.sin(a), cy + r1 * math.cos(a), zf),
              .04, .03, tone("iron"))
    strut(s, (cx, cy, zf + .01), (cx + br * .62 * math.sin(.7), cy + br * .62 * math.cos(.7), zf + .01), .05, .03, tone("iron"))


def build(s):
    (x0, x1), (y0, y1), (z0, z1) = tl.BOX
    for (gx, gy), br in tl.GAUGES:
        gauge(s, gx, gy, br, z1 + .13)
    for a, b in (((x0 + .05, y1 - .17), (x1 - .05, y1 - .05)), ((x0 + .05, y0 + .15), (x1 - .05, y0 + .27)),
                 ((x0 + .05, y0 + .15), (x0 + .17, y1 - .05)), ((x1 - .17, y0 + .15), (x1 - .05, y1 - .05))):
        box(s, (a[0], a[1], z1 - .02), (b[0], b[1], z1 + .05), tone("iron"))
    (kx, ky), kr = tl.KNOB
    k = along_z(s, (kx, ky, z1))
    ring(k, [(.02, -.02), (kr + .14, -.02), (kr + .14, .04), (.02, .04)], 10, tone("iron"))
    box(s, (x0 + .25, .25, z1 - .02), (x0 + .7, .95, z1 + .04), tone("beam"))
    for px in (x0 + .32, x0 + .63):
        for py in (.32, .88):
            rivet(s, (px, py, z1 + .04), r=.06, h=.04)
    (qx, qy, qz), qr, qh = tl.PULLEY
    h = along_x(s, (qx, qy, qz))
    ring(h, [(.02, -qh - .12), (.3, -qh - .12), (.3, qh + .12), (.02, qh + .12)], 6, tone("iron"))
    for a, b in tl.CABLES:
        d = tuple(a[i] - b[i] for i in range(3))
        n = math.sqrt(sum(c * c for c in d))
        at = tuple(b[i] + d[i] / n * .6 for i in range(3))
        box(s, (at[0] - .12, at[1] - .12, at[2] - .12), (at[0] + .12, at[1] + .12, at[2] + .12), tone("iron"))
    hl, b0, b1, hd = tl.BEAM
    for i in range(10):
        rivet(s, (-hl + .45 + (i + .5) * (2 * hl - .9) / 10, b0 + .1, tl.FZ + hd), r=.08, h=.05)
    ring(s, [(tl.ROD[0], tl.PISTON[2] - .05), (.28, tl.PISTON[2] - .05), (.24, tl.PISTON[2] + .25), (tl.ROD[0], tl.PISTON[2] + .25)],
         8, tone("copper"), at=(0.0, FZ))
    (vx, vy, vz), vr = tl.VALVE
    torus(s, (vx, vy + .25 + .08, vz), .26, .045, 10, 3, tone("copper"))
    strut(s, (vx - .26, vy + .33, vz), (vx + .26, vy + .33, vz), .05, .05, tone("copper"))
    (lx, ly, lz), lr, _ = tl.LAMP
    ring(s, [(.02, ly - .16), (lr + .04, ly - .16), (lr + .1, ly + .08), (lr + .02, ly + .08), (.02, ly - .1)], 6, tone("copper"), at=(lx, lz))
    (fx, fy, fz), ty, _ = tl.PIPE
    for y in (fy + .9, ty - 1.1):
        ring(s, [(.13, y - .07), (.21, y - .07), (.21, y + .07), (.13, y + .07), (.13, y - .07)], 6, tone("copper"), at=(fx, fz))


def main():
    tl.polish_on()
    tl.export(NAME, [("Detail2", "steel", False, build)], {}, tl.out_dir(), budget=DETAIL, tag="TREBUCHET_D2", size=SIZE)


if __name__ == "__main__":
    main()
