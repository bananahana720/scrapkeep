"""Headless recipes for the sky-island family of the park (design-v3/PARK.md section 4, row "Sky-island hops", unit KC8):
mesa_lip_kicker, net_deck and floating_island, each with a base GLB, two detail shells and a -col collision mesh.

Family convention, the same for all three: +Y up, the ride direction +Z (the fall line), x centred, the origin at the entry
lip with y 0 at the ridden surface there. A park row places a recipe with position, y, size and yaw, so a row's y is the
height of its ridden surface and a row's yaw turns the ride direction. A row's at is its footprint's centre; the registry
rows say origin entry_lip, so park_recipes.gd ride_frame puts this origin size[0] / 2 behind at, and the kicker's lip
(z L here) lands on the footprint's far edge, where park_map.gd kicker_lip finds it (KC-INT, 2026-10-11).
  mesa_lip_kicker  12 m long, 2.5 m high at the lip, 14 m wide (the stage 3 pit rows' size [12, 2.5, 14]). The top is the
                   parabola y = H * (z / L)^2: flush with the ground at z 0, 22.6 degrees at the lip, so the ball leaves at
                   the angle atan(2 H / L) the row's height and length set. Mesa strata in red and cream slickrock, three
                   bleached chevrons on the ride face, a pale caprock band on the lip.
  net_deck         one 80 m cell of the animals' net lattice: x -40..40, z 0..80. The net hangs from y 0 at four 16 m
                   juniper posts (copper caps, a yoke, a tethered balloon each) and sags 3.5 m at its middle; the border
                   cable stays at y 0, so cells tile on an 80 m lattice (neighbours share their posts and cables).
  floating_island  the Hanging Isle (stage 5): a deck 180 m across (x -90..90, z 0..180, rim at y 0) on an upside-down
                   mountain that tapers 318 m to a tip at y -318. The deck crowns 0.4 m, a lane 28 m wide along +Z (x -14..14) has no trees or rocks.
Files: <recipe>.glb holds the render mesh named <recipe> (one draw, vertex colour, material named elastomer: the repo's matte vertex-colour slot, assets/materials/dig_mechanical/elastomer.tres, which park_recipes.gd's _views gives every surface by name) and
the trimesh <recipe>-col (never drawn); <recipe>_detail1.glb and <recipe>_detail2.glb are the two additive `detail` shells
park_recipes.gd loads (nothing in a shell stands more than SHELL_PROUD over a ridden surface). No light nodes. Palette:
sandstone, red and cream slickrock, iron oxide, desert varnish, sage, juniper; copper #b77843 for machinery, never brass.
Real-culture guardrail (PARK.md section 4): these are mesa, butte, net and balloon works of the fictional animals; nothing
here names or imitates a living people's work.

  blender --background --threads 2 --python-exit-code 1 --python \
      sketches/core-loop/tools/blender/park/skyislands.py -- [--out DIR] [--count-only]
"""
import argparse
import hashlib
import json
import math
from pathlib import Path
import struct
import sys

import bpy

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE.parent))
import common

SKETCH = HERE.parents[2]
MODELS = SKETCH / "assets/models/park"

BUDGET = {"landform": [8000, 24000], "park_large": [16000, 48000]}
SHELL_BUDGET = [1500, 3000]
SHELL_PROUD = 0.02
ROPE_H = 0.1

HEX = {
    "slick_red": "a9553a", "deep_red": "7d3a2a", "cream": "e3d3ad", "sandstone": "c6a274", "oxide": "9b513a",
    "varnish": "3a2e29", "bone": "d2c5a5", "sage": "6b7a4e", "dry_sage": "8a8a56", "juniper": "4b5c3e", "pine": "3f5238",
    "timber": "7a5a3d", "grey_timber": "8c7e6b", "rope": "c9b27c", "rope_dark": "4a4234", "net_cloth": "5a5240",
    "copper": "b77843", "charcoal": "242a28", "water": "bfe3ea", "mist": "e9f2ef", "balloon_red": "b5503a",
    "balloon_cream": "e6d8b4",
}


def col(name):
    return common.srgb(HEX.get(name, name))


def lerp(a, b, t):
    return tuple(a[i] + (b[i] - a[i]) * t for i in range(3))


def dim(c, k):
    return tuple(max(0.0, min(1.0, x * k)) for x in c)


def rnd(*key):
    """Deterministic float in [0, 1) from integers (FNV-1a), the same on every machine."""
    h = 2166136261
    for k in key:
        h = ((h ^ (int(k) & 0xFFFFFFFF)) * 16777619) & 0xFFFFFFFF
        h ^= h >> 15
    return (h & 0xFFFFFF) / float(1 << 24)


def sub(a, b):
    return (a[0] - b[0], a[1] - b[1], a[2] - b[2])


def cross(a, b):
    return (a[1] * b[2] - a[2] * b[1], a[2] * b[0] - a[0] * b[2], a[0] * b[1] - a[1] * b[0])


def dot(a, b):
    return a[0] * b[0] + a[1] * b[1] + a[2] * b[2]


def norm(a):
    n = math.sqrt(dot(a, a))
    return (a[0] / n, a[1] / n, a[2] / n) if n > 1e-12 else (0.0, 1.0, 0.0)


def add(a, b, k=1.0):
    return (a[0] + b[0] * k, a[1] + b[1] * k, a[2] + b[2] * k)


class Surf:
    """Triangles with a vertex colour each. Every polygon is a convex fan with its own vertices (flat shaded); its winding
    is set here from an `up` direction or an `inside` point, so no run depends on Blender's normal recalculation."""

    def __init__(self, name):
        self.name = name
        self.v = []
        self.c = []
        self.t = []

    def poly(self, pts, color, up=None, inside=None):
        n = (0.0, 0.0, 0.0)
        for i in range(len(pts)):
            n = add(n, cross(pts[i], pts[(i + 1) % len(pts)]))
        if dot(n, n) < 1e-14:
            return
        flip = False
        if up is not None:
            flip = dot(n, up) < 0
        elif inside is not None:
            mid = (sum(p[0] for p in pts) / len(pts), sum(p[1] for p in pts) / len(pts), sum(p[2] for p in pts) / len(pts))
            flip = dot(n, sub(mid, inside)) < 0
        if flip:
            pts = list(reversed(pts))
            if isinstance(color, list):
                color = list(reversed(color))
        base = len(self.v)
        for i, p in enumerate(pts):
            self.v.append(tuple(p))
            self.c.append(color[i] if isinstance(color, list) else color)
        for i in range(1, len(pts) - 1):
            self.t.append((base, base + i, base + i + 1))

    def ring_solid(self, r0, r1, color, caps=(True, True), inside=None):
        n = len(r0)
        mid = inside or tuple(sum(p[k] for p in r0 + r1) / (2 * n) for k in range(3))
        for i in range(n):
            j = (i + 1) % n
            self.poly([r0[i], r0[j], r1[j], r1[i]], color, inside=mid)
        if caps[0]:
            self.poly(list(r0), color, inside=mid)
        if caps[1]:
            self.poly(list(r1), color, inside=mid)

    def box(self, c, size, color, yaw=0.0, inside=None):
        self.chunk(c, size, yaw, 0, color, jitter=0.0)

    def chunk(self, c, size, yaw, seed, color, jitter=0.4, top=1.0):
        """A rock block: a box with jittered corners; top narrows the upper face (1 is a box)."""
        sx, sy, sz = size
        cs, sn = math.cos(yaw), math.sin(yaw)
        pts = []
        for k, (a, b, d) in enumerate([(-1, 0, -1), (1, 0, -1), (1, 0, 1), (-1, 0, 1), (-1, 1, -1), (1, 1, -1), (1, 1, 1), (-1, 1, 1)]):
            s = top if b else 1.0
            x = a * sx / 2 * s + (rnd(seed, k, 1) - 0.5) * jitter * sx
            y = b * sy + (rnd(seed, k, 2) - 0.5) * jitter * sy * (1 if b else 0)
            z = d * sz / 2 * s + (rnd(seed, k, 3) - 0.5) * jitter * sz
            pts.append((c[0] + x * cs + z * sn, c[1] + y, c[2] - x * sn + z * cs))
        mid = (c[0], c[1] + sy * 0.5, c[2])
        for q in [(0, 3, 2, 1), (4, 5, 6, 7), (0, 1, 5, 4), (1, 2, 6, 5), (2, 3, 7, 6), (3, 0, 4, 7)]:
            self.poly([pts[i] for i in q], color, inside=mid)

    def cone(self, c, r, h, sides, color, spin=0.0, r_top=0.0, base=False):
        r0 = [(c[0] + r * math.cos(spin + math.tau * i / sides), c[1], c[2] + r * math.sin(spin + math.tau * i / sides)) for i in range(sides)]
        if r_top > 0:
            r1 = [(c[0] + r_top * math.cos(spin + math.tau * i / sides), c[1] + h, c[2] + r_top * math.sin(spin + math.tau * i / sides)) for i in range(sides)]
            self.ring_solid(r0, r1, color, caps=(base, True))
            return
        apex = (c[0], c[1] + h, c[2])
        mid = (c[0], c[1] + h * 0.3, c[2])
        for i in range(sides):
            self.poly([r0[i], r0[(i + 1) % sides], apex], color, inside=mid)
        if base:
            self.poly(r0, color, inside=mid)

    def sphere(self, c, r, rings, sides, colors):
        grid = []
        for i in range(rings + 1):
            a = math.pi * i / rings
            y, rr = math.cos(a) * r, math.sin(a) * r
            grid.append([(c[0] + rr * math.cos(math.tau * k / sides), c[1] + y, c[2] + rr * math.sin(math.tau * k / sides)) for k in range(sides)])
        for i in range(rings):
            for k in range(sides):
                j = (k + 1) % sides
                color = colors[k % len(colors)]
                if i == 0:
                    self.poly([(c[0], c[1] + r, c[2]), grid[1][j], grid[1][k]], color, inside=c)
                elif i == rings - 1:
                    self.poly([grid[i][k], grid[i][j], (c[0], c[1] - r, c[2])], color, inside=c)
                else:
                    self.poly([grid[i][k], grid[i][j], grid[i + 1][j], grid[i + 1][k]], color, inside=c)

    def rope(self, a, b, w, h, color):
        """A triangular ridge from a to b: base w wide, apex h above the base line, open ends."""
        d = norm(sub(b, a))
        s = norm(cross(d, (0.0, 1.0, 0.0)))
        if abs(d[1]) > 0.999:
            s = (1.0, 0.0, 0.0)
        l0, r0 = add(a, s, -w / 2), add(a, s, w / 2)
        l1, r1 = add(b, s, -w / 2), add(b, s, w / 2)
        ap0, ap1 = add(a, (0.0, 1.0, 0.0), h), add(b, (0.0, 1.0, 0.0), h)
        mid = add(add(a, b), (0.0, 1.0, 0.0), h * 0.0)
        mid = (mid[0] / 2, mid[1] / 2 + h / 3, mid[2] / 2)
        self.poly([l0, ap0, ap1, l1], color, inside=mid)
        self.poly([ap0, r0, r1, ap1], color, inside=mid)
        self.poly([r0, l0, l1, r1], color, inside=mid)

    def pyramid(self, c, r, h, color, seed=0):
        """A small knot or cap: four sides, no base."""
        self.cone(c, r, h, 3, color, spin=rnd(seed) * math.tau)

    def tuft(self, c, h, blades, color, seed):
        for k in range(blades):
            a = rnd(seed, k) * math.tau
            lean = 0.25 + 0.5 * rnd(seed, k, 9)
            ht = h * (0.6 + 0.4 * rnd(seed, k, 5))
            base = (c[0] + 0.12 * math.cos(a), c[1], c[2] + 0.12 * math.sin(a))
            tip = (c[0] + lean * ht * 0.5 * math.cos(a), c[1] + ht, c[2] + lean * ht * 0.5 * math.sin(a))
            self.cone(base, 0.05, ht, 3, color)
            for i in range(len(self.v) - 9, len(self.v)):
                if abs(self.v[i][1] - (c[1] + ht)) < 1e-9:
                    self.v[i] = tip


def tris_of(surf):
    return len(surf.t)


STRATA = [("oxide", 0.34), ("cream", 0.5), ("slick_red", 0.3), ("sandstone", 0.6), ("varnish", 0.16), ("cream", 0.4), ("deep_red", 0.36)]


def strata_edges(top, step=1.0):
    """Hard colour bands from y 0 to `top` as (y0, y1, colour name); the band pattern repeats every sum of STRATA."""
    out = []
    y = 0.0
    k = 0
    while y < top - 1e-9:
        name, th = STRATA[k % len(STRATA)]
        th *= step
        out.append((y, min(top, y + th), name))
        y += th
        k += 1
    return out


def wall(surf, pts_top, x_of, inside, outward):
    """A strata wall under a polyline of top points [(u, y_top)] in a plane: x_of(u) -> the 3D point at height y."""
    for (u0, t0), (u1, t1) in zip(pts_top, pts_top[1:]):
        top = max(t0, t1)
        for y0, y1, name in strata_edges(top):
            a0, b0 = min(y0, t0), min(y1, t0)
            a1, b1 = min(y0, t1), min(y1, t1)
            c = lerp(col(name), col("varnish"), 0.18 * rnd(int(u0 * 10), int(y0 * 10)))
            surf.poly([x_of(u0, a0), x_of(u1, a1), x_of(u1, b1), x_of(u0, b0)] if outward > 0 else [x_of(u0, a0), x_of(u0, b0), x_of(u1, b1), x_of(u1, a1)],
                      c, inside=inside)


K_L, K_H, K_W = 12.0, 2.5, 14.0
K_NX, K_NZ = 28, 24


def k_top(z):
    return K_H * (z / K_L) ** 2


def slick(x, z):
    """Cross-bedded red and cream slickrock with varnish streaks near the walls."""
    w = 0.5 + 0.5 * math.sin(0.85 * x + 0.32 * z + 1.3 * math.sin(0.35 * z + 0.4 * x))
    t = min(1.0, max(0.0, (w - 0.35) / 0.3))
    c = lerp(lerp(col("deep_red"), col("slick_red"), 0.5 + 0.5 * math.sin(0.5 * z - 0.7 * x)), col("sandstone"), 0.55 * t)
    edge = max(0.0, (abs(x) - 5.6) / 1.4)
    c = lerp(c, col("varnish"), 0.55 * min(1.0, edge) * (0.5 + 0.5 * math.sin(2.2 * z + 7 * x)))
    if z > K_L - 0.55:
        c = lerp(c, col("cream"), 0.8)
    return c


CHEVRONS = (2.6, 5.4, 8.2)
CHEV_PROUD = 0.006


def chevrons(s):
    """Three bleached chevrons laid on the ride face, each arm followed along the parabola in short steps."""
    for zt in CHEVRONS:
        for sign in (-1, 1):
            n = 10
            for q in range(n):
                f0, f1 = q / n, (q + 1) / n
                x0, x1 = sign * 3.3 * (1 - f0), sign * 3.3 * (1 - f1)
                z0, z1 = zt - 2.0 * (1 - f0), zt - 2.0 * (1 - f1)
                pts = []
                for (x, z) in ((x0, z0), (x0, z0 - 0.5), (x1, z1 - 0.5), (x1, z1)):
                    pts.append((x, k_top(z) + CHEV_PROUD, z))
                s.poly(pts, col("bone"), up=(0.0, 1.0, 0.0))


def build_kicker_base():
    s = Surf("mesa_lip_kicker")
    hw = K_W / 2
    dx, dz = K_W / K_NX, K_L / K_NZ
    for i in range(K_NX):
        for j in range(K_NZ):
            x0, x1, z0, z1 = -hw + i * dx, -hw + (i + 1) * dx, j * dz, (j + 1) * dz
            pts = [(x0, k_top(z0), z0), (x0, k_top(z1), z1), (x1, k_top(z1), z1), (x1, k_top(z0), z0)]
            s.poly(pts, [slick(p[0], p[2]) for p in pts], up=(0.0, 1.0, 0.0))
    inside = (0.0, K_H / 2, K_L / 2)
    zs = [j * dz for j in range(K_NZ + 1)]
    for sign in (-1, 1):
        wall(s, [(z, k_top(z)) for z in zs], lambda u, y, sg=sign: (sg * hw, y, u), inside, sign)
    wall(s, [(-hw + i * 1.0, K_H) for i in range(15)], lambda u, y: (u, y, K_L), inside, 1)
    s.poly([(-hw, 0.0, 0.0), (hw, 0.0, 0.0), (hw, 0.0, K_L), (-hw, 0.0, K_L)], col("sandstone"), up=(0.0, -1.0, 0.0))
    chevrons(s)
    return s


def build_kicker_col():
    s = Surf("mesa_lip_kicker-col")
    hw = K_W / 2
    dz = K_L / K_NZ
    inside = (0.0, K_H / 2, K_L / 2)
    for j in range(K_NZ):
        z0, z1 = j * dz, (j + 1) * dz
        s.poly([(-hw, k_top(z0), z0), (-hw, k_top(z1), z1), (hw, k_top(z1), z1), (hw, k_top(z0), z0)], col("sandstone"), up=(0.0, 1.0, 0.0))
        for sign in (-1, 1):
            s.poly([(sign * hw, 0.0, z0), (sign * hw, 0.0, z1), (sign * hw, k_top(z1), z1), (sign * hw, k_top(z0), z0)], col("sandstone"), inside=inside)
    s.poly([(-hw, 0.0, K_L), (hw, 0.0, K_L), (hw, K_H, K_L), (-hw, K_H, K_L)], col("sandstone"), inside=inside)
    return s


def build_kicker_d1():
    s = Surf("mesa_lip_kicker_detail1")
    hw = K_W / 2
    for sign in (-1, 1):
        for k in range(16):
            z = 0.8 + k * 0.78 + rnd(k, sign) * 0.4
            x = sign * (hw + 0.35 + 1.9 * rnd(k, 3, sign))
            sz = 0.3 + 0.6 * rnd(k, 4, sign)
            s.chunk((x, 0.0, z), (sz, sz * 0.7, sz * 1.1), rnd(k, 5, sign) * math.tau, k + 40 * sign, lerp(col("sandstone"), col("slick_red"), rnd(k, 6, sign)), top=0.7)
        for k in range(10):
            z0 = 0.6 + k * 1.1
            h = k_top(z0) * 0.55
            if h > 0.3:
                s.chunk((sign * (hw + 0.035), h, z0 + 0.5), (0.1, 0.07, 0.9), 0.0, k, col("cream"), jitter=0.0)
    for k, (cx, cz) in enumerate([(hw + 1.1, 11.4), (-hw - 1.4, 10.6)]):
        for tier in range(4):
            r = 0.55 - 0.1 * tier
            s.chunk((cx, tier * 0.34, cz), (r, 0.3, r), tier + 3 * k, 90 + tier, col("bone"), top=0.75)
    for k in range(8):
        sg = -1 if k % 2 else 1
        s.tuft((sg * (hw + 2.4 + 1.5 * rnd(k, 8)), 0.0, 1.2 + k * 1.4), 0.9, 6, col("dry_sage" if k % 3 else "sage"), 70 + k)
    return s


def build_kicker_d2():
    s = Surf("mesa_lip_kicker_detail2")
    hw = K_W / 2
    for sign in (-1, 1):
        for k in range(22):
            z = 0.4 + k * 0.58 + rnd(k, 1, sign) * 0.3
            x = sign * (hw + 0.15 + 1.2 * rnd(k, 2, sign))
            sz = 0.1 + 0.2 * rnd(k, 3, sign)
            s.chunk((x, 0.0, z), (sz, sz * 0.6, sz), rnd(k, 4, sign) * math.tau, k + 200 * sign, lerp(col("sandstone"), col("varnish"), rnd(k, 5, sign) * 0.6), top=0.6)
        for k in range(5):
            z = 2.0 + k * 1.9
            h = k_top(z) * 0.9
            s.poly([(sign * (hw + 0.012), h, z), (sign * (hw + 0.012), h, z + 0.22), (sign * (hw + 0.012), 0.1, z + 0.12), (sign * (hw + 0.012), 0.1, z + 0.02)],
                   col("varnish"), inside=(0.0, 1.0, z))
    for k in range(7):
        s.chunk((-hw + 0.8 + k * 2.0, 0.0, K_L + 0.28), (0.4, 0.32, 0.32), 0.0, 300 + k, col("bone" if k % 2 else "cream"), top=0.7)
    for k in range(6):
        for twig in range(3):
            a = rnd(k, twig, 7) * math.tau
            base = (-hw - 0.8 - 1.8 * rnd(k, 8), 0.0, 1.0 + k * 2.0)
            tip = (base[0] + 0.7 * math.cos(a), 0.55 + 0.3 * rnd(k, twig, 9), base[2] + 0.7 * math.sin(a))
            s.rope(base, tip, 0.05, 0.05, col("grey_timber"))
    return s


N_X, N_Z, N_SAG, N_POST, N_STEP = 40.0, 80.0, 3.5, 16.0, 5.0
N_NX, N_NZ = 16, 16
N_CELL_X, N_CELL_Z = 2 * N_X / N_NX, N_Z / N_NZ


def net_y(x, z):
    sx = 1.0 - (x / N_X) ** 2
    sz = 1.0 - ((z - N_Z / 2) / (N_Z / 2)) ** 2
    return -N_SAG * sx * sz


def net_post_at(s, x, z, solid_col=False):
    """A tapered juniper post with a copper cap; the render version adds wraps and the yoke."""
    base = (x, -0.4, z)
    sides = 8
    r0 = [(x + 0.6 * math.cos(math.tau * i / sides), -0.4, z + 0.6 * math.sin(math.tau * i / sides)) for i in range(sides)]
    r1 = [(x + 0.34 * math.cos(math.tau * i / sides), N_POST, z + 0.34 * math.sin(math.tau * i / sides)) for i in range(sides)]
    s.ring_solid(r0, r1, col("grey_timber"), caps=(False, True))
    if solid_col:
        return
    for k in range(1, 5):
        y = 3.0 * k
        rr = 0.6 - (0.26 * (y + 0.4) / (N_POST + 0.4)) + 0.05
        a = [(x + rr * math.cos(math.tau * i / sides), y, z + rr * math.sin(math.tau * i / sides)) for i in range(sides)]
        b = [(p[0], y + 0.22, p[2]) for p in a]
        s.ring_solid(a, b, col("rope"), caps=(False, False))
    cap0 = [(x + 0.5 * math.cos(math.tau * i / sides), N_POST, z + 0.5 * math.sin(math.tau * i / sides)) for i in range(sides)]
    cap1 = [(x + 0.3 * math.cos(math.tau * i / sides), N_POST + 0.5, z + 0.3 * math.sin(math.tau * i / sides)) for i in range(sides)]
    s.ring_solid(cap0, cap1, col("copper"))
    sx = -1.0 if x > 0 else 1.0
    s.box((x + sx * 1.6, 13.0, z), (3.4, 0.28, 0.28), col("timber"))
    s.cone((x + sx * 3.2, 12.55, z), 0.45, 0.2, 8, col("copper"), r_top=0.45, base=True)
    bc = (x + sx * 3.2, 19.0, z)
    s.rope((x + sx * 3.2, 13.0, z), (bc[0], bc[1] - 2.3, bc[2]), 0.06, 0.05, col("rope_dark"))
    s.sphere(bc, 2.3, 5, 10, [col("balloon_red"), col("balloon_cream")])


def net_posts():
    return [(sx * N_X, sz) for sx in (-1, 1) for sz in (0.0, N_Z)]


def build_net_base():
    s = Surf("net_deck")
    for i in range(N_NX):
        for j in range(N_NZ):
            x0, x1 = -N_X + i * N_CELL_X, -N_X + (i + 1) * N_CELL_X
            z0, z1 = j * N_CELL_Z, (j + 1) * N_CELL_Z
            pts = [(x0, net_y(x0, z0), z0), (x0, net_y(x0, z1), z1), (x1, net_y(x1, z1), z1), (x1, net_y(x1, z0), z0)]
            shade = 0.88 + 0.24 * rnd(i, j)
            s.poly(pts, dim(col("net_cloth"), shade), up=(0.0, 1.0, 0.0))
    for i in range(N_NX + 1):
        x = -N_X + i * N_CELL_X
        for j in range(N_NZ):
            a, b = (x, net_y(x, j * N_CELL_Z), j * N_CELL_Z), (x, net_y(x, (j + 1) * N_CELL_Z), (j + 1) * N_CELL_Z)
            s.rope(add(a, (0, -0.02, 0)), add(b, (0, -0.02, 0)), 0.22, ROPE_H + 0.02, lerp(col("rope"), col("rope_dark"), 0.15 * rnd(i, j, 4)))
    for j in range(N_NZ + 1):
        z = j * N_CELL_Z
        for i in range(N_NX):
            x0, x1 = -N_X + i * N_CELL_X, -N_X + (i + 1) * N_CELL_X
            s.rope((x0, net_y(x0, z) - 0.02, z), (x1, net_y(x1, z) - 0.02, z), 0.22, ROPE_H + 0.02, lerp(col("rope"), col("rope_dark"), 0.15 * rnd(i, j, 6)))
    for (x, z) in net_posts():
        net_post_at(s, x, z)
    return s


def build_net_col():
    s = Surf("net_deck-col")
    for i in range(N_NX):
        for j in range(N_NZ):
            x0, x1 = -N_X + i * N_CELL_X, -N_X + (i + 1) * N_CELL_X
            z0, z1 = j * N_CELL_Z, (j + 1) * N_CELL_Z
            s.poly([(x0, net_y(x0, z0), z0), (x0, net_y(x0, z1), z1), (x1, net_y(x1, z1), z1), (x1, net_y(x1, z0), z0)], col("rope"), up=(0.0, 1.0, 0.0))
    for (x, z) in net_posts():
        net_post_at(s, x, z, solid_col=True)
    return s


def build_net_d1():
    s = Surf("net_deck_detail1")
    for i in range(1, N_NX):
        for j in range(1, N_NZ):
            x, z = -N_X + i * N_CELL_X, j * N_CELL_Z
            s.pyramid((x, net_y(x, z) + ROPE_H * 0.4, z), 0.2, 0.2, lerp(col("rope"), col("bone"), 0.4 * rnd(i, j, 11)), seed=i * 40 + j)
    for sx in (-1, 1):
        for k in range(1, 5):
            z = k * 2.2
            s.chunk((sx * N_X, -0.02, z), (0.5, 0.2, 0.3), 0.0, 5 + k, col("rope_dark"), jitter=0.0)
    return s


def build_net_d2():
    s = Surf("net_deck_detail2")
    for k in range(26):
        x = -N_X + 6 + 68 * rnd(k, 1)
        z = 6 + 68 * rnd(k, 2)
        w, d = 1.6 + 1.6 * rnd(k, 3), 1.4 + 1.2 * rnd(k, 4)
        pts = [(x, net_y(x, z) + ROPE_H + 0.02, z), (x, net_y(x, z + d) + ROPE_H + 0.02, z + d),
               (x + w, net_y(x + w, z + d) + ROPE_H + 0.02, z + d), (x + w, net_y(x + w, z) + ROPE_H + 0.02, z)]
        s.poly(pts, lerp(col("cream"), col("sandstone"), rnd(k, 5)), up=(0.0, 1.0, 0.0))
    for (x, z) in net_posts():
        sx = -1.0 if x > 0 else 1.0
        for k in range(8):
            s.chunk((x + sx * (0.9 + 0.3 * k), 12.0, z + (k % 2) * 0.18), (0.16, 0.5 + 0.1 * (k % 3), 0.04), 0.0, k, col("oxide" if k % 3 else "bone"), jitter=0.05)
        s.cone((x + sx * 3.2, 12.3, z), 0.5, 0.08, 12, col("copper"), r_top=0.5, base=True)
    return s


I_R, I_DROP, I_CROWN = 90.0, 318.0, 0.4
I_SIDES = 40
I_RINGS = 26


def i_depth(k):
    """Ring depths below the rim: dense under the rim, one step a ring toward the tip."""
    u = k / I_RINGS
    return I_DROP * (u ** 1.35)


def i_radius(k, a):
    """Hull radius at ring k, angle a: never wider than the 90 m rim, rippled and stepped inward by strata."""
    if k >= I_RINGS:
        return 0.0
    u = i_depth(k) / I_DROP
    r = I_R * (1.0 - u) ** 0.78
    if k == 0:
        return I_R
    cut = 0.045 * (0.5 + 0.5 * math.sin(3 * a + 1.7 * (k // 4))) + 0.03 * (0.5 + 0.5 * math.sin(7 * a + 2.9 * (k // 3)))
    step = 0.0 if k % 2 == 0 else 0.05
    return max(r * (1.0 - cut - step), 2.2)


def i_crown(r):
    return I_CROWN * max(0.0, 1.0 - (r / I_R) ** 2)


def i_pt(k, a, r_scale=1.0):
    r = i_radius(k, a) * r_scale
    return (r * math.cos(a), -(i_depth(k)) if k > 0 else 0.0, I_R + r * math.sin(a))


def i_hull_ring(k):
    out = []
    for n in range(I_SIDES):
        a = math.tau * n / I_SIDES
        if k == 0:
            out.append((I_R * math.cos(a), 0.0, I_R + I_R * math.sin(a)))
        else:
            out.append(i_pt(k, a))
    return out


def deck_rim_pts(rscale):
    return [(I_R * rscale * math.cos(math.tau * n / I_SIDES), i_crown(I_R * rscale), I_R + I_R * rscale * math.sin(math.tau * n / I_SIDES)) for n in range(I_SIDES)]


ISLE_STRATA = [("slick_red", 14.0), ("cream", 9.0), ("oxide", 18.0), ("sandstone", 11.0), ("deep_red", 12.0), ("cream", 6.0), ("slick_red", 20.0), ("varnish", 5.0)]


def i_band_colour(k, n):
    """Strata of unequal thickness whose beds tilt round the island (a sine of the angle shifts the bed depth)."""
    a = math.tau * (n + 0.5) / I_SIDES
    d = (i_depth(k) + i_depth(k + 1)) / 2 + 3.0 * math.sin(2 * a + 1.0) + 1.2 * math.sin(5 * a + 0.4)
    d = d % sum(t for _, t in ISLE_STRATA)
    acc = 0.0
    name = ISLE_STRATA[0][0]
    for nm, th in ISLE_STRATA:
        acc += th
        if d < acc:
            name = nm
            break
    base = col(name)
    if rnd(n, k // 5, 77) > 0.95:
        base = lerp(base, col("varnish"), 0.5)
    return lerp(base, col("bone"), 0.1 * rnd(n, k, 5))


def i_pine_sites():
    out = []
    n = 70
    for i in range(n):
        r = 24 + 62 * math.sqrt((i + 0.5) / n)
        a = i * 2.39996
        x, z = r * math.cos(a), I_R + r * math.sin(a)
        if abs(x) < 18.0 or r > 84:
            continue
        out.append((x, z, 11.0 + 9.0 * rnd(i, 1), i))
    return out


def build_island_base():
    s = Surf("floating_island")
    rings = 10
    for j in range(rings):
        r0, r1 = I_R * j / rings, I_R * (j + 1) / rings
        for n in range(I_SIDES):
            a0, a1 = math.tau * n / I_SIDES, math.tau * (n + 1) / I_SIDES
            p = lambda r, a: (r * math.cos(a), i_crown(r), I_R + r * math.sin(a))
            c = lerp(col("dry_sage"), col("sandstone"), 0.3 * rnd(n, j, 3))
            if rnd(n, j, 8) > 0.82:
                c = lerp(c, col("sage"), 0.7)
            pts = [p(r0, a0), p(r1, a0), p(r1, a1), p(r0, a1)] if j > 0 else [p(r0, a0), p(r1, a0), p(r1, a1)]
            s.poly(pts, c, up=(0.0, 1.0, 0.0))
    for k in range(I_RINGS):
        r0, r1 = i_hull_ring(k), i_hull_ring(k + 1) if k + 1 < I_RINGS else None
        for n in range(I_SIDES):
            m = (n + 1) % I_SIDES
            ctr = (0.0, -i_depth(k), I_R)
            if r1 is None:
                tip = (0.0, -I_DROP, I_R)
                s.poly([r0[n], r0[m], tip], i_band_colour(k, n), inside=(0.0, -i_depth(k) + 5, I_R))
            else:
                s.poly([r0[n], r0[m], r1[m], r1[n]], i_band_colour(k, n), inside=(ctr[0], (r0[n][1] + r1[n][1]) / 2, ctr[2]))
    top = (-I_R * 1.0 - 0.6, -2.0, I_R)
    steps = 8
    widths = [4.0, 5.0, 6.0, 7.0, 7.5, 6.0, 3.5, 1.0, 0.0]
    for q in range(steps):
        y0, y1 = -2.0 - 14.0 * q, -2.0 - 14.0 * (q + 1)
        x0 = top[0] - 0.012 * (-y0) ** 1.1
        x1 = top[0] - 0.012 * (-y1) ** 1.1
        c0, c1 = lerp(col("water"), col("mist"), q / steps), lerp(col("water"), col("mist"), (q + 1) / steps)
        w0, w1 = widths[q], widths[q + 1]
        quad = [(x0, y0, I_R - w0 / 2), (x1, y1, I_R - w1 / 2), (x1, y1, I_R + w1 / 2), (x0, y0, I_R + w0 / 2)]
        s.poly(quad, [c0, c1, c1, c0], up=(-1.0, 0.0, 0.0))
        s.poly(quad, [c0, c1, c1, c0], up=(1.0, 0.0, 0.0))
    for (x, z, h, seed) in i_pine_sites():
        y = i_crown(math.hypot(x, z - I_R))
        s.cone((x, y, z), 0.45, h * 0.3, 4, col("timber"), r_top=0.3)
        for t in range(3):
            s.cone((x, y + h * (0.22 + 0.22 * t), z), (0.34 - 0.07 * t) * h * 0.5, h * 0.4, 6, lerp(col("pine"), col("juniper"), 0.4 * rnd(seed, t)), spin=rnd(seed, t, 2))
    return s


def build_island_col():
    s = Surf("floating_island-col")
    rings = 5
    for j in range(rings):
        r0, r1 = I_R * j / rings, I_R * (j + 1) / rings
        for n in range(I_SIDES):
            a0, a1 = math.tau * n / I_SIDES, math.tau * (n + 1) / I_SIDES
            p = lambda r, a: (r * math.cos(a), i_crown(r), I_R + r * math.sin(a))
            pts = [p(r0, a0), p(r1, a0), p(r1, a1), p(r0, a1)] if j > 0 else [p(r0, a0), p(r1, a0), p(r1, a1)]
            s.poly(pts, col("sandstone"), up=(0.0, 1.0, 0.0))
    ks = [0, 2, 5, 8, 11, 14, 17, 20, 23, I_RINGS]
    for a_, b_ in zip(ks, ks[1:]):
        r0 = i_hull_ring(a_)
        r1 = i_hull_ring(b_) if b_ < I_RINGS else None
        for n in range(I_SIDES):
            m = (n + 1) % I_SIDES
            if r1 is None:
                s.poly([r0[n], r0[m], (0.0, -I_DROP, I_R)], col("sandstone"), inside=(0.0, r0[n][1] + 5, I_R))
            else:
                s.poly([r0[n], r0[m], r1[m], r1[n]], col("sandstone"), inside=(0.0, (r0[n][1] + r1[n][1]) / 2, I_R))
    return s


def build_island_d1():
    s = Surf("floating_island_detail1")
    for n in range(26):
        a = math.tau * (n + 0.3 * rnd(n, 1)) / 26
        r = I_R * (0.9 + 0.08 * rnd(n, 2))
        sz = 2.5 + 3.5 * rnd(n, 3)
        s.chunk((r * math.cos(a), i_crown(r), I_R + r * math.sin(a)), (sz, sz * 0.7, sz * 1.2), rnd(n, 4) * math.tau, n, lerp(col("sandstone"), col("slick_red"), rnd(n, 5)), top=0.65)
    for n in range(14):
        a = math.tau * (n + 0.5 * rnd(n, 6)) / 14
        r = I_R * (0.55 + 0.25 * rnd(n, 7))
        ln = 24 * (0.5 + rnd(n, 9))
        y0 = -i_depth(6) * (0.7 + 0.3 * rnd(n, 8))
        s.cone((r * math.cos(a), y0, I_R + r * math.sin(a)), 2.4 + rnd(n, 10) * 2, -ln, 5, col("deep_red"))
    for n in range(24):
        x, z = (rnd(n, 11) - 0.5) * 140, I_R + (rnd(n, 12) - 0.5) * 140
        if abs(x) < 16 or math.hypot(x, z - I_R) > 80:
            continue
        s.tuft((x, i_crown(math.hypot(x, z - I_R)), z), 1.6, 6, col("sage"), 400 + n)
    return s


def build_island_d2():
    s = Surf("floating_island_detail2")
    for n in range(30):
        x, z = (rnd(n, 21) - 0.5) * 150, I_R + (rnd(n, 22) - 0.5) * 150
        r = math.hypot(x, z - I_R)
        if abs(x) < 16 or r > 86:
            continue
        sz = 0.5 + 1.0 * rnd(n, 23)
        s.chunk((x, i_crown(r) - 0.05, z), (sz, sz * 0.6, sz), rnd(n, 24) * math.tau, 500 + n, lerp(col("sandstone"), col("varnish"), rnd(n, 25) * 0.5), top=0.65)
    for n in range(10):
        a = math.tau * n / 10 + 0.2
        c0 = (I_R * 1.02 * math.cos(a), -3.0, I_R + I_R * 1.02 * math.sin(a))
        c1 = (c0[0] * 1.015, c0[1] - 14, c0[2] - (c0[2] - I_R) * 0.015)
        s.rope(c0, c1, 0.5, 0.4, col("grey_timber"))
    for n in range(26):
        x, z = (rnd(n, 31) - 0.5) * 150, I_R + (rnd(n, 32) - 0.5) * 150
        r = math.hypot(x, z - I_R)
        if abs(x) < 16 or r > 84:
            continue
        s.tuft((x, i_crown(r), z), 0.9, 7, col("dry_sage"), 700 + n)
    return s


RECIPES = {
    "mesa_lip_kicker": {"budget": "landform", "base": build_kicker_base, "col": build_kicker_col, "d": (build_kicker_d1, build_kicker_d2),
                        "material": "elastomer",
                        "extent": ((-K_W / 2, 0.0, 0.0), (K_W / 2, K_H, K_L))},
    "net_deck": {"budget": "landform", "base": build_net_base, "col": build_net_col, "d": (build_net_d1, build_net_d2),
                 "material": "elastomer",
                 "extent": ((-N_X - 0.6, -N_SAG, -0.6), (N_X + 0.6, N_POST, N_Z + 0.6))},
    "floating_island": {"budget": "park_large", "base": build_island_base, "col": build_island_col, "d": (build_island_d1, build_island_d2),
                        "material": "elastomer",
                        "extent": ((-I_R, -I_DROP, 0.0), (I_R, I_CROWN, 2 * I_R))},
}


def xyz(v):
    return (v[0], -v[2], v[1])


def material(name):
    mat = bpy.data.materials.get(name)
    if mat:
        return mat
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    bsdf = mat.node_tree.nodes.get("Principled BSDF")
    bsdf.inputs["Roughness"].default_value = 0.92
    bsdf.inputs["Metallic"].default_value = 0.0
    attr = mat.node_tree.nodes.new("ShaderNodeVertexColor")
    attr.layer_name = "Color"
    mat.node_tree.links.new(attr.outputs["Color"], bsdf.inputs["Base Color"])
    return mat


def to_object(surf, root, mat_name):
    mesh = bpy.data.meshes.new(surf.name)
    mesh.from_pydata([xyz(v) for v in surf.v], [], [list(t) for t in surf.t])
    mesh.update()
    attr = mesh.color_attributes.new(name="Color", type="FLOAT_COLOR", domain="CORNER")
    for poly in mesh.polygons:
        poly.use_smooth = False
        for li in poly.loop_indices:
            attr.data[li].color = common.rgba(surf.c[mesh.loops[li].vertex_index])
    mesh.color_attributes.active_color = attr
    if mat_name:
        mesh.materials.append(material(mat_name))
    obj = bpy.data.objects.new(surf.name, mesh)
    bpy.context.scene.collection.objects.link(obj)
    obj.parent = root
    return obj


def read_glb(path):
    data = Path(path).read_bytes()
    length = struct.unpack_from("<I", data, 12)[0]
    doc = json.loads(data[20:20 + length])
    out = {"meshes": {}, "nodes": [n["name"] for n in doc["nodes"]], "materials": [m["name"] for m in doc.get("materials", [])]}
    names = {}
    for n in doc["nodes"]:
        if "mesh" in n:
            names[n["mesh"]] = n["name"]
    for mi, mesh in enumerate(doc["meshes"]):
        tris = verts = 0
        lo, hi = [1e18] * 3, [-1e18] * 3
        for prim in mesh["primitives"]:
            acc = doc["accessors"][prim["attributes"]["POSITION"]]
            verts += acc["count"]
            tris += doc["accessors"][prim["indices"]]["count"] // 3
            for k in range(3):
                lo[k], hi[k] = min(lo[k], acc["min"][k]), max(hi[k], acc["max"][k])
        out["meshes"][names.get(mi, mesh.get("name"))] = {"tris": tris, "verts": verts, "draws": len(mesh["primitives"]), "min": lo, "max": hi}
    return out


def export(name, parts, out_dir):
    """parts: [(Surf, material or None)]. Writes <out_dir>/<name>.glb and returns its measured row."""
    common.reset()
    root = common.empty(name + "_root")
    for surf, mat in parts:
        to_object(surf, root, mat)
    path = Path(out_dir) / (name + ".glb")
    common.export(root, str(path))
    row = read_glb(path)
    row["file"] = path.name
    row["sha256"] = hashlib.sha256(path.read_bytes()).hexdigest()
    return row


def height_at(surf, x, z):
    """Highest upward-facing surface of surf over (x, z), or None."""
    best = None
    for (a, b, c) in surf.t:
        p, q, r = surf.v[a], surf.v[b], surf.v[c]
        if dot(cross(sub(q, p), sub(r, p)), (0.0, 1.0, 0.0)) <= 1e-9:
            continue
        d = (q[2] - r[2]) * (p[0] - r[0]) + (r[0] - q[0]) * (p[2] - r[2])
        if abs(d) < 1e-12:
            continue
        w1 = ((q[2] - r[2]) * (x - r[0]) + (r[0] - q[0]) * (z - r[2])) / d
        w2 = ((r[2] - p[2]) * (x - r[0]) + (p[0] - r[0]) * (z - r[2])) / d
        w3 = 1.0 - w1 - w2
        if min(w1, w2, w3) >= -1e-9:
            y = w1 * p[1] + w2 * q[1] + w3 * r[1]
            best = y if best is None else max(best, y)
    return best


def check_surfaces(recipe, base, col_s, shells):
    """The col surface is the ridden surface: the render's walkable top matches it, and no shell stands proud of it."""
    worst = 0.0
    if recipe == "mesa_lip_kicker":
        probes = [(x * 0.35, z * 0.3) for x in range(-19, 20) for z in range(0, 40)]
        probes = [(x, z) for x, z in probes if abs(x) <= K_W / 2 and 0 <= z <= K_L]
    elif recipe == "net_deck":
        probes = [(-N_X + 3.1 * i, 2.45 * j) for i in range(0, 27) for j in range(0, 34)]
        probes = [(x, z) for x, z in probes if abs(x) <= N_X and 0 <= z <= N_Z and not (abs(x) > 30 and (z < 6 or z > N_Z - 6))]
    else:
        probes = [(-13.0 + 3.25 * i, 3 + 3.1 * j) for i in range(9) for j in range(57)]
        probes = [(x, z) for x, z in probes if math.hypot(x, z - I_R) <= I_R - 2]
    assert len(probes) > 100, (recipe, len(probes))
    proud_max = ROPE_H + 0.02 if recipe == "net_deck" else 0.0105
    for (x, z) in probes:
        h_col = height_at(col_s, x, z)
        h_view = height_at(base, x, z)
        if recipe == "net_deck":
            sheet = net_y(x, z)
            assert abs(h_col - sheet) < 0.05 or h_col >= N_POST - 1, (recipe, x, z, h_col, sheet)
            if h_view is not None and abs(h_col - sheet) < 0.05:
                worst = max(worst, h_view - h_col)
                assert h_view - h_col <= proud_max + 1e-6, ("rope proud", x, z, h_view, h_col)
                assert h_view >= h_col - 0.05, ("render under the net", x, z, h_view, h_col)
        elif recipe == "mesa_lip_kicker":
            assert h_col is not None and abs(h_col - k_top(z)) < 0.002, ("col is the parabola", x, z, h_col)
            assert abs(h_view - h_col) < 0.0105, ("ride face", x, z, h_view, h_col)
            worst = max(worst, abs(h_view - h_col))
        else:
            assert h_col is not None and h_view is not None and abs(h_col - h_view) < 0.02, ("deck", x, z, h_col, h_view)
            worst = max(worst, abs(h_col - h_view))
    for shell in shells:
        for (x, z) in probes[::3]:
            if recipe == "mesa_lip_kicker" and (abs(x) > K_W / 2 or not 0 <= z <= K_L):
                continue
            if recipe == "net_deck":
                continue
            if recipe == "floating_island" and abs(x) < 14.0:
                h_col = height_at(col_s, x, z)
                h_sh = height_at(shell, x, z)
                assert h_sh is None or h_sh - h_col <= SHELL_PROUD + 1e-6, ("shell proud in the lane", shell.name, x, z, h_sh, h_col)
            if recipe == "mesa_lip_kicker":
                h_sh = height_at(shell, x, z)
                assert h_sh is None or h_sh - k_top(z) <= SHELL_PROUD + 1e-6, ("shell proud on the ride face", shell.name, x, z, h_sh)
    return worst


def build(recipe, out_dir, count_only=False):
    spec = RECIPES[recipe]
    base, col_s = spec["base"](), spec["col"]()
    shells = [fn() for fn in spec["d"]]
    cap_t, cap_v = BUDGET[spec["budget"]]
    ext_lo, ext_hi = spec["extent"]
    assert len(base.t) + len(col_s.t) <= cap_t, (recipe, "base+col triangles", len(base.t), len(col_s.t), cap_t)
    assert len(base.v) + len(col_s.v) <= cap_v, (recipe, "vertices", len(base.v) + len(col_s.v), cap_v)
    for sh in shells:
        assert len(sh.t) <= SHELL_BUDGET[0] and len(sh.v) <= SHELL_BUDGET[1], (sh.name, len(sh.t), len(sh.v))
    for sf in [base, col_s] + shells:
        for v in sf.v:
            assert all(math.isfinite(x) for x in v), (sf.name, v)
    worst = check_surfaces(recipe, base, col_s, shells)
    rows = {"recipe": recipe, "budget": spec["budget"], "ride_surface_worst_m": round(worst, 5),
            "counts": {s.name: {"tris": len(s.t), "verts": len(s.v)} for s in [base, col_s] + shells}}
    if count_only:
        return rows
    rows["glb"] = {}
    rows["glb"][recipe] = export(recipe, [(base, spec["material"]), (col_s, None)], out_dir)
    for k, sh in enumerate(shells, start=1):
        rows["glb"][f"{recipe}_detail{k}"] = export(f"{recipe}_detail{k}", [(sh, spec["material"])], out_dir)
    g = rows["glb"][recipe]
    assert recipe in g["meshes"] and recipe + "-col" in g["meshes"], (recipe, list(g["meshes"]))
    assert g["materials"] == [spec["material"]], (recipe, g["materials"])
    render, colm = g["meshes"][recipe], g["meshes"][recipe + "-col"]
    assert render["draws"] == 1 and colm["draws"] == 1, (recipe, render["draws"], colm["draws"])
    assert render["tris"] + colm["tris"] <= cap_t, (recipe, render["tris"], colm["tris"], cap_t)
    for k in range(3):
        assert abs(colm["min"][k] - ext_lo[k]) <= 0.02 and abs(colm["max"][k] - ext_hi[k]) <= 0.02, \
            (recipe, "col extent", k, colm["min"], colm["max"], ext_lo, ext_hi)
    for k in (1, 2):
        sh = rows["glb"][f"{recipe}_detail{k}"]
        m = sh["meshes"][f"{recipe}_detail{k}"]
        assert sh["materials"] == [spec["material"]] and m["draws"] == 1 and m["tris"] <= SHELL_BUDGET[0], (recipe, k, m)
    return rows


def main():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    parser = argparse.ArgumentParser()
    parser.add_argument("--out", default=str(MODELS))
    parser.add_argument("--count-only", action="store_true")
    parser.add_argument("--recipe", default="all")
    args = parser.parse_args(argv)
    ids = list(RECIPES) if args.recipe == "all" else args.recipe.split(",")
    log = []
    for rid in ids:
        row = build(rid, args.out, args.count_only)
        log.append(row)
        print("SKYISLANDS", rid, json.dumps(row, sort_keys=True))
    if not args.count_only:
        print("SKYISLANDS_SHA256", json.dumps({f: g["sha256"] for r in log for f, g in r["glb"].items()}, sort_keys=True))


if __name__ == "__main__":
    main()
