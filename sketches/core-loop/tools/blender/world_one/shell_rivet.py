# C08 Rivet pod, world-one wear pass. Ports tools/blender/shell_rivet.py (read-only
# reference; the port reproduces the shipped GLB byte for byte before wear() is added) and
# adds broad wear and exposed mechanisms without growing the silhouette: chipped fin edges
# and repair patches, riveted fin mounts, a rack and focus knob on the optical rail, lens
# struts and bolts, stack heat shields, braces and a gauge, a worn saddle with weld beads.
# Visor arc, optical rail, raked fins, twin stacks, node names, pilot and slots are unchanged.
# Budget: shell + rig pod stays under the 16,000 T / 15,000 V no-growth ceiling.
#
#   systemd-run --user --scope -p MemoryMax=20G -p MemorySwapMax=2G \
#     blender -b --factory-startup -P world_one/shell_rivet.py -- --out <file.glb>

import math
import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))

import common  # noqa: E402
import shell_base as sb  # noqa: E402
from common import Part  # noqa: E402

# Pod ceiling from ASSETS.md: 16,000 T with the unchanged pilot rig; base pod 14,332 T.
POD_TRIS_MAX = 16000
BASE_POD_TRIS = 14332
BASE_SHELL_TRIS = 5956
SHELL_TRIS = (3000, BASE_SHELL_TRIS + POD_TRIS_MAX - BASE_POD_TRIS)

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
    wear(p, rail, tilt)
    return p


def fin_pt(side, z0, reach, lx, ly):
    """A point on a fin layer in pod space (same dihedral as pod())."""
    return common.mtx((side * 0.6, 0, z0), (0, -side * 0.28, 0)) @ common.Vector((side * lx * reach, ly, 0))


def wear(p, rail, tilt):
    """Wear and exposed mechanisms; every piece stays inside the old pod extents."""
    V = common.Vector
    for side in (-1, 1):
        # Fins: rubbed-through chips on the trailing edge, a mismatched repair plate.
        for k, z in enumerate((0.68, 0.8, 0.92)):
            reach = 1.0 - 0.12 * k
            at = fin_pt(side, z, reach, 0.4, -0.5 - 0.05 * k)
            p.box("bare_metal", (0.09, 0.07, 0.042), loc=at, rot=(0, -side * 0.28, 0.5 * side))
        at = fin_pt(side, 0.8, 0.88, 0.22, -0.2)
        p.box("paint", (0.12, 0.1, 0.05), loc=at, rot=(0, -side * 0.28, 0), color="bone" if side < 0 else "petrol")
        # Fin mounts: a second row of rivets and a patch plate.
        root_x = side * 0.58
        for y in (-0.08,):
            for z in (0.7, 0.9):
                p.bolt((root_x + side * 0.05, y, z), (side, 0, 0), r=0.02, h=0.015, segs=5)
        p.box("paint", (0.02, 0.2, 0.12), loc=(root_x + side * 0.055, 0.07, 0.8), color="bone")
        # Stacks: standoff heat shield and a brace back to the saddle.
        base = V((side * 0.2, -0.5, 0.78))
        top = V((side * 0.24, -0.72, 1.3))
        mid = base + (top - base) * 0.62
        inner = V((mid.x - side * 0.09, mid.y, mid.z))
        p.box("bare_metal", (0.016, 0.08, 0.26), loc=inner, rot=(-0.44, 0, 0))
        p.beam("bare_metal", base + (top - base) * 0.3, (side * 0.4, -0.3, 0.78), 0.024)
    # Gauge on the rear petrol box: bezel, bone face, needle, and a chip on its top.
    g = (0.0, -0.593, 0.79)
    p.ring("bare_metal", 0.045, 0.062, 0.02, 10, loc=g, rot=(math.pi / 2, 0, 0))
    p.cyl("paint", 0.045, 0.045, 0.014, 10, loc=(0, -0.588, 0.79), rot=(math.pi / 2, 0, 0), color="bone")
    p.rod("rubber", (0, -0.598, 0.79), (0.025, -0.598, 0.815), 0.006, 4)
    p.box("bare_metal", (0.08, 0.06, 0.01), loc=(0.11, -0.52, 0.842), rot=(0, 0, 0.3))
    # Optical rail: rack teeth on both edges, focus knob, lens struts and face bolts.
    for side in (-1, 1):
        for k in range(4):
            y = 0.14 + 0.2 * k
            p.box("bare_metal", (0.024, 0.04, 0.03), loc=rail @ V((side * 0.092, y, 0.0)), rot=(tilt, 0, 0))
        strut_a = rail @ V((side * 0.08, 0.72, 0.02))
        strut_b = rail @ V((side * 0.115, 0.9, 0.0))
        p.beam("bare_metal", strut_a, strut_b, 0.024)
    p.cyl("bare_metal", 0.045, 0.045, 0.04, 8, loc=rail @ V((0.1, 0.3, 0.06)), rot=(tilt, math.pi / 2, 0))
    for k in range(2):
        a = k * math.pi + math.pi / 4
        q = rail @ V((0.13 * math.cos(a), 1.03, 0.13 * math.sin(a)))
        n = rail.to_3x3() @ V((0, 1, 0))
        p.bolt(q, n, r=0.014, h=0.012, segs=5)
    # Saddle: two rubbed-through arcs, weld beads and two repair patches with rivets.
    for start in (0.5, 3.7):
        p.ring("bare_metal", 0.615, 0.643, 0.03, 4, loc=(0, 0, 0.8), arc=(start, start + 0.8))
    for deg in (20, 150, 250):
        a = math.radians(deg)
        p.rod("bare_metal", (0.5 * math.cos(a), 0.5 * math.sin(a), 0.83),
              (0.6 * math.cos(a), 0.6 * math.sin(a), 0.83), 0.014, 5)
    for deg, col in ((75, "bone"), (200, "petrol")):
        a = math.radians(deg)
        p.box("paint", (0.1, 0.07, 0.03), loc=(0.56 * math.cos(a), 0.56 * math.sin(a), 0.835), rot=(0, 0, a), color=col)
        for d in (0.0,):
            p.bolt((0.56 * math.cos(a) - d * math.sin(a), 0.56 * math.sin(a) + d * math.cos(a), 0.85),
                   (0, 0, 1), r=0.014, h=0.008, segs=5)


def pilot():
    f = Part("Pilot")
    fur = common.mix("charcoal", "bone", 0.32)
    pink = common.mix("oxide", "bone", 0.55)
    f.uv("pilot", 0.23, 24, 16, loc=(0, 0, 1.1), scale=(1.12, 0.96, 0.93), color=fur)
    f.uv("pilot", 0.1, 16, 10, loc=(0, 0.21, 1.045), scale=(1.05, 1.15, 0.72), color=pink)
    f.uv("pilot", 0.055, 12, 8, loc=(0, 0.31, 1.052), scale=(1, 0.58, 0.68), color=pink)
    f.ring("pilot", 0.224, 0.247, 0.035, 24, loc=(0, 0, 1.16), color="charcoal", arc=(math.pi - 0.2, 2 * math.pi + 0.2))
    for side in (-1, 1):
        f.uv("pilot", 0.06, 12, 8, loc=(side * 0.225, 0.0, 1.135), scale=(0.7, 0.75, 1), color=fur)
        f.ring("pilot", 0.052, 0.076, 0.04, 16, loc=(side * 0.092, 0.195, 1.165), rot=(math.pi / 2, 0, 0), color="copper")
        sb.eye(f, (side * 0.092, 0.218, 1.165), 0.047)
        f.uv("pilot", 0.012, 8, 6, loc=(side * 0.023, 0.34, 1.055), scale=(1, 0.3, 0.7), color="charcoal")
    f.rod("pilot", (-0.024, 0.212, 1.17), (0.024, 0.212, 1.17), 0.011, 8, color="copper")
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
    shell_tris = common.tri_total(root, skip=(pilot_obj.name,))
    ok = common.report("Rivet", [("shell", shell_tris, SHELL_TRIS), ("pilot", common.tris(pilot_obj), sb.PILOT_TRIS)])
    radius = common.max_radius(core_obj)
    print("CORE_RADIUS Rivet %.3f %s" % (radius, "ok" if radius <= 1.0 else "OUT"))
    out = common.args()["out"] or os.path.join(common.MODELS, "world_one", "shell_rivet.glb")
    common.export(root, out)
    if not ok or radius > 1.0:
        raise SystemExit("budget out of range for Rivet")


main()
