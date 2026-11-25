"""Lived-in dry-wash liners for any park's half_pipe (WASH) and stamped flow_line "ramp" (WASH_RAMP) rows.

washes_README  (how World runs this for park_islands: cloud_wash_west, cloud_wash_east, run_turn_wash)

  1. The park must be baked: assets/park/<park>/ground.bin exists and src/world/park/<park>.json holds the rows.
  2. Build (the builder reads only the rows named; it edits no park JSON and no other module):
       cpuq --cores 2 --name <lane> -- nice -n 10 blender --background --threads 2 \
         --python-exit-code 1 --python sketches/core-loop/tools/blender/park/washes.py -- \
         --park park_islands --rows cloud_wash_west,cloud_wash_east,run_turn_wash [--out-dir DIR]
     --park accepts "crown" or "park_crown" (the park JSON stem, with or without the prefix); --bake-dir DIR overrides
     assets/park/<park>/ and --json FILE overrides the park JSON. Output is three GLBs per row under --out-dir
     (default assets/models/park): liner_<row>.glb, liner_<row>_detail1.glb, liner_<row>_detail2.glb.
  3. Verify (re-reads ground.bin; reports the vertical gap mesh-to-ground; exits 1 on a failure):
       ... washes.py -- --park park_islands --rows ... --check
  4. Register: write the fragment, then fold it from the repository root:
       ... washes.py -- --park park_islands --rows ... --registry > sketches/core-loop/assets/registry.d/park_islands_washes.json
       python3 sketches/core-loop/tools/fold_registry.py
  5. Wire each row in its park JSON (World's edit, not this tool's): "recipe": "liner_<row>"; keep stamp, y, size and routes.
  Row fields read: id, element (flow_line with stamp "ramp" builds WASH_RAMP, anything else WASH), stamp, at [x, z], size
  [length, height, width] (length runs along the row's local z, width across x), yaw_deg. Nothing else is read. Rebuild after
  a re-bake: every vertex is conformed to ground.bin.

Contract (the same as flume_works.py section D, whose helpers it imports unchanged): decoration only, NO -col mesh; the
stamped terrain stays the only collider. Registry origin "centre", no fit: park_recipes.gd places the GLB rigidly at the
row's `at`, y = ground(at), turned by yaw_deg, never scaled, so every vertex carries local y = ground(world x, z) -
ground(at) + an offset. The middle 40 % of the width (|x| <= 0.2 W) is flush: lattice only, never above BASE_OFF + 0.03
over the ground. Mud cracks are 0.10 m wide mud-brown ribbons lying 0.05 m over the ground (0.015 m over the floor lattice).
Raised features of the lattice stay under 0.25 m; strata ledge shelves stand 0.1 to 0.2 m off the bank; props (driftwood, root
balls, bent corrugated sheet, pipe sections, gravel bars, boulders) stay under PROP_TOP = 1.2 m over the ground and sit outside the
flush band.

Look pass v3 (2026-10-18): crack seams are mud-brown ribbons 0.10 m wide on a 2 m hex tile lattice (the middle lane keeps half of
them, the rest go to detail2); props are 2 big clusters (root ball, three-log jam of 0.8 to 1.0 m logs, bent sheet, two pipes) plus
3 gravel bars 1.2 m tall and 5 to 8 m long per wash; strata have real ledge shelves; the cap is one smooth grey-tan band; a ramp's
flush corridor is 0.04 W (the whole slope is ride line) and it carries streaks, 40 boulders of 0.6 to 1.2 m in 8 groups, 8 sand
drifts and 3 clusters. Detail shells only show
within range of the row centre, so the base carries the look.

What each liner holds (everything deterministic: the seed is the row id, no clock, no unseeded randomness):
  base    cracked mud floor on a jittered hex tile lattice (plate tops as vertex colour, mud-brown seam ribbons);
          curled mud plates at the floor margin only; cut bank with banded strata (sandstone cream, ochre-tan, red-brown,
          grey cap) as colour bands plus shallow ledge lips; sun-bleached driftwood and root balls, rusted bent corrugated
          sheet and pipe sections half-buried against the banks and at bends; gravel bars on the inside of bends.
          WASH_RAMP swaps mud and banks for contour-banded slickrock and scree.
  detail1 pebbles (drawn at 60 m); detail2 crack lips and curled flakes (drawn at 25 m).
Budgets (asset_budgets.json via grind.BUDGET): landform 8000 tris, detail 1500 tris and 3000 vertices, one draw per mesh,
one "enamel" vertex-colour slot. Palette: sandstone, ochre, muted brown rust, bleached bone; never HAZARD, ANCIENT or MINT,
nothing emissive, AMBER and COPPER unused, no crates or barrels, no ramps, no long rails, nothing taller than 1.0 m.
"""
import argparse
import hashlib
import json
import math
import random
from pathlib import Path
import struct
import sys
import tempfile

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
import flume_works as fw
from flume_works import (kit, common, grind, ss, refine, fill, lifted, read_glb, mesh_nodes, mesh_positions, edge_weight,
                         BASE_OFF, EDGE_OFF, FEATURE_MAX, MARGIN, BASE_TRIS, CHECK_MIN, GROUND_N, GROUND_STEP, GROUND_HALF)

SKETCH = kit.SKETCH
BUDGET = grind.BUDGET
PARK_DIR = SKETCH / "src/world/park"
MODELS = SKETCH / "assets/models/park"

MUD = ("b39a76", "a98f6d", "bba784", "a49378")
MUD_DARK = "7f6a50"
SEAM = "54432f"
MUD_TOP = ("e2cfa8", "d9c49c", "e8d5ae", "d2bc94")
CAP_COL = "a39b86"
SEAM_W = 0.10
SEAM_TOP = 0.05
FLOOR_OFF = 0.035
CREAM_L = "dccaa2"
OCHRE = "c2a06c"
REDBROWN = "8c5c46"
TAN = "b8a07a"
CAP = ("94907f", "a09b8a")
SAND_TOP = "c6a274"
BONE_WOOD = ("e0d3b2", "d0c19e", "bfae8a")
SOIL = "6a5a42"
RUST = ("8a5a44", "74503c", "9a6a50")
IRON = "4a4e4c"
PEBBLE = ("c4b490", "a69a82", "d4c4a0", "8f8470")
FLAKE = ("a8725a", "c2a06c", "dccaa2", "8c5c46")
BANNED = {"ff5a3c", "9dff3c", "8bf0d3", "e5a044", "b77843", "d9b44a"}

FLUSH = 0.2
PLATES_X = (0.26, 0.40)
LATTICE_MIN = 1500
PROP_MAX = 1.0
PROP_TOP = 1.2
LIMITS = {"base_max": PROP_TOP + 0.05, "flush_max": BASE_OFF + 0.03, "gap_min": -0.35}
PROFILE_PROPS = {
    "wash": dict(clusters=2, bars=3, plates=60, pebbles=60, seam_cap=1100, d2_seams=300, d2_flakes=70),
    "ramp": dict(clusters=3, bars=0, boulders=40, drifts=8, plates=0, pebbles=60, seam_cap=0, d2_seams=0, d2_flakes=190),
}
WASH_PLANS = [(2.0, 1.5, 3.5), (3.0, 1.5, 4.0), (3.0, 2.0, 4.0), (4.0, 2.0, 5.0), (4.0, 2.5, 6.0), (5.0, 3.0, 6.0), (6.0, 4.0, 8.0), (8.0, 6.0, 12.0), (10.0, 8.0, 16.0), (14.0, 12.0, 24.0)]
RAMP_PLANS = [(5.0, 5.0, 5.0), (6.0, 6.0, 6.0), (8.0, 8.0, 8.0), (10.0, 10.0, 10.0), (12.0, 12.0, 12.0), (16.0, 16.0, 16.0), (20.0, 20.0, 20.0)]


def hexof(c):
    if isinstance(c, str):
        return c.lstrip("#").lower()
    return "%02x%02x%02x" % tuple(max(0, min(255, int(round(v * 255)))) for v in c)


def mix(a, b, t):
    """Blend two colours (hex strings or sRGB triples); returns an sRGB triple."""
    return common.mix(hexof(a), hexof(b), t)


def tone(base, other=None, k=0, span=0.22):
    """A deterministic jitter of base toward other by index k (no randomness)."""
    return mix(base, other or SOIL, ((k * 37 + 11) % 13) / 12.0 * span)


_GROUND = {}


def ground_rows(path):
    """A bake's ground heights (GCPF file of zstd blocks), decoded once per path."""
    key = str(path)
    if key not in _GROUND:
        import numpy
        import zstandard
        raw = Path(path).read_bytes()
        assert raw[:4] == b"GCPF", raw[:4]
        mode, block, total = struct.unpack_from("<3I", raw, 4)
        assert mode == 2, mode
        count = -(-total // block)
        sizes = struct.unpack_from("<%dI" % count, raw, 16)
        pos = 16 + 4 * count
        out = bytearray()
        dec = zstandard.ZstdDecompressor()
        for size in sizes:
            out += dec.decompress(raw[pos:pos + size], max_output_size=block)
            pos += size
        assert len(out) == total == GROUND_N * GROUND_N * 4, (len(out), total)
        _GROUND[key] = numpy.frombuffer(bytes(out), dtype="<f4").reshape(GROUND_N, GROUND_N).astype("float64")
    return _GROUND[key]


def seed_of(rid):
    return int(hashlib.sha1(rid.encode()).hexdigest()[:8], 16)


class Row:
    """A liner row: the world <-> GLB-local transform of park_recipes.gd row_transform, and the ground under it."""

    def __init__(self, jrow, bake_dir):
        self.src = jrow["id"]
        self.rid = "liner_" + jrow["id"]
        self.profile = "ramp" if jrow.get("stamp") == "ramp" and jrow.get("element") == "flow_line" else "wash"
        self.g = ground_rows(Path(bake_dir) / "ground.bin")
        self.ax, self.az = jrow["at"]
        self.L, self.H, self.W = jrow["size"]
        yaw = math.radians(float(jrow.get("yaw_deg", 0.0)))
        self.c, self.s = math.cos(yaw), math.sin(yaw)
        self.hw, self.hl = self.W / 2.0, self.L / 2.0
        self.profile_margin = 0.0 if self.profile == "ramp" else MARGIN
        self.ex, self.ez = self.hw + self.profile_margin, self.hl + self.profile_margin
        self.seed = seed_of(self.rid)
        self.cache = {}
        self.g0 = self.ground(self.ax, self.az)[0]
        self.fl = (FLUSH if self.profile == "wash" else 0.04) * self.W

    def ground(self, x, z):
        g = self.g
        fx = min(max((x + GROUND_HALF) / GROUND_STEP, 0.0), GROUND_N - 1 - 1e-9)
        fz = min(max((z + GROUND_HALF) / GROUND_STEP, 0.0), GROUND_N - 1 - 1e-9)
        ix, iz = int(fx), int(fz)
        u, v = fx - ix, fz - iz
        h00, h10, h01, h11 = float(g[iz, ix]), float(g[iz, ix + 1]), float(g[iz + 1, ix]), float(g[iz + 1, ix + 1])
        bil = h00 * (1 - u) * (1 - v) + h10 * u * (1 - v) + h01 * (1 - u) * v + h11 * u * v
        da = h00 + u * (h10 - h00) + v * (h11 - h10) if u >= v else h00 + v * (h01 - h00) + u * (h11 - h01)
        db = h00 + u * (h10 - h00) + v * (h01 - h00) if u + v <= 1.0 else h11 + (1 - u) * (h01 - h11) + (1 - v) * (h10 - h11)
        return bil, max(bil, da, db)

    def world(self, lx, lz):
        return self.ax + lx * self.c + lz * self.s, self.az - lx * self.s + lz * self.c

    def sample(self, lx, lz):
        key = (round(lx, 5), round(lz, 5))
        if key not in self.cache:
            self.cache[key] = self.ground(*self.world(lx, lz))
        return self.cache[key]

    def gy(self, lx, lz):
        """Local y of the bilinear ground."""
        return self.sample(lx, lz)[0] - self.g0


def hjit(i, j, k=0, salt=0):
    """Deterministic hash in [0, 1)."""
    return ((i * 73856093) ^ (j * 19349663) ^ (k * 83492791) ^ (salt * 2654435761)) % 1009 / 1009.0


TILE = 2.0


class Tiles:
    """Hex-ish mud tiles. Centres sit on a jittered triangular lattice (world space, seeded by the row), so a Voronoi cell is a
    polygon plate; the cracks are the cell edges, the corners the circumcentres of the lattice triangles."""

    def __init__(self, seed):
        self.seed = seed
        self.cc = {}

    def centre(self, i, j):
        key = (i, j)
        if key not in self.cc:
            jx = (hjit(i, j, 1, self.seed) - 0.5) * 0.5 * TILE
            jz = (hjit(i, j, 2, self.seed) - 0.5) * 0.5 * TILE
            self.cc[key] = (TILE * (i + 0.5 * j) + jx, TILE * 0.866 * j + jz)
        return self.cc[key]

    def near(self, x, z):
        """(nearest id, second-nearest gap d2 - d1 in metres) over the 5x5 lattice block around (x, z)."""
        j0 = int(round(z / (TILE * 0.866)))
        i0 = int(round(x / TILE - 0.5 * j0))
        best = []
        for dj in range(-2, 3):
            for di in range(-2, 3):
                i, j = i0 + di, j0 + dj
                cx, cz = self.centre(i, j)
                best.append((math.hypot(cx - x, cz - z), (i, j)))
        best.sort()
        return best[0][1], best[1][0] - best[0][0]

    def corners(self, i, j):
        """The cell polygon: circumcentres of the six lattice triangles around (i, j), in angular order."""
        a = self.centre(i, j)
        ring = [(1, 0), (0, 1), (-1, 1), (-1, 0), (0, -1), (1, -1)]
        pts = []
        for k in range(6):
            b = self.centre(i + ring[k][0], j + ring[k][1])
            c = self.centre(i + ring[(k + 1) % 6][0], j + ring[(k + 1) % 6][1])
            pts.append(circum(a, b, c))
        return pts


def circum(a, b, c):
    ax, az = a
    bx, bz = b[0] - ax, b[1] - az
    cx, cz = c[0] - ax, c[1] - az
    d = 2.0 * (bx * cz - bz * cx)
    if abs(d) < 1e-9:
        return ((a[0] + b[0] + c[0]) / 3.0, (a[1] + b[1] + c[1]) / 3.0)
    ux = (cz * (bx * bx + bz * bz) - bz * (cx * cx + cz * cz)) / d
    uz = (bx * (cx * cx + cz * cz) - cx * (bx * bx + bz * bz)) / d
    return (ax + ux, az + uz)


def newell(pts):
    nx = ny = nz = 0.0
    for k, p in enumerate(pts):
        q = pts[(k + 1) % len(pts)]
        nx += (p[1] - q[1]) * (p[2] + q[2])
        ny += (p[2] - q[2]) * (p[0] + q[0])
        nz += (p[0] - q[0]) * (p[1] + q[1])
    return nx, ny, nz


def solid(s, verts, faces, color, colors=None):
    """A convex solid: every face wound outward from the vertex centroid (the surface does not recompute normals)."""
    n = len(verts)
    cx = sum(v[0] for v in verts) / n
    cy = sum(v[1] for v in verts) / n
    cz = sum(v[2] for v in verts) / n
    out = []
    for f in faces:
        pts = [verts[i] for i in f]
        nx, ny, nz = newell(pts)
        fx = sum(p[0] for p in pts) / len(pts) - cx
        fy = sum(p[1] for p in pts) / len(pts) - cy
        fz = sum(p[2] for p in pts) / len(pts) - cz
        out.append(tuple(reversed(f)) if nx * fx + ny * fy + nz * fz < 0 else tuple(f))
    s.add([tuple(v) for v in verts], out, color, colors)


def sheet_up(s, pts, color=None, colors=None):
    """One open face wound counter-clockwise seen from above."""
    nx, ny, nz = newell(pts)
    face = list(range(len(pts)))
    cols = colors
    if ny < 0:
        face.reverse()
    s.add([tuple(p) for p in pts], [tuple(face)], color, cols)


def frame(a, b):
    """Unit axis a->b with a horizontal-ish side and an up vector."""
    ax, ay, az = b[0] - a[0], b[1] - a[1], b[2] - a[2]
    n = math.sqrt(ax * ax + ay * ay + az * az) or 1.0
    ax, ay, az = ax / n, ay / n, az / n
    sx, sy, sz = -az, 0.0, ax
    sn = math.hypot(sx, sz) or 1.0
    sx, sz = sx / sn, sz / sn
    ux, uy, uz = ay * sz - az * sy, az * sx - ax * sz, ax * sy - ay * sx
    return (ax, ay, az), (sx, sy, sz), (ux, uy, uz), n


def tube(s, a, b, radii, ts, sides, color, wobble=0.0, k=0, caps=True, colors_fn=None):
    """A tapered tube from a to b: rings at fractions ts with radii (convex enough for the centroid winding)."""
    ax, sd, up, _ = frame(a, b)
    verts, faces, cols = [], [], []
    for r_i, (t, r) in enumerate(zip(ts, radii)):
        c = tuple(a[m] + (b[m] - a[m]) * t for m in range(3))
        for i in range(sides):
            ph = math.tau * i / sides
            rr = r * (1.0 + wobble * (hjit(k, i, r_i) - 0.5))
            verts.append(tuple(c[m] + rr * (math.cos(ph) * sd[m] + math.sin(ph) * up[m]) for m in range(3)))
            cols.append(colors_fn(r_i, i) if colors_fn else color)
    for r_i in range(len(ts) - 1):
        for i in range(sides):
            j = (i + 1) % sides
            faces.append((r_i * sides + i, r_i * sides + j, (r_i + 1) * sides + j, (r_i + 1) * sides + i))
    if caps:
        faces.append(tuple(range(sides)))
        faces.append(tuple(range((len(ts) - 1) * sides, len(ts) * sides)))
    solid(s, verts, faces, color, cols)


def lump(s, cx, cz, base_y, top_y, r, sides, color, row, k, flat=0.0):
    """A rounded stone or pebble: a low ring sunk below the surface and a smaller, higher one. No bottom cap (buried)."""
    verts, faces = [], []
    for i in range(sides):
        ph = math.tau * i / sides + 0.3 * k
        rr = r * (0.85 + 0.3 * hjit(k, i, 3))
        verts.append((cx + rr * math.cos(ph), base_y, cz + rr * math.sin(ph)))
    for i in range(sides):
        ph = math.tau * (i + 0.5) / sides + 0.3 * k
        rr = r * (0.5 + 0.12 * hjit(k, i, 4))
        verts.append((cx + rr * math.cos(ph), top_y - flat * hjit(k, i, 5), cz + rr * math.sin(ph)))
    for i in range(sides):
        j = (i + 1) % sides
        faces.append((i, j, sides + j))
        faces.append((i, sides + j, sides + i))
    faces.append(tuple(range(sides, 2 * sides)))
    solid(s, verts, faces, color)


LAYERS = [0.9, 0.55, 0.8, 0.5, 1.0, 0.6, 0.7, 0.45]
LAYER_COLOURS = [CREAM_L, OCHRE, REDBROWN, OCHRE, CREAM_L, TAN, REDBROWN, OCHRE]


def layer_of(h, scale, shift):
    """(layer index, fraction through it) of a height h above the floor, layers cycling LAYERS * scale from a shifted start."""
    h = h + shift
    total = sum(LAYERS) * scale
    cyc, rem = divmod(h, total)
    acc = 0.0
    for i, t in enumerate(LAYERS):
        t *= scale
        if rem < acc + t:
            return int(cyc) * len(LAYERS) + i, (rem - acc) / t
        acc += t
    return int(cyc + 1) * len(LAYERS), 0.0


def lip(u):
    return ss(u / 0.6) if u < 0.88 else ss((1.0 - u) / 0.12)


class Cross:
    """Per-station cut profile read from the bake: floor height (lowest ground within the flush band) and rim height."""

    def __init__(self, row):
        self.row = row
        self.cache = {}

    def at(self, lz):
        key = round(lz, 3)
        if key not in self.cache:
            r = self.row
            floor = min(r.sample(x, lz)[0] for x in (-r.fl, -0.5 * r.fl, 0.0, 0.5 * r.fl, r.fl))
            rim = max(r.sample(sx * (r.hw + 1.5), lz)[0] for sx in (-1, 1))
            self.cache[key] = (floor, max(rim, floor + 0.5))
        return self.cache[key]


def vertex_rules(row, cross, lx, lz, gh, bank_face):
    """(offset above the ground, vertex colour) of one lattice vertex."""
    wx, wz = row.world(lx, lz)
    a = abs(lx)
    if row.profile == "ramp":
        s = int(math.floor((lx + 3.0 * math.sin(lz / 23.0 + row.seed % 7)) / 12.0))
        pick = int(hjit(s, 5, 3, row.seed) * 8)
        col = (CREAM_L, OCHRE, REDBROWN, OCHRE, CREAM_L, REDBROWN, TAN, SAND_TOP)[pick]
        col = tone(col, SOIL, int(lz // 18) + s, 0.3)
        wt = ss((a - row.fl) / (0.08 * row.W))
        return BASE_OFF + wt * 0.10 * (pick % 2), col
    floor, rim = cross.at(lz)
    h_rel = gh - floor
    depth = rim - floor
    wt = ss((a - row.fl) / (0.08 * row.W))
    pi, pj = int(wx // 5), int(wz // 5)
    mud = tone(MUD_TOP[(pi + 2 * pj) % 4], MUD_DARK, pi * 3 + pj, 0.35)
    if a > row.hw:
        return BASE_OFF, tone(SAND_TOP, TAN, int(wx // 6) + int(wz // 6), 0.4)
    k = ss((h_rel - 0.25) / 0.35)
    base_off = FLOOR_OFF if a <= row.fl else BASE_OFF
    if k <= 0.0:
        return base_off, mud
    if h_rel > 0.84 * depth:
        return BASE_OFF, CAP_COL
    idx, u = layer_of(h_rel, 1.0, row.seed % 5)
    col = LAYER_COLOURS[idx % len(LAYER_COLOURS)]
    col = tone(col, SOIL, idx + int(wz / 5), 0.15)
    off = BASE_OFF + wt * 0.06 * lip(u)
    if u < 0.18:
        col = mix(col, SOIL, 0.3)
    if bank_face:
        return off, col
    return BASE_OFF + (off - BASE_OFF) * k, mix(mud, col, k)


def across_stations(row, sf, sb):
    hw, W, fl = row.hw, row.W, row.fl
    if row.profile == "ramp":
        k = [0.0, fl, row.ex, hw, 0.28 * W]
        return fill([-v for v in sorted(set(round(v, 4) for v in k))[1:]] + sorted(set(round(v, 4) for v in k)), sf)
    k = sorted(set(round(v, 4) for v in [0.0, fl, 0.28 * W, hw, row.ex]))
    out = [0.0]
    for a, b in zip(k, k[1:]):
        step = sf if b <= 0.28 * W + 1e-6 else sb
        n = max(1, int(math.ceil((b - a) / step - 1e-9)))
        out += [a + (b - a) * t / n for t in range(1, n + 1)]
    return [-v for v in out[1:]][::-1] + out


def along_stations(row, step):
    return fill([-row.ez, row.ez], step)


def lattice_plan(row, budget):
    plans = WASH_PLANS if row.profile == "wash" else RAMP_PLANS
    for sf, sb, sa in plans:
        xs0 = across_stations(row, sf, sb)
        zs = refine(along_stations(row, sa),
                    lambda a, b: max(abs(row.sample(x, (a + b) / 2.0)[0] - (row.sample(x, a)[0] + row.sample(x, b)[0]) / 2.0)
                                     for x in xs0[::2]))
        xs = refine(xs0, lambda a, b: max(abs(row.sample((a + b) / 2.0, z)[0] - (row.sample(a, z)[0] + row.sample(b, z)[0]) / 2.0)
                                          for z in zs[::2]))
        tris = 2 * (len(xs) - 1) * (len(zs) - 1)
        if tris <= budget:
            return xs, zs, tris, (sf, sb, sa)
    raise AssertionError("%s: no lattice fits %d tris" % (row.rid, budget))


def draw_lattice(s, row, cross, xs, zs):
    lat = []
    for lz in zs:
        line = []
        for lx in xs:
            bil, hi = row.sample(lx, lz)
            line.append((lx, lz, bil, hi))
        lat.append(line)
    for j in range(len(zs) - 1):
        for i in range(len(xs) - 1):
            quad = [lat[j][i], lat[j + 1][i], lat[j + 1][i + 1], lat[j][i + 1]]
            amean = sum(abs(q[0]) for q in quad) / 4.0
            if row.profile == "wash":
                floor, rim = cross.at((zs[j] + zs[j + 1]) / 2.0)
                bank_face = amean > row.fl and min(q[2] for q in quad) - floor > 0.5
            else:
                floor, rim = 0.0, 1.0
                bank_face = True
            mlx, mlz = sum(q[0] for q in quad) / 4.0, sum(q[1] for q in quad) / 4.0
            mx = sum(q[2] for q in quad) / 4.0
            face_col = vertex_rules(row, cross, mlx, mlz, mx, True)[1] if bank_face else None
            pts, cols = [], []
            for lx, lz, bil, hi in quad:
                off, col = vertex_rules(row, cross, lx, lz, bil, bank_face)
                if bank_face:
                    col = face_col
                we = edge_weight(min(row.ex - abs(lx), row.ez - abs(lz)))
                off = EDGE_OFF + (off - EDGE_OFF) * we
                capped = row.profile == "wash" and bil - floor > 0.84 * (rim - floor)
                pts.append((lx, lifted(row, bil, hi, off, abs(lx) <= row.fl + 1e-6 or capped), lz))
                cols.append(col)
            sheet_up(s, pts, None, cols)


class Sites:
    """Seeded prop placement: candidate points outside the flush band, on calm ground, kept apart from one another."""

    def __init__(self, row, rng):
        self.row, self.rng, self.used = row, rng, []
        self.thal = self.thalweg() if row.profile == "wash" else {}

    def thalweg(self):
        row = self.row
        zs = [-row.hl + 4.0 * k for k in range(int(row.L / 4.0) + 1)]
        raw = []
        for z in zs:
            best = min((row.sample(x, z)[0], x) for x in [-0.3 * row.W + 1.0 * k for k in range(int(0.6 * row.W) + 1)])
            raw.append(best[1])
        sm = []
        for i in range(len(raw)):
            win = raw[max(0, i - 2):i + 3]
            sm.append(sum(win) / len(win))
        return dict(zip(zs, sm))

    def bends(self, count):
        """Up to count sites (lz, thalweg x, inside side) ranked by thalweg curvature, at least 30 m apart; straight reaches
        fall back to evenly spaced sites that alternate sides."""
        zs = sorted(self.thal)
        scored = []
        for i in range(2, len(zs) - 2):
            curv = self.thal[zs[i - 2]] - 2 * self.thal[zs[i]] + self.thal[zs[i + 2]]
            scored.append((abs(curv), zs[i], self.thal[zs[i]], 1 if curv > 0 else -1))
        scored.sort(reverse=True)
        out = []
        for c, z, x, side in scored:
            if c < 0.8:
                break
            if all(abs(z - o[0]) >= 30.0 for o in out):
                out.append((z, x, side))
            if len(out) >= count:
                break
        cands = [-self.row.hl + 10.0 + (self.row.L - 20.0) * (q + 0.5) / (count * 2) for q in range(count * 2)]
        for z in cands:
            if len(out) >= count:
                break
            if all(abs(z - o[0]) >= 24.0 for o in out):
                zq = min(self.thal, key=lambda t: abs(t - z))
                out.append((z, self.thal[zq], 1 if len(out) % 2 == 0 else -1))
        return out

    def calm(self, lx, lz, rad, limit):
        """Whether a prop of this radius lies true: the ground bends less than limit over it and is no steeper than 0.8."""
        r = self.row
        c = r.sample(lx, lz)[0]
        for dx, dz in ((rad, 0), (0, rad)):
            p, m = r.sample(lx + dx, lz + dz)[0], r.sample(lx - dx, lz - dz)[0]
            if abs(p + m - 2 * c) > limit or abs(p - m) > 2.0 * rad:
                return False
        return True

    def pick(self, lx0, lz0, rad, spread=3.0, tries=14, limit=0.9, xlo=0.23, xhi=0.40, apart=2.4):
        """A calm spot near (lx0, lz0) between xlo and xhi of the width, clear of earlier picks."""
        row = self.row
        for t in range(tries):
            lx = lx0 + (self.rng.random() - 0.5) * spread * (1 + t * 0.3)
            lz = lz0 + (self.rng.random() - 0.5) * spread * 2 * (1 + t * 0.3)
            if not (max(xlo * row.W, row.fl + 1.2 + rad) <= abs(lx) <= min(max(xhi * row.W, row.fl + 3.0 + rad), row.hw - 0.5)) or abs(lz) > row.hl:
                continue
            if any(math.hypot(lx - u[0], lz - u[1]) < apart + rad + u[2] for u in self.used):
                continue
            if not self.calm(lx, lz, rad, limit):
                continue
            self.used.append((lx, lz, rad))
            return lx, lz
        return None

    def spread(self, count, rad, **kw):
        row = self.row
        out = []
        for k in range(count):
            lz0 = -row.hl + 6.0 + (row.L - 12.0) * (k + 0.5 + 0.6 * (self.rng.random() - 0.5)) / count
            side = 1 if (k + row.seed) % 2 else -1
            lx0 = side * (0.3 + 0.1 * self.rng.random()) * row.W
            p = self.pick(lx0, lz0, rad, spread=4.0, **kw)
            if p:
                out.append(p)
        return out


def surface_y(row, lx, lz):
    """Local y of the lattice surface under a prop (calm ground: bilinear + the base offset)."""
    return row.gy(lx, lz) + BASE_OFF


def mound(s, row, cx, cz, rx, rz, top, colour, sides=12, k=0):
    """An elongated rounded mound (rx across, rz along the flow), sunk below the ground at its rim; no bottom cap."""
    verts, faces = [], []
    for i in range(sides):
        ph = math.tau * i / sides
        verts.append((cx + rx * math.cos(ph), row.gy(cx + rx * math.cos(ph), cz + rz * math.sin(ph)) - 0.12, cz + rz * math.sin(ph)))
    for i in range(sides):
        ph = math.tau * (i + 0.5) / sides
        x, z = cx + 0.5 * rx * math.cos(ph), cz + 0.5 * rz * math.sin(ph)
        verts.append((x, row.gy(x, z) + top * (0.85 + 0.15 * hjit(k, i, 6)), z))
    for i in range(sides):
        j = (i + 1) % sides
        faces.append((i, j, sides + j))
        faces.append((i, sides + j, sides + i))
    faces.append(tuple(range(sides, 2 * sides)))
    solid(s, verts, faces, colour)


def gravel_bar(s, row, rng, bx, bz, k):
    """A gravel bar on the inside of a bend: a 4 to 8 m long pale mound about 0.9 m tall, capped with rounded pebbles."""
    rz = 2.6 + 1.4 * rng.random()
    rx = 1.7
    mound(s, row, bx, bz, rx, rz, 1.05, tone(PEBBLE[2], SOIL, k, 0.3), 12, k)
    for q in range(12):
        ph = math.tau * rng.random()
        rho = 0.75 * math.sqrt(rng.random())
        px, pz = bx + rho * rx * math.cos(ph), bz + rho * rz * math.sin(ph)
        r = 0.38 + 0.14 * rng.random()
        top = row.gy(px, pz) + 0.3 + 0.8 * (1.0 - rho * rho) * 0.9 + 0.15 * rng.random()
        lump(s, px, pz, row.gy(px, pz) + 0.1, top, r, 6, tone(PEBBLE[q % 4], SOIL, q + k, 0.3), row, q + 5 * k, 0.04)


def cluster(s, row, rng, lx, lz, side, k):
    """One readable driftwood cluster against a bank: a root ball, a three-log jam running with the flow, a half-buried bent
    sheet and a pair of pipe sections, all muted brown and bleached wood."""
    root_ball(s, row, lx, lz, rng, k, 2.4)
    for q in range(3):
        px = lx - side * (0.9 + 0.5 * q)
        pz = lz + (q - 1) * 2.1
        log(s, row, px, pz, rng, k + q, ang=math.pi / 2 + (rng.random() - 0.5) * 0.7, length=3.8 + 1.6 * rng.random(),
            r=0.42 + 0.08 * rng.random(), lift=0.7 if q == 2 else 0.0)
    sheet(s, row, lx - side * 3.2, lz + 4.8, rng, k, 1.6)
    pipe(s, row, lx - side * 3.4, lz - 4.4, rng, k, 1.5)
    pipe(s, row, lx - side * 4.2, lz - 3.4, rng, k + 1, 1.5)


def shelves(s, row, cross):
    """Ledge lips: a shelf 0.3 m deep and 0.12 m thick follows the contour at the top of every third strata layer on both
    banks, so the layers read as stacked ledges and not painted stripes."""
    n_tri = 0
    for side in (-1, 1):
        for lz0 in [-row.hl + 3.0 + 5.0 * q for q in range(int((row.L - 6.0) / 5.0))]:
            floor, rim = cross.at(lz0)
            depth = rim - floor
            hs, acc, i = [], -(row.seed % 5), 0
            while acc < 0.84 * depth:
                acc += LAYERS[i % len(LAYERS)]
                if i % 3 == 1 and 0.6 < acc < 0.84 * depth:
                    hs.append(acc)
                i += 1
            for hb in hs[:3]:
                pts = []
                for dz in (0.0, 5.0):
                    fl2, rim2 = cross.at(min(lz0 + dz, row.hl - 1.0))
                    lz = min(lz0 + dz, row.hl - 1.0)
                    found = None
                    xx = row.fl + 0.4
                    while xx < row.hw - 0.3:
                        if row.sample(side * xx, lz)[0] - fl2 >= hb:
                            found = xx
                            break
                        xx += 0.25
                    if found is None:
                        break
                    pts.append((side * found, lz))
                if len(pts) < 2:
                    continue
                (x0, z0), (x1, z1) = pts
                inx = -side * 0.3
                y0, y1 = row.gy(x0, z0) + 0.1, row.gy(x1, z1) + 0.1
                top = [(x0, y0, z0), (x1, y1, z1), (x1 + inx, y1, z1), (x0 + inx, y0, z0)]
                col = LAYER_COLOURS[(hs.index(hb) * 3 + 1) % len(LAYER_COLOURS)]
                sheet_up(s, top, mix(col, CREAM_L, 0.35))
                front = [(x0 + inx, y0, z0), (x1 + inx, y1, z1), (x1 + inx, y1 - 0.3, z1), (x0 + inx, y0 - 0.3, z0)]
                nx_, ny_, nz_ = newell(front)
                if nx_ * inx < 0:
                    front.reverse()
                s.add([tuple(q) for q in front], [(0, 1, 2, 3)], mix(col, SOIL, 0.45))


def build_props(s, row, sites, counts):
    rng = sites.rng
    if row.profile == "wash":
        n = counts["bars"] + counts["clusters"]
        bends = sites.bends(n)
        for k, (z, tx, side) in enumerate(bends):
            if k < counts["bars"]:
                bx = side * max(abs(tx + side * 0.3 * row.W), row.fl + 1.9)
                gravel_bar(s, row, rng, bx, z, k)
            else:
                lx = -side * (row.fl + 2.6)
                cluster(s, row, rng, lx, z, -side, k)
        shelves(s, row, Cross(row))
        print("WASHES_PROPS %s bends %d bars %d clusters %d" % (row.rid, len(bends), counts["bars"], len(bends) - counts["bars"]))
        return
    for k in range(counts["clusters"]):
        side = 1 if k % 2 else -1
        lz = -row.hl + row.L * (k + 0.5) / counts["clusters"]
        cluster(s, row, rng, side * (row.fl + 6.0 + 14.0 * rng.random()), lz, side, k)
    groups = 8
    for g in range(groups):
        side = 1 if g % 2 else -1
        gx = side * (row.fl + 6.0 + (row.hw * 0.55) * rng.random())
        gz = -row.hl + row.L * (g + 0.5) / groups + (rng.random() - 0.5) * 10.0
        for q in range(counts["boulders"] // groups):
            px = gx + (rng.random() - 0.5) * 9.0
            pz = gz + (rng.random() - 0.5) * 9.0
            if abs(px) < row.fl + 2.0 or abs(px) > row.hw - 2.0 or abs(pz) > row.hl - 2.0:
                continue
            h = 0.6 + 0.6 * rng.random()
            lump(s, px, pz, row.gy(px, pz) - 0.12, row.gy(px, pz) + BASE_OFF + h, h * 1.25, 8,
                 tone(PEBBLE[(g + q) % 4], SOIL, g * 7 + q, 0.3), row, g * 7 + q, 0.08)
    for k in range(counts["drifts"]):
        side = 1 if k % 2 else -1
        px = side * (row.fl + 6.0 + (row.hw - row.fl - 12.0) * rng.random())
        pz = (rng.random() * 2 - 1) * (row.hl - 8.0)
        mound(s, row, px, pz, 2.5, 5.0 + 3.0 * rng.random(), 0.22, tone("d8c19a", SAND_TOP, k, 0.3), 12, k)


def log(s, row, lx, lz, rng, k, ang=None, length=None, r=None, lift=0.0):
    ang = math.tau * rng.random() if ang is None else ang
    length = 2.2 + 2.2 * rng.random() if length is None else length
    r = 0.17 + 0.12 * rng.random() if r is None else r
    d = (math.cos(ang), math.sin(ang))
    a = (lx - d[0] * length / 2, row.gy(lx - d[0] * length / 2, lz - d[1] * length / 2) + BASE_OFF + r * 0.2 + lift, lz - d[1] * length / 2)
    b = (lx + d[0] * length / 2, row.gy(lx + d[0] * length / 2, lz + d[1] * length / 2) + BASE_OFF + r * 0.2 + lift, lz + d[1] * length / 2)
    wood = BONE_WOOD[k % 3]
    tube(s, a, b, [r * 0.6, r, r * 0.55], [0.0, 0.5, 1.0], 7, tone(wood, SOIL, k, 0.2), wobble=0.25, k=k)
    t = 0.35 + 0.3 * rng.random()
    base = tuple(a[m] + (b[m] - a[m]) * t for m in range(3))
    tip = (base[0] - d[1] * 0.3, base[1] + 0.2 + r * 0.4, base[2] + d[0] * 0.3)
    tube(s, base, tip, [r * 0.4, r * 0.28], [0.0, 1.0], 5, tone(wood, SOIL, k + 3, 0.3), caps=True)


def root_ball(s, row, lx, lz, rng, k, scale=1.0):
    r = (0.5 + 0.2 * rng.random()) * scale
    gy = row.gy(lx, lz)
    top = gy + BASE_OFF + (0.45 + 0.3 * rng.random()) * scale
    wood = tone(BONE_WOOD[2], SOIL, k, 0.45)
    lump(s, lx, lz, gy - 0.2, top, r, 8, wood, row, k, 0.1)
    for q in range(5):
        ph = math.tau * (q + 0.4 * rng.random()) / 5
        reach = (0.9 + 0.5 * rng.random()) * scale
        a = (lx + math.cos(ph) * 0.2, top - 0.15, lz + math.sin(ph) * 0.2)
        ex, ez = lx + math.cos(ph) * reach, lz + math.sin(ph) * reach
        b = (ex, row.gy(ex, ez) + BASE_OFF + 0.1 + 0.2 * rng.random(), ez)
        tube(s, a, b, [0.1, 0.045], [0.0, 1.0], 4, tone(BONE_WOOD[1], SOIL, k + q, 0.35), caps=False)


def sheet(s, row, lx, lz, rng, k, sc=1.0):
    """Bent corrugated sheet, half-buried: a rippled slab 2.0 x 1.3 m, one end curled up 0.3 m, on the local ground plane."""
    ang = math.tau * rng.random()
    ca, sa = math.cos(ang), math.sin(ang)
    na, nb, A, B = 7, 5, 2.0 * sc, 1.3 * sc
    gx = (row.gy(lx + 1.0, lz) - row.gy(lx - 1.0, lz)) / 2.0
    gz = (row.gy(lx, lz + 1.0) - row.gy(lx, lz - 1.0)) / 2.0
    base_y = row.gy(lx, lz) + BASE_OFF
    top, bot = [], []
    for ia in range(na):
        u = ia / (na - 1) - 0.5
        for ib in range(nb):
            v = ib / (nb - 1) - 0.5
            dx, dz = u * A * ca - v * B * sa, u * A * sa + v * B * ca
            ripple = 0.045 * math.sin(math.tau * 3 * (v + 0.5))
            curl = 0.3 * sc * max(0.0, u - 0.1) ** 2 / 0.16
            y = base_y + gx * dx + gz * dz - 0.05 + ripple + curl
            top.append((lx + dx, y, lz + dz))
            bot.append((lx + dx, y - 0.05, lz + dz))
    col = [tone(RUST[k % 3], IRON, ia, 0.5) for ia in range(na)]
    for ia in range(na - 1):
        for ib in range(nb - 1):
            q = [ia * nb + ib, ia * nb + ib + 1, (ia + 1) * nb + ib + 1, (ia + 1) * nb + ib]
            c = col[ia]
            sheet_up(s, [top[i] for i in q], c)
            sheet_up(s, [bot[i] for i in q][::-1], c)
    ring = [(ia, 0) for ia in range(na)] + [(na - 1, ib) for ib in range(1, nb)] + [(ia, nb - 1) for ia in range(na - 2, -1, -1)] + \
           [(0, ib) for ib in range(nb - 2, 0, -1)]
    cx = sum(p[0] for p in top) / len(top)
    cz = sum(p[2] for p in top) / len(top)
    for q in range(len(ring)):
        ia, ib = ring[q]
        ja, jb = ring[(q + 1) % len(ring)]
        i0, i1 = ia * nb + ib, ja * nb + jb
        quad = [top[i0], top[i1], bot[i1], bot[i0]]
        nx, ny, nz = newell(quad)
        mid_x = (quad[0][0] + quad[1][0]) / 2 - cx
        mid_z = (quad[0][2] + quad[1][2]) / 2 - cz
        if nx * mid_x + nz * mid_z < 0:
            quad.reverse()
        s.add([tuple(p) for p in quad], [(0, 1, 2, 3)], IRON)


def pipe(s, row, lx, lz, rng, k, sc=1.0):
    ang = math.tau * rng.random()
    length = (2.0 + 1.0 * rng.random()) * sc
    r = (0.2 + 0.05 * rng.random()) * sc
    d = (math.cos(ang), math.sin(ang))
    pa = (lx - d[0] * length / 2, lz - d[1] * length / 2)
    pb = (lx + d[0] * length / 2, lz + d[1] * length / 2)
    a = (pa[0], row.gy(*pa) + BASE_OFF + r * 0.1, pa[1])
    b = (pb[0], row.gy(*pb) + BASE_OFF + r * 0.1, pb[1])
    rust = tone(RUST[k % 3], IRON, k, 0.4)
    tube(s, a, b, [r * 1.1, r, r * 1.1], [0.0, 0.5, 1.0], 8, rust,
         colors_fn=lambda ri, i: IRON if ri in (0, 2) and i % 2 else rust)


def plates(s, row, tiles, count):
    if count <= 0:
        return 0
    cand = []
    lo, hi = PLATES_X[0] * row.W, PLATES_X[1] * row.W
    xs = int(row.W / TILE) + 3
    zs = int(row.L / (TILE * 0.866)) + 3
    j0 = int(round(row.az / (TILE * 0.866)))
    i0 = int(round(row.ax / TILE - 0.5 * j0))
    span = int(max(row.W, row.L) / TILE) + 4
    seen = set()
    for dj in range(-span, span + 1):
        for di in range(-span, span + 1):
            i, j = i0 + di - int(0.5 * dj), j0 + dj
            if (i, j) in seen:
                continue
            seen.add((i, j))
            wx, wz = tiles.centre(i, j)
            dx, dz = wx - row.ax, wz - row.az
            lx, lz = dx * row.c - dz * row.s, dx * row.s + dz * row.c
            if lo <= abs(lx) <= hi and abs(lz) <= row.hl - 2.0 and hjit(i, j, 9, row.seed) < 0.55:
                cand.append((hjit(i, j, 11, row.seed), i, j, lx, lz))
    cand.sort()
    n_tri = 0
    done = 0
    for _, i, j, lx, lz in cand:
        if done >= count:
            break
        if not Sites(row, random.Random(0)).calm(lx, lz, 1.0, 0.9):
            continue
        poly = tiles.corners(i, j)
        cx, cz = tiles.centre(i, j)
        if any(abs((px - row.ax) * row.c - (pz - row.az) * row.s) < row.fl + 0.3 for px, pz in poly):
            continue
        pts = []
        curl_at = int(hjit(i, j, 13, row.seed) * 6)
        for q, (px, pz) in enumerate(poly):
            fx, fz = cx + (px - cx) * 0.86, cz + (pz - cz) * 0.86
            dx, dz = fx - row.ax, fz - row.az
            plx, plz = dx * row.c - dz * row.s, dx * row.s + dz * row.c
            curl = 0.1 + 0.05 * hjit(i, j, q) if q in (curl_at, (curl_at + 1) % 6) else 0.02
            y = row.gy(plx, plz) + BASE_OFF + 0.03 + curl
            y = min(y, row.gy(plx, plz) + FEATURE_MAX)
            pts.append((plx, y, plz))
        mid = (lx, row.gy(lx, lz) + BASE_OFF + 0.015, lz)
        col = tone(MUD[(i * 5 + j) % 4], MUD_DARK, i + j, 0.35)
        light = mix(col, CREAM_L, 0.25)
        for q in range(6):
            sheet_up(s, [mid, pts[q], pts[(q + 1) % 6]], None, [col, light, light])
        done += 1
    return done


SEAMS_USED = {}


def seam_list(row, tiles):
    """Crack seams as local-space segments, best first: the lane the pilot rides gets them first and they thin out toward the
    outer floor. A seam is a Voronoi edge of the mud tile lattice (jittered triangular lattice, so plates are polygons)."""
    sw = 0.3 * row.W
    span = int(max(row.W, row.L) / TILE) + 4
    j0 = int(round(row.az / (TILE * 0.866)))
    i0 = int(round(row.ax / TILE - 0.5 * j0))
    ring = [(1, 0), (0, 1), (-1, 1), (-1, 0), (0, -1), (1, -1)]
    items = []
    for dj in range(-span, span + 1):
        for di in range(-span, span + 1):
            i, j = i0 + di - int(0.5 * dj), j0 + dj
            for dd in ((1, 0), (0, 1), (-1, 1)):
                a = tiles.centre(i, j)
                b = tiles.centre(i + dd[0], j + dd[1])
                k = ring.index(dd)
                c1 = tiles.centre(i + ring[(k + 1) % 6][0], j + ring[(k + 1) % 6][1])
                c2 = tiles.centre(i + ring[(k - 1) % 6][0], j + ring[(k - 1) % 6][1])
                pts = []
                for (wx, wz) in (circum(a, b, c1), circum(a, b, c2)):
                    dx, dz = wx - row.ax, wz - row.az
                    pts.append((dx * row.c - dz * row.s, dx * row.s + dz * row.c))
                mid = (abs(pts[0][0]) + abs(pts[1][0])) / 2.0
                if mid > sw or max(abs(pts[0][1]), abs(pts[1][1])) > row.hl - 1.0:
                    continue
                if mid < 0.5 * sw and hjit(i, j, k, 7 + row.seed) < 0.5:
                    continue
                items.append((hjit(i, j, k, row.seed) + 0.9 * mid / sw, pts))
    items.sort(key=lambda it: it[0])
    return [p for _, p in items]


def seam_quad(row, pts, w=SEAM_W):
    (x0, z0), (x1, z1) = pts
    ln = math.hypot(x1 - x0, z1 - z0) or 1.0
    nx, nz = -(z1 - z0) / ln * w / 2, (x1 - x0) / ln * w / 2
    return [(x, row.gy(x, z) + SEAM_TOP, z) for x, z in ((x0 - nx, z0 - nz), (x1 - nx, z1 - nz), (x1 + nx, z1 + nz), (x0 + nx, z0 + nz))]


def base_builder(row, plan_holder):
    def build(s):
        rng = random.Random(row.seed)
        tiles = Tiles(row.seed % 997)
        cross = Cross(row)
        counts = PROFILE_PROPS[row.profile]
        sites = Sites(row, rng)
        scratch = kit_surface()
        build_props(scratch, row, sites, counts)
        n_plates = plates(scratch, row, tiles, counts["plates"])
        lim = row.fl + 0.25
        scratch.verts = [(nx, min(max(y, row.gy(nx, z) - 0.3), row.gy(nx, z) + PROP_TOP), z)
                         for x, y, z in scratch.verts for nx in (math.copysign(max(abs(x), lim), x),)]
        prop_tris = surface_tris(scratch)
        seams = seam_list(row, tiles) if counts["seam_cap"] else []
        n_seams = max(0, min(counts["seam_cap"], (BASE_TRIS - prop_tris - 3000) // 2, len(seams)))
        budget = BASE_TRIS - prop_tris - 2 * n_seams
        xs, zs, tris, step = lattice_plan(row, budget)
        SEAMS_USED[row.rid] = (seams, n_seams)
        plan_holder.update(dict(prop_tris=prop_tris, seams=n_seams, lattice_tris=tris, step=step, plates=n_plates))
        draw_lattice(s, row, cross, xs, zs)
        for pts in seams[:n_seams]:
            sheet_up(s, seam_quad(row, pts), SEAM)
        s.verts.extend(scratch.verts)
        off = len(s.verts) - len(scratch.verts)
        s.faces.extend(tuple(off + i for i in f) for f in scratch.faces)
        s.colors.extend(scratch.colors)
    return build


def kit_surface():
    return fw.LinerSurf("scratch", "enamel", smooth=False)


def surface_tris(s):
    return sum(len(f) - 2 for f in s.faces)


def pebbles_builder(row):
    def build(s):
        rng = random.Random(row.seed + 1)
        sites = Sites(row, rng)
        n = PROFILE_PROPS[row.profile]["pebbles"]
        done = 0
        tries = 0
        while done < n and tries < n * 8:
            tries += 1
            lx = (1 if rng.random() < 0.5 else -1) * row.W * (0.22 + 0.3 * rng.random())
            lz = (rng.random() * 2 - 1) * (row.hl - 1.0)
            if abs(lx) > row.hw + 1.0 or not sites.calm(lx, lz, 0.3, 0.8):
                continue
            r = 0.12 + 0.13 * rng.random()
            top = row.gy(lx, lz) + BASE_OFF + 0.1 + 0.12 * rng.random()
            lump(s, lx, lz, row.gy(lx, lz) - 0.04, top, r, 6, tone(PEBBLE[done % 4], SOIL, done, 0.3), row, done, 0.02)
            done += 1
    return build


def cracks_builder(row):
    """Detail 2: the seams the base had no triangles for, and curled flakes (mud) or slickrock chips (ramp) outside the flush band."""
    def build(s):
        rng = random.Random(row.seed + 2)
        counts = PROFILE_PROPS[row.profile]
        seams, used = SEAMS_USED.get(row.rid, ([], 0))
        for pts in seams[used:used + counts["d2_seams"]]:
            sheet_up(s, seam_quad(row, pts), SEAM)
        flakes = 0
        want = counts["d2_flakes"]
        sites = Sites(row, rng)
        tries = 0
        while flakes < want and tries < want * 10:
            tries += 1
            lx = (1 if rng.random() < 0.5 else -1) * (row.fl + 0.5 + (row.hw - row.fl - 1.0) * rng.random() * (0.5 if row.profile == "wash" else 1.0))
            lz = (rng.random() * 2 - 1) * (row.hl - 1.0)
            if abs(lx) > row.hw or not sites.calm(lx, lz, 0.3, 0.7):
                continue
            r = 0.14 + 0.12 * rng.random()
            n = 5
            ph = math.tau * rng.random()
            pts = []
            for q in range(n):
                x, z = lx + r * math.cos(ph + math.tau * q / n), lz + r * math.sin(ph + math.tau * q / n)
                pts.append((x, row.gy(x, z) + BASE_OFF + 0.03 + (0.08 if q == 0 else 0.015), z))
            col = MUD_TOP[flakes % 4] if row.profile == "wash" else FLAKE[flakes % 4]
            mid = (lx, row.gy(lx, lz) + BASE_OFF + 0.03, lz)
            for q in range(n):
                sheet_up(s, [mid, pts[q], pts[(q + 1) % n]], tone(col, MUD_DARK if row.profile == "wash" else SOIL, flakes, 0.35))
            flakes += 1
    return build


def liner_build(row, out_dir):
    holder = {}
    plans = [
        (row.rid, [(row.rid + "_body", base_builder(row, holder))], "base"),
        (row.rid + "_detail1", [(row.rid + "_detail1_mesh", pebbles_builder(row))], "detail"),
        (row.rid + "_detail2", [(row.rid + "_detail2_mesh", cracks_builder(row))], "detail"),
    ]
    rows = []
    for name, builders, kind in plans:
        common.reset()
        kit.PARTS.clear()
        root = common.empty(name + "_recipe")
        for obj_name, fn in builders:
            s = fw.LinerSurf(obj_name, "enamel", smooth=False)
            fn(s)
            for c in s.colors:
                if isinstance(c, str):
                    assert c.lstrip("#").lower() not in BANNED, (name, c)
            s.finish(root)
        path = Path(out_dir) / (name + ".glb")
        common.export(root, str(path))
        info = grind.gltf_info(path)
        m = info["metrics"]
        budget = BUDGET["base" if kind == "base" else "detail"]
        assert m["triangles"] <= budget["tris"], (name, m["triangles"], budget)
        if kind == "detail":
            assert m["vertices"] <= 3000, (name, m["vertices"])
        assert m["materials"] == ["enamel"], (name, m["materials"])
        assert m["draws"] == 1, (name, m["draws"])
        assert not any("-col" in n for n in info["nodes"]), (name, info["nodes"])
        entry = {"file": path.name, "triangles": m["triangles"], "vertices": m["vertices"], "draws": m["draws"],
                 "sha256": hashlib.sha256(path.read_bytes()).hexdigest()}
        if kind == "base":
            entry["plan"] = {k: (list(v) if isinstance(v, tuple) else v) for k, v in holder.items()}
        print("WASHES_EXPORT", row.rid, json.dumps(entry, sort_keys=True))
        rows.append(entry)
    return rows


def liner_check(row, out_dir):
    """Re-read ground.bin and measure each GLB against it; confirm no -col node anywhere."""
    fails = []
    for name in (row.rid, row.rid + "_detail1", row.rid + "_detail2"):
        doc, binary = read_glb(Path(out_dir) / (name + ".glb"))
        if any("-col" in n["name"] for n in doc["nodes"]):
            fails.append("%s: has a -col node" % name)
        meshes = mesh_nodes(doc)
        if len(meshes) != 1:
            fails.append("%s: %d mesh nodes" % (name, len(meshes)))
            continue
        pts = mesh_positions(doc, binary, meshes[0])
        gaps = [(x, y + row.g0 - row.sample(x, z)[0]) for x, y, z in pts]
        lo = min(g for _, g in gaps)
        if name == row.rid:
            worst = sorted(((g, x, z) for (x, g), (_, _, z) in zip(gaps, pts)))[:3] + sorted(((g, x, z) for (x, g), (_, _, z) in zip(gaps, pts)))[-2:]
            print("WASHES_WORST", [(round(g, 2), round(x, 1), round(z, 1)) for g, x, z in worst])
        hi = max(g for _, g in gaps)
        flush = [g for x, g in gaps if abs(x) <= row.fl]
        fmax = max(flush) if flush else 0.0
        line = "%s verts %d  vertical gap to ground %.3f .. %.3f m  flush-band max %.3f m (limit %.2f)" % (
            name, len(pts), lo, hi, fmax, LIMITS["flush_max"])
        ok = lo >= LIMITS["gap_min"] and hi <= LIMITS["base_max"] and fmax <= LIMITS["flush_max"] + 1e-4
        print("WASHES_LINER", line, "  no -col: yes  ", "PASS" if ok else "FAIL")
        if not ok:
            fails.append("%s: %s" % (name, line))
    return fails


NOTE = ("Decoration only, conformed to the %s bake; rebuild after a re-bake. Procedural, authored in this repository from Blender "
        "bmesh sheets and solids; no external mesh. No -col mesh: the stamped terrain stays the only collider. %s.")
DESC = {
    "wash": "a cracked mud floor of polygon plates with dark seams, a cut bank of banded strata under a grey cap, bleached driftwood, "
            "root balls, rusted corrugated sheet and pipe sections half-buried against the banks, gravel bars on the inside of bends",
    "ramp": "contour-banded slickrock and scree with bleached driftwood, root balls, rusted sheet and pipe sections at the margins "
            "and gravel fans",
}


def registry_rows(row, park):
    rows = []
    for name, base, text in ((row.rid, True, DESC[row.profile]),
                             (row.rid + "_detail1", False, "pebbles"),
                             (row.rid + "_detail2", False, "crack lips and curled flakes" if row.profile == "wash" else "slickrock chips")):
        note = NOTE % (park, text) if base else "Decoration only. Detail shell %s of %s, drawn by range (the detail class): %s." % (
            name[-1], row.rid, text)
        rows.append({"id": name, "path": "res://assets/models/park/%s.glb" % name, "class": "landform" if base else "detail",
                     "origin": "centre", "ships": True, "loader": "src/world/park/park_recipes.gd",
                     "provenance": {"recipe": "tools/blender/park/washes.py", "note": note}})
    return rows


def load_rows(args):
    stem = args.park if args.park.startswith("park_") else "park_" + args.park
    json_path = Path(args.json) if args.json else PARK_DIR / (stem + ".json")
    bake = Path(args.bake_dir) if args.bake_dir else SKETCH / "assets/park" / stem
    data = json.loads(json_path.read_text())
    by_id = {r["id"]: r for r in data["park_rows"]}
    ids = [r for r in args.rows.split(",") if r]
    missing = [r for r in ids if r not in by_id]
    assert not missing, "rows not in %s: %s" % (json_path, missing)
    return stem, [Row(by_id[r], bake) for r in ids]


def main():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    parser = argparse.ArgumentParser()
    parser.add_argument("--park", required=True)
    parser.add_argument("--rows", required=True)
    parser.add_argument("--json", default="")
    parser.add_argument("--bake-dir", default="")
    parser.add_argument("--out-dir", default=str(MODELS))
    parser.add_argument("--liners", action="store_true", help="accepted for flume_works parity; liners are all this tool builds")
    parser.add_argument("--check", action="store_true")
    parser.add_argument("--registry", action="store_true")
    parser.add_argument("--count-only", action="store_true")
    args = parser.parse_args(argv)
    stem, rows = load_rows(args)
    if args.registry:
        doc = {"assets": [r for row in rows for r in registry_rows(row, stem)]}
        print(json.dumps(doc, indent=1))
        return
    if args.check:
        bad = []
        for row in rows:
            fails = liner_check(row, args.out_dir)
            print("WASHES_CHECK", row.rid, "PASS" if not fails else "FAIL")
            bad += fails
        for line in bad:
            print("WASHES_FAIL", line)
        if bad:
            sys.exit(1)
        return
    out_dir = tempfile.mkdtemp(prefix="washes_count_") if args.count_only else args.out_dir
    for row in rows:
        liner_build(row, out_dir)


if __name__ == "__main__":
    main()
