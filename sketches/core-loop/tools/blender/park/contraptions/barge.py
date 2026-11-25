"""Headless recipe for the barge skin: barge.glb, barge_detail1.glb, barge_detail2.glb (KC9, PARK.md section 4, recipe `barge`).

A dam-era concrete lighter in Southwest salvage: an open-topped pontoon of poured concrete boards (form-board joints, desert varnish
and oxide streaks), a dark-iron rim with copper cleats at the corners, a copper strake round the hull, charcoal tyre fenders hung
on the sides and two dark-iron thruster shrouds on the -X end. It takes the deck node's place (src/world/contraptions.gd
`_build_barge`): the deck node leans with the ball's weight, the collider box (14 x 1.2 x 14 in the gorge rows, `size` in the
row) stays the code's and the ball rolls on its top.

Origin at the collider's centre, +Y up, plan a rounded square 15 m across (the code scales it to the row's `size` in X and Z).
The code puts this origin 0.4 under the collider centre (`size.y * 0.5 - 1.0`), so the FLOOR is flat at y +1.0 here and the
collider top is the floor. The rim stands to y 1.95 with no collider (the ball can clip it, as the wave 12 barge). The hull
hangs to -3.6. The barge has no aim; the thrusters face -X (the lane runs along the row's a to b). Class `landform` for the
base, `detail` for the shells. One enamel draw each.

  blender -b --threads 2 --python-exit-code 1 -P sketches/core-loop/tools/blender/park/contraptions/barge.py [-- --out-dir DIR] [--count-only]
"""
import math
from pathlib import Path
import sys

sys.path.insert(0, str(Path(__file__).resolve().parent))
import _park as pk

T = pk.TONES
SEG = 4
SEAM = 0.001
FLOOR = 1.0
HULL = [(3.4, 2.2, -3.6, "concrete_dk"), (5.4, 2.6, -3.2, "concrete"), (6.6, 2.8, -2.2, "concrete_lt"),
        (7.2, 2.8, -0.8, "concrete"), (7.42, 2.8, 0.4, "concrete_lt"), (7.5, 2.8, 1.35, "concrete")]
RIM = [(7.62, 2.85, 1.45), (7.62, 2.85, 1.95), (7.05, 2.3, 1.95), (7.05, 2.3, 1.8)]
WALL = (7.05, 2.3, 1.8, FLOOR)


def shell(s):
    rows = [((h, r, y), t) for h, r, y, t in HULL]
    rows.append(((HULL[-1][0], HULL[-1][1], HULL[-1][2] + SEAM), "iron"))
    rows += [(row, "iron") for row in RIM]
    h, r, y1, y0 = WALL
    rows += [((h, r, y1 - SEAM), "concrete_lt"), ((h, r, y0 + SEAM), "concrete_lt"), ((h, r, y0), "deck")]
    rings = [pk.plan(*row, seg=SEG) for row, _ in rows]
    n = len(rings[0])
    verts = [v for ring in rings for v in ring]
    colors = [pk.TONES[t] for _, t in rows for _ in range(n)]
    faces = [(k * n + i, k * n + (i + 1) % n, (k + 1) * n + (i + 1) % n, (k + 1) * n + i) for k in range(len(rings) - 1) for i in range(n)]
    faces += [tuple(reversed(range(n))), tuple(range((len(rings) - 1) * n, len(rings) * n))]
    s.add(verts, faces, colors=colors)


def band(s, h, r, y0, y1, out, color):
    rings = [pk.plan(h, r, y0, SEG), pk.plan(h, r, y0, SEG, out), pk.plan(h, r, y1, SEG, out), pk.plan(h, r, y1, SEG)]
    n = len(rings[0])
    verts = [v for ring in rings for v in ring]
    faces = [(k * n + i, k * n + (i + 1) % n, (k + 1) * n + (i + 1) % n, (k + 1) * n + i) for k in range(3) for i in range(n)]
    s.add(verts, faces, color)


def perimeter(h, r, y, count, start=0.0):
    """Points evenly spaced by arc length on the rounded square, each with its outward normal in XZ."""
    c = h - r
    straight, arc = 2 * c, math.pi * r / 2
    total = 4 * (straight + arc)
    out = []
    for k in range(count):
        d = (start + k * total / count) % total
        side, d = int(d // (straight + arc)), d % (straight + arc)
        ang = side * math.pi / 2
        nrm = (math.cos(ang), math.sin(ang))
        tan = (-nrm[1], nrm[0])
        if d < straight:
            p = (nrm[0] * h + tan[0] * (d - c), nrm[1] * h + tan[1] * (d - c))
            nn = nrm
        else:
            a = ang + (d - straight) / r
            cc = (nrm[0] * c + tan[0] * c, nrm[1] * c + tan[1] * c)
            nn = (math.cos(a), math.sin(a))
            p = (cc[0] + nn[0] * r, cc[1] + nn[1] * r)
        out.append(((p[0], y, p[1]), (nn[0], 0.0, nn[1])))
    return out


def hull_at(y):
    """The hull's half extent and corner radius at height y, by straight lines between the HULL rings."""
    for (h0, r0, y0, _), (h1, r1, y1, _) in zip(HULL, HULL[1:]):
        if y0 <= y <= y1:
            t = (y - y0) / (y1 - y0)
            return h0 + (h1 - h0) * t - 0.01, r0 + (r1 - r0) * t
    raise ValueError(y)


def base(s):
    shell(s)
    band(s, 7.36, HULL[3][1], -0.25, 0.0, 0.07, T["copper"])
    for y in (-2.6, -1.5, -0.4):
        h, r = hull_at(y)
        band(s, h, r, y, y + 0.05, 0.05, T["concrete_dk"])
    for sx, sz in ((1, 1), (-1, 1), (1, -1), (-1, -1)):
        pk.frustum(s, 0.34, 0.2, 1.95, 2.15, 6, T["copper"], at=(sx * 6.1, sz * 6.1))
        pk.frustum(s, 0.4, 0.4, 1.95, 2.0, 6, T["iron_hi"], at=(sx * 6.1, sz * 6.1))
    for z, y in ((-2.3, -0.55), (2.3, -0.55)):
        pk.tube(s, (-6.95, y, z), (-7.72, y, z), 0.74, 0.74, 12, T["iron"])
        pk.tube(s, (-7.72, y, z), (-7.78, y, z), 0.54, 0.54, 12, T["charcoal"])
    for side in (-1, 1):
        for x in (-4.6, 0.0, 4.6):
            pk.tube(s, (x - 0.35, 0.35, side * 7.35), (x + 0.35, 0.35, side * 7.35), 0.42, 0.42, 10, T["charcoal"])
    for z in (-4.6, 0.0, 4.6):
        pk.tube(s, (7.35, 0.35, z - 0.35), (7.35, 0.35, z + 0.35), 0.42, 0.42, 10, T["charcoal"])


def detail1(s):
    for p, nrm in perimeter(7.62, 2.85, 1.72, 30, 0.4):
        pk.hexstud(s, (p[0] - nrm[0] * 0.01, p[1], p[2] - nrm[2] * 0.01), nrm, 0.06, 0.05, T["iron_hi"])
    for p, nrm in perimeter(7.5, 2.8, 0.9, 16, 0.0):
        s.box((0.1, 0.1, 0.1), (p[0] + nrm[0] * 0.0, p[1], p[2] + nrm[2] * 0.0), T["charcoal"])
    for sx, sz in ((1, 1), (-1, 1), (1, -1), (-1, -1)):
        for k in range(4):
            a = math.tau * k / 4 + math.pi / 4
            pk.hexstud(s, (sx * 6.1 + 0.26 * math.cos(a), 1.99, sz * 6.1 + 0.26 * math.sin(a)), (0, 1, 0), 0.05, 0.04, T["copper_dk"])
    for z in (-2.3, 2.3):
        for k in range(6):
            a = math.tau * k / 6
            pk.hexstud(s, (-7.72, -0.55 + 0.64 * math.cos(a), z + 0.64 * math.sin(a)), (-1, 0, 0), 0.05, 0.04, T["iron_hi"])


def detail2(s):
    for k in range(-6, 7):
        s.box((0.04, 0.012, 11.6), (k * 1.0, FLOOR + 0.006, 0), T["concrete"])
    for sx, sz in ((1, 1), (-1, 1), (1, -1), (-1, -1)):
        s.box((0.9, 0.03, 0.9), (sx * 5.6, FLOOR + 0.015, sz * 5.6), T["copper"])
        for dx, dz in ((-0.3, -0.3), (0.3, 0.3)):
            pk.hexstud(s, (sx * 5.6 + dx, FLOOR + 0.03, sz * 5.6 + dz), (0, 1, 0), 0.05, 0.03, T["copper_dk"])
    for p, nrm in perimeter(7.5, 2.8, -1.2, 18, 0.9):
        pk.tube(s, (p[0] + nrm[0] * 0.03, p[1] + 1.4, p[2] + nrm[2] * 0.03), (p[0] + nrm[0] * 0.03, p[1], p[2] + nrm[2] * 0.03), 0.07, 0.04, 4, T["varnish"])
    for p, nrm in perimeter(7.5, 2.8, 0.2, 10, 2.1):
        s.box((0.5, 0.35, 0.05), (p[0] + nrm[0] * 0.02, p[1], p[2] + nrm[2] * 0.02), T["oxide"])
    for sx, sz in ((1, 1), (-1, 1), (1, -1), (-1, -1)):
        a = (sx * 6.1, 1.9, sz * 6.1)
        pk.tube(s, a, (sx * 6.9, 0.6, sz * 6.9), 0.05, 0.05, 6, T["iron_hi"])
    for p, nrm in perimeter(6.9, 2.2, FLOOR + 0.07, 8, 1.6):
        s.box((0.5, 0.14, 0.5), p, T["charcoal"])


def check_base(s):
    lo, hi = pk.bounds(s)
    assert abs(lo[1] + 3.6) < 0.2 and hi[1] <= 2.5 and 14.0 <= hi[0] - lo[0] <= 16.0 and 14.0 <= hi[2] - lo[2] <= 16.0, ("barge bounds", lo, hi)
    assert any(abs(y - FLOOR) < 0.01 and abs(x) > 5.0 and abs(z) > 5.0 for x, y, z in s.verts), "no flat floor at y 1.0"
    floor = [y for x, y, z in s.verts if abs(x) < 4.5 and abs(z) < 4.5 and y > 0.5]
    assert max(floor, default=FLOOR) <= FLOOR + 0.01, ("something stands on the floor in the base", max(floor))


def main():
    args = pk.options()
    base_s = pk.build("barge", base, "landform")
    check_base(base_s)
    for name, fn in (("barge_detail1", detail1), ("barge_detail2", detail2)):
        pk.inside(pk.build(name, fn, "detail"), [base_s])
    pk.export("barge", base, "landform", args.out_dir, args.count_only, check_base)
    pk.export("barge_detail1", detail1, "detail", args.out_dir, args.count_only)
    pk.export("barge_detail2", detail2, "detail", args.out_dir, args.count_only)


if __name__ == "__main__":
    main()
