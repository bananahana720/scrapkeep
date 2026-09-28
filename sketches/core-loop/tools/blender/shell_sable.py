# VD-01 Sable pilot and class equipment. shell_base.spherical() seats the
# pilot inside the clear rolling hull. Authored here from Blender primitives.

import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import common  # noqa: E402
import shell_base as sb  # noqa: E402
from common import Part  # noqa: E402

DOME_C = (0.0, 0.0, 0.84)
DOME_R = 0.6


def pod():
    p = Part("Pod")
    sb.saddle(p)
    p.ring("field", 0.62, 0.7, 0.08, 24, loc=(0, 0, 0.7))
    for k in range(12):
        a = k * math.tau / 12
        p.box("rubber", (0.05, 0.1, 0.11), loc=(0.66 * math.cos(a), 0.66 * math.sin(a), 0.7), rot=(0, 0, a))
    colors = ["petrol", "oxide", "bone", "petrol", "oxide"]
    for k, a in enumerate([math.radians(d) for d in (40, 100, 140, 220, 300)]):
        loc = (0.78 * math.cos(a), 0.78 * math.sin(a), 0.64)
        p.box("paint", (0.05, 0.22, 0.26), loc=loc, rot=(0, -0.45, a), color=colors[k])
        top = (0.83 * math.cos(a), 0.83 * math.sin(a), 0.76)
        p.box("class_accent", (0.07, 0.24, 0.04), loc=top, rot=(0, -0.45, a))
        p.bolt((0.8 * math.cos(a), 0.8 * math.sin(a), 0.62), (math.cos(a), math.sin(a), 0.4), r=0.025)
    sx, sz = 0.84, 0.66
    p.beam("bare_metal", (0.6, 0.0, 0.76), (sx - 0.06, 0.0, sz), 0.06)
    p.cyl("paint", 0.13, 0.13, 0.14, 10, loc=(sx, 0.0, sz), rot=(0, math.pi / 2, 0), color="bone")
    for dx in (-0.085, 0.085):
        p.cyl("bare_metal", 0.19, 0.19, 0.03, 10, loc=(sx + dx, 0.0, sz), rot=(0, math.pi / 2, 0))
    for k in range(3):
        p.ring("rubber", 0.128, 0.142, 0.02, 10, loc=(sx - 0.04 + k * 0.04, 0.0, sz), rot=(0, math.pi / 2, 0))
    p.beam("bare_metal", (sx, 0.12, sz - 0.12), (sx, 0.3, sz - 0.08), 0.04)
    p.ring("bare_metal", 0.035, 0.065, 0.05, 8, loc=(sx, 0.32, sz - 0.08), rot=(math.pi / 2, 0, 0))
    # Off-centre, so the chase camera sees the pilot past it.
    base = (-0.42, -0.46, 0.74)
    tip = (-0.56, -0.6, 1.24)
    p.box("paint", (0.2, 0.2, 0.1), loc=base, color="oxide")
    p.rod("bare_metal", base, tip, 0.055, 6, r2=0.035)
    for t in (0.35, 0.65):
        at = [base[i] + (tip[i] - base[i]) * t for i in range(3)]
        p.cyl("rubber", 0.085, 0.085, 0.03, 8, loc=at, rot=(-0.3, 0, 0))
    p.ico("class_accent", 0.09, 1, loc=(-0.58, -0.62, 1.31), scale=(1, 1, 1.5))
    return p


def pilot():
    f = Part("Pilot")
    f.cyl("pilot", 0.27, 0.19, 0.16, 12, loc=(0, -0.02, 0.9), color="petrol")
    f.ring("pilot", 0.15, 0.21, 0.06, 10, loc=(0, 0, 0.99), color="bone")
    f.uv("pilot", 0.22, 16, 10, loc=(0, 0.01, 1.1), scale=(1.08, 0.95, 0.9), color="oxide")
    f.uv("pilot", 0.11, 12, 8, loc=(0.1, 0.11, 1.03), color="bone")
    f.uv("pilot", 0.11, 12, 8, loc=(-0.1, 0.11, 1.03), color="bone")
    f.rod("pilot", (0, 0.1, 1.05), (0, 0.34, 1.02), 0.09, 6, color="bone", r2=0.05)
    f.ico("pilot", 0.035, 1, loc=(0, 0.345, 1.03), color="charcoal")
    for side in (-1, 1):
        sb.eye(f, (side * 0.08, 0.18, 1.14), 0.034)
        sb.ear(f, (side * 0.12, -0.01, 1.2), 0.21, 0.16, side * -0.3, "oxide", inner="bone", tip="charcoal")
        f.ico("pilot", 0.045, 1, loc=(side * 0.2, 0.2, 0.92), color="oxide")
    f.cyl("pilot", 0.1, 0.09, 0.06, 10, loc=(0, -0.05, 1.28), color="petrol")
    f.box("pilot", (0.16, 0.1, 0.02), loc=(0, 0.07, 1.265), rot=(-0.15, 0, 0), color="petrol")
    f.rod("pilot", (0, 0.2, 0.86), (0, 0.24, 0.96), 0.018, 6, color="charcoal")
    return f


def main():
    common.reset()
    root, core_obj, pilot_obj = sb.spherical("Sable", pod(), pilot(), extras=[("RopeExit", (0.84, 0.36, 0.58))])
    sb.finish("Sable", root, core_obj, pilot_obj)


main()
