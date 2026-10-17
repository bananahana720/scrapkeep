"""Headless recipe for the sinkhole's lava channel half-pipe (placeholder burn-down unit F,
alpha-status/placeholders/BREAKDOWN.md): the lava_channel_1..21 rows of park_sinkhole.json, each a 51 to 60 m wash stamp
4 m deep and 28 m wide, take one GLB through the seat fit (park_recipes.gd, PARK-SEAT: a 58 m piece seats 43.5 to 87 m).

  lava_channel  a cooled lava channel: a black basalt floor with ropy pahoehoe folds and a hot seam glowing down its middle,
                walls banded basalt, red scoria and ash, a cinder rim. The ridden surface is the bake's own wash stamp
                (park_stamps.gd "wash": flat over the middle 40 percent of the width, curved walls, the ends opening over
                min(width, length / 4)), lifted LIFT over it so the liner never fights the terrain for a pixel, the lift easing
                in over the first and last EASE metres so the ball rolls on and off without a step. Seated, the stretch scales
                the open ends with the row exactly as the stamp does (both are a quarter of the length).
                Detail shells: basalt boulders and spatter cones along the rim with a dam-era survey stake and a kettle
                someone set on a vent to boil (detail1); glowing cracks on the floor and cinders on the rim (detail2).

Convention, the same as the half-pipe family (halfpipes.py) and the kickers: +Y up, the ride +Z, x centred, the origin at
the entry lip with y 0 at the ground there (the open end, where the stamp cuts nothing); registry rows say origin entry_lip.
No sockets: the seat fit takes the origin as the entry and the -col box's far end on the centre line as the exit, both on
the ground. The row's node stands on the ground at its at, the channel floor, so its ride sensor spans the channel.
Files: lava_channel.glb holds "lava_channel" (one draw, vertex colour, the elastomer slot) and "lava_channel-col" (never
drawn), plus the two additive detail shells. Palette: basalt, scoria red, ash, iron oxide and a hot orange for the seams
(vertex colour, no emission); copper #b77843 for the stake cap. Guardrail (PARK.md section 4): a natural lava channel and
dam-era survey gear; nothing names or depicts a living people.

  blender -b --threads 2 --python-exit-code 1 -P sketches/core-loop/tools/blender/park/lavachannels.py -- [--out DIR]
      [--count-only]
"""
import argparse
import json
import math
from pathlib import Path
import sys

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
import skyislands as si
from skyislands import Surf, col, lerp, dim, rnd

BUDGET = si.BUDGET["landform"]
SHELL_BUDGET = si.SHELL_BUDGET
SHELL_PROUD = si.SHELL_PROUD
PAINT_PROUD = 0.008
UP = (0.0, 1.0, 0.0)

L, H, W = 58.0, 4.0, 28.0
RUN = min(W, L / 4)           # park_stamps.gd _open_end: the ends open over min(width, length / 4)
LIFT = 0.12
EASE = 2.0
SKIRT = 0.6                   # the render's outer skirt reaches this far under the rim

si.HEX.update({
    "basalt": "2b2726", "basalt_hi": "433b37", "basalt_lo": "1d1a1a", "scoria": "6e3426", "ash": "6f655c",
    "cinder": "5a3024", "lava": "e8641e", "lava_hot": "ffb347", "lava_deep": "a8321a", "kettle": "6f7a74", "stake": "8c7e6b",
})


def cross_depth(x):
    """park_stamps.gd wash across the width: 1 over the middle 40 percent, 1 - w^2 out to the edge."""
    t = abs(2.0 * x / W)
    if t <= 0.4:
        return 1.0
    w = (min(t, 1.0) - 0.4) / 0.6
    return 1.0 - w * w


def open_end(z):
    return max(0.0, min(1.0, min(z, L - z) / RUN))


def ease(z):
    t = max(0.0, min(1.0, min(z, L - z) / EASE))
    return t * t * (3 - 2 * t)


def stamp(x, z):
    return -H * cross_depth(x) * open_end(z)


def ride(x, z):
    return stamp(x, z) + LIFT * ease(z)


def xs_across(n_floor, n_wall):
    hw = W / 2
    f = 0.2 * W
    out = [-f + 2 * f * i / n_floor for i in range(n_floor + 1)]
    wall = [f + (hw - f) * i / n_wall for i in range(1, n_wall + 1)]
    return [-x for x in reversed(wall)] + out + wall


def zs_along():
    out = [0.0, 0.5, 1.0, 1.5]
    z = EASE
    while z < RUN - 1e-9:
        out.append(z)
        z += 1.0
    mid = L - 2 * RUN
    n = max(1, round(mid / 2.0))
    out += [RUN + mid * i / n for i in range(n + 1)]
    out += [L - z for z in reversed(out[:-1]) if L - z > RUN + mid + 1e-9]
    return sorted(set(round(z, 6) for z in out))


XS = xs_across(14, 12)        # the render: a fine floor for the seam and the folds
XS_COL = xs_across(4, 12)     # the collider: the floor is flat, so four facets carry it
ZS = zs_along()


def floor_colour(x, z):
    """Basalt with ropy pahoehoe folds bowed downstream, the hot seam wandering down the middle, walls banded by depth,
    a cinder rim. Sampled at each vertex, so the bands and the glow blend across a facet."""
    depth = -stamp(x, z) / H if open_end(z) > 0 else 0.0
    t = abs(2.0 * x / W)
    fold = 0.5 + 0.5 * math.sin(2.1 * (z - 0.09 * x * x) + 0.9 * math.sin(0.27 * z + 0.6 * x))
    rock = lerp(col("basalt_lo"), col("basalt_hi"), 0.25 + 0.6 * fold)
    if t <= 0.42:
        seam = abs(x + 1.1 * math.sin(0.19 * z) + 0.5 * math.sin(0.61 * z + 1.1))
        glow = max(0.0, 1.0 - seam / 0.9)
        crust = 0.55 + 0.45 * math.sin(1.7 * z + 3.0 * x)
        c = lerp(rock, col("lava_deep"), min(1.0, 2.0 * glow))
        return lerp(c, lerp(col("lava"), col("lava_hot"), crust), max(0.0, 2.0 * glow - 1.0))
    band = 0.5 + 0.5 * math.sin(depth * 11.0 + 0.35 * math.sin(0.3 * z))
    c = lerp(rock, col("scoria"), 0.75 * band * band)
    if depth > 0.15 and depth < 0.3:
        c = lerp(c, col("ash"), 0.35)
    return lerp(c, col("cinder"), max(0.0, min(1.0, (t - 0.86) / 0.1)))


def build_base():
    s = Surf("lava_channel")
    for z0, z1 in zip(ZS, ZS[1:]):
        for x0, x1 in zip(XS, XS[1:]):
            pts = [(x0, ride(x0, z0), z0), (x0, ride(x0, z1), z1), (x1, ride(x1, z1), z1), (x1, ride(x1, z0), z0)]
            s.poly(pts, [floor_colour(p[0], p[2]) for p in pts], up=UP)
        for sign in (-1, 1):  # the skirt under the rim, so no slit shows where the liner meets the terrain
            x = sign * W / 2
            s.poly([(x, ride(x, z0), z0), (x, ride(x, z1), z1), (x, ride(x, z1) - SKIRT, z1), (x, ride(x, z0) - SKIRT, z0)],
                   col("cinder"), inside=(0.0, -H, 0.5 * (z0 + z1)))
    return s


def build_col():
    s = Surf("lava_channel-col")
    for z0, z1 in zip(ZS, ZS[1:]):
        for x0, x1 in zip(XS_COL, XS_COL[1:]):
            s.poly([(x0, ride(x0, z0), z0), (x0, ride(x0, z1), z1), (x1, ride(x1, z1), z1), (x1, ride(x1, z0), z0)], col("basalt"), up=UP)
    return s


def spatter_cone(s, x, z, r, h, seed):
    """A small spatter cone: a ragged basalt frustum with a hot throat."""
    s.cone((x, -0.1, z), r, h, 7, lerp(col("basalt"), col("scoria"), rnd(seed, 1)), spin=rnd(seed, 2) * math.tau, r_top=r * 0.35)
    s.cone((x, h - 0.12, z), r * 0.3, 0.14, 7, col("lava_hot"), r_top=r * 0.18)


def kettle(s, x, z):
    """A crew kettle set on a vent to boil: the vent's hot rim, the kettle, lid, spout and bail handle."""
    s.cone((x, -0.05, z), 0.55, 0.22, 8, col("basalt_hi"), r_top=0.32)
    s.cone((x, 0.17, z), 0.33, 0.04, 8, col("lava"), r_top=0.3)
    s.cone((x, 0.21, z), 0.24, 0.3, 8, col("kettle"), r_top=0.2)
    s.cone((x, 0.51, z), 0.2, 0.06, 8, dim(col("kettle"), 0.8), r_top=0.06)
    s.rope((x + 0.2, 0.3, z), (x + 0.42, 0.48, z), 0.06, 0.06, col("kettle"))
    s.rope((x - 0.18, 0.5, z), (x + 0.18, 0.5, z), 0.03, 0.18, col("basalt_lo"))


def stake(s, x, z):
    s.box((x, -0.2, z), (0.09, 1.3, 0.09), col("stake"))
    s.box((x, 1.1, z), (0.13, 0.08, 0.13), col("copper"))
    s.box((x + 0.12, 0.85, z), (0.22, 0.12, 0.02), col("ash"))


def build_d1():
    s = Surf("lava_channel_detail1")
    hw = W / 2
    for sign in (-1, 1):
        for q in range(26):  # basalt boulders along the rim, outside the ride footprint
            z = L * (q + 0.3 + 0.4 * rnd(q, sign, 1)) / 26
            x = sign * (hw + 0.5 + 4.0 * rnd(q, sign, 2))
            sz = 0.5 + 1.1 * rnd(q, sign, 3)
            s.chunk((x, -0.2, z), (sz, sz * 0.6, sz * 0.9), rnd(q, sign, 4) * math.tau, 30 + q + 50 * sign,
                    lerp(col("basalt"), col("basalt_hi"), rnd(q, sign, 5)), top=0.65)
        for q in range(3):
            spatter_cone(s, sign * (hw + 3.2 + 2.0 * rnd(q, sign, 6)), L * (0.2 + 0.3 * q) + 3.0 * sign, 1.1 + 0.5 * rnd(q, sign, 7), 1.2 + 0.8 * rnd(q, sign, 8), q + 9 * sign)
    stake(s, -hw - 1.2, 1.5)
    stake(s, hw + 1.2, L - 1.5)
    kettle(s, hw + 2.6, 6.0)
    assert len(s.t) <= SHELL_BUDGET[0], (s.name, len(s.t))
    return s


def floor_strip(s, pts, w, color):
    """A painted strip on the ridden surface through the plan points pts, PAINT_PROUD over it."""
    for (xa, za), (xb, zb) in zip(pts, pts[1:]):
        dx, dz = xb - xa, zb - za
        ln = math.hypot(dx, dz)
        nx, nz = -dz / ln * w / 2, dx / ln * w / 2
        quad = [(xa - nx, za - nz), (xb - nx, zb - nz), (xb + nx, zb + nz), (xa + nx, za + nz)]
        s.poly([(x, ride(x, z) + PAINT_PROUD, z) for x, z in quad], color, up=UP)


def build_d2():
    s = Surf("lava_channel_detail2")
    hw = W / 2
    for q in range(28):  # glowing cracks branching off the seam across the flat floor
        z0 = RUN * 0.6 + (L - 1.2 * RUN) * (q + rnd(q, 1)) / 28
        side = -1 if q % 2 else 1
        x = side * (0.5 + 0.6 * rnd(q, 2))
        pts = [(x, z0)]
        for step in range(4):
            x += side * (0.6 + 0.5 * rnd(q, step, 3))
            pts.append((min(0.18 * W, max(-0.18 * W, x)), z0 + (rnd(q, step, 4) - 0.3) * 1.4 * (step + 1)))
        floor_strip(s, pts, 0.09, col("lava" if q % 3 else "lava_hot"))
    for sign in (-1, 1):
        for q in range(26):  # cinders scattered past the rim
            z = L * (q + rnd(q, sign, 5)) / 26
            x = sign * (hw + 0.2 + 2.6 * rnd(q, sign, 6))
            sz = 0.12 + 0.22 * rnd(q, sign, 7)
            s.chunk((x, -0.02, z), (sz, sz * 0.6, sz), rnd(q, sign, 8) * math.tau, 400 + q + 90 * sign,
                    lerp(col("cinder"), col("scoria"), rnd(q, sign, 9)), top=0.6)
    assert len(s.t) <= SHELL_BUDGET[0], (s.name, len(s.t))
    return s


def check_surfaces(base, col_s, shells):
    """The -col surface is the stamp plus the lift; the render's top sits on it; no shell stands proud of it inside the
    footprint by more than SHELL_PROUD."""
    probes = [(-W / 2 + W * (i + 0.41) / 37, L * (j + 0.27) / 61) for i in range(37) for j in range(61)]
    worst = 0.0
    for x, z in probes:
        h_col = si.height_at(col_s, x, z)
        h_view = si.height_at(base, x, z)
        assert h_col is not None and abs(h_col - ride(x, z)) < 0.03, ("col is the stamp", x, z, h_col, ride(x, z))
        assert h_col - stamp(x, z) > -0.03, ("col under the stamp", x, z, h_col, stamp(x, z))
        assert h_view is not None and abs(h_view - h_col) < 1e-4, ("ride face", x, z, h_view, h_col)
        worst = max(worst, abs(h_col - ride(x, z)))
    for shell in shells:
        for x, z in probes[::2]:
            h_sh = si.height_at(shell, x, z)
            assert h_sh is None or h_sh - si.height_at(col_s, x, z) <= SHELL_PROUD + 1e-6, ("shell proud", shell.name, x, z, h_sh)
    return worst


def build(out_dir, count_only=False):
    base, col_s = build_base(), build_col()
    shells = [build_d1(), build_d2()]
    cap_t, cap_v = BUDGET
    assert len(base.t) + len(col_s.t) <= cap_t, ("base+col triangles", len(base.t), len(col_s.t), cap_t)
    assert len(base.v) + len(col_s.v) <= cap_v, ("vertices", len(base.v) + len(col_s.v), cap_v)
    for sh in shells:
        assert len(sh.t) <= SHELL_BUDGET[0] and len(sh.v) <= SHELL_BUDGET[1], (sh.name, len(sh.t), len(sh.v))
    worst = check_surfaces(base, col_s, shells)
    row = {"recipe": "lava_channel", "size": [L, H, W], "seat_m": [0.75 * L, 1.5 * L], "ride_vs_stamp_worst_m": round(worst, 5),
           "counts": {s.name: {"tris": len(s.t), "verts": len(s.v)} for s in [base, col_s] + shells}}
    if count_only:
        return row
    row["glb"] = {"lava_channel": si.export("lava_channel", [(base, "elastomer"), (col_s, None)], out_dir)}
    for n, sh in enumerate(shells, start=1):
        row["glb"][f"lava_channel_detail{n}"] = si.export(f"lava_channel_detail{n}", [(sh, "elastomer")], out_dir)
    g = row["glb"]["lava_channel"]
    render, colm = g["meshes"]["lava_channel"], g["meshes"]["lava_channel-col"]
    assert g["materials"] == ["elastomer"] and render["draws"] == 1 and colm["draws"] == 1, (g["materials"], render, colm)
    want_lo, want_hi = (-W / 2, -H + LIFT, 0.0), (W / 2, LIFT, L)
    for a in range(3):
        assert abs(colm["min"][a] - want_lo[a]) <= 0.02 and abs(colm["max"][a] - want_hi[a]) <= 0.02, ("col extent", colm["min"], colm["max"])
    return row


def main():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    parser = argparse.ArgumentParser()
    parser.add_argument("--out", default=str(si.MODELS))
    parser.add_argument("--count-only", action="store_true")
    args = parser.parse_args(argv)
    row = build(args.out, args.count_only)
    print("LAVACHANNELS", json.dumps({k: v for k, v in row.items() if k != "glb"}, sort_keys=True))
    if not args.count_only:
        print("LAVACHANNELS_SHA256", json.dumps({f: g["sha256"] for f, g in row["glb"].items()}, sort_keys=True))


if __name__ == "__main__":
    main()
