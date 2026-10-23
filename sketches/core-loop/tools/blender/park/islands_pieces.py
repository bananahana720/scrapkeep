"""Real pieces for the four stage 5 (park_islands) rows that were still greybox stand-ins (wave 20 zero-placeholder bar):

  islands_ore_adit    row ore_adit   a timbered adit mouth: four timber sets (posts, caps, knee braces) down the fall line with
                                     side and roof lagging, set into the existing 30 x 14 opening. The lane between the posts
                                     stays open, 7.6 m clear over the ground. Drape fit: no collider (the stamp is the shape).
  islands_tram_head   row tram_head  the tram head's deck: planks laid on the stamped 30 x 30 plateau, a kerb beam round it,
                                     a rail stub with sleepers and a timber buffer stop with two copper bumpers. Drape fit.
  islands_keel_rib    rows keel_rib_w and keel_rib_e   a rusted ancient hull rib, 50 x 12 x 3 m, filling its collision box:
                                     web plate, top and keel flanges, stiffeners, lap strakes, rivets and chevron paint.

The collision contract (Andrew's coordinator, 2026-10-19): each row keeps today's collider exactly.
  keel ribs      their greybox collider is a 3 x 12 x 50 BoxShape3D standing on the ground. This GLB holds a `-col` box of
                 exactly that extent (eight corners at x +-1.5, y 0 or 12, z +-25, twelve triangles) and the rows take no fit,
                 so park_recipes.place_parts puts the GLB origin on the row node and the trimesh is the box's surface.
  tram, adit     stamped rows (`plateau`, no absolute y): park_recipes.place_row drops a greybox stand-in's Collider, so their
                 collider today is none and the stamped ground is the only solid. These GLBs carry no `-col`, and the rows say
                 `"fit": "drape"` so the node keeps standing on seat() (the plain the stamp raised) and the ride sensor stays
                 where it is. tests/park_islands_pieces_test.gd builds old and new and asserts all of it.

Drape rule (dam_dressing.py): a part with no collider stays within FLUSH (0.12 m) over the ground a ball rolls on, except the
timber work that stands outside the lane or above it. Vertices are authored relative to the row node: origin at (at.x, y0, at.z)
with y0 = what seat() gives, turned by yaw_deg (0 for these two rows), from the committed bake assets/park/park_islands/ground.bin.

Palette: weathered hewn timber, black iron and rust, desert-varnish stone, copper b77843 for the bumpers and lamp (never
brass), and cream chevron paint on the ribs (the ancient pattern cue). Vertex colour only; slots enamel (timber, paint, footings),
steel (iron, rust, copper) and, on the adit, stone. Polish (tools/blender/POLISH.md) is on: bevelled, smooth, AO and edge wear baked.

  blender -b -t 2 --python-exit-code 1 -P sketches/core-loop/tools/blender/park/islands_pieces.py -- \\
      [--out-dir DIR] [--only islands_keel_rib,...] [--count-only] [--log FILE]
"""
import argparse
import hashlib
import importlib.util
import json
import math
import os
from pathlib import Path
import random
import struct
import sys

import bmesh
import bpy

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE.parent))
import common  # noqa: E402

# Park recipes use the runtime material slots; the hero recipe kit does not know them, so name them as vertex-colour slots.
for _slot, _spec in (("enamel", {"vc": True, "rough": 0.7}), ("steel", {"vc": True, "rough": 0.55, "metal": 0.3}),
                     ("stone", {"vc": True, "rough": 0.95}), ("elastomer", {"vc": True, "rough": 0.9})):
    common.SLOTS[_slot] = _spec
import polish  # noqa: E402

polish.enable(detail=2, bevel=0.03, bevel_min=0.2)

SKETCH = HERE.parents[2]
MODELS = SKETCH / "assets/models/park"
PARK_FILE = SKETCH / "src/world/park/park_islands.json"
GROUND_BIN = SKETCH / "assets/park/park_islands/ground.bin"
CLASSES = json.loads((SKETCH / "assets/asset_budgets.json").read_text())["classes"]

FLUSH = 0.12        # the most a part with no collider may stand over a surface a ball rolls on
SET_Z = (-12.0, -4.0, 4.0, 12.0)    # the adit's timber sets, along the fall line
POST_X = 7.45       # post centre; 0.9 m posts leave the 14 m opening clear between their inner faces
CLEAR = 7.6         # cap underside over the ground: ball top 2 m + a full jump 3.25 m + margin
RIB_L, RIB_H, RIB_W = 50.0, 12.0, 3.0

RECIPES = {
    "islands_ore_adit": {"row": "ore_adit", "budget": "park_large", "seed": 501},
    "islands_tram_head": {"row": "tram_head", "budget": "landform", "seed": 502},
    "islands_keel_rib": {"row": "keel_rib_w", "budget": "detail", "seed": 503},
}

# Tones, sRGB hex.
TIMBER = ("6d4f36", "7a5a3d", "5d4430", "86694a")
TIMBER_OLD = ("8a7a64", "7c6e5b", "9a8b73")        # sun-bleached grey faces
PLANK = ("8b6a47", "7c5d3f", "9a7a55", "6f533a")
ENDGRAIN = ("4a3422", "553b27")
IRON = ("2b2724", "3a3430", "443c36")
RUST = ("8a4a35", "7a3f2d", "9b513a", "6b3a2c")
RUST_DK = ("4f3328", "5a3a2c", "46302a")
COPPER = ("b77843", "a56b3b")
VARNISH = ("3a3027", "463a30")
SANDSTONE = ("a98f68", "9a8460", "b49c74")
CREAM = ("d9c9a8", "cdbb98", "e3d4b0")


def hexf(h):
    return tuple(int(h[i:i + 2], 16) / 255.0 for i in (0, 2, 4))


def tone(rng, palette, spread=0.06):
    """A palette colour with a small deterministic brightness shift, as sRGB hex."""
    c = hexf(palette[rng.randrange(len(palette))])
    k = 1.0 + rng.uniform(-spread, spread)
    return "%02x%02x%02x" % tuple(max(0, min(255, round(v * k * 255))) for v in c)


def xyz(v):
    """Godot (x, y up, z ride) to Blender (x, -z, y); the exporter turns it back."""
    return (v[0], -v[2], v[1])


# ------------------------------------------------------------------------------------------------ the ground
def load_dressing():
    spec = importlib.util.spec_from_file_location("dam_dressing", HERE / "dam_dressing.py")
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


class Site:
    """A row's node frame and the bake's ground under it (yaw 0 for the two draped rows)."""

    def __init__(self, dd, row):
        self.row = row
        self.ground = dd.Ground(GROUND_BIN)
        self.ax, self.az = float(row["at"][0]), float(row["at"][1])
        self.y0 = dd.base_height(row, self.ground)

    def g(self, x, z):
        """Ground height over the node's origin plane at local (x, z)."""
        return self.ground.h(self.ax + x, self.az + z) - self.y0


# ------------------------------------------------------------------------------------------------ geometry kit
class Kit:
    """Godot-coordinate primitives over a common.Part (Blender Z up)."""

    def __init__(self, name, seed):
        self.part = common.Part(name)
        self.rng = random.Random(seed)

    def box(self, slot, lo, hi, color, **kw):
        size = (hi[0] - lo[0], hi[2] - lo[2], hi[1] - lo[1])
        centre = ((lo[0] + hi[0]) / 2, (lo[1] + hi[1]) / 2, (lo[2] + hi[2]) / 2)
        return self.part.box(slot, size, loc=xyz(centre), color=color)

    def slab(self, slot, x0, x1, z0, z1, ylo, yhi, color):
        """A box whose bottom and top run straight in z: ylo and yhi are (y at z0, y at z1)."""
        r = bmesh.ops.create_cube(self.part.bm, size=1.0)
        for v in r["verts"]:
            gx = x0 if v.co.x < 0 else x1
            gz = z1 if v.co.y < 0 else z0              # Blender y is -z
            t = 0.0 if gz == z0 else 1.0
            gy = (ylo[0] + (ylo[1] - ylo[0]) * t) if v.co.z < 0 else (yhi[0] + (yhi[1] - yhi[0]) * t)
            v.co = xyz((gx, gy, gz))
        return self.part.paint(self.part._faces(r["verts"]), slot, color)

    def beam(self, slot, a, b, w, h, color, roll=0.0):
        return self.part.beam(slot, xyz(a), xyz(b), w, h, color=color, roll=roll)

    def rod(self, slot, a, b, r, color, segs=6):
        return self.part.rod(slot, xyz(a), xyz(b), r, segs=segs, color=color)

    def disc(self, slot, centre, r, thick, axis, color, segs=8):
        """A flat cylinder facing +/-axis ('x' or 'z' in Godot terms)."""
        a = list(centre)
        b = list(centre)
        i = 0 if axis == "x" else 2
        a[i] -= thick / 2
        b[i] += thick / 2
        return self.rod(slot, tuple(a), tuple(b), r, color, segs=segs)


def lerp(a, b, t):
    return a + (b - a) * t


# ------------------------------------------------------------------------------------------------ ore_adit
def build_adit(site, seed):
    k = Kit("islands_ore_adit", seed)
    rng = k.rng
    g = site.g
    # The set's cap underside follows the higher post's ground, so the opening never closes toward the slope.
    hc = {z: max(g(-POST_X, z), g(POST_X, z)) + CLEAR for z in SET_Z}
    for z in SET_Z:
        top = hc[z]
        for sx in (-1, 1):
            x = sx * POST_X
            base = g(x, z) - 0.9
            # stone footing, then the hewn post
            k.box("stone", (x - 0.85, base, z - 0.85), (x + 0.85, g(x, z) + 0.3, z + 0.85), tone(rng, SANDSTONE))
            k.box("enamel", (x - 0.45, g(x, z) + 0.3, z - 0.45), (x + 0.45, top, z + 0.45), tone(rng, TIMBER))
            # bleached face boards on the lane side, iron strap bands, bolt heads
            k.box("enamel", (x - sx * 0.46 - 0.02, g(x, z) + 0.4, z - 0.36), (x - sx * 0.46 + 0.02, top - 0.2, z + 0.36),
                  tone(rng, TIMBER_OLD))
            for h in (1.1, 3.4, 5.7):
                y = g(x, z) + h
                k.box("steel", (x - 0.5, y, z - 0.5), (x + 0.5, y + 0.14, z + 0.5), tone(rng, IRON))
                k.box("steel", (x - sx * 0.51 - 0.02, y - 0.02, z - 0.1), (x - sx * 0.51 + 0.02, y + 0.16, z + 0.1), tone(rng, RUST))
            # knee brace from the post's inner face up to the cap
            k.beam("enamel", (x - sx * 0.45, top - 2.6, z), (x - sx * 2.7, top - 0.1, z), 0.5, 0.5, tone(rng, TIMBER))
        # cap beam across both posts, with end grain showing
        k.box("enamel", (-POST_X - 0.8, top, z - 0.55), (POST_X + 0.8, top + 1.0, z + 0.55), tone(rng, TIMBER, 0.04))
        for sx in (-1, 1):
            k.box("enamel", (sx * (POST_X + 0.8) - 0.01 * sx, top + 0.05, z - 0.45), (sx * (POST_X + 0.8) + 0.03 * sx, top + 0.95, z + 0.45),
                  tone(rng, ENDGRAIN))
        # iron tie plate on the cap's front
        k.box("steel", (-1.6, top + 0.15, z - 0.58), (1.6, top + 0.85, z - 0.55), tone(rng, IRON))
    # lagging: roof planks over the caps and side boards between the posts
    zs = list(SET_Z)
    for i in range(len(zs) - 1):
        za, zb = zs[i], zs[i + 1]
        ra, rb = hc[za] + 1.0, hc[zb] + 1.0
        za2, zb2 = za, zb
        ya, yb = ra, rb
        if i == 0:                       # overhang past the first set, on the same slope
            za2 = za - 1.6
            ya = ra - (rb - ra) / (zb - za) * 1.6
        if i == len(zs) - 2:
            zb2 = zb + 1.6
            yb = rb + (rb - ra) / (zb - za) * 1.6
        n = 7
        w = (2 * (POST_X + 1.1)) / n
        for j in range(n):
            x0 = -(POST_X + 1.1) + j * w
            k.slab("enamel", x0 + 0.03, x0 + w - 0.03, za2, zb2, (ya, yb), (ya + 0.28, yb + 0.28), tone(rng, PLANK))
        # side boards, vertical, between the sets' posts on both sides
        m = 8
        bw = (zb - za - 1.0) / m
        for sx in (-1, 1):
            xo = sx * (POST_X - 0.3)
            for j in range(m):
                z0 = za + 0.5 + j * bw
                z1 = z0 + bw - 0.05
                lo0, lo1 = g(xo, z0) - 0.7, g(xo, z1) - 0.7
                t0, t1 = hc[za] + (hc[zb] - hc[za]) * ((z0 - za) / (zb - za)), hc[za] + (hc[zb] - hc[za]) * ((z1 - za) / (zb - za))
                k.slab("enamel", xo - 0.12, xo + 0.12, z0, z1, (lo0, lo1), (t0, t1), tone(rng, PLANK if (i + j) % 3 else TIMBER_OLD))
            # a waling rail along the board faces on the lane side
            wy = lambda z: g(xo, z) + 3.6
            k.slab("steel", xo - sx * 0.14 - 0.03, xo - sx * 0.14 + 0.03, za + 0.5, zb - 0.5, (wy(za + 0.5), wy(zb - 0.5)),
                   (wy(za + 0.5) + 0.22, wy(zb - 0.5) + 0.22), tone(rng, IRON))
    # the carbide lamp (mining_adit_lamp): a copper housing on a bracket under the first cap, lane side +x
    lz = SET_Z[0] + 0.7
    top = hc[SET_Z[0]]
    k.box("steel", (POST_X - 1.9, top - 0.3, lz - 0.05), (POST_X - 0.4, top - 0.18, lz + 0.05), tone(rng, IRON))
    k.rod("steel", (POST_X - 1.5, top - 0.3, lz), (POST_X - 1.5, top - 0.9, lz), 0.03, tone(rng, IRON), segs=4)
    k.part.cyl("steel", 0.26, 0.2, 0.55, segs=8, loc=xyz((POST_X - 1.5, top - 1.2, lz)), color=tone(rng, COPPER))
    k.part.cyl("steel", 0.12, 0.18, 0.12, segs=8, loc=xyz((POST_X - 1.5, top - 0.88, lz)), color=tone(rng, COPPER))
    # a sign board nailed across the first cap's front
    k.box("enamel", (-2.2, top + 0.05, SET_Z[0] - 0.64), (2.2, top + 0.9, SET_Z[0] - 0.58), tone(rng, CREAM))
    for dx in (-1.55, -0.5, 0.55, 1.5):
        k.box("steel", (dx - 0.18, top + 0.2, SET_Z[0] - 0.67), (dx + 0.18, top + 0.75, SET_Z[0] - 0.64), tone(rng, VARNISH))
    return k


# ------------------------------------------------------------------------------------------------ tram_head
def build_tram(site, seed):
    k = Kit("islands_tram_head", seed)
    rng = k.rng
    g = site.g
    half = 14.7
    top = 0.04                      # deck planks stand this far over the stamped plateau
    # deck: planks run across x in 1.2 m courses down z, butt joints every 7.35 m
    course = 1.2
    z = -half
    row = 0
    while z < half - 1e-6:
        z1 = min(z + course, half)
        cuts = [-half, -half + 3.4 + (row % 3) * 1.6, 0.0 + (row % 2) * 1.9 - 0.9, half - 3.1 - ((row + 1) % 3) * 1.4, half]
        cuts = sorted(set(round(c, 3) for c in cuts))
        for a, b in zip(cuts, cuts[1:]):
            xm = (a + b) / 2
            y0 = g(xm, z) + top
            y1 = g(xm, z1) + top
            k.slab("enamel", a + 0.03, b - 0.03, z + 0.02, z1 - 0.02, (y0 - 0.1, y1 - 0.1), (y0, y1), tone(rng, PLANK if row % 5 else TIMBER_OLD))
        z = z1
        row += 1
    # kerb beams round the deck
    for sx in (-1, 1):
        xo = sx * (half + 0.15)
        k.slab("enamel", xo - 0.18, xo + 0.18, -half - 0.3, half + 0.3, (g(xo, -half) - 0.3, g(xo, half) - 0.3),
               (g(xo, -half) + 0.11, g(xo, half) + 0.11), tone(rng, TIMBER, 0.04))
    for sz in (-1, 1):
        zo = sz * (half + 0.15)
        k.slab("enamel", -half - 0.3, half + 0.3, zo - 0.18, zo + 0.18, (g(0, zo) - 0.3, g(0, zo) - 0.3), (g(0, zo) + 0.11, g(0, zo) + 0.11),
               tone(rng, TIMBER, 0.04))
    # iron straps across the deck at each butt-joint line (flat, 3 mm over the planks)
    for zz in (-9.6, -2.4, 4.8, 11.4):
        y = g(0, zz) + top + 0.012
        k.slab("steel", -half + 0.3, half - 0.3, zz - 0.07, zz + 0.07, (y, g(0, zz + 0.07) + top + 0.012), (y + 0.012, g(0, zz + 0.07) + top + 0.024),
               tone(rng, IRON))
    # the rail stub: along the fall line on the west side, from the buffer stop at the back to the front kerb
    gauge = 0.75
    rx = -9.2
    z_back, z_front = -12.6, 12.6
    for rz in [z_back + 0.6 + i * 1.1 for i in range(int((z_front - z_back) / 1.1))]:
        y = g(rx, rz) + top
        k.slab("enamel", rx - gauge - 0.3, rx + gauge + 0.3, rz - 0.13, rz + 0.13, (y, g(rx, rz + 0.13) + top), (y + 0.035, g(rx, rz + 0.13) + top + 0.035),
               tone(rng, TIMBER))
    for sx in (-1, 1):
        x = rx + sx * gauge
        ya, yb = g(x, z_back) + top + 0.035, g(x, z_front) + top + 0.035
        k.slab("steel", x - 0.05, x + 0.05, z_back, z_front, (ya, yb), (ya + 0.05, yb + 0.05), tone(rng, RUST))
    # the buffer stop: a timber baulk across the rail ends, two copper bumpers on iron stems, a sleeper behind
    yb = g(rx, z_back) + top
    k.box("enamel", (rx - 1.55, yb, z_back - 0.55), (rx + 1.55, yb + 0.95, z_back + 0.05), tone(rng, TIMBER, 0.04))
    k.box("enamel", (rx - 1.65, yb, z_back - 0.9), (rx - 1.25, yb + 1.3, z_back - 0.3), tone(rng, TIMBER))
    k.box("enamel", (rx + 1.25, yb, z_back - 0.9), (rx + 1.65, yb + 1.3, z_back - 0.3), tone(rng, TIMBER))
    for sx in (-1, 1):
        x = rx + sx * gauge
        k.rod("steel", (x, yb + 0.48, z_back + 0.05), (x, yb + 0.48, z_back + 0.35), 0.07, tone(rng, IRON), segs=6)
        k.disc("steel", (x, yb + 0.48, z_back + 0.42), 0.24, 0.1, "z", tone(rng, COPPER), segs=10)
    k.box("steel", (rx - 1.4, yb + 0.7, z_back + 0.05), (rx + 1.4, yb + 0.8, z_back + 0.08), tone(rng, IRON))
    # a rusted cable shoe and stanchion at the far corner where the tramway leaves the deck (tramway from [95, -372])
    cx, cz = -half + 0.7, -half + 0.9
    yc = g(cx, cz) + top
    k.box("enamel", (cx - 0.8, yc - 0.1, cz - 0.8), (cx + 0.8, yc + 0.35, cz + 0.8), tone(rng, SANDSTONE))
    k.box("steel", (cx - 0.22, yc + 0.35, cz - 0.22), (cx + 0.22, yc + 1.5, cz + 0.22), tone(rng, RUST))
    k.part.cyl("steel", 0.3, 0.3, 0.14, segs=10, loc=xyz((cx, yc + 1.55, cz)), rot=(math.pi / 2, 0, 0), color=tone(rng, COPPER))
    return k


# ------------------------------------------------------------------------------------------------ keel ribs
def rib_top(z):
    """The rib's top edge: a shallow arch, 11.85 m amidships and 10.65 m at the ends (the box is 12 m)."""
    return RIB_H - 0.15 - 1.2 * (z / (RIB_L / 2)) ** 2


def build_rib(_site, seed):
    k = Kit("islands_keel_rib", seed)
    rng = k.rng
    hz = RIB_L / 2 - 0.05               # polish and the beams' squared ends stay inside the collision box
    hx = RIB_W / 2 - 0.02
    bays = 5
    step = 2 * hz / bays
    web = 0.42
    flange = 0.6
    keel = 0.75
    for i in range(bays):
        z0, z1 = -hz + i * step, -hz + (i + 1) * step
        ta, tb = rib_top(z0), rib_top(z1)
        # keel flange, web plate and top flange (a bulb angle) in 10 m bays, each a little different in rust
        k.box("steel", (-hx, 0.0, z0 + 0.03), (hx, keel, z1 - 0.03), tone(rng, RUST_DK))
        k.slab("steel", -web, web, z0 + 0.02, z1 - 0.02, (keel - 0.05, keel - 0.05), (ta - flange + 0.05, tb - flange + 0.05),
               tone(rng, RUST if i % 2 else RUST_DK, 0.1))
        k.slab("steel", -hx, hx, z0 + 0.03, z1 - 0.03, (ta - flange, tb - flange), (ta, tb), tone(rng, IRON if i % 2 else RUST_DK))
        # chevron paint on the flange top, faded: the ancient pattern cue
        for s in (-2.5, 2.5):
            zc = (z0 + z1) / 2 + s
            yc = rib_top(zc)
            for sx in (-1, 1):
                k.beam("enamel", (sx * 0.8, yc + 0.01, zc + 0.35), (0.0, yc + 0.01, zc - 0.25), 0.16, 0.02, tone(rng, CREAM, 0.1))
    # stiffeners: a flat bar on both faces at every frame line, 5 m apart
    for i in range(11):
        z = -hz + 0.2 + i * (2 * hz - 0.4) / 10
        for sx in (-1, 1):
            x0, x1 = (web, web + 0.38) if sx > 0 else (-web - 0.38, -web)
            k.box("steel", (x0, keel - 0.05, z - 0.17), (x1, rib_top(z) - flange + 0.05, z + 0.17), tone(rng, IRON))
    # lap strakes on the web at 1/3 and 2/3 height, staggered between bays, two rivets a corner
    for lvl, y in ((0, 3.8), (1, 7.2)):
        for i in range(bays):
            if (i + lvl) % 2:
                continue
            z0, z1 = -hz + i * step + 1.0, -hz + (i + 1) * step - 1.0
            for sx in (-1, 1):
                x0, x1 = (web, web + 0.1) if sx > 0 else (-web - 0.1, -web)
                k.box("steel", (x0, y, z0), (x1, y + 1.1, z1), tone(rng, RUST, 0.12))
                for rz in (z0 + 0.4, z1 - 0.4):
                    k.part.cyl("steel", 0.08, 0.06, 0.06, segs=4, loc=xyz((sx * (web + 0.12), y + 0.55, rz)), rot=(0, math.pi / 2, 0),
                               color=tone(rng, IRON))
    # shallow dark recesses in the web, four per face: age, not holes (the collision box is solid)
    for zc in (-18.0, -6.0, 6.0, 18.0):
        yc = 0.5 * (keel + rib_top(zc) - flange) + 0.3
        for sx in (-1, 1):
            k.disc("steel", (sx * (web + 0.04), yc, zc), 0.95, 0.04, "x", tone(rng, VARNISH), segs=6)
    return k


# ------------------------------------------------------------------------------------------------ export
def box_col(name, hx, h, hz):
    """The collision mesh: the greybox collider's box as eight corners and twelve triangles, a BoxShape3D's surface."""
    corners = [(sx * hx, sy, sz * hz) for sx in (-1, 1) for sy in (0.0, h) for sz in (-1, 1)]
    idx = {c: i for i, c in enumerate(corners)}

    def v(sx, sy, sz):
        return idx[(sx * hx, sy * h, sz * hz)]
    quads = [((1, 0, -1), (1, 1, -1), (1, 1, 1), (1, 0, 1)), ((-1, 0, 1), (-1, 1, 1), (-1, 1, -1), (-1, 0, -1)),
             ((-1, 1, -1), (-1, 1, 1), (1, 1, 1), (1, 1, -1)), ((-1, 0, 1), (-1, 0, -1), (1, 0, -1), (1, 0, 1)),
             ((1, 0, 1), (1, 1, 1), (-1, 1, 1), (-1, 0, 1)), ((-1, 0, -1), (-1, 1, -1), (1, 1, -1), (1, 0, -1))]
    faces = []
    for q in quads:
        a, b, c, d = (v(*p) for p in q)
        faces += [(a, b, c), (a, c, d)]
    mesh = bpy.data.meshes.new(name)
    mesh.from_pydata([xyz(c) for c in corners], [], faces)
    mesh.update()
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.scene.collection.objects.link(obj)
    return obj


def export_one(path, rid, kit, col):
    root = common.empty(rid + "_root")
    obj = kit.part.to_object(parent=root)
    obj.name = rid
    bpy.context.view_layer.update()
    polish.bake(root, polish.options())             # bake before the collision box joins the scene: it would occlude the rib
    if col:
        c = box_col(rid + "-col-col", *col)
        c.parent = root
    bpy.context.view_layer.update()
    for o in bpy.context.scene.objects:
        o.select_set(False)
    for o in common.tree(root):
        o.select_set(True)
    os.makedirs(os.path.dirname(str(path)), exist_ok=True)
    bpy.ops.export_scene.gltf(filepath=str(path), export_format="GLB", use_selection=True, export_apply=True, export_yup=True,
                              export_materials="EXPORT", export_vertex_color="ACTIVE", export_extras=False, export_animations=False,
                              export_cameras=False, export_lights=False)
    common.canonical_indices(str(path), vertices=True)
    print("EXPORTED", path)


def gltf_metrics(path):
    data = Path(path).read_bytes()
    length = struct.unpack_from("<I", data, 12)[0]
    doc = json.loads(data[20:20 + length])
    tris = verts = draws = 0
    lo, hi = [float("inf")] * 3, [-float("inf")] * 3
    nodes = {i: n for i, n in enumerate(doc["nodes"])}
    col_meshes = {n["mesh"] for n in nodes.values() if "mesh" in n and n["name"].endswith("-col")}
    for mi, mesh in enumerate(doc["meshes"]):
        for prim in mesh["primitives"]:
            p = doc["accessors"][prim["attributes"]["POSITION"]]
            verts += p["count"]
            tris += doc["accessors"][prim["indices"]]["count"] // 3
            if mi not in col_meshes:
                draws += 1
            if mi not in col_meshes:
                for kk in range(3):
                    lo[kk], hi[kk] = min(lo[kk], p["min"][kk]), max(hi[kk], p["max"][kk])
    return {"triangles": tris, "vertices": verts, "draws": draws, "materials": [m["name"] for m in doc.get("materials", [])],
            "nodes": [n["name"] for n in doc["nodes"]], "bounds": {"min": lo, "max": hi}}


BUILDERS = {"islands_ore_adit": build_adit, "islands_tram_head": build_tram, "islands_keel_rib": build_rib}


def main():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    ap = argparse.ArgumentParser()
    ap.add_argument("--out-dir", default=str(MODELS))
    ap.add_argument("--only", default="")
    ap.add_argument("--count-only", action="store_true")
    ap.add_argument("--log", default=None)
    args = ap.parse_args(argv)
    only = [s for s in args.only.split(",") if s]
    dd = load_dressing()
    rows = {r["id"]: r for r in json.loads(PARK_FILE.read_text())["park_rows"]}
    out = {}
    for rid, spec in RECIPES.items():
        if only and rid not in only:
            continue
        common.reset()
        site = Site(dd, rows[spec["row"]]) if spec["row"] != "keel_rib_w" else None
        kit = BUILDERS[rid](site, spec["seed"])
        col = (RIB_W / 2, RIB_H, RIB_L / 2) if rid == "islands_keel_rib" else None
        path = Path(args.out_dir) / (rid + ".glb")
        if args.count_only:
            print("COUNT", rid, len(kit.part.bm.faces))
            continue
        export_one(path, rid, kit, col)
        m = gltf_metrics(path)
        cap = CLASSES[spec["budget"]]
        assert m["triangles"] <= cap["tris"] and m["vertices"] <= cap["verts"] and m["draws"] <= cap["draws"], (rid, m, cap)
        out[rid] = dict(m, file=path.name, sha256=hashlib.sha256(path.read_bytes()).hexdigest(), budget=spec["budget"])
        print("PIECE", rid, json.dumps({k2: out[rid][k2] for k2 in ("triangles", "vertices", "draws", "bounds", "sha256")}, sort_keys=True))
    if args.log and out:
        Path(args.log).parent.mkdir(parents=True, exist_ok=True)
        Path(args.log).write_text(json.dumps(out, indent=1, sort_keys=True) + "\n")


if __name__ == "__main__":
    main()
