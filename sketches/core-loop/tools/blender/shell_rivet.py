# VD-01 Rivet pilot and class equipment. shell_base.spherical() seats the
# pilot inside the clear rolling hull. Authored here from Blender primitives.

import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import common  # noqa: E402
import shell_base as sb  # noqa: E402
from common import Part  # noqa: E402

DOME_C = (0.0, -0.02, 0.84)
DOME_R = 0.6
FIN = [(0.0, 0.2), (0.12, 0.18), (0.56, -0.64), (0.47, -0.76), (0.0, -0.22)]


def pod():
    p = Part("Pod")
    sb.saddle(p, color="oxide")
    for side in (-1, 1):
        root_x = side * 0.58
        p.box("bare_metal", (0.1, 0.46, 0.34), loc=(root_x, -0.02, 0.8))
        for k, z in enumerate((0.68, 0.8, 0.92)):
            reach = 1.0 - 0.12 * k
            outline = [(side * (0.6 + x * reach), y) for x, y in FIN]
            if side < 0:
                outline.reverse()
            outline = [(x - side * 0.6, y) for x, y in outline]
            dihedral = common.mtx((side * 0.6, 0, z), (0, -side * 0.28, 0))
            p.prism("class_accent", outline, 0.035, matrix=dihedral)
        for z in (0.7, 0.9):
            p.bolt((root_x + side * 0.05, 0.12, z), (side, 0, 0), r=0.025)
    for side in (-1, 1):
        base = (side * 0.2, -0.5, 0.78)
        top = (side * 0.24, -0.72, 1.3)
        p.rod("bare_metal", base, top, 0.07, 8)
        p.rod("rubber", top, (top[0], top[1] - 0.02, top[2] + 0.06), 0.085, 8)
        mid = [base[i] + (top[i] - base[i]) * 0.45 for i in range(3)]
        p.rod("paint", (mid[0], mid[1] + 0.02, mid[2] - 0.05), (mid[0], mid[1] - 0.02, mid[2] + 0.05), 0.08, 8,
              color="petrol")
    p.box("paint", (0.36, 0.14, 0.12), loc=(0, -0.52, 0.78), color="petrol")
    # The optical rail: a flat bed, not a barrel, with a slotted carriage and the lens.
    # It runs forward and down from the pod, so the lens sits below the pilot's face.
    tilt = -0.38
    rail = common.mtx((0, 0.5, 0.78), (tilt, 0, 0))
    p.box("bare_metal", (0.16, 0.9, 0.035), loc=rail @ common.Vector((0, 0.45, 0)), rot=(tilt, 0, 0))
    p.box("rubber", (0.05, 0.88, 0.02), loc=rail @ common.Vector((0, 0.45, 0.025)), rot=(tilt, 0, 0))
    p.box("paint", (0.14, 0.12, 0.08), loc=rail @ common.Vector((0, 0.3, 0.06)), rot=(tilt, 0, 0), color="bone")
    lens = rail @ common.Vector((0, 0.95, 0))
    p.cyl("paint", 0.14, 0.14, 0.1, 12, loc=lens, rot=(math.pi / 2 + tilt, 0, 0), color="petrol")
    face = rail @ common.Vector((0, 1.01, 0))
    p.ring("bare_metal", 0.1, 0.16, 0.04, 12, loc=face, rot=(math.pi / 2 + tilt, 0, 0))
    p.cyl("class_accent", 0.1, 0.1, 0.02, 12, loc=rail @ common.Vector((0, 1.015, 0)), rot=(math.pi / 2 + tilt, 0, 0))
    return p


def pilot():
    f = Part("Pilot")
    fur = common.mix("charcoal", "bone", 0.32)
    pink = common.mix("oxide", "bone", 0.55)
    f.cyl("pilot", 0.28, 0.2, 0.16, 12, loc=(0, -0.02, 0.9), color="bone")
    f.box("pilot", (0.06, 0.03, 0.14), loc=(0.12, 0.2, 0.9), color="copper")
    f.box("pilot", (0.06, 0.03, 0.14), loc=(-0.12, 0.2, 0.9), color="copper")
    f.uv("pilot", 0.23, 16, 10, loc=(0, 0.0, 1.1), scale=(1.1, 1.05, 0.88), color=fur)
    f.rod("pilot", (0, 0.14, 1.06), (0, 0.4, 1.02), 0.085, 8, color=pink, r2=0.04)
    for k in range(6):
        a = k * math.tau / 6
        f.rod("pilot", (0, 0.41, 1.02), (0.05 * math.cos(a), 0.45, 1.02 + 0.05 * math.sin(a)), 0.012, 4,
              color=pink)
    f.ring("pilot", 0.22, 0.27, 0.035, 12, loc=(0, 0.0, 1.14), color="charcoal", arc=(math.pi - 0.2, 2 * math.pi + 0.2))
    for side in (-1, 1):
        f.ico("pilot", 0.07, 1, loc=(side * 0.2, 0.22, 0.94), scale=(1.2, 0.8, 0.6), color=pink)
        for k in (-1, 0, 1):
            f.rod("pilot", (side * 0.2 + k * 0.035, 0.27, 0.94), (side * 0.2 + k * 0.04, 0.33, 0.93), 0.012, 4,
                  color="bone")
    for side in (-1, 1):
        f.ring("pilot", 0.055, 0.085, 0.04, 10, loc=(side * 0.09, 0.205, 1.16), rot=(math.pi / 2, 0, 0), color="copper")
        sb.eye(f, (side * 0.09, 0.23, 1.16), 0.049)
    cable = [(-0.24, 0.02, 1.12), (-0.32, -0.08, 1.02), (-0.34, -0.14, 0.92), (-0.28, -0.22, 0.86)]
    for a, b in zip(cable, cable[1:]):
        f.rod("pilot", a, b, 0.018, 5, color="charcoal")
    return f


def visor():
    """The visor is class_accent (section 9), so it is its own object under Pilot."""
    v = Part("Visor")
    v.ring("class_accent", 0.22, 0.29, 0.09, 12, loc=(0, 0.0, 1.14), arc=(0.35, math.pi - 0.35))
    v.box("rubber", (0.05, 0.05, 0.06), loc=(-0.27, 0.02, 1.13))
    return v


def main():
    common.reset()
    common.preview_class("copper")
    root, core_obj, pilot_obj = sb.spherical("Rivet", pod(), pilot())
    sb.finish("Rivet", root, core_obj, pilot_obj)


main()
