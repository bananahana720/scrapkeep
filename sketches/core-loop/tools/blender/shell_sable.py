import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import common
import shell_base as sb
from common import Part

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
    f.uv("pilot", 0.22, 24, 16, loc=(0, 0.01, 1.1), scale=(1.04, 0.88, 0.94), color="oxide")
    for side in (-1, 1):
        f.uv("pilot", 0.105, 16, 10, loc=(side * 0.095, 0.12, 1.025), scale=(1.0, 1.05, 0.7), color="bone")
        sb.eye(f, (side * 0.082, 0.175, 1.135), 0.037)
        f.rod("pilot", (side * 0.035, 0.174, 1.185), (side * 0.125, 0.153, 1.19), 0.013, 8, color="charcoal")
        sb.ear(f, (side * 0.13, -0.01, 1.235), 0.19, 0.14, side * -0.26, "oxide", inner="bone", tip="charcoal")
    f.uv("pilot", 0.1, 16, 10, loc=(0, 0.215, 1.035), scale=(0.74, 1.30, 0.60), color="bone")
    f.uv("pilot", 0.06, 12, 8, loc=(0, 0.242, 0.995), scale=(1.0, 1.25, 0.30), color="charcoal")
    f.uv("pilot", 0.033, 12, 8, loc=(0, 0.328, 1.055), scale=(1.05, 0.62, 0.78), color="charcoal")
    f.uv("pilot", 0.115, 16, 8, loc=(0, -0.035, 1.265), scale=(1.15, 1.1, 0.48), color="petrol")
    f.uv("pilot", 0.09, 12, 6, loc=(0, 0.075, 1.265), scale=(1.35, 0.9, 0.12), color="petrol")
    return f


def main():
    common.reset()
    root, core_obj, pilot_obj = sb.spherical("Sable", pod(), pilot(), extras=[("RopeExit", (0.84, 0.36, 0.58))])
    sb.finish("Sable", root, core_obj, pilot_obj)


main()
