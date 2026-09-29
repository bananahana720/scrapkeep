# C07 Sable pod, world-one wear pass. Ports tools/blender/shell_sable.py (read-only
# reference) and adds broad wear and exposed mechanisms without growing the silhouette:
# chipped and mismatched-repair patches on the plates, worn saddle edge, weld beads,
# a ratchet gear and pawl on the flank spool, spool braces, a rope run and a guy wire
# on the stubby mast. Ears, spool, mast, node names, pilot and slots are unchanged.
# Budget: shell+rig pod stays under the 16,000 T / 15,000 V no-growth ceiling.
#
#   systemd-run --user --scope -p MemoryMax=20G -p MemorySwapMax=2G \
#     blender -b --factory-startup -P world_one/shell_sable.py -- --out <file.glb>

import math
import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))

import common  # noqa: E402
import shell_base as sb  # noqa: E402
from common import Part  # noqa: E402

# No-growth pod ceiling (ASSETS.md, pod class): 16,000 T / 15,000 V with the 4,592 T,
# 2,950 V pilot rig glb. shell_base.SHELL_TRIS is the older per-recipe range.
RIG_TRIS = 4592
POD_TRIS_MAX = 16000
SHELL_TRIS = (3000, POD_TRIS_MAX - RIG_TRIS - 4344)

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
    wear(p, sx, sz)
    return p


def wear(p, sx, sz):
    """Wear and exposed mechanisms; every piece stays inside the old pod extents."""
    # Plates: a rubbed-through metal chip and a mismatched repair patch on each panel.
    repair = ["bone", "petrol", "oxide", "bone", "petrol"]
    for k, deg in enumerate((40, 100, 140, 220, 300)):
        a = math.radians(deg)
        b = a + 0.16
        p.box("bare_metal", (0.052, 0.07, 0.08), loc=(0.782 * math.cos(b), 0.782 * math.sin(b), 0.58),
              rot=(0, -0.45, b))
        c = a - 0.13
        p.box("paint", (0.05, 0.075, 0.09), loc=(0.775 * math.cos(c), 0.775 * math.sin(c), 0.69),
              rot=(0, -0.45, c), color=repair[k])
    # Saddle edge rubbed to bare metal in two arcs.
    for start in (0.4, 3.6):
        p.ring("bare_metal", 0.615, 0.643, 0.03, 4, loc=(0, 0, 0.79), arc=(start, start + 0.8))
    # Weld beads where plates meet.
    for deg in (70, 180, 260):
        a = math.radians(deg)
        p.rod("bare_metal", (0.77 * math.cos(a), 0.77 * math.sin(a), 0.55),
              (0.79 * math.cos(a), 0.79 * math.sin(a), 0.75), 0.014, 5)
    # Spool ratchet: toothed wheel on the outer flange with a pinned pawl.
    tx = sx + 0.093
    for k in range(8):
        a = k * math.tau / 8
        p.box("bare_metal", (0.014, 0.034, 0.04), loc=(tx, 0.165 * math.cos(a), sz + 0.165 * math.sin(a)),
              rot=(a - 0.35, 0, 0))
    p.box("bare_metal", (0.014, 0.06, 0.03), loc=(tx, 0.045, sz + 0.165), rot=(0.2, 0, 0))
    p.bolt((tx + 0.007, 0.075, sz + 0.165), (1, 0, 0), r=0.014, h=0.006, segs=5)
    # Flange bolts.
    for k in range(4):
        a = k * math.tau / 4 + 0.4
        p.bolt((sx + 0.1, 0.12 * math.cos(a), sz + 0.12 * math.sin(a)), (1, 0, 0), r=0.014, h=0.006, segs=5)
    # Braces from saddle to spool bracket, and the rope run to the fairlead.
    for y in (-0.08, 0.08):
        p.beam("bare_metal", (0.64, y, 0.7), (sx - 0.06, y * 1.4, sz - 0.05), 0.03)
    p.rod("rubber", (sx, 0.1, sz - 0.135), (sx, 0.31, sz - 0.085), 0.018, 5)
    # Mast: swivel collar and a guy wire back to the saddle.
    p.cyl("bare_metal", 0.07, 0.07, 0.03, 7, loc=(-0.456, -0.5, 0.85), rot=(-0.3, 0, 0))
    p.rod("bare_metal", (-0.55, -0.59, 1.16), (-0.47, -0.42, 0.79), 0.01, 4)


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
    shell_tris = common.tri_total(root, skip=(pilot_obj.name,))
    ok = common.report("Sable", [("shell", shell_tris, SHELL_TRIS), ("pilot", common.tris(pilot_obj), sb.PILOT_TRIS)])
    radius = common.max_radius(core_obj)
    print("CORE_RADIUS Sable %.3f %s" % (radius, "ok" if radius <= 1.0 else "OUT"))
    out = common.args()["out"] or os.path.join(common.MODELS, "world_one", "shell_sable.glb")
    common.export(root, out)
    if not ok or radius > 1.0:
        raise SystemExit("budget out of range for Sable")


main()
