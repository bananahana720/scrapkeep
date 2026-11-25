"""Headless recipes for the sinkhole's stamped channels (placeholder burn-down unit F,
alpha-status/placeholders/BREAKDOWN.md): liners over the bake's own wash and channel stamps, and one small raised chute.
Each GLB is one row size, because the seat fit stretches a GLB along its ride only (park_recipes.gd, PARK-SEAT).

  lava_channel             58 x 4 x 28 wash, chained: the lava_channel_* rows (51 to 60 m long), whose stamps overlap end
                           to end, so it is measured from the floor centre with no end taper and its -col is two deep end slabs.
  lava_trench_420x6x40     420 x 6 x 40 channel stamp: west_trench, its walls as the 2 m bake grid draws them.
  dry_wash_1500x4x60       1500 x 4 x 60 wash in the dry_wash landform: south_flats.
  lava_chute_3x0p5x8       3 x 0.5 x 8, no stamp: lava_chute, a small basalt trough standing on its own.

The tube fit (agreed with the Sinkhole park pass, 2026-10-17): the stamp is the ride. The drawn shell follows the stamp
profile analytically SHELL_LIFT over it (the bake's 2 m grid sags up to about 0.13 m on a wall, so the shell hides the
terrain without floating); the -col mesh is the same profile COL_DROP under it, so the terrain carries the ball and the
collider gives the seat fit its authored ends and a safety net. Both offsets taper with the stamp's open ends (park_stamps.gd
_open_end, min(width, length / 4)), so a piece meets the plain at its row's ends, and seated, the stretch scales those ends
exactly as the stamp does. The lane is the footprint: nothing drawn or colliding stands over the ridden surface inside it;
boulders, cones and crust only stand beyond the crest, |x| >= W / 2 + CREST_CLEAR. On the chained piece they also stay END_ZONE
from either end, where the next row's lane at a bend reaches, and the crest band is meshed finer (CREST_BAND). The carve band (the Dig's carving skill;
FloorRule.on_floor is normal.y >= 0.9): wherever the stamp is steeper than CARVE_DEG the wall is drawn in polished glassy
basalt with flow streaks along the run, computed from the profile's own gradient, with a pale lip line on the floor's last
safe line (carve_x) and cinder grit on the floor centre, so the safe walls and the bitten floor read from the chase camera.

Look: black basalt with ropy pahoehoe folds and a hot seam wandering down the floor, scoria-banded walls, the glassy carve
band, a cinder rim; spatter cones and basalt boulders past the crest, a dam-era survey stake, and a kettle someone set on a
vent to boil. The dry wash is silt and sand with gravel bars and a damp thread down its floor. Vertex colour only, one draw,
the elastomer slot; copper #b77843 for the stake cap. Guardrail (PARK.md section 4): natural channels and dam-era survey gear;
nothing names or depicts a living people.

Convention (the half-pipe family and the kickers): +Y up, the ride +Z, x centred, the origin at the entry lip on the floor
centre with y 0 at the ground there (the open end, where the stamp cuts nothing); registry rows say origin entry_lip. No
sockets: the seat fit takes the origin as the entry and the -col box's far end on the centre line as the exit.

  blender -b --threads 2 --python-exit-code 1 -P sketches/core-loop/tools/blender/park/lavachannels.py -- [--out DIR]
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
PAINT_PROUD = 0.008
UP = (0.0, 1.0, 0.0)
SHELL_LIFT = 0.2
COL_DROP = 0.15
CREST_CLEAR = 0.5
CARVE_DEG = 25.8
END_SLAB = (6.0, 0.2)
BAKE_GRID = 2.0
SKIRT = 0.6
CREST_BAND = 2.0
BAND_STEP = 0.5
MAX_BEND_DEG = 45.0
END_ZONE = 15.0
MIN_STRETCH = 0.88
PROP_HALF = 1.5

si.HEX.update({
    "basalt": "2b2726", "basalt_hi": "433b37", "basalt_lo": "1d1a1a", "scoria": "6e3426", "ash": "6f655c",
    "cinder": "5a3024", "lava": "e8641e", "lava_hot": "ffb347", "lava_deep": "a8321a", "kettle": "6f7a74", "stake": "8c7e6b",
    "glass": "171b22", "glass_hi": "3c4656", "silt": "cdb487", "sand": "c6a274", "gravel": "9a8a74", "damp": "8f7a5c",
})


class Piece:
    """One stamped channel: its stamp (park_stamps.gd) and the shell, collider and detail built over it."""

    def __init__(self, rid, L, H, W, stamp, look, chained=False):
        self.id, self.L, self.H, self.W, self.kind, self.look = rid, float(L), float(H), float(W), stamp, look
        self.chained = chained
        self.crest = self.H if chained else 0.0
        self.run = max(min(self.W, 0.25 * self.L), 0.001)
        self.wall = max(min(0.2 * self.H, 0.25 * self.W), 0.001)
        if stamp == "channel":
            self.wall = max(self.wall, BAKE_GRID)
        lo, hi = 0.0, self.W / 2
        for _ in range(40):
            mid = 0.5 * (lo + hi)
            lo, hi = (lo, mid) if self.steep(mid, 0.5 * self.L) else (mid, hi)
        self.carve_x = hi
        self.z_lo = (END_ZONE / MIN_STRETCH + PROP_HALF) if chained else 0.0
        self.z_span = self.L - 2.0 * self.z_lo

    def cross(self, x):
        """The stamp's depth across the width, 0..1: park_stamps.gd wash or channel."""
        side_m = (0.5 - min(0.5, abs(x) / self.W)) * self.W
        if self.kind == "channel":
            return max(0.0, min(1.0, side_m / self.wall))
        t = min(1.0, abs(2.0 * x / self.W))
        if t <= 0.4:
            return 1.0
        w = (t - 0.4) / 0.6
        return 1.0 - w * w

    def open_end(self, z):
        return 1.0 if self.chained else max(0.0, min(1.0, min(z, self.L - z) / self.run))

    def stamp(self, x, z):
        return self.crest - self.H * self.cross(x) * self.open_end(z)

    def shell(self, x, z):
        return self.stamp(x, z) + SHELL_LIFT * self.open_end(z)

    def col_y(self, x, z):
        return self.stamp(x, z) - COL_DROP * self.open_end(z)

    def steep(self, x, z):
        """Whether the stamp is steeper than CARVE_DEG at (x, z), from its gradient by central differences."""
        e = 0.05
        gx = (self.stamp(x + e, z) - self.stamp(x - e, z)) / (2 * e)
        gz = (self.stamp(x, z + e) - self.stamp(x, z - e)) / (2 * e)
        return math.hypot(gx, gz) > math.tan(math.radians(CARVE_DEG))

    def xs(self, n_floor, n_wall):
        hw = self.W / 2
        if self.kind == "channel":
            f = hw - self.wall
            wall = [f + self.wall * i / n_wall for i in range(1, n_wall + 1)]
        else:
            f = 0.2 * self.W
            wall = [f + (hw - f) * i / n_wall for i in range(1, n_wall + 1)]
        floor = [-f + 2 * f * i / n_floor for i in range(n_floor + 1)]
        if self.chained:
            edge = [f] + wall
            wall = [w for a, b in zip(edge, edge[1:]) for w in ((0.5 * (a + b), b) if b > hw - CREST_BAND + 1e-9 else (b,))]
        return [-x for x in reversed(wall)] + floor + wall

    def band_x(self, xs):
        """|x| where a chained piece's crest band starts: its last wall node inside CREST_BAND of the crest, None on other pieces."""
        if not self.chained:
            return None
        return max(abs(x) for x in xs if abs(x) <= self.W / 2 - CREST_BAND + 1e-9 and abs(x) > 0.2 * self.W)

    def fine_zs(self, zs):
        """zs with every interval split to at most BAND_STEP, so the crest band's rows nest in the coarse rows' edges."""
        out = []
        for a, b in zip(zs, zs[1:]):
            n = max(1, math.ceil((b - a) / BAND_STEP - 1e-9))
            out += [a + (b - a) * i / n for i in range(n)]
        return sorted(set(round(z, 6) for z in out + [zs[-1]]))

    def zs(self, end_step, mid_step):
        n_end = max(4, math.ceil(self.run / end_step))
        ends = [self.run * i / n_end for i in range(n_end + 1)]
        mid = self.L - 2 * self.run
        n_mid = max(1, round(mid / mid_step))
        middle = [self.run + mid * i / n_mid for i in range(n_mid + 1)]
        out = ends + middle + [self.L - z for z in ends]
        return sorted(set(round(z, 6) for z in out))


PIECES = {
    "lava_channel": Piece("lava_channel", 58, 4, 28, "wash", "lava", chained=True),
    "lava_trench_420x6x40": Piece("lava_trench_420x6x40", 420, 6, 40, "channel", "lava"),
    "dry_wash_1500x4x60": Piece("dry_wash_1500x4x60", 1500, 4, 60, "wash", "dry"),
}
GRID = {
    "lava_channel": (14, 12, 1.0, 2.0),
    "lava_trench_420x6x40": (12, 4, 2.0, 10.0),
    "dry_wash_1500x4x60": (10, 7, 4.0, 40.0),
}


def lava_colour(p, x, z):
    """Basalt with ropy folds bowed downstream, the hot seam wandering down the floor, walls banded by depth, the glassy
    carve band where the stamp is too steep to stand on, a cinder rim. Sampled at each vertex, so bands blend."""
    depth = -p.stamp(x, z) / p.H if p.open_end(z) > 0 else 0.0
    t = abs(2.0 * x / p.W)
    fold = 0.5 + 0.5 * math.sin(2.1 * (z - 0.09 * x * x * 28.0 / p.W) + 0.9 * math.sin(0.27 * z + 0.6 * x))
    rock = lerp(col("basalt_lo"), col("basalt_hi"), 0.25 + 0.6 * fold)
    if p.steep(x, z):
        streak = 0.5 + 0.5 * math.sin(4.3 * abs(x) + 0.5 * math.sin(0.17 * z + x))
        return lerp(col("glass"), col("glass_hi"), 0.6 * streak ** 3)
    if p.cross(x) >= 0.999:
        seam = abs(x + 1.1 * math.sin(0.19 * z) + 0.5 * math.sin(0.61 * z + 1.1))
        glow = max(0.0, 1.0 - seam / max(0.9, 0.04 * p.W))
        crust = 0.55 + 0.45 * math.sin(1.7 * z + 3.0 * x)
        c = lerp(rock, col("lava_deep"), min(1.0, 2.0 * glow))
        return lerp(c, lerp(col("lava"), col("lava_hot"), crust), max(0.0, 2.0 * glow - 1.0))
    band = 0.5 + 0.5 * math.sin(depth * 11.0 + 0.35 * math.sin(0.3 * z))
    c = lerp(rock, col("scoria"), 0.75 * band * band)
    return lerp(c, col("cinder"), max(0.0, min(1.0, (t - 0.86) / 0.1)))


def dry_colour(p, x, z):
    """Silt and sand with gravel bars along the floor and a damp thread down its middle; the carve band in packed caliche."""
    if p.steep(x, z):
        return lerp(col("bone"), col("sand"), 0.3 + 0.3 * math.sin(0.4 * z))
    bar = 0.5 + 0.5 * math.sin(0.07 * z + 0.4 * x + 1.3 * math.sin(0.021 * z))
    c = lerp(col("silt"), col("sand"), 0.5 + 0.5 * math.sin(0.13 * z - 0.2 * x))
    c = lerp(c, col("gravel"), 0.6 * max(0.0, bar - 0.6) / 0.4)
    thread = abs(x - 6.0 * math.sin(0.011 * z) - 2.0 * math.sin(0.05 * z))
    return lerp(c, col("damp"), max(0.0, 1.0 - thread / 2.5) * 0.8)


def colour(p, x, z):
    return lava_colour(p, x, z) if p.look == "lava" else dry_colour(p, x, z)


def build_base(p):
    s = Surf(p.id)
    nf, nw, es, ms = GRID[p.id]
    xs, zs = p.xs(nf, nw), p.zs(es, ms)
    xb = p.band_x(xs)
    zf = p.fine_zs(zs) if xb is not None else zs

    def vert(x, z):
        return (x, p.shell(x, z), z)

    def emit(a, b, c):
        pts = [vert(*a), vert(*b), vert(*c)]
        s.poly(pts, [colour(p, q[0], q[2]) for q in pts], up=UP)

    for z0, z1 in zip(zs, zs[1:]):
        inner = [z for z in zf if z0 < z < z1]
        for x0, x1 in zip(xs, xs[1:]):
            if xb is not None and min(abs(x0), abs(x1)) >= xb - 1e-9:
                zl = [z0] + inner + [z1]
                for za, zb in zip(zl, zl[1:]):
                    pts = [vert(x0, za), vert(x0, zb), vert(x1, zb), vert(x1, za)]
                    s.poly(pts, [colour(p, q[0], q[2]) for q in pts], up=UP)
                continue
            seam = xb is not None and inner and {abs(x0), abs(x1)} & {xb} and max(abs(x0), abs(x1)) < p.W / 2 and min(abs(x0), abs(x1)) < xb - 1e-9
            if not seam:
                pts = [vert(x0, z0), vert(x0, z1), vert(x1, z1), vert(x1, z0)]
                s.poly(pts, [colour(p, q[0], q[2]) for q in pts], up=UP)
                continue
            xa, xe = (x0, x1) if abs(x1) > abs(x0) else (x1, x0)
            edge = [z0] + inner + [z1]
            c = min(range(len(edge)), key=lambda k: abs(edge[k] - 0.5 * (z0 + z1)))
            for k in range(c):
                emit((xa, z0), (xe, edge[k]), (xe, edge[k + 1]))
            emit((xa, z0), (xe, edge[c]), (xa, z1))
            for k in range(c, len(edge) - 1):
                emit((xa, z1), (xe, edge[k]), (xe, edge[k + 1]))
        for sign in (-1, 1):
            x = sign * p.W / 2
            zl = [z0] + [z for z in zf if z0 < z < z1] + [z1]
            for za, zb in zip(zl, zl[1:]):
                s.poly([(x, p.shell(x, za), za), (x, p.shell(x, zb), zb), (x, p.shell(x, zb) - SKIRT, zb), (x, p.shell(x, za) - SKIRT, za)],
                       col("cinder" if p.look == "lava" else "sand"), inside=(0.0, -p.H, 0.5 * (za + zb)))
    return s


def build_col(p):
    s = Surf(p.id + "-col")
    if p.chained:
        for z0 in (0.0, p.L - END_SLAB[1]):
            s.box((0.0, -END_SLAB[0], z0 + END_SLAB[1] / 2), (p.W, END_SLAB[1], END_SLAB[1]), col("basalt"))
        return s
    nf, nw, es, ms = GRID[p.id]
    xs, zs = p.xs(4, nw), p.zs(es, ms)
    for z0, z1 in zip(zs, zs[1:]):
        for x0, x1 in zip(xs, xs[1:]):
            s.poly([(x0, p.col_y(x0, z0), z0), (x0, p.col_y(x0, z1), z1), (x1, p.col_y(x1, z1), z1), (x1, p.col_y(x1, z0), z0)], col("basalt"), up=UP)
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


def rim_rock(s, p, sign, q, n, seed, size, tones):
    """A boulder past the crest: its inner face at least CREST_CLEAR beyond the footprint's side."""
    hw = p.W / 2
    z = p.z_lo + p.z_span * (q + 0.3 + 0.4 * rnd(q, sign, seed)) / n
    sz = size[0] + size[1] * rnd(q, sign, seed + 1)
    x = sign * (hw + CREST_CLEAR + 0.75 * sz + 3.5 * rnd(q, sign, seed + 2))
    s.chunk((x, -0.2, z), (sz, sz * 0.6, sz * 0.9), rnd(q, sign, seed + 3) * math.tau, seed * 7 + q + 50 * sign,
            lerp(col(tones[0]), col(tones[1]), rnd(q, sign, seed + 4)), top=0.65)


def on_crest(s, p):
    """Lift what stands beyond the footprint (rim rocks, cones, stakes, cinders) onto the crest: y 0 of a stamp liner is the
    plain, of a chained piece its floor."""
    if p.crest:
        s.v = [(x, y + p.crest, z) if abs(x) >= p.W / 2 else (x, y, z) for x, y, z in s.v]


def build_d1(p):
    s = Surf(p.id + "_detail1")
    hw = p.W / 2
    n = 26 if p.L < 100 else 30
    n_rock = max(1, round(n * p.z_span / p.L))
    for sign in (-1, 1):
        for q in range(n_rock):
            rim_rock(s, p, sign, q, n_rock, 1, (0.5, 1.1), ("basalt", "basalt_hi") if p.look == "lava" else ("gravel", "sandstone"))
        if p.look == "lava":
            for q in range(3):
                r = 1.1 + 0.5 * rnd(q, sign, 7)
                spatter_cone(s, sign * (hw + CREST_CLEAR + r + 2.0 * rnd(q, sign, 6)), p.z_lo + p.z_span * (0.2 + 0.3 * q) + 3.0 * sign, r, 1.2 + 0.8 * rnd(q, sign, 8), q + 9 * sign)
    stake(s, -hw - 1.2, p.z_lo + 1.5)
    stake(s, hw + 1.2, p.z_lo + p.z_span - 1.5)
    if p.look == "lava":
        kettle(s, hw + 2.6, p.z_lo + 6.0)
    assert len(s.t) <= SHELL_BUDGET[0], (s.name, len(s.t))
    on_crest(s, p)
    return s


def lerp_f(a, b, t):
    return a + (b - a) * t


def floor_strip(s, p, pts, w, color, fine=True):
    """A painted strip on the shell through the plan points pts, PAINT_PROUD over it."""
    path = [pts[0]]
    for (xa, za), (xb, zb) in zip(pts, pts[1:]):
        ln = math.hypot(xb - xa, zb - za)
        near = fine and min(abs(z - k) for z in (za, zb) for k in (p.run, p.L - p.run)) < ln + 0.5
        n = max(1, math.ceil(ln / 0.25)) if near else 1
        path += [(lerp_f(xa, xb, i / n), lerp_f(za, zb, i / n)) for i in range(1, n + 1)]
    for (xa, za), (xb, zb) in zip(path, path[1:]):
        dx, dz = xb - xa, zb - za
        ln = math.hypot(dx, dz)
        nx, nz = -dz / ln * w / 2, dx / ln * w / 2
        quad = [(xa - nx, za - nz), (xb - nx, zb - nz), (xb + nx, zb + nz), (xa + nx, za + nz)]
        s.poly([(x, p.shell(x, z) + PAINT_PROUD, z) for x, z in quad], color, up=UP)


def build_d2(p):
    s = Surf(p.id + "_detail2")
    hw = p.W / 2
    flat = 0.18 * p.W if p.kind == "wash" else hw - p.wall - 0.5
    for q in range(28):
        z0 = p.run * 1.05 + (p.L - 2.1 * p.run) * (q + rnd(q, 1)) / 28
        side = -1 if q % 2 else 1
        x = side * (0.5 + 0.6 * rnd(q, 2))
        pts = [(x, z0)]
        for step in range(4):
            x += side * (0.6 + 0.5 * rnd(q, step, 3))
            pts.append((min(flat, max(-flat, x)), z0 + (rnd(q, step, 4) - 0.3) * 1.4 * (step + 1)))
        hot = col("lava" if q % 3 else "lava_hot") if p.look == "lava" else col("damp")
        floor_strip(s, p, pts, 0.09, hot)
    zs = p.zs(*GRID[p.id][2:])
    for sign in ((-1, 1) if p.carve_x < p.W / 2 - 0.01 else ()):
        x = sign * (p.carve_x - 0.2)
        floor_strip(s, p, [(x, z) for z in zs], 0.4, col("bone"), fine=False)
    for q in range(40 if p.look == "lava" else 0):
        x = 2.4 * (rnd(q, 11) - 0.5) * 2
        z = p.run + (p.L - 2 * p.run) * (q + rnd(q, 12)) / 40
        floor_strip(s, p, [(x, z), (x + 0.25 * (rnd(q, 13) - 0.5), z + 0.3)], 0.22, lerp(col("cinder"), col("ash"), rnd(q, 14)))
    n_grit = max(1, round(26 * p.z_span / p.L))
    for sign in (-1, 1):
        for q in range(n_grit):
            z = p.z_lo + p.z_span * (q + rnd(q, sign, 5)) / n_grit
            sz = 0.12 + 0.22 * rnd(q, sign, 7)
            x = sign * (hw + CREST_CLEAR + 0.6 * sz + 2.6 * rnd(q, sign, 6))
            tones = ("cinder", "scoria") if p.look == "lava" else ("gravel", "bone")
            s.chunk((x, -0.02, z), (sz, sz * 0.6, sz), rnd(q, sign, 8) * math.tau, 400 + q + 90 * sign,
                    lerp(col(tones[0]), col(tones[1]), rnd(q, sign, 9)), top=0.6)
    assert len(s.t) <= SHELL_BUDGET[0], (s.name, len(s.t))
    on_crest(s, p)
    return s


CHUTE = {"id": "lava_chute_3x0p5x8", "L": 3.0, "H": 0.5, "W": 8.0}


def chute_top(x):
    """The trough's ridden top: a half-pipe from the floor (y 0 across the middle 40 percent) to H at the sides."""
    t = min(1.0, abs(2.0 * x / CHUTE["W"]))
    if t <= 0.4:
        return 0.0
    w = (t - 0.4) / 0.6
    return CHUTE["H"] * w * w


def chute_xs():
    hw = CHUTE["W"] / 2
    return [-hw + CHUTE["W"] * i / 20 for i in range(21)]


def build_chute_base(_p=None):
    s = Surf(CHUTE["id"])
    L, hw = CHUTE["L"], CHUTE["W"] / 2
    xs = chute_xs()
    zs = [L * j / 12 for j in range(13)]

    def tone(x, z):
        glow = max(0.0, 1.0 - abs(x + 0.3 * math.sin(2.0 * z)) / 0.6)
        rock = col("glass") if chute_top(x) > 0.06 else lerp(col("basalt_lo"), col("basalt_hi"), 0.5 + 0.5 * math.sin(3.0 * z + x))
        return lerp(rock, lerp(col("lava_deep"), col("lava_hot"), glow), min(1.0, 1.6 * glow))

    for z0, z1 in zip(zs, zs[1:]):
        for x0, x1 in zip(xs, xs[1:]):
            pts = [(x0, chute_top(x0), z0), (x0, chute_top(x0), z1), (x1, chute_top(x1), z1), (x1, chute_top(x1), z0)]
            s.poly(pts, [tone(q[0], q[2]) for q in pts], up=UP)
    inside = (0.0, -0.4, L / 2)
    for z, flip in ((0.0, 1), (L, -1)):
        for x0, x1 in zip(xs, xs[1:]):
            s.poly([(x0, -0.4, z), (x1, -0.4, z), (x1, chute_top(x1), z), (x0, chute_top(x0), z)], col("basalt"), inside=inside)
    for sign in (-1, 1):
        s.poly([(sign * hw, -0.4, 0.0), (sign * hw, -0.4, L), (sign * hw, CHUTE["H"], L), (sign * hw, CHUTE["H"], 0.0)], col("scoria"), inside=inside)
    s.poly([(-hw, -0.4, 0.0), (hw, -0.4, 0.0), (hw, -0.4, L), (-hw, -0.4, L)], col("basalt_lo"), up=(0.0, -1.0, 0.0))
    return s


def build_chute_col(_p=None):
    s = Surf(CHUTE["id"] + "-col")
    L = CHUTE["L"]
    xs = chute_xs()
    for x0, x1 in zip(xs, xs[1:]):
        s.poly([(x0, chute_top(x0), 0.0), (x0, chute_top(x0), L), (x1, chute_top(x1), L), (x1, chute_top(x1), 0.0)], col("basalt"), up=UP)
    return s


def build_chute_d1(_p=None):
    s = Surf(CHUTE["id"] + "_detail1")
    hw = CHUTE["W"] / 2
    for sign in (-1, 1):
        for q in range(4):
            sz = 0.3 + 0.3 * rnd(q, sign, 1)
            s.chunk((sign * (hw + CREST_CLEAR + 0.75 * sz), -0.4, 0.4 + 0.75 * q), (sz, sz * 0.7, sz), rnd(q, sign, 2) * math.tau, q + 9 * sign,
                    lerp(col("basalt"), col("scoria"), rnd(q, sign, 3)), top=0.65)
    return s


def build_chute_d2(_p=None):
    s = Surf(CHUTE["id"] + "_detail2")
    hw = CHUTE["W"] / 2
    for sign in (-1, 1):
        for q in range(10):
            sz = 0.08 + 0.12 * rnd(q, sign, 1)
            s.chunk((sign * (hw + CREST_CLEAR + 0.5 + 0.8 * rnd(q, sign, 2)), -0.4, 0.15 + 0.28 * q), (sz, sz * 0.6, sz), 0.0, 200 + q + 9 * sign, col("cinder"), top=0.6)
    return s


def check_piece(p, base, col_s, shells):
    """The shell is the stamp lifted SHELL_LIFT and the -col the stamp dropped COL_DROP, both tapering with the open ends;
    no shell stands more than SHELL_PROUD over the drawn surface inside the footprint."""
    probes = [(-p.W / 2 + p.W * (i + 0.41) / 37, p.L * (j + 0.27) / 61) for i in range(37) for j in range(61)]
    worst = 0.0
    for x, z in probes:
        h_col = si.height_at(col_s, x, z)
        h_view = si.height_at(base, x, z)
        if p.chained:
            assert h_col is None or h_col <= -END_SLAB[0] + END_SLAB[1] + 1e-6, (p.id, "chained col in the ride", x, z, h_col)
            assert h_view is not None and abs(h_view - p.shell(x, z)) < 0.03 + 0.01 * p.H, (p.id, "shell", x, z, h_view, p.shell(x, z))
            worst = max(worst, abs(h_view - p.shell(x, z)))
            continue
        assert h_col is not None and abs(h_col - p.col_y(x, z)) < 0.03 + 0.01 * p.H, (p.id, "col", x, z, h_col, p.col_y(x, z))
        assert h_col <= p.stamp(x, z) + 0.02, (p.id, "col over the stamp", x, z, h_col, p.stamp(x, z))
        assert h_view is not None and abs(h_view - p.shell(x, z)) < 0.03 + 0.01 * p.H, (p.id, "shell", x, z, h_view, p.shell(x, z))
        assert h_view >= p.stamp(x, z) - 0.01, (p.id, "shell under the stamp", x, z, h_view, p.stamp(x, z))
        worst = max(worst, abs(h_view - p.shell(x, z)))
    for shell in shells:
        for x, z in probes[::2]:
            h_sh = si.height_at(shell, x, z)
            assert h_sh is None or h_sh - si.height_at(base, x, z) <= SHELL_PROUD + 1e-6, (p.id, "shell proud", shell.name, x, z, h_sh)
        for x, y, z in shell.v:
            if abs(x) < p.W / 2 and 0.0 < z < p.L:
                assert y - p.shell(x, z) <= SHELL_PROUD + 1e-6, (p.id, "shell vertex in the lane", shell.name, x, y, z)
            elif p.chained and abs(x) >= p.W / 2:
                assert END_ZONE / MIN_STRETCH <= z <= p.L - END_ZONE / MIN_STRETCH, (p.id, "prop in the end zone", shell.name, x, y, z)
    return worst


def check_chute(base, col_s, shells):
    hw = CHUTE["W"] / 2
    probes = [(-hw + CHUTE["W"] * (i + 0.41) / 29, CHUTE["L"] * (j + 0.27) / 11) for i in range(29) for j in range(11)]
    for x, z in probes:
        h_col = si.height_at(col_s, x, z)
        h_view = si.height_at(base, x, z)
        assert h_col is not None and abs(h_col - chute_top(x)) < 0.01 and h_view is not None and abs(h_view - h_col) < 1e-4, ("chute", x, z, h_col, h_view)
    for shell in shells:
        for x, z in probes:
            assert si.height_at(shell, x, z) is None, ("chute shell in the lane", shell.name, x, z)
    return 0.0


ROWS_JSON = HERE.parents[2] / "src" / "world" / "park" / "park_sinkhole.json"


def check_rows(path=ROWS_JSON):
    """The end zone holds only for the rows it was measured on: fail the build, naming the row, if a lava_channel row is shorter
    than MIN_STRETCH of the piece or turns more than MAX_BEND_DEG from its chained neighbour."""
    if not Path(path).is_file():
        raise SystemExit("lavachannels: %s missing, cannot check the lava_channel rows against END_ZONE" % path)
    rows = [r for r in json.loads(Path(path).read_text())["park_rows"] if r.get("recipe") == "lava_channel"]
    assert rows, ("no lava_channel rows in", str(path))
    prev = None
    for r in rows:
        assert r["size"][0] / PIECES["lava_channel"].L >= MIN_STRETCH - 1e-9, (r["id"], "row shorter than MIN_STRETCH of the piece", r["size"][0])
        if prev is not None:
            bend = abs((r["yaw_deg"] - prev["yaw_deg"] + 180.0) % 360.0 - 180.0)
            assert bend <= MAX_BEND_DEG + 1e-9, (prev["id"], r["id"], "bend over MAX_BEND_DEG", bend)
        prev = r
    return len(rows)


RECIPES = list(PIECES) + [CHUTE["id"]]


def build(rid, out_dir, count_only=False):
    if rid == CHUTE["id"]:
        base, col_s = build_chute_base(), build_chute_col()
        shells = [build_chute_d1(), build_chute_d2()]
        size = [CHUTE["L"], CHUTE["H"], CHUTE["W"]]
        want = ((-CHUTE["W"] / 2, 0.0, 0.0), (CHUTE["W"] / 2, CHUTE["H"], CHUTE["L"]))
        worst = check_chute(base, col_s, shells)
    else:
        p = PIECES[rid]
        base, col_s = build_base(p), build_col(p)
        shells = [build_d1(p), build_d2(p)]
        size = [p.L, p.H, p.W]
        want = (((-p.W / 2, -END_SLAB[0], 0.0), (p.W / 2, -END_SLAB[0] + END_SLAB[1], p.L)) if p.chained
                else ((-p.W / 2, -p.H - COL_DROP, 0.0), (p.W / 2, 0.0, p.L)))
        worst = check_piece(p, base, col_s, shells)
    cap_t, cap_v = BUDGET
    assert len(base.t) + len(col_s.t) <= cap_t, (rid, "base+col triangles", len(base.t), len(col_s.t), cap_t)
    assert len(base.v) + len(col_s.v) <= cap_v, (rid, "vertices", len(base.v) + len(col_s.v), cap_v)
    for sh in shells:
        assert len(sh.t) <= SHELL_BUDGET[0] and len(sh.v) <= SHELL_BUDGET[1], (sh.name, len(sh.t), len(sh.v))
    row = {"recipe": rid, "size": size, "carve_x_m": round(p.carve_x, 3) if rid in PIECES else None, "seat_m": [0.75 * size[0], 1.5 * size[0]], "shell_vs_profile_worst_m": round(worst, 5),
           "counts": {s.name: {"tris": len(s.t), "verts": len(s.v)} for s in [base, col_s] + shells}}
    if count_only:
        return row
    row["glb"] = {rid: si.export(rid, [(base, "elastomer"), (col_s, None)], out_dir)}
    for n, sh in enumerate(shells, start=1):
        row["glb"][f"{rid}_detail{n}"] = si.export(f"{rid}_detail{n}", [(sh, "elastomer")], out_dir)
    g = row["glb"][rid]
    render, colm = g["meshes"][rid], g["meshes"][rid + "-col"]
    assert g["materials"] == ["elastomer"] and render["draws"] == 1 and colm["draws"] == 1, (g["materials"], render, colm)
    for a in range(3):
        assert abs(colm["min"][a] - want[0][a]) <= 0.02 and abs(colm["max"][a] - want[1][a]) <= 0.02, (rid, "col extent", colm["min"], colm["max"], want)
    return row


def main():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    parser = argparse.ArgumentParser()
    parser.add_argument("--out", default=str(si.MODELS))
    parser.add_argument("--count-only", action="store_true")
    parser.add_argument("--recipe", default="all")
    args = parser.parse_args(argv)
    ids = RECIPES if args.recipe == "all" else args.recipe.split(",")
    if "lava_channel" in ids:
        print("LAVACHANNELS rows checked", check_rows())
    log = [build(rid, args.out, args.count_only) for rid in ids]
    for row in log:
        print("LAVACHANNELS", row["recipe"], json.dumps({k: v for k, v in row.items() if k != "glb"}, sort_keys=True))
    if not args.count_only:
        print("LAVACHANNELS_SHA256", json.dumps({f: g["sha256"] for r in log for f, g in r["glb"].items()}, sort_keys=True))


if __name__ == "__main__":
    main()
