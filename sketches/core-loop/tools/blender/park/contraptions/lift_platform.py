"""Headless recipe for the lift platform skin: lift_platform.glb, lift_platform_detail1.glb, lift_platform_detail2.glb (KC9,
PARK.md section 4, recipe `lift_platform`).

A dam-era service lift: a round cap of copper and charcoal stripe sectors (the stripes are the lift's "stand here, this
rides" read, as the code's striped plate) round a copper hub, falling 1 in 6 to a dark-iron rim. The drum under the cap,
flush with the rim, is the code's (contraptions.gd _build_lift; its length is the row's `rise`), so nothing of the skin
hangs under the cap.

Purpose note (wave 37 lift-drum, the art rule's three lines):
  For: carrying the ball up the row's `rise`, or throwing it when it fires.
  The player must read: a striped cap that rides, on a solid banded copper column that is a wall while raised.
  Changed: the thin piston became the code's flush drum; the cap falls 1 in 6 to its rim; the collar, ribs, hoses and oxide
  streaks that hung under the deck went, since they would sit inside the drum. No board under docs/art/reference draws this
  column (the looping-workers board's maintenance lift is a cage on a rail beside a wall); only that board's palette strip,
  copper b77843 and charcoal 242a28, backs the drum's colours.

Origin at the plate's centre (the body's origin). The skin follows the plate collider's outline, contraptions.gd LIFT_PROFILE
(FLAT and RIM_Y below; check_base fails a vertex outside it): the deck TOP is the collider top, y +0.5, flat to
FLAT, with nothing above the deck line in the base (the shells stand 0.04 proud at most); radius 4.5, which the code scales to
the row's `radius` in X and Z. +Y up; the lift has no aim, so +Z is free. Class `detail`, one enamel draw.

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
# The cap's outline (radius, height), the same numbers as contraptions.gd LIFT_PROFILE, which builds the collider and the
# code's drum from them (wave 37 lift-drum): the deck is flat to FLAT and falls 1 in 6 to the rim at (R, RIM_Y). The drum is
# the code's, radius R from RIM_Y down (its length is the row's rise, and its charcoal collar is the rim's side), so the skin
# is the cap alone: nothing of it hangs under RIM_Y or reaches past R.
FLAT = 2.7
RIM_Y = 0.2
SLOPE = (TOP - RIM_Y) / (R - FLAT)
assert abs(SLOPE - 1.0 / 6.0) < 1e-9, SLOPE


def deck_y(r):
    """The deck top at radius r: flat to FLAT, then the 1 in 6 bevel to the rim."""
    return TOP if r <= FLAT else TOP - (r - FLAT) * SLOPE


def bevel_normal(a):
    n = (SLOPE * math.cos(a), 1.0, SLOPE * math.sin(a))
    m = math.sqrt(sum(c * c for c in n))
    return tuple(c / m for c in n)


def lathe(s, outline, n, color, arc=None):
    """pk.ring_y with any closed convex outline of (radius, y) points in place of its rectangle."""
    k_n = len(outline)
    closed = arc is None
    a0, a1 = (0.0, math.tau) if closed else arc
    steps = n if closed else n + 1
    angles = [a0 + (a1 - a0) * i / n for i in range(steps)]
    verts = [(r * math.cos(t), y, r * math.sin(t)) for t in angles for r, y in outline]
    faces = []
    for i in range(steps if closed else steps - 1):
        j = (i + 1) % steps
        for k in range(k_n):
            m = (k + 1) % k_n
            faces.append((i * k_n + k, i * k_n + m, j * k_n + m, j * k_n + k))
    if not closed:
        faces.append(tuple(reversed(range(k_n))))
        last = (steps - 1) * k_n
        faces.append(tuple(last + k for k in range(k_n)))
    s.add(verts, faces, color)


def base(s):
    for k in range(STRIPES):                                                     # stripes over the deck and its bevel
        a0 = math.tau * k / STRIPES
        a1 = math.tau * (k + 1) / STRIPES
        lathe(s, [(1.62, 0.1), (4.2, 0.1), (4.2, deck_y(4.2)), (FLAT, TOP), (1.62, TOP)], 3,
              T["copper"] if k % 2 == 0 else T["charcoal"], arc=(a0, a1))
    lathe(s, [(4.2, RIM_Y), (R, RIM_Y), (4.2, deck_y(4.2))], 24, T["iron"])     # the rim's bevel ring
    pk.frustum(s, 1.6, 1.6, 0.1, TOP, 16, T["copper_dk"])                        # hub


def detail1(s):
    for k in range(32):
        a = math.tau * (k + 0.5) / 32
        pk.hexstud(s, (4.38 * math.cos(a), deck_y(4.38), 4.38 * math.sin(a)), bevel_normal(a), 0.09, 0.04, T["iron_hi"])
    for k in range(8):
        a = math.tau * k / 8
        pk.hexstud(s, (1.2 * math.cos(a), TOP, 1.2 * math.sin(a)), (0, 1, 0), 0.08, 0.04, T["copper"])
    for k in range(STRIPES):                                                     # stripe seam studs
        a = math.tau * k / STRIPES
        pk.hexstud(s, (2.0 * math.cos(a), TOP, 2.0 * math.sin(a)), (0, 1, 0), 0.05, 0.03, T["charcoal"])


def detail2(s):
    for ring, count, radius in ((0, 24, 2.8), (1, 24, 3.7)):                     # anti-slip studs on the stripes
        for k in range(count):
            a = math.tau * (k + 0.5 * ring) / count
            pk.hexstud(s, (radius * math.cos(a), deck_y(radius), radius * math.sin(a)), bevel_normal(a) if radius > FLAT else (0, 1, 0),
                       0.05, 0.03, T["iron"] if (k + ring) % 2 else T["copper_dk"])


def check_base(s):
    lo, hi = pk.bounds(s)
    assert abs(hi[1] - TOP) < 0.02, ("deck top is not the collider top", hi[1])
    assert abs((hi[0] - lo[0]) - 2 * R) < 0.3 and abs((hi[2] - lo[2]) - 2 * R) < 0.3, ("lift plan", lo, hi)
    assert lo[1] >= 0.1 - 1e-6, ("the skin hangs under the cap, into the drum", lo[1])
    # Nothing outside the outline: over the deck line, or past the rim.
    out = [v for v in s.verts if v[1] > deck_y(math.hypot(v[0], v[2])) + 0.002 or math.hypot(v[0], v[2]) > R + 0.002]
    assert not out, ("the skin leaves the collider outline", len(out), out[:3])


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
