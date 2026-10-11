"""Headless recipe for the lift platform skin: lift_platform.glb, lift_platform_detail1.glb, lift_platform_detail2.glb (KC9,
PARK.md section 4, recipe `lift_platform`).

A dam-era service lift: a round deck of concrete boards under copper and charcoal stripe sectors (the stripes are the lift's
"stand here, this rides" read, as the code's striped plate), a dark-iron rim, and an iron collar with eight ribs under the
deck where the copper-coloured piston goes. The piston stays the code's cylinder (its length is the row's `rise`), so the
collar closes over its top.

Origin at the plate's centre (the body's origin: the code plate is a 1.0 m cylinder centred there, contraptions.gd:365-372).
The deck TOP is the collider top, y +0.5, flat, with nothing above it in the base (the shells stand 0.04 proud at most); radius
4.5, which the code scales to the row's `radius` in X and Z. +Y up; the lift has no aim, so +Z is free. Class `detail`, one
enamel draw.

  blender -b --threads 2 --python-exit-code 1 -P sketches/core-loop/tools/blender/park/contraptions/lift_platform.py [-- --out-dir DIR] [--count-only]
"""
import math
from pathlib import Path
import sys

sys.path.insert(0, str(Path(__file__).resolve().parent))
import _park as pk

T = pk.TONES
R = 4.5
TOP = 0.5
STRIPES = 16


def base(s):
    pk.ring_y(s, 1.6, 4.25, -0.5, 0.1, 24, T["concrete"])                       # concrete core
    pk.ring_y(s, 1.6, 4.26, -0.12, -0.1, 24, T["concrete_dk"])                  # board joint
    for k in range(STRIPES):
        a0 = math.tau * k / STRIPES
        a1 = math.tau * (k + 1) / STRIPES
        pk.ring_y(s, 1.62, 4.2, 0.1, TOP, 3, T["copper"] if k % 2 == 0 else T["charcoal"], arc=(a0, a1))
    pk.ring_y(s, 4.25, R, -0.5, TOP, 24, T["iron"])                              # rim
    pk.ring_y(s, 4.25, R - 0.04, 0.12, 0.16, 24, T["iron_hi"])                   # rim lip line
    pk.frustum(s, 1.6, 1.6, 0.1, TOP, 16, T["copper_dk"])                        # hub
    pk.frustum(s, 1.7, 1.5, -1.2, -0.5, 12, T["iron"])                           # collar over the piston
    pk.frustum(s, 1.78, 1.78, -1.0, -0.88, 12, T["copper"])                      # gland ring
    for k in range(8):                                                           # ribs from collar to rim underside
        a = math.tau * k / 8 + math.pi / 8
        ca, sa = math.cos(a), math.sin(a)
        pk.strut(s, (1.6 * ca, -1.0, 1.6 * sa), (4.1 * ca, -0.5, 4.1 * sa), 0.3, 0.26, T["iron_hi"])


def detail1(s):
    for k in range(32):
        a = math.tau * (k + 0.5) / 32
        pk.hexstud(s, (4.38 * math.cos(a), TOP, 4.38 * math.sin(a)), (0, 1, 0), 0.09, 0.04, T["iron_hi"])
    for k in range(8):
        a = math.tau * k / 8
        pk.hexstud(s, (1.2 * math.cos(a), TOP, 1.2 * math.sin(a)), (0, 1, 0), 0.08, 0.04, T["copper"])
        pk.hexstud(s, (1.6 * math.cos(a + math.pi / 8), -0.6, 1.6 * math.sin(a + math.pi / 8)), (math.cos(a + math.pi / 8), 0, math.sin(a + math.pi / 8)), 0.07, 0.06, T["iron"])
    for k in range(STRIPES):                                                     # stripe seam studs
        a = math.tau * k / STRIPES
        pk.hexstud(s, (2.0 * math.cos(a), TOP, 2.0 * math.sin(a)), (0, 1, 0), 0.05, 0.03, T["charcoal"])


def detail2(s):
    for ring, count, radius in ((0, 24, 2.8), (1, 24, 3.7)):                     # anti-slip studs on the stripes
        for k in range(count):
            a = math.tau * (k + 0.5 * ring) / count
            pk.hexstud(s, (radius * math.cos(a), TOP, radius * math.sin(a)), (0, 1, 0), 0.05, 0.03,
                       T["iron"] if (k + ring) % 2 else T["copper_dk"])
    for k in range(4):                                                           # hydraulic hose looped down a rib
        a = math.tau * k / 4 + math.pi / 8 + 0.12
        ca, sa = math.cos(a), math.sin(a)
        pk.tube(s, (1.75 * ca, -0.9, 1.75 * sa), (2.6 * ca, -0.8, 2.6 * sa), 0.07, 0.07, 6, T["copper"])
        pk.tube(s, (2.6 * ca, -0.8, 2.6 * sa), (3.2 * ca, -0.45, 3.2 * sa), 0.07, 0.07, 6, T["copper_dk"])
    for k in range(6):                                                           # oxide streaks off the rim
        a = math.tau * k / 6 + 0.4
        pk.tube(s, (4.46 * math.cos(a), 0.3, 4.46 * math.sin(a)), (4.46 * math.cos(a), -0.45, 4.46 * math.sin(a)), 0.06, 0.03, 4, T["oxide"])
    pk.ring_y(s, 1.55, 1.72, -0.6, -0.5, 12, T["iron_hi"])                       # collar flange


def check_base(s):
    lo, hi = pk.bounds(s)
    assert abs(hi[1] - TOP) < 0.02, ("deck top is not the collider top", hi[1])
    assert abs((hi[0] - lo[0]) - 2 * R) < 0.3 and abs((hi[2] - lo[2]) - 2 * R) < 0.3, ("lift plan", lo, hi)
    assert lo[1] > -1.3, ("collar hangs too low", lo[1])


def main():
    args = pk.options()
    base_s = pk.build("lift_platform", base, "detail")
    check_base(base_s)
    for name, fn in (("lift_platform_detail1", detail1), ("lift_platform_detail2", detail2)):
        shell = pk.build(name, fn, "detail")
        pk.inside(shell, [base_s], 0.1)
        assert pk.bounds(shell)[1][1] <= TOP + 0.04 + 1e-6, "a shell stands more than 0.04 over the deck top"
    pk.export("lift_platform", base, "detail", args.out_dir, args.count_only, check_base)
    pk.export("lift_platform_detail1", detail1, "detail", args.out_dir, args.count_only)
    pk.export("lift_platform_detail2", detail2, "detail", args.out_dir, args.count_only)


if __name__ == "__main__":
    main()
