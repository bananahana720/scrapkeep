import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import common
import shell_base as sb
from common import Part, Vector

DOME_C = (0.0, 0.2, 0.8)
DOME_R = 0.56
VANE_HINGE = (0.0, -0.32, 1.02)


def satchel(p, loc, yaw, canvas):
    m = common.mtx(loc, (0, 0, yaw))
    p.box("paint", (0.3, 0.2, 0.26), loc=m @ Vector((0, 0, 0)), rot=(0, 0, yaw), color=canvas)
    p.box("paint", (0.31, 0.12, 0.08), loc=m @ Vector((0, 0.05, 0.12)), rot=(0.3, 0, yaw), color="petrol")
    for dz in (-0.07, 0.03):
        p.box("class_accent", (0.32, 0.22, 0.045), loc=m @ Vector((0, 0, dz)), rot=(0, 0, yaw))
    for dx in (-0.07, 0.07):
        top = m @ Vector((dx, -0.03, 0.13))
        tip = m @ Vector((dx * 1.3, -0.05, 0.25))
        p.rod("rubber", top, tip, 0.014, 5)
        p.ico("class_accent", 0.028, 1, loc=tip)
    p.rod("rubber", m @ Vector((0, -0.1, 0.1)), (loc[0] * 0.7, loc[1] * 0.7, loc[2] + 0.12), 0.02, 5)


def pod():
    p = Part("Pod")
    sb.saddle(p, center=(0.0, 0.14, 0.76), r_in=0.42, r_out=0.62, color="bone")
    satchel(p, (0.8, -0.08, 0.66), math.pi / 2 + 0.2, "oxide")
    satchel(p, (0.06, -0.8, 0.64), math.pi, "petrol")
    satchel(p, (-0.74, 0.3, 0.62), -math.pi / 2 - 0.3, "oxide")
    base = Vector((-0.6, -0.42, 0.78))
    mouth = Vector((-0.66, -0.26, 1.2))
    p.rod("paint", base, mouth, 0.09, 10, color="oxide")
    p.rod("bare_metal", base - (mouth - base) * 0.12, base + (mouth - base) * 0.12, 0.11, 10)
    p.ring("class_accent", 0.065, 0.115, 0.05, 10, loc=mouth,
           rot=(Vector((0, 0, 1)).rotation_difference((mouth - base).normalized())).to_euler())
    for side in (-1, 1):
        p.box("paint", (0.03, 0.26, 0.22), loc=base + Vector((side * 0.13, 0.02, 0.02)), color="petrol")
        p.rod("bare_metal", base + Vector((side * 0.13, -0.12, -0.06)), base + Vector((side * 0.13, -0.02, 0.2)),
              0.022, 6)
    p.beam("bare_metal", (-0.35, -0.2, 0.8), base, 0.06)
    p.beam("bare_metal", (0, -0.2, 0.88), (0, -0.9, 0.9), 0.06, 0.05)
    p.beam("bare_metal", (0, -0.62, 0.9), (0, -0.62, 0.72), 0.05)
    return p


def blade(name, side):
    """One vane blade standing folded; the hinge runs fore-aft along its base, and
    opening turns it 90 degrees outward about that axis (VaneL/VaneR, rotation y)."""
    b = Part(name)
    outline = [(0.1, 0.0), (-0.62, 0.0), (-0.7, 0.07), (-0.58, 0.3), (-0.02, 0.16)]
    m = common.mtx((side * 0.03, 0, 0), (0, -math.pi / 2, 0))
    yz = [(z, y) for y, z in outline]
    hinge = Vector(VANE_HINGE)
    b.prism("paint", yz, 0.028, matrix=common.mtx(hinge) @ m, color="bone")
    for y in (-0.1, -0.35):
        b.beam("bare_metal", hinge + Vector((side * 0.045, y, 0.01)), hinge + Vector((side * 0.045, y, 0.22)), 0.03)
    b.box("rubber", (0.05, 0.72, 0.04), loc=hinge + Vector((0, -0.27, 0.0)))
    return b


def pilot():
    f = Part("Pilot")
    crest = common.mix("oxide", "amber", 0.2)
    beak = common.mix("amber", "sandstone", 0.35)
    f.uv("pilot", 0.21, 24, 16, loc=(0, 0.2, 1.09), scale=(1.02, 0.88, 1.0), color="bone")
    for side in (-1, 1):
        f.uv("pilot", 0.08, 12, 8, loc=(side * 0.115, 0.302, 1.085), scale=(0.85, 0.40, 1.15), color="charcoal")
        f.ring("pilot", 0.044, 0.063, 0.03, 16, loc=(side * 0.088, 0.35, 1.155), rot=(math.pi / 2, 0, 0), color="copper")
        sb.eye(f, (side * 0.088, 0.374, 1.155), 0.040)
    f.rod("pilot", (-0.027, 0.35, 1.158), (0.027, 0.35, 1.158), 0.012, 8, color="charcoal")
    f.uv("pilot", 0.08, 16, 10, loc=(0, 0.357, 1.035), scale=(0.8, 1.2, 0.6), color=beak)
    f.rod("pilot", (0, 0.39, 1.043), (0, 0.475, 0.99), 0.045, 10, color=beak, r2=0.006)
    f.rod("pilot", (0, 0.37, 0.994), (0, 0.44, 0.976), 0.026, 8, color="charcoal", r2=0.005)
    for k in range(3):
        f.uv("pilot", 0.07, 12, 8, loc=(0, 0.16 - k * 0.05, 1.3 + k * 0.015), scale=(0.42, 0.65, 1.75), rot=(0.35 + k * 0.2, 0, 0), color=crest)
    return f


def main():
    common.reset()
    common.preview_class("amber")
    root, core_obj, pilot_obj = sb.spherical("Kest", pod(), pilot(), extras=[(blade("VaneL", -1), VANE_HINGE), (blade("VaneR", 1), VANE_HINGE)])
    sb.finish("Kest", root, core_obj, pilot_obj)


main()
