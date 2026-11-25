"""Headless recipe for the flooded-cavern family of design-v3/PARK.md section 4 (unit KC5): cenote_pool, flooded_shaft and
cavern_shell, each with two detail shells and a -col trimesh. Karst sinkholes, cenote pools and timbered flooded drifts, in
the Southwest palette (sandstone and limestone grey-cream, iron-oxide timber, copper pipe and anchor eyes; never brass).

Convention (the same for every park recipe family): +Y up, the ride direction is +Z (the fall line), the origin sits on the
entry lip at the ground centre (x 0, y 0, z 0), so a park row places the recipe with its position, size and yaw. The recipe
runs from z 0 (entry ring) to z LENGTH (exit ring) and spans x -WIDTH/2 .. WIDTH/2 around the centre line. Floors lie at
or below y 0; a pool is a dip in a flat shelf with the water sheet at the shelf's level, so its depth is the dip: at most
POOL_DEPTH (1.1 m), under the 1.2 m a ball rolls out of (PARK.md:294, :357).

  recipe          nominal L x H x W (m)   stage row it matches                         ride
  cenote_pool     70 x 20 x 60            park_sinkhole west_cenote (70, 20, 60)       scree ramp, pool, falling runout
  flooded_shaft   80 x 24 x 16            none yet (caisson_bowl is a greybox)         timbered decline, sump, flat runout
  cavern_shell    190 x 16 x 30           park_sinkhole west_gallery_1 (190, 16, 30)   gallery with two steps and a pool

Files per recipe (the loader's names, park_recipes.paths): <recipe>.glb = a "Rock" mesh (slot stone: shell, stalactites,
timbers, pipe and anchor eyes, painted by vertex colour), a "Water" mesh (slot glass: the flat sheet, teal vertex colour), a
"<recipe>-col-col" trimesh node (the floor, walls, roof at half the ring density, timbers, anchor stalactites and a block at
each anchor eye so the harpoon's world ray bites it, never drawn; Godot strips
one "-col" on import, so the imported node is "<recipe>-col" with its StaticBody3D and trimesh, the name park_recipes.gd looks for) and Anchor.NN empties (Godot
imports them as Anchor_NN); <recipe>_detail1.glb and <recipe>_detail2.glb = additive stone shells at the same origin (class
detail). Stalactite anchors: a copper eye hangs from each anchor stalactite's tip, the Anchor.NN empty at the eye's centre;
shaft anchors hang from the cap beams the same way. One meaning, one look: a copper ring is a harpoon bite.

The ride line is the centre line (x 0): the ball arrives rolling at y 0 at z 0. The floor is smooth along it (no ring vertex
over 0.12 m off the analytic floor inside the lane |x| < LANE), the detail shells keep a lane clear of anything taller than
0.12 m, and the lowest thing hanging in the lane is a shaft anchor eye, 5.4 m above the floor. The check (check_*) fails loud on the pool depth, the lane, the budget and the
anchor gap.

  blender -b --threads 2 --python-exit-code 1 -P sketches/core-loop/tools/blender/park/caverns.py [-- --out-dir DIR]
      [--only RECIPE] [--count-only]
"""
import argparse
import hashlib
import json
import math
from pathlib import Path
import sys

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE.parent))
sys.path.insert(0, str(HERE.parent / "dig_mechanical"))

TAU = math.tau
LANE = 3.5
POOL_DEPTH = 1.1
POOL_LIMIT = 1.2
WATER_BELOW_SHELF = 0.04
PARK_LARGE = [16000, 48000]
DETAIL = [1500, 3000]
COL_NODE = "%s-col-col"
ANCHOR_GAP_MAX = 40.0

TIMBER = (0.50, 0.37, 0.25)
TIMBER_DARK = (0.38, 0.27, 0.18)
COPPER = (0.718, 0.471, 0.263)
WATER = (0.30, 0.52, 0.50)
PLATE = (0.34, 0.33, 0.31)


def smooth(t):
    t = max(0.0, min(1.0, t))
    return t * t * (3.0 - 2.0 * t)


def lerp(a, b, t):
    return a + (b - a) * t


def _hash(i, j, k, s):
    n = (i * 374761393 + j * 668265263 + k * 2147483629 + s * 1274126177) & 0xFFFFFFFF
    n = ((n ^ (n >> 13)) * 1274126177) & 0xFFFFFFFF
    return ((n ^ (n >> 16)) & 0xFFFF) / 65535.0


def vnoise(x, y, z, s=0):
    xi, yi, zi = math.floor(x), math.floor(y), math.floor(z)
    fx, fy, fz = smooth(x - xi), smooth(y - yi), smooth(z - zi)
    out = 0.0
    for dx in (0, 1):
        for dy in (0, 1):
            for dz in (0, 1):
                w = (fx if dx else 1 - fx) * (fy if dy else 1 - fy) * (fz if dz else 1 - fz)
                out += w * _hash(xi + dx, yi + dy, zi + dz, s)
    return out


def fbm(x, y, z, s=0):
    return 0.6 * vnoise(x, y, z, s) + 0.3 * vnoise(x * 2.1, y * 2.1, z * 2.1, s + 7) + 0.1 * vnoise(x * 4.3, y * 4.3, z * 4.3, s + 13)


class Rng:
    """A small deterministic generator (a hash counter), so the shells do not depend on the random module."""

    def __init__(self, seed):
        self.seed, self.n = seed, 0

    def f(self):
        self.n += 1
        return _hash(self.n, self.seed, 91, 5)

    def span(self, lo, hi):
        return lo + (hi - lo) * self.f()


def path_y(points, z):
    """Piecewise smoothstep through (z, y) control points: flat tangents at every point, so a shelf is truly flat."""
    if z <= points[0][0]:
        return points[0][1]
    for (z0, y0), (z1, y1) in zip(points, points[1:]):
        if z <= z1:
            return lerp(y0, y1, smooth((z - z0) / (z1 - z0)))
    return points[-1][1]


class Hall:
    """One swept recipe: a ring of N points per station z, lower half a superellipse floor and walls, upper half a roof."""

    def __init__(self, name, length, width, dz, n_points, path, n_floor, n_roof, rise, amp_wall, amp_roof, seed,
                 half=None, spring=None, roof_open=None, pool=None, rim_lock=False):
        self.name, self.length, self.width, self.dz, self.N = name, length, width, dz, n_points
        self.path, self.n_floor, self.n_roof, self.rise = path, n_floor, n_roof, rise
        self.amp_wall, self.amp_roof, self.seed = amp_wall, amp_roof, seed
        self._half, self._spring, self._open, self.pool = half, spring, roof_open, pool
        self.rim_lock = rim_lock
        assert round(length / dz) % 2 == 0, "an even interval count, so the -col stride 2 lands on the exit ring"
        self.rings = round(length / dz) + 1

    def half(self, z):
        return self._half(z) if self._half else self.width / 2

    def floor_c(self, z):
        return path_y(self.path, z)

    def spring(self, z):
        yc = self.floor_c(z)
        sl = self._spring(z) if self._spring else yc + 3.0
        return max(sl, yc + 0.6)

    def roof_open(self, x, z):
        return bool(self._open and self._open(x, z))

    def dip(self, z, xn):
        if not self.pool:
            return 0.0
        z0, z1 = self.pool
        if z <= z0 or z >= z1:
            return 0.0
        t = (z - z0) / (z1 - z0)
        bx = 1.0 if xn <= 0.3 else (math.cos(min(1.0, (xn - 0.3) / 0.35) * math.pi / 2) ** 2 if xn < 0.65 else 0.0)
        return POOL_DEPTH * math.sin(math.pi * t) ** 2 * bx

    def shelf(self):
        """The flat shelf level under the pool, which is also the water level plus WATER_BELOW_SHELF."""
        z0, z1 = self.pool
        return self.floor_c((z0 + z1) / 2)

    def water_y(self):
        return self.shelf() - WATER_BELOW_SHELF

    def floor_y(self, x, z):
        """The analytic floor height at (x, z) inside the lower half, pool dip included."""
        a, yc, sl = self.half(z), self.floor_c(z), self.spring(z)
        b = sl - yc
        xn = min(abs(x) / a, 1.0)
        return sl - b * (1.0 - xn ** self.n_floor) ** (1.0 / self.n_floor) - self.dip(z, xn)

    def point(self, z, u, noisy=True):
        """The ring point at station z and angle u (0 = floor centre, +x side first, pi = roof apex)."""
        a, yc, sl = self.half(z), self.floor_c(z), self.spring(z)
        b = sl - yc
        s, c = math.sin(u), math.cos(u)
        lower = c >= 0.0
        n = self.n_floor if lower else self.n_roof
        e = 2.0 / n
        x = a * math.copysign(abs(s) ** e, s)
        if lower:
            y = sl - b * abs(c) ** e - self.dip(z, abs(x) / a)
            yb = b
        else:
            y = sl + self.rise(z) * abs(c) ** e
            yb = self.rise(z)
        if noisy:
            ua = abs(((u + math.pi) % TAU) - math.pi)
            mask = smooth((ua - 0.45) / 0.65) if lower else 1.0
            if self.rim_lock:
                mask *= smooth(abs(ua - math.pi / 2) / 0.5)
            if mask > 0.0:
                amp = lerp(self.amp_wall, self.amp_roof, smooth((ua - (math.pi / 2 - 0.3)) / 0.6))
                d = amp * (2.0 * fbm(x * 0.11, y * 0.11, z * 0.09, self.seed) - 1.0) * mask
                nx, ny = x / (a * a), (y - sl) / (yb * yb) if yb > 1e-6 else 0.0
                ln = math.hypot(nx, ny) or 1.0
                x, y = x + nx / ln * d, y + ny / ln * d
        return x, y, z

    def tone(self, z, u, x, y):
        ua = abs(((u + math.pi) % TAU) - math.pi)
        if ua < 0.6:
            v = 0.96
        elif ua < 1.6:
            v = lerp(0.96, 0.78, (ua - 0.6))
        else:
            v = lerp(0.78, 0.56, (ua - 1.6) / (math.pi - 1.6))
        v *= 1.0 + 0.18 * (fbm(x * 0.2, y * 0.2, z * 0.2, self.seed + 3) - 0.5)
        if math.cos(u) >= 0.0:
            wet = self.dip(z, min(abs(x) / self.half(z), 1.0)) / POOL_DEPTH if self.pool else 0.0
            v *= 1.0 - 0.32 * wet
        return (v, v * 0.965, v * 0.915)


def cenote_pool():
    def roof_open(x, z):
        ring = (x / 17.0) ** 2 + ((z - 33.0) / 13.0) ** 2
        return z < 14.0 or z > 58.0 or ring < 1.0 + 0.35 * (fbm(x * 0.2, 0.0, z * 0.2, 41) - 0.5)

    return Hall("cenote_pool", 70.0, 60.0, 1.25, 40, [(0, 0), (3, 0), (24, -9), (52, -9), (70, -11.5)], 5.0, 3.0,
                lambda z: 1.5, 1.5, 1.0, 11, half=lambda z: 27.0 + 1.5 * (2.0 * fbm(0, 0, z * 0.05, 21) - 1.0),
                spring=lambda z: 0.0, roof_open=roof_open, pool=(27.0, 49.0), rim_lock=True)


def flooded_shaft():
    return Hall("flooded_shaft", 80.0, 16.0, 1.25, 24, [(0, 0), (4, 0), (30, -9), (34, -9), (62, -9), (80, -9)], 8.0, 8.0,
                lambda z: 3.8, 0.10, 0.10, 17, half=lambda z: 7.85, spring=lambda z: path_y(
                    [(0, 0), (4, 0), (30, -9), (34, -9), (62, -9), (80, -9)], z) + 3.2, pool=(38.0, 58.0))


def cavern_shell():
    path = [(0, 0), (10, 0), (46, -2.6), (56, -4.6), (72, -4.6), (106, -4.6), (150, -7.2), (160, -9.0), (190, -9.0)]
    return Hall("cavern_shell", 190.0, 30.0, 1.9, 36, path, 3.2, 2.4, lambda z: 8.0, 1.1, 1.4, 29,
                half=lambda z: 12.5 + 1.2 * (2.0 * fbm(0, 0, z * 0.04, 23) - 1.0), spring=lambda z: path_y(path, z) + 8.0,
                pool=(76.0, 100.0))


HALLS = {"cenote_pool": cenote_pool, "flooded_shaft": flooded_shaft, "cavern_shell": cavern_shell}

ANCHORS = {
    "cenote_pool": [(20, -2.36), (26, 2.36), (32, -2.36), (38, 2.36), (44, -2.36), (50, 2.36)],
    "cavern_shell": [(10 + 13.3 * k, (2.7 if k % 2 == 0 else -2.7) + (0.35 if k % 3 == 0 else 0.0)) for k in range(14)],
    "flooded_shaft": [(11 + 12 * k, 0.0) for k in range(6)],
}
TIMBER_STATIONS = [5 + 6 * k for k in range(13)]


class Soup:
    def __init__(self):
        self.v, self.c, self.t = [], [], []

    def vert(self, p, color):
        self.v.append((float(p[0]), float(p[1]), float(p[2])))
        self.c.append(color)
        return len(self.v) - 1

    def tri(self, a, b, c):
        self.t.append((a, b, c))

    def quad(self, a, b, c, d):
        self.tri(a, b, c)
        self.tri(a, c, d)

    def grid(self, rows, closed, keep=None):
        """rows[k][j] are vertex indices; quad (k, j) between rows k, k+1 and columns j, j+1 (wrapping when closed). The
        winding gives normals up on a floor swept toward +z with j rising toward +x, so a ring faces inward."""
        for k in range(len(rows) - 1):
            cols = len(rows[k]) if closed else len(rows[k]) - 1
            for j in range(cols):
                j1 = (j + 1) % len(rows[k])
                if keep is not None and not keep(k, j):
                    continue
                p00, p01, p10, p11 = rows[k][j], rows[k][j1], rows[k + 1][j], rows[k + 1][j1]
                self.tri(p00, p10, p01)
                self.tri(p01, p10, p11)

    def box(self, lo, hi, color):
        """A flat-shaded box, outward faces, its own 24 vertices."""
        x0, y0, z0 = lo
        x1, y1, z1 = hi
        faces = [((x0, y0, z1), (x1, y0, z1), (x1, y1, z1), (x0, y1, z1)), ((x1, y0, z0), (x0, y0, z0), (x0, y1, z0), (x1, y1, z0)),
                 ((x0, y0, z0), (x0, y0, z1), (x0, y1, z1), (x0, y1, z0)), ((x1, y0, z1), (x1, y0, z0), (x1, y1, z0), (x1, y1, z1)),
                 ((x0, y1, z1), (x1, y1, z1), (x1, y1, z0), (x0, y1, z0)), ((x0, y0, z0), (x1, y0, z0), (x1, y0, z1), (x0, y0, z1))]
        for f in faces:
            self.quad(*[self.vert(p, color) for p in f])

    def cone(self, base, radius, length, sides, color, tip_color=None, up=False, mid=0.55, spin=0.0):
        """A two-stage cone from base (a point on the surface) hanging down, or growing up. The base ring is sunk 0.35 m into
        the host so the join is closed."""
        sign = 1.0 if up else -1.0
        bx, by, bz = base
        rings = [(radius, -sign * 0.35), (radius, 0.0), (radius * 0.55, length * mid)]
        idx = []
        for r, d in rings:
            idx.append([self.vert((bx + r * math.cos(spin + TAU * i / sides), by + sign * d, bz + r * math.sin(spin + TAU * i / sides)),
                                  color) for i in range(sides)])
        tip = self.vert((bx, by + sign * length, bz), tip_color or color)
        for r in range(2):
            for i in range(sides):
                i1 = (i + 1) % sides
                a, b, c, d = idx[r][i], idx[r][i1], idx[r + 1][i1], idx[r + 1][i]
                if up:
                    self.quad(a, d, c, b)
                else:
                    self.quad(a, b, c, d)
        for i in range(sides):
            i1 = (i + 1) % sides
            if up:
                self.tri(idx[2][i1], idx[2][i], tip)
            else:
                self.tri(idx[2][i], idx[2][i1], tip)
        return tip

    def rock(self, center, radius, squash, rng, color):
        """A jittered icosahedron: 20 triangles, flat, outward."""
        t = (1 + 5 ** 0.5) / 2
        base = [(-1, t, 0), (1, t, 0), (-1, -t, 0), (1, -t, 0), (0, -1, t), (0, 1, t), (0, -1, -t), (0, 1, -t),
                (t, 0, -1), (t, 0, 1), (-t, 0, -1), (-t, 0, 1)]
        faces = [(0, 11, 5), (0, 5, 1), (0, 1, 7), (0, 7, 10), (0, 10, 11), (1, 5, 9), (5, 11, 4), (11, 10, 2), (10, 7, 6),
                 (7, 1, 8), (3, 9, 4), (3, 4, 2), (3, 2, 6), (3, 6, 8), (3, 8, 9), (4, 9, 5), (2, 4, 11), (6, 2, 10), (8, 6, 7),
                 (9, 8, 1)]
        pts = []
        for p in base:
            ln = math.sqrt(p[0] ** 2 + p[1] ** 2 + p[2] ** 2)
            j = rng.span(0.72, 1.18)
            pts.append((center[0] + p[0] / ln * radius * j, center[1] + p[1] / ln * radius * j * squash,
                        center[2] + p[2] / ln * radius * j * 0.9))
        ids = [self.vert(p, tuple(min(1.0, ch * rng.span(0.9, 1.05)) for ch in color)) for p in pts]
        for f in faces:
            self.tri(*[ids[i] for i in f])

    def pebble(self, center, radius, rng, color):
        """An 8-triangle jittered octahedron, flat."""
        pts = [(1, 0, 0), (-1, 0, 0), (0, 1, 0), (0, -1, 0), (0, 0, 1), (0, 0, -1)]
        pts = [(center[0] + p[0] * radius * rng.span(0.8, 1.2), center[1] + p[1] * radius * 0.6 * rng.span(0.8, 1.2),
                center[2] + p[2] * radius * rng.span(0.8, 1.2)) for p in pts]
        ids = [self.vert(p, color) for p in pts]
        for a, b, c in ((2, 4, 0), (2, 1, 4), (2, 5, 1), (2, 0, 5), (3, 0, 4), (3, 4, 1), (3, 1, 5), (3, 5, 0)):
            self.tri(ids[a], ids[b], ids[c])

    def tube(self, points, radius, sides, color):
        """A tube along a polyline, open ends, outward faces."""
        rows = []
        for i, p in enumerate(points):
            q = points[min(i + 1, len(points) - 1)]
            o = points[max(i - 1, 0)]
            d = (q[0] - o[0], q[1] - o[1], q[2] - o[2])
            ln = math.sqrt(d[0] ** 2 + d[1] ** 2 + d[2] ** 2)
            d = (d[0] / ln, d[1] / ln, d[2] / ln)
            e1 = (1.0, 0.0, 0.0)
            e2 = (d[1] * e1[2] - d[2] * e1[1], d[2] * e1[0] - d[0] * e1[2], d[0] * e1[1] - d[1] * e1[0])
            rows.append([self.vert((p[0] + radius * (math.cos(TAU * s / sides) * e1[0] + math.sin(TAU * s / sides) * e2[0]),
                                    p[1] + radius * (math.cos(TAU * s / sides) * e1[1] + math.sin(TAU * s / sides) * e2[1]),
                                    p[2] + radius * (math.cos(TAU * s / sides) * e1[2] + math.sin(TAU * s / sides) * e2[2])), color)
                         for s in range(sides)])
        for k in range(len(rows) - 1):
            for s in range(sides):
                s1 = (s + 1) % sides
                self.quad(rows[k][s], rows[k][s1], rows[k + 1][s1], rows[k + 1][s])

    def eye(self, center, color, major=0.3, minor=0.07):
        """A copper ring in the xy plane (a hanging D-ring seen from the ride line): 6 x 4 sides, 48 triangles."""
        rows = []
        for m in range(6):
            a = TAU * m / 6
            cx, cy = center[0] + major * math.cos(a), center[1] + major * math.sin(a)
            rows.append([self.vert((cx + minor * math.cos(TAU * s / 4) * math.cos(a), cy + minor * math.cos(TAU * s / 4) * math.sin(a),
                                    center[2] + minor * math.sin(TAU * s / 4)), color) for s in range(4)])
        for m in range(6):
            m1 = (m + 1) % 6
            for s in range(4):
                s1 = (s + 1) % 4
                self.quad(rows[m][s], rows[m1][s], rows[m1][s1], rows[m][s1])


def ring_rows(hall, soup, stride=1, with_color=True):
    """The swept shell as rows of vertex indices, one row per kept station, plus (z, u) per row and column."""
    rows, stations = [], []
    for i in range(0, hall.rings, stride):
        z = min(i * hall.dz, hall.length)
        row = []
        for j in range(hall.N):
            u = TAU * j / hall.N
            x, y, zz = hall.point(z, u)
            row.append(soup.vert((x, y, zz), hall.tone(z, u, x, y) if with_color else (1, 1, 1)))
        rows.append(row)
        stations.append(z)
    return rows, stations


def roof_keeper(hall, soup, rows, stations):
    quarter = hall.N // 4

    def keep(k, j):
        if not (quarter <= j < 3 * quarter):
            return True
        xs = [soup.v[rows[k + dk][(j + dj) % hall.N]][0] for dk in (0, 1) for dj in (0, 1)]
        return not hall.roof_open(sum(xs) / 4.0, (stations[k] + stations[k + 1]) / 2.0)

    return keep


EYE_HALF = (0.4, 0.4, 0.15)


def eye_block(col, center):
    col.box(tuple(c - h for c, h in zip(center, EYE_HALF)), tuple(c + h for c, h in zip(center, EYE_HALF)), (1, 1, 1))


def stalactites(hall, soup, rng, anchors, col):
    """Hanging cones from the roof: filler stalactites on a loose lattice, then the anchor stalactites with copper eyes;
    the anchor cones and eyes also go to col. Returns the anchor positions [(x, y, z)] (eye centres)."""
    out = []
    z = 6.0
    while z < hall.length - 4:
        for _ in range(2 if hall.name == "cavern_shell" else 1):
            side = -1.0 if rng.f() < 0.5 else 1.0
            u = side * rng.span(2.0, 3.1)
            x, y, zz = hall.point(z + rng.span(-2, 2), u)
            if hall.roof_open(x, zz) or abs(x) < LANE * 0.5:
                continue
            soup.cone((x, y, zz), rng.span(0.25, 0.55), rng.span(0.9, 2.2), 7, (0.86, 0.83, 0.77), (0.93, 0.9, 0.84))
        z += 8.0 if hall.name != "cenote_pool" else 6.0
    for zs, u in anchors:
        x, y, zz = hall.point(zs, u)
        length = rng.span(3.6, 4.6)
        soup.cone((x, y, zz), 0.75, length, 8, (0.84, 0.8, 0.74), (0.74, 0.7, 0.64), mid=0.6)
        col.cone((x, y, zz), 0.75, length, 8, (1, 1, 1), (1, 1, 1), mid=0.6)
        ey = y - length - 0.18
        soup.eye((x, ey, zz), COPPER)
        eye_block(col, (x, ey, zz))
        out.append((x, ey, zz))
    return out


def timbers(hall, soup, col):
    """The shaft's timber sets (two posts and a cap beam each), a grey plate over each post head, and its copper pipe; the
    boxes also go to the collider soup. Returns the anchor eye centres (hanging under every other cap beam's middle)."""
    a = hall.half(0.0)
    for z in TIMBER_STATIONS:
        yc = hall.floor_c(z)
        for side in (-1, 1):
            lo, hi = (side * (a - 0.3) - 0.25, yc - 0.1, z - 0.25), (side * (a - 0.3) + 0.25, yc + 6.5, z + 0.25)
            soup.box(lo, hi, TIMBER)
            col.box(lo, hi, (1, 1, 1))
            inner = side * (a - 0.55)
            soup.box((min(inner, inner - side * 0.05), yc + 5.7, z - 0.28), (max(inner, inner - side * 0.05), yc + 6.5, z + 0.28), PLATE)
        lo, hi = (-a + 0.05, yc + 5.9, z - 0.3), (a - 0.05, yc + 6.5, z + 0.3)
        soup.box(lo, hi, TIMBER_DARK)
        col.box(lo, hi, (1, 1, 1))
    pts = [(-a + 0.9, hall.floor_c(z) + 1.3, z) for z in [i * 2.5 for i in range(int(hall.length / 2.5) + 1)]]
    soup.tube(pts, 0.2, 6, COPPER)
    return [(0.0, hall.floor_c(z) + 5.9 - 0.35, z) for z in [11 + 12 * k for k in range(6)]]


def water_sheet(hall):
    """The flat water sheet: 0.75 m cells whose centre floor lies under the sheet. Returns a Soup."""
    soup = Soup()
    y = hall.water_y()
    z0, z1 = hall.pool
    cell = 0.75
    a = hall.half((z0 + z1) / 2)
    nx = int(2 * a / cell) + 1
    ids = {}

    def vid(i, k):
        if (i, k) not in ids:
            ids[(i, k)] = soup.vert((-a + i * cell, y, z0 - cell + k * cell), WATER)
        return ids[(i, k)]

    for k in range(int((z1 - z0) / cell) + 3):
        zc = z0 - cell + (k + 0.5) * cell
        for i in range(nx):
            xc = -a + (i + 0.5) * cell
            if hall.floor_y(xc, zc) < y - 0.04:
                soup.tri(vid(i, k), vid(i, k + 1), vid(i + 1, k))
                soup.tri(vid(i + 1, k), vid(i, k + 1), vid(i + 1, k + 1))
    return soup


def build_base(name):
    """Everything for <name>.glb: dict of soups and the anchor list."""
    hall = HALLS[name]()
    rng = Rng(hall.seed * 7 + 1)
    rock, col = Soup(), Soup()
    rows, stations = ring_rows(hall, rock)
    rock.grid(rows, True, roof_keeper(hall, rock, rows, stations))
    anchors = stalactites(hall, rock, rng, ANCHORS[name], col) if name != "flooded_shaft" else []
    if name == "flooded_shaft":
        anchors = timbers(hall, rock, col)
        for p in anchors:
            rock.eye(p, COPPER)
            eye_block(col, p)
    crow, cst = ring_rows(hall, col, stride=2, with_color=False)
    col.grid(crow, True, roof_keeper(hall, col, crow, cst))
    return {"hall": hall, "rock": rock, "col": col, "water": water_sheet(hall), "anchors": anchors}


def shell_rows(hall, soup, rng, level):
    """Detail shell contents. level 1: boulders on the walls and shelf edges, stalagmites, rim stones round the pool.
    level 2: cobble and gravel scatter. Everything keeps the lane |x| < LANE clear."""
    stone = (0.78, 0.74, 0.68)
    lo_u, hi_u = (0.25, 0.62) if hall.name == "flooded_shaft" else (0.75, 1.45)
    z = 3.0
    step = {1: {"cenote_pool": 2.6, "flooded_shaft": 2.2, "cavern_shell": 6.0}, 2: {"cenote_pool": 1.4, "flooded_shaft": 1.7, "cavern_shell": 3.5}}[level][hall.name]
    while z < hall.length - 1.0 and len(soup.t) <= DETAIL[0] - 40:
        side = -1.0 if rng.f() < 0.5 else 1.0
        u = side * rng.span(lo_u, hi_u)
        x, y, zz = hall.point(z + rng.span(-0.8, 0.8), u)
        shore = hall.pool and hall.pool[0] - 3 < zz < hall.pool[1] + 3
        if abs(x) < LANE + 1.5 or (hall.name == "flooded_shaft" and abs(x) > 7.0):
            z += step
            continue
        if level == 1:
            r = rng.span(0.45, 1.1)
            if rng.f() < 0.35:
                soup.cone((x, y - 0.05, zz), r * 0.5, rng.span(1.0, 2.4), 6, (0.88, 0.85, 0.79), (0.95, 0.92, 0.86), up=True)
            else:
                soup.rock((x, y + r * 0.2, zz), r, 0.7, rng, stone)
            if shore and rng.f() < 0.5:
                sx, sy, sz = hall.point(zz, side * rng.span(0.5, 0.7))
                if abs(sx) >= LANE + 1.5:
                    soup.rock((sx, sy + 0.1, sz), rng.span(0.3, 0.55), 0.6, rng, (0.7, 0.67, 0.62))
        else:
            for _ in range(3):
                px, py, pz = hall.point(zz + rng.span(-0.9, 0.9), side * rng.span(lo_u, hi_u))
                if abs(px) >= LANE + 0.5:
                    soup.pebble((px, py + 0.04, pz), rng.span(0.1, 0.24), rng, (0.74, 0.7, 0.64))
        z += step * rng.span(0.7, 1.3)


def build_shell(name, level):
    hall = HALLS[name]()
    soup = Soup()
    rng = Rng(hall.seed * 13 + level)
    shell_rows(hall, soup, rng, level)
    return {"hall": hall, "rock": soup}


def check_base(name, parts):
    hall, rock, col, water = parts["hall"], parts["rock"], parts["col"], parts["water"]
    tris = len(rock.t) + len(col.t) + len(water.t)
    assert tris <= PARK_LARGE[0], (name, "triangles", tris)
    wy = hall.water_y()
    z0, z1 = hall.pool
    depth = 0.0
    for (x, y, z) in rock.v[:hall.rings * hall.N]:
        if z0 <= z <= z1 and abs(x) < hall.half(z) * 0.7 and y < wy:
            depth = max(depth, wy - y)
    assert 0.5 <= depth <= POOL_LIMIT, (name, "pool depth", depth)
    assert len(water.t) >= 50, (name, "water sheet", len(water.t))
    worst = 0.0
    for i in range(hall.rings):
        for j in range(hall.N):
            x, y, z = rock.v[i * hall.N + j]
            if math.cos(TAU * j / hall.N) > 0.2 and abs(x) < LANE:
                worst = max(worst, abs(y - hall.floor_y(x, z)))
    assert worst <= 0.12, (name, "lane noise", worst)
    for i in range(1, hall.rings - 1, 2):
        z = i * hall.dz
        mid = 0.5 * (hall.floor_y(0.0, z - hall.dz) + hall.floor_y(0.0, z + hall.dz))
        assert abs(mid - hall.floor_y(0.0, z)) <= 0.25, (name, "collider drift", z, mid, hall.floor_y(0.0, z))
    xs = [p[0] for p in rock.v[:hall.rings * hall.N]]
    assert max(abs(min(xs)), max(xs)) <= hall.width / 2 + 0.05, (name, "width", min(xs), max(xs))
    gaps, last = [], 0.0
    for (_, _, z) in sorted(parts["anchors"], key=lambda p: p[2]):
        gaps.append(z - last)
        last = z
    assert gaps and max(gaps) <= ANCHOR_GAP_MAX, (name, "anchor gap", gaps)
    return {"pool_depth": round(depth, 3), "lane_noise": round(worst, 3), "anchor_gap_max": round(max(gaps), 2)}


def check_shell(name, level, parts):
    soup, hall = parts["rock"], parts["hall"]
    assert len(soup.t) <= DETAIL[0], (name, level, "triangles", len(soup.t))
    for (x, y, z) in soup.v:
        if abs(x) < LANE - 0.05:
            assert y <= hall.floor_y(x, z) + 0.12 or y > hall.floor_y(x, z) + 3.0, (name, level, "inside the lane", (x, y, z))
    return {}


def to_blender(soup_parts, root, bpy, common, kit):
    """Turn Soup objects into Blender mesh objects under root. soup_parts: [(object name, soup, slot or None, smooth)]."""
    objs = []
    for oname, soup, slot, smooth_flag in soup_parts:
        mesh = bpy.data.meshes.new(oname)
        mesh.from_pydata([(x, -z, y) for (x, y, z) in soup.v], [], soup.t)
        mesh.update()
        if slot:
            attr = mesh.color_attributes.new(name="Color", type="FLOAT_COLOR", domain="CORNER")
            for poly in mesh.polygons:
                for li in poly.loop_indices:
                    attr.data[li].color = common.rgba(tuple(soup.c[mesh.loops[li].vertex_index]))
            mesh.color_attributes.active_color = attr
            mesh.materials.append(material(slot, bpy, common))
        for poly in mesh.polygons:
            poly.use_smooth = smooth_flag
        obj = bpy.data.objects.new(oname, mesh)
        bpy.context.scene.collection.objects.link(obj)
        obj.parent = root
        objs.append(obj)
    return objs


def material(slot, bpy, common):
    mat = bpy.data.materials.get(slot)
    if mat is not None:
        return mat
    mat = bpy.data.materials.new(slot)
    mat.use_nodes = True
    bsdf = mat.node_tree.nodes.get("Principled BSDF")
    bsdf.inputs["Roughness"].default_value = 0.95 if slot == "stone" else 0.38
    attr = mat.node_tree.nodes.new("ShaderNodeVertexColor")
    attr.layer_name = "Color"
    mat.node_tree.links.new(attr.outputs["Color"], bsdf.inputs["Base Color"])
    return mat


def export_all(only, out_dir, count_only):
    import bpy
    import common
    import kit
    rows = {}
    for name in HALLS:
        if only and name != only:
            continue
        base = build_base(name)
        facts = check_base(name, base)
        n_base = len(base["rock"].t) + len(base["col"].t) + len(base["water"].t)
        shells = [build_shell(name, k) for k in (1, 2)]
        for k, sh in enumerate(shells, 1):
            check_shell(name, k, sh)
        print("CAVERNS_COUNT", name, json.dumps({"base_tris": n_base, "rock": len(base["rock"].t), "col": len(base["col"].t),
              "water": len(base["water"].t), "detail1": len(shells[0]["rock"].t), "detail2": len(shells[1]["rock"].t),
              "anchors": len(base["anchors"]), **facts}, sort_keys=True))
        if count_only:
            continue
        common.reset()
        root = common.empty(name)
        to_blender([("Rock", base["rock"], "stone", True), ("Water", base["water"], "glass", False),
                    (COL_NODE % name, base["col"], None, False)], root, bpy, common, kit)
        for i, p in enumerate(base["anchors"], 1):
            kit.empty("Anchor.%02d" % i, p, root)
        path = Path(out_dir) / (name + ".glb")
        common.export(root, str(path))
        rows[path.name] = report(name, path, kit, PARK_LARGE, [COL_NODE % name, "Rock", "Water"], len(base["anchors"]))
        for k, sh in enumerate(shells, 1):
            common.reset()
            sroot = common.empty("%s_detail%d" % (name, k))
            to_blender([("Detail%d" % k, sh["rock"], "stone", True)], sroot, bpy, common, kit)
            spath = Path(out_dir) / ("%s_detail%d.glb" % (name, k))
            common.export(sroot, str(spath))
            rows[spath.name] = report(name, spath, kit, DETAIL, ["Detail%d" % k], 0)
    return rows


def report(name, path, kit, budget, want_nodes, anchors):
    metrics = kit.gltf_metrics(path)
    assert metrics["triangles"] <= budget[0] and metrics["vertices"] <= budget[1], (path.name, metrics["triangles"], metrics["vertices"], budget)
    for n in want_nodes:
        assert n in metrics["nodes"], (path.name, "missing node", n, metrics["nodes"])
    got = len([n for n in metrics["nodes"] if n.startswith("Anchor.")])
    assert got == anchors, (path.name, "anchors", got, anchors)
    row = {"file": path.name, "sha256": hashlib.sha256(path.read_bytes()).hexdigest(), "triangles": metrics["triangles"],
           "vertices": metrics["vertices"], "draws": metrics["draws"], "materials": metrics["materials"],
           "bounds_min": [round(v, 2) for v in metrics["bounds"]["min"]], "bounds_max": [round(v, 2) for v in metrics["bounds"]["max"]]}
    print("CAVERNS_EXPORT", path.name, json.dumps(row, sort_keys=True))
    return row


def main():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    parser = argparse.ArgumentParser()
    parser.add_argument("--out-dir", default=None)
    parser.add_argument("--only", default=None)
    parser.add_argument("--count-only", action="store_true")
    args = parser.parse_args(argv)
    out_dir = args.out_dir
    if out_dir is None:
        import common
        out_dir = str(Path(common.SKETCH) / "assets/models/park")
    Path(out_dir).mkdir(parents=True, exist_ok=True)
    export_all(args.only, out_dir, args.count_only)


if __name__ == "__main__":
    main()
