"""Headless recipes for the park's sized kickers (placeholder burn-down units C and the crown's wide lips,
alpha-status/placeholders/BREAKDOWN.md): one GLB per row size, because the seat fit stretches a GLB along its ride only and
keeps its width and lip height as authored (park_recipes.gd, PARK-SEAT). Each id is <family>_<L>x<H>x<W>, the row's own
size order [length, height, width], with p for a decimal point; a seat-fit row seats any length from 0.75 to 1.5 L.

  plate_kicker_*     the industrial kicker of the flume and the pit: a riveted steel ramp on timber cribbing. Deck plates in
                     staggered rows with dark seams, bold cream chevrons up the fall line, a hazard-striped lip and a copper
                     angle-iron cap on the back edge. Detail shells: the cribbing stacks and two amber lip lamps (detail1),
                     rivet rows on the plate seams, rust runs and a crew's forgotten lunch pail (detail2).
  mesa_lip_kicker_*  wide versions of the sky-island family's mesa_lip_kicker (skyislands.py) for the crown's kickers: the
                     same red and cream slickrock, strata cheeks and bleached chevrons, repeated across the width.
  mesa_shelf_edge    the islands' 12 x 0.01 x 1600 shelf-edge step lips: a caprock coping band 12 m deep across the full
                     1600 m, its top 0.06 m over y 0, its bevelled back edge buried, and a bullnose that rolls 2.5 m down over
                     the shelf at z 12. Its -col reaches z 12.7 over the bullnose, so the seat fit reads 12.7 m as its
                     authored length (rows 9.5 to 19.05 m) and a 12 m row lands the coping's edge 0.66 m short of the lip.

Convention, the same as mesa_lip_kicker: +Y up, the ride direction +Z (the fall line), x centred, the origin at the entry lip
with y 0 at the ground there; registry rows say origin entry_lip, so park_recipes.gd ride_frame puts the origin size[0] / 2
behind the row's at and the lip (z L) lands on the footprint's far edge, where park_map.gd kicker_lip finds it. A kicker's
top is the parabola y = H (z / L)^2, flush at z 0 and atan(2 H / L) at the lip, the angle the row's height and length set.
No sockets: the seat fit takes the origin as the entry and the -col box's far end on the centre line as the exit, both on
the ground. Files: <id>.glb holds the render mesh "<id>" (one draw, vertex colour) and the trimesh "<id>-col" (never drawn);
<id>_detail1.glb and <id>_detail2.glb are the two additive detail shells (nothing in a shell stands more than SHELL_PROUD
over a ridden surface inside the footprint). Plates take the enamel slot, rock the elastomer slot.
Palette: iron, oxide and rust for steel, grey timber, cream and bone paint, copper #b77843 for machinery (never brass);
sandstone, red and cream slickrock and desert varnish for the mesa pieces. Guardrail (PARK.md section 4): dam-era and
mining works and the fictional animals' mesa works; nothing names or depicts a living people.

  blender -b --threads 2 --python-exit-code 1 -P sketches/core-loop/tools/blender/park/kickers.py -- [--out DIR]
      [--recipe ID[,ID]] [--count-only]
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
PAINT_PROUD = 0.006
RIVET_H = 0.015
UP = (0.0, 1.0, 0.0)

si.HEX.update({
    "iron": "3a3430", "iron_hi": "4d453e", "iron_dk": "262220", "plate_a": "5b524a", "plate_b": "665a4d", "plate_c": "534c47",
    "seam": "1f1c1a", "hazard": "d9a441", "amber": "e8a23a", "amber_dk": "9a5a22", "crib": "8a7660", "crib_dk": "6a5a48",
    "pail": "7d8f86", "rust": "7a4430", "thermos": "a9553a", "cap": "d8c9a4",
})


def fmt(v):
    return ("%g" % v).replace(".", "p")


PLATE_SIZES = [
    (12, 2.5, 14), (12, 2.5, 30), (12, 2.5, 40),
    (10, 3, 8), (30, 8, 18), (28, 14, 34), (24, 3, 20), (24, 4, 18), (18, 4, 10), (16, 6, 24), (8, 3, 20),
]
MESA_SIZES = [
    (24, 6, 36), (24, 6, 60), (24, 6, 90), (26, 5, 30), (60, 32, 36), (60, 26, 60),
    (12, 4, 56), (12, 4, 300),
]
SHELF = {"L": 12.0, "W": 1600.0, "TOP": 0.06, "NOSE": 2.5, "BLOCK": 8.0}


def ktop(z, k):
    return k["H"] * (z / k["L"]) ** 2


def zs_of(k, step):
    n = max(8, min(120, round(k["L"] / step)))
    return [k["L"] * j / n for j in range(n + 1)]


PLATE_ROW = 2.4
PLATE_W = 3.0
SEAM = 0.05
LIP_BAND = 0.6


def plate_colour(i, j):
    base = dim(col(("plate_a", "plate_b", "plate_c")[int(rnd(i, j, 11) * 3)]), 0.92 + 0.16 * rnd(i, j, 12))
    return lerp(base, col("oxide"), 0.4 * rnd(i, j, 13) ** 2)


def plate_xs(k, j):
    """x stations of plate row j across the width: each plate's seam edges, staggered half a plate every other row."""
    hw = k["W"] / 2
    off = (PLATE_W / 2) * (j % 2)
    edges = sorted({-hw, hw} | {x for x in (-hw + off + PLATE_W * n for n in range(int(k["W"] / PLATE_W) + 2)) if -hw < x < hw})
    out = []
    for a, b in zip(edges, edges[1:]):
        out.append((a, b))
    return out


def plate_face(s, k):
    """The ridden deck: plate rows along z, each plate its own tone with dark seams, the lip band hazard-striped."""
    L = k["L"]
    bands = []
    z = 0.0
    while z < L - LIP_BAND - 1e-9:
        bands.append((z, min(L - LIP_BAND, z + PLATE_ROW)))
        z += PLATE_ROW
    for j, (z0, z1) in enumerate(bands):
        nz = max(1, math.ceil((z1 - z0) / 0.6))
        for i, (x0, x1) in enumerate(plate_xs(k, j)):
            c = plate_colour(i, j)
            xa, xb = x0 + (SEAM if x0 > -k["W"] / 2 + 1e-9 else 0.0), x1 - (SEAM if x1 < k["W"] / 2 - 1e-9 else 0.0)
            for q in range(nz):
                za, zb = z0 + (z1 - z0) * q / nz, z0 + (z1 - z0) * (q + 1) / nz
                if q == 0 and j > 0:
                    za += SEAM
                s.poly([(xa, ktop(za, k), za), (xa, ktop(zb, k), zb), (xb, ktop(zb, k), zb), (xb, ktop(za, k), za)], c, up=UP)
                for u0, u1 in ((x0, xa), (xb, x1)):
                    if u1 - u0 > 1e-9:
                        s.poly([(u0, ktop(za, k), za), (u0, ktop(zb, k), zb), (u1, ktop(zb, k), zb), (u1, ktop(za, k), za)], col("seam"), up=UP)
        if j > 0:
            s.poly([(-k["W"] / 2, ktop(z0, k), z0), (-k["W"] / 2, ktop(z0 + SEAM, k), z0 + SEAM),
                    (k["W"] / 2, ktop(z0 + SEAM, k), z0 + SEAM), (k["W"] / 2, ktop(z0, k), z0)], col("seam"), up=UP)
    z0, z1 = L - LIP_BAND, L
    hw = k["W"] / 2
    n = max(1, round(k["W"]))
    for i in range(n):
        x0, x1 = -hw + k["W"] * i / n, -hw + k["W"] * (i + 1) / n
        c = col("hazard") if i % 2 == 0 else col("iron_dk")
        s.poly([(x0, ktop(z0, k), z0), (x0, ktop(z1, k), z1), (x1, ktop(z1, k), z1), (x1, ktop(z0, k), z0)], c, up=UP)


def plate_chevrons(s, k):
    """Cream chevrons up the fall line in columns every 7 m across, followed along the parabola in short steps."""
    hw = k["W"] / 2
    cols = max(1, round(k["W"] / 7.0))
    arm = min(2.6, 0.32 * k["W"] / cols)
    rise = min(1.6, 0.14 * k["L"])
    tips = [k["L"] * f for f in (0.3, 0.52, 0.74)]
    for c in range(cols):
        cx = -hw + k["W"] * (c + 0.5) / cols
        for zt in tips:
            for sign in (-1, 1):
                n = 6
                for q in range(n):
                    f0, f1 = q / n, (q + 1) / n
                    x0, x1 = cx + sign * arm * (1 - f0), cx + sign * arm * (1 - f1)
                    z0, z1 = zt - rise * (1 - f0), zt - rise * (1 - f1)
                    pts = [(x, ktop(z, k) + PAINT_PROUD, z) for (x, z) in ((x0, z0), (x0, z0 - 0.4), (x1, z1 - 0.4), (x1, z1))]
                    s.poly(pts, col("cap"), up=UP)


def solid_sides(s, k, zs, side_col, back_col):
    """The cheeks under the parabola and the back face at the lip, one quad per z step each side."""
    hw = k["W"] / 2
    inside = (0.0, k["H"] / 3, k["L"] * 0.66)
    for sign in (-1, 1):
        for z0, z1 in zip(zs, zs[1:]):
            c = side_col(sign, z0) if callable(side_col) else side_col
            s.poly([(sign * hw, 0.0, z0), (sign * hw, 0.0, z1), (sign * hw, ktop(z1, k), z1), (sign * hw, ktop(z0, k), z0)], c, inside=inside)
    s.poly([(-hw, 0.0, k["L"]), (hw, 0.0, k["L"]), (hw, k["H"], k["L"]), (-hw, k["H"], k["L"])], back_col, inside=inside)


def build_plate_base(k):
    s = Surf(k["id"])
    plate_face(s, k)
    plate_chevrons(s, k)
    zs = zs_of(k, 0.5)
    solid_sides(s, k, zs, lambda sign, z: dim(col("iron"), 0.9 + 0.2 * rnd(int(z * 10), sign, 3)), col("iron_dk"))
    hw = k["W"] / 2
    cap = min(0.35, 0.12 * k["H"])
    s.poly([(-hw, k["H"] - cap, k["L"] + 0.004), (hw, k["H"] - cap, k["L"] + 0.004), (hw, k["H"], k["L"] + 0.004), (-hw, k["H"], k["L"] + 0.004)],
           col("copper"), inside=(0.0, k["H"] / 2, k["L"] / 2))
    s.poly([(-hw, 0.0, 0.0), (hw, 0.0, 0.0), (hw, 0.0, k["L"]), (-hw, 0.0, k["L"])], col("iron_dk"), up=(0.0, -1.0, 0.0))
    return s


def build_kicker_col(k):
    s = Surf(k["id"] + "-col")
    hw = k["W"] / 2
    zs = zs_of(k, 0.5)
    for z0, z1 in zip(zs, zs[1:]):
        s.poly([(-hw, ktop(z0, k), z0), (-hw, ktop(z1, k), z1), (hw, ktop(z1, k), z1), (hw, ktop(z0, k), z0)], col("iron"), up=UP)
    solid_sides(s, k, zs, col("iron"), col("iron"))
    return s


def crib_stack(s, x, z, top, seed):
    """Crossed timber cribbing from the ground to top: pairs of sleepers, each course turned 90 degrees."""
    course = max(0.3, top / 6.0)
    n = max(1, int(top / course))
    beam = max(0.24, 0.6 * course)
    span = max(1.2, 4.0 * beam)
    for c in range(n):
        y = c * course
        tone = lerp(col("crib"), col("crib_dk"), rnd(seed, c, 1))
        for side in (-1, 1):
            if c % 2 == 0:
                s.box((x + side * (span / 2 - beam / 2), y, z), (beam, course * 0.92, span), tone)
            else:
                s.box((x, y, z + side * (span / 2 - beam / 2)), (span, course * 0.92, beam), tone)


def lamp(s, x, z):
    """An amber warning lamp on a short iron post, copper hood; the lamp marks the lip from the side."""
    s.box((x, 0.0, z), (0.16, 1.4, 0.16), col("iron_hi"))
    s.box((x, 1.4, z), (0.42, 0.34, 0.42), col("amber"))
    s.box((x, 1.74, z), (0.52, 0.1, 0.52), col("copper"))
    s.box((x, 1.84, z), (0.2, 0.08, 0.2), col("amber_dk"))


def build_plate_d1(k):
    s = Surf(k["id"] + "_detail1")
    hw = k["W"] / 2
    per_side = max(2, min(4, round(k["L"] / 3.0)))
    for sign in (-1, 1):
        for q in range(per_side):
            z = k["L"] * (q + 0.75) / (per_side + 0.5)
            top = ktop(z, k) * 0.85
            if top < 0.3:
                continue
            crib_stack(s, sign * (hw + 0.15 + max(0.6, 2.4 * max(0.24, 0.1 * top))), z, top, q + 20 * (sign + 1))
    for sign in (-1, 1):
        lamp(s, sign * (hw + 0.7), k["L"] - 0.25)
    assert len(s.t) <= SHELL_BUDGET[0], (s.name, len(s.t))
    return s


def build_plate_d2(k):
    s = Surf(k["id"] + "_detail2")
    hw = k["W"] / 2
    rows = [z for z in (PLATE_ROW * j for j in range(1, 40)) if z < k["L"] - LIP_BAND]
    spacing = max(0.6, (len(rows) * k["W"] * 2) / 240.0)
    for j, z in enumerate(rows):
        for zz in (z - 0.12, z + 0.17):
            n = int(k["W"] / spacing)
            for i in range(n):
                x = -hw + spacing * (i + 0.5)
                drop = ktop(zz, k) - ktop(zz - 0.05, k)
                s.cone((x, ktop(zz, k) - drop, zz), 0.05, RIVET_H + drop, 3, col("iron_hi"), spin=rnd(i, j))
    for sign in (-1, 1):
        for q, z in enumerate(rows):
            h = ktop(z, k)
            if h < 0.4:
                continue
            x = sign * (hw + 0.008)
            s.poly([(x, h - 0.05, z - 0.08), (x, h - 0.05, z + 0.08), (x, 0.15, z + 0.04), (x, 0.15, z - 0.02)], col("rust"), inside=(0.0, h / 2, z))
    px, pz = -hw - 1.6, 1.4
    s.box((px, 0.0, pz), (0.36, 0.26, 0.24), col("pail"))
    s.box((px, 0.26, pz), (0.36, 0.05, 0.24), dim(col("pail"), 0.8))
    s.rope((px - 0.16, 0.31, pz), (px + 0.16, 0.31, pz), 0.03, 0.12, col("iron_hi"))
    s.cone((px + 0.36, 0.0, pz + 0.05), 0.07, 0.34, 6, col("thermos"), r_top=0.07)
    s.cone((px + 0.36, 0.34, pz + 0.05), 0.06, 0.05, 6, col("cap"), r_top=0.06)
    assert len(s.t) <= SHELL_BUDGET[0], (s.name, len(s.t))
    return s


def slick_w(x, z, k):
    """mesa_lip_kicker's cross-bedded slickrock, with the varnish edge and the cream lip set by this kicker's width and length."""
    w = 0.5 + 0.5 * math.sin(0.85 * x + 0.32 * z + 1.3 * math.sin(0.35 * z + 0.4 * x))
    t = min(1.0, max(0.0, (w - 0.35) / 0.3))
    c = lerp(lerp(col("deep_red"), col("slick_red"), 0.5 + 0.5 * math.sin(0.5 * z - 0.7 * x)), col("sandstone"), 0.55 * t)
    edge = max(0.0, (abs(x) - (k["W"] / 2 - 1.4)) / 1.4)
    c = lerp(c, col("varnish"), 0.55 * min(1.0, edge) * (0.5 + 0.5 * math.sin(2.2 * z + 7 * x)))
    if z > k["L"] - 0.55 * k["L"] / 12.0:
        c = lerp(c, col("cream"), 0.8)
    return c


def strata_wall(s, pts_top, x_of, inside, outward, step):
    """skyislands.wall with a band scale, so a 32 m cheek keeps the same band count as a 6 m one."""
    for (u0, t0), (u1, t1) in zip(pts_top, pts_top[1:]):
        top = max(t0, t1)
        for y0, y1, name in si.strata_edges(top, step):
            a0, b0 = min(y0, t0), min(y1, t0)
            a1, b1 = min(y0, t1), min(y1, t1)
            if b0 - a0 < 1e-6 and b1 - a1 < 1e-6:
                continue
            c = lerp(col(name), col("varnish"), 0.18 * rnd(int(u0 * 10), int(y0 * 10)))
            s.poly([x_of(u0, a0), x_of(u1, a1), x_of(u1, b1), x_of(u0, b0)] if outward > 0 else [x_of(u0, a0), x_of(u0, b0), x_of(u1, b1), x_of(u1, a1)],
                   c, inside=inside)


def mesa_grid(k):
    nz = max(24, min(80, round(k["L"] / 0.75)))
    nx = max(16, min(64, round(k["W"] / 1.5), 2200 // nz))
    return nx, nz


def build_mesa_base(k):
    s = Surf(k["id"])
    hw = k["W"] / 2
    nx, nz = mesa_grid(k)
    dx, dz = k["W"] / nx, k["L"] / nz
    for i in range(nx):
        for j in range(nz):
            x0, x1, z0, z1 = -hw + i * dx, -hw + (i + 1) * dx, j * dz, (j + 1) * dz
            pts = [(x0, ktop(z0, k), z0), (x0, ktop(z1, k), z1), (x1, ktop(z1, k), z1), (x1, ktop(z0, k), z0)]
            s.poly(pts, [slick_w(p[0], p[2], k) for p in pts], up=UP)
    step = max(1.0, k["H"] / 5.0)
    inside = (0.0, k["H"] / 3, k["L"] * 0.66)
    zs = [j * dz for j in range(0, nz + 1, 2 if nz > 40 else 1)]
    for sign in (-1, 1):
        strata_wall(s, [(z, ktop(z, k)) for z in zs], lambda u, y, sg=sign: (sg * hw, y, u), inside, sign, step)
    nb = max(14, min(45, round(k["W"] / 2.0)))
    strata_wall(s, [(-hw + k["W"] * i / nb, k["H"]) for i in range(nb + 1)], lambda u, y: (u, y, k["L"]), inside, 1, step)
    s.poly([(-hw, 0.0, 0.0), (hw, 0.0, 0.0), (hw, 0.0, k["L"]), (-hw, 0.0, k["L"])], col("sandstone"), up=(0.0, -1.0, 0.0))
    sets = max(1, min(12, round(k["W"] / 14.0)))
    sc = k["L"] / 12.0
    band = 0.5 * min(sc, 1.6)
    n = max(10, round(5 * sc))
    for c in range(sets):
        cx = -hw + k["W"] * (c + 0.5) / sets
        for zt in (2.6 * sc, 5.4 * sc, 8.2 * sc):
            for sign in (-1, 1):
                for q in range(n):
                    f0, f1 = q / n, (q + 1) / n
                    x0, x1 = cx + sign * 3.3 * (1 - f0), cx + sign * 3.3 * (1 - f1)
                    z0, z1 = zt - 2.0 * sc * (1 - f0), zt - 2.0 * sc * (1 - f1)
                    pts = [(x, ktop(z, k) + PAINT_PROUD, z) for (x, z) in ((x0, z0), (x0, z0 - band), (x1, z1 - band), (x1, z1))]
                    s.poly(pts, col("bone"), up=UP)
    return s


def build_mesa_d1(k):
    s = Surf(k["id"] + "_detail1")
    hw = k["W"] / 2
    n = max(10, min(18, round(k["L"] * 1.2)))
    for sign in (-1, 1):
        for q in range(n):
            z = k["L"] * (q + 0.6) / (n + 0.4) + rnd(q, sign) * 0.4
            sz = (0.3 + 0.6 * rnd(q, 4, sign)) * (1.0 + k["H"] / 20.0)
            x = sign * (hw + 0.35 + 0.85 * sz + 1.9 * rnd(q, 3, sign))
            s.chunk((x, 0.0, z), (sz, sz * 0.7, sz * 1.1), rnd(q, 5, sign) * math.tau, q + 40 * sign, lerp(col("sandstone"), col("slick_red"), rnd(q, 6, sign)), top=0.7)
    for c, (cx, cz) in enumerate([(hw + 1.1, k["L"] - 0.6), (-hw - 1.4, k["L"] - 1.4)]):
        for tier in range(4):
            r = 0.55 - 0.1 * tier
            s.chunk((cx, tier * 0.34, cz), (r, 0.3, r), tier + 3 * c, 90 + tier, col("bone"), top=0.75)
    for q in range(10):
        sg = -1 if q % 2 else 1
        s.tuft((sg * (hw + 2.4 + 1.5 * rnd(q, 8)), 0.0, k["L"] * (q + 0.5) / 10), 0.9, 6, col("dry_sage" if q % 3 else "sage"), 70 + q)
    assert len(s.t) <= SHELL_BUDGET[0], (s.name, len(s.t))
    return s


def build_mesa_d2(k):
    s = Surf(k["id"] + "_detail2")
    hw = k["W"] / 2
    for sign in (-1, 1):
        for q in range(22):
            z = k["L"] * (q + 0.4) / 22.4
            x = sign * (hw + 0.15 + 1.2 * rnd(q, 2, sign))
            sz = 0.1 + 0.2 * rnd(q, 3, sign)
            s.chunk((x, 0.0, z), (sz, sz * 0.6, sz), rnd(q, 4, sign) * math.tau, q + 200 * sign, lerp(col("sandstone"), col("varnish"), rnd(q, 5, sign) * 0.6), top=0.6)
        for q in range(6):
            z = k["L"] * (0.17 + 0.14 * q)
            h = ktop(z, k) * 0.9
            s.poly([(sign * (hw + 0.012), h, z), (sign * (hw + 0.012), h, z + 0.22), (sign * (hw + 0.012), 0.1, z + 0.12), (sign * (hw + 0.012), 0.1, z + 0.02)],
                   col("varnish"), inside=(0.0, 1.0, z))
    stones = max(7, min(30, round(k["W"] / 2.0)))
    for q in range(stones):
        s.chunk((-hw + 0.8 + (k["W"] - 1.6) * q / max(1, stones - 1), 0.0, k["L"] + 0.28), (0.4, 0.32, 0.32), 0.0, 300 + q, col("bone" if q % 2 else "cream"), top=0.7)
    assert len(s.t) <= SHELL_BUDGET[0], (s.name, len(s.t))
    return s


def nose_pts():
    """The bullnose profile past the lip: (z, y) from the top edge at z L round to the face NOSE below."""
    L, top, nose = SHELF["L"], SHELF["TOP"], SHELF["NOSE"]
    r = 0.7
    pts = [(L, top)]
    for q in range(1, 5):
        a = math.radians(90 - 90 * q / 4)
        pts.append((L + r * math.cos(a) - r * 0.0, top - r + r * math.sin(a)))
    pts.append((L + r, -nose))
    return pts


def build_shelf_base(k):
    s = Surf(k["id"])
    L, W, top = SHELF["L"], k["W"], SHELF["TOP"]
    hw = W / 2
    n = int(W / SHELF["BLOCK"])
    prof = nose_pts()
    for i in range(n):
        x0, x1 = -hw + SHELF["BLOCK"] * i, -hw + SHELF["BLOCK"] * (i + 1)
        tone = lerp(col("cream"), col("sandstone"), 0.25 + 0.5 * rnd(i, 1))
        jx = 0.06
        s.poly([(x0, -0.3, -0.4), (x0, top, 0.0), (x1 - jx, top, 0.0), (x1 - jx, -0.3, -0.4)], dim(tone, 0.85), up=UP)
        s.poly([(x0, top, 0.0), (x0, top, L), (x1 - jx, top, L), (x1 - jx, top, 0.0)],
               [tone, lerp(tone, col("varnish"), 0.15), lerp(tone, col("varnish"), 0.15), tone], up=UP)
        s.poly([(x1 - jx, top - 0.02, 0.0), (x1 - jx, top - 0.02, L), (x1, top - 0.02, L), (x1, top - 0.02, 0.0)], col("varnish"), up=UP)
        for (za, ya), (zb, yb) in zip(prof, prof[1:]):
            c = lerp(tone, col("varnish"), 0.2 + 0.5 * (top - yb) / (top + SHELF["NOSE"]))
            s.poly([(x0, ya, za), (x0, yb, zb), (x1, yb, zb), (x1, ya, za)], c, inside=(0.5 * (x0 + x1), -3.0, L - 1.0))
    return s


def build_shelf_col(k):
    s = Surf(k["id"] + "-col")
    L, W, top = SHELF["L"], k["W"], SHELF["TOP"]
    hw = W / 2
    s.poly([(-hw, -0.3, -0.4), (-hw, top, 0.0), (hw, top, 0.0), (hw, -0.3, -0.4)], col("cream"), up=UP)
    s.poly([(-hw, top, 0.0), (-hw, top, L), (hw, top, L), (hw, top, 0.0)], col("cream"), up=UP)
    prof = nose_pts()
    for (za, ya), (zb, yb) in zip(prof, prof[1:]):
        s.poly([(-hw, ya, za), (-hw, yb, zb), (hw, yb, zb), (hw, ya, za)], col("cream"), inside=(0.0, -3.0, L - 1.0))
    return s


def build_shelf_d1(k):
    s = Surf(k["id"] + "_detail1")
    hw = k["W"] / 2
    for q in range(70):
        x = -hw + k["W"] * (q + rnd(q, 1)) / 70
        if q % 2:
            s.chunk((x, -SHELF["NOSE"], SHELF["L"] + 1.2 + 1.4 * rnd(q, 2)), (0.9, 0.6, 0.8), rnd(q, 3) * math.tau, q, lerp(col("cream"), col("sandstone"), rnd(q, 4)), top=0.7)
        else:
            s.chunk((x, -0.1, -0.9 - 0.6 * rnd(q, 2)), (0.6, 0.4, 0.5), rnd(q, 3) * math.tau, q, lerp(col("sandstone"), col("slick_red"), rnd(q, 4)), top=0.7)
    assert len(s.t) <= SHELL_BUDGET[0], (s.name, len(s.t))
    return s


def build_shelf_d2(k):
    s = Surf(k["id"] + "_detail2")
    hw = k["W"] / 2
    for q in range(60):
        x = -hw + k["W"] * (q + 0.5) / 60
        if q % 3:
            s.tuft((x, 0.0, -0.8), 0.7, 5, col("dry_sage" if q % 2 else "sage"), 500 + q)
        else:
            z = SHELF["L"] + 0.72
            s.poly([(x, -0.2, z), (x + 0.3, -0.2, z), (x + 0.22, -2.2, z), (x + 0.06, -2.2, z)], col("varnish"), up=(0.0, 0.0, 1.0))
    assert len(s.t) <= SHELL_BUDGET[0], (s.name, len(s.t))
    return s


def spec_of(family, L, H, W):
    rid = f"{family}_{fmt(L)}x{fmt(H)}x{fmt(W)}"
    return rid, {"id": rid, "family": family, "L": float(L), "H": float(H), "W": float(W)}


RECIPES = {}
for _L, _H, _W in PLATE_SIZES:
    _id, _k = spec_of("plate_kicker", _L, _H, _W)
    _k.update(base=build_plate_base, col=build_kicker_col, d=(build_plate_d1, build_plate_d2), material="enamel",
              extent=((-_W / 2, 0.0, 0.0), (_W / 2, _H, _L)))
    RECIPES[_id] = _k
for _L, _H, _W in MESA_SIZES:
    _id, _k = spec_of("mesa_lip_kicker", _L, _H, _W)
    _k.update(base=build_mesa_base, col=build_kicker_col, d=(build_mesa_d1, build_mesa_d2), material="elastomer",
              extent=((-_W / 2, 0.0, 0.0), (_W / 2, _H, _L)))
    RECIPES[_id] = _k
for _id, _W in (("mesa_shelf_edge", SHELF["W"]), ("mesa_shelf_edge_12x0p01x840", 840.0), ("mesa_shelf_edge_12x0p01x720", 720.0)):
    RECIPES[_id] = {"id": _id, "family": "mesa_shelf_edge", "L": SHELF["L"], "H": SHELF["TOP"], "W": _W,
                    "base": build_shelf_base, "col": build_shelf_col, "d": (build_shelf_d1, build_shelf_d2), "material": "elastomer",
                    "extent": ((-_W / 2, -SHELF["NOSE"], -0.4), (_W / 2, SHELF["TOP"], SHELF["L"] + 0.7))}


def ride_top(k, z):
    return SHELF["TOP"] if k["family"] == "mesa_shelf_edge" else ktop(z, k)


def check_surfaces(k, base, col_s, shells):
    """The -col top is the ride surface (the parabola, or the shelf's flat top); the render's top sits on it within paint and
    rivet height; no shell stands more than SHELL_PROUD over it inside the footprint."""
    hw = k["W"] / 2
    if k["family"] == "mesa_shelf_edge":
        nb = int(k["W"] / SHELF["BLOCK"])
        probes = [(-hw + SHELF["BLOCK"] * ((nb - 1) * i // 42) + 0.5 + 0.17 * (i % 40), 0.3 + 0.9 * j) for i in range(43) for j in range(13)]
    else:
        probes = [(-hw + k["W"] * (i + 0.37) / 31, k["L"] * (j + 0.21) / 33) for i in range(31) for j in range(33)]
    tol = 0.002 + k["H"] / k["L"] ** 2 * 1.1 ** 2 / 4
    worst = 0.0
    for x, z in probes:
        want = ride_top(k, z)
        h_col = si.height_at(col_s, x, z)
        h_view = si.height_at(base, x, z)
        assert h_col is not None and abs(h_col - want) < tol, (k["id"], "col is the ride top", x, z, h_col, want)
        assert h_view is not None and -2 * tol < h_view - h_col < PAINT_PROUD + 2 * tol, (k["id"], "ride face", x, z, h_view, h_col)
        worst = max(worst, abs(h_view - h_col))
    for shell in shells:
        for x, z in probes[::2]:
            h_sh = si.height_at(shell, x, z)
            assert h_sh is None or h_sh - ride_top(k, z) <= SHELL_PROUD + 1e-6, (k["id"], "shell proud", shell.name, x, z, h_sh)
        for x, y, z in shell.v:
            if abs(x) < hw and 0.0 < z < k["L"]:
                assert y - ride_top(k, z) <= SHELL_PROUD + 1e-6, (k["id"], "shell vertex proud", shell.name, x, y, z)
    return worst


def build(rid, out_dir, count_only=False):
    k = RECIPES[rid]
    base, col_s = k["base"](k), k["col"](k)
    shells = [fn(k) for fn in k["d"]]
    cap_t, cap_v = BUDGET
    assert len(base.t) + len(col_s.t) <= cap_t, (rid, "base+col triangles", len(base.t), len(col_s.t), cap_t)
    assert len(base.v) + len(col_s.v) <= cap_v, (rid, "vertices", len(base.v) + len(col_s.v), cap_v)
    for sh in shells:
        assert len(sh.t) <= SHELL_BUDGET[0] and len(sh.v) <= SHELL_BUDGET[1], (sh.name, len(sh.t), len(sh.v))
    worst = check_surfaces(k, base, col_s, shells)
    row = {"recipe": rid, "size": [k["L"], k["H"], k["W"]], "seat_m": [round(0.75 * k["extent"][1][2], 2), round(1.5 * k["extent"][1][2], 2)],
           "ride_surface_worst_m": round(worst, 5),
           "counts": {s.name: {"tris": len(s.t), "verts": len(s.v)} for s in [base, col_s] + shells}}
    if count_only:
        return row
    row["glb"] = {rid: si.export(rid, [(base, k["material"]), (col_s, None)], out_dir)}
    for n, sh in enumerate(shells, start=1):
        row["glb"][f"{rid}_detail{n}"] = si.export(f"{rid}_detail{n}", [(sh, k["material"])], out_dir)
    g = row["glb"][rid]
    assert g["materials"] == [k["material"]], (rid, g["materials"])
    render, colm = g["meshes"][rid], g["meshes"][rid + "-col"]
    assert render["draws"] == 1 and colm["draws"] == 1 and render["tris"] + colm["tris"] <= cap_t, (rid, render, colm)
    lo, hi = k["extent"]
    for a in range(3):
        assert abs(colm["min"][a] - lo[a]) <= 0.02 and abs(colm["max"][a] - hi[a]) <= 0.02, (rid, "col extent", colm["min"], colm["max"], lo, hi)
    return row


def main():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    parser = argparse.ArgumentParser()
    parser.add_argument("--out", default=str(si.MODELS))
    parser.add_argument("--count-only", action="store_true")
    parser.add_argument("--recipe", default="all")
    args = parser.parse_args(argv)
    ids = list(RECIPES) if args.recipe == "all" else args.recipe.split(",")
    log = [build(rid, args.out, args.count_only) for rid in ids]
    for row in log:
        print("KICKERS", row["recipe"], json.dumps({k: v for k, v in row.items() if k != "glb"}, sort_keys=True))
    if not args.count_only:
        print("KICKERS_SHA256", json.dumps({f: g["sha256"] for r in log for f, g in r["glb"].items()}, sort_keys=True))


if __name__ == "__main__":
    main()
