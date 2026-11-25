"""Headless recipe for the geyser vent skin: geyser_vent.glb, geyser_vent_detail1.glb, geyser_vent_detail2.glb (KC9, PARK.md
section 4, recipe `geyser_vent`).

A Gorge-era pressure vent in Southwest salvage: a collar of dam-era concrete board rings (form-board joints) around the steam
mouth, a dark-iron lip with a grate of flat iron bars across the opening, a copper strap band, sandstone chunks heaped against
the collar's foot, desert-varnish streaks and a dark-iron relief stack 2.6 m tall on the back side, which stands outside the steam column (radius 1.6 at the base, 2.4 at 10 m). The steam column is the code's (the
animated `arm`, radius 1.6 at its base, src/world/contraptions.gd:454), so the mouth stays open: nothing above the grate rises
into radius 1.5.

Origin at the launcher's mouth point (the ground is y -1.0 there, `ground.call(x, z, 1.0)`), +Y up, +Z the aim (the vent is a
ring, so only the relief stack faces -Z, away from the aim). The collar stays inside the code ring's inner radius 2.9 and under
the ring's tube (y -1.1 to -0.5 at r 2.9 to 3.5), so the amber ring stays the readable signal. Class `detail`, one enamel draw.

  blender -b --threads 2 --python-exit-code 1 -P sketches/core-loop/tools/blender/park/contraptions/geyser_vent.py [-- --out-dir DIR] [--count-only]
"""
import math
from pathlib import Path
import sys

sys.path.insert(0, str(Path(__file__).resolve().parent))
import _park as pk

T = pk.TONES
MOUTH_R = 1.75
COLLAR_R = 2.8
GROUND = -1.0
LIP_TOP = -0.2
STACK_TOP = 2.6


def base(s):
    y = GROUND
    for k, h in enumerate((0.2, 0.2, 0.15)):
        pk.ring_y(s, MOUTH_R, COLLAR_R - 0.04 * k, y, y + h, 20, T["concrete"] if k != 1 else T["concrete_lt"])
        y += h
        if k < 2:
            pk.ring_y(s, MOUTH_R, COLLAR_R - 0.04 * k + 0.012, y - 0.012, y + 0.012, 20, T["concrete_dk"])
    pk.ring_y(s, MOUTH_R, 2.3, y, LIP_TOP, 20, T["iron"])
    pk.ring_y(s, 2.38, 2.8, -0.78, -0.66, 20, T["copper"])
    for i in range(-3, 4):
        x = i * 0.46
        half = math.sqrt(max(MOUTH_R ** 2 - x ** 2, 0.0)) - 0.05
        pk.strut(s, (x, -0.9, -half), (x, -0.9, half), 0.12, 0.1, T["iron_hi"])
    for z in (-0.8, 0.0, 0.8):
        half = math.sqrt(max(MOUTH_R ** 2 - z ** 2, 0.0)) - 0.05
        pk.strut(s, (-half, -0.95, z), (half, -0.95, z), 0.1, 0.08, T["iron"])
    for k in range(9):
        a = math.tau * k / 9 + 0.3
        r = 2.35 + 0.05 * (k % 3)
        h = 0.35 + 0.1 * (k % 4)
        pk.frustum(s, 0.32, 0.2, GROUND, GROUND + h, 5, T["sand"] if k % 3 else T["varnish"], at=(r * math.cos(a), r * math.sin(a)))
    pk.tube(s, (0, GROUND, -2.3), (0, STACK_TOP - 0.12, -2.3), 0.26, 0.22, 8, T["iron"])
    pk.tube(s, (0, STACK_TOP - 0.12, -2.3), (0, STACK_TOP, -2.3), 0.3, 0.3, 8, T["copper"])
    pk.tube(s, (0, -0.4, -2.3), (0, -0.4, -1.9), 0.1, 0.1, 6, T["copper"])


def detail1(s):
    for k in range(16):
        a = math.tau * (k + 0.5) / 16
        pk.hexstud(s, (2.0 * math.cos(a), LIP_TOP, 2.0 * math.sin(a)), (0, 1, 0), 0.07, 0.06, T["iron_hi"])
    for k in range(8):
        a = math.tau * k / 8 + 0.2
        x, z = (COLLAR_R - 0.02) * math.cos(a), (COLLAR_R - 0.02) * math.sin(a)
        pk.tube(s, (x, GROUND, z), (x, -0.45, z), 0.03, 0.03, 4, T["concrete_dk"])
    for k in range(6):
        a = math.tau * k / 6
        pk.hexstud(s, (1.62 * math.cos(a), -0.84, 1.62 * math.sin(a)), (0, 1, 0), 0.06, 0.05, T["iron"])
    for dx in (-0.25, 0.25):
        pk.hexstud(s, (dx, STACK_TOP, -2.3), (0, 1, 0), 0.06, 0.05, T["copper_dk"])


def detail2(s):
    for k in range(24):
        a = math.tau * k / 24
        pk.hexstud(s, ((2.8 - 0.02) * math.cos(a), -0.72, (2.8 - 0.02) * math.sin(a)), (math.cos(a), 0, math.sin(a)), 0.035, 0.04, T["copper_dk"])
    for k in range(7):
        a = math.tau * k / 7 + 0.5
        x, z = (COLLAR_R - 0.05) * math.cos(a), (COLLAR_R - 0.05) * math.sin(a)
        pk.tube(s, (x, -0.5, z), (x, -0.95, z), 0.07, 0.04, 4, T["varnish"])
    for k in range(5):
        a = math.tau * k / 5 + 0.7
        pk.frustum(s, 0.16, 0.1, -0.88, -0.78, 5, T["oxide"], at=(1.0 * math.cos(a), 1.0 * math.sin(a)))
    pk.ring_y(s, 0.21, 0.31, -0.62, -0.5, 8, T["iron_hi"], at=(0, -2.3))
    for dx in (-1, 1):
        pk.hexstud(s, (dx * 0.26, -0.5, -2.3), (0, 1, 0), 0.04, 0.05, T["copper_dk"])


def check_base(s):
    lo, hi = pk.bounds(s)
    rmax = max(math.hypot(x, z) for x, y, z in s.verts)
    assert abs(lo[1] - GROUND) < 0.05 and hi[1] <= 3.0, ("vent height", lo, hi)
    assert rmax <= 2.9, ("vent leaves the ring's inner radius", rmax)
    for x, y, z in s.verts:
        assert not (math.hypot(x, z) < 1.5 and y > -0.7), ("the steam mouth is capped", (x, y, z))


def main():
    args = pk.options()
    base_s = pk.build("geyser_vent", base, "detail")
    check_base(base_s)
    for name, fn in (("geyser_vent_detail1", detail1), ("geyser_vent_detail2", detail2)):
        pk.inside(pk.build(name, fn, "detail"), [base_s])
    pk.export("geyser_vent", base, "detail", args.out_dir, args.count_only, check_base)
    pk.export("geyser_vent_detail1", detail1, "detail", args.out_dir, args.count_only)
    pk.export("geyser_vent_detail2", detail2, "detail", args.out_dir, args.count_only)


if __name__ == "__main__":
    main()
