"""Dressing kit for the 40 greybox "ride lip" rows of stage 1, park_dam (design-v3/park/stages/1-park_dam.md section 15),
the new `eye_mouth` row (a 0 m plateau on the canyon floor at the Eye's south mouth) and the two dome-summit survey gates. One deterministic parametric builder writes 3 GLBs per recipe: <id>.glb,
<id>_detail1.glb and <id>_detail2.glb (the names park_recipes.gd reads), 43 recipes, 129 files.

The idea (a "drape"). The stamps already shape every one of these rows and the traversal bands were tuned against that
shape, so the dressing must not change how the ball rolls. Each row gets a recipe `dam_<row id>` whose mesh is built
from the committed bake (assets/park/park_dam/ground.bin): the 2 m ground triangles over the row's footprint, exactly
as terrain.gd _grid_height reads them (cell split on the b-c diagonal, a + (b-a)fx + (c-a)fz below it), clipped to the
footprint and lifted 0.04 to 0.11 m (OFF_*). Painted layers sit on that skin at 0.06 to 0.10 m, so nothing is ever
more than FLUSH (0.12 m) above the stamped ground or below it. A drape has no `-col` mesh: the stamped ground stays the
only collider. Two exceptions carry a `-col` and real height (each arch is its own mesh node `<id>_arch`, so the drape's flush contract reads without it): the Eye arch (a natural sandstone arch between the two
Eye fins, underside at least 18 m over the ramp) and the spillway portal (a concrete headwall arch, at least 10 m over
the wash floor, legs outside the cut).

Placement contract. A greybox stand-in of a stamped row stands on seat(): the ground at its centre less its own stamp's
raise. A GLB row would stand on the ground itself, which moves its ride sensor up, and a `y` on the row would make
tools/park_graph.gd read a deck. So every dressed park row says `"fit": "drape"` (park_recipes.gd fits_drape), `y` null, and
seat() puts its node at y0 = round(ground(at) - max(own stamp offset at the centre, 0), 0.01) (this script's base_height,
the same formula). The vertices here are authored relative to the node origin (at.x, y0, at.z) turned by yaw_deg exactly as
row_transform builds it: local x across the footprint, local z along the facing, Godot axes (+Y up). The park file edit is
`--write-park`; a later dome or bake change is a re-run of this script.

Files per recipe (assets/asset_budgets.json class landform, park_large for tunnels and the vent pits, detail for shells):
  <id>.glb          one drawn mesh `<id>`: surface `enamel` carries vertex colour (the slot role park_recipes.gd maps to the
                    resource material), `ancient_lens` the green seams, `steel` the survey pole; plus `<id>-col` for the
                    two exceptions only
  <id>_detail1.glb  the mid shell: joints, chevrons, stains, bedding lines (at most 1,000 triangles: 3 vertices each
                    unwelded stays inside the class's 3,000)
  <id>_detail2.glb  the near shell: chips, pebbles, flakes

Palette: slickrock cream and red strata, desert varnish, dam-era concrete, copper b77843 for machinery (never brass),
survey amber, ancient lens 9dff3c. Vertex colour only, no texture, no light. The cliff rooms are dry-laid sandstone
coursing as a shaped reference; nothing here names or imitates a living people.

  blender -b --threads 2 --python-exit-code 1 -P sketches/core-loop/tools/blender/park/dam_dressing.py -- \\
      [--out-dir DIR] [--only dam_wash_fin_west,...] [--count-only] [--log FILE] [--registry FILE] [--write-park]
"""
import argparse
import hashlib
import json
import math
from pathlib import Path
import random
import struct
import subprocess
import sys
import zlib

import numpy as np

HERE = Path(__file__).resolve().parent
SKETCH = HERE.parents[2]
MODELS = SKETCH / "assets/models/park"
PARK_FILE = SKETCH / "src/world/park/park_dam.json"
GROUND_BIN = SKETCH / "assets/park/park_dam/ground.bin"
BUDGETS = json.loads((SKETCH / "assets/asset_budgets.json").read_text())["classes"]

FLUSH = 0.12
OFF_BASE, OFF_PAINT, OFF_MARK, OFF_TOP = 0.04, 0.06, 0.08, 0.10
DETAIL_TRIS = 1000
GATE_SINK = 0.15
GATE_REACH = 1.9
EYE_CLEAR, PORTAL_CLEAR = 18.0, 10.0
TAU = math.tau

HEX = {
    "cream": "e3d4b0", "cream2": "ead8b4", "cream3": "d2c5a5", "sand": "d0b88c", "sand2": "c6a274", "red": "a65f43",
    "red2": "b3694a", "red3": "9b513a", "red4": "86513c", "varnish": "3a3027", "caprock": "4a3a33", "talus": "b79f78",
    "ochre": "c9a066", "umber": "7d5a45", "pale": "e9dcc0", "rust": "8a4a35", "stone": "9a9488",
    "concrete": "8f8b82", "concrete2": "9a9a92", "concrete_lt": "a8a398", "concrete_dk": "706c65", "joint": "5c5a54",
    "stain": "4a4038", "wet": "5f5a52", "iron": "2b2724", "steel": "4f4c48", "steel_lt": "6a6761", "copper": "b77843",
    "amber": "e5a044", "charcoal": "242a28", "bone": "d2c5a5", "paint": "e8e4d8", "lens": "9dff3c", "glass": "2f3d44",
    "gravel": "a89a82", "gravel2": "8d8068", "cobble": "7a6e5d", "cobble2": "9c8f78", "sage": "7d8b6a",
    "plate": "3b3a3c", "plate2": "47464a", "flag_red": "e0483a", "flag_blue": "3a6fd0", "mortar": "5a4a3a",
    "door": "2b2420", "timber": "5a4230", "wetrock": "6b5f55", "basalt": "57504b",
}


def hexf(h):
    return tuple(int(h[i:i + 2], 16) / 255.0 for i in (0, 2, 4))


def C(name):
    return hexf(HEX.get(name, name))


def mixc(a, b, t):
    return tuple(a[i] + (b[i] - a[i]) * t for i in range(3))


def tint(c, k):
    return tuple(max(0.0, min(1.0, x * k)) for x in c)


def hn(*a):
    """A deterministic number in [0, 1) from its arguments."""
    return (zlib.crc32("|".join(str(x) for x in a).encode()) & 0xffffff) / float(0x1000000)


def seed_of(name):
    return zlib.crc32(name.encode())


class Ground:
    """ground.bin read as park_terrain.gd does (GCPF header, zstd blocks), sampled as terrain.gd _grid_height does."""

    SIDE, HALF, STEP = 801, 800.0, 2.0

    def __init__(self, path=GROUND_BIN):
        raw = Path(path).read_bytes()
        magic, mode, block, total = struct.unpack_from("<4sIII", raw, 0)
        assert magic == b"GCPF" and mode == 2, ("ground.bin header", magic, mode)
        n = (total + block - 1) // block
        sizes = struct.unpack_from("<%dI" % n, raw, 16)
        pos, out = 16 + 4 * n, bytearray()
        for s in sizes:
            out += _unzstd(raw[pos:pos + s], block)
            pos += s
        assert len(out) == self.SIDE * self.SIDE * 4
        self.H = np.frombuffer(bytes(out), dtype="<f4").reshape(self.SIDE, self.SIDE).astype(np.float64)

    def cell(self, x, z):
        gx = min(max((x + self.HALF) / self.STEP, 0.0), 800 - 0.001)
        gz = min(max((z + self.HALF) / self.STEP, 0.0), 800 - 0.001)
        i, j = int(gx), int(gz)
        return i, j, gx - i, gz - j

    def h(self, x, z):
        i, j, fx, fz = self.cell(x, z)
        H = self.H
        a, b, c, d = H[j, i], H[j, i + 1], H[j + 1, i], H[j + 1, i + 1]
        if fx + fz <= 1.0:
            return float(a + (b - a) * fx + (c - a) * fz)
        return float(d + (c - d) * (1.0 - fx) + (b - d) * (1.0 - fz))

    def tri(self, x, z):
        i, j, fx, fz = self.cell(x, z)
        return (i, j, 0 if fx + fz <= 1.0 else 1)


def _unzstd(block, size):
    try:
        import zstandard
        return zstandard.ZstdDecompressor().decompress(block, max_output_size=size)
    except ImportError:
        return subprocess.run(["zstd", "-dc"], input=block, stdout=subprocess.PIPE, check=True).stdout


def smoothstep(a, b, x):
    t = min(max((x - a) / (b - a), 0.0), 1.0)
    return t * t * (3.0 - 2.0 * t)


def stamp_offset(row, x, z):
    """park_stamps.gd offset(), ported: the height the row's own stamp adds at (x, z)."""
    a = math.radians(float(row["yaw_deg"]))
    length, h, width = max(float(row["size"][0]), 0.001), float(row["size"][1]), max(float(row["size"][2]), 0.001)
    rx, rz = x - row["at"][0], z - row["at"][1]
    u = (rx * math.sin(a) + rz * math.cos(a)) / length
    v = (rx * math.cos(a) - rz * math.sin(a)) / width
    kind = row["stamp"]
    if kind in ("butte", "spire", "bowl", "crater", "sinkhole"):
        r = 2.0 * math.sqrt(u * u + v * v)
        if r > 1.0:
            return 0.0
        if kind == "butte":
            return h * min(max((1.0 - r) / 0.15, 0.0), 1.0)
        if kind == "spire":
            return h * smoothstep(1.0, 0.4, r)
        if kind == "bowl":
            return -h * (1.0 - r * r)
        raise ValueError(kind)
    if abs(u) > 0.5 or abs(v) > 0.5:
        return 0.0
    side_m, end_m = (0.5 - abs(v)) * width, (0.5 - abs(u)) * length
    if kind == "plateau":
        return h
    if kind == "mesa":
        return h * min(max(min(side_m, end_m) / max(0.3 * h, 0.001), 0.0), 1.0)
    if kind == "ramp":
        return h * (0.5 - u)
    if kind == "ridge":
        t = 2.0 * v
        return h * (1.0 - t * t) * min(max(end_m / (0.5 * width), 0.0), 1.0)
    if kind == "wash":
        t = abs(2.0 * v)
        depth = 1.0
        if t > 0.4:
            w = (t - 0.4) / 0.6
            depth = 1.0 - w * w
        run = max(min(width, 0.25 * length), 0.001)
        return -h * depth * min(max(end_m / run, 0.0), 1.0)
    raise ValueError(kind)


def base_height(row, ground):
    """The node y of a dressed row: what park_recipes.gd seat() gives a stamped greybox at its centre."""
    at = row["at"]
    return round(ground.h(at[0], at[1]) - max(stamp_offset(row, at[0], at[1]), 0.0), 2)


class Frame:
    """The row node: at, yaw_deg and the base height, as row_transform builds it."""

    def __init__(self, at, yaw_deg, y0):
        self.ax, self.az, self.y0 = float(at[0]), float(at[1]), float(y0)
        a = math.radians(float(yaw_deg))
        self.c, self.s = math.cos(a), math.sin(a)

    def local(self, x, z):
        dx, dz = x - self.ax, z - self.az
        return (dx * self.c - dz * self.s, dx * self.s + dz * self.c)

    def world(self, lx, lz):
        return (self.ax + lx * self.c + lz * self.s, self.az - lx * self.s + lz * self.c)


def clip(poly, f):
    out, n = [], len(poly)
    for k in range(n):
        p, q = poly[k], poly[(k + 1) % n]
        fp, fq = f(p), f(q)
        if fp >= 0:
            out.append(p)
        if (fp >= 0) != (fq >= 0):
            t = fp / (fp - fq)
            out.append((p[0] + (q[0] - p[0]) * t, p[1] + (q[1] - p[1]) * t, p[2] + (q[2] - p[2]) * t))
    return clean(out)


def clean(poly):
    out = []
    for p in poly:
        if not out or abs(p[0] - out[-1][0]) + abs(p[1] - out[-1][1]) + abs(p[2] - out[-1][2]) > 1e-7:
            out.append(p)
    while len(out) > 1 and abs(out[0][0] - out[-1][0]) + abs(out[0][1] - out[-1][1]) + abs(out[0][2] - out[-1][2]) <= 1e-7:
        out.pop()
    if len(out) < 3 or area3(out) < 1e-5:
        return []
    return out


def newell(poly):
    """The (unnormalised) normal of a planar polygon of (x, z, y) points, in (x, y, z) order."""
    nx = ny = nz = 0.0
    n = len(poly)
    for k in range(n):
        p, q = poly[k], poly[(k + 1) % n]
        nx += (p[2] - q[2]) * (p[1] + q[1])
        ny += (p[1] - q[1]) * (p[0] + q[0])
        nz += (p[0] - q[0]) * (p[2] + q[2])
    return nx, ny, nz


def area3(poly):
    nx, ny, nz = newell(poly)
    return 0.5 * math.sqrt(nx * nx + ny * ny + nz * nz)


def slope_of(poly):
    nx, ny, nz = newell(poly)
    return math.hypot(nx, nz) / max(abs(ny), 1e-9)


def hp_xz(ax, az, c):
    return lambda p: ax * p[0] + az * p[1] - c


def hp_y(ay, c, ax=0.0, az=0.0):
    return lambda p: ax * p[0] + az * p[1] + ay * p[2] - c


def convex_hps(pts):
    """Half-planes (>= 0 inside) of a convex polygon of (x, z) points, whichever way it winds."""
    s = sum(pts[k][0] * pts[(k + 1) % len(pts)][1] - pts[(k + 1) % len(pts)][0] * pts[k][1] for k in range(len(pts)))
    if s < 0:
        pts = pts[::-1]
    out = []
    for k in range(len(pts)):
        p, q = pts[k], pts[(k + 1) % len(pts)]
        dx, dz = q[0] - p[0], q[1] - p[1]
        out.append(lambda v, p=p, dx=dx, dz=dz: dx * (v[1] - p[1]) - dz * (v[0] - p[0]))
    return out


def footprint_of(row):
    """A row's footprint in world (x, z), as Dress.footprint draws it: an ellipse for a round stamp, else the rectangle."""
    fr = Frame(row["at"], row["yaw_deg"], 0.0)
    hl, hw = float(row["size"][0]) / 2, float(row["size"][2]) / 2
    if row["stamp"] in ("butte", "spire", "bowl", "crater", "sinkhole"):
        return [fr.world(hw * math.cos(TAU * k / 40), hl * math.sin(TAU * k / 40)) for k in range(40)]
    return [fr.world(x, z) for x, z in ((-hw, -hl), (hw, -hl), (hw, hl), (-hw, hl))]


def footprint_area(pts):
    return abs(sum(pts[k][0] * pts[(k + 1) % len(pts)][1] - pts[(k + 1) % len(pts)][0] * pts[k][1] for k in range(len(pts)))) / 2


def covered_by(rid, rows, order):
    """The footprints (half-planes) of the drape rows dressed here that overlap rid and are smaller than it (or as large
    and earlier in the park file). Two skins over the same ground drew the same faces twice, steep walls included, and
    they z-fought (clip audit, 30 Oct: spillway_tunnel and cliff_rooms_west 3,570 m2, training_wall_west and
    tailwater_bar 813 m2), so the smaller, more particular row keeps the ground and the larger one leaves it out."""
    mine = footprint_of(rows[rid])
    size = round(footprint_area(mine), 2)
    mx0, mx1 = min(p[0] for p in mine), max(p[0] for p in mine)
    mz0, mz1 = min(p[1] for p in mine), max(p[1] for p in mine)
    out = []
    for k, other in enumerate(order):
        if other == rid:
            continue
        theirs = footprint_of(rows[other])
        if max(p[0] for p in theirs) <= mx0 or min(p[0] for p in theirs) >= mx1 or max(p[1] for p in theirs) <= mz0 or min(p[1] for p in theirs) >= mz1:
            continue
        area = round(footprint_area(theirs), 2)
        if area < size or (area == size and k < order.index(rid)):
            out.append(convex_hps(theirs))
    return out


def outside_of(poly, hps):
    """The convex pieces of poly outside the convex footprint hps (half-planes, >= 0 inside): the part past each edge
    and inside the edges before it. Poly whole when it misses the footprint, nothing when the footprint holds it."""
    inside = poly
    for f in hps:
        inside = clip(inside, f)
        if not inside:
            return [poly]
    if area3(inside) <= 1e-6:
        return [poly]
    if area3(inside) >= area3(poly) - 1e-6:
        return []
    out, rest = [], poly
    for f in hps:
        piece = clip(rest, lambda v, f=f: -f(v))
        if piece and area3(piece) > 1e-6:
            out.append(piece)
        rest = clip(rest, f)
        if not rest:
            break
    return out


def centroid(poly):
    n = len(poly)
    return (sum(p[0] for p in poly) / n, sum(p[1] for p in poly) / n, sum(p[2] for p in poly) / n)


class Out:
    """Polygons in the node's own space (Godot axes) by material slot, with a triangle cap."""

    def __init__(self, cap):
        self.cap = cap
        self.slots = {}

    def tris(self):
        return sum(len(p) - 2 for polys in self.slots.values() for p, _ in polys)

    def add(self, slot, pts, color, up=True):
        """pts: planar polygon of (x, y, z) Godot points. up=True winds it to face +Y; else it is wound already."""
        if up:
            nx = ny = nz = 0.0
            for k in range(len(pts)):
                p, q = pts[k], pts[(k + 1) % len(pts)]
                nx += (p[1] - q[1]) * (p[2] + q[2])
                ny += (p[2] - q[2]) * (p[0] + q[0])
                nz += (p[0] - q[0]) * (p[1] + q[1])
            if ny < 0:
                pts = pts[::-1]
        self.slots.setdefault(slot, []).append((list(pts), tuple(color)))

    def bounds(self):
        pts = [v for polys in self.slots.values() for p, _ in polys for v in p]
        return [min(v[k] for v in pts) for k in range(3)], [max(v[k] for v in pts) for k in range(3)]


def convex_solid(out, slot, verts, faces, color):
    """A convex piece: every face wound outward from the piece's centre."""
    centre = tuple(sum(v[k] for v in verts) / len(verts) for k in range(3))
    for f in faces:
        ring = [verts[i] for i in f]
        n = [0.0, 0.0, 0.0]
        for k in range(1, len(ring) - 1):
            a, b = [ring[k][i] - ring[0][i] for i in range(3)], [ring[k + 1][i] - ring[0][i] for i in range(3)]
            n[0] += a[1] * b[2] - a[2] * b[1]
            n[1] += a[2] * b[0] - a[0] * b[2]
            n[2] += a[0] * b[1] - a[1] * b[0]
        mid = [sum(p[i] for p in ring) / len(ring) for i in range(3)]
        if sum(n[i] * (mid[i] - centre[i]) for i in range(3)) < 0:
            ring = ring[::-1]
        out.add(slot, ring, color, up=False)


def box_solid(out, slot, lo, hi, color, yaw=0.0, skip=()):
    xs, ys, zs = (lo[0], hi[0]), (lo[1], hi[1]), (lo[2], hi[2])
    pts = [(xs[i], ys[j], zs[k]) for i in (0, 1) for j in (0, 1) for k in (0, 1)]
    if yaw:
        cx, cz = (lo[0] + hi[0]) / 2, (lo[2] + hi[2]) / 2
        cs, sn = math.cos(yaw), math.sin(yaw)
        pts = [(cx + (p[0] - cx) * cs + (p[2] - cz) * sn, p[1], cz - (p[0] - cx) * sn + (p[2] - cz) * cs) for p in pts]
    faces = {"-x": (0, 1, 3, 2), "+x": (4, 5, 7, 6), "-y": (0, 1, 5, 4), "+y": (2, 3, 7, 6), "-z": (0, 2, 6, 4), "+z": (1, 3, 7, 5)}
    convex_solid(out, slot, pts, [f for k, f in faces.items() if k not in skip], color)


def prism_xz(out, slot, ring_xz, y0, y1, color, skip_bottom=False):
    """A vertical prism over a convex ring of (x, z)."""
    n = len(ring_xz)
    verts = [(x, y0, z) for x, z in ring_xz] + [(x, y1, z) for x, z in ring_xz]
    faces = [tuple(range(n, 2 * n))] + ([] if skip_bottom else [tuple(range(n))])
    faces += [(k, (k + 1) % n, n + (k + 1) % n, n + k) for k in range(n)]
    convex_solid(out, slot, verts, faces, color)


def rod_solid(out, slot, a, b, r, color, sides=8):
    d = [b[i] - a[i] for i in range(3)]
    ln = math.sqrt(sum(x * x for x in d))
    d = [x / ln for x in d]
    ref = (0.0, 1.0, 0.0) if abs(d[1]) < 0.9 else (1.0, 0.0, 0.0)
    u = [d[1] * ref[2] - d[2] * ref[1], d[2] * ref[0] - d[0] * ref[2], d[0] * ref[1] - d[1] * ref[0]]
    lu = math.sqrt(sum(x * x for x in u))
    u = [x / lu for x in u]
    v = [d[1] * u[2] - d[2] * u[1], d[2] * u[0] - d[0] * u[2], d[0] * u[1] - d[1] * u[0]]
    ring = [[math.cos(TAU * k / sides) * r * u[i] + math.sin(TAU * k / sides) * r * v[i] for i in range(3)] for k in range(sides)]
    verts = [tuple(a[i] + q[i] for i in range(3)) for q in ring] + [tuple(b[i] + q[i] for i in range(3)) for q in ring]
    faces = [tuple(range(sides)), tuple(range(sides, 2 * sides))]
    faces += [(k, (k + 1) % sides, sides + (k + 1) % sides, sides + k) for k in range(sides)]
    convex_solid(out, slot, verts, faces, color)


def ear_clip(pts):
    """Triangles (index triples) of a simple counter-clockwise polygon of (x, y)."""
    idx = list(range(len(pts)))
    tris = []

    def cross(o, a, b):
        return (pts[a][0] - pts[o][0]) * (pts[b][1] - pts[o][1]) - (pts[a][1] - pts[o][1]) * (pts[b][0] - pts[o][0])

    guard = 0
    while len(idx) > 3 and guard < 10000:
        guard += 1
        for k in range(len(idx)):
            a, b, c = idx[k - 1], idx[k], idx[(k + 1) % len(idx)]
            if cross(a, b, c) <= 1e-9:
                continue
            if any(cross(a, b, p) >= -1e-9 and cross(b, c, p) >= -1e-9 and cross(c, a, p) >= -1e-9 for p in idx if p not in (a, b, c)):
                continue
            tris.append((a, b, c))
            idx.pop(k)
            break
        else:
            break
    tris.append(tuple(idx))
    return tris


def loft(out, slot, outline, zf, zb, color_of):
    """Extrudes a counter-clockwise (x, y) outline between a front z and a back z per vertex: the cap faces are triangulated
    by ear clipping, the walls are quads. Faces wind outward (+z back, -z front is the caller's choice of zf < zb).
    color_of(kind, points) -> colour."""
    n = len(outline)
    front = [(outline[k][0], outline[k][1], zf[k]) for k in range(n)]
    back = [(outline[k][0], outline[k][1], zb[k]) for k in range(n)]
    for a, b, c in ear_clip(outline):
        out.add(slot, [front[a], front[c], front[b]], color_of("front", [front[a], front[b], front[c]]), up=False)
        out.add(slot, [back[a], back[b], back[c]], color_of("back", [back[a], back[b], back[c]]), up=False)
    for k in range(n):
        j = (k + 1) % n
        quad = [front[k], back[k], back[j], front[j]]
        out.add(slot, quad, color_of("wall", quad), up=False)


class Dress:
    """One row: its frame, the ground triangles clipped to its footprint and the three outputs."""

    def __init__(self, row, ground, base_cap, region=None, covered=()):
        self.row, self.g = row, ground
        self.id = row["id"]
        self.y0 = base_height(row, ground)
        self.fr = Frame(row["at"], row["yaw_deg"], self.y0)
        self.len, self.hgt, self.wid = float(row["size"][0]), float(row["size"][1]), float(row["size"][2])
        self.rng = random.Random(seed_of(self.id))
        self.base, self.d1, self.d2 = Out(base_cap), Out(DETAIL_TRIS), Out(DETAIL_TRIS)
        self.ellipse = row["stamp"] in ("butte", "spire", "bowl", "crater", "sinkhole")
        if region is None:
            region = self.footprint()
        self.region = region
        self.facets = []
        for poly, sl in self._facets(region):
            parts = [poly]
            for hps in covered:
                parts = [q for part in parts for q in outside_of(part, hps)]
            self.facets.extend((q, sl) for q in parts)
        self.bucket = {}
        for k, (poly, _) in enumerate(self.facets):
            c = centroid(poly)
            self.bucket.setdefault((int(c[0] // 8), int(c[1] // 8)), []).append(k)
        ys = [p[2] for poly, _ in self.facets for p in poly]
        self.ymin, self.ymax = min(ys), max(ys)

    def footprint(self):
        hl, hw = self.len / 2, self.wid / 2
        if self.ellipse:
            return [self.fr.world(hw * math.cos(TAU * k / 40), hl * math.sin(TAU * k / 40)) for k in range(40)]
        return [self.fr.world(x, z) for x, z in ((-hw, -hl), (hw, -hl), (hw, hl), (-hw, hl))]

    def _facets(self, region):
        hps = convex_hps(region)
        g = self.g
        x0, x1 = min(p[0] for p in region), max(p[0] for p in region)
        z0, z1 = min(p[1] for p in region), max(p[1] for p in region)
        i0, i1 = max(0, int(math.floor((x0 + 800) / 2)) - 1), min(799, int(math.floor((x1 + 800) / 2)) + 1)
        j0, j1 = max(0, int(math.floor((z0 + 800) / 2)) - 1), min(799, int(math.floor((z1 + 800) / 2)) + 1)
        out = []
        for j in range(j0, j1 + 1):
            for i in range(i0, i1 + 1):
                X, Z = -800.0 + 2.0 * i, -800.0 + 2.0 * j
                a, b = (X, Z, g.H[j, i]), (X + 2.0, Z, g.H[j, i + 1])
                c, d = (X, Z + 2.0, g.H[j + 1, i]), (X + 2.0, Z + 2.0, g.H[j + 1, i + 1])
                for tri in ((a, b, c), (d, c, b)):
                    poly = [tuple(float(v) for v in p) for p in tri]
                    for f in hps:
                        poly = clip(poly, f)
                        if not poly:
                            break
                    if poly:
                        out.append((poly, slope_of(poly)))
        return out

    def info(self, poly):
        c = centroid(poly)
        lx, lz = self.fr.local(c[0], c[1])
        return {"c": c, "lx": lx, "lz": lz, "y": c[2], "slope": slope_of(poly), "up": c[2] - self.ymin}

    def put(self, out, slot, poly, color, off):
        pts = [(self.fr.local(p[0], p[1])[0], p[2] + off - self.fr.y0, self.fr.local(p[0], p[1])[1]) for p in poly]
        out.add(slot, pts, color)

    def lpoly(self, pts):
        """Local (lx, lz) points to world (x, z)."""
        return [self.fr.world(a, b) for a, b in pts]

    def pieces(self, pts_local, ylo=None, yhi=None, minslope=None, maxslope=None, extra=(), where=None):
        """The ground facets cut to a convex local polygon (and optional world-height slab); a list of (poly, slope)."""
        world = self.lpoly(pts_local)
        hps = convex_hps(world)
        if ylo is not None:
            hps.append(hp_y(1.0, ylo))
        if yhi is not None:
            hps.append(hp_y(-1.0, -yhi))
        hps.extend(extra)
        x0, x1 = min(p[0] for p in world), max(p[0] for p in world)
        z0, z1 = min(p[1] for p in world), max(p[1] for p in world)
        found = []
        for bi in range(int((x0 - 3) // 8), int((x1 + 3) // 8) + 1):
            for bj in range(int((z0 - 3) // 8), int((z1 + 3) // 8) + 1):
                found.extend(self.bucket.get((bi, bj), ()))
        out = []
        for k in sorted(set(found)):
            poly, sl = self.facets[k]
            if minslope is not None and sl < minslope:
                continue
            if maxslope is not None and sl > maxslope:
                continue
            if where is not None and not where(poly, sl):
                continue
            for f in hps:
                poly = clip(poly, f)
                if not poly:
                    break
            if poly:
                out.append((poly, sl))
        return out

    def decal(self, out, pts_local, color, off, slot="enamel", colorfn=None, **kw):
        """Paints a convex local polygon onto the ground; skipped whole when it would pass the output's cap."""
        pcs = self.pieces(pts_local, **kw)
        cost = sum(len(p) - 2 for p, _ in pcs)
        if not pcs or out.tris() + cost > out.cap:
            return False
        for poly, _ in pcs:
            self.put(out, slot, poly, colorfn(poly) if colorfn else color, off)
        return True

    def rect(self, out, lx0, lx1, lz0, lz1, color, off, **kw):
        return self.decal(out, [(lx0, lz0), (lx1, lz0), (lx1, lz1), (lx0, lz1)], color, off, **kw)

    def bar(self, out, a, b, w, color, off, **kw):
        """A strip from local a to local b, w wide."""
        dx, dz = b[0] - a[0], b[1] - a[1]
        ln = math.hypot(dx, dz)
        nx, nz = -dz / ln * w / 2, dx / ln * w / 2
        return self.decal(out, [(a[0] - nx, a[1] - nz), (b[0] - nx, b[1] - nz), (b[0] + nx, b[1] + nz), (a[0] + nx, a[1] + nz)],
                          color, off, **kw)

    def chevron(self, out, lx, lz, direction, size, width, color, off, **kw):
        """A V pointing along local +z (direction 1) or -z (-1), tip at (lx, lz)."""
        ok = False
        for sgn in (-1, 1):
            ok |= self.bar(out, (lx + sgn * size, lz - direction * size * 0.8), (lx, lz), width, color, off, **kw)
        return ok

    def pass_flat(self, colorfn, off=OFF_BASE):
        """The whole skin in one pass, no cuts; colorfn(info) -> colour."""
        for poly, _ in self.facets:
            self.put(self.base, "enamel", poly, colorfn(self.info(poly)), off)

    def pass_cut(self, colorfn, cuts, off=OFF_BASE, only=None):
        """The skin cut by planes (functions on (x, z, y)), as many in priority order as the cap allows; `only`
        (poly, slope) -> bool limits the cuts to the facets it names."""
        room = self.base.cap - self.base.tris()
        use = list(cuts)
        while True:
            pieces = [(p, only is None or only(p, sl)) for p, sl in self.facets]
            for fn in use:
                nxt = []
                for p, cut in pieces:
                    vals = [fn(v) for v in p] if cut else [0.0]
                    if min(vals) >= -1e-9 or max(vals) <= 1e-9:
                        nxt.append((p, cut))
                        continue
                    nxt.extend((q, True) for q in (clip(p, fn), clip(p, lambda v, fn=fn: -fn(v))) if q)
                pieces = nxt
            pieces = [p for p, _ in pieces]
            if sum(len(p) - 2 for p in pieces) <= room or not use:
                break
            use = use[::2] if len(use) > 1 else []
        assert sum(len(p) - 2 for p in pieces) <= room, (self.id, "skin does not fit the cap", sum(len(p) - 2 for p in pieces), room)
        for poly in pieces:
            self.put(self.base, "enamel", poly, colorfn(self.info(poly)), off)
        return len(use), len(cuts)

    def in_region(self, x, z):
        return all(f((x, z, 0.0)) >= 0 for f in convex_hps(self.region)) if not hasattr(self, "_hps") else all(f((x, z, 0.0)) >= 0 for f in self._hps)

    def spot(self, maxslope=0.5, edge=0.0, tries=40):
        """A random (lx, lz, x, z) on a ground facet gentler than maxslope (inside the footprint), or None."""
        if not hasattr(self, "_hps"):
            self._hps = convex_hps(self.region)
        key = round(maxslope, 3)
        cache = self.__dict__.setdefault("_elig", {})
        if key not in cache:
            cache[key] = [poly for poly, sl in self.facets if sl <= maxslope and area3(poly) > 0.4]
        pool = cache[key]
        if not pool:
            return None
        poly = pool[self.rng.randrange(len(pool))]
        c = centroid(poly)
        v = poly[self.rng.randrange(len(poly))]
        t = self.rng.uniform(0.0, 0.7)
        x, z = c[0] + (v[0] - c[0]) * t, c[1] + (v[1] - c[1]) * t
        lx, lz = self.fr.local(x, z)
        return lx, lz, x, z

    def chips(self, out, n, colors, rmin=0.12, rmax=0.35, maxslope=0.6, sink=0.04, peak=0.10, where=None):
        """Tetra flakes: a base triangle at OFF 0.04 with an apex at 0.10, wholly inside one ground triangle."""
        made = 0
        for _ in range(n * 6):
            if made >= n or out.tris() + 3 > out.cap:
                break
            s = self.spot(maxslope)
            if s is None:
                continue
            lx, lz, x, z = s
            if where is not None and not where(lx, lz, x, z):
                continue
            r = self.rng.uniform(rmin, rmax)
            a0 = self.rng.uniform(0, TAU)
            ring = [(x + r * math.cos(a0 + TAU * k / 3 + self.rng.uniform(-.3, .3)), z + r * math.sin(a0 + TAU * k / 3 + self.rng.uniform(-.3, .3))) for k in range(3)]
            ids = {self.g.tri(*p) for p in ring} | {self.g.tri(x, z)}
            if len(ids) != 1:
                continue
            slope = slope_of([(p[0], p[1], self.g.h(*p)) for p in ring])
            if slope > maxslope or not all(f((p[0], p[1], 0.0)) >= 0.3 for p in ring for f in self._hps):
                continue
            col = self.rng.choice(colors)
            col = tint(col, self.rng.uniform(0.9, 1.08))
            base = [(p[0], p[1], self.g.h(*p) + sink) for p in ring]
            apex = (x, z, self.g.h(x, z) + peak)
            for k in range(3):
                tri = [base[k], base[(k + 1) % 3], apex]
                self.put(out, "enamel", tri, tint(col, 0.94 + 0.06 * (k % 2)), 0.0)
            made += 1
        return made

    def pebbles(self, out, n, colors, rmin=0.25, rmax=0.5, maxslope=0.45, where=None):
        """Hexagonal domes (ring at 0.04, crown at 0.10), wholly inside one ground triangle."""
        made = 0
        for _ in range(n * 8):
            if made >= n or out.tris() + 16 > out.cap:
                break
            s = self.spot(maxslope)
            if s is None:
                continue
            lx, lz, x, z = s
            if where is not None and not where(lx, lz, x, z):
                continue
            r = self.rng.uniform(rmin, rmax)
            a0 = self.rng.uniform(0, TAU)
            ring = [(x + r * math.cos(a0 + TAU * k / 6), z + r * math.sin(a0 + TAU * k / 6)) for k in range(6)]
            top = [(x + 0.55 * r * math.cos(a0 + TAU * k / 6), z + 0.55 * r * math.sin(a0 + TAU * k / 6)) for k in range(6)]
            if len({self.g.tri(*p) for p in ring} | {self.g.tri(x, z)}) != 1:
                continue
            if slope_of([(p[0], p[1], self.g.h(*p)) for p in ring[:3]]) > maxslope or not all(f((p[0], p[1], 0.0)) >= 0.3 for p in ring for f in self._hps):
                continue
            col = tint(self.rng.choice(colors), self.rng.uniform(0.9, 1.1))
            lo = [(p[0], p[1], self.g.h(*p) + 0.04) for p in ring]
            hi = [(p[0], p[1], self.g.h(*p) + 0.10) for p in top]
            for k in range(6):
                j = (k + 1) % 6
                self.put(out, "enamel", [lo[k], lo[j], hi[j], hi[k]], tint(col, 0.9 + 0.02 * k), 0.0)
            self.put(out, "enamel", hi, tint(col, 1.06), 0.0)
            made += 1
        return made


def pick(rng, tones, last):
    choices = [t for t in tones if t != last] or tones
    return rng.choice(choices)


def strata_plan(d, set_t, band_t):
    """Cross-bedded sets: horizontal set boundaries and, inside each set, planes tilted along the row's length (the
    tilt flips from set to set). Returns (set list, cut functions in priority order, band edge lists per set)."""
    rng = random.Random(seed_of(d.id + "/strata"))
    sets, y = [], d.ymin - 0.05
    while y < d.ymax + 0.05:
        t = rng.uniform(*set_t)
        sets.append({"lo": y, "hi": y + t, "tilt": rng.choice((-1, 1)) * rng.uniform(0.04, 0.11), "edges": []})
        y += t
    fr = d.fr
    for st in sets:
        e = st["lo"] - 3.0
        while e < st["hi"] + 3.0:
            st["edges"].append(e)
            e += rng.uniform(*band_t)
    cuts = [hp_y(1.0, st["lo"]) for st in sets[1:]]
    for st in sets:
        lo, hi, tl = st["lo"], st["hi"], st["tilt"]
        for e in st["edges"]:
            cuts.append(hp_y(1.0, e + tl * (-fr.ax * fr.s - fr.az * fr.c), tl * fr.s, tl * fr.c))
    return sets, cuts


def strata_color(d, sets, info, pal, streak=0.0, crest=0.0, foot=0.6, varnish_slope=0.9, crest_tone="caprock", sheet=True):
    y, lz, lx = info["y"], info["lz"], info["lx"]
    st = sets[-1]
    for s in sets:
        if y < s["hi"]:
            st = s
            break
    q = y + st["tilt"] * lz
    k = int(math.floor((q - st["edges"][0]) / 1.0)) if st["edges"] else 0
    band = 0
    for e in st["edges"]:
        if q >= e:
            band += 1
    tones = pal[sets.index(st) % len(pal)]
    c = C(tones[(band * 5 + sets.index(st) * 3) % len(tones)])
    c = tint(c, 0.94 + 0.12 * hn(d.id, round(info["c"][0] / 3.0), round(info["c"][1] / 3.0), band))
    if streak and info["slope"] > varnish_slope:
        w = 2.4 + 5.0 * hn(d.id, "w", int(lz // 17))
        kk = int(lz // w)
        if hn(d.id, "streak", kk) < streak and abs((lz % w) - w / 2) < w * 0.32:
            c = mixc(c, C("varnish"), 0.78)
    if crest and info["up"] > (d.ymax - d.ymin) - crest and info["slope"] < 1.2:
        c = mixc(c, C(crest_tone), 0.55)
    if foot and info["up"] < foot and info["slope"] < 0.8:
        c = mixc(c, C("talus"), 0.55)
    return c


def strata(d, pal, set_t=(5.0, 9.0), band_t=(1.1, 2.8), streak=0.4, crest=0.0, foot=0.6, varnish_slope=0.9, crest_tone="caprock"):
    sets, cuts = strata_plan(d, set_t, band_t)
    return d.pass_cut(lambda info: strata_color(d, sets, info, pal, streak, crest, foot, varnish_slope, crest_tone), cuts)


SLICK = [["cream", "cream2", "sand", "cream3"], ["red", "red2", "red3", "red4"], ["cream", "sand", "cream2"], ["red3", "red", "red4"]]
MESA = [["red", "red2", "red3"], ["cream", "cream2"], ["red4", "red", "red3"], ["sand", "cream3"]]
CANYON = [["ochre", "umber", "pale"], ["umber", "rust", "ochre"], ["pale", "ochre", "cream3"], ["rust", "umber"]]


def concrete_color(d, info, pitch=(4.0, 4.0), base="concrete", sat=0.06):
    kz, kx = int(math.floor(info["lz"] / pitch[0])), int(math.floor(info["lx"] / pitch[1]))
    c = C(base)
    return tint(c, 1.0 - sat + 2 * sat * hn(d.id, kz, kx))


def bedding_lines(d, out, n, color, length, off=0.08, minslope=0.35, width=0.14):
    """Pale or dark bedding lines running along the row on its flanks."""
    for _ in range(n):
        lx = d.rng.uniform(-d.wid / 2 + 0.5, d.wid / 2 - 0.5)
        lz = d.rng.uniform(-d.len / 2 + length, d.len / 2 - length) if d.len > 2 * length else d.rng.uniform(-d.len / 3, d.len / 3)
        d.bar(out, (lx, lz), (lx + d.rng.uniform(-.6, .6), lz + length * d.rng.uniform(.5, 1.0)), width, color, off, minslope=minslope)


def cracks(d, out, n, color, off=0.07, minslope=0.6):
    for _ in range(n):
        lx = d.rng.choice((-1, 1)) * d.rng.uniform(0.2, 0.5) * d.wid
        lz = d.rng.uniform(-d.len / 2 + 2, d.len / 2 - 2)
        d.bar(out, (lx, lz), (lx + d.rng.uniform(-3, 3), lz + d.rng.uniform(-1, 1)), d.rng.uniform(0.1, 0.22), color, off, minslope=minslope)


def joint_grid(d, out, pitch_z, pitch_x, color, width=0.10, off=OFF_MARK, z0=None, z1=None, x0=None, x1=None, **kw):
    z0 = -d.len / 2 if z0 is None else z0
    z1 = d.len / 2 if z1 is None else z1
    x0 = -d.wid / 2 if x0 is None else x0
    x1 = d.wid / 2 if x1 is None else x1
    lz = z0 + pitch_z if pitch_z else None
    while pitch_z and lz < z1 - 0.2:
        d.bar(out, (x0, lz), (x1, lz), width, color, off, **kw)
        lz += pitch_z
    lx = x0 + pitch_x if pitch_x else None
    while pitch_x and lx < x1 - 0.2:
        d.bar(out, (lx, z0), (lx, z1), width, color, off, **kw)
        lx += pitch_x


def survey_chevrons(d, out, lz_lip, color=None, width=0.5, count=3, gap=2.1, lx=0.0, size=None):
    """Flush painted survey chevrons pointing along the launch (+z), the nearest to the lip first, and a lip line."""
    color = color or C("amber")
    size = size or min(d.wid * 0.22, 3.2)
    for k in range(count):
        d.chevron(out, lx, lz_lip - 1.4 - k * gap, 1, size, width, color, OFF_MARK)
    d.rect(out, -d.wid / 2 + 0.4, d.wid / 2 - 0.4, lz_lip - 0.55, lz_lip - 0.15, C("paint"), OFF_PAINT)


GLYPHS = {
    "P": [(0, 0, 1, 5), (1, 4, 3, 5), (1, 2, 3, 3), (2, 3, 3, 4)],
    "I": [(0, 0, 3, 1), (1, 1, 2, 4), (0, 4, 3, 5)],
    "E": [(0, 0, 1, 5), (1, 0, 3, 1), (1, 2, 3, 3), (1, 4, 3, 5)],
    "L": [(0, 0, 1, 5), (1, 0, 3, 1)],
    "N": [(0, 0, 1, 5), (2, 0, 3, 5), (1, 3, 2, 4)],
    "3": [(2, 0, 3, 5), (0, 0, 2, 1), (0, 2, 2, 3), (0, 4, 2, 5)],
}


def stencil(d, out, text, lx0, lz0, unit, color, off=OFF_PAINT, **kw):
    """Block letters laid along +z starting at lz0, glyph height across x from lx0."""
    z = lz0
    for ch in text:
        if ch == " ":
            z += 3 * unit
            continue
        for gx0, gy0, gx1, gy1 in GLYPHS[ch]:
            d.rect(out, lx0 + gy0 * unit, lx0 + gy1 * unit, z + gx0 * unit, z + gx1 * unit, color, off, **kw)
        z += 4 * unit


def style_slick_fin(d, pal=SLICK, crest=2.2):
    cracks(d, d.d1, 70, C("varnish"))
    bedding_lines(d, d.d1, 60, C("cream2"), 9.0)
    bedding_lines(d, d.d1, 30, C("red3"), 7.0, off=0.09)
    d.chips(d.d2, 260, [C(n) for n in ("cream", "sand", "red2", "red3", "cream3")])
    return strata(d, pal, streak=0.42, crest=crest)


def style_mesa(d, spine=False):
    if spine:
        lz = -d.len / 2 + 3
        while lz < d.len / 2 - 3:
            d.rect(d.d1, -1.5, 1.5, lz, lz + 0.28, C("timber"), OFF_MARK, maxslope=1.6)
            lz += 1.3
        for lx in (-0.75, 0.75):
            d.bar(d.d1, (lx, -d.len / 2 + 3), (lx, d.len / 2 - 3), 0.12, C("steel_lt"), OFF_TOP, maxslope=1.6)
        joint_grid(d, d.d1, 6.0, 0, C("joint"), 0.1, OFF_PAINT)
        d.chips(d.d2, 200, [C(n) for n in ("concrete", "concrete_lt", "concrete_dk", "stone")], sink=0.04)
        return d.pass_cut(lambda i: concrete_color(d, i, (5.0, 3.0), "concrete", 0.07), [hp_y(1.0, d.ymin + 6.0), hp_y(1.0, d.ymin + 13.0)])
    cracks(d, d.d1, 60, C("varnish"))
    bedding_lines(d, d.d1, 60, C("cream2"), 10.0)
    d.chips(d.d2, 260, [C(n) for n in ("red", "cream", "red3", "sand", "cream3")])
    return strata(d, MESA, set_t=(6.0, 10.0), band_t=(1.4, 3.2), streak=0.3, crest=1.8, crest_tone="red4")


def style_canyon(d, hoodoo=False):
    cracks(d, d.d1, 40, C("varnish"))
    bedding_lines(d, d.d1, 30, C("pale"), 6.0)
    d.chips(d.d2, 220, [C(n) for n in ("ochre", "umber", "pale", "rust")])
    if hoodoo:
        top = d.ymax - d.hgt * 0.22
        rng = d.rng
        sets, cuts = strata_plan(d, (3.0, 5.0), (0.9, 2.0))
        cuts = [hp_y(1.0, top), hp_y(1.0, top - 1.2)] + cuts

        def cf(i):
            if i["y"] >= top - 0.2:
                return tint(C("caprock"), 0.92 + 0.1 * hn(d.id, round(i["c"][0]), round(i["c"][1])))
            return strata_color(d, sets, i, CANYON, streak=0.4, crest=0.0, foot=0.5)
        return d.pass_cut(cf, cuts)
    return strata(d, CANYON, set_t=(3.0, 6.0), band_t=(0.8, 2.0), streak=0.35, crest=1.2)


def style_pool_rock(d):
    wet = d.ymin + 3.2
    cracks(d, d.d1, 16, C("varnish"))
    d.chips(d.d2, 200, [C(n) for n in ("wetrock", "stone", "basalt", "talus")])
    sets, cuts = strata_plan(d, (2.0, 3.5), (0.8, 1.6))
    cuts = [hp_y(1.0, wet), hp_y(1.0, wet - 0.5)] + cuts

    def cf(i):
        c = strata_color(d, sets, i, [["stone", "sand2", "talus"], ["stone", "cream3"]], streak=0.3, foot=0.0)
        if i["y"] < wet:
            c = mixc(c, C("wet"), 0.7 if i["y"] < wet - 0.5 else 0.4)
        return c
    return d.pass_cut(cf, cuts)


def style_pier(d):
    hw_line = d.ymin + 5.0
    joint_grid(d, d.d1, 2.2, 2.2, C("joint"), 0.09, OFF_PAINT, minslope=0.0)
    d.rect(d.d1, -d.wid / 2, d.wid / 2, -d.len / 2, d.len / 2, C("stain"), OFF_PAINT, ylo=hw_line - 0.25, yhi=hw_line + 0.25)
    d.chips(d.d2, 180, [C(n) for n in ("concrete", "concrete_lt", "concrete_dk")])
    cuts = [hp_y(1.0, hw_line), hp_y(1.0, hw_line - 0.7)]
    return d.pass_cut(lambda i: mixc(concrete_color(d, i, (2.2, 2.2)), C("stain"), 0.45) if i["y"] < hw_line else concrete_color(d, i, (2.2, 2.2)), cuts)


def style_training_wall(d):
    hw_line = d.ymin + d.hgt * 0.55
    joint_grid(d, d.d1, 2.5, 0, C("joint"), 0.1, OFF_PAINT, z0=-d.len / 2 + 4.5, z1=d.len / 2 - 4.5)
    d.rect(d.d1, -d.wid / 2, d.wid / 2, -d.len / 2, d.len / 2, C("stain"), OFF_PAINT, ylo=hw_line - 0.3, yhi=hw_line + 0.3)
    for sgn in (-1, 1):
        for k in range(3):
            d.chevron(d.d1 if k else d.base, 0.0, sgn * (d.len / 2 - 2.2 - k * 1.6), sgn, 1.6, 0.4, C("amber"), OFF_MARK)
        d.rect(d.base, -d.wid / 2 + 0.6, d.wid / 2 - 0.6, sgn * (d.len / 2 - 1.2) - 0.2, sgn * (d.len / 2 - 1.2) + 0.2, C("charcoal"), OFF_PAINT)
    d.chips(d.d2, 180, [C(n) for n in ("concrete", "concrete_lt", "concrete_dk", "stone")])
    cuts = [hp_y(1.0, hw_line), hp_y(1.0, hw_line - 0.8)]
    return d.pass_cut(lambda i: mixc(concrete_color(d, i, (2.5, 8.0)), C("stain"), 0.4) if i["y"] < hw_line else concrete_color(d, i, (2.5, 8.0)), cuts)


def style_rooms(d):
    def flank(poly, sl):
        c = centroid(poly)
        return sl >= 0.8 and stamp_offset(d.row, c[0], c[1]) >= 0.6

    def doorway(poly, sl):
        c = centroid(poly)
        return sl >= 0.8 and 0.9 <= stamp_offset(d.row, c[0], c[1]) <= 3.6

    for sgn in (-1, 1):
        lz = -d.len / 2 + 9.0
        while lz < d.len / 2 - 9.0:
            if hn(d.id, sgn, round(lz)) > 0.25:
                d.rect(d.d1, 0.0 if sgn > 0 else -d.wid / 2, d.wid / 2 if sgn > 0 else 0.0, lz, lz + 2.0, C("door"), OFF_TOP, where=doorway)
            lz += 6.5 + 4.0 * hn(d.id, "door", round(lz))
    d.chips(d.d2, 240, [C(n) for n in ("sand", "sand2", "cream3", "talus")])
    ys = [centroid(p)[2] for p, sl in d.facets if flank(p, sl)]
    levels, y = [], math.floor(min(ys) / 0.9) * 0.9
    while y < max(ys):
        levels.append(y)
        y += 0.9

    def cf(i):
        course = int(math.floor(i["y"] / 0.9))
        tones = ("sand", "sand2", "cream3", "talus") if i["slope"] >= 0.8 else ("sand2", "talus", "sand")
        c = C(tones[(course * 3 + int(hn(d.id, course, round(i["lz"] / 2.2)) * 4)) % len(tones)])
        return tint(c, 0.93 + 0.12 * hn(d.id, "b", course, round(i["lz"] / 1.3)))
    return d.pass_cut(cf, [hp_y(1.0, v) for v in levels], only=flank)


def style_kicker(d, kind):
    lip = d.len / 2
    survey_chevrons(d, d.base, lip)
    for sgn in (-1, 1):
        d.bar(d.d1, (sgn * (d.wid / 2 - 0.5), -lip + 1), (sgn * (d.wid / 2 - 0.5), lip - 0.7), 0.25, C("paint"), OFF_PAINT)
    if kind == "slick":
        cracks(d, d.d1, 12, C("varnish"), minslope=0.0)
        bedding_lines(d, d.d1, 14, C("cream2"), 6.0, minslope=0.0)
        d.chips(d.d2, 120, [C(n) for n in ("cream", "sand", "red2", "cream3")])
        return strata(d, SLICK, set_t=(1.2, 2.2), band_t=(0.7, 1.4), streak=0.0, crest=0.0, foot=0.0)
    if kind == "concrete":
        joint_grid(d, d.d1, 2.5, 3.0, C("joint"), 0.1, OFF_PAINT)
        d.chips(d.d2, 120, [C(n) for n in ("concrete", "concrete_lt", "concrete_dk")])
        d.pass_flat(lambda i: concrete_color(d, i, (2.5, 3.0)))
        return 0
    if kind == "bucket":
        for k in range(1, 6):
            d.bar(d.d1, (-d.wid / 2, lip - k * 2.6), (d.wid / 2, lip - k * 2.6), 0.1, C("joint"), OFF_PAINT)
        for k in range(-3, 4):
            d.bar(d.d1, (k * 3.0, lip), (k * 2.0, -lip), 0.1, C("joint"), OFF_PAINT)
        d.chips(d.d2, 120, [C(n) for n in ("concrete", "concrete_lt", "concrete_dk", "wetrock")])
        d.pass_flat(lambda i: mixc(concrete_color(d, i, (2.6, 3.0)), C("wet"), 0.25 * (1 - min(1, max(0, (i["lz"] + lip) / d.len)))))
        return 0
    d.pebbles(d.d2, 40, [C(n) for n in ("cobble", "cobble2", "gravel2")])
    d.chips(d.d2, 120, [C(n) for n in ("gravel", "gravel2", "cobble2")])
    for _ in range(26):
        lx, lz = d.rng.uniform(-d.wid / 2 + 1, d.wid / 2 - 1), d.rng.uniform(-lip + 1, lip - 1)
        a = d.rng.uniform(0, TAU)
        r = d.rng.uniform(0.3, 0.7)
        d.decal(d.d1, [(lx + r * math.cos(a + TAU * k / 6), lz + r * math.sin(a + TAU * k / 6)) for k in range(6)], tint(C("cobble"), d.rng.uniform(.9, 1.1)), OFF_MARK)
    d.pass_flat(lambda i: tint(mixc(C("gravel"), C("gravel2"), hn(d.id, round(i["c"][0] / 2), round(i["c"][1] / 2))), 0.92 + 0.14 * hn(d.id, i["c"][0])))
    return 0


def style_gallery(d):
    hx, hz = d.wid / 2, d.len / 2
    top = dict(maxslope=0.25)
    for lx0, lx1, lz0, lz1 in ((-hx, -hx + 0.7, -hz, hz), (hx - 0.7, hx, -hz, hz), (-hx, hx, -hz, -hz + 0.7), (-hx, hx, hz - 0.7, hz)):
        d.rect(d.base, lx0, lx1, lz0, lz1, C("concrete_lt"), OFF_TOP, **top)
    k = -hz + 3.0
    while k < hz - 4.0:
        d.decal(d.base, [(-hx + 0.9, k), (-hx + 1.8, k), (-hx + 1.8 + 1.1, k + 1.1), (-hx + 0.9 + 1.1, k + 1.1)],
                C("amber") if int(round((k + hz) / 1.1)) % 2 == 0 else C("charcoal"), OFF_PAINT, **top)
        k += 1.1
    for sgn in (-1, 1):
        z = -hz + 5.0
        while z < hz - 4.0:
            d.rect(d.d1, sgn * (hx - 2.0) - 0.25, sgn * (hx - 2.0) + 0.25, z, z + 1.4, C("iron"), OFF_PAINT, **top)
            z += 6.0
    joint_grid(d, d.d1, 5.0, 6.0, C("joint"), 0.1, OFF_PAINT, **top)
    d.chips(d.d2, 160, [C(n) for n in ("concrete", "concrete_lt", "concrete_dk", "stone")], maxslope=0.3)
    d.pass_flat(lambda i: concrete_color(d, i, (5.0, 6.0)) if i["slope"] < 1.0 else mixc(concrete_color(d, i, (5.0, 6.0)), C("concrete_dk"), 0.35))
    return 0


def style_abutment(d):
    joint_grid(d, d.d1, 3.0, 3.0, C("joint"), 0.1, OFF_PAINT)
    for k in range(3):
        d.chevron(d.base, 0.0, d.len / 2 - 3.0 - k * 2.0, 1, 3.0, 0.5, C("amber"), OFF_MARK)
    d.chips(d.d2, 160, [C(n) for n in ("concrete", "concrete_lt", "concrete_dk")])
    d.pass_flat(lambda i: concrete_color(d, i, (3.0, 3.0)))
    return 0


def style_powerhouse(d):
    hx, hz = d.wid / 2, d.len / 2
    y0 = d.ymin
    wall = d.hgt
    steep = dict(minslope=1.5)
    for k, (a, b) in enumerate(((4.0, 6.2), (9.0, 11.2), (14.0, 16.2))):
        d.rect(d.base, -hx, hx, -hz, hz, C("glass"), OFF_PAINT, ylo=y0 + a, yhi=y0 + b, **steep)
        d.rect(d.d1, -hx, hx, -hz, hz, C("concrete_lt"), OFF_MARK, ylo=y0 + a - 0.18, yhi=y0 + a, **steep)
    z = -hz + 3.0
    while z < hz - 1.0:
        d.rect(d.d1, -hx, hx, z, z + 0.35, C("concrete_dk"), OFF_TOP, ylo=y0 + 3.9, yhi=y0 + 16.3, **steep)
        z += 3.0
    for k in range(6):
        yy = y0 + 17.4 + 0.45 * k
        d.rect(d.d1, -hx, hx, -hz, hz, C("iron"), OFF_PAINT, ylo=yy, yhi=yy + 0.14, **steep)
    top = dict(maxslope=0.3, ylo=y0 + wall - 0.5)
    d.rect(d.base, -1.6, 1.6, -hz + 1.5, hz - 1.5, C("copper"), OFF_PAINT, **top)
    for k in range(5):
        for lx in (-hx + 7.0, hx - 7.0):
            z = -hz + 8.0 + k * 11.0
            d.rect(d.d1, lx - 1.2, lx + 1.2, z - 1.2, z + 1.2, C("iron"), OFF_TOP, **top)
            for m in range(3):
                d.rect(d.d1, lx - 1.0, lx + 1.0, z - 0.9 + 0.7 * m, z - 0.7 + 0.7 * m, C("steel_lt"), OFF_TOP, **top)
    d.chips(d.d2, 140, [C(n) for n in ("concrete", "concrete_lt", "concrete_dk")], maxslope=0.3)
    joint_grid(d, d.d1, 6.0, 6.0, C("joint"), 0.1, OFF_PAINT, **top)
    d.pass_flat(lambda i: concrete_color(d, i, (6.0, 6.0), "concrete_lt" if i["slope"] < 1.0 else "concrete", 0.05))
    return 0


def style_plunge(d):
    ring = [(0.5 * d.wid * math.cos(TAU * k / 48), 0.5 * d.len * math.sin(TAU * k / 48)) for k in range(48)]
    inner = [(0.47 * d.wid * math.cos(TAU * k / 48), 0.47 * d.len * math.sin(TAU * k / 48)) for k in range(48)]
    for k in range(48):
        a, b, c, e = ring[k], ring[(k + 1) % 48], inner[(k + 1) % 48], inner[k]
        d.decal(d.base, [a, b, c, e], C("concrete_lt") if k % 2 else C("concrete2"), OFF_TOP)
    tide = d.ymin + 0.9
    d.rect(d.d1, -d.wid / 2, d.wid / 2, -d.len / 2, d.len / 2, C("stain"), OFF_PAINT, ylo=tide - 0.25, yhi=tide + 0.25)
    for _ in range(90):
        a = d.rng.uniform(0, TAU)
        rr = d.rng.uniform(0.55, 0.9)
        lx, lz = 0.5 * d.wid * rr * math.cos(a), 0.5 * d.len * rr * math.sin(a)
        r = d.rng.uniform(1.0, 2.0)
        a0 = d.rng.uniform(0, TAU)
        d.decal(d.d1, [(lx + r * math.cos(a0 + TAU * k / 5), lz + r * math.sin(a0 + TAU * k / 5)) for k in range(5)],
                tint(C(d.rng.choice(("stone", "concrete_dk", "wetrock", "basalt"))), d.rng.uniform(.85, 1.1)), OFF_MARK)
    d.pebbles(d.d2, 40, [C(n) for n in ("stone", "wetrock", "concrete_dk")], rmin=0.3, rmax=0.6)
    d.chips(d.d2, 200, [C(n) for n in ("stone", "wetrock", "concrete_dk", "basalt")])
    cuts = [hp_y(1.0, tide), hp_y(1.0, tide - 0.8)]
    return d.pass_cut(lambda i: mixc(tint(C("stone"), 0.9 + 0.2 * hn(d.id, round(i["c"][0] / 2), round(i["c"][1] / 2))), C("wet"), 0.6 if i["y"] < tide else 0.0), cuts)


def style_vents(d):
    rings = (0.2, 0.42, 0.66, 0.9)
    for k, r in enumerate(rings):
        pts_o = [(0.5 * d.wid * (r + 0.02) * math.cos(TAU * j / 36), 0.5 * d.len * (r + 0.02) * math.sin(TAU * j / 36)) for j in range(36)]
        pts_i = [(0.5 * d.wid * (r - 0.02) * math.cos(TAU * j / 36), 0.5 * d.len * (r - 0.02) * math.sin(TAU * j / 36)) for j in range(36)]
        for j in range(36):
            d.decal(d.base, [pts_o[j], pts_o[(j + 1) % 36], pts_i[(j + 1) % 36], pts_i[j]], C("lens"), OFF_MARK, slot="ancient_lens")
    for j in range(12):
        a = TAU * j / 12
        d.bar(d.base, (0.5 * d.wid * 0.2 * math.cos(a), 0.5 * d.len * 0.2 * math.sin(a)), (0.5 * d.wid * 0.9 * math.cos(a), 0.5 * d.len * 0.9 * math.sin(a)), 0.22, C("lens"), OFF_MARK, slot="ancient_lens")
    for j in range(24):
        t = TAU * (j + 0.5) / 24
        r0, r1 = 0.3 + 0.2 * hn(d.id, "s", j), 0.62 + 0.3 * hn(d.id, "e", j)
        d.bar(d.d1, (0.5 * d.wid * r0 * math.cos(t), 0.5 * d.len * r0 * math.sin(t)), (0.5 * d.wid * r1 * math.cos(t), 0.5 * d.len * r1 * math.sin(t)), 0.35, C("steel"), OFF_PAINT)
    d.chips(d.d2, 120, [C(n) for n in ("plate", "plate2", "basalt")])

    def cf(i):
        r = math.hypot(i["lx"] / (0.5 * d.wid), i["lz"] / (0.5 * d.len))
        k = int(r * 6)
        a = int((math.atan2(i["lz"], i["lx"]) + math.pi) / TAU * (6 + 3 * k))
        return tint(C("plate") if (k + a) % 2 else C("plate2"), 0.92 + 0.14 * hn(d.id, k, a))
    d.pass_flat(cf)
    return 0


def style_pipeline(d):
    hl = d.len / 2
    top = dict(maxslope=6.0)
    d.bar(d.base, (0.0, -hl + 1.0), (0.0, hl - 1.0), 1.5, C("steel"), OFF_PAINT, **top)
    z = -hl + 4.0
    while z < hl - 3.0:
        d.rect(d.base, -0.95, 0.95, z, z + 0.45, C("steel_lt"), OFF_MARK, **top)
        z += 5.0
    z = -hl + 9.0
    while z < hl - 6.0:
        d.rect(d.d1, -1.5, 1.5, z - 0.5, z + 0.5, C("iron"), OFF_TOP, **top)
        z += 15.0
    stencil(d, d.d1, "PIPELINE 3", 1.0, -hl + 12.0, 0.2, C("paint"), OFF_PAINT, **top)
    z = -hl + 3.0
    while z < hl - 2.0:
        d.bar(d.d1, (-0.8, z), (0.8, z), 0.08, C("iron"), OFF_MARK, **top)
        z += 2.5
    d.chips(d.d2, 120, [C(n) for n in ("concrete", "concrete_dk", "stone", "steel")], maxslope=2.0)
    d.pass_flat(lambda i: concrete_color(d, i, (6.0, 2.0), "concrete_dk" if abs(i["lx"]) < 1.0 else "concrete", 0.05))
    return 0


def style_canal(d):
    hl, hx = d.len / 2, d.wid / 2
    top = dict(maxslope=6.0)
    z = -hl + 6.0
    while z < hl - 3.0:
        d.bar(d.base, (-hx, z), (hx, z), 0.12, C("joint"), OFF_PAINT, **top)
        z += 6.0
    d.rect(d.base, -hx, -hx + 0.55, -hl, hl, C("concrete_lt"), OFF_TOP, **top)
    d.rect(d.base, hx - 0.55, hx, -hl, hl, C("concrete_lt"), OFF_TOP, **top)
    d.rect(d.base, -hx + 0.7, hx - 0.7, -hl + 0.3, -hl + 9.0, C("concrete_dk"), OFF_PAINT, **top)
    d.rect(d.d1, -2.0, 2.0, -hl + 1.0, -hl + 3.0, C("iron"), OFF_TOP, **top)
    d.rect(d.d1, -1.4, 1.4, -hl + 3.6, -hl + 4.2, C("copper"), OFF_TOP, **top)
    for k in range(4):
        d.chevron(d.d1, 0.0, -hl + 14.0 + k * 2.4, 1, 1.4, 0.3, C("amber"), OFF_MARK, **top)
    for sgn in (-1, 1):
        d.bar(d.d1, (sgn * (hx - 1.0), -hl + 10.0), (sgn * (hx - 1.0), hl - 2.0), 0.6, C("stain"), OFF_PAINT, **top)
    d.chips(d.d2, 140, [C(n) for n in ("concrete", "concrete_lt", "concrete_dk")], maxslope=1.2)
    d.pass_flat(lambda i: concrete_color(d, i, (6.0, 8.0)))
    return 0


def style_tailwater(d):
    for _ in range(60):
        lx, lz = d.rng.uniform(-d.wid / 2 + 3, d.wid / 2 - 3), d.rng.uniform(-d.len / 2 + 3, d.len / 2 - 3)
        w, h = d.rng.uniform(1.5, 4.0), d.rng.uniform(4.0, 9.0)
        a = d.rng.uniform(-0.3, 0.3)
        pts = [(lx + w * math.cos(TAU * k / 8) * math.cos(a) - h * math.sin(TAU * k / 8) * math.sin(a),
                lz + w * math.cos(TAU * k / 8) * math.sin(a) + h * math.sin(TAU * k / 8) * math.cos(a)) for k in range(8)]
        d.decal(d.base, pts, tint(C(d.rng.choice(("gravel", "cobble2", "gravel2"))), d.rng.uniform(.9, 1.1)), OFF_PAINT)
    d.pebbles(d.d2, 45, [C(n) for n in ("cobble", "cobble2", "gravel2", "stone")], rmin=0.3, rmax=0.6)
    d.chips(d.d2, 200, [C(n) for n in ("gravel", "gravel2", "cobble2")])
    for _ in range(60):
        lx, lz = d.rng.uniform(-d.wid / 2 + 3, d.wid / 2 - 3), d.rng.uniform(-d.len / 2 + 3, d.len / 2 - 3)
        r = d.rng.uniform(0.5, 1.1)
        a0 = d.rng.uniform(0, TAU)
        d.decal(d.d1, [(lx + r * math.cos(a0 + TAU * k / 6), lz + r * math.sin(a0 + TAU * k / 6)) for k in range(6)], tint(C("cobble"), d.rng.uniform(.85, 1.1)), OFF_MARK)
    d.pass_flat(lambda i: tint(mixc(C("sand2"), C("gravel"), 0.5 + 0.3 * (hn(d.id, round(i["c"][0] / 2), round(i["c"][1] / 2)) - 0.5)), 0.95 + 0.1 * hn(d.id, i["c"][1])))
    return 0


def style_crest(d):
    hl = d.len / 2
    top = dict(maxslope=6.0)
    d.bar(d.base, (0.0, -hl + 0.5), (0.0, hl - 0.5), 0.35, C("amber"), OFF_PAINT, **top)
    z = -hl + 5.0
    while z < hl - 2.0:
        d.bar(d.d1, (-d.wid / 2, z), (d.wid / 2, z), 0.1, C("joint"), OFF_MARK, **top)
        z += 5.0
    for sgn in (-1, 1):
        d.bar(d.d1, (sgn * (d.wid / 2 - 0.3), -hl + 0.5), (sgn * (d.wid / 2 - 0.3), hl - 0.5), 0.12, C("concrete_lt"), OFF_TOP, **top)
    d.chips(d.d2, 160, [C(n) for n in ("concrete", "concrete_lt", "concrete_dk")], maxslope=1.2)
    d.pass_flat(lambda i: concrete_color(d, i, (5.0, 4.0)))
    return 0


def style_spillway(d):
    hl, hx = d.len / 2, d.wid / 2
    joint_grid(d, d.d1, 4.0, 6.0, C("joint"), 0.12, OFF_PAINT)
    for sgn in (-1, 1):
        d.bar(d.d1, (sgn * (hx - 6.0), -hl + 3.0), (sgn * (hx - 6.0), hl - 3.0), 0.8, C("stain"), OFF_MARK)
    d.chips(d.d2, 200, [C(n) for n in ("concrete", "concrete_lt", "concrete_dk", "wetrock")], maxslope=1.0)
    d.pass_flat(lambda i: mixc(concrete_color(d, i, (4.0, 6.0)), C("wet"), 0.35 if abs(i["lx"]) < hx * 0.4 else 0.0))
    return 0


def style_eye_floor(d):
    d.chips(d.d2, 200, [C(n) for n in ("cream", "sand", "red2", "cream3")])
    bedding_lines(d, d.d1, 30, C("cream2"), 8.0, minslope=0.0)
    return strata(d, SLICK, set_t=(1.0, 1.8), band_t=(0.5, 1.2), streak=0.0, crest=0.0, foot=0.0)


def style_eye_mouth(d):
    groove, lens = C("door"), C("lens")
    for r_out, r_in, seam in ((7.6, 7.2, True), (4.7, 4.3, True), (2.0, 1.7, False)):
        for j in range(36):
            a0, a1 = TAU * j / 36, TAU * (j + 1) / 36
            quad = [(r_out * math.cos(a0), r_out * math.sin(a0)), (r_out * math.cos(a1), r_out * math.sin(a1)),
                    (r_in * math.cos(a1), r_in * math.sin(a1)), (r_in * math.cos(a0), r_in * math.sin(a0))]
            d.decal(d.base, quad, groove, OFF_PAINT)
            if seam:
                mid = (r_out + r_in) / 2
                q2 = [(mid * 1.02 * math.cos(a0), mid * 1.02 * math.sin(a0)), (mid * 1.02 * math.cos(a1), mid * 1.02 * math.sin(a1)),
                      (mid * 0.98 * math.cos(a1), mid * 0.98 * math.sin(a1)), (mid * 0.98 * math.cos(a0), mid * 0.98 * math.sin(a0))]
                d.decal(d.base, q2, lens, OFF_MARK, slot="ancient_lens")
    for j in range(12):
        t = TAU * (j + 0.5) / 12
        c, s_ = math.cos(t), math.sin(t)
        d.bar(d.base, (4.9 * c, 4.9 * s_), (7.0 * c, 7.0 * s_), 0.28, groove, OFF_PAINT)
        d.bar(d.base, (5.4 * c, 5.4 * s_), (5.4 * c - 0.7 * s_, 5.4 * s_ + 0.7 * c), 0.22, groove, OFF_PAINT)
        d.bar(d.base, (5.1 * c, 5.1 * s_), (6.8 * c, 6.8 * s_), 0.07, lens, OFF_MARK, slot="ancient_lens")
    for j in range(24):
        t = TAU * (j + 0.25) / 24
        d.bar(d.d1, (8.4 * math.cos(t), 8.4 * math.sin(t)), (10.2 * math.cos(t), 10.2 * math.sin(t)), 0.18, groove, OFF_PAINT)
    bedding_lines(d, d.d1, 12, C("cream2"), 6.0, minslope=0.0)
    d.chips(d.d2, 200, [C(n) for n in ("cream", "sand", "red2", "cream3")])
    return strata(d, SLICK, set_t=(1.0, 1.8), band_t=(0.5, 1.2), streak=0.0, crest=0.0, foot=0.0)


STYLES = {}
for rid in ("wash_fin_west", "slot_fin_west", "slot_fin_east", "slot_fin_far", "domes_fin_west", "domes_fin_mid", "domes_fin_east", "eye_fin_west", "eye_fin_east"):
    STYLES[rid] = style_slick_fin
STYLES.update({
    "west_lane_fin": style_mesa, "east_lane_fin": style_mesa, "incline_spine": lambda d: style_mesa(d, spine=True),
    "eye_chute_west": style_canyon, "eye_chute_east": style_canyon,
    "eye_fall_spire_west": lambda d: style_canyon(d, hoodoo=True), "eye_fall_spire_east": lambda d: style_canyon(d, hoodoo=True),
    "pool_rock": style_pool_rock, "pool_pillar": style_pier, "training_wall_west": style_training_wall, "training_wall_east": style_training_wall,
    "cliff_rooms_west": style_rooms,
    "shelf_lip": lambda d: style_kicker(d, "slick"), "domes_kicker": lambda d: style_kicker(d, "slick"),
    "upper_slot_step": lambda d: style_kicker(d, "slick"), "corkscrew_step": lambda d: style_kicker(d, "slick"),
    "wash_kicker": lambda d: style_kicker(d, "concrete"), "outlet_bucket": lambda d: style_kicker(d, "bucket"),
    "apron_kicker": lambda d: style_kicker(d, "gravel"),
    "service_ledge": style_gallery, "lobber_ledge": style_gallery, "east_abutment": style_abutment, "powerhouse": style_powerhouse,
    "plunge_pool": style_plunge, "toe_vent_pits": style_vents, "pipeline_bridge": style_pipeline, "canal_lips": style_canal,
    "spillway_tunnel": style_spillway, "tailwater_bar": style_tailwater, "crest_rail": style_crest, "the_eye": style_eye_floor,
})
STYLES["eye_mouth"] = style_eye_mouth
ROWS = list(STYLES)
assert len(ROWS) == 41
EXTRA_ROWS = {"eye_mouth": {"id": "eye_mouth", "element": "elevated_line", "landform": "slickrock", "society": "ancient", "at": [0, 205], "y": None,
                            "size": [20, 0, 30], "yaw_deg": 180, "verb": "roll", "ride_fact": "layer_mind_quote_spillway", "home": "",
                            "recipe": "dam_eye_mouth", "fit": "drape", "stamp": "plateau", "hole": False, "budget": "landform", "routes": [], "fragment": ""}}
LARGE = {"the_eye", "spillway_tunnel", "toe_vent_pits"}
GATES = ("dam_survey_gate_red", "dam_survey_gate_blue", "dam_survey_benchmark")
HAS_COL = {"the_eye", "spillway_tunnel"}


def arch_color_fn(d, tones):
    """Strata by world height for the lofted solids; the soffit and walls a shade darker than the faces."""
    def f(kind, pts):
        y = sum(p[1] for p in pts) / len(pts)
        band = int(math.floor(y / 1.6))
        c = C(tones[(band * 7 + 3) % len(tones)])
        k = 0.9 + 0.14 * hn(d.id, "arch", band, kind, round(sum(p[0] for p in pts) / len(pts)))
        return tint(c, k * (0.88 if kind == "wall" else 1.0))
    return f


def node_local(d, p):
    """A world (x, y, z) point in the row node's space."""
    lx, lz = d.fr.local(p[0], p[2])
    return (lx, p[1] - d.fr.y0, lz)


def lump(out, rng, centre, size, color):
    pts = []
    for i in (-1, 1):
        for j in (-1, 1):
            for k in (-1, 1):
                pts.append(tuple(centre[a] + (i, j, k)[a] * size[a] / 2 * rng.uniform(0.75, 1.1) for a in range(3)))
    faces = [(0, 1, 3, 2), (4, 5, 7, 6), (0, 1, 5, 4), (2, 3, 7, 6), (0, 2, 6, 4), (1, 3, 7, 5)]
    convex_solid(out, "enamel", pts, faces, color)


def loft_world(d, out, col, slot, outline, zf, zb, color_of):
    """The lofted solid in world axes, to the node's space; the same triangles go to the collider when one is given."""
    n = len(outline)
    front = [(outline[k][0], outline[k][1], zf[k]) for k in range(n)]
    back = [(outline[k][0], outline[k][1], zb[k]) for k in range(n)]

    def emit(pts, color):
        local = [node_local(d, p) for p in pts]
        out.add(slot, local, color, up=False)
        if col is not None:
            col.add("col", local, color, up=False)

    for a, b, c in ear_clip(outline):
        emit([front[a], front[c], front[b]], color_of("front", [front[a], front[b], front[c]]))
        emit([back[a], back[b], back[c]], color_of("back", [back[a], back[b], back[c]]))
    for k in range(n):
        j = (k + 1) % n
        dx, dy = outline[j][0] - outline[k][0], outline[j][1] - outline[k][1]
        quad = [front[k], back[k], back[j], front[j]]
        nrm = [(quad[1][i] - quad[0][i]) for i in range(3)]
        e2 = [(quad[2][i] - quad[1][i]) for i in range(3)]
        cr = [nrm[1] * e2[2] - nrm[2] * e2[1], nrm[2] * e2[0] - nrm[0] * e2[2], nrm[0] * e2[1] - nrm[1] * e2[0]]
        if cr[0] * dy - cr[1] * dx < 0:
            quad = quad[::-1]
        emit(quad, color_of("wall", quad))


def face_marks(d, out, pts_xy, z, facing, color, slot="enamel"):
    """A flat polygon painted on a cap face of an arch: facing +1 faces +z (back), -1 faces -z (front)."""
    poly = [(x, y, z + facing * 0.05) for x, y in pts_xy]
    if facing < 0:
        poly = poly[::-1]
    out.add(slot, [node_local(d, p) for p in poly], color, up=False)


def build_eye(d, rows, extra, lens, col):
    """The Eye: a natural sandstone arch across the gap between the two Eye fins, over the ramp. Legs stand on the fins
    outside the ramp's width; the soffit clears the ramp floor by EYE_CLEAR and more everywhere under the arch."""
    g = d.g
    west, east = rows["eye_fin_west"], rows["eye_fin_east"]
    zc = west["at"][1]
    inner_w, inner_e = west["at"][0] + west["size"][0] / 2, east["at"][0] - east["size"][0] / 2
    assert abs(inner_w + inner_e) < 1e-6 and inner_e > d.wid / 2, "fins must leave the ramp's width between them"
    ramp_half = d.wid / 2
    fin_half = west["size"][2] / 2
    zlo, zhi = zc - fin_half - 2.0, zc + fin_half + 2.0
    F = max(g.h(x, z) for x in np.linspace(-ramp_half, ramp_half, 31) for z in np.linspace(zlo, zhi, 29))
    span = inner_e + 6.0
    ysp, apex = F + 8.0, F + 26.0
    thick_a, thick_s = 7.0, 13.0
    leg_out = span + 24.0

    def soffit(x):
        return ysp + (apex - ysp) * math.sqrt(max(0.0, 1.0 - (x / span) ** 2))

    legs = [g.h(sx * x, z) for sx in (-1, 1) for x in np.linspace(span, leg_out, 13) for z in np.linspace(zlo, zhi, 9)]
    yb = min(legs) - 3.0
    n = 18
    soff = [(-span + 2 * span * k / n, soffit(-span + 2 * span * k / n)) for k in range(n + 1)]
    ext = []
    for x, ys in soff:
        t = thick_a + (thick_s - thick_a) * (abs(x) / span) ** 2
        ext.append((x * (1.0 + 0.12 * (abs(x) / span) ** 2), ys + t))
    yt_out = max(max(legs) + 4.0, ext[0][1] - 3.0)
    outline = [(-leg_out, yb), (-span, yb)] + soff + [(span, yb), (leg_out, yb), (leg_out, yt_out)] + ext[::-1] + [(-leg_out, yt_out)]
    rng = random.Random(seed_of("eye-arch"))
    hf, hb = fin_half - 0.5, fin_half + 1.5
    zf = [zc - hf - 1.0 * math.sin(k * 1.3) for k in range(len(outline))]
    zb = [zc + hb + 1.0 * math.sin(k * 0.9 + 1.0) for k in range(len(outline))]
    zf0, zb0 = zc - hf, zc + hb
    zf, zb = [zf0] * len(outline), [zb0] * len(outline)
    tones = ["cream", "sand", "red2", "cream2", "red", "sand2"]
    loft_world(d, extra, col, "enamel", outline, zf, zb, arch_color_fn(d, tones))
    for k in range(18):
        x = -leg_out + 2.0 + (2 * leg_out - 4.0) * rng.random()
        ytop = np.interp(x, [p[0] for p in ext], [p[1] for p in ext]) if abs(x) <= ext[-1][0] else yt_out
        lump(extra, rng, node_local(d, (x, ytop - 0.4, zc + rng.uniform(-fin_half, fin_half))), (rng.uniform(2.0, 4.5), rng.uniform(1.2, 2.6), rng.uniform(2.5, 5.0)),
             tint(C(rng.choice(tones)), rng.uniform(0.85, 1.05)))
    rim = [(x, y - 2.4) for x, y in ext]
    for k in range(1, len(rim) - 1):
        x, y = rim[k]
        for facing, z in ((-1, zf0), (1, zb0)):
            for sgn in (-1, 1):
                a = (x + sgn * 0.0, y + 0.9)
                b = (x + sgn * 1.0, y - 0.1)
                dx, dy = b[0] - a[0], b[1] - a[1]
                ln = math.hypot(dx, dy)
                nx, ny = -dy / ln * 0.09, dx / ln * 0.09
                face_marks(d, lens, [(a[0] - nx, a[1] - ny), (b[0] - nx, b[1] - ny), (b[0] + nx, b[1] + ny), (a[0] + nx, a[1] + ny)], z, facing, C("lens"), "ancient_lens")
    worst = min(soffit(x) - g.h(x, z) for x in np.linspace(-ramp_half, ramp_half, 61) for z in np.linspace(max(zf0, zc - fin_half), zb0, 41)
                if zf0 <= z <= zb0)
    assert worst >= EYE_CLEAR + 2.0, ("the_eye soffit clearance", worst)
    return {"clear_m": round(worst, 2), "apex_over_floor_m": round(apex - F, 2), "span_m": span}


def build_portal(d, extra, col):
    """The spillway portal: a concrete headwall arch at the upstream end of the chute, spanning the wash cut with its
    legs outside the cut and at least PORTAL_CLEAR over the wash floor across the whole width."""
    g = d.g
    cx, hw = d.row["at"][0], d.wid / 2
    z_up = d.row["at"][1] - d.len / 2 + 2.0
    if g.h(cx, d.row["at"][1] - d.len / 2) < g.h(cx, d.row["at"][1] + d.len / 2):
        z_up = d.row["at"][1] + d.len / 2 - 2.0
    zf0, zb0 = z_up - 4.0, z_up + 4.0
    face = hw + 2.0
    leg = 8.0
    xs = np.linspace(cx - face - leg, cx + face + leg, 41)
    zs = np.linspace(zf0, zb0, 9)
    B = max(g.h(x, z) for x in xs for z in zs)
    legs = [g.h(x, z) for x in np.concatenate([np.linspace(cx - face - leg, cx - face, 9), np.linspace(cx + face, cx + face + leg, 9)]) for z in zs]
    yb = min(legs) - 3.0
    ytop = B + PORTAL_CLEAR + 11.0

    def soffit(x):
        return B + PORTAL_CLEAR + 6.0 * (1.0 - ((x - cx) / face) ** 2)

    n = 16
    soff = [(cx - face + 2 * face * k / n, soffit(cx - face + 2 * face * k / n)) for k in range(n + 1)]
    outline = [(cx - face - leg, yb), (cx - face, yb)] + soff + [(cx + face, yb), (cx + face + leg, yb), (cx + face + leg, ytop), (cx - face - leg, ytop)]
    tones = ["concrete", "concrete2", "concrete_lt", "concrete"]
    loft_world(d, extra, col, "enamel", outline, [zf0] * len(outline), [zb0] * len(outline), arch_color_fn(d, tones))
    facing = -1 if z_up < d.row["at"][1] else 1
    zface = zf0 if facing < 0 else zb0
    for side in (-1, 1):
        for k in range(1, 4):
            x = cx + side * (face + k * leg / 4.0)
            face_marks(d, extra, [(x - 0.06, yb + 3.0), (x + 0.06, yb + 3.0), (x + 0.06, ytop), (x - 0.06, ytop)], zface, facing, C("joint"))
    for yy in (B + PORTAL_CLEAR + 7.2, B + PORTAL_CLEAR + 9.0):
        face_marks(d, extra, [(cx - face - leg, yy - 0.05), (cx + face + leg, yy - 0.05), (cx + face + leg, yy + 0.05), (cx - face - leg, yy + 0.05)], zface, facing, C("joint"))
    face_marks(d, extra, [(cx - face - leg, ytop - 1.6), (cx + face + leg, ytop - 1.6), (cx + face + leg, ytop - 0.9), (cx - face - leg, ytop - 0.9)], zface, facing, C("amber"))
    worst = min(soffit(x) - g.h(x, z) for x in np.linspace(cx - hw, cx + hw, 61) for z in zs)
    assert worst >= PORTAL_CLEAR, ("portal clearance over the wash floor", worst)
    assert face > hw, "legs stand outside the cut"
    return {"clear_m": round(worst, 2), "z": round(z_up, 2)}


def build_gate(rid):
    """A survey gate for a dome summit: the cairn's foot at local (0, 16 - GATE_SINK, 0). A `dome_N` row's 16 m spire
    stamp is flat over its inner 40 percent of the radius but rides the shelf's fall (about 6.5 percent along z), so the
    gate sits GATE_SINK under the seat's summit and keeps every stone within 2 m of the pole: the downhill edge stays
    bedded and the uphill stones sink into the rock instead of one side floating. No collider."""
    flag = C("flag_red") if rid.endswith("red") else C("copper") if rid.endswith("benchmark") else C("flag_blue")
    pole = 6.0 if not rid.endswith("benchmark") else 1.4
    rng = random.Random(seed_of(rid))
    base, d1, d2 = Out(BUDGETS["landform"]["tris"]), Out(DETAIL_TRIS), Out(DETAIL_TRIS)
    foot = 16.0 - GATE_SINK
    stones = ["sand", "sand2", "cream3", "talus", "cream"]
    prism_xz(base, "enamel", [(0.55 * math.cos(TAU * k / 10), 0.55 * math.sin(TAU * k / 10)) for k in range(10)], foot, foot + 1.15, C("sand2"))
    for c, (count, radius, size) in enumerate(((7, 0.78, 0.5), (6, 0.66, 0.46), (5, 0.52, 0.42), (4, 0.36, 0.38))):
        a0 = rng.uniform(0, TAU)
        for k in range(count):
            a = a0 + TAU * k / count + rng.uniform(-0.12, 0.12)
            lump(base, rng, (radius * math.cos(a), foot + 0.17 + 0.3 * c, radius * math.sin(a)), (size, 0.3, size * rng.uniform(0.85, 1.1)), tint(C(rng.choice(stones)), rng.uniform(.88, 1.06)))
    ring = 12
    r_in, r_out = 0.86, 0.98
    for k in range(ring):
        a0, a1 = TAU * k / ring, TAU * (k + 1) / ring
        prism_xz(base, "enamel", [(r_in * math.cos(a0), r_in * math.sin(a0)), (r_out * math.cos(a0), r_out * math.sin(a0)),
                                  (r_out * math.cos(a1), r_out * math.sin(a1)), (r_in * math.cos(a1), r_in * math.sin(a1))], foot + 0.5, foot + 0.78, flag)
    top = foot + 1.25
    prism_xz(base, "enamel", [(0.24 * math.cos(TAU * k / 12), 0.24 * math.sin(TAU * k / 12)) for k in range(12)], top, top + 0.06, C("copper"))
    rod_solid(base, "steel", (0.0, top + 0.06, 0.0), (0.0, top + 0.06 + pole, 0.0), 0.04, C("steel_lt"))
    yp = top + pole
    if pole < 6.0:
        prism_xz(base, "enamel", [(0.09 * math.cos(TAU * k / 8), 0.09 * math.sin(TAU * k / 8)) for k in range(8)], yp, yp + 0.08, C("copper"))
    else:
        convex_solid(base, "enamel", [(0.04, yp - 0.85, -0.012), (0.04, yp - 0.1, -0.012), (1.45, yp - 0.5, -0.012),
                                       (0.04, yp - 0.85, 0.012), (0.04, yp - 0.1, 0.012), (1.45, yp - 0.5, 0.012)],
                     [(0, 1, 2), (3, 4, 5), (0, 1, 4, 3), (1, 2, 5, 4), (2, 0, 3, 5)], flag)
    for k in range(10):
        a = TAU * k / 10 + rng.uniform(-0.1, 0.1)
        r = rng.uniform(1.25, 1.9)
        lump(d1, rng, (r * math.cos(a), foot + 0.14, r * math.sin(a)), (rng.uniform(0.3, 0.6), 0.24, rng.uniform(0.3, 0.6)), tint(C(rng.choice(stones)), rng.uniform(.85, 1.05)))
    for yy in [top + h for h in (0.9, 3.0, 5.4) if h < pole]:
        prism_xz(d1, "enamel", [(0.075 * math.cos(TAU * k / 8), 0.075 * math.sin(TAU * k / 8)) for k in range(8)], yy, yy + 0.07, C("steel_lt"))
    box_solid(d1, "enamel", (-0.16, foot + 0.9, 0.9), (0.16, foot + 1.08, 0.94), C("copper"))
    for k in range(40):
        a, r = rng.uniform(0, TAU), rng.uniform(1.1, GATE_REACH)
        x, z = r * math.cos(a), r * math.sin(a)
        rr = rng.uniform(0.12, 0.34)
        a0 = rng.uniform(0, TAU)
        ring6 = [(x + rr * math.cos(a0 + TAU * j / 6), z + rr * math.sin(a0 + TAU * j / 6)) for j in range(6)]
        top6 = [(x + 0.55 * rr * math.cos(a0 + TAU * j / 6), z + 0.55 * rr * math.sin(a0 + TAU * j / 6)) for j in range(6)]
        col = tint(C(rng.choice(stones)), rng.uniform(0.9, 1.08))
        if d2.tris() + 16 > DETAIL_TRIS:
            break
        for j in range(6):
            q = (j + 1) % 6
            d2.add("enamel", [(ring6[j][0], foot + 0.0, ring6[j][1]), (ring6[q][0], foot + 0.0, ring6[q][1]), (top6[q][0], foot + 0.1, top6[q][1]), (top6[j][0], foot + 0.1, top6[j][1])], tint(col, 0.9 + 0.02 * j))
        d2.add("enamel", [(p[0], foot + 0.1, p[1]) for p in top6], tint(col, 1.05))
    return base, d1, d2


CRANE = "dam_crest_crane"
CRANE_TOP = 28.0
CRANE_JIB = 34.0


def build_crane():
    """The dam crew's tower crane on the crest (Andrew's "All hands": during the Mind's quote it swings once, empty).
    Two meshes: the mast with its cab (dam_crest_crane) and the jib, counter-jib and empty hook (dam_crest_crane_jib),
    both with the mast's axis at local x = z = 0 and the crest at y 0, so the jib turns about the node's own y axis.
    Members are chunky on purpose: the crane reads from the Eye, about 450 m off. No collider."""
    mast, jib, d1, d2 = Out(BUDGETS["landform"]["tris"] // 2), Out(BUDGETS["landform"]["tris"] // 2), Out(DETAIL_TRIS), Out(DETAIL_TRIS)
    paint, paint2, rust = C("ochre"), tint(C("ochre"), 0.82), C("rust")
    h = 1.6
    legs = [(-h, -h), (h, -h), (h, h), (-h, h)]
    box_solid(mast, "enamel", (-2.6, -0.6, -2.6), (2.6, 0.5, 2.6), C("concrete_dk"))
    for x, z in legs:
        rod_solid(mast, "enamel", (x, 0.0, z), (x, CRANE_TOP, z), 0.22, paint, sides=4)
    step = 2.8
    y = 0.0
    while y + step <= CRANE_TOP + 0.01:
        for k in range(4):
            a, b = legs[k], legs[(k + 1) % 4]
            rod_solid(mast, "enamel", (a[0], y, a[1]), (b[0], y + step, b[1]), 0.1, paint2, sides=4)
            rod_solid(mast, "enamel", (a[0], y + step, a[1]), (b[0], y + step, b[1]), 0.12, paint, sides=4)
        y += step
    box_solid(mast, "enamel", (-2.0, CRANE_TOP - 0.6, -2.0), (2.0, CRANE_TOP, 2.0), rust)
    top = CRANE_TOP
    box_solid(jib, "enamel", (-1.6, top, -1.6), (1.6, top + 0.4, 1.6), rust)
    box_solid(jib, "enamel", (-1.3, top + 0.4, 1.7), (1.3, top + 3.0, 4.5), paint)
    box_solid(jib, "enamel", (-1.1, top + 1.6, 4.5), (1.1, top + 2.7, 4.56), C("glass"))
    rod_solid(jib, "enamel", (0.0, top + 0.4, 0.0), (0.0, top + 7.0, 0.0), 0.2, paint, sides=4)
    w, d = 0.9, 1.6
    ch = [(-w, top + 0.4), (w, top + 0.4), (0.0, top + 0.4 + d)]
    for x, yy in ch:
        rod_solid(jib, "enamel", (x, yy, 0.0), (x * 0.4, yy - (0.6 if yy > top + 1 else 0.0), CRANE_JIB), 0.16, paint, sides=4)
    n = 12
    for k in range(n):
        z0, z1 = CRANE_JIB * k / n, CRANE_JIB * (k + 1) / n
        for i in range(3):
            a, b = ch[i], ch[(i + 1) % 3]
            rod_solid(jib, "enamel", (a[0], a[1], z0), (b[0], b[1], z1), 0.08, paint2, sides=4)
    box_solid(jib, "enamel", (-0.7, top + 0.32, 4.6), (0.7, top + 0.4, CRANE_JIB - 0.5), C("steel"))
    rod_solid(jib, "enamel", (0.0, top + 7.0, 0.0), (0.0, top + 0.4 + d, CRANE_JIB * 0.7), 0.06, C("steel_lt"), sides=4)
    cj = CRANE_JIB * 0.3
    for x in (-w, w):
        rod_solid(jib, "enamel", (x, top + 0.4, 0.0), (x, top + 0.4, -cj), 0.16, paint, sides=4)
    rod_solid(jib, "enamel", (0.0, top + 7.0, 0.0), (0.0, top + 0.6, -cj), 0.06, C("steel_lt"), sides=4)
    box_solid(jib, "enamel", (-1.5, top - 1.4, -cj + 0.2), (1.5, top + 0.4, -cj + 3.2), C("concrete"))
    box_solid(jib, "enamel", (-1.0, top + 0.1, CRANE_JIB - 9.0), (1.0, top + 0.5, CRANE_JIB - 7.6), rust)
    rod_solid(jib, "enamel", (0.0, top + 0.1, CRANE_JIB - 8.3), (0.0, top - 9.0, CRANE_JIB - 8.3), 0.05, C("iron"), sides=4)
    box_solid(jib, "enamel", (-0.5, top - 10.4, CRANE_JIB - 8.8), (0.5, top - 9.0, CRANE_JIB - 7.8), C("amber"))
    for yy in [0.6 + 0.6 * k for k in range(int((CRANE_TOP - 1.0) / 0.6))]:
        if d1.tris() + 12 > DETAIL_TRIS:
            break
        box_solid(d1, "enamel", (h + 0.05, yy, -0.3), (h + 0.12, yy + 0.05, 0.3), C("steel_lt"))
    for x in (-0.35, 0.35):
        box_solid(d1, "enamel", (h + 0.08, 0.0, x - 0.03), (h + 0.14, CRANE_TOP, x + 0.03), C("steel_lt"))
    for k in range(16):
        a = TAU * k / 16
        box_solid(d2, "enamel", (2.2 * math.cos(a) - 0.08, 0.5, 2.2 * math.sin(a) - 0.08), (2.2 * math.cos(a) + 0.08, 0.68, 2.2 * math.sin(a) + 0.08), C("iron"))
    return mast, jib, d1, d2


SLOT_ORDER = ("enamel", "steel", "ancient_lens")


def xyz(v):
    return (v[0], -v[2], v[1])


def slot_material(slot):
    import bpy
    mat = bpy.data.materials.get(slot)
    if mat is not None:
        return mat
    mat = bpy.data.materials.new(slot)
    mat.use_nodes = True
    bsdf = mat.node_tree.nodes.get("Principled BSDF")
    bsdf.inputs["Roughness"].default_value = 0.93 if slot == "enamel" else 0.5 if slot == "steel" else 0.3
    bsdf.inputs["Metallic"].default_value = 0.5 if slot == "steel" else 0.0
    if slot == "ancient_lens":
        import common
        lin = common.rgba(C("lens"))
        bsdf.inputs["Base Color"].default_value = lin
        bsdf.inputs["Emission Color"].default_value = lin
        bsdf.inputs["Emission Strength"].default_value = 3.0
    else:
        attr = mat.node_tree.nodes.new("ShaderNodeVertexColor")
        attr.layer_name = "Color"
        mat.node_tree.links.new(attr.outputs["Color"], bsdf.inputs["Base Color"])
    return mat


def make_mesh(name, outs, root, colored=True):
    """outs: [Out] merged into one mesh node, one material per slot; "col" polygons are never coloured."""
    import bpy
    import common
    verts, tris, cols, mats, slots = [], [], [], [], []
    for slot in SLOT_ORDER + ("col",):
        polys = [pc for out in outs for pc in out.slots.get(slot, [])]
        if not polys:
            continue
        if slot != "col":
            slots.append(slot)
        mi = slots.index(slot) if slot in slots else 0
        for pts, color in polys:
            b = len(verts)
            verts += [xyz(p) for p in pts]
            for k in range(1, len(pts) - 1):
                tris.append((b, b + k, b + k + 1))
                cols.append(color)
                mats.append(mi)
    mesh = bpy.data.meshes.new(name)
    mesh.from_pydata(verts, [], tris)
    mesh.update()
    for poly in mesh.polygons:
        poly.use_smooth = False
        poly.material_index = mats[poly.index]
    if colored:
        attr = mesh.color_attributes.new(name="Color", type="FLOAT_COLOR", domain="CORNER")
        for poly in mesh.polygons:
            for li in poly.loop_indices:
                attr.data[li].color = common.rgba(cols[poly.index])
        mesh.color_attributes.active_color = attr
        for slot in slots:
            mesh.materials.append(slot_material(slot))
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.scene.collection.objects.link(obj)
    obj.parent = root
    return obj


def gltf_metrics(path):
    data = Path(path).read_bytes()
    length = struct.unpack_from("<I", data, 12)[0]
    doc = json.loads(data[20:20 + length])
    tris = verts = draws = 0
    lo, hi = [float("inf")] * 3, [-float("inf")] * 3
    per = {}
    for mesh in doc["meshes"]:
        t = v = 0
        for prim in mesh["primitives"]:
            p = doc["accessors"][prim["attributes"]["POSITION"]]
            v += p["count"]
            t += doc["accessors"][prim["indices"]]["count"] // 3
            draws += 1
            if not mesh.get("name", "").endswith("-col"):
                for k in range(3):
                    lo[k], hi[k] = min(lo[k], p["min"][k]), max(hi[k], p["max"][k])
        per[mesh.get("name", "")] = {"tris": t, "verts": v}
        tris += t
        verts += v
    return {"triangles": tris, "vertices": verts, "primitives": draws, "meshes": per, "materials": [m["name"] for m in doc.get("materials", [])],
            "bounds": {"min": [round(x, 4) for x in lo], "max": [round(x, 4) for x in hi]}}


def export_one(path, name, nodes):
    import common
    common.reset()
    root = common.empty(name + "_root")
    for node_name, outs, colored in nodes:
        make_mesh(node_name, outs, root, colored)
    common.export(root, str(path))
    return gltf_metrics(path)


def load_rows():
    park = json.loads(PARK_FILE.read_text())
    return {r["id"]: r for r in park["park_rows"]}


def build_row(rid, rows, ground):
    """Everything one `dam_<rid>` recipe holds: the dresser, the exception parts and the notes."""
    row = rows[rid]
    large = rid in LARGE
    cls = "park_large" if large else "landform"
    cap = BUDGETS[cls]["tris"]
    extra, lens, col = Out(cap), Out(cap), Out(cap)
    order = [r for r in rows if r in STYLES]
    d = Dress(row, ground, cap, covered=covered_by(rid, rows, order))
    notes = {}
    d.base.cap = cap
    if rid == "the_eye":
        notes.update(build_eye(d, rows, extra, lens, col))
        d.base.cap = cap - extra.tris() - lens.tris() - col.tris()
    elif rid == "spillway_tunnel":
        notes.update(build_portal(d, extra, col))
        d.base.cap = cap - extra.tris() - col.tris()
    STYLES[rid](d)
    return d, extra, lens, col, cls, notes


def check_flush(d, rid):
    """Every drawn drape vertex stands between 0 and FLUSH over the ground under it (the contract the test repeats)."""
    lo, hi = 9.0, -9.0
    for out in (d.base, d.d1, d.d2):
        for polys in out.slots.values():
            for pts, _ in polys:
                for lx, ly, lz in pts:
                    x, z = d.fr.world(lx, lz)
                    off = ly + d.fr.y0 - d.g.h(x, z)
                    lo, hi = min(lo, off), max(hi, off)
    assert lo > 0.0 and hi <= FLUSH, (rid, "drape vertices outside 0..FLUSH", lo, hi)
    return round(lo, 4), round(hi, 4)


def counts_of(base, extra, col, d1, d2):
    return {"base": base, "col": col, "detail1": d1, "detail2": d2}


def build(rid, out_dir, rows, ground, count_only=False):
    name = rid if rid in GATES or rid == CRANE else "dam_" + rid
    if rid == CRANE:
        mast, jib, d1, d2 = build_crane()
        info = {"counts": {"base": mast.tris() + jib.tris(), "col": 0, "detail1": d1.tris(), "detail2": d2.tris()}, "cls": "landform", "flush": None}
        base_nodes = [(CRANE, [mast], True), (CRANE + "_jib", [jib], True)]
        shells = (d1, d2)
        has_col = False
        notes = {}
    elif rid in GATES:
        base, d1, d2 = build_gate(rid)
        info = {"counts": {"base": base.tris(), "col": 0, "detail1": d1.tris(), "detail2": d2.tris()}, "cls": "landform", "flush": None}
        base_nodes = [(rid, [base], True)]
        shells = (d1, d2)
        has_col = False
        notes = {}
    else:
        d, extra, lens, col, cls, notes = build_row(rid, rows, ground)
        flush = check_flush(d, rid)
        base_total = d.base.tris() + extra.tris() + lens.tris() + col.tris()
        assert base_total <= BUDGETS[cls]["tris"], (rid, "base over class", base_total, cls)
        info = {"counts": {"base": d.base.tris() + extra.tris() + lens.tris(), "col": col.tris(), "detail1": d.d1.tris(), "detail2": d.d2.tris()},
                "cls": cls, "flush": flush}
        has_col = rid in HAS_COL
        if has_col:
            base_nodes = [(name, [d.base], True), (name + "_arch", [extra, lens], True), (name + "-col", [col], False)]
        else:
            base_nodes = [(name, [d.base], True)]
        shells = (d.d1, d.d2)
    info["notes"] = notes
    print("DAM_COUNT", name, json.dumps(info["counts"], sort_keys=True), info["flush"] or "", json.dumps(notes, sort_keys=True))
    for k, s in enumerate(shells, 1):
        assert 0 < s.tris() <= DETAIL_TRIS, (name, "detail", k, s.tris())
    if count_only:
        return name, info, {}
    glb = {}
    out = Path(out_dir)
    files = [(name, base_nodes), (name + "_detail1", [(name + "_detail1", [shells[0]], True)]), (name + "_detail2", [(name + "_detail2", [shells[1]], True)])]
    for fname, nodes in files:
        path = out / (fname + ".glb")
        m = export_one(path, fname, nodes)
        cls_name = info["cls"] if fname == name else "detail"
        cap = BUDGETS[cls_name]
        if fname == name:
            assert m["triangles"] <= cap["tris"] and m["vertices"] <= cap["verts"], (fname, m["triangles"], m["vertices"], cap)
        else:
            assert m["triangles"] <= cap["tris"] and m["vertices"] <= cap["verts"] and m["primitives"] == 1, (fname, m)
        glb[fname] = {"file": path.name, "sha256": hashlib.sha256(path.read_bytes()).hexdigest(), "class": cls_name, **{k: m[k] for k in ("triangles", "vertices", "primitives", "materials", "bounds")}}
        print("DAM_EXPORT", fname, json.dumps({k: glb[fname][k] for k in ("triangles", "vertices", "primitives", "sha256")}, sort_keys=True))
    return name, info, glb


def registry_rows(results):
    rows = []
    for name, info, glb in results:
        for fname, g in glb.items():
            row = {"id": fname, "path": "res://assets/models/park/%s.glb" % fname, "class": g["class"], "ships": True}
            if fname == name:
                what = "a dome-summit survey gate" if name in GATES else "the crest crane (mast and jib meshes; the jib swings on the Mind's quote)" if name == CRANE else "the drape recipe of park row %s" % name[4:]
                row["loader"] = "src/world/park/park_recipes.gd place (the park row's recipe id; base mesh %s, material enamel%s; visibility range from the %s class)" % (
                    what, "" if name in GATES or name == CRANE or name[4:] not in HAS_COL else " and its -col trimesh", g["class"])
            else:
                shell = fname[-1]
                row["loader"] = "src/world/park/park_recipes.gd place (detail shell %s at the base GLB's origin, visibility range from the landform class shells[%d]; material enamel)" % (shell, int(shell) - 1)
            row["provenance"] = {"recipe": "tools/blender/park/dam_dressing.py",
                                 "notes": "design-v3/park/stages/1-park_dam.md section 15 follow-up (dam kit): built from assets/park/park_dam/ground.bin and src/world/park/park_dam.json, "
                                          "deterministic; vertices relative to the row node at its base height"}
            if fname == name and name == "dam_the_eye":
                row["exception"] = {"draws": 4}
                row["exception_why"] = "The enamel floor drape, the arch (enamel) with its ancient_lens carved marks, and the arch's -col trimesh are four primitives; the park_large class allows two."
            if fname == name and name == "dam_spillway_tunnel":
                row["exception"] = {"draws": 3}
                row["exception_why"] = "The concrete chute drape, the portal headwall arch and its -col trimesh are three primitives; the park_large class allows two."
            if fname == name and name == "dam_eye_mouth":
                row["exception"] = {"draws": 2}
                row["exception_why"] = "Enamel grooves and the ancient_lens seams are two material slots on one mesh; the landform class allows one draw."
            if fname == name and name == CRANE:
                row["exception"] = {"draws": 2}
                row["exception_why"] = "The mast and the jib are two meshes so the jib can turn on the Mind's quote; one enamel slot each."
            if fname == name and name in GATES:
                row["exception"] = {"draws": 2}
                row["exception_why"] = "The enamel cairn and flag and the steel survey pole are two material slots on one mesh; the landform class allows one draw."
            row["bounds"] = {"min": g["bounds"]["min"], "max": g["bounds"]["max"], "size": [round(g["bounds"]["max"][k] - g["bounds"]["min"][k], 4) for k in range(3)]}
            rows.append(row)
    return rows


def write_park(rows, ground, out_path):
    """Sets recipe, fit (drape), y (null) and budget on the 40 dressed rows, one line each, leaving every other byte alone."""
    import re
    text = Path(out_path).read_text().split("\n")
    done = set()
    for k, line in enumerate(text):
        m = re.match(r'\s*\{"id": "([a-z_0-9]+)"', line)
        if not m or m.group(1) not in STYLES:
            continue
        rid = m.group(1)
        row = rows[rid]
        budget = "park_large" if rid in LARGE else "landform"
        line = re.sub(r'"recipe": "[^"]*"', '"recipe": "dam_%s"' % rid, line, count=1)
        line = re.sub(r'"y": (null|-?[0-9.]+)', '"y": null', line, count=1)
        if '"fit"' not in line:
            line = re.sub(r'("recipe": "dam_%s")' % rid, r'\1, "fit": "drape"', line, count=1)
        line = re.sub(r'"budget": "[^"]*"', '"budget": "%s"' % budget, line, count=1)
        text[k] = line
        done.add(rid)
    for rid, extra_row in EXTRA_ROWS.items():
        if rid in done:
            continue
        row = rows[rid]
        at = next(k for k, line in enumerate(text) if re.match(r'\s*\{"id": "the_eye"', line))
        text.insert(at + 1, "  " + json.dumps(row) + ",")
        done.add(rid)
    assert done == set(STYLES), sorted(set(STYLES) - done)
    Path(out_path).write_text("\n".join(text))


def main():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else sys.argv[1:]
    parser = argparse.ArgumentParser()
    parser.add_argument("--out-dir", default=str(MODELS))
    parser.add_argument("--only", default="")
    parser.add_argument("--count-only", action="store_true")
    parser.add_argument("--log", default=None)
    parser.add_argument("--registry", default=None, help="write the registry fragment for the built recipes to this file")
    parser.add_argument("--write-park", action="store_true", help="set recipe, fit, y and budget on the dressed rows of park_dam.json")
    parser.add_argument("--park", default=str(PARK_FILE))
    args = parser.parse_args(argv)
    sys.path.insert(0, str(HERE.parent))
    rows = json.loads(Path(args.park).read_text())
    rows = {r["id"]: r for r in rows["park_rows"]}
    for k, v in EXTRA_ROWS.items():
        rows.setdefault(k, dict(v))
    ground = Ground()
    wanted = [i.strip() for i in args.only.split(",") if i.strip()]
    ids = [("dam_" + r) for r in ROWS] + list(GATES) + [CRANE]
    if wanted:
        ids = [i for i in ids if i in wanted]
    results = []
    for full in ids:
        rid = full if full in GATES or full == CRANE else full[4:]
        results.append(build(rid, args.out_dir, rows, ground, args.count_only))
    if args.log:
        Path(args.log).parent.mkdir(parents=True, exist_ok=True)
        Path(args.log).write_text(json.dumps({n: {"counts": i["counts"], "glb": g} for n, i, g in results}, indent=1, sort_keys=True) + "\n")
    if args.registry and not args.count_only:
        Path(args.registry).write_text(json.dumps({"assets": registry_rows(results)}, indent=1) + "\n")
    if args.write_park:
        write_park(rows, ground, args.park)


if __name__ == "__main__":
    main()
