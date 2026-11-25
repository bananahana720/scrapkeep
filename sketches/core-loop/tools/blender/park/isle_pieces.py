"""The Highdraft islands' collider-locked pieces (park_islands, coordinator on #149, 2026-10-19 02:18Z): three GLBs drawn
over rows whose greybox collider must not change, so park_recipes.gd places them as OVER_GREYBOX recipes (the row's
greybox node, seat, ride sensor and box collider, or none where its stamp replaces the box) and only the view is new.
Only the adit portal carries a -col, for its own uprights (adit_collider), which park_recipes.gd puts on a separate
PieceCollider body; nothing else the ball can reach stands more than FLUSH over a surface it rolls on.

  isle_keel_rib     keel_rib_w and keel_rib_e ([50, 12, 3], element ledge, no stamp): a rusted hull rib that fills the
                    live 3 x 12 x 50 box (x +-1.5, y 0 to 12, z +-25) so no face of the collider stands in open air: top
                    and bottom flanges and 0.4 m stiffeners every 5 m at the box faces, flaking-paint web panels between
                    them set in only 0.1 m, end plates on the box ends, rivet rows proud by 0.04 m. The bottom flange
                    skirts down to the ground under the flat-bottomed box (the bake's ground there is y = 0.024 + 0.0166 z
                    in the row frame, -0.39 to +0.44 over the rib; both rows sit mirrored on the same profile).
  isle_tram_head    tram_head ([30, 3, 30], element ledge, stamp plateau): the plateau stamp replaces the box, so the
                    stamped top is the collider. Its flat top is y = 3.0 - 0.05 z for z -14 to 8 and |x| <= 14 in the
                    row frame (the node stands on the plain under the stamp); past z 8 a neighbour cuts it lower. A
                    plank deck 0.04 m proud of that top, a 2 m tram track, a wheel-stop sill, a painted hazard band and
                    a winch bed plate at the back (z -12.6), none more than FLUSH (0.12 m) proud, because the stamped
                    top is the row's only collider; no part on the drop side. The nearest pilot line passes 35 m from the centre.
  isle_adit_portal  ore_adit ([30, 0.01, 14], element tunnel, stamp plateau with no raise): a 1 cm decal on a ramp, y =
                    0.0127 - 0.2625 z in the row frame, with no opening in the terrain. Three timber sets straddle the
                    ramp's uphill end (z -13.5, -9.5, -5.5), posts at x +-9.5 outside the 14 m lane, caps 7 m over the
                    ramp (CLEAR_ABOVE 5.5 in ledges.py), roof lagging over them, a number board and a hanging lamp on the
                    downhill cap; ties and a track down the ramp 0.05 and 0.11 m proud; rubble footings sunk to FLUSH.
                    The posts and side lagging carry the portal's own -col (adit_collider), all outside the lane. Sable, Rivet and Cannon's lines
                    enter the lane 5 m off its axis at z -13, 3.5 m inside the posts after the ball's radius.

Convention: Godot metres, +Y up, the row's length along +Z, its width along X, the origin at the row node (the footprint
centre on the ground the row stands on); park_recipes.gd draws each GLB at the node with no scale. Each part is a
common.Part under polish (POLISH.md: bevels, smooth shading with hard creases, baked AO and edge wear into the vertex
colours), one "enamel" surface (the slot role whose material reads vertex colour as albedo), one draw.

Palette: Highdraft mine timber, black iron, rust and flaking petrol hull paint, copper b77843 for the lamp (never brass),
bone for the number board. No texture, no light, no mesh from any other source.

  prlimit -v12884901888 blender -b --factory-startup --threads 2 --python-exit-code 1 -P \\
      sketches/core-loop/tools/blender/park/isle_pieces.py -- [--out-dir DIR] [--recipe ID] [--count-only]
"""
import argparse
import hashlib
import json
import math
import os
import random
import sys

import bmesh
import bpy
from mathutils import Vector

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, ".."))
import common
import polish

MODELS = os.path.join(common.SKETCH, "assets", "models", "park")
CLASSES = json.load(open(os.path.join(common.SKETCH, "assets", "asset_budgets.json")))["classes"]
SLOT = "enamel"
FLUSH = 0.12
CLEAR_ABOVE = 5.5

TIMBER = "8c6d4c"
TIMBER_DK = "6b4a30"
TIMBER_LT = "9a7650"
IRON = "2b2724"
IRON_HI = "3d3732"
RUST = "8a4e36"
RUST_DK = "5e3424"
RUST_LT = "a8603c"
PAINT = "365754"
PAINT_DK = "2a4543"
COPPER = "b77843"
BONE = "d2c5a5"
STENCIL = "2b2724"
HAZARD = "c8553a"
STONE = "8a7a68"


def g(x, y, z):
    """Godot (x, y, z) to Blender (x, -z, y)."""
    return (x, -z, y)


def solid(part, corners, color):
    """A convex six-sided solid from eight Godot corners: bottom ring then top ring, each counter-clockwise from above."""
    bm = part.bm
    vs = [bm.verts.new(g(*c)) for c in corners]
    faces = [bm.faces.new([vs[3], vs[2], vs[1], vs[0]]), bm.faces.new([vs[4], vs[5], vs[6], vs[7]])]
    for k in range(4):
        faces.append(bm.faces.new([vs[k], vs[(k + 1) % 4], vs[4 + (k + 1) % 4], vs[4 + k]]))
    return part.paint(faces, SLOT, color)


def block(part, lo, hi, color):
    """An axis-aligned box between two Godot corners."""
    (x0, y0, z0), (x1, y1, z1) = lo, hi
    return solid(part, [(x0, y0, z0), (x1, y0, z0), (x1, y0, z1), (x0, y0, z1),
                        (x0, y1, z0), (x1, y1, z0), (x1, y1, z1), (x0, y1, z1)], color)


def sloped(part, x0, x1, z0, z1, floor, lo, hi, color):
    """A box whose bottom and top follow floor(z) + lo and floor(z) + hi along z (a plank or tie on a slope)."""
    a0, a1 = floor(z0), floor(z1)
    return solid(part, [(x0, a0 + lo, z0), (x1, a0 + lo, z0), (x1, a1 + lo, z1), (x0, a1 + lo, z1),
                        (x0, a0 + hi, z0), (x1, a0 + hi, z0), (x1, a1 + hi, z1), (x0, a1 + hi, z1)], color)


def shade(hex_color, rng, amount=0.06):
    """The colour lightened or darkened by up to amount, so neighbouring pieces never read as one flat fill."""
    c = common.srgb(hex_color)
    k = 1.0 + rng.uniform(-amount, amount)
    return "".join("%02x" % max(0, min(255, round(v * k * 255))) for v in c)


def stencil(part, cx, y0, y1, z, digits, facing):
    """Seven-segment digits on a board face at z (facing +1 for +z): strokes 0.015 m proud."""
    segs_of = {"0": "abcdef", "1": "bc", "2": "abdeg", "3": "abcdg", "4": "bcfg", "5": "acdfg", "6": "acdefg", "7": "abc",
               "8": "abcdefg", "9": "abcdfg"}
    ys = (y0 + 0.08, (y0 + y1) / 2, y1 - 0.08)
    w, sw = 0.14, 0.035
    for k, d in enumerate(digits):
        x = cx + (k - (len(digits) - 1) / 2) * 0.42
        bars = {"a": ((x - w, ys[2] - sw), (x + w, ys[2])), "g": ((x - w, ys[1] - sw / 2), (x + w, ys[1] + sw / 2)),
                "d": ((x - w, ys[0]), (x + w, ys[0] + sw)), "b": ((x + w - sw, ys[1]), (x + w, ys[2])),
                "c": ((x + w - sw, ys[0]), (x + w, ys[1])), "f": ((x - w, ys[1]), (x - w + sw, ys[2])),
                "e": ((x - w, ys[0]), (x - w + sw, ys[1]))}
        for s in segs_of[d]:
            (bx0, by0), (bx1, by1) = bars[s]
            za, zb = sorted((z, z + facing * 0.015))
            block(part, (bx0, by0, za), (bx1, by1, zb), STENCIL)


RIB_HX, RIB_TOP, RIB_HZ = 1.5, 12.0, 25.0
RIB_FLANGE = 0.8
RIB_INSET = 0.1
RIB_BAY = 5.0
RIB_STIFF = 0.4


def rib_ground(z):
    return 0.024 + 0.0166 * z


def keel_rib(root, rng):
    rib = common.Part("isle_keel_rib")
    n = int(2 * RIB_HZ / RIB_BAY)
    for k in range(n):
        z0, z1 = -RIB_HZ + k * RIB_BAY, -RIB_HZ + (k + 1) * RIB_BAY
        foot = min(rib_ground(z0), rib_ground(z1), 0.0) - 0.15
        block(rib, (-RIB_HX, foot, z0), (RIB_HX, RIB_FLANGE, z1), shade(RUST_DK, rng))
        za, zb = z0 + RIB_STIFF / 2, z1 - RIB_STIFF / 2
        paint = PAINT if rng.random() < 0.55 else RUST
        block(rib, (-RIB_HX + RIB_INSET, RIB_FLANGE, za), (RIB_HX - RIB_INSET, RIB_TOP - RIB_FLANGE, zb), shade(paint, rng))
        h = rng.uniform(1.6, 3.4)
        block(rib, (-RIB_HX + RIB_INSET - 0.01, RIB_FLANGE, za + 0.3), (RIB_HX - RIB_INSET + 0.01, RIB_FLANGE + h, zb - 0.3),
              shade(RUST_LT if paint == PAINT else RUST_DK, rng))
    block(rib, (-RIB_HX, RIB_TOP - RIB_FLANGE, -RIB_HZ), (RIB_HX, RIB_TOP, RIB_HZ), shade(RUST, rng, 0.03))
    for k in range(n + 1):
        z = -RIB_HZ + k * RIB_BAY
        z0, z1 = max(-RIB_HZ, z - RIB_STIFF / 2), min(RIB_HZ, z + RIB_STIFF / 2)
        block(rib, (-RIB_HX, RIB_FLANGE, z0), (RIB_HX, RIB_TOP - RIB_FLANGE, z1), shade(RUST_DK if k % 2 else RUST, rng))
    with rib.region(bevel=0):
        for side in (-1, 1):
            x0, x1 = sorted((side * RIB_HX, side * (RIB_HX + 0.04)))
            z = -RIB_HZ + 0.75
            while z < RIB_HZ - 0.5:
                y = RIB_TOP - 0.25
                block(rib, (x0, y - 0.06, z - 0.06), (x1, y + 0.06, z + 0.06), IRON_HI)
                z += 1.5
            for k in range(n + 1):
                z = max(-RIB_HZ + 0.12, min(RIB_HZ - 0.12, -RIB_HZ + k * RIB_BAY))
                y = RIB_FLANGE + 1.2
                while y < RIB_TOP - RIB_FLANGE - 0.5:
                    block(rib, (x0, y - 0.06, z - 0.06), (x1, y + 0.06, z + 0.06), IRON_HI)
                    y += 2.4
    rib.to_object(parent=root)


TRAM_Z = (-12.8, 6.6)
TRAM_HX = 12.0
TRAM_GAUGE = 1.0


def tram_top(z):
    return 3.0 - 0.05 * z


def tram_head(root, rng):
    deck = common.Part("isle_tram_head")
    z = TRAM_Z[0]
    k = 0
    while z < TRAM_Z[1] - 0.1:
        z1 = min(z + 0.9, TRAM_Z[1])
        trim0, trim1 = rng.uniform(0.0, 0.6), rng.uniform(0.0, 0.6)
        tone = (TIMBER, TIMBER_DK, TIMBER_LT)[k % 3]
        sloped(deck, -TRAM_HX + trim0, TRAM_HX - trim1, z + 0.02, z1 - 0.02, tram_top, -0.08, 0.04, shade(tone, rng, 0.08))
        z = z1
        k += 1
    with deck.region(bevel=0.01):
        for x in (-TRAM_GAUGE, TRAM_GAUGE):
            sloped(deck, x - 0.08, x + 0.08, TRAM_Z[0] + 0.3, TRAM_Z[1] - 0.2, tram_top, 0.0, FLUSH, IRON)
    zb = TRAM_Z[0] + 0.15
    sloped(deck, -TRAM_GAUGE - 0.7, TRAM_GAUGE + 0.7, zb, zb + 0.5, tram_top, 0.0, FLUSH, shade(TIMBER_DK, rng))
    for x in (-TRAM_GAUGE, TRAM_GAUGE):
        sloped(deck, x - 0.25, x + 0.25, zb + 0.05, zb + 0.45, tram_top, FLUSH - 0.02, FLUSH, IRON_HI)
    for k in range(9):
        x = -TRAM_GAUGE - 1.6 + k * 0.4
        sloped(deck, x, x + 0.2, zb + 0.7, zb + 1.3, tram_top, 0.0, 0.045, HAZARD if k % 2 == 0 else BONE)
    wx, wz = -5.5, TRAM_Z[0] + 1.4
    sloped(deck, wx - 0.9, wx + 0.9, wz - 0.7, wz + 0.7, tram_top, 0.0, 0.07, IRON)
    deck.ring(SLOT, 0.3, 0.55, 0.05, segs=12, loc=g(wx, tram_top(wz) + 0.06, wz), color=RUST)
    deck.to_object(parent=root)


ADIT_SETS = (-13.5, -9.5, -5.5)
ADIT_POST_X = 9.5
ADIT_POST = 0.55
ADIT_CAP = (7.0, 7.7)
ADIT_HZ = 15.0
ADIT_TRACK = 1.0
LANE_HX = 7.0
ADIT_COL = "isle_adit_portal-col-col"


def adit_floor(z):
    return 0.0127 - 0.2625 * z


def adit_portal(root, rng):
    adit = common.Part("isle_adit_portal")
    for k, z in enumerate(ADIT_SETS):
        base = adit_floor(z)
        for s in (-1, 1):
            x0, x1 = sorted((s * (ADIT_POST_X - ADIT_POST / 2), s * (ADIT_POST_X + ADIT_POST / 2)))
            block(adit, (x0, base - 0.4, z - ADIT_POST / 2), (x1, base + ADIT_CAP[0], z + ADIT_POST / 2),
                  shade(TIMBER_DK if k % 2 else TIMBER, rng))
            for j in range(3):
                r = rng.uniform(0.45, 0.8)
                rx, rz = rng.uniform(0.2, 0.9), z + rng.uniform(-0.9, 0.9)
                adit.ico(SLOT, r, subdiv=1, loc=g(s * (ADIT_POST_X + rx), adit_floor(rz + r) + FLUSH - 0.02 - 0.6 * r, rz),
                         scale=(1.0, 1.0, 0.6), color=shade(STONE, rng, 0.1))
        block(adit, (-ADIT_POST_X - 0.6, base + ADIT_CAP[0], z - 0.32), (ADIT_POST_X + 0.6, base + ADIT_CAP[1], z + 0.32),
              shade(TIMBER, rng))
    for z in ADIT_SETS:
        base = adit_floor(z)
        for s in (-1, 1):
            post = s * (ADIT_POST_X - ADIT_POST / 2)
            adit.beam(SLOT, g(post, base + ADIT_CAP[0] - 1.8, z), g(post - s * 1.8, base + ADIT_CAP[0], z), 0.3, 0.3,
                      color=shade(TIMBER_DK, rng))
    for s in (-1, 1):
        xo = s * (ADIT_POST_X + ADIT_POST / 2)
        x0, x1 = sorted((xo, xo + s * 0.12))
        j = 0
        lo = 4.5
        while lo < ADIT_CAP[0] - 0.05:
            hi = min(lo + 0.36, ADIT_CAP[0])
            sloped(adit, x0, x1, ADIT_SETS[0] - 0.25, ADIT_SETS[-1] + 0.25, adit_floor, lo + 0.02, hi,
                   shade(TIMBER if j % 2 else TIMBER_DK, rng, 0.08))
            lo = hi
            j += 1
    za, zb = ADIT_SETS[0] - 0.5, ADIT_SETS[-1] + 0.4
    x = -ADIT_POST_X
    k = 0
    while x < ADIT_POST_X - 0.05:
        w = min(0.62, ADIT_POST_X - x)
        lift = rng.uniform(0.0, 0.05)
        sloped(adit, x + 0.03, x + w - 0.03, za + rng.uniform(0, 0.25), zb - rng.uniform(0, 0.25), adit_floor,
               ADIT_CAP[1] + lift, ADIT_CAP[1] + 0.14 + lift, shade(TIMBER_LT if k % 2 else TIMBER_DK, rng, 0.08))
        x += w
        k += 1
    zf = ADIT_SETS[-1] + 0.32
    yb = adit_floor(ADIT_SETS[-1]) + ADIT_CAP[0]
    block(adit, (-0.75, yb + 0.06, zf), (0.75, yb + 0.64, zf + 0.06), BONE)
    stencil(adit, 0.0, yb + 0.06, yb + 0.64, zf + 0.06, "07", 1)
    ly = yb - 0.05
    with adit.region(bevel=0):
        for j in range(2):
            block(adit, (-0.04, ly - 0.25 * (j + 1), zf - 0.36), (0.04, ly - 0.25 * j - 0.03, zf - 0.28), IRON)
    adit.cyl(SLOT, 0.22, 0.28, 0.5, segs=10, loc=g(0.0, ly - 0.75, zf - 0.32), color=COPPER)
    adit.cyl(SLOT, 0.16, 0.16, 0.3, segs=10, loc=g(0.0, ly - 1.1, zf - 0.32), color="e5a044")
    adit_collider(root)
    z = -ADIT_HZ + 0.4
    while z < ADIT_HZ - 0.3:
        sloped(adit, -ADIT_TRACK - 0.9, ADIT_TRACK + 0.9, z - 0.11, z + 0.11, adit_floor, -0.09, 0.05,
               shade(TIMBER_DK, rng, 0.1))
        z += 1.4
    with adit.region(bevel=0.01):
        for xr in (-ADIT_TRACK, ADIT_TRACK):
            sloped(adit, xr - 0.07, xr + 0.07, -ADIT_HZ + 0.2, ADIT_HZ - 0.2, adit_floor, 0.0, 0.11, IRON)
    adit.to_object(parent=root)


def adit_collider(root):
    """The portal's own collider (ADIT_COL): a box on each post and a slab on each side's lagging, so the uprights the
    ball can reach are solid. Every face stands outside the 14 m lane (|x| >= ADIT_POST_X - ADIT_POST / 2); the row's
    own collider (none: its stamp replaces the box) is untouched, because park_recipes.gd puts this mesh on a separate
    PieceCollider body, not the row's Collider."""
    verts, faces = [], []

    def add(corners):
        o = len(verts)
        verts.extend(g(*c) for c in corners)
        faces.extend([(o + 3, o + 2, o + 1, o), (o + 4, o + 5, o + 6, o + 7)])
        faces.extend((o + k, o + (k + 1) % 4, o + 4 + (k + 1) % 4, o + 4 + k) for k in range(4))

    for z in ADIT_SETS:
        base = adit_floor(z)
        for s in (-1, 1):
            x0, x1 = sorted((s * (ADIT_POST_X - ADIT_POST / 2), s * (ADIT_POST_X + ADIT_POST / 2)))
            y0, y1, z0, z1 = base - 0.4, base + ADIT_CAP[0], z - ADIT_POST / 2, z + ADIT_POST / 2
            add([(x0, y0, z0), (x1, y0, z0), (x1, y0, z1), (x0, y0, z1),
                 (x0, y1, z0), (x1, y1, z0), (x1, y1, z1), (x0, y1, z1)])
    za, zb = ADIT_SETS[0] - 0.25, ADIT_SETS[-1] + 0.25
    a0, a1 = adit_floor(za), adit_floor(zb)
    for s in (-1, 1):
        x0, x1 = sorted((s * (ADIT_POST_X + ADIT_POST / 2), s * (ADIT_POST_X + ADIT_POST / 2 + 0.12)))
        add([(x0, a0 + 4.5, za), (x1, a0 + 4.5, za), (x1, a1 + 4.5, zb), (x0, a1 + 4.5, zb),
             (x0, a0 + ADIT_CAP[0], za), (x1, a0 + ADIT_CAP[0], za), (x1, a1 + ADIT_CAP[0], zb), (x0, a1 + ADIT_CAP[0], zb)])
    mesh = bpy.data.meshes.new(ADIT_COL)
    mesh.from_pydata(verts, [], faces)
    mesh.update()
    obj = bpy.data.objects.new(ADIT_COL, mesh)
    bpy.context.scene.collection.objects.link(obj)
    obj.parent = root


RECIPES = {
    "isle_keel_rib": (keel_rib, 3101, "landform"),
    "isle_tram_head": (tram_head, 3111, "landform"),
    "isle_adit_portal": (adit_portal, 3121, "park_large"),
}


def bounds(root, skip=()):
    lo = Vector((math.inf,) * 3)
    hi = Vector((-math.inf,) * 3)
    for o in common.tree(root):
        if o.type != "MESH" or o in skip:
            continue
        for v in o.data.vertices:
            p = o.matrix_world @ v.co
            lo = Vector(map(min, lo, p))
            hi = Vector(map(max, hi, p))
    return (lo.x, lo.z, -hi.y), (hi.x, hi.z, -lo.y)


def build(rid, out_dir, count_only):
    fn, seed, cls = RECIPES[rid]
    common.reset()
    common.SLOTS[SLOT] = {"vc": True, "rough": 0.87}
    polish.enable(detail=1, bevel=0.04, bevel_min=0.2, bake_slots=(SLOT,))
    root = common.empty(rid + "_root")
    fn(root, random.Random(seed))
    cols = [o for o in common.tree(root) if "-col" in o.name]
    tris = common.tri_total(root)
    lo, hi = bounds(root, skip=cols)
    cap = CLASSES[cls]
    print("ISLE_COUNT", rid, json.dumps({"tris": tris, "class": cls, "cap": cap["tris"],
                                         "bounds": [[round(v, 3) for v in lo], [round(v, 3) for v in hi]]}))
    assert tris <= cap["tris"], (rid, tris, cap["tris"])
    for o in common.tree(root):
        if o.type != "MESH" or o in cols:
            continue
        for v in o.data.vertices:
            p = o.matrix_world @ v.co
            x, y, z = p.x, p.z, -p.y
            if rid == "isle_tram_head":
                assert y - tram_top(z) <= FLUSH + 1e-3, (rid, "over FLUSH", (x, y, z))
            elif rid == "isle_adit_portal" and abs(x) < LANE_HX + 1.0:
                up = y - adit_floor(z)
                assert up <= FLUSH + 1e-3 or up >= CLEAR_ABOVE, (rid, "in the lane between FLUSH and CLEAR_ABOVE", (x, y, z))
    if rid == "isle_adit_portal":
        assert [o.name for o in cols] == [ADIT_COL], (rid, [o.name for o in cols])
        inner = min(abs((o.matrix_world @ v.co).x) for o in cols for v in o.data.vertices)
        assert inner >= ADIT_POST_X - ADIT_POST / 2 - 1e-4, (rid, "the portal's collider stands outside the lane", inner)
    else:
        assert not cols, (rid, "no -col: the row's greybox collider is the only one")
    if rid == "isle_keel_rib":
        assert abs(lo[0] + RIB_HX) < 0.06 and abs(hi[0] - RIB_HX) < 0.06, (rid, "x faces at the box", lo, hi)
        assert abs(hi[1] - RIB_TOP) < 1e-3 and abs(lo[2] + RIB_HZ) < 1e-3 and abs(hi[2] - RIB_HZ) < 1e-3, (rid, lo, hi)
    if count_only:
        return
    path = os.path.join(out_dir, rid + ".glb")
    common.export(root, path)
    print("ISLE_EXPORT", rid, json.dumps({"file": os.path.basename(path), "tris": tris,
                                          "sha256": hashlib.sha256(open(path, "rb").read()).hexdigest()}))


def main():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    parser = argparse.ArgumentParser()
    parser.add_argument("--out-dir", default=MODELS)
    parser.add_argument("--recipe", action="append", choices=sorted(RECIPES))
    parser.add_argument("--count-only", action="store_true")
    args = parser.parse_args(argv)
    for rid in args.recipe or sorted(RECIPES):
        build(rid, args.out_dir, args.count_only)


main()
