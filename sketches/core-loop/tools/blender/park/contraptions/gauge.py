"""Headless recipe for the gauge skin: gauge.glb, gauge_detail1.glb, gauge_detail2.glb (KC9, PARK.md section 4, recipe `gauge`).

A Gorge-era pressure gauge on a post: a dam-era concrete footing with form-board joints, a dark-iron post, a drum of dark iron
behind a copper bezel, a sandstone face with tick marks and an oxide redline. It stands where the code's dial stands
(src/world/contraptions.gd `_dial`): origin on the ground under the post, +Y up, the face looks along +Z with its centre at
(0, 3.4, 0). The code keeps the needle (animated, a box at z 0.095 to 0.145 turned about Z), so nothing inside radius 1.0 of the
face centre rises past z 0.09 (asserted). The post is the same radius as the code's (0.2) and rises to 3.0.

Class `detail` (1,500 tris, 1 draw) for the base and both shells; one enamel draw with COLOR_0 vertex colour. Copper is the
palette copper, never brass. No lights.

  blender -b --threads 2 --python-exit-code 1 -P sketches/core-loop/tools/blender/park/contraptions/gauge.py [-- --out-dir DIR] [--count-only]
"""
import math
from pathlib import Path
import sys

sys.path.insert(0, str(Path(__file__).resolve().parent))
import _park as pk

T = pk.TONES
FACE = (0.0, 3.4)
SWEEP = 2.1
REDLINE_FROM = 0.72
MAJORS = 13


def phi(g):
    return -SWEEP + 2 * SWEEP * g


def tick(s, g, r0, r1, w, z1, color):
    a = phi(g)
    rm = (r0 + r1) / 2
    pk.bar_xy(s, (FACE[0] + rm * math.sin(a), FACE[1] + rm * math.cos(a)), -a, r1 - r0, w, 0.03, z1, color)


def base(s):
    s.box((1.5, 0.5, 1.1), (0, 0.25, 0), T["concrete"])
    for y in (0.17, 0.34):
        s.box((1.53, 0.035, 1.13), (0, y, 0), T["concrete_dk"])
    pk.frustum(s, 0.2, 0.2, 0.5, 2.4, 8, T["iron"])
    pk.frustum(s, 0.3, 0.3, 0.55, 0.75, 8, T["copper"])
    s.box((0.5, 1.0, 0.45), (0, 2.7, -0.35), T["iron_hi"])
    pk.disc_z(s, 0, 1.2, -0.6, -0.12, 20, T["iron"], at=FACE)
    pk.disc_z(s, 1.06, 1.32, -0.12, 0.12, 24, T["copper"], at=FACE)
    pk.disc_z(s, 0, 1.06, -0.12, 0.07, 24, T["sand"], at=FACE)
    for k in range(MAJORS):
        g = k / (MAJORS - 1)
        hot = g >= REDLINE_FROM
        tick(s, g, 0.72, 0.96, 0.07 if hot else 0.055, 0.085, T["oxide"] if hot else T["charcoal"])
    pk.disc_z(s, 0, 0.12, 0.07, 0.085, 10, T["copper"], at=FACE)


def detail1(s):
    for k in range(12):
        a = math.tau * (k + 0.5) / 12
        pk.hexstud(s, (FACE[0] + 1.19 * math.cos(a), FACE[1] + 1.19 * math.sin(a), 0.12), (0, 0, 1), 0.05, 0.05, T["copper_dk"])
    for k in range(8):
        a = math.tau * k / 8
        pk.hexstud(s, (FACE[0] + 0.95 * math.cos(a), FACE[1] + 0.95 * math.sin(a), -0.6), (0, 0, -1), 0.05, 0.05, T["iron_hi"])
    for sx in (-1, 1):
        for sz in (-1, 1):
            s.box((0.15, 0.02, 0.15), (sx * 0.6, 0.51, sz * 0.4), T["iron_hi"])
            pk.hexstud(s, (sx * 0.6, 0.52, sz * 0.4), (0, 1, 0), 0.045, 0.07, T["iron"])
    for sx in (-1, 1):
        s.box((0.1, 0.1, 0.012), (sx * 0.45, 0.25, 0.556), T["charcoal"])
    for y in (1.2, 2.2):
        pk.frustum(s, 0.24, 0.24, y, y + 0.05, 8, T["iron_hi"])


def detail2(s):
    for k in range(MAJORS - 1):
        g = (k + 0.5) / (MAJORS - 1)
        tick(s, g, 0.84, 0.96, 0.035, 0.08, T["oxide"] if g >= REDLINE_FROM else T["charcoal"])
    for k in range(24):
        a = math.tau * k / 24
        pk.hexstud(s, (FACE[0] + 1.1 * math.cos(a), FACE[1] + 1.1 * math.sin(a), 0.12), (0, 0, 1), 0.028, 0.03, T["copper_dk"])
    s.box((0.3, 0.4, 0.03), (0, 1.6, 0.215), T["copper"])
    for sx in (-1, 1):
        for sy in (-1, 1):
            pk.hexstud(s, (sx * 0.1, 1.6 + sy * 0.15, 0.23), (0, 0, 1), 0.022, 0.02, T["copper_dk"])
    pk.tube(s, (0, 2.25, -0.25), (0, 0.6, -0.3), 0.045, 0.045, 6, T["iron_hi"])
    pk.tube(s, (0, 0.6, -0.3), (0, 0.45, -0.3), 0.07, 0.07, 6, T["copper"])
    pk.tube(s, (0, 2.2, -0.05), (0, 1.95, -0.05), 0.04, 0.04, 6, T["copper"])


def check_base(s):
    lo, hi = pk.bounds(s)
    assert abs(lo[1]) < 0.05 and 4.5 < hi[1] < 4.9 and abs((lo[0] + hi[0]) / 2) < 0.1, ("gauge bounds", lo, hi)
    for x, y, z in s.verts:
        if math.hypot(x - FACE[0], y - FACE[1]) < 1.0:
            assert z <= 0.09 + 1e-6, ("something rises into the needle's reach", (x, y, z))


def main():
    args = pk.options()
    base_s = pk.build("gauge", base, "detail")
    check_base(base_s)
    for name, fn in (("gauge_detail1", detail1), ("gauge_detail2", detail2)):
        pk.inside(pk.build(name, fn, "detail"), [base_s])
    pk.export("gauge", base, "detail", args.out_dir, args.count_only, check_base)
    pk.export("gauge_detail1", detail1, "detail", args.out_dir, args.count_only)
    pk.export("gauge_detail2", detail2, "detail", args.out_dir, args.count_only)


if __name__ == "__main__":
    main()
