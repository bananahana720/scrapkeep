"""Headless recipe for the trebuchet skin: trebuchet.glb (the frame), trebuchet_arm.glb (the throwing arm), trebuchet_detail1.glb
and trebuchet_detail2.glb (frame shells) (KC9, PARK.md section 4, recipe `trebuchet`; the launcher row's style `trebuchet`).

A Gorge-era dam trebuchet in Southwest salvage: two dark-iron girder towers on poured concrete footings with raked rear legs and
a ground sill, a copper axle through the tops, and an iron arm with a concrete counterweight block in copper straps and a copper
sling cradle at the throwing end. The frame takes the code posts' place (two 1 x 12 x 1 boxes at mouth - aim * 6, side +-3.0,
y -1 to 11, src/world/contraptions.gd:470-480); the arm takes the code arm (20 m, pivot at mouth - aim * 6 + UP * 10.5), which the
code still poses each step (`_launcher_pose` turns it about the side axis, -0.9 to 0.7 rad). The arm's -Z end is the throwing end.

Origin at the launcher's mouth point (the ground is y -1.0), +Y up, +Z the aim; the code turns the node about Y to the row's
aim. The arm GLB's origin is the pivot (the axle), the arm lies along Z from -10 to +10, the counterweight at +Z. Nothing in
the frame stands in the arm's swing round the pivot (0, 10.5, -6): no frame vertex within 1.4 m of the arm's plane lies
between 1.4 and 10.3 m from the pivot (asserted); the sill and the rear legs' feet stay under y 0.5, the axle and the bearings
sit at the pivot. The code's amber ring (radius 3.5, y -0.8) stays code-drawn: the footings stand at z -6, beyond it.
Class `landform` for the frame, `detail` for the arm and the shells. One enamel draw each.

  blender -b --threads 2 --python-exit-code 1 -P sketches/core-loop/tools/blender/park/contraptions/trebuchet.py [-- --out-dir DIR] [--count-only]
"""
import math
from pathlib import Path
import sys

sys.path.insert(0, str(Path(__file__).resolve().parent))
import _park as pk

T = pk.TONES
GROUND = -1.0
PIVOT = (0.0, 10.5, -6.0)
POST_X = 3.0
POST_Z = -6.0
POST_TOP = 11.0
FOOT_Z = -11.4


def leg_at(x, y):
    """The rear leg's centre line at height y (it runs from (x, 9.6, POST_Z - 0.4) to (1.08 x, GROUND + 0.9, FOOT_Z))."""
    t = (9.6 - y) / (9.6 - (GROUND + 0.9))
    return (x * (1 + 0.08 * t), y, POST_Z - 0.4 + (FOOT_Z - (POST_Z - 0.4)) * t)


def base(s):
    for sx in (-1, 1):
        x = sx * POST_X
        s.box((1.8, 0.9, 1.8), (x, GROUND + 0.45, POST_Z), T["concrete"])
        s.box((1.84, 0.04, 1.84), (x, GROUND + 0.3, POST_Z), T["concrete_dk"])
        s.box((1.4, 0.9, 1.4), (x * 1.08, GROUND + 0.45, FOOT_Z), T["concrete"])
        pk.strut(s, (x, GROUND + 0.9, POST_Z), (x, POST_TOP, POST_Z), 1.1, 1.1, T["iron"])
        s.box((1.4, 0.3, 1.4), (x, POST_TOP + 0.15, POST_Z), T["copper"])
        pk.strut(s, (x, 9.6, POST_Z - 0.4), (x * 1.08, GROUND + 0.9, FOOT_Z), 0.7, 0.7, T["iron_hi"])
        pk.strut(s, (x, 3.2, POST_Z - 0.5), (x * 1.03, 3.2, POST_Z - 3.2), 0.35, 0.35, T["iron"])
        s.box((1.5, 1.5, 1.5), (x, 10.5, POST_Z), T["iron_hi"])
        s.box((1.6, 1.6, 1.6), (x, GROUND + 1.4, POST_Z), T["concrete"])
        s.box((1.64, 0.04, 1.64), (x, GROUND + 1.5, POST_Z), T["concrete_dk"])
        ys = (2.0, 4.5, 7.0)
        for y in ys:
            pk.strut(s, (x, y, POST_Z - 0.4), leg_at(x, y), 0.28, 0.28, T["iron"])
        for y0, y1 in zip(ys, ys[1:] + (9.4,)):
            pk.strut(s, (x, y0, POST_Z - 0.4), leg_at(x, y1), 0.22, 0.22, T["iron_hi"])
    s.box((7.2, 0.5, 0.8), (0, GROUND + 0.7, FOOT_Z), T["concrete_lt"])
    s.box((6.2, 0.5, 0.9), (0, GROUND + 0.7, POST_Z), T["concrete_lt"])
    pk.tube(s, (-3.7, PIVOT[1], PIVOT[2]), (3.7, PIVOT[1], PIVOT[2]), 0.3, 0.3, 10, T["copper"])
    for sx in (-1, 1):
        pk.tube(s, (sx * 3.0 - 0.91, GROUND + 0.75, POST_Z), (sx * 3.0 + 0.91, GROUND + 0.75, POST_Z), 0.03, 0.03, 4, T["concrete_dk"])


def arm(s):
    pk.strut(s, (0, 0, -10.0), (0, 0, 6.5), 0.6, 0.7, T["iron"])
    pk.tube(s, (-0.8, 0, 0), (0.8, 0, 0), 0.55, 0.55, 10, T["copper"])
    for z in (-1.5, 1.5):
        s.box((0.74, 0.9, 0.3), (0, 0, z), T["iron_hi"])
    s.box((2.0, 2.0, 3.6), (0, -0.55, 8.2), T["concrete"])
    for y in (-0.9, -0.1):
        s.box((2.04, 0.05, 3.64), (0, y - 0.1, 8.2), T["concrete_dk"])
    for z in (6.7, 9.7):
        s.box((2.1, 2.1, 0.22), (0, -0.55, z), T["copper"])
    s.box((1.4, 0.18, 1.6), (0, -0.52, -9.0), T["copper"])
    for sx in (-1, 1):
        s.box((0.14, 0.7, 1.6), (sx * 0.68, -0.2, -9.0), T["copper_dk"])
    pk.tube(s, (0, -0.1, -10.0), (0, -0.5, -10.0), 0.12, 0.12, 6, T["copper"])
    pk.strut(s, (0, 0.3, -1.0), (0, 1.1, -1.0), 0.3, 0.3, T["iron_hi"])
    pk.tube(s, (0, 1.1, -1.0), (0, 0.35, -9.8), 0.05, 0.05, 6, T["copper_dk"])
    pk.tube(s, (0, 1.1, -1.0), (0, 0.35, 6.4), 0.05, 0.05, 6, T["copper_dk"])
    for z in (-6.5, -3.5, 3.0, 5.0):
        s.box((0.74, 0.8, 0.14), (0, 0, z), T["iron_hi"])


def detail1(s):
    for sx in (-1, 1):
        x = sx * POST_X
        for row in range(10):
            y = 0.2 + row * 1.0
            pk.hexstud(s, (x - sx * 0.2, y, POST_Z + 0.55), (0, 0, 1), 0.07, 0.06, T["iron_hi"])
            pk.hexstud(s, (x + sx * 0.55, y, POST_Z - 0.2), (sx, 0, 0), 0.07, 0.06, T["iron_hi"])
        for dx in (-0.45, 0.45):
            for dz in (-0.45, 0.45):
                pk.hexstud(s, (x + dx, POST_TOP + 0.3, POST_Z + dz), (0, 1, 0), 0.08, 0.06, T["copper_dk"])
        for dz in (-0.5, 0.5):
            pk.hexstud(s, (x + sx * 0.75, 10.5, POST_Z + dz), (sx, 0, 0), 0.09, 0.08, T["iron"])
        for dx in (-0.6, 0.6):
            for dz in (-0.6, 0.6):
                pk.hexstud(s, (x + dx, GROUND + 0.9, POST_Z + dz), (0, 1, 0), 0.07, 0.07, T["iron"])
        s.box((1.0, 0.6, 0.06), (sx * 3.2, 9.4, POST_Z - 0.6), T["iron_hi"])


def detail2(s):
    for sx in (-1, 1):
        x = sx * POST_X
        for k in range(8):
            s.box((0.7, 0.07, 0.07), (x, 1.2 + k * 1.1, POST_Z + 0.62), T["iron_hi"])
        s.box((0.5, 0.35, 0.04), (x, 5.2, POST_Z + 0.57), T["copper"])
        for dx in (-0.2, 0.2):
            pk.hexstud(s, (x + dx, 5.2, POST_Z + 0.6), (0, 0, 1), 0.022, 0.02, T["copper_dk"])
        pk.tube(s, (x * 1.08, 0.0, FOOT_Z), (x * 1.08, 0.5, FOOT_Z), 0.1, 0.1, 6, T["iron"])
        for dz in (-0.5, 0.5):
            pk.hexstud(s, (x * 1.08 + dz, GROUND + 0.9, FOOT_Z), (0, 1, 0), 0.08, 0.07, T["iron"])
        pk.tube(s, (x, 10.9, POST_Z + 0.6), (x, 10.9, POST_Z + 0.85), 0.14, 0.1, 6, T["copper"])
        for k in range(4):
            s.box((0.04, 1.2, 0.04), (x + (k - 1.5) * 0.28, GROUND + 0.7 + 0.0, POST_Z + 0.92), T["rust"])
    for k in range(6):
        s.box((0.1, 0.1, 0.02), (-2.5 + k, GROUND + 0.7, FOOT_Z + 0.41), T["charcoal"])


def check_frame(s):
    lo, hi = pk.bounds(s)
    assert abs(lo[1] - GROUND) < 0.06 and abs(hi[1] - POST_TOP) < 0.4 and 6.0 <= hi[0] - lo[0] <= 8.0, ("frame bounds", lo, hi)
    for x, y, z in s.verts:
        d = math.hypot(y - PIVOT[1], z - PIVOT[2])
        assert not (abs(x) < 1.4 and 1.4 < d < 10.3), ("frame stands in the arm's swing", (x, y, z), d)
        assert not (z > -4.5 and y < -0.45), ("frame stands in the launch ring", (x, y, z))


def check_arm(s):
    lo, hi = pk.bounds(s)
    assert abs(lo[2] + 10.0) < 0.3 and abs(hi[2] - 10.0) < 0.3 and hi[0] - lo[0] < 3.0 and hi[1] - lo[1] < 3.0, ("arm bounds", lo, hi)
    assert abs(lo[0] + hi[0]) < 0.1, "arm is not centred in x"
    for x, y, z in s.verts:
        assert abs(x) < POST_X - 0.55 - 0.3, ("arm too wide for the towers", x)


def main():
    args = pk.options()
    frame_s = pk.build("trebuchet", base, "landform")
    check_frame(frame_s)
    arm_s = pk.build("trebuchet_arm", arm, "detail")
    check_arm(arm_s)
    for name, fn in (("trebuchet_detail1", detail1), ("trebuchet_detail2", detail2)):
        pk.inside(pk.build(name, fn, "detail"), [frame_s])
    pk.export("trebuchet", base, "landform", args.out_dir, args.count_only, check_frame)
    pk.export("trebuchet_arm", arm, "detail", args.out_dir, args.count_only, check_arm)
    pk.export("trebuchet_detail1", detail1, "detail", args.out_dir, args.count_only)
    pk.export("trebuchet_detail2", detail2, "detail", args.out_dir, args.count_only)


if __name__ == "__main__":
    main()
