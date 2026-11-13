"""Headless recipes for the six hero landmarks of the park stages (design-v3/park/LANDMARK-CARDS.md, the hero_landmark
budget class): landmark_dam, landmark_penstock_tower, landmark_headframe, landmark_sinkhole, landmark_sky_island and
landmark_spire. Each writes five GLBs: <id>.glb (base, with the <id>-col trimesh and the named empties),
<id>_detail1.glb and <id>_detail2.glb (detail shells, one draw each), <id>_mid.glb and <id>_far.glb (the hero_landmark
mid and far views park_recipes.gd paths() names). landmark_sky_island also writes landmark_sky_island_tip.glb: the
moving tip's collider alone, which nothing loads until the isle's tilt drives it (ISLE-TIP).

Convention (LANDMARK-CARDS.md section 1): +Y up, metres, origin at the footprint centre on each card's y datum, local +Z
the side facing the arriving player; the stage's landmark row turns it by yaw_deg. Each builder is written in that local
frame; FRAMES holds each row's at, y datum and yaw so a builder can place a part from world coordinates (Frame.local).
The row numbers come from src/world/park/<map>.json; the terrain numbers come from the stage bake at
assets/park/<map>/ground.bin (sampled 2026-10-17, read with a GCPF/zstd reader), and each builder names the ones it
fits to. Storyboard rulings (design-v3/park/storyboards/DECISIONS.md, Andrew 2026-10-16) override the cards: the
headframe legs are solid to the ground, the sinkhole gallery is a full ring, the spire has a 30 m waist to 60 m and
the Hanging Isle's tip is a moving harpoon anchor. Wave 15 (PW1) lowered the stage 5 hand to y 66, so the isle hangs
the hand from its tip on a tether.

Files: the base GLB holds one drawn mesh named <id> (one surface per material slot, at most 6), separate drawn nodes
where a part moves (the dam's gate_l and gate_r, origin on their hinges; the isle's tether, origin on the tip), the
"<id>-col-col" trimesh (Godot strips one -col, so it imports as <id>-col; park_recipes.gd makes it the trimesh and never
draws it) and the empties sight_top, beam_root, warden_anchor, hp_0..hp_2 and each card's extras. Surfaces are named
by runtime material slots; the resource slots (enamel, steel, stone, elastomer, glass) take their material from
src/presentation/material_slots.gd at placement and every vertex carries its colour; ancient_lens keeps its exported
emissive uranium-glass green #9dff3c. No light nodes. Palette: dam-era concrete, black iron, copper #b77843 for
machinery (never brass), basalt and limestone, red and cream slickrock, desert varnish.

Real-culture guardrail (PARK.md section 4): every landmark is dam-era, mining, natural, ancient or Fleet work; nothing
here names or imitates a living people's work.

Soft toy (Andrew, 18 Oct): the base GLB and the detail shells run through the polish toolkit's bevel, smooth shading and AO/edge-wear
bake (the SOFT adapter below; tools/blender/POLISH.md). Those meshes carry a zeroed first UV map (UVMap) and the toolkit's second
map (Bake: x unoccluded fraction, y wear); the -col meshes, the mid and far views and the isle tip stay unpolished and map-free.

  blender -b --threads 2 --python-exit-code 1 -P sketches/core-loop/tools/blender/park/landmarks.py -- \
      [--out-dir DIR] [--only landmark_dam,...] [--count-only]
"""
import argparse
import hashlib
import json
import math
from pathlib import Path
import sys

import bmesh
import bpy

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE.parent))
sys.path.insert(0, str(HERE))
import common
import polish
import skyislands as sky

SKETCH = HERE.parents[2]
MODELS = SKETCH / "assets/models/park"
CLASSES = json.loads((SKETCH / "assets/asset_budgets.json").read_text())["classes"]
HERO, DETAIL = CLASSES["hero_landmark"], CLASSES["detail"]
SLOTS = ("enamel", "steel", "stone", "elastomer", "glass", "ancient_lens")
TAU = math.tau
UP = (0.0, 1.0, 0.0)
FLUSH = 0.12        # the most a part with no collider may stand over a surface a ball rolls on
CLEAR = 8.0         # no landmark geometry this close to warden_anchor except the card's cradle (card section 1)

HEX = {
    "concrete": "8f8b82", "concrete_lt": "a8a398", "concrete_dk": "706c65", "joint": "5c5a54", "patch": "9a9488",
    "stain": "4a4038", "iron": "2b2724", "iron_hi": "3d3732", "steel": "4f4c48", "copper": "b77843", "copper_dk": "8d5a32",
    "oxide": "9b513a", "rust": "7a4430", "timber": "7a5a3d", "timber_dk": "5a4230", "timber_lt": "8c6d4c",
    "basalt": "57504b", "basalt_dk": "3b3633", "lime": "e6dccb", "lime_dk": "c9bba1", "ochre": "c9a066",
    "calcite": "f2eee6", "mangan": "6a5f58", "verdigris": "8fa38a", "varnish": "3a2e29", "slick_red": "a9553a",
    "deep_red": "7d3a2a", "cream": "e3d3ad", "sandstone": "c6a274", "caprock": "4a3a33", "bone": "d2c5a5",
    "cable": "34312e", "amber": "e5a044", "water": "bfe3ea", "mist": "e9f2ef", "fulgurite": "dfe9e6", "lens": "9dff3c",
    "sage": "6b7a4e", "pine": "3f5238", "juniper": "4b5c3e",
}


def col(name):
    return common.srgb(HEX.get(name, name))


def lerp(a, b, t):
    return tuple(a[i] + (b[i] - a[i]) * t for i in range(3))


def shade(name, k, seed, amount=0.08):
    """A colour with a deterministic brightness wobble, so repeated panels do not read as one flat sheet."""
    c = col(name)
    f = 1.0 + (sky.rnd(*seed) - 0.5) * 2 * amount
    return tuple(max(0.0, min(1.0, x * f * k)) for x in c)


rnd = sky.rnd


# ---------------------------------------------------------------- vector kit (Godot space, metres)
def vadd(a, b, k=1.0):
    return (a[0] + b[0] * k, a[1] + b[1] * k, a[2] + b[2] * k)


def vsub(a, b):
    return (a[0] - b[0], a[1] - b[1], a[2] - b[2])


def vscale(a, k):
    return (a[0] * k, a[1] * k, a[2] * k)


def vlerp(a, b, t):
    return (a[0] + (b[0] - a[0]) * t, a[1] + (b[1] - a[1]) * t, a[2] + (b[2] - a[2]) * t)


def vlen(a):
    return math.sqrt(sky.dot(a, a))


def frame(d):
    """Two unit vectors across the unit direction d; the second leans up where it can."""
    ref = UP if abs(d[1]) < 0.95 else (1.0, 0.0, 0.0)
    u = sky.norm(sky.cross(d, ref))
    return u, sky.norm(sky.cross(u, d))


class Frame:
    """A landmark row's place: at [x, z], the y datum and yaw_deg, as park_recipes.gd row_transform builds it."""

    def __init__(self, at, y, yaw_deg):
        self.ax, self.az, self.y = float(at[0]), float(at[1]), float(y)
        self.c, self.s = math.cos(math.radians(yaw_deg)), math.sin(math.radians(yaw_deg))

    def local(self, x, y, z):
        dx, dz = x - self.ax, z - self.az
        return (dx * self.c - dz * self.s, y - self.y, dx * self.s + dz * self.c)

    def world(self, x, y, z):
        return (self.ax + x * self.c + z * self.s, y + self.y, self.az - x * self.s + z * self.c)

    def dir_local(self, x, z):
        return (x * self.c - z * self.s, 0.0, x * self.s + z * self.c)


FRAMES = {
    "landmark_dam": Frame((0, 620), 0.0, 180.0),
    "landmark_penstock_tower": Frame((270, 510), 0.0, 31.0),
    "landmark_headframe": Frame((0, 255), -100.0, 180.0),
    "landmark_sinkhole": Frame((0, 350), 0.0, 0.0),
    "landmark_sky_island": Frame((0, 520), 200.0, 0.0),
    "landmark_spire": Frame((0, 470), -12.0, 0.0),
}


# ---------------------------------------------------------------- solids on a sky.Surf
def circle(c, r, y, n, spin=0.0):
    """n points on a horizontal circle about (c[0], c[1]); bearing 0 is +Z, turning toward +X."""
    return [(c[0] + r * math.sin(spin + TAU * i / n), y, c[1] + r * math.cos(spin + TAU * i / n)) for i in range(n)]


def frustum(s, c, r0, r1, y0, y1, n, color, caps=(True, True), spin=0.0):
    s.ring_solid(circle(c, r0, y0, n, spin), circle(c, r1, y1, n, spin), color, caps)


def box(s, lo, hi, color):
    (x0, y0, z0), (x1, y1, z1) = lo, hi
    s.ring_solid([(x0, y0, z0), (x1, y0, z0), (x1, y0, z1), (x0, y0, z1)],
                 [(x0, y1, z0), (x1, y1, z0), (x1, y1, z1), (x0, y1, z1)], color)


def obox(s, c, half, axes, color):
    """A box about centre c with half extents along the three unit axes (ax, ay, az)."""
    ax, ay, az = axes
    ring = []
    for sy in (-1, 1):
        ring.append([vadd(vadd(vadd(c, ax, sx * half[0]), ay, sy * half[1]), az, sz * half[2])
                     for sx, sz in ((-1, -1), (1, -1), (1, 1), (-1, 1))])
    s.ring_solid(ring[0], ring[1], color)


def yawed(yaw):
    c, n = math.cos(yaw), math.sin(yaw)
    return ((c, 0.0, -n), UP, (n, 0.0, c))


def beam(s, a, b, w, h, color, caps=True):
    """A rectangular bar from a to b, w across and h up."""
    d = sky.norm(vsub(b, a))
    u, v = frame(d)
    ring = lambda p: [vadd(vadd(p, u, x * w / 2), v, y * h / 2) for x, y in ((-1, -1), (1, -1), (1, 1), (-1, 1))]
    s.ring_solid(ring(a), ring(b), color, (caps, caps))


def tube(s, a, b, r, n, color, r2=None, caps=True):
    d = sky.norm(vsub(b, a))
    u, v = frame(d)
    ring = lambda p, rr: [vadd(vadd(p, u, rr * math.cos(TAU * i / n)), v, rr * math.sin(TAU * i / n)) for i in range(n)]
    s.ring_solid(ring(a, r), ring(b, r if r2 is None else r2), color, (caps, caps))


def wheel(s, centre, axis, radius, rim, spokes, segs, color, hub_color):
    """A spoked wheel in the plane across the unit axis: a rim of segs bars, spokes and a hub drum."""
    u, v = frame(axis)
    pt = lambda a, r: vadd(vadd(centre, u, r * math.cos(a)), v, r * math.sin(a))
    for i in range(segs):
        a0, a1 = TAU * i / segs, TAU * (i + 1) / segs
        beam(s, pt(a0, radius - rim / 2), pt(a1, radius - rim / 2), rim, rim, color, caps=False)
    for i in range(spokes):
        a = TAU * (i + 0.5) / spokes
        beam(s, pt(a, rim), pt(a, radius - rim), rim * 0.45, rim * 0.45, color, caps=False)
    tube(s, vadd(centre, axis, -0.7), vadd(centre, axis, 0.7), max(rim * 1.4, 0.5), 8, hub_color)


def annulus(s, c, r0, r1, y0, y1, n, color_fn, arc=None, sides=True):
    """A flat ring of n cells from radius r0 to r1, its top at y1; arc=(a0, a1) keeps a sector (bearings)."""
    a0, a1 = arc if arc else (0.0, TAU)
    p = lambda r, t, y: (c[0] + r * math.sin(t), y, c[1] + r * math.cos(t))
    for i in range(n):
        t0, t1 = a0 + (a1 - a0) * i / n, a0 + (a1 - a0) * (i + 1) / n
        cc = color_fn(i)
        s.poly([p(r0, t0, y1), p(r1, t0, y1), p(r1, t1, y1), p(r0, t1, y1)], cc, up=UP)
        if sides:
            mid = p((r0 + r1) / 2, (t0 + t1) / 2, (y0 + y1) / 2)
            s.poly([p(r1, t0, y0), p(r1, t1, y0), p(r1, t1, y1), p(r1, t0, y1)], cc, inside=mid)
            s.poly([p(r0, t0, y0), p(r0, t1, y0), p(r0, t1, y1), p(r0, t0, y1)], cc, inside=mid)


def slab(s, outline, y0, y1, color, top_color=None):
    """A prism over a convex outline [(x, z)] from y0 to y1."""
    lo = [(x, y0, z) for x, z in outline]
    hi = [(x, y1, z) for x, z in outline]
    mid = (sum(x for x, _ in outline) / len(outline), (y0 + y1) / 2, sum(z for _, z in outline) / len(outline))
    n = len(outline)
    for i in range(n):
        j = (i + 1) % n
        s.poly([lo[i], lo[j], hi[j], hi[i]], color, inside=mid)
    s.poly(hi, top_color or color, inside=mid)
    s.poly(lo, color, inside=mid)


def card(s, corners, color, normal):
    """One flat quad facing normal (a decal laid on a wall or floor)."""
    s.poly(list(corners), color, up=normal)


def lattice(s, a, b, wa, wb, panels, color, chord=0.5, lace=0.22):
    """A four-chord lattice leg from a to b, half width wa at a and wb at b, laced in alternating diagonals."""
    d = sky.norm(vsub(b, a))
    u, v = frame(d)
    signs = ((-1, -1), (1, -1), (1, 1), (-1, 1))

    def corner(t, i):
        w = wa + (wb - wa) * t
        return vadd(vadd(vlerp(a, b, t), u, signs[i][0] * w), v, signs[i][1] * w)

    for i in range(4):
        beam(s, corner(0.0, i), corner(1.0, i), chord, chord, color)
    for k in range(panels):
        t0, t1 = k / panels, (k + 1) / panels
        for i in range(4):
            j = (i + 1) % 4
            if (k + i) % 2 == 0:
                beam(s, corner(t0, i), corner(t1, j), lace, lace, color, caps=False)
            else:
                beam(s, corner(t0, j), corner(t1, i), lace, lace, color, caps=False)
            if k % 2 == 1:
                beam(s, corner(t1, i), corner(t1, j), lace, lace, color, caps=False)


def hexcell(s, c, normal, r, depth, color, rim=None, open_end=False):
    """A six-sided cell standing out of a wall along normal; rim paints the mouth ring a second colour (a second Surf)."""
    u, v = frame(normal)
    base = [vadd(vadd(c, u, r * math.cos(TAU * i / 6 + 0.5)), v, r * math.sin(TAU * i / 6 + 0.5)) for i in range(6)]
    top = [vadd(p, normal, depth) for p in base]
    s.ring_solid(base, top, color, (False, not open_end))
    if rim is not None:
        surf, rim_color = rim
        inner = [vadd(vlerp(p, vadd(c, normal, depth), 0.25), normal, 0.02) for p in top]
        lip = [vadd(p, normal, 0.02) for p in top]
        for i in range(6):
            j = (i + 1) % 6
            surf.poly([lip[i], lip[j], inner[j], inner[i]], rim_color, up=normal)


# ---------------------------------------------------------------- one view of a landmark
class View:
    """The drawn parts of one GLB view, one sky.Surf per material slot, merged into one mesh at export."""

    def __init__(self, name):
        self.name = name
        self.parts = {}

    def __getitem__(self, slot):
        assert slot in SLOTS, slot
        if slot not in self.parts:
            self.parts[slot] = sky.Surf("%s:%s" % (self.name, slot))
        return self.parts[slot]

    def surfs(self):
        return [(self.parts[k], k) for k in SLOTS if k in self.parts and self.parts[k].t]

    def tris(self):
        return sum(len(s.t) for s, _ in self.surfs())

    def absorb(self, other):
        for s, slot in other.surfs():
            dst = self[slot]
            base = len(dst.v)
            dst.v += s.v
            dst.c += s.c
            dst.t += [(a + base, b + base, c + base) for a, b, c in s.t]


def verts_of(views):
    for view in views:
        if isinstance(view, View):
            for s, _ in view.surfs():
                yield from s.v
        else:
            yield from view.v


# ================================================================ card 1: the spillway dam (park_dam)
# Bake fit (assets/park/park_dam): the dam_face_quarter stamp is a straight ramp, y = 1.2 * (5 - z) from local z 5
# (y 0) to z -20 (y 30), then a near-vertical cliff from z -20 (y 30) to z -22 (y 100) under the plateau at 100, across
# x -200..200 (the canyon walls). A wall curved in plan below the plateau would float over the ridden ramp or sink into
# the cliff, so the lower face is straight and clads the cliff (DAM_FACE_Z, in front of every cliff point), and the
# arch is the upper wall standing on the plateau, bowed 25 m upstream at the centre. Its front stays behind the
# crest_rail row (local z -36, the ridge stamp at 100.75), so the rail's drop down the face stays open. The data's
# warden anchor [0, 22, 590] is local (0, 22, 30), out over the toe apron: the cradle is a concrete halo hung from a steel
# jib crane cantilevered off the face, ringing the relic in its own plane, with hp_1 and hp_2 on the halo. White water
# spills from under the radial gates down the face and the ramp (enamel dressing, no collider).
DAM_FACE_Z = -19.94
DAM_RAMP_TOP = 30.0
DAM_PLATEAU = 100.0
DAM_CHORD = 160.0           # half chord of the arch
DAM_CANYON = 200.0          # half width of the canyon the face spans
DAM_CREST = 121.0
DAM_TOWER = (12.0, 24.0)    # inner and outer |x| of the gate towers: inner faces 24 m apart, the reactor's SHEET_WIDTH
DAM_TOWER_Z = (-27.0, -15.0)
DAM_TOP = 141.0
DAM_ANCHOR = (0.0, 22.0, 30.0)
DAM_HINGE = (44.0, -8.0)    # the radial gates' trunnion axis (y, z)
DAM_GATE_R = 11.5
DAM_HALO = (8.6, 11.2, 2.2)  # inner radius, outer radius, depth
DAM_JIB_TIP = (0.0, 44.0, 30.0)  # the crane's tip, 22 m over the relic


def dam_ramp_y(z):
    return max(0.0, min(DAM_RAMP_TOP, 1.2 * (5.0 - z)))


def dam_arch_z(x):
    """The upper arch's front face: 46 m behind the face line at the abutments, 71 m at the crown."""
    return -46.0 - 25.0 * (1.0 - (x / DAM_CHORD) ** 2)


def arch_pieces(x, z, thick):
    """The upper arch's cross-section at x as drawn, in convex pieces (a ring_solid winds each face away from its piece's
    centre, so a concave ring turns faces inward): the body from 99 m to the crest deck at DAM_CREST, and the two
    parapets (0.6 m wide, 1.2 m tall) on its edges."""
    top, cap = DAM_CREST, DAM_CREST + 1.2
    return [[(x, 99.0, z), (x, top, z), (x, top, z - thick), (x, 99.0, z - thick)],
            [(x, top, z), (x, cap, z), (x, cap, z - 0.6), (x, top, z - 0.6)],
            [(x, top, z - thick + 0.6), (x, cap, z - thick + 0.6), (x, cap, z - thick), (x, top, z - thick)]]


def dam_course(row, colm):
    """One cast lift: each 16 m monolith keeps its own tone, the lifts in it vary only slightly."""
    return shade("concrete_lt" if rnd(colm, 5) > 0.5 else "concrete", 1.0 + 0.04 * (rnd(colm, 6) - 0.5), (row, colm, 3), 0.025)


def dam_gate(name, x0, x1):
    """One radial gate leaf: skin plate, ribs and two arms on the trunnion; landmark-local vertices (the node's origin is the hinge)."""
    v = View(name)
    hy, hz = DAM_HINGE
    hx = (x0 + x1) / 2
    steps = 8
    th = 0.62
    pts = [(-th + 2 * th * k / steps) for k in range(steps + 1)]
    skin = lambda x, t, dr=0.0: (x, hy + (DAM_GATE_R + dr) * math.sin(t), hz - (DAM_GATE_R + dr) * math.cos(t))
    hub = (hx, hy, hz)
    for k in range(steps):
        t0, t1 = pts[k], pts[k + 1]
        c = shade("iron_hi", 1.0, (k, int(x0)), 0.06)
        v["steel"].poly([skin(x0, t0), skin(x1, t0), skin(x1, t1), skin(x0, t1)], c, inside=(hx, hy, hz - 50.0))
        v["steel"].poly([skin(x0, t0, 0.35), skin(x0, t1, 0.35), skin(x1, t1, 0.35), skin(x1, t0, 0.35)], col("iron"),
                        inside=hub)
    for t in pts[::2]:
        beam(v["steel"], skin(x0, t, 0.2), skin(x1, t, 0.2), 0.5, 0.6, col("iron"))
    for x in (x0 + 0.5, x1 - 0.5):
        for t in (-th, th):
            beam(v["steel"], skin(x, t, 0.3), (x, hy, hz), 0.7, 0.9, col("iron"))
        tube(v["steel"], (x - 0.6, hy, hz), (x + 0.6, hy, hz), 0.9, 10, col("copper"))
    return v


# The dam's look (W1-25, Andrew's taste pick of 13 Nov under ruling cq): a weathered cast face (graded lifts, monolith
# tones, calcite leach and varnish streaks, a wet band by the spill) with its structure drawn, ribs at 40 m with the bays
# between them set back BAY_DEPTH (never forward: the face's collider stays where it is, so a ball can only stand off a
# bay, never sink into one) under a lintel band carrying the Fleet's claim, and the crew's chalk answer low on the face
# by the yard (STORY-MAP.md, The Spillway).
DAM_RIBS = (-168.0, -128.0, -88.0, -48.0, 48.0, 88.0, 128.0, 168.0)   # rib centres; +-168 are the collided pilasters
DAM_RIB_W = 6.0
BAY_DEPTH = 1.0
BAY_TOP = 88.0
BAY_FOOT = 36.0       # each bay keeps a flush plinth up to here, then a batter slopes back to the set-back face at BAY_SILL:
BAY_SILL = 64.0       # the bake's cliff (z -20 at y 30 to z -22 at y 100) stands in front of a 1 m set-back until y 62.9, so
                      # a bay set back from the ramp top showed bare rock along its foot (review of W1-25)
DAM_CLAIM = "ALL WATER IS NOW INVENTORY"
DAM_CHALK = "Tell the river."


def dam_tone(i):
    """A monolith's own tone: three pours, warm, mid and pale, in a seeded order."""
    r = rnd(i, 91)
    base = col("concrete_lt") if r > 0.62 else (col("concrete") if r > 0.25 else lerp(col("concrete"), col("ochre"), 0.18))
    return tuple(max(0.0, min(1.0, x * (1.0 + 0.07 * (rnd(i, 92) - 0.5)))) for x in base)


def dam_lift(i, j):
    """One lift's two colours, bottom and top: each lift is darker at its cold joint and catches light at its top."""
    c = dam_tone(i)
    if rnd(i, j, 17) > 0.93:
        c = lerp(c, col("patch"), 0.6)
    c = vscale(c, 1.0 + 0.03 * (rnd(i, j, 4) - 0.5))
    return vscale(c, 0.76), vscale(c, 1.06)


def dam_spans():
    """The face across x in (x0, x1, kind): kind "rib" stands on the face line, "bay" is set back."""
    edges = [-DAM_CANYON]
    for r in DAM_RIBS:
        edges += [r - DAM_RIB_W / 2, r + DAM_RIB_W / 2]
    edges.append(DAM_CANYON)
    spans = []
    for k in range(len(edges) - 1):
        x0, x1 = edges[k], edges[k + 1]
        rib = k % 2 == 1
        if not rib and (x1 <= -DAM_CHORD - 10 or x0 >= DAM_CHORD + 10 or (x0 >= -50 and x1 <= 50)):
            rib = True        # abutment ends and the gate bay stay on the face line (the jib and trunnions bolt to it)
        spans.append((x0, x1, "rib" if rib else "bay"))
    return spans


def bay_z(fz, y):
    """A bay's face depth at height y: flush plinth, batter back to the set-back, the set-back, flush lintel."""
    if y <= BAY_FOOT or y >= BAY_TOP:
        return fz
    if y >= BAY_SILL:
        return fz - BAY_DEPTH
    return fz - BAY_DEPTH * (y - BAY_FOOT) / (BAY_SILL - BAY_FOOT)


def dam_face(e, fz):
    """The cast face from the ramp top (29.9) to the plateau lip, in lifts; returns the face depth function z(x, y)."""
    assert BAY_DEPTH >= 0.0 and 29.9 < BAY_FOOT < BAY_SILL < BAY_TOP   # bays only ever go back of the collided face
    rows = 20
    spans = dam_spans()
    for si, (x0, x1, kind) in enumerate(spans):
        set_back = kind == "bay"
        z = fz - (BAY_DEPTH if set_back else 0.0)
        n = max(1, int(round((x1 - x0) / 16.0)))
        for i in range(n):
            xa, xb = x0 + (x1 - x0) * i / n, x0 + (x1 - x0) * (i + 1) / n
            mono = int((xa + DAM_CANYON) // 16)
            for j in range(rows):
                y0 = 29.9 + (DAM_PLATEAU + 0.3 - 29.9) * j / rows
                y1 = 29.9 + (DAM_PLATEAU + 0.3 - 29.9) * (j + 1) / rows
                lo, hi = dam_lift(mono if kind == "bay" else 300 + si, j)
                if kind == "rib":
                    lo, hi = vscale(lo, 1.14), vscale(hi, 1.14)
                elif set_back:
                    lo, hi = vscale(lo, 0.8), vscale(hi, 0.84)
                if abs((xa + xb) / 2) > DAM_CHORD:
                    lo, hi = lerp(lo, col("concrete_dk"), 0.45), lerp(hi, col("concrete_dk"), 0.45)
                if not set_back:
                    e.poly([(xa, y0, z), (xb, y0, z), (xb, y1, z), (xa, y1, z)], [lo, lo, hi, hi], up=(0.0, 0.0, 1.0))
                    continue
                # a bay's lift splits where its profile bends (plinth, batter, set-back, lintel)
                ys = [y0] + [b for b in (BAY_FOOT, BAY_SILL, BAY_TOP) if y0 < b < y1] + [y1]
                for ya, yb in zip(ys, ys[1:]):
                    ca, cb = lerp(lo, hi, (ya - y0) / (y1 - y0)), lerp(lo, hi, (yb - y0) / (y1 - y0))
                    if yb > BAY_TOP + 0.01:
                        ca = cb = hi
                    za, zb = bay_z(fz, ya + 1e-6), bay_z(fz, yb - 1e-6)
                    e.poly([(xa, ya, za), (xb, ya, za), (xb, yb, zb), (xa, yb, zb)], [ca, ca, cb, cb], up=(0.0, 0.0, 1.0))
        if set_back:
            # the bay's reveals: its two sides (down to the batter) and its head under the lintel
            shadow = vscale(dam_tone(si), 0.34)
            for x, nx in ((x0, 1.0), (x1, -1.0)):
                e.poly([(x, BAY_FOOT, fz), (x, BAY_TOP, fz), (x, BAY_TOP, z), (x, BAY_SILL, z)], shadow, up=(nx, 0.0, 0.0))
            e.poly([(x0, BAY_TOP, fz), (x1, BAY_TOP, fz), (x1, BAY_TOP, z), (x0, BAY_TOP, z)], vscale(shadow, 0.8), up=(0.0, -1.0, 0.0))

    def depth(x, y):
        for x0, x1, kind in spans:
            if x0 <= x <= x1:
                return bay_z(fz, y) if kind == "bay" else fz
        return fz
    return depth


def dam_streak(s, depth, x, y_top, length, w_top, w_bot, c_top, c_bot, lift=0.04):
    """A tapered stain hanging down the face from (x, y_top): calcite leach or varnish, fading into the wall."""
    y_bot = max(29.95, y_top - length)
    z = depth(x, (y_top + y_bot) / 2) + lift
    s.poly([(x - w_bot / 2, y_bot, z), (x + w_bot / 2, y_bot, z), (x + w_top / 2, y_top, z), (x - w_top / 2, y_top, z)],
           [c_bot, c_bot, c_top, c_top], up=(0.0, 0.0, 1.0))


def dam_weather(e, depth):
    """Streaks on the face: varnish from the lip's drains, calcite under the lift joints, a wet band by the spill."""
    rows = 20
    band = dam_band()[0]
    for k in range(34):
        x = -DAM_CANYON + 3.0 + (2 * DAM_CANYON - 6.0) * (k + rnd(k, 51)) / 34
        if abs(x) < 26.0:
            continue
        if any(abs(x - r) < DAM_RIB_W / 2 + 0.8 for r in DAM_RIBS):
            continue
        wall = dam_lift(int((x + DAM_CANYON) // 16), rows - 1)[1]
        in_bay = depth(x, 70.0) != depth(x, 95.0)
        top = BAY_TOP - 0.05 if in_bay else (BAY_TOP + 1.35 if abs(x) < band else DAM_PLATEAU + 0.2)
        length = 10.0 + 42.0 * rnd(k, 53) ** 1.5
        if in_bay:
            length = min(length, top - BAY_SILL)
        dark = lerp(wall, col("varnish"), 0.55 + 0.3 * rnd(k, 52))
        w = 1.4 + 3.6 * rnd(k, 54)
        dam_streak(e, depth, x, top, length, w, w * (0.35 + 0.3 * rnd(k, 55)), dark, wall)
    for k in range(90):
        i, j = int(rnd(k, 61) * 25), 2 + int(rnd(k, 62) * (rows - 4))
        x = -DAM_CANYON + 16.0 * i + 1.0 + 14.0 * rnd(k, 63)
        if abs(x) < 26.0:
            continue
        y = 29.9 + (DAM_PLATEAU + 0.3 - 29.9) * j / rows
        if depth(x, 70.0) != depth(x, 95.0) and not (BAY_SILL + 12.6 < y < BAY_TOP - 0.2):
            continue
        if any(abs(x - r) < DAM_RIB_W / 2 + 0.6 for r in DAM_RIBS):
            continue
        wall = dam_lift(int((x + DAM_CANYON) // 16), j - 1)[1]
        pale = lerp(wall, col("calcite"), 0.55 + 0.3 * rnd(k, 64))
        w = 0.9 + 1.8 * rnd(k, 66)
        dam_streak(e, depth, x, y - 0.05, 2.5 + 10.0 * rnd(k, 65), w, w * 0.55, pale, wall, lift=0.05)
    for sx in (-1, 1):
        x0, x1 = sorted((sx * 11.4, sx * 17.0))
        wet = lerp(col("concrete"), col("stain"), 0.7)
        wall = dam_lift(12, 2)[1]
        e.poly([(x0, 29.95, DAM_FACE_Z + 0.06), (x1, 29.95, DAM_FACE_Z + 0.06), (x1, 46.0, DAM_FACE_Z + 0.06),
                (x0, 46.0, DAM_FACE_Z + 0.06)], [wet, wet, wall, wall],
               up=(0.0, 0.0, 1.0))


def dam_works(e, fz):
    """The outlet works low on the ribs (a dark adit with a steel frame) and the hoist houses' windows."""
    for r in DAM_RIBS:
        if abs(r) > DAM_CHORD:
            continue
        x0, x1 = r - 1.6, r + 1.6
        e.poly([(x0, 33.0, fz + 0.04), (x1, 33.0, fz + 0.04), (x1, 37.5, fz + 0.04), (x0, 37.5, fz + 0.04)], col("varnish"),
               up=(0.0, 0.0, 1.0))
        for a, b in (((x0 - 0.3, 32.7), (x1 + 0.3, 33.0)), ((x0 - 0.3, 37.5), (x1 + 0.3, 37.8)), ((x0 - 0.3, 33.0), (x0, 37.5)),
                     ((x1, 33.0), (x1 + 0.3, 37.5))):
            e.poly([(a[0], a[1], fz + 0.06), (b[0], a[1], fz + 0.06), (b[0], b[1], fz + 0.06), (a[0], b[1], fz + 0.06)],
                   col("iron_hi"), up=(0.0, 0.0, 1.0))
        wall = dam_lift(300, 1)[1]
        e.poly([(x0 + 0.4, 29.95, fz + 0.05), (x1 - 0.4, 29.95, fz + 0.05), (x1 - 0.4, 32.7, fz + 0.05), (x0 + 0.4, 32.7, fz + 0.05)],
               [lerp(wall, col("stain"), 0.6)] * 2 + [lerp(wall, col("stain"), 0.3)] * 2, up=(0.0, 0.0, 1.0))
    for sx in (-1, 1):
        x0, x1 = sorted((sx * DAM_TOWER[0], sx * DAM_TOWER[1]))
        zf = DAM_TOWER_Z[1] + 0.04
        for k in range(3):
            xa = x0 + 1.5 + k * (x1 - x0 - 3.0) / 3 + 0.4
            xb = xa + (x1 - x0 - 3.0) / 3 - 0.8
            e.poly([(xa, 131.0, zf), (xb, 131.0, zf), (xb, 136.5, zf), (xa, 136.5, zf)], col("iron"), up=(0.0, 0.0, 1.0))


def dam_face_flat(s, fz, lifts):
    """The face for the mid and far views: the same spans and tones as the base, flat, a bay drawn darker for its set-back."""
    for si, (x0, x1, kind) in enumerate(dam_spans()):
        n = max(1, int(round((x1 - x0) / (16.0 if lifts > 1 else 48.0))))
        for i in range(n):
            xa, xb = x0 + (x1 - x0) * i / n, x0 + (x1 - x0) * (i + 1) / n
            mono = int((xa + DAM_CANYON) // 16)
            for j in range(lifts):
                y0 = 29.9 + (DAM_PLATEAU + 0.3 - 29.9) * j / lifts
                y1 = 29.9 + (DAM_PLATEAU + 0.3 - 29.9) * (j + 1) / lifts
                lo, hi = dam_lift(mono if kind == "bay" else 300 + si, j * 20 // lifts)
                if kind == "bay":
                    lo, hi = vscale(lo, 0.7), vscale(hi, 0.76)
                else:
                    lo, hi = vscale(lo, 1.14), vscale(hi, 1.14)
                if abs((xa + xb) / 2) > DAM_CHORD:
                    lo, hi = lerp(lo, col("concrete_dk"), 0.45), lerp(hi, col("concrete_dk"), 0.45)
                s.poly([(xa, y0, fz), (xb, y0, fz), (xb, y1, fz), (xa, y1, fz)], [lo, lo, hi, hi], up=(0.0, 0.0, 1.0))
    half = dam_band()[0]
    for k in range(18):
        x = -DAM_CANYON + 10.0 + (2 * DAM_CANYON - 20.0) * (k + rnd(k, 51)) / 18
        if abs(x) < max(26.0, half):
            continue
        wall = dam_lift(int((x + DAM_CANYON) // 16), 19)[1]
        y_bot = DAM_PLATEAU - 15.0 - 30.0 * rnd(k, 53)
        w = 2.5 + 3.0 * rnd(k, 54)
        dark = lerp(wall, col("varnish"), 0.65)
        s.poly([(x - 0.3, y_bot, fz + 0.05), (x + 0.3, y_bot, fz + 0.05), (x + w / 2, DAM_PLATEAU, fz + 0.05),
                (x - w / 2, DAM_PLATEAU, fz + 0.05)], [wall, wall, dark, dark], up=(0.0, 0.0, 1.0))
    y0, y1 = BAY_TOP + 1.4, DAM_PLATEAU - 1.0
    s.poly([(-half, y0, fz + 0.08), (half, y0, fz + 0.08), (half, y1, fz + 0.08), (-half, y1, fz + 0.08)], col("oxide"),
           up=(0.0, 0.0, 1.0))


def dam_letters(text, height=None, size_x=None, scale=None):
    """A line of text in Blender's built-in face as XY triangles from (0, 0): (triangles, width, height, scale). The scale
    fits the given height and width, or is given outright so that two lines share one size."""
    cu = bpy.data.curves.new("dam_text", "FONT")
    cu.body = text
    cu.size = 1.0
    ob = bpy.data.objects.new("dam_text", cu)
    bpy.context.scene.collection.objects.link(ob)
    dg = bpy.context.evaluated_depsgraph_get()
    me = ob.evaluated_get(dg).to_mesh()
    bm = bmesh.new()
    bm.from_mesh(me)
    bmesh.ops.triangulate(bm, faces=bm.faces[:])
    tris = [[(v.co.x, v.co.y) for v in f.verts] for f in bm.faces]
    xs = [p[0] for t in tris for p in t]
    ys = [p[1] for t in tris for p in t]
    bm.free()
    ob.evaluated_get(dg).to_mesh_clear()
    bpy.data.objects.remove(ob)
    bpy.data.curves.remove(cu)
    k = scale or height / (max(ys) - min(ys))
    if size_x and not scale:
        k = min(k, size_x / (max(xs) - min(xs)))
    x0, y0 = min(xs), min(ys)
    return [[((x - x0) * k, (y - y0) * k) for x, y in t] for t in tris], (max(xs) - x0) * k, (max(ys) - y0) * k, k


_BAND = []


def dam_band():
    """The Fleet's claim band, one size in every view: (half width, letter triangles, letter width)."""
    if not _BAND:
        y0, y1 = BAY_TOP + 1.4, DAM_PLATEAU - 1.0
        tris, width, _, _ = dam_letters(DAM_CLAIM, (y1 - y0) * 0.62, size_x=250.0)
        _BAND.extend((width / 2 + 6.0, tris, width))
    return _BAND


def dam_claim(e, d1, fz):
    """The Fleet's stencil across the lintel, bone on an oxide band, and the crew's chalk under it at the yard."""
    y0, y1 = BAY_TOP + 1.4, DAM_PLATEAU - 1.0
    half, tris, width = dam_band()
    band = (-half, half)
    ox = col("oxide")
    e.poly([(band[0], y0, fz + 0.04), (band[1], y0, fz + 0.04), (band[1], y1, fz + 0.04), (band[0], y1, fz + 0.04)],
           [vscale(ox, 0.85), vscale(ox, 0.85), ox, ox], up=(0.0, 0.0, 1.0))
    ly = y0 + (y1 - y0) * 0.19
    for t in tris:
        e.poly([(-width / 2 + x, ly + y, fz + 0.07) for x, y in t], col("bone"), up=(0.0, 0.0, 1.0))
    for sx in (-1, 1):
        x = sx * (width / 2 + 3.0)
        e.poly([(x - 1.6, y0 + 2.0, fz + 0.07), (x + 1.6, y0 + 2.0, fz + 0.07), (x + 1.6, y1 - 2.0, fz + 0.07),
                (x - 1.6, y1 - 2.0, fz + 0.07)], col("iron"), up=(0.0, 0.0, 1.0))
    # the crew's answer, chalked by hand inside a scrawled box on the gate bay's flush face (x -45 to -24, clear of the
    # set-back bays and the jib's foot), so it never floats over a bay
    # in two lines, written by hand: slanted, climbing a little to the right, the second line set in under the first
    words = DAM_CHALK.rsplit(" ", 1)
    _, w0, _, k = dam_letters(words[0], 3.6, size_x=15.0)
    chalk = lerp(col("calcite"), col("concrete_lt"), 0.1)
    x0, y0 = -42.6, 33.0
    lines = [(words[1], 1.6, 0.0), (words[0], 0.0, 4.6)]
    right, top = x0, y0
    for text, dx, dy in lines:
        tris, w, h, _ = dam_letters(text, scale=k)
        for t in tris:
            d1.poly([(x0 + dx + x + 0.18 * y, y0 + dy + y + 0.035 * (x + dx), fz + 0.06) for x, y in t], chalk,
                    up=(0.0, 0.0, 1.0))
        right = max(right, x0 + dx + w + 0.18 * h)
        top = max(top, y0 + dy + h + 0.035 * (w + dx))
    assert right + 2.4 < -24.0, right   # the box stays on the gate bay's flush face, clear of the jib's foot
    pad, lw = 1.4, 0.32
    box_pts = [(x0 - pad, y0 - pad), (right + pad + 0.8, y0 - pad - 0.3), (right + pad + 1.0, top + pad),
               (x0 - pad + 0.3, top + pad + 0.4)]
    for k in range(4):
        (ax_, ay_), (bx_, by_) = box_pts[k], box_pts[(k + 1) % 4]
        dx, dy = bx_ - ax_, by_ - ay_
        ln = math.hypot(dx, dy)
        nx, ny = -dy / ln * lw / 2, dx / ln * lw / 2
        d1.poly([(ax_ - nx, ay_ - ny, fz + 0.06), (bx_ - nx, by_ - ny, fz + 0.06), (bx_ + nx, by_ + ny, fz + 0.06),
                 (ax_ + nx, ay_ + ny, fz + 0.06)], chalk, up=(0.0, 0.0, 1.0))


def build_dam():
    base, exempt, mid, far = View("landmark_dam"), View("cradle"), View("landmark_dam_mid"), View("landmark_dam_far")
    colm = sky.Surf("landmark_dam-col-col")
    e, st, ln = base["enamel"], base["steel"], base["ancient_lens"]
    fz = DAM_FACE_Z
    # face cladding: concrete panels laid on the ridden ramp, FLUSH-safe at 0.06 m, no collider (the stamp is the ride)
    for i in range(20):
        x0, x1 = -DAM_CANYON + 20.0 * i, -DAM_CANYON + 20.0 * (i + 1)
        for j in range(5):
            z0, z1 = 4.9 - j * (24.84 / 5), 4.9 - (j + 1) * (24.84 / 5)
            q = [(x0, dam_ramp_y(z0) + 0.06, z0), (x1, dam_ramp_y(z0) + 0.06, z0), (x1, dam_ramp_y(z1) + 0.06, z1),
                 (x0, dam_ramp_y(z1) + 0.06, z1)]
            e.poly(q, shade("concrete_dk", 1.0, (i, j, 1), 0.05), up=(0.0, 0.83, 0.55))
    rows = 20
    d1, d2 = sky.Surf("landmark_dam_detail1"), sky.Surf("landmark_dam_detail2")
    # the face, cast in lifts with its ribs and set-back bays, weathered, its works and its two voices
    depth = dam_face(e, fz)
    dam_weather(e, depth)
    dam_works(e, fz)
    dam_claim(e, d1, fz)
    box(e, (-DAM_CANYON, DAM_PLATEAU, fz - 2.0), (DAM_CANYON, DAM_PLATEAU + 0.3, fz + 0.3), col("concrete_lt"))
    # pilasters just past the chord, standing on the ramp (outside x +-160, so nothing below y 30 collides there)
    for sx in (-1, 1):
        lo_x, hi_x = sorted((sx * 164.0, sx * 172.0))
        box(e, (lo_x, dam_ramp_y(fz + 3.0) - 0.6, fz - 1.0), (hi_x, 104.0, fz + 3.0), col("concrete"))
        box(colm, (lo_x, dam_ramp_y(fz + 3.0) - 0.6, fz - 1.0), (hi_x, 104.0, fz + 3.0), col("concrete"))
    # crest terrace on the plateau, flush (the terrain is the surface)
    for i in range(10):
        x0, x1 = -DAM_CANYON + 40.0 * i, -DAM_CANYON + 40.0 * (i + 1)
        e.poly([(x0, DAM_PLATEAU + 0.08, fz - 2.0), (x0, DAM_PLATEAU + 0.08, -44.0), (x1, DAM_PLATEAU + 0.08, -44.0),
                (x1, DAM_PLATEAU + 0.08, fz - 2.0)], shade("concrete_dk", 1.05, (i, 9), 0.04), up=UP)
    box(colm, (-DAM_CANYON, 30.5, -30.0), (DAM_CANYON, DAM_PLATEAU, fz), col("concrete"))
    # the face's returns into the rock: the block above ends on the canyon walls' line, and its end showed bare in the
    # wedge where the wall's foot slope meets the cliff under the face, a strip up to 1.7 m deep beside the face at
    # x +-200 with nothing drawn on it (red team w30, collision sweep: y 50 to 93). The ground reaches the plateau within
    # 2 m of it, so no ball fits there; the return gives the collider a drawn face and the rock hides the rest
    for sx in (-1, 1):
        x = sx * DAM_CANYON
        e.poly([(x, 29.9, fz), (x, DAM_PLATEAU, fz), (x, DAM_PLATEAU, fz - 2.5), (x, 29.9, fz - 2.5)],
               lerp(col("concrete"), col("concrete_dk"), 0.45), inside=(0.0, 65.0, fz - 1.25))
    # the upper arch: bowed upstream, cast courses, an 8 m crest deck at 121 with parapets both sides
    n = 24
    xs = [-DAM_CHORD + 2 * DAM_CHORD * k / n for k in range(n + 1)]
    thick = 9.0
    bands = 6
    for k in range(n):
        xa, xb = xs[k], xs[k + 1]
        za, zb = dam_arch_z(xa), dam_arch_z(xb)
        ctr = ((xa + xb) / 2, 110.0, (za + zb) / 2 - thick / 2)
        for j in range(bands):
            y0 = 99.0 + (DAM_CREST - 99.0) * j / bands
            y1 = 99.0 + (DAM_CREST - 99.0) * (j + 1) / bands
            e.poly([(xa, y0, za), (xb, y0, zb), (xb, y1, zb), (xa, y1, za)], dam_course(j, k), inside=ctr)
        e.poly([(xa, 99.0, za - thick), (xa, DAM_CREST, za - thick), (xb, DAM_CREST, zb - thick), (xb, 99.0, zb - thick)],
               col("concrete_dk"), inside=ctr)
        e.poly([(xa, DAM_CREST, za), (xb, DAM_CREST, zb), (xb, DAM_CREST, zb - thick), (xa, DAM_CREST, za - thick)],
               shade("concrete_lt", 1.0, (k, 33)), up=UP)
        for dz in (0.0, -thick + 0.6):
            beam(e, (xa, DAM_CREST + 0.6, za + dz - 0.3), (xb, DAM_CREST + 0.6, zb + dz - 0.3), 0.6, 1.2, col("concrete_lt"))
        # the collider follows the drawn arch segment by segment: its faces, the crest deck and the parapets. A box per
        # two segments met the ball inside the arch's drawn walls at every joint (clip audit, 30 Oct: 2,539 m2 felt,
        # up to 3.5 m from a drawn face) and floated it 1.2 m over the deck
        for ra, rb in zip(arch_pieces(xa, za, thick), arch_pieces(xb, zb, thick)):
            colm.ring_solid(ra, rb, col("concrete"), caps=(k == 0, k == n - 1))
    for sx in (-1, 1):
        x = sx * DAM_CHORD
        z = dam_arch_z(x)
        e.poly([(x, 99.0, z), (x, DAM_CREST, z), (x, DAM_CREST, z - thick), (x, 99.0, z - thick)], col("concrete_dk"),
               inside=(x - sx, 110.0, z - thick / 2))
    # gate towers: from the terrace to 139, a copper-roofed hoist house on each, corbelled over the face
    for sx in (-1, 1):
        x0, x1 = sorted((sx * DAM_TOWER[0], sx * DAM_TOWER[1]))
        for j in range(8):
            y0, y1 = DAM_PLATEAU + 4.875 * j, DAM_PLATEAU + 4.875 * (j + 1)
            c = dam_course(j, 40 + sx)
            box(e, (x0, y0, DAM_TOWER_Z[0]), (x1, y1, DAM_TOWER_Z[1]), c)
        box(e, (x0 - 0.6, 139.0, DAM_TOWER_Z[0] - 0.6), (x1 + 0.6, 139.6, DAM_TOWER_Z[1] + 0.6), col("concrete_lt"))
        box(st, (x0 + 1.5, 139.6, DAM_TOWER_Z[0] + 1.5), (x1 - 1.5, DAM_TOP - 0.01, DAM_TOWER_Z[1] - 1.5), col("copper_dk"))
        box(colm, (x0, DAM_PLATEAU, DAM_TOWER_Z[0]), (x1, DAM_TOP, DAM_TOWER_Z[1]), col("concrete"))
        for xc in (x0 + 2.0, x1 - 2.0):
            beam(st, (xc, 92.0, fz + 0.2), (xc, DAM_PLATEAU, DAM_TOWER_Z[1]), 0.8, 0.8, col("iron"))
        # a truss bridge from each tower back to the arch crest, high over the crest_rail
        xm = sx * 18.0
        z_arch = dam_arch_z(xm)
        for dx in (-2.0, 2.0):
            beam(st, (xm + dx, 119.0, DAM_TOWER_Z[0]), (xm + dx, 119.0, z_arch), 0.5, 0.7, col("iron"))
            beam(st, (xm + dx, DAM_CREST + 1.2, DAM_TOWER_Z[0]), (xm + dx, DAM_CREST + 1.2, z_arch), 0.4, 0.5, col("iron"))
            steps = 10
            for k in range(steps):
                za, zb = DAM_TOWER_Z[0] + (z_arch - DAM_TOWER_Z[0]) * k / steps, DAM_TOWER_Z[0] + (z_arch - DAM_TOWER_Z[0]) * (k + 1) / steps
                ya, yb = (119.0, DAM_CREST + 1.2) if k % 2 == 0 else (DAM_CREST + 1.2, 119.0)
                beam(st, (xm + dx, ya, za), (xm + dx, yb, zb), 0.25, 0.25, col("iron_hi"), caps=False)
        box(e, (xm - 2.4, 118.6, z_arch + 0.5), (xm + 2.4, 119.0, DAM_TOWER_Z[0]), col("concrete_dk"))
    # gantry: a box truss between the towers' inner faces; sight_top sits on its top centre
    gz = -20.0
    for dy in (138.0, DAM_TOP - 0.25):
        for dz in (-1.5, 1.5):
            beam(st, (-DAM_TOWER[0], dy, gz + dz), (DAM_TOWER[0], dy, gz + dz), 0.5, 0.5, col("iron"))
    for k in range(12):
        xa, xb = -DAM_TOWER[0] + 2.0 * k, -DAM_TOWER[0] + 2.0 * (k + 1)
        for dz in (-1.5, 1.5):
            ya, yb = (138.0, DAM_TOP - 0.25) if k % 2 == 0 else (DAM_TOP - 0.25, 138.0)
            beam(st, (xa, ya, gz + dz), (xb, yb, gz + dz), 0.22, 0.22, col("iron_hi"), caps=False)
    box(st, (-3.0, 138.3, gz - 1.2), (3.0, 140.2, gz + 1.2), col("copper"))
    box(colm, (-DAM_TOWER[0], 137.75, gz - 1.75), (DAM_TOWER[0], DAM_TOP, gz + 1.75), col("iron"))
    # trunnion brackets for the two radial gates (the leaves are their own nodes)
    hy, hz = DAM_HINGE
    for x in (-12.4, 0.0, 12.4):
        beam(e, (x, hy, fz), (x, hy, hz - 0.8), 1.2, 2.0, col("concrete_dk"))
    # the halo: the relic's cradle, hung from the jib, rims green at hp_1 and hp_2
    ax, ay, az = DAM_ANCHOR
    r0, r1, dep = DAM_HALO
    segs = 24
    for k in range(segs):
        a0, a1 = TAU * k / segs, TAU * (k + 1) / segs
        ring = lambda r, a, z: (ax + r * math.sin(a), ay + r * math.cos(a), z)
        c = shade("concrete_lt", 1.0, (k, 71), 0.06)
        q = lambda r, z: [ring(r, a0, z), ring(r, a1, z)]
        for (ra, za), (rb, zb) in (((r1, az - dep / 2), (r1, az + dep / 2)), ((r0, az + dep / 2), (r0, az - dep / 2)),
                                   ((r0, az + dep / 2), (r1, az + dep / 2)), ((r1, az - dep / 2), (r0, az - dep / 2))):
            pa, pb = q(ra, za), q(rb, zb)
            exempt["enamel"].poly([pa[0], pa[1], pb[1], pb[0]], c, inside=ring((r0 + r1) / 2, (a0 + a1) / 2, az))
        if k % 3 == 0:
            for z in (az - dep / 2 - 0.05, az + dep / 2 + 0.05):
                beam(exempt["steel"], ring(r0 - 0.05, a0, z), ring(r1 + 0.05, a0, z), 0.5, 0.08, col("iron"))
    for sx in (-1, 1):
        stud = (ax + sx * (r0 + r1) / 2, ay, az + dep / 2 + 0.02)
        for k in range(8):
            a0, a1 = TAU * k / 8, TAU * (k + 1) / 8
            p = lambda r, a: (stud[0] + r * math.cos(a), stud[1] + r * math.sin(a), stud[2])
            exempt["ancient_lens"].poly([p(0.8, a0), p(1.25, a0), p(1.25, a1), p(0.8, a1)], col("lens"), up=(0.0, 0.0, 1.0))
        top = (ax + sx * r1 * math.sin(0.5), ay + r1 * math.cos(0.5), az)
        tube(exempt["steel"], top, (sx * 1.2, DAM_JIB_TIP[1] - 1.4, az), 0.3, 6, col("cable"))
    # the jib: a steel A-frame crane cantilevered off the face, its tip over the halo, so the cradle reads as rigged
    tip = DAM_JIB_TIP
    for sx in (-1, 1):
        roots = [(sx * 22.0, 76.0, fz + 0.3), (sx * 22.0, 52.0, fz + 0.3)]
        for root in roots:
            beam(st, root, tip, 1.1, 1.1, col("iron"))
        lace = 8
        for k in range(lace):
            a = vlerp(roots[0], tip, k / lace)
            b = vlerp(roots[1], tip, (k + 1) / lace) if k % 2 == 0 else vlerp(roots[1], tip, k / lace)
            beam(st, a, b, 0.35, 0.35, col("iron_hi"), caps=False)
            if k % 2:
                beam(st, vlerp(roots[0], tip, k / lace), vlerp(roots[1], tip, k / lace), 0.35, 0.35, col("iron_hi"), caps=False)
        box(e, (sx * 22.0 - 2.0, 49.0, fz), (sx * 22.0 + 2.0, 79.0, fz + 1.0), col("concrete_dk"))
    for y in (52.0, 76.0):
        beam(st, (-22.0, y, fz + 0.3), (22.0, y, fz + 0.3), 0.7, 0.7, col("iron"))
    box(st, (tip[0] - 1.6, tip[1] - 1.6, tip[2] - 1.6), (tip[0] + 1.6, tip[1] + 1.6, tip[2] + 1.6), col("copper"))
    wheel(st, (0.0, tip[1] - 1.4, tip[2]), (1.0, 0.0, 0.0), 1.3, 0.25, 4, 12, col("iron"), col("copper_dk"))
    # spill: white water from under the radial gates, down the face, the ramp and out across the apron
    gl = e          # on the enamel slot: a sixth draw would push the base over the class cap with the -col mesh counted
    lip = DAM_HINGE[0] - DAM_GATE_R * math.sin(0.62)
    for x0, x1 in ((-11.4, -0.6), (0.6, 11.4)):
        steps = [(lip, fz + 0.18), (DAM_RAMP_TOP + 0.1, fz + 0.18)]
        for k in range(1, 7):
            z = fz + 0.2 + (5.0 - fz - 0.2) * k / 6
            steps.append((dam_ramp_y(z) + 0.1, z))
        for z in (12.0, 22.0):
            steps.append((0.1, z))
        for k in range(len(steps) - 1):
            (ya, za), (yb, zb) = steps[k], steps[k + 1]
            spread = 1.4 * max(0.0, (zb - 5.0) / 17.0)
            spread_a = 1.4 * max(0.0, (za - 5.0) / 17.0)
            ca = lerp(col("water"), col("mist"), min(1.0, k / 5))
            cb = lerp(col("water"), col("mist"), min(1.0, (k + 1) / 5))
            q = [(x0 - spread_a, ya, za), (x1 + spread_a, ya, za), (x1 + spread, yb, zb), (x0 - spread, yb, zb)]
            face = sky.norm(sky.cross(vsub(q[1], q[0]), vsub(q[3], q[0])))
            if face[1] < 0 or (abs(face[1]) < 1e-6 and face[2] < 0):
                face = vscale(face, -1.0)
            gl.poly(q, [ca, ca, cb, cb], up=face)
    gates = [dam_gate("gate_l", -11.6, -0.4), dam_gate("gate_r", 0.4, 11.6)]

    # ---- mid: a 24-segment arch, the face, towers, gantry, closed gates, the halo
    me, ms = mid["enamel"], mid["steel"]
    dam_face_flat(me, fz, 5)
    for k in range(n):
        xa, xb = xs[k], xs[k + 1]
        za, zb = dam_arch_z(xa), dam_arch_z(xb)
        ctr = ((xa + xb) / 2, 110.0, (za + zb) / 2 - thick / 2)
        me.poly([(xa, 99.0, za), (xb, 99.0, zb), (xb, DAM_CREST + 1.2, zb), (xa, DAM_CREST + 1.2, za)], dam_course(k, 1), inside=ctr)
        me.poly([(xa, DAM_CREST + 1.2, za), (xb, DAM_CREST + 1.2, zb), (xb, DAM_CREST + 1.2, zb - thick), (xa, DAM_CREST + 1.2, za - thick)],
                col("concrete_lt"), up=UP)
        me.poly([(xa, 99.0, za - thick), (xa, DAM_CREST + 1.2, za - thick), (xb, DAM_CREST + 1.2, zb - thick), (xb, 99.0, zb - thick)],
                col("concrete_dk"), inside=ctr)
    for sx in (-1, 1):
        x0, x1 = sorted((sx * DAM_TOWER[0], sx * DAM_TOWER[1]))
        box(me, (x0, DAM_PLATEAU, DAM_TOWER_Z[0]), (x1, 139.6, DAM_TOWER_Z[1]), col("concrete"))
        box(ms, (x0 + 1.5, 139.6, DAM_TOWER_Z[0] + 1.5), (x1 - 1.5, DAM_TOP - 0.01, DAM_TOWER_Z[1] - 1.5), col("copper_dk"))
        box(ms, (sx * 18.0 - 2.4, 118.6, dam_arch_z(18.0)), (sx * 18.0 + 2.4, DAM_CREST + 1.2, DAM_TOWER_Z[0]), col("iron"))
        lo_x, hi_x = sorted((sx * 164.0, sx * 172.0))
        box(me, (lo_x, 26.0, fz - 1.0), (hi_x, 104.0, fz + 3.0), col("concrete"))
    box(ms, (-DAM_TOWER[0], 138.0, gz - 1.5), (DAM_TOWER[0], DAM_TOP, gz + 1.5), col("iron"))
    box(me, (-DAM_CANYON, DAM_PLATEAU, fz - 2.0), (DAM_CANYON, DAM_PLATEAU + 0.3, fz + 0.3), col("concrete_lt"))
    for x0, x1 in ((-11.6, -0.4), (0.4, 11.6)):
        box(ms, (x0, 37.3, fz + 0.1), (x1, 50.7, fz + 1.4), col("iron_hi"))
    for k in range(16):
        a0, a1 = TAU * k / 16, TAU * (k + 1) / 16
        ring = lambda r, a: (ax + r * math.sin(a), ay + r * math.cos(a), az + dep / 2)
        me.poly([ring(r0, a0), ring(r1, a0), ring(r1, a1), ring(r0, a1)], col("concrete_lt"), up=(0.0, 0.0, 1.0))
    for sx in (-1, 1):
        beam(ms, (sx * 22.0, 76.0, fz + 0.3), DAM_JIB_TIP, 1.4, 1.4, col("iron"))
        beam(ms, (sx * 22.0, 52.0, fz + 0.3), DAM_JIB_TIP, 1.4, 1.4, col("iron"))
        tube(ms, (ax + sx * r1 * math.sin(0.5), ay + r1 * math.cos(0.5), az), (0.0, DAM_JIB_TIP[1], az), 0.4, 4, col("cable"))
    for x0, x1 in ((-11.4, -0.6), (0.6, 11.4)):
        mid["enamel"].poly([(x0, 37.3, fz + 0.18), (x1, 37.3, fz + 0.18), (x1, DAM_RAMP_TOP, fz + 0.18), (x0, DAM_RAMP_TOP, fz + 0.18)],
                          col("water"), up=(0.0, 0.0, 1.0))
        mid["enamel"].poly([(x0, DAM_RAMP_TOP + 0.1, fz + 0.2), (x1, DAM_RAMP_TOP + 0.1, fz + 0.2), (x1 + 1.4, 0.1, 22.0), (x0 - 1.4, 0.1, 22.0)],
                          col("mist"), up=(0.0, 0.83, 0.55))

    # ---- far: the drop-in hero silhouette: crest line, tower notches, the face as a pale bar
    fe = far["enamel"]
    box(fe, (-DAM_CANYON, 29.9, fz - 1.0), (DAM_CANYON, DAM_PLATEAU + 0.3, fz), col("concrete"))
    dam_face_flat(fe, fz + 0.15, 1)
    for k in range(12):
        xa, xb = -DAM_CHORD + 2 * DAM_CHORD * k / 12, -DAM_CHORD + 2 * DAM_CHORD * (k + 1) / 12
        za, zb = dam_arch_z(xa), dam_arch_z(xb)
        ctr = ((xa + xb) / 2, 110.0, (za + zb) / 2 - thick / 2)
        fe.poly([(xa, 99.0, za), (xb, 99.0, zb), (xb, DAM_CREST + 1.2, zb), (xa, DAM_CREST + 1.2, za)], col("concrete_lt"), inside=ctr)
        fe.poly([(xa, DAM_CREST + 1.2, za), (xb, DAM_CREST + 1.2, zb), (xb, DAM_CREST + 1.2, zb - thick), (xa, DAM_CREST + 1.2, za - thick)],
                col("concrete_lt"), up=UP)
    for sx in (-1, 1):
        x0, x1 = sorted((sx * DAM_TOWER[0], sx * DAM_TOWER[1]))
        box(fe, (x0, DAM_PLATEAU, DAM_TOWER_Z[0]), (x1, DAM_TOP, DAM_TOWER_Z[1]), col("concrete"))
    box(far["steel"], (-DAM_TOWER[0], 138.0, gz - 1.5), (DAM_TOWER[0], DAM_TOP, gz + 1.5), col("iron"))
    for sx in (-1, 1):
        beam(far["steel"], (sx * 22.0, 76.0, fz + 0.3), DAM_JIB_TIP, 2.0, 2.0, col("iron"))
        beam(far["steel"], (sx * 22.0, 52.0, fz + 0.3), DAM_JIB_TIP, 2.0, 2.0, col("iron"))
    for x0, x1 in ((-11.4, -0.6), (0.6, 11.4)):
        fe.poly([(x0, 37.3, fz + 0.18), (x1, 37.3, fz + 0.18), (x1, DAM_RAMP_TOP, fz + 0.18), (x0, DAM_RAMP_TOP, fz + 0.18)],
                col("mist"), up=(0.0, 0.0, 1.0))
    for k in range(8):
        a0, a1 = TAU * k / 8, TAU * (k + 1) / 8
        ring = lambda r, a: (ax + r * math.sin(a), ay + r * math.cos(a), az + dep / 2)
        fe.poly([ring(r0, a0), ring(r1, a0), ring(r1, a1), ring(r0, a1)], col("concrete_lt"), up=(0.0, 0.0, 1.0))

    # ---- shells: course lines and tower ladders (1); monolith joints (2)
    lines = [(x0, x1) for x0, x1, _ in dam_spans()]
    for j in range(1, rows):
        y = 29.9 + (DAM_PLATEAU + 0.3 - 29.9) * j / rows
        for x0, x1 in lines:
            z = depth((x0 + x1) / 2, y) + 0.03
            card(d1, [(x0, y - 0.12, z), (x1, y - 0.12, z), (x1, y + 0.12, z), (x0, y + 0.12, z)],
                 col("joint"), (0.0, 0.0, 1.0))
    for sx in (-1, 1):
        x = sx * (DAM_TOWER[1] + 0.35)
        for side in (-0.4, 0.4):
            beam(d1, (x, DAM_PLATEAU, -21.0 + side), (x, 139.0, -21.0 + side), 0.08, 0.08, col("iron"), caps=False)
        for k in range(0, 78, 2):
            beam(d1, (x, DAM_PLATEAU + 0.5 * k + 0.4, -21.4), (x, DAM_PLATEAU + 0.5 * k + 0.4, -20.6), 0.05, 0.05, col("iron"), caps=False)
        for j in range(5):
            y = 106.0 + 6.5 * j
            card(d1, [(sx * DAM_TOWER[0] - sx * 0.02, y, -24.0), (sx * DAM_TOWER[0] - sx * 0.02, y, -18.0),
                      (sx * DAM_TOWER[0] - sx * 0.02, y + 3.0, -18.0), (sx * DAM_TOWER[0] - sx * 0.02, y + 3.0, -24.0)],
                 col("stain"), (-sx, 0.0, 0.0))
    for i in range(1, 25):
        x = -DAM_CANYON + 16.0 * i
        if any(abs(x - r) < DAM_RIB_W / 2 + 0.2 for r in DAM_RIBS):
            continue
        # a joint follows the face's profile: plinth, batter, set-back, lintel
        for ya, yb in ((29.95, BAY_FOOT), (BAY_FOOT, BAY_SILL), (BAY_SILL, BAY_TOP), (BAY_TOP, DAM_PLATEAU)):
            za, zb = depth(x, ya + 1e-6) + 0.04, depth(x, yb - 1e-6) + 0.04
            card(d2, [(x - 0.08, ya, za), (x + 0.08, ya, za), (x + 0.08, yb, zb), (x - 0.08, yb, zb)], col("joint"), (0.0, 0.0, 1.0))
    empties = {
        "sight_top": (0.0, DAM_TOP, gz), "beam_root": DAM_ANCHOR, "warden_anchor": DAM_ANCHOR,
        "hp_0": (ax, ay + 1.6, az), "hp_1": (ax + 10.0, ay, az), "hp_2": (ax - 10.0, ay, az),
        "gate_l_hinge": (-6.0, hy, hz), "gate_r_hinge": (6.0, hy, hz),
    }
    nodes = [(g, (sx * 6.0, hy, hz)) for g, sx in zip(gates, (-1, 1))]
    return {"base": base, "exempt": exempt, "col": colm, "nodes": nodes, "empties": empties, "mid": mid, "far": far,
            "shells": (d1, d2), "shell_slot": "enamel", "clear": CLEAR}


# ================================================================ card 2: the penstock tower (park_flume)
# Bake fit (assets/park/park_flume): the head_house_drum terrace stamp is square, not round: its floor is at y -14 inside
# 40 m of the centre (230, 480) and its walls slope to grade (y 0) at 42 m on all four sides, so the head house is a
# square concrete pit. The liner lies on those four planes 0.07 m proud; the parapet stands outside the rim and keeps
# off every crossing of the six pilot lines and the floor line in assets/park/park_flume/lines.json (the south-west
# corner and the south wall near x 253), the annex corner and the whole east wall (the warden_exit kicker and gate lip).
# The roof is a ring girder on rim columns carrying six north-south trusses, never lower than y 14.6.
FLUME_DRUM = (230.0, 480.0)
FLUME_FLOOR = -14.0
FLUME_WALL = (40.0, 42.0)
FLUME_TOWER = (300.0, 560.0)
FLUME_ANCHOR = (230.0, -2.0, 470.0)
# parapet runs on the rim, world coordinates: (side, from, to) with side W/N/S along the drum's edges
FLUME_PARAPET = (("W", 462.0, 504.0), ("N", 212.0, 268.0), ("S", 204.0, 238.0))
FLUME_LINE_CROSSINGS = ((188.0, 445.0), (189.0, 441.0), (253.0, 438.0))


def flume_tower_r(y):
    if y <= 80.0:
        return 9.0 - 2.0 * y / 80.0
    if y <= 87.0:
        return 7.0 + 4.0 * (y - 80.0) / 7.0
    return 11.0 - 0.8 * (y - 87.0) / 3.0


def build_penstock_tower():
    F = FRAMES["landmark_penstock_tower"]
    L = lambda x, y, z: F.local(x, y, z)
    base, exempt, mid, far = View("landmark_penstock_tower"), View("cradle"), View("landmark_penstock_tower_mid"), View("landmark_penstock_tower_far")
    colm = sky.Surf("landmark_penstock_tower-col-col")
    e, st, ln = base["enamel"], base["steel"], base["ancient_lens"]
    tx, _, tz = L(FLUME_TOWER[0], 0.0, FLUME_TOWER[1])
    tc = (tx, tz)
    # surge tower: formwork bands every 3 m, the bell, a gallery at 84, a green ring round the beam root
    ys = [-1.0] + [3.0 * k for k in range(1, 27)] + [80.0, 82.0, 84.0, 86.0, 87.0, 89.0, 90.0]
    for k in range(len(ys) - 1):
        y0, y1 = ys[k], ys[k + 1]
        c = shade("concrete_lt" if k % 2 else "concrete", 1.0, (k, 2), 0.04)
        frustum(e, tc, flume_tower_r(max(y0, 0.0)), flume_tower_r(y1), y0, y1, 32, c, caps=(k == 0, k == len(ys) - 2))
    frustum(e, tc, 10.5, 10.2, -1.0, 1.5, 32, col("concrete_dk"))
    annulus(st, tc, 9.4, 12.6, 83.4, 83.8, 32, lambda i: col("iron"))
    for i in range(16):
        a = TAU * i / 16
        p = (tc[0] + 12.4 * math.sin(a), 83.8, tc[1] + 12.4 * math.cos(a))
        beam(st, p, vadd(p, UP, 1.1), 0.12, 0.12, col("iron"), caps=False)
        q = (tc[0] + 12.4 * math.sin(a + TAU / 16), 84.9, tc[1] + 12.4 * math.cos(a + TAU / 16))
        beam(st, vadd(p, UP, 1.1), q, 0.1, 0.1, col("iron"), caps=False)
    annulus(ln, tc, 2.0, 3.2, 90.0, 90.06, 16, lambda i: col("lens"), sides=False)
    frustum(colm, tc, 9.0, 7.0, -1.0, 80.0, 12, col("concrete"))
    frustum(colm, tc, 7.0, 11.0, 80.0, 87.0, 12, col("concrete"))
    frustum(colm, tc, 11.0, 10.2, 87.0, 90.0, 12, col("concrete"))
    # the head house: the four liner planes, panelled in 8 m form panels, 0.07 m proud of the stamp's slopes
    cx, cz = FLUME_DRUM
    d0, d1w = FLUME_WALL
    inset = 0.07
    sides = {"N": ((1, 0), (0, 1)), "S": ((1, 0), (0, -1)), "E": ((0, 1), (1, 0)), "W": ((0, 1), (-1, 0))}
    for name, (along, out) in sides.items():
        for i in range(10):
            for j in range(3):
                pts = []
                for (fa, fy) in ((i / 10, j / 3), ((i + 1) / 10, j / 3), ((i + 1) / 10, (j + 1) / 3), (i / 10, (j + 1) / 3)):
                    y = FLUME_FLOOR + 14.0 * fy
                    d = d0 + (d1w - d0) * (y - FLUME_FLOOR) / 14.0 - inset
                    a = -d + 2 * d * fa
                    wx = cx + along[0] * a + out[0] * d
                    wz = cz + along[1] * a + out[1] * d
                    pts.append(L(wx, y, wz))
                n_out = F.dir_local(out[0], out[1])
                e.poly(pts, shade("concrete", 1.0, (i, j, ord(name)), 0.06), up=vscale(n_out, -1.0))
    # parapet: concrete runs on the rim with pilasters; each run collides
    for side, a0, a1 in FLUME_PARAPET:
        if side == "W":
            lo, hi = (cx - 43.8, -0.3, a0), (cx - 42.3, 4.0, a1)
        elif side == "N":
            lo, hi = (a0, -0.3, cz + 42.3), (a1, 4.0, cz + 43.8)
        else:
            lo, hi = (a0, -0.3, cz - 43.8), (a1, 4.0, cz - 42.3)
        corners = [L(lo[0], 0, lo[2]), L(hi[0], 0, lo[2]), L(hi[0], 0, hi[2]), L(lo[0], 0, hi[2])]
        outline = [(p[0], p[2]) for p in corners]
        slab(e, outline, lo[1], hi[1], col("concrete"), col("concrete_lt"))
        slab(colm, outline, lo[1], hi[1], col("concrete"))
        length = a1 - a0
        for k in range(int(length // 8) + 1):
            a = a0 + min(length, 8.0 * k)
            if side == "W":
                plo, phi = (cx - 44.1, 0.0, a - 0.6), (cx - 42.0, 4.6, a + 0.6)
            elif side == "N":
                plo, phi = (a - 0.6, 0.0, cz + 42.0), (a + 0.6, 4.6, cz + 44.1)
            else:
                plo, phi = (a - 0.6, 0.0, cz - 44.1), (a + 0.6, 4.6, cz - 42.0)
            pc = [L(plo[0], 0, plo[2]), L(phi[0], 0, plo[2]), L(phi[0], 0, phi[2]), L(plo[0], 0, phi[2])]
            slab(e, [(p[0], p[2]) for p in pc], plo[1], phi[1], col("concrete_lt"))
    # roof: rim columns (on the parapet runs and the two east corners), a square ring girder, six trusses north-south
    cols_w = [(cx - 43.0, cz + dz) for dz in (-12.0, 2.0, 16.0)] + [(cx + dx, cz + 43.0) for dx in (-14.0, 2.0, 18.0, 36.0)] + \
             [(cx + dx, cz - 43.0) for dx in (-22.0, -8.0)] + [(cx + 43.0, cz - 43.0), (cx + 43.0, cz + 43.0), (cx - 43.0, cz + 43.0), (cx - 43.0, cz - 43.0)]
    for wx, wz in cols_w:
        p = L(wx, 0.0, wz)
        box(st, (p[0] - 0.6, 0.0, p[2] - 0.6), (p[0] + 0.6, 18.6, p[2] + 0.6), col("iron"))
    ring_pts = [(cx - 43.0, cz - 43.0), (cx + 43.0, cz - 43.0), (cx + 43.0, cz + 43.0), (cx - 43.0, cz + 43.0)]
    for k in range(4):
        a, b = ring_pts[k], ring_pts[(k + 1) % 4]
        beam(st, L(a[0], 17.8, a[1]), L(b[0], 17.8, b[1]), 0.9, 1.6, col("iron"))
    for k, dx in enumerate((-30.0, -18.0, -6.0, 6.0, 18.0, 30.0)):
        x = cx + dx
        z0, z1 = cz - 43.0, cz + 43.0
        top, bot = 18.6, 14.6
        beam(st, L(x, top, z0), L(x, top, z1), 0.5, 0.6, col("iron"))
        beam(st, L(x, bot, z0 + 6.0), L(x, bot, z1 - 6.0), 0.5, 0.6, col("iron"))
        panels = 12
        for j in range(panels):
            za, zb = z0 + (z1 - z0) * j / panels, z0 + (z1 - z0) * (j + 1) / panels
            ya, yb = (top, bot) if j % 2 == 0 else (bot, top)
            if (j == 0 and yb == bot) or (j == panels - 1 and ya == bot):
                ya = yb = top if j == 0 else ya
            beam(st, L(x, ya, za), L(x, yb, zb), 0.25, 0.25, col("iron_hi"), caps=False)
    for dz in (-30.0, -10.0, 10.0, 30.0):
        beam(st, L(cx - 30.0, 18.9, cz + dz), L(cx + 30.0, 18.9, cz + dz), 0.3, 0.3, col("iron_hi"), caps=False)
    # penstock heads: three copper valve collars on the south wall, toward the bluff piers
    for dx in (-16.0, 0.0, 16.0):
        x = cx + dx
        wall = cz - (d0 + (d1w - d0) * 8.0 / 14.0)
        a, b = L(x, -6.0, wall - 0.5), L(x, -6.0, wall + 2.6)
        tube(st, a, b, 2.3, 16, col("copper"))
        tube(st, vadd(b, sky.norm(vsub(b, a)), -0.4), vadd(b, sky.norm(vsub(b, a)), 0.2), 2.9, 16, col("copper_dk"))
        hub = vadd(b, sky.norm(vsub(b, a)), 1.2)
        tube(st, vadd(b, sky.norm(vsub(b, a)), 0.2), hub, 0.25, 6, col("iron"))
        wheel(st, hub, sky.norm(vsub(b, a)), 1.6, 0.18, 6, 12, col("copper"), col("iron"))
    # the pour channel's two cheeks: green rims at hp_1 and hp_2 (the reactor's latch points)
    ax, ay, az = FLUME_ANCHOR
    hp = {"hp_0": (ax, ay + 1.6, az), "hp_1": (ax - 3.1, ay + 4.0, az + 3.9), "hp_2": (ax + 3.1, ay + 4.0, az - 3.9)}
    for key in ("hp_1", "hp_2"):
        c = L(*hp[key])
        out = sky.norm(vsub(c, L(ax, ay + 4.0, az)))
        u, v = frame(out)
        for k in range(8):
            a0, a1 = TAU * k / 8, TAU * (k + 1) / 8
            p = lambda r, a: vadd(vadd(c, u, r * math.cos(a)), v, r * math.sin(a))
            exempt["ancient_lens"].poly([p(0.5, a0), p(0.85, a0), p(0.85, a1), p(0.5, a1)], col("lens"), up=out)

    # ---- mid: tower, parapet runs, liner planes, girder and trusses as bars
    me, ms = mid["enamel"], mid["steel"]
    for k, (y0, y1) in enumerate(((-1.0, 30.0), (30.0, 60.0), (60.0, 80.0), (80.0, 87.0), (87.0, 90.0))):
        frustum(me, tc, flume_tower_r(max(y0, 0.0)), flume_tower_r(y1), y0, y1, 16, col("concrete_lt" if k % 2 else "concrete"), caps=(k == 0, k == 4))
    annulus(ms, tc, 9.4, 12.6, 83.4, 83.8, 16, lambda i: col("iron"))
    for name, (along, out) in sides.items():
        pts = []
        for fa, y in ((0.0, FLUME_FLOOR), (1.0, FLUME_FLOOR), (1.0, 0.0), (0.0, 0.0)):
            d = d0 + (d1w - d0) * (y - FLUME_FLOOR) / 14.0 - inset
            a = -d + 2 * d * fa
            pts.append(L(cx + along[0] * a + out[0] * d, y, cz + along[1] * a + out[1] * d))
        me.poly(pts, col("concrete"), up=vscale(F.dir_local(out[0], out[1]), -1.0))
    for side, a0, a1 in FLUME_PARAPET:
        if side == "W":
            lo, hi = (cx - 43.8, a0), (cx - 42.3, a1)
        elif side == "N":
            lo, hi = (a0, cz + 42.3), (a1, cz + 43.8)
        else:
            lo, hi = (a0, cz - 43.8), (a1, cz - 42.3)
        corners = [L(lo[0], 0, lo[1]), L(hi[0], 0, lo[1]), L(hi[0], 0, hi[1]), L(lo[0], 0, hi[1])]
        slab(me, [(p[0], p[2]) for p in corners], -0.3, 4.0, col("concrete"))
    for k in range(4):
        a, b = ring_pts[k], ring_pts[(k + 1) % 4]
        beam(ms, L(a[0], 17.8, a[1]), L(b[0], 17.8, b[1]), 0.9, 1.6, col("iron"))
    for dx in (-30.0, -18.0, -6.0, 6.0, 18.0, 30.0):
        beam(ms, L(cx + dx, 16.6, cz - 43.0), L(cx + dx, 16.6, cz + 43.0), 0.4, 4.0, col("iron"))
    for wx, wz in cols_w:
        p = L(wx, 0.0, wz)
        box(ms, (p[0] - 0.6, 0.0, p[2] - 0.6), (p[0] + 0.6, 18.6, p[2] + 0.6), col("iron"))

    # ---- far: the tower (a 12-sided frustum and bell) and the drum's rim line
    fe = far["enamel"]
    frustum(fe, tc, 9.0, 7.0, -1.0, 80.0, 12, col("concrete"), caps=(False, False))
    frustum(fe, tc, 7.0, 11.0, 80.0, 87.0, 12, col("concrete_lt"), caps=(False, False))
    frustum(fe, tc, 11.0, 10.2, 87.0, 90.0, 12, col("concrete"), caps=(False, True))
    for k in range(4):
        a, b = ring_pts[k], ring_pts[(k + 1) % 4]
        beam(fe, L(a[0], 2.0, a[1]), L(b[0], 2.0, b[1]), 1.5, 4.0, col("concrete_lt"))
        beam(far["steel"], L(a[0], 17.8, a[1]), L(b[0], 17.8, b[1]), 0.9, 1.6, col("iron"))

    # ---- shells: window slots, gallery brackets, truss gussets (1); tie holes and liner streaks (2)
    s1, s2 = sky.Surf("landmark_penstock_tower_detail1"), sky.Surf("landmark_penstock_tower_detail2")
    for k in range(6):
        a = TAU * (k + 0.5) / 6
        for j in range(6):
            y0 = 8.0 + 12.0 * j
            r = flume_tower_r(y0 + 2.5) + 0.03
            n = (math.sin(a), 0.0, math.cos(a))
            t = (math.cos(a), 0.0, -math.sin(a))
            p = (tc[0] + r * n[0], 0.0, tc[1] + r * n[2])
            card(s1, [vadd(vadd(p, t, -0.6), UP, y0), vadd(vadd(p, t, 0.6), UP, y0), vadd(vadd(p, t, 0.6), UP, y0 + 5.0),
                      vadd(vadd(p, t, -0.6), UP, y0 + 5.0)], col("iron"), n)
    for i in range(16):
        a = TAU * (i + 0.5) / 16
        p0 = (tc[0] + flume_tower_r(80.5) * math.sin(a), 80.5, tc[1] + flume_tower_r(80.5) * math.cos(a))
        p1 = (tc[0] + 11.6 * math.sin(a), 83.3, tc[1] + 11.6 * math.cos(a))
        beam(s1, p0, p1, 0.3, 0.3, col("iron"), caps=False)
    for dx in (-30.0, -18.0, -6.0, 6.0, 18.0, 30.0):
        for dz in (-43.0, 43.0):
            p = L(cx + dx, 16.6, cz + dz * 0.97)
            box(s1, (p[0] - 0.7, 14.4, p[2] - 0.7), (p[0] + 0.7, 18.8, p[2] + 0.7), col("iron_hi"))
    for k in range(30):
        y = 2.0 + 2.7 * k
        a = TAU * rnd(k, 3)
        r = flume_tower_r(y) + 0.02
        n = (math.sin(a), 0.0, math.cos(a))
        t = (math.cos(a), 0.0, -math.sin(a))
        for m in range(4):
            p = (tc[0] + r * math.sin(a + m * 0.35), y, tc[1] + r * math.cos(a + m * 0.35))
            nm = (math.sin(a + m * 0.35), 0.0, math.cos(a + m * 0.35))
            tm = (math.cos(a + m * 0.35), 0.0, -math.sin(a + m * 0.35))
            card(s2, [vadd(vadd(p, tm, -0.12), UP, -0.12), vadd(vadd(p, tm, 0.12), UP, -0.12), vadd(vadd(p, tm, 0.12), UP, 0.12),
                      vadd(vadd(p, tm, -0.12), UP, 0.12)], col("joint"), nm)
    for name, (along, out) in sides.items():
        for k in range(12):
            a = -36.0 + 72.0 * rnd(k, ord(name), 1)
            w = 0.5 + 1.2 * rnd(k, ord(name), 2)
            top = -0.5 - 2.0 * rnd(k, ord(name), 3)
            bot = FLUME_FLOOR + 1.0 + 6.0 * rnd(k, ord(name), 4)
            pts = []
            for aa, y in ((a - w, bot), (a + w, bot), (a + w * 0.5, top), (a - w * 0.5, top)):
                d = d0 + (d1w - d0) * (y - FLUME_FLOOR) / 14.0 - inset - 0.03
                pts.append(L(cx + along[0] * aa + out[0] * d, y, cz + along[1] * aa + out[1] * d))
            card(s2, pts, lerp(col("stain"), col("rust"), rnd(k, ord(name), 5)), vscale(F.dir_local(out[0], out[1]), -1.0))
    empties = {"sight_top": (tc[0], 90.0, tc[1]), "beam_root": (tc[0], 90.0, tc[1]), "warden_anchor": L(*FLUME_ANCHOR)}
    empties.update({k: L(*v) for k, v in hp.items()})
    return {"base": base, "exempt": exempt, "col": colm, "nodes": [], "empties": empties, "mid": mid, "far": far,
            "shells": (s1, s2), "shell_slot": "enamel", "clear": CLEAR}


# ================================================================ card 3: the headframe (park_pit)
# Bake fit (assets/park/park_pit): the pit floor is y -100 (local 0); the collar_dish dips to local -10 at the axis and
# meets the floor at 35 m. Front legs stand at the collar corners and run below the dish (solid to the ground, Andrew
# 2026-10-16); the back legs rake toward the hoist_house row (local (75, 0, 40)) and land on open floor clear of it and
# of the tipple deck. The hive well (|x|, |z| < 6, y 0..38) stays empty; the sheave deck sits at 104.5 under the two
# 14 m wheels, whose tops are sight_top at 120.
PIT_FEET = ((12.0, 10.0), (-12.0, 10.0), (-12.0, -10.0), (12.0, -10.0))
PIT_TOPS = ((6.0, 5.0), (-6.0, 5.0), (-6.0, -5.0), (6.0, -5.0))
PIT_FOOT_Y, PIT_DECK_Y = -12.0, 104.5
PIT_ROPE = (0.882, 0.0, 0.470)          # toward the hoist house, unit
PIT_PERP = (-0.470, 0.0, 0.882)
PIT_WHEEL_Y, PIT_WHEEL_R = 113.0, 7.0
PIT_WELL = (6.0, 0.0, 38.0)             # half width, bottom, top
# The tipple_deck row (park_pit: at [0, 240], y -60, size [24, 2, 16], yaw 180) in this frame: Frame.local(0, -60, 240)
# = (0, 40, 15); the row's yaw less the landmark's is 0, so its length (24) runs along local z and its width (16) along
# x; place_greybox stands the box on the row's y: local x -8..8, y 40..42, z 3..27. The deck plate's top is the row's
# top, 42; its edge stringers sit on the girders (top 39.7) through bearing shims out to x +-8.7.
PIT_DECK_BOX = ((-8.0, 40.0, 3.0), (8.0, 42.0, 27.0))
# The hoist_house row (at [-75, 215], ground y -100, size [44, 16, 26], yaw -63): Frame.local(-75, -100, 215) = (75, 0,
# 40); local yaw = -63 - 180 = -243 = 117 degrees, so its length axis is local (sin 117, 0, cos 117) = (0.891, 0, -0.454)
# (Frame.dir_local of the row's world +Z) and its width axis (cos 117, 0, -sin 117) = (-0.454, 0, -0.891). Half 22 by 13,
# roof 16. The rope ends (hoist, below) lie 12 m from the centre toward the headframe on the plane square to PIT_ROPE;
# the house meets them with a rope slot cut in the roof: the drum wall on that plane (d 12, d along -PIT_ROPE from the
# centre), the slot 2 m deep to d 14, |q| < 5.5 along PIT_PERP, floor at 12. A rope rises 1.49 m per metre of plan back
# toward the wheels, so it clears the slot's far lip (y 17 at d 14) and the roof beyond.
PIT_HOUSE_ROW = ((-75.0, 215.0), -63.0, (44.0, 16.0, 26.0))
PIT_ROPE_END_D = 12.0
# d from, d to, half q, floor y; d is -PIT_ROPE . (p - centre), and PIT_ROPE is unit to 3 places, so the rope ends sit
# at d = 12 |PIT_ROPE|^2 (11.986), where the drum wall stands
PIT_SLOT = (PIT_ROPE_END_D * (PIT_ROPE[0] ** 2 + PIT_ROPE[2] ** 2), 14.0, 5.5, 12.0)


def pit_house():
    """(centre, length axis, width axis, half length, half width, roof) of the hoist house in the landmark frame."""
    F = FRAMES["landmark_headframe"]
    (wx, wz), yaw, size = PIT_HOUSE_ROW
    c = F.local(wx, F.y, wz)
    a = math.radians(yaw)
    ax = F.dir_local(math.sin(a), math.cos(a))
    aw = F.dir_local(math.cos(a), -math.sin(a))
    return c, ax, aw, size[0] / 2, size[2] / 2, size[1]


def clip(poly, n, k):
    """The part of a convex outline [(x, z)] with n . p <= k (Sutherland-Hodgman, one plane)."""
    out = []
    for i, p in enumerate(poly):
        q = poly[(i + 1) % len(poly)]
        dp, dq = n[0] * p[0] + n[1] * p[1] - k, n[0] * q[0] + n[1] * q[1] - k
        if dp <= 0:
            out.append(p)
        if dp * dq < 0:
            t = dp / (dp - dq)
            out.append((p[0] + (q[0] - p[0]) * t, p[1] + (q[1] - p[1]) * t))
    return out


def pit_house_pieces():
    """[(outline, y0, y1)]: the house up to the slot floor, then the roof block round the rope slot (each convex)."""
    c, ax, aw, hl, hw, roof = pit_house()
    rect = [(c[0] + ax[0] * sl * hl + aw[0] * sw * hw, c[2] + ax[2] * sl * hl + aw[2] * sw * hw)
            for sl, sw in ((-1, -1), (1, -1), (1, 1), (-1, 1))]
    d0, d1, hq, floor = PIT_SLOT
    u, p = (-PIT_ROPE[0], -PIT_ROPE[2]), (PIT_PERP[0], PIT_PERP[2])
    du = u[0] * c[0] + u[1] * c[2]
    dp = p[0] * c[0] + p[1] * c[2]
    neg = lambda n: (-n[0], -n[1])
    parts = [(rect, 0.0, floor), (clip(rect, u, du + d0), floor, roof), (clip(rect, neg(u), -du - d1), floor, roof)]
    band = clip(clip(rect, neg(u), -du - d0), u, du + d1)
    parts += [(clip(band, neg(p), -dp - hq), floor, roof), (clip(band, p, dp - hq), floor, roof)]
    return [(o, y0, y1) for o, y0, y1 in parts if len(o) >= 3]


def pit_rope_ends():
    return [vadd(vadd((75.0, 14.0, 40.0), PIT_ROPE, -PIT_ROPE_END_D), PIT_PERP, s * 3.5) for s in (-1, 1)]


def pit_house_solid(s, roof_col, wall_col, slot=True):
    if not slot:
        c, ax, aw, hl, hw, roof = pit_house()
        obox(s, vadd(c, UP, roof / 2), (hw, roof / 2, hl), (aw, UP, ax), wall_col)
        return
    for outline, y0, y1 in pit_house_pieces():
        slab(s, outline, y0, y1, wall_col, roof_col if y1 > PIT_SLOT[3] + 1 else wall_col)


def pit_stack():
    c, ax, aw, hl, hw, roof = pit_house()
    return vadd(vadd(c, ax, 14.0), aw, -6.0)


def pit_leg(i, y):
    t = (y - PIT_FOOT_Y) / (PIT_DECK_Y - PIT_FOOT_Y)
    (fx, fz), (tx, tz) = PIT_FEET[i], PIT_TOPS[i]
    return (fx + (tx - fx) * t, y, fz + (tz - fz) * t)


def pit_back():
    u, p = PIT_ROPE, PIT_PERP
    feet = [vadd(vscale(u, 45.0), p, s * 10.0) for s in (1, -1)]
    tops = [vadd(vscale(u, 6.0), p, s * 5.0) for s in (1, -1)]
    return [((f[0], -2.0, f[2]), (t[0], PIT_DECK_Y, t[2])) for f, t in zip(feet, tops)]


def build_headframe():
    base, exempt, mid, far = View("landmark_headframe"), View("cradle"), View("landmark_headframe_mid"), View("landmark_headframe_far")
    colm = sky.Surf("landmark_headframe-col-col")
    st = base["steel"]
    iron = col("iron")
    # four lattice legs of the front tower, X-braced on its four faces between the legs
    for i in range(4):
        a, b = pit_leg(i, PIT_FOOT_Y), pit_leg(i, PIT_DECK_Y)
        lattice(st, a, b, 1.4, 0.9, 24, iron)
        c0, c1 = pit_leg(i, PIT_FOOT_Y), pit_leg(i, PIT_DECK_Y)
        beam(colm, c0, c1, 2.8, 2.8, iron)
    levels = [-2.0, 14.0, 30.0, 46.0, 62.0, 78.0, 94.0, PIT_DECK_Y - 0.5]
    for k in range(len(levels) - 1):
        y0, y1 = levels[k], levels[k + 1]
        for i in range(4):
            j = (i + 1) % 4
            beam(st, pit_leg(i, y0), pit_leg(j, y1), 0.45, 0.45, col("iron_hi"), caps=False)
            beam(st, pit_leg(j, y0), pit_leg(i, y1), 0.45, 0.45, col("iron_hi"), caps=False)
            beam(st, pit_leg(i, y1), pit_leg(j, y1), 0.6, 0.6, iron)
    # back legs and their ties to the tower
    for (f, t) in pit_back():
        lattice(st, f, t, 1.5, 1.0, 22, iron)
        beam(colm, f, t, 3.0, 3.0, iron)
        for y in (40.0, 76.0):
            tt = (y - f[1]) / (t[1] - f[1])
            pb = vlerp(f, t, tt)
            near = min(range(4), key=lambda i: vlen(vsub(pit_leg(i, y), pb)))
            beam(st, pb, pit_leg(near, y), 0.5, 0.5, col("iron_hi"), caps=False)
    (fa, ta), (fb, tb) = pit_back()
    for y in (20.0, 52.0, 84.0):
        pa = vlerp(fa, ta, (y - fa[1]) / (ta[1] - fa[1]))
        pb = vlerp(fb, tb, (y - fb[1]) / (tb[1] - fb[1]))
        beam(st, pa, pb, 0.5, 0.5, col("iron_hi"), caps=False)
    # sheave deck with a rope hole, stools and the two wheels; sight_top on the wheel tops
    dy0, dy1 = PIT_DECK_Y, PIT_DECK_Y + 1.5
    for lo, hi in (((-8.0, -7.0), (-2.0, 7.0)), ((2.0, -7.0), (8.0, 7.0)), ((-2.0, -7.0), (2.0, -2.0)), ((-2.0, 2.0), (2.0, 7.0))):
        box(st, (lo[0], dy0, lo[1]), (hi[0], dy1, hi[1]), col("iron_hi"))
    box(colm, (-8.0, dy0, -7.0), (8.0, dy1, 7.0), iron)
    axle_a = vadd((0.0, PIT_WHEEL_Y, 0.0), PIT_PERP, -5.4)
    axle_b = vadd((0.0, PIT_WHEEL_Y, 0.0), PIT_PERP, 5.4)
    tube(st, axle_a, axle_b, 0.45, 8, col("iron_hi"))
    for s in (-1, 1):
        c = vadd((0.0, PIT_WHEEL_Y, 0.0), PIT_PERP, s * 3.5)
        wheel(st, c, PIT_PERP, PIT_WHEEL_R, 0.55, 10, 32, iron, col("copper"))
        for k in (-1, 1):
            foot = vadd((c[0], dy1, c[2]), PIT_ROPE, k * 3.0)
            beam(st, foot, vadd((c[0], PIT_WHEEL_Y - 0.6, c[2]), PIT_PERP, s * 1.4), 0.6, 0.6, iron)
        blk = vadd((0.0, PIT_WHEEL_Y, 0.0), PIT_PERP, s * 5.0)
        box(st, (blk[0] - 0.7, PIT_WHEEL_Y - 0.9, blk[2] - 0.7), (blk[0] + 0.7, PIT_WHEEL_Y + 0.9, blk[2] + 0.7), col("copper"))
        a = vadd(vadd(c, PIT_ROPE, PIT_WHEEL_R - 0.3), UP, 0.0)
        hoist = vadd(vadd((75.0, 14.0, 40.0), PIT_ROPE, -12.0), PIT_PERP, s * 3.5)
        tube(st, a, hoist, 0.22, 4, col("cable"))
    # shaft collar: a steel frame round the hive well, flush on the dish
    for lo, hi in (((-8.5, -8.5), (8.5, -6.5)), ((-8.5, 6.5), (8.5, 8.5)), ((-8.5, -6.5), (-6.5, 6.5)), ((6.5, -6.5), (8.5, 6.5))):
        box(st, (lo[0], -9.78, lo[1]), (hi[0], -9.7, hi[1]), col("iron_hi"))
    # tipple girders: under the tipple deck row's long edges (local x +-8, z 3..27, base y 40), cantilevered off the legs
    for sx in (-1, 1):
        root = pit_leg(0 if sx > 0 else 1, 39.2)
        beam(st, (sx * 8.4, 39.2, root[2]), (sx * 8.4, 39.2, 27.5), 0.6, 1.0, iron)
        beam(st, root, (sx * 8.4, 39.2, root[2]), 0.6, 1.0, iron)
        beam(st, pit_leg(0 if sx > 0 else 1, 18.0), (sx * 8.4, 38.7, 22.0), 0.5, 0.5, col("iron_hi"))
    for z in (12.0, 20.0, 27.0):
        beam(st, (-8.4, 38.9, z), (8.4, 38.9, z), 0.4, 0.5, col("iron_hi"), caps=False)
    # tipple deck (PIT_DECK_BOX): plate, edge stringers on bearing shims over the girders, floor beams, end channels
    (dx0, dyb, dz0), (dx1, dyt, dz1) = PIT_DECK_BOX
    box(st, (dx0, dyt - 0.4, dz0), (dx1, dyt, dz1), col("steel"))
    for sx in (-1, 1):
        box(st, (min(sx * 7.7, sx * 8.0), 39.7, dz0), (max(sx * 7.7, sx * 8.0), dyt - 0.4, dz1), iron)
        for z in (4.0, 9.0, 15.0, 21.0, 26.0):
            box(st, (min(sx * 7.7, sx * 8.7), 39.7, z - 0.3), (max(sx * 7.7, sx * 8.7), 40.0, z + 0.3), col("iron_hi"))
    for z in (dz0 + 0.2, 7.0, 11.0, 15.0, 19.0, 23.0, dz1 - 0.2):
        box(st, (-7.7, dyb + 0.2, z - 0.2), (7.7, dyt - 0.4, z + 0.2), col("iron_hi"))
    box(colm, (dx0, dyb, dz0), (dx1, dyt, dz1), iron)
    # hoist house (pit_house): corrugated walls, rust roof round the rope slot, the drum window on the slot's back wall
    # facing the headframe, a boiler stack with two bands and a cap
    hc, hax, haw, hhl, hhw, hroof = pit_house()
    pit_house_solid(st, col("rust"), col("steel"))
    pit_house_solid(colm, iron, iron, slot=False)
    d0, d1, hq, floor = PIT_SLOT
    wall = vadd(hc, PIT_ROPE, -(d0 + 0.03))
    win = lambda q, y: vadd(vadd((wall[0], y, wall[2]), PIT_PERP, q), UP, 0.0)
    card(st, [win(-4.6, floor + 0.4), win(4.6, floor + 0.4), win(4.6, hroof - 0.5), win(-4.6, hroof - 0.5)], col("iron"), vscale(PIT_ROPE, -1.0))
    for q in (-4.6, -1.55, 1.55, 4.6):
        beam(st, win(q, floor + 0.4), win(q, hroof - 0.5), 0.22, 0.22, col("copper"))
    for y in (floor + 0.4, hroof - 0.5):
        beam(st, win(-4.6, y), win(4.6, y), 0.22, 0.22, col("copper"))
    sc = pit_stack()
    frustum(st, (sc[0], sc[2]), 1.0, 0.85, hroof - 0.2, 34.0, 10, col("iron"))
    for y in (22.0, 29.0):
        frustum(st, (sc[0], sc[2]), 1.0, 1.0, y, y + 0.5, 10, col("rust"))
    frustum(st, (sc[0], sc[2]), 1.15, 1.15, 33.4, 34.4, 10, col("iron_hi"))
    frustum(colm, (sc[0], sc[2]), 1.0, 0.85, hroof - 0.2, 34.0, 8, iron)

    # ---- mid: box legs with cross braces, the deck, 16-segment wheel discs, ropes
    ms = mid["steel"]
    for i in range(4):
        beam(ms, pit_leg(i, PIT_FOOT_Y), pit_leg(i, PIT_DECK_Y), 2.4, 2.4, iron)
    for k in range(len(levels) - 1):
        for i in range(4):
            j = (i + 1) % 4
            beam(ms, pit_leg(i, levels[k]), pit_leg(j, levels[k + 1]), 0.6, 0.6, col("iron_hi"), caps=False)
            beam(ms, pit_leg(j, levels[k]), pit_leg(i, levels[k + 1]), 0.6, 0.6, col("iron_hi"), caps=False)
    for (f, t) in pit_back():
        beam(ms, f, t, 2.6, 2.6, iron)
    box(ms, (-8.0, dy0, -7.0), (8.0, dy1, 7.0), col("iron_hi"))
    for s in (-1, 1):
        c = vadd((0.0, PIT_WHEEL_Y, 0.0), PIT_PERP, s * 3.5)
        u, v = frame(PIT_PERP)
        ring = [vadd(vadd(c, u, PIT_WHEEL_R * math.cos(TAU * k / 16)), v, PIT_WHEEL_R * math.sin(TAU * k / 16)) for k in range(16)]
        ms.ring_solid([vadd(p, PIT_PERP, -0.3) for p in ring], [vadd(p, PIT_PERP, 0.3) for p in ring], iron)
        hoist = vadd(vadd((75.0, 14.0, 40.0), PIT_ROPE, -12.0), PIT_PERP, s * 3.5)
        tube(ms, vadd(c, PIT_ROPE, PIT_WHEEL_R - 0.3), hoist, 0.3, 3, col("cable"))
    box(ms, PIT_DECK_BOX[0], PIT_DECK_BOX[1], col("steel"))
    pit_house_solid(ms, col("rust"), col("steel"))
    frustum(ms, (sc[0], sc[2]), 1.0, 0.85, hroof - 0.2, 34.0, 8, col("iron"))

    # ---- far: four box legs, the back legs, the deck and both wheel discs (the A-and-wheels read)
    fs = far["steel"]
    for i in range(4):
        beam(fs, pit_leg(i, PIT_FOOT_Y), pit_leg(i, PIT_DECK_Y), 2.6, 2.6, iron)
    for (f, t) in pit_back():
        beam(fs, f, t, 2.8, 2.8, iron)
    for y in (30.0, 62.0, 94.0):
        for i in range(4):
            beam(fs, pit_leg(i, y), pit_leg((i + 1) % 4, y), 0.8, 0.8, iron, caps=False)
    box(fs, (-8.0, dy0, -7.0), (8.0, dy1, 7.0), iron)
    for s in (-1, 1):
        c = vadd((0.0, PIT_WHEEL_Y, 0.0), PIT_PERP, s * 3.5)
        u, v = frame(PIT_PERP)
        ring = [vadd(vadd(c, u, PIT_WHEEL_R * math.cos(TAU * k / 12)), v, PIT_WHEEL_R * math.sin(TAU * k / 12)) for k in range(12)]
        fs.ring_solid([vadd(p, PIT_PERP, -0.3) for p in ring], [vadd(p, PIT_PERP, 0.3) for p in ring], iron)
    pit_house_solid(fs, None, col("steel"), slot=False)

    # ---- shells: ladder and gusset plates (1); rivet rows (2)
    s1, s2 = sky.Surf("landmark_headframe_detail1"), sky.Surf("landmark_headframe_detail2")
    for k in range(len(levels)):
        for i in range(4):
            p = pit_leg(i, levels[k])
            box(s1, (p[0] - 1.9, p[1] - 0.9, p[2] - 1.9), (p[0] + 1.9, p[1] + 0.9, p[2] + 1.9), col("iron_hi"))
    for side in (-0.5, 0.5):
        a, b = pit_leg(3, PIT_FOOT_Y + 2.0), pit_leg(3, PIT_DECK_Y)
        off = (2.0, 0.0, side - 1.6)
        beam(s1, vadd(a, off), vadd(b, off), 0.1, 0.1, col("iron_hi"), caps=False)
    for k in range(0, 112, 3):
        y = PIT_FOOT_Y + 2.0 + k
        p = pit_leg(3, y)
        beam(s1, vadd(p, (2.0, 0.0, -2.1)), vadd(p, (2.0, 0.0, -1.1)), 0.06, 0.06, col("iron_hi"), caps=False)
    for x0, x1, z in ((-8.0, 8.0, 7.0), (-8.0, 8.0, -7.0)):
        beam(s1, (x0, dy1 + 1.1, z), (x1, dy1 + 1.1, z), 0.08, 0.08, col("iron_hi"), caps=False)
        for k in range(9):
            x = x0 + 2.0 * k
            beam(s1, (x, dy1, z), (x, dy1 + 1.1, z), 0.06, 0.06, col("iron_hi"), caps=False)
    # corrugation ribs every 2 m on the two house walls facing the headframe (+width and -length), under the slot floor
    for axis, half, along, span in ((haw, hhw, hax, hhl), (hax, -hhl, haw, hhw)):
        n = int(span)
        for k in range(-n + 1, n, 2):
            foot = vadd(vadd(hc, axis, half + (0.04 if half > 0 else -0.04)), along, float(k))
            beam(s1, vadd(foot, UP, 0.3), vadd(foot, UP, floor - 0.3), 0.12, 0.08, col("iron_hi"), caps=False)
    for k in range(len(levels)):
        for i in range(4):
            p = pit_leg(i, levels[k])
            for m in range(3):
                q = vadd(p, (-1.0 + m, 0.95, 2.0 if p[2] > 0 else -2.0))
                box(s2, vsub(q, (0.09, 0.09, 0.09)), vadd(q, (0.09, 0.09, 0.09)), col("copper_dk"))
    # rivet rows on the tipple deck's edge stringers
    for sx in (-1, 1):
        for k in range(12):
            q = (sx * 8.05, 40.8, 4.0 + 2.0 * k)
            box(s2, vsub(q, (0.07, 0.07, 0.07)), vadd(q, (0.07, 0.07, 0.07)), col("copper_dk"))
    empties = {"sight_top": (0.0, PIT_WHEEL_Y + PIT_WHEEL_R, 0.0), "warden_anchor": (0.0, 4.0, 0.0),
               "hoist_high": (0.0, 34.0, 0.0), "sheave_rope": (0.0, 110.0, 0.0)}
    return {"base": base, "exempt": exempt, "col": colm, "nodes": [], "empties": empties, "mid": mid, "far": far,
            "shells": (s1, s2), "shell_slot": "steel", "clear": CLEAR}


# ================================================================ card 4: the sinkhole (park_sinkhole)
# Bake fit (assets/park/park_sinkhole): the collapse is a U, not a round hole. The floor is flat at y -100 for 50 m
# round the axis and out to the walls; the walls are planes, x = +-(124 + 0.02 (y + 100)) east and west from local z
# -100 to 48, and z = 48 + 0.02 (y + 100) to the south; the U opens north toward the tubes. Stains and strata are cards on
# those planes 0.08 m inside; coping lies on the rims where the plateau reads y 0 (the east and west rims from local z
# -50, the south rim within x +-104). The gallery ring is full (Andrew 2026-10-16): timber decking round the pool from r
# 42 to 49, its top 0.1 m over the floor, so it needs no collider and moves no line. The pool cylinder (r 40, y -120 to
# -100) stays empty. Refit to the sinkhole bake of 2026-10-17 (claude/sinkhole-bake-rkry23, rows gallery_ring to
# gallery_ring_24, gallery_cut_1 to _15, gallery_post_1 to _11): the ring lane runs r 46 to 61, so the deck spans it and
# the lamps stand inside it at r LAMP_R; the south wall is cut back into an alcove (SINK_ALCOVE, the floor line where the
# bake's wall meets y -100, sampled every 3 m, the same 0.02 lean as the planes). The nest's comb hangs on a timber gantry
# over the lane at the anchor (legs on the caisson lip and behind the ring, nothing in the lane below SINK_LANE_TOP), and
# its cells carry on into the alcove wall. The headgear stands east of the pump gallery (now at x 73), over its far end.
SINK_FLOOR = -100.0
SINK_RING = (46.0, 61.0)
SINK_LANE_TOP = -92.0
SINK_POOL = (40.0, -120.0, -100.0)
SINK_ANCHOR = (0.0, -99.0, 38.0)
LAMP_R = 44.2
SINK_HEAD_X = 100.0
# The tube mouths' wash stamps (main_tube_lower_11, east_haulage_11) cut a trough through the north ring, down to y
# -107.8; the deck, its seams and its lamps stop at the trough's bearings (degrees, sampled at bake 49b06209).
SINK_WASH = (math.radians(142.0), math.radians(183.0))


def sink_in_wash(a):
    return SINK_WASH[0] <= a % TAU <= SINK_WASH[1]
SINK_ALCOVE = [(0.0, 66.0), (12.0, 66.0), (15.0, 65.0), (18.0, 64.0), (21.0, 63.0), (24.0, 62.0), (27.0, 61.0),
               (30.0, 60.0), (33.0, 59.0), (36.0, 58.0), (39.0, 55.0), (42.0, 54.0), (45.0, 49.0), (46.5, 48.0)]


def sink_wall_x(y):
    return 124.0 + 0.02 * (y - SINK_FLOOR)


def sink_wall_z(y, x=None):
    """The south wall at height y: the plane z 48, or the alcove's floor line where x falls inside it."""
    z = 48.0
    ax = abs(x) if x is not None else 99.0
    for (xa, za), (xb, zb) in zip(SINK_ALCOVE, SINK_ALCOVE[1:]):
        if xa <= ax <= xb:
            z = max(z, za + (zb - za) * (ax - xa) / (xb - xa))
    return z + 0.02 * (y - SINK_FLOOR)


def sink_south_xs(step):
    """Column breaks along the south wall: the planes in about step-metre columns, the alcove at its sampled knots."""
    edge = sink_wall_x(-97.0) - 0.4
    n = max(1, round((edge - SINK_ALCOVE[-1][0]) / step))
    plane = [SINK_ALCOVE[-1][0] + (edge - SINK_ALCOVE[-1][0]) * i / n for i in range(n + 1)]
    knots = [x for x, _ in SINK_ALCOVE][::1 if step <= 12.0 else 2]
    if knots[-1] != SINK_ALCOVE[-1][0]:
        knots.append(SINK_ALCOVE[-1][0])
    half = sorted(set(knots[1:] + plane))
    return [-x for x in reversed(half)] + [0.0] + half


def sink_south_normal(xa, xb):
    """The horizontal normal into the hole of the south wall between xa and xb."""
    dz = sink_wall_z(SINK_FLOOR, xb) - sink_wall_z(SINK_FLOOR, xa)
    return sky.norm((dz, 0.0, -(xb - xa)))


STRATA_SINK = [("basalt_dk", 4.0), ("basalt", 6.0), ("lime_dk", 3.0), ("lime", 9.0), ("ochre", 2.5), ("lime", 7.0),
               ("lime_dk", 4.0), ("lime", 11.0), ("mangan", 1.5), ("lime", 8.0), ("lime_dk", 5.0), ("lime", 10.0),
               ("ochre", 3.0), ("lime", 12.0), ("lime_dk", 14.0)]


def sink_band(y):
    d = -y
    acc = 0.0
    for name, th in STRATA_SINK:
        acc += th
        if d < acc:
            return name
    return STRATA_SINK[-1][0]


def sink_walls(s, cols, rows, inset, color_fn, y_top=-3.0, y_bot=-97.0):
    """Covers the three wall planes with a grid of cards; color_fn(wall, i, j, y_mid) paints them."""
    walls = []
    for sx in (-1, 1):
        z0, z1 = -100.0, sink_wall_z(y_bot) - 0.4
        walls.append((("E" if sx > 0 else "W"), lambda a, y, sx=sx: (sx * (sink_wall_x(y) - inset), y, a), z0, z1, (-sx, 0.0, 0.0)))
    for name, at, a0, a1, normal in walls:
        n_cols = max(4, int(cols * 0.6))
        for i in range(n_cols):
            for j in range(rows):
                aa, ab = a0 + (a1 - a0) * i / n_cols, a0 + (a1 - a0) * (i + 1) / n_cols
                ya, yb = y_bot + (y_top - y_bot) * j / rows, y_bot + (y_top - y_bot) * (j + 1) / rows
                c = color_fn(name, i, j, (ya + yb) / 2)
                card(s, [at(aa, ya), at(ab, ya), at(ab, yb), at(aa, yb)], c, normal)
    # the south wall follows the alcove: one card per column break, each facing into the hole
    xs = sink_south_xs(2.0 * sink_wall_x(y_bot) / cols)
    at = lambda a, y: (a, y, sink_wall_z(y, a) - inset)
    for i, (aa, ab) in enumerate(zip(xs, xs[1:])):
        normal = sink_south_normal(aa, ab)
        for j in range(rows):
            ya, yb = y_bot + (y_top - y_bot) * j / rows, y_bot + (y_top - y_bot) * (j + 1) / rows
            c = color_fn("S", i, j, (ya + yb) / 2)
            card(s, [at(aa, ya), at(ab, ya), at(ab, yb), at(aa, yb)], c, normal)


def sink_alcove_rim(s, step, color_fn):
    """Coping slabs on the plateau round the alcove's rim (top 0.08 m over grade, no collider), step metres apart."""
    xs = [x for x in sink_south_xs(step) if abs(x) <= SINK_ALCOVE[-1][0]]
    for k, (xa, xb) in enumerate(zip(xs, xs[1:])):
        n = sink_south_normal(xa, xb)
        za, zb = sink_wall_z(0.0, xa) + 0.1, sink_wall_z(0.0, xb) + 0.1
        w = 2.4 + 1.6 * rnd(k, 24)
        slab(s, [(xa, za), (xb, zb), (xb - n[0] * w, zb - n[2] * w), (xa - n[0] * w, za - n[2] * w)], -0.6, 0.08, color_fn(k))


# The trestle: a timber span over the wash trough, closing the ring (Andrew 16 Oct: "sinkhole a full ring"). It follows the
# deck's arc from bearing 142 to 183, planked flush with the deck (top SINK_FLOOR + 0.1) and slung on four fish-belly
# stringers whose soffit sags 0.9 m at mid-span, so the span's lowest timber is y -101.44, 6.3 m over the trough floor at
# -107.8. Two bents (three legs, a cap beam, knee braces) stand on the trough's flanks, 0.6 degrees (0.5 to 0.6 m) inside the
# sampled bearings 142 and 183, and their legs run down to the floor at -107.8; the span between them carries no support, so
# the ball's line down the trough stays open. Visual only: nothing here enters the -col mesh.
TRESTLE_N = 30
TRESTLE_PLANK = 0.14
TRESTLE_STRINGERS = (47.2, 51.4, 55.6, 59.8)
TRESTLE_SAG = 0.9
TRESTLE_DEPTH = 0.5
TRESTLE_BENT_INSET = math.radians(0.6)
TRESTLE_LEG_FOOT = -107.8


def sink_pt(r, t, y):
    return (r * math.sin(t), y, r * math.cos(t))


def sink_trestle(e, ex, mid):
    """e: the base enamel surface (substructure), ex: the flush deck's, mid: the mid view's enamel."""
    a0, a1 = SINK_WASH
    top = SINK_FLOOR + 0.1
    seat = top - TRESTLE_PLANK
    r0, r1 = SINK_RING
    at = lambda u: a0 + (a1 - a0) * u
    for i in range(TRESTLE_N):
        ta, tb = at(i / TRESTLE_N), at((i + 1) / TRESTLE_N)
        c = shade("timber" if i % 3 else "timber_dk", 1.0, (i, 42), 0.08)
        lo = [sink_pt(r0, ta, seat), sink_pt(r1, ta, seat), sink_pt(r1, tb, seat), sink_pt(r0, tb, seat)]
        hi = [sink_pt(r0, ta, top), sink_pt(r1, ta, top), sink_pt(r1, tb, top), sink_pt(r0, tb, top)]
        ex.ring_solid(lo, hi, c)
    segs = 10
    for r in TRESTLE_STRINGERS:
        for k in range(segs):
            rings = []
            for u in (k / segs, (k + 1) / segs):
                t, bot = at(u), seat - TRESTLE_DEPTH - TRESTLE_SAG * math.sin(math.pi * u)
                rings.append([sink_pt(r - 0.25, t, bot), sink_pt(r + 0.25, t, bot), sink_pt(r + 0.25, t, seat),
                              sink_pt(r - 0.25, t, seat)])
            e.ring_solid(rings[0], rings[1], col("timber_dk"), (k == 0, k == segs - 1))
    for k in range(7):
        t = at((k + 0.5) / 7)
        beam(e, sink_pt(r0 + 0.3, t, seat - 0.2), sink_pt(r1 - 0.3, t, seat - 0.2), 0.3, 0.36, col("timber_lt"), caps=True)
    legs = (47.5, 53.5, 59.5)
    for tb, inward in ((a0 + TRESTLE_BENT_INSET, 1.0), (a1 - TRESTLE_BENT_INSET, -1.0)):
        cap = seat - TRESTLE_DEPTH
        beam(e, sink_pt(r0 + 0.3, tb, cap - 0.28), sink_pt(r1 - 0.3, tb, cap - 0.28), 0.7, 0.56, col("timber"))
        for r in legs:
            beam(e, sink_pt(r, tb, TRESTLE_LEG_FOOT), sink_pt(r, tb, cap), 0.6, 0.6, col("timber"))
            tk = tb + inward * math.radians(3.0)
            beam(e, sink_pt(r, tb, cap - 2.6), sink_pt(r, tk, seat - TRESTLE_DEPTH - 0.2), 0.3, 0.3, col("timber_lt"))
    # mid view: the planks and the four stringers as single runs
    annulus(mid, (0.0, 0.0), r0, r1, seat, top, 10, lambda i: col("timber"), arc=SINK_WASH, sides=False)
    bot = lambda u: seat - TRESTLE_DEPTH - TRESTLE_SAG * math.sin(math.pi * u)
    for r in TRESTLE_STRINGERS:
        for k in range(4):
            ta, tb = at(k / 4), at((k + 1) / 4)
            mid.ring_solid([sink_pt(r - 0.3, ta, bot(k / 4)), sink_pt(r + 0.3, ta, bot(k / 4)), sink_pt(r + 0.3, ta, seat), sink_pt(r - 0.3, ta, seat)],
                           [sink_pt(r - 0.3, tb, bot((k + 1) / 4)), sink_pt(r + 0.3, tb, bot((k + 1) / 4)), sink_pt(r + 0.3, tb, seat), sink_pt(r - 0.3, tb, seat)],
                           col("timber_dk"), (False, False))


def build_sinkhole():
    base, exempt, mid, far = View("landmark_sinkhole"), View("flush"), View("landmark_sinkhole_mid"), View("landmark_sinkhole_far")
    colm = sky.Surf("landmark_sinkhole-col-col")
    sto, e, st, ln = base["stone"], base["enamel"], base["steel"], base["ancient_lens"]
    # strata cards: basalt cap over pale limestone, painted near-white for the stone slot's beds to multiply
    wall_colour = lambda name, i, j, y: shade(sink_band(y), 1.0, (i, j, ord(name)), 0.05)
    sink_walls(sto, 20, 16, 0.08, wall_colour, y_top=-0.6)
    # mineral stains over the strata: iron, ochre, calcite, manganese, a few verdigris
    stains = ("oxide", "ochre", "calcite", "mangan", "verdigris", "rust")
    for k in range(70):
        wall = ("E", "W", "S")[k % 3]
        w = 0.8 + 2.4 * rnd(k, 1)
        top = -1.5 - 18.0 * rnd(k, 2)
        bot = top - 20.0 - 70.0 * rnd(k, 3)
        bot = max(bot, -97.0)
        c = lerp(col(stains[int(rnd(k, 4) * len(stains)) % len(stains)]), col("lime_dk"), 0.55)
        if wall == "S":
            a = -100.0 + 200.0 * rnd(k, 5)
            pts = [(a - w, bot, sink_wall_z(bot, a - w) - 0.14), (a + w, bot, sink_wall_z(bot, a + w) - 0.14),
                   (a + w * 0.4, top, sink_wall_z(top, a + w * 0.4) - 0.14), (a - w * 0.4, top, sink_wall_z(top, a - w * 0.4) - 0.14)]
            card(sto, pts, c, sink_south_normal(a - w, a + w))
        else:
            sx = 1 if wall == "E" else -1
            a = -95.0 + 140.0 * rnd(k, 5)
            pts = [(sx * (sink_wall_x(bot) - 0.14), bot, a - w), (sx * (sink_wall_x(bot) - 0.14), bot, a + w),
                   (sx * (sink_wall_x(top) - 0.14), top, a + w * 0.4), (sx * (sink_wall_x(top) - 0.14), top, a - w * 0.4)]
            card(sto, pts, c, (-sx, 0.0, 0.0))
    # rim coping: broken basalt slabs on the plateau along the edge, top 0.08 m over grade, no collider
    def coping(s, a0, a1, step, place, seed):
        k = 0
        a = a0
        while a < a1 - 0.5:
            ln = min(step * (0.7 + 0.6 * rnd(seed, k, 1)), a1 - a)
            w = 2.4 + 1.6 * rnd(seed, k, 2)
            jit = [(rnd(seed, k, 3 + m) - 0.5) * 0.6 for m in range(4)]
            quad = [place(a + jit[0], 0.0 + 0.0 * jit[1]), place(a + ln + jit[2], 0.0), place(a + ln + jit[3], w), place(a + jit[1], w)]
            slab(s, quad, -0.6, 0.08, shade("basalt", 1.0, (seed, k, 9), 0.1))
            a += ln + 0.25
            k += 1
    for sx in (-1, 1):
        coping(sto, -50.0, 48.0, 5.0, lambda a, w, sx=sx: (sx * (126.1 + w), a), 10 + sx)
    for sx in (-1, 1):
        coping(sto, SINK_ALCOVE[-1][0] + 0.6, 104.0, 5.0, lambda a, w, sx=sx: (sx * a, 50.1 + w), 20 + sx)
    sink_alcove_rim(sto, 3.0, lambda k: shade("basalt", 1.0, (k, 23), 0.1))
    # the full gallery ring round the pool: radial planks on sleepers, flush (FLUSH-safe), with lamp posts
    fe = exempt["enamel"]
    deck_arc = (SINK_WASH[1], SINK_WASH[0] + TAU)
    annulus(fe, (0.0, 0.0), SINK_RING[0], SINK_RING[1], SINK_FLOOR, SINK_FLOOR + 0.1, 106, arc=deck_arc, color_fn=
            lambda i: shade("timber" if i % 3 else "timber_dk", 1.0, (i, 41), 0.08))
    sink_trestle(e, fe, mid["enamel"])
    # the caisson lip: a riveted steel band set flush just outside the pool
    annulus(exempt["steel"], (0.0, 0.0), SINK_POOL[0] + 0.15, SINK_POOL[0] + 1.1, SINK_FLOOR, SINK_FLOOR + 0.08, 64,
            lambda i: shade("steel", 1.0, (i, 51), 0.06))
    for k in range(16):
        a = TAU * (k + 0.5) / 16
        if sink_in_wash(a):
            continue
        p = (LAMP_R * math.sin(a), SINK_FLOOR + 0.1, LAMP_R * math.cos(a))
        box(e, (p[0] - 0.12, p[1], p[2] - 0.12), (p[0] + 0.12, p[1] + 2.6, p[2] + 0.12), col("timber_dk"))
        box(e, (p[0] - 0.35, p[1] + 2.6, p[2] - 0.35), (p[0] + 0.35, p[1] + 3.1, p[2] + 0.35), col("amber"))
    # copper anchor eyes where the anchor rows ring_post_w and ring_post_e stand (the swarm's hardpoints; the loader
    # builds no post inside the landmark's footprint): rings set flush in the deck, so the lane stays open
    for sx in (-1, 1):
        annulus(exempt["steel"], (sx * 20.0, 43.0), 0.45, 0.9, SINK_FLOOR, SINK_FLOOR + 0.11, 12,
                lambda i: col("copper") if i % 2 else col("copper_dk"))
    # headgear: two timber A-frames, a cap beam and a sheave over the pump gallery's far end
    hx = SINK_HEAD_X
    for z in (-11.0, 11.0):
        for x in (hx - 8.0, hx + 8.0):
            beam(e, (x, SINK_FLOOR - 1.0, z), (hx, -72.0, z), 0.9, 0.9, col("timber"))
            beam(colm, (x, SINK_FLOOR - 1.0, z), (hx, -72.0, z), 0.9, 0.9, col("timber"))
        beam(e, (hx - 5.0, -90.0, z), (hx + 5.0, -90.0, z), 0.6, 0.6, col("timber_dk"))
    beam(e, (hx, -71.4, -12.0), (hx, -71.4, 12.0), 1.0, 1.2, col("timber_dk"))
    wheel(st, (hx, -68.6, 0.0), (0.0, 0.0, 1.0), 2.4, 0.3, 6, 16, col("iron"), col("copper"))
    tube(st, (hx - 2.4, -68.6, 0.0), (78.0, -94.0, 0.0), 0.12, 4, col("cable"))
    # the nest socket on the south wall: broken hex cells, green rims on the central ones, timbers through them
    cells = []
    for i in range(-9, 10):
        for j in range(0, 9):
            x = i * 1.9 + (0.95 if j % 2 else 0.0)
            y = SINK_FLOOR + 1.2 + j * 1.65
            if abs(x) > 17.0 - j * 0.9 or rnd(i, j, 61) < 0.18:
                continue
            cells.append((x, y, i, j))
    for x, y, i, j in cells:
        depth = 0.6 + 1.4 * rnd(i, j, 62)
        z = sink_wall_z(y, x) - 0.05
        dist = math.sqrt(x * x + (y - SINK_ANCHOR[1]) ** 2 + (z - depth - SINK_ANCHOR[2]) ** 2)
        if dist < CLEAR + 0.3:
            depth = max(0.2, depth - (CLEAR + 0.3 - dist))
        central = abs(x) < 5.0 and j < 5
        hexcell(sto, (x, y, z), (0.0, 0.0, -1.0), 0.92, depth, shade("basalt_dk", 1.0, (i, j, 63), 0.12),
                rim=(ln, col("lens")) if central and rnd(i, j, 64) > 0.35 else None, open_end=rnd(i, j, 65) > 0.6)
    for k in range(6):
        x = -14.0 + 28.0 * rnd(k, 66)
        y = SINK_FLOOR + 3.0 + 9.0 * rnd(k, 67)
        beam(e, (x, y, sink_wall_z(y, x) - 0.1), (x + 2.5 * (rnd(k, 68) - 0.5), y - 1.5, sink_wall_z(y, x) - 2.2), 0.4, 0.4, col("timber_dk"))
    # the comb over the lane: a timber gantry with legs on the caisson lip (r 44) and behind the ring (r 64), cap beams
    # at y -83, and a hex comb hung from the front beam facing the anchor; nothing in the lane below SINK_LANE_TOP
    gx, gz0, gz1, gy = 10.5, 42.6, 63.5, -83.0
    for sx in (-1, 1):
        for z in (gz0, gz1):
            beam(e, (sx * gx, SINK_FLOOR, z), (sx * gx, gy, z), 0.7, 0.7, col("timber"))
        beam(e, (sx * gx, gy, gz0 - 0.4), (sx * gx, gy, gz1 + 0.4), 0.8, 0.9, col("timber_dk"))
        beam(e, (sx * gx, gy - 4.0, gz1), (sx * gx, gy - 0.5, gz1 - 3.5), 0.4, 0.4, col("timber_dk"))
        beam(e, (sx * gx, gy - 4.0, gz0), (sx * gx, gy - 0.5, gz0 + 3.5), 0.4, 0.4, col("timber_dk"))
        box(e, (sx * gx - 0.35, gy + 0.45, gz1 - 0.35), (sx * gx + 0.35, gy + 0.95, gz1 + 0.35), col("amber"))
    for z in (gz0, 44.6, gz1):
        beam(e, (-gx - 0.4, gy, z), (gx + 0.4, gy, z), 0.8, 0.9, col("timber_dk"))
    box(sto, (-8.0, -93.0, 44.6), (8.0, gy - 0.45, 45.0), shade("basalt_dk", 0.8, (0, 69), 0.0))
    for i in range(-4, 5):
        for j in range(6):
            x = i * 1.9 + (0.95 if j % 2 else 0.0)
            y = -92.0 + j * 1.65
            if abs(x) > 7.0 or rnd(i, j, 70) < 0.12:
                continue
            depth = 0.4 + 0.8 * rnd(i, j, 71)
            dist = math.sqrt(x * x + (y - SINK_ANCHOR[1]) ** 2 + (44.6 - depth - SINK_ANCHOR[2]) ** 2)
            if dist < CLEAR + 0.3:
                depth = max(0.2, depth - (CLEAR + 0.3 - dist))
            hexcell(sto, (x, y, 44.6), (0.0, 0.0, -1.0), 0.92, depth, shade("basalt_dk", 1.0, (i, j, 72), 0.12),
                    rim=(ln, col("lens")) if abs(x) < 4.0 and rnd(i, j, 73) > 0.3 else None, open_end=rnd(i, j, 74) > 0.5)

    # ---- mid: coping, coarse strata, the ring deck, the caisson band, the headgear's outline
    sink_walls(mid["stone"], 6, 5, 0.08, wall_colour, y_top=-0.6)
    annulus(mid["enamel"], (0.0, 0.0), SINK_RING[0], SINK_RING[1], SINK_FLOOR, SINK_FLOOR + 0.1, 42, lambda i: col("timber"),
            arc=deck_arc, sides=False)
    annulus(mid["steel"], (0.0, 0.0), SINK_POOL[0] + 0.15, SINK_POOL[0] + 1.1, SINK_FLOOR, SINK_FLOOR + 0.08, 32, lambda i: col("steel"), sides=False)
    for sx in (-1, 1):
        box(mid["stone"], (min(sx * 126.1, sx * 129.0), -0.6, -50.0), (max(sx * 126.1, sx * 129.0), 0.08, 48.0), col("basalt"))
    for sx in (-1, 1):
        box(mid["stone"], (min(sx * 47.1, sx * 104.0), -0.6, 50.1), (max(sx * 47.1, sx * 104.0), 0.08, 53.0), col("basalt"))
    sink_alcove_rim(mid["stone"], 9.0, lambda k: col("basalt"))
    for z in (-11.0, 11.0):
        for x in (SINK_HEAD_X - 8.0, SINK_HEAD_X + 8.0):
            beam(mid["enamel"], (x, SINK_FLOOR - 1.0, z), (SINK_HEAD_X, -72.0, z), 1.0, 1.0, col("timber"), caps=False)
    beam(mid["enamel"], (SINK_HEAD_X, -71.4, -12.0), (SINK_HEAD_X, -71.4, 12.0), 1.0, 1.2, col("timber_dk"))

    # ---- far: the rim coping as a dark lip and the cap band under it, so the U reads from the plateau
    for sx in (-1, 1):
        box(far["stone"], (min(sx * 126.1, sx * 129.0), -0.6, -50.0), (max(sx * 126.1, sx * 129.0), 0.08, 48.0), col("basalt"))
    for sx in (-1, 1):
        box(far["stone"], (min(sx * 47.1, sx * 104.0), -0.6, 50.1), (max(sx * 47.1, sx * 104.0), 0.08, 53.0), col("basalt"))
    sink_alcove_rim(far["stone"], 15.0, lambda k: col("basalt"))
    sink_walls(far["stone"], 4, 2, 0.08, lambda name, i, j, y: col("basalt_dk") if j else col("lime"), y_top=-0.6, y_bot=-20.0)

    # ---- shells: plank seams, lamp brackets, rubble at the wall foot (1); caisson rivets and drips (2)
    s1, s2 = sky.Surf("landmark_sinkhole_detail1"), sky.Surf("landmark_sinkhole_detail2")
    for k in range(60):
        a = TAU * k / 60
        if sink_in_wash(a):
            continue
        p0 = (SINK_RING[0] * math.sin(a), SINK_FLOOR + 0.105, SINK_RING[0] * math.cos(a))
        p1 = (SINK_RING[1] * math.sin(a), SINK_FLOOR + 0.105, SINK_RING[1] * math.cos(a))
        t = (math.cos(a), 0.0, -math.sin(a))
        card(s1, [vadd(p0, t, -0.06), vadd(p1, t, -0.06), vadd(p1, t, 0.06), vadd(p0, t, 0.06)], col("timber_dk"), UP)
    for k in range(TRESTLE_N // 2):
        t = SINK_WASH[0] + (SINK_WASH[1] - SINK_WASH[0]) * (k + 0.5) / (TRESTLE_N // 2)
        tg = (math.cos(t), 0.0, -math.sin(t))
        p0, p1 = sink_pt(SINK_RING[0], t, SINK_FLOOR + 0.105), sink_pt(SINK_RING[1], t, SINK_FLOOR + 0.105)
        card(s1, [vadd(p0, tg, -0.06), vadd(p1, tg, -0.06), vadd(p1, tg, 0.06), vadd(p0, tg, 0.06)], col("timber_dk"), UP)
    for k in range(48):
        wall = k % 3
        sz = 0.2 + 0.25 * rnd(k, 71)
        if wall == 2:
            x = -110.0 + 220.0 * rnd(k, 72)
            p = (x, SINK_FLOOR, sink_wall_z(SINK_FLOOR, x) - 0.8 - 2.0 * rnd(k, 73))
        else:
            sx = 1 if wall == 0 else -1
            p = (sx * (sink_wall_x(SINK_FLOOR) - 0.8 - 2.0 * rnd(k, 73)), SINK_FLOOR, -40.0 + 85.0 * rnd(k, 72))
        s1.chunk(p, (sz * 1.6, sz, sz * 1.3), rnd(k, 74) * TAU, k, shade("basalt", 1.0, (k, 75), 0.1), jitter=0.2, top=0.7)
    for k in range(16):
        a = TAU * (k + 0.5) / 16
        if sink_in_wash(a):
            continue
        p = (LAMP_R * math.sin(a), SINK_FLOOR + 2.2, LAMP_R * math.cos(a))
        t = (math.sin(a), 0.0, math.cos(a))
        beam(s1, p, vadd(p, t, 0.6), 0.08, 0.08, col("iron"), caps=False)
    for k in range(96):
        a = TAU * k / 96
        r = SINK_POOL[0] + 0.62
        p = (r * math.sin(a), SINK_FLOOR + 0.08, r * math.cos(a))
        box(s2, (p[0] - 0.06, p[1], p[2] - 0.06), (p[0] + 0.06, p[1] + 0.03, p[2] + 0.06), col("iron_hi"))
    for k in range(40):
        sx = (-1, 1)[k % 2]
        a = -45.0 + 90.0 * rnd(k, 81)
        top = -1.0 - 3.0 * rnd(k, 82)
        bot = top - 4.0 - 8.0 * rnd(k, 83)
        w = 0.2 + 0.4 * rnd(k, 84)
        pts = [(sx * (sink_wall_x(bot) - 0.2), bot, a - w), (sx * (sink_wall_x(bot) - 0.2), bot, a + w),
               (sx * (sink_wall_x(top) - 0.2), top, a + w), (sx * (sink_wall_x(top) - 0.2), top, a - w)]
        card(s2, pts, col("varnish"), (-sx, 0.0, 0.0))
    ax, ay, az = SINK_ANCHOR
    empties = {"sight_top": (0.0, 140.0, 38.0), "beam_root": SINK_ANCHOR, "warden_anchor": SINK_ANCHOR,
               "hp_0": (ax, ay + 1.6, az), "hp_1": (ax + 20.0, ay + 3.0, az + 5.0), "hp_2": (ax - 20.0, ay + 3.0, az + 5.0)}
    return {"base": base, "exempt": exempt, "col": colm, "nodes": [], "empties": empties, "mid": mid, "far": far,
            "shells": (s1, s2), "shell_slot": "stone", "clear": CLEAR}


# ================================================================ card 5: the Hanging Isle (park_islands)
# The isle is sky.floating_island (the same builders), re-origined onto the tilt pivot (warden_mind.gd PIVOT_HEIGHT 118 m
# above the tip, the tip at world 82), with more rings and sides on the underside players see from the bowl. The hand
# hangs 16 m under the tip since PW1 (wave 15: the stage 5 anchor at y 66, in rope reach), so a copper collar on the tip
# carries a chain tether down to it; the tether is its own node (origin on the tip) for the runtime to stretch. The tip's
# lowest 49 m collide only through landmark_sky_island_tip.glb (ISLE-TIP, Andrew 2026-10-16: a moving harpoon anchor on
# an AnimatableBody3D), so the base collider stops above it and nothing here bites until the tilt drives that body.
ISLE_SHIFT = (0.0, 200.0, -sky.I_R)
ISLE_PIVOT = 118.0
ISLE_HAND_Y = 66.0 - 200.0              # park_islands.json warden anchor y 66 (PW1, wave 15)
ISLE_HAND_CLEAR = 16.0
ISLE_TIP = (0.0, -ISLE_PIVOT, 0.0)
ISLE_COL_RING = 23                      # the base collider follows the hull to this ring (of the default 26)


def isle_shift(surf, name):
    out = sky.Surf(name)
    out.v = [vadd(v, ISLE_SHIFT) for v in surf.v]
    out.c = list(surf.c)
    out.t = list(surf.t)
    return out


class IsleDetail:
    """Temporarily raises floating_island's ring and side counts; the builders read them at call time."""

    def __init__(self, sides, rings):
        self.want = (sides, rings)

    def __enter__(self):
        self.saved = (sky.I_SIDES, sky.I_RINGS)
        sky.I_SIDES, sky.I_RINGS = self.want

    def __exit__(self, *exc):
        sky.I_SIDES, sky.I_RINGS = self.saved


def isle_hull_r(depth):
    """floating_island's hull radius at a depth below the rim (its i_radius without the strata cuts)."""
    u = min(1.0, depth / sky.I_DROP)
    return sky.I_R * (1.0 - u) ** 0.78


def isle_tip_col():
    """The tip collider: the hull from ring ISLE_COL_RING to the point, 16 sides, in the isle's local frame."""
    s = sky.Surf("isle_tip-col-col")
    depth0 = sky.I_DROP * (ISLE_COL_RING / 26.0) ** 1.35
    y0 = 200.0 - depth0
    ring = circle((0.0, 0.0), isle_hull_r(depth0), y0, 16)
    for i in range(16):
        s.poly([ring[i], ring[(i + 1) % 16], ISLE_TIP], col("sandstone"), inside=(0.0, y0 - 5.0, 0.0))
    s.poly(list(ring), col("sandstone"), inside=(0.0, y0 - 5.0, 0.0))
    return s


def build_sky_island():
    base, exempt, mid, far = View("landmark_sky_island"), View("tether"), View("landmark_sky_island_mid"), View("landmark_sky_island_far")
    with IsleDetail(72, 44):
        hull = sky.build_island_base()
    el = isle_shift(hull, "isle")
    base.parts["elastomer"] = el
    el.name = "landmark_sky_island:elastomer"
    st, ln = base["steel"], base["ancient_lens"]
    # keel ribs: rusted iron ribs on the lower taper, where the hand's fingers would curl
    for k in range(6):
        a = TAU * (k + 0.5) / 6
        pts = []
        for m in range(9):
            depth = 236.0 + 62.0 * m / 8
            r = isle_hull_r(depth) * 0.97 + 1.4
            pts.append((r * math.sin(a), 200.0 - depth, r * math.cos(a)))
        for p, q in zip(pts, pts[1:]):
            beam(st, p, q, 1.6, 1.1, lerp(col("rust"), col("copper"), 0.3 * rnd(k, 7)))
        for p in pts[1:-1:2]:
            t = (math.cos(a), 0.0, -math.sin(a))
            beam(st, vadd(p, t, -1.6), vadd(p, t, 1.6), 0.6, 0.6, col("copper_dk"))
    # the tip collar and the green ring round the beam root on the deck
    collar_d = 312.0
    r = isle_hull_r(collar_d) + 0.6
    for k in range(12):
        a0, a1 = TAU * k / 12, TAU * (k + 1) / 12
        beam(st, (r * math.sin(a0), 200.0 - collar_d, r * math.cos(a0)), (r * math.sin(a1), 200.0 - collar_d, r * math.cos(a1)),
             0.8, 1.4, col("copper"))
    annulus(ln, (0.0, 0.0), 3.0, 4.2, 200.0 + sky.I_CROWN - 0.02, 200.0 + sky.I_CROWN + 0.02, 16, lambda i: col("lens"), sides=False)
    # mist under the waterfall's end: crossed pale cards
    fall_x = -sky.I_R - 1.6
    for k in range(5):
        y = 200.0 - 112.0 - 8.0 * k
        w = 6.0 + 4.0 * k
        for d in ((1.0, 0.0, 0.0), (0.0, 0.0, 1.0)):
            t = (d[2], 0.0, -d[0]) if d[0] == 0.0 else (0.0, 0.0, 1.0)
            c0 = (fall_x - 0.02 * k, y, 0.0)
            pts = [vadd(vadd(c0, t, -w), UP, -w * 0.6), vadd(vadd(c0, t, w), UP, -w * 0.6), vadd(vadd(c0, t, w), UP, w * 0.6),
                   vadd(vadd(c0, t, -w), UP, w * 0.6)]
            normal = sky.norm(sky.cross(t, UP))
            el.poly(pts, lerp(col("mist"), col("water"), 0.2 * k / 5), up=normal)
            el.poly(list(reversed(pts)), lerp(col("mist"), col("water"), 0.2 * k / 5), up=vscale(normal, -1.0))
    # the tether: a chain from the tip to the hand's grip (its own node, origin on the tip)
    tet = exempt["steel"]
    top = ISLE_TIP
    grip = (0.0, ISLE_HAND_Y + 3.0, 0.0)
    links = 14
    for k in range(links):
        y0 = top[1] + (grip[1] - top[1]) * k / links
        y1 = top[1] + (grip[1] - top[1]) * (k + 1) / links
        h, w = (y0 - y1) * 0.62, 0.42
        yc = (y0 + y1) / 2
        if k % 2 == 0:
            corners = [(-w, yc - h), (w, yc - h), (w, yc + h), (-w, yc + h)]
            pts = [(x, y, 0.0) for x, y in corners]
        else:
            pts = [(0.0, y, z) for z, y in ((-w, yc - h), (w, yc - h), (w, yc + h), (-w, yc + h))]
        for i in range(4):
            beam(tet, pts[i], pts[(i + 1) % 4], 0.22, 0.22, col("iron"), caps=False)
    tube(tet, top, (0.0, top[1] - 1.0, 0.0), 1.1, 8, col("copper"))
    tube(tet, (0.0, grip[1] + 0.8, 0.0), (0.0, grip[1] - 0.4, 0.0), 0.9, 8, col("copper_dk"))
    # base collider: floating_island's deck and hull down to ring ISLE_COL_RING, closed there
    colm = sky.Surf("landmark_sky_island-col-col")
    rings = 5
    for j in range(rings):
        r0, r1 = sky.I_R * j / rings, sky.I_R * (j + 1) / rings
        for n in range(sky.I_SIDES):
            a0, a1 = TAU * n / sky.I_SIDES, TAU * (n + 1) / sky.I_SIDES
            p = lambda rr, a: (rr * math.cos(a), 200.0 + sky.i_crown(rr), rr * math.sin(a))
            pts = [p(r0, a0), p(r1, a0), p(r1, a1), p(r0, a1)] if j > 0 else [p(r0, a0), p(r1, a0), p(r1, a1)]
            colm.poly(pts, col("sandstone"), up=UP)
    ks = [0, 2, 5, 8, 11, 14, 17, 20, ISLE_COL_RING]
    for a_, b_ in zip(ks, ks[1:]):
        r0 = [vadd(p, ISLE_SHIFT) for p in sky.i_hull_ring(a_)]
        r1 = [vadd(p, ISLE_SHIFT) for p in sky.i_hull_ring(b_)]
        for n in range(sky.I_SIDES):
            m = (n + 1) % sky.I_SIDES
            colm.poly([r0[n], r0[m], r1[m], r1[n]], col("sandstone"), inside=(0.0, (r0[n][1] + r1[n][1]) / 2, 0.0))
    last = [vadd(p, ISLE_SHIFT) for p in sky.i_hull_ring(ISLE_COL_RING)]
    colm.poly(list(last), col("sandstone"), inside=(0.0, last[0][1] + 5.0, 0.0))

    # ---- mid: the taper at half the rings, the deck with clumps of pines, one waterfall ribbon, ribs, the tether
    with IsleDetail(32, 13):
        m_el = mid["elastomer"]
        for k in range(sky.I_RINGS):
            r0 = [vadd(p, ISLE_SHIFT) for p in sky.i_hull_ring(k)]
            r1 = [vadd(p, ISLE_SHIFT) for p in sky.i_hull_ring(k + 1)] if k + 1 < sky.I_RINGS else None
            for n in range(sky.I_SIDES):
                m = (n + 1) % sky.I_SIDES
                if r1 is None:
                    m_el.poly([r0[n], r0[m], ISLE_TIP], sky.i_band_colour(k, n), inside=(0.0, r0[n][1] + 5.0, 0.0))
                else:
                    m_el.poly([r0[n], r0[m], r1[m], r1[n]], sky.i_band_colour(k, n), inside=(0.0, (r0[n][1] + r1[n][1]) / 2, 0.0))
        rim = [vadd(p, ISLE_SHIFT) for p in sky.i_hull_ring(0)]
        for n in range(sky.I_SIDES):
            m_el.poly([(0.0, 200.0 + sky.I_CROWN, 0.0), rim[n], rim[(n + 1) % sky.I_SIDES]], col("sage"), up=UP)
    for k in range(14):
        a = k * 2.39996
        rr = 30.0 + 50.0 * ((k + 0.5) / 14) ** 0.5
        x, z = rr * math.cos(a), rr * math.sin(a)
        if abs(x) < 18.0:
            x += 20.0 if x >= 0 else -20.0
        m_el.cone((x, 200.0 + sky.i_crown(math.hypot(x, z)), z), 7.0, 20.0, 6, col("pine"))
    for q in range(4):
        y0, y1 = 198.0 - 28.0 * q, 198.0 - 28.0 * (q + 1)
        w0, w1 = (4.0, 6.0, 7.0, 4.0, 0.5)[q], (4.0, 6.0, 7.0, 4.0, 0.5)[q + 1]
        quad = [(fall_x, y0, -w0 / 2), (fall_x, y1, -w1 / 2), (fall_x, y1, w1 / 2), (fall_x, y0, w0 / 2)]
        m_el.poly(quad, lerp(col("water"), col("mist"), q / 4), up=(-1.0, 0.0, 0.0))
        m_el.poly(list(reversed(quad)), lerp(col("water"), col("mist"), q / 4), up=(1.0, 0.0, 0.0))
    for k in range(6):
        a = TAU * (k + 0.5) / 6
        p = (isle_hull_r(236.0) + 1.4) * math.sin(a), 200.0 - 236.0, (isle_hull_r(236.0) + 1.4) * math.cos(a)
        q = (isle_hull_r(298.0) + 1.4) * math.sin(a), 200.0 - 298.0, (isle_hull_r(298.0) + 1.4) * math.cos(a)
        beam(mid["steel"], p, q, 1.6, 1.1, col("rust"), caps=False)
    tube(mid["steel"], ISLE_TIP, grip, 0.5, 4, col("iron"))

    # ---- far: a 24-sided inverted cone under the deck disc, the waterfall as one strip
    fl = far["elastomer"]
    rings_f = [(0.0, sky.I_R), (40.0, isle_hull_r(40.0)), (110.0, isle_hull_r(110.0)), (200.0, isle_hull_r(200.0)), (270.0, isle_hull_r(270.0))]
    for (d0, r0), (d1, r1) in zip(rings_f, rings_f[1:]):
        lo, hi = circle((0.0, 0.0), r1, 200.0 - d1, 24), circle((0.0, 0.0), r0, 200.0 - d0, 24)
        for n in range(24):
            m = (n + 1) % 24
            fl.poly([lo[n], lo[m], hi[m], hi[n]], col(("slick_red", "cream", "oxide", "deep_red")[int(d0 // 70) % 4]),
                    inside=(0.0, 200.0 - (d0 + d1) / 2, 0.0))
    last = circle((0.0, 0.0), isle_hull_r(270.0), 200.0 - 270.0, 24)
    for n in range(24):
        fl.poly([last[n], last[(n + 1) % 24], ISLE_TIP], col("deep_red"), inside=(0.0, -80.0, 0.0))
    top_ring = circle((0.0, 0.0), sky.I_R, 200.0, 24)
    for n in range(24):
        fl.poly([(0.0, 200.0 + sky.I_CROWN, 0.0), top_ring[n], top_ring[(n + 1) % 24]], col("sage"), up=UP)
    quad = [(fall_x, 198.0, -2.5), (fall_x, 90.0, -1.0), (fall_x, 90.0, 1.0), (fall_x, 198.0, 2.5)]
    fl.poly(quad, col("water"), up=(-1.0, 0.0, 0.0))
    fl.poly(list(reversed(quad)), col("water"), up=(1.0, 0.0, 0.0))

    # ---- shells: floating_island's two shells, re-origined, plus rib rivet plates (2)
    s1 = isle_shift(sky.build_island_d1(), "landmark_sky_island_detail1")
    s2 = isle_shift(sky.build_island_d2(), "landmark_sky_island_detail2")
    for k in range(6):
        a = TAU * (k + 0.5) / 6
        for m in range(1, 8):
            depth = 236.0 + 62.0 * m / 8
            r = isle_hull_r(depth) * 0.97 + 2.3
            p = (r * math.sin(a), 200.0 - depth, r * math.cos(a))
            n = (math.sin(a), 0.0, math.cos(a))
            t = (math.cos(a), 0.0, -math.sin(a))
            card(s2, [vadd(vadd(p, t, -1.0), UP, -1.0), vadd(vadd(p, t, 1.0), UP, -1.0), vadd(vadd(p, t, 1.0), UP, 1.0),
                      vadd(vadd(p, t, -1.0), UP, 1.0)], col("copper_dk"), n)
    empties = {"sight_top": (0.0, 200.0, 0.0), "beam_root": (0.0, 200.0 + sky.I_CROWN, 0.0),
               "warden_anchor": (0.0, ISLE_HAND_Y, 0.0), "tip": ISLE_TIP, "pivot": (0.0, 0.0, 0.0)}
    tip_glb = {"nodes": [("isle_tip-col-col", [(isle_tip_col(), None)], (0.0, 0.0, 0.0))], "empties": {"tip": ISLE_TIP}}
    return {"base": base, "exempt": View("none"), "col": colm, "nodes": [(exempt, ISLE_TIP)], "empties": empties,
            "mid": mid, "far": far, "shells": (s1, s2), "shell_slot": "elastomer", "clear": ISLE_HAND_CLEAR,
            "extra": {"landmark_sky_island_tip": tip_glb}}


# ================================================================ card 6: the Crown Spire (park_crown)
# The bowl floor is y -12 at the axis (local 0) and climbs 0.03 m by r 15 (bake). The shaft is 30 m across from the floor
# to y 60 (Andrew 2026-10-16), so warden_mind.gd's perch-to-perch flight (chords 22.5 m off the axis, at most 9 m over
# the perches at local 30) keeps 7.5 m from it; it widens to 50 m by 120, tapers to 20 m at 330 under a dark caprock to
# 342. Flutes only cut inward, so no vertex below y 60 stands outside r 15.
SPIRE_PROFILE = ((-2.0, 15.0), (0.0, 15.0), (60.0, 15.0), (120.0, 25.0), (200.0, 22.0), (280.0, 16.0), (330.0, 10.0))
SPIRE_TOP = 342.0
SPIRE_PERCHES = ((0.0, 30.0, 45.0), (39.0, 30.0, -22.5), (-39.0, 30.0, -22.5))
SPIRE_ARC_RISE = 9.0
SPIRE_ARC_CLEAR = 6.0
SPIRE_WAIST = 15.0
STRATA_SPIRE = [("slick_red", 9.0), ("cream", 5.0), ("oxide", 12.0), ("sandstone", 7.0), ("deep_red", 8.0), ("cream", 3.5),
                ("slick_red", 14.0), ("varnish", 2.5), ("sandstone", 6.0)]


def spire_r(y):
    pts = SPIRE_PROFILE
    if y <= pts[0][0]:
        return pts[0][1]
    for (y0, r0), (y1, r1) in zip(pts, pts[1:]):
        if y <= y1:
            t = (y - y0) / (y1 - y0)
            s = t * t * (3 - 2 * t)
            return r0 + (r1 - r0) * s
    return pts[-1][1]


def spire_flute(a, y):
    return 0.05 * (0.5 + 0.5 * math.sin(7 * a + 0.02 * y)) + 0.03 * (0.5 + 0.5 * math.sin(13 * a + 1.3 + 0.05 * y))


def spire_band(y, a):
    d = y + 1.2 * math.sin(a + 0.6)
    d %= sum(t for _, t in STRATA_SPIRE)
    acc = 0.0
    for name, th in STRATA_SPIRE:
        acc += th
        if d < acc:
            return name
    return STRATA_SPIRE[0][0]


def spire_shaft(s, sides, ys, flutes=True, colour=None):
    rings = []
    for y in ys:
        ring = []
        for n in range(sides):
            a = TAU * n / sides
            r = spire_r(y) * (1.0 - (spire_flute(a, y) if flutes else 0.0))
            ring.append((r * math.sin(a), y, r * math.cos(a)))
        rings.append(ring)
    for k in range(len(ys) - 1):
        for n in range(sides):
            m = (n + 1) % sides
            a = TAU * (n + 0.5) / sides
            c = colour(k, n) if colour else shade(spire_band((ys[k] + ys[k + 1]) / 2, a), 1.0, (k, n // 6, 5), 0.03)
            s.poly([rings[k][n], rings[k][m], rings[k + 1][m], rings[k + 1][n]], c, inside=(0.0, (ys[k] + ys[k + 1]) / 2, 0.0))
    return rings[-1]


def spire_cap(s, sides, top_ring, color):
    y = top_ring[0][1]
    lip = circle((0.0, 0.0), 11.4, y + 4.0, sides)
    crown = circle((0.0, 0.0), 7.0, SPIRE_TOP, sides)
    s.ring_solid(top_ring, lip, color, caps=(False, False))
    s.ring_solid(lip, crown, color, caps=(False, True))


def build_spire():
    base, exempt, mid, far = View("landmark_spire"), View("none"), View("landmark_spire_mid"), View("landmark_spire_far")
    colm = sky.Surf("landmark_spire-col-col")
    el, gl, ln = base["elastomer"], base["glass"], base["ancient_lens"]
    ys = [-2.0] + [4.0 * k for k in range(0, 83)] + [330.0]
    ys = sorted(set(ys))
    top = spire_shaft(el, 36, ys)
    spire_cap(el, 36, top, col("caprock"))
    annulus(ln, (0.0, 0.0), 2.4, 3.6, SPIRE_TOP, SPIRE_TOP + 0.04, 16, lambda i: col("lens"), sides=False)
    # talus skirt: fallen blocks round the foot, never past r 15 and never over 3 m
    for k in range(34):
        a = TAU * (k + 0.4 * rnd(k, 1)) / 34
        sz = 1.2 + 1.0 * rnd(k, 2)
        r = SPIRE_WAIST - sz * 0.75 - 0.2
        c = (r * math.sin(a), -1.0, r * math.cos(a))
        hgt = min(3.0, 1.2 + 2.6 * rnd(k, 3))
        el.chunk(c, (sz, hgt, sz * 0.9), a, 300 + k, shade(("cream", "sandstone", "slick_red")[k % 3], 1.0, (k, 4), 0.08), jitter=0.15, top=0.6)
    # desert varnish streaks and three fulgurite scars down the upper shaft (the lightning prefers it)
    for k in range(18):
        a = TAU * rnd(k, 11)
        y1 = 300.0 - 120.0 * rnd(k, 12)
        y0 = y1 - 20.0 - 50.0 * rnd(k, 13)
        w = 0.8 + 1.6 * rnd(k, 14)
        pts = []
        for y, ww in ((y0, w), (y0, -w), (y1, -w * 0.5), (y1, w * 0.5)):
            r = spire_r(y) + 0.06
            aa = a + ww / max(r, 1.0)
            pts.append((r * math.sin(aa), y, r * math.cos(aa)))
        el.poly(pts, col("varnish"), inside=(0.0, (y0 + y1) / 2, 0.0))
    for k in range(3):
        a = TAU * (k + 0.2) / 3
        y = 330.0
        while y > 150.0:
            ny = y - 10.0 - 6.0 * rnd(k, int(y), 1)
            na = a + (rnd(k, int(y), 2) - 0.5) * 0.12
            pts = []
            for yy, aa, ww in ((y, a, 0.5), (ny, na, 0.5), (ny, na, -0.5), (y, a, -0.5)):
                r = spire_r(yy) + 0.1
                ab = aa + ww / r
                pts.append((r * math.sin(ab), yy, r * math.cos(ab)))
            gl.poly(pts, col("fulgurite"), inside=(0.0, (y + ny) / 2, 0.0))
            y, a = ny, na
    # collider: 12-sided frustums inside the profile (flutes cut inward, so the polygon's corners touch r)
    cys = [-2.0, 60.0, 90.0, 120.0, 160.0, 200.0, 240.0, 280.0, 330.0]
    rings = [circle((0.0, 0.0), spire_r(y), y, 12) for y in cys]
    for k in range(len(cys) - 1):
        colm.ring_solid(rings[k], rings[k + 1], col("sandstone"), caps=(k == 0, False))
    colm.ring_solid(rings[-1], circle((0.0, 0.0), 7.0, SPIRE_TOP, 12), col("caprock"), caps=(False, True))

    # ---- mid: a 16-sided banded shaft and the cap
    top_m = spire_shaft(mid["elastomer"], 16, [-2.0] + [16.0 * k for k in range(0, 21)] + [330.0], flutes=False)
    spire_cap(mid["elastomer"], 16, top_m, col("caprock"))
    # ---- far: a 10-sided lofted shaft and the cap
    top_f = spire_shaft(far["elastomer"], 10, [-2.0, 30.0, 60.0, 90.0, 120.0, 160.0, 200.0, 240.0, 280.0, 310.0, 330.0], flutes=False,
                        colour=lambda k, n: col(("slick_red", "cream", "oxide", "sandstone")[k % 4]))
    spire_cap(far["elastomer"], 10, top_f, col("caprock"))

    # ---- shells: small talus and ledges (1); varnish drips on the lower shaft (2)
    s1, s2 = sky.Surf("landmark_spire_detail1"), sky.Surf("landmark_spire_detail2")
    for k in range(40):
        a = TAU * rnd(k, 21)
        sz = 0.3 + 0.5 * rnd(k, 22)
        r = SPIRE_WAIST - sz - 0.1
        s1.chunk((r * math.sin(a), -0.5, r * math.cos(a)), (sz, sz * 0.7, sz), a, 500 + k, shade("sandstone", 1.0, (k, 23), 0.1), jitter=0.2, top=0.7)
    for k in range(30):
        a = TAU * rnd(k, 24)
        y = 70.0 + 240.0 * rnd(k, 25)
        r = spire_r(y) * (1.0 - spire_flute(a, y)) + 0.02
        t = (math.cos(a), 0.0, -math.sin(a))
        n = (math.sin(a), 0.0, math.cos(a))
        p = (r * math.sin(a), y, r * math.cos(a))
        box(s1, vadd(vadd(p, t, -2.0), UP, -0.2), vadd(vadd(vadd(p, t, 2.0), UP, 0.25), n, 0.5), col("cream"))
    for k in range(20):
        a = TAU * rnd(k, 31)
        y1 = 58.0 - 20.0 * rnd(k, 32)
        y0 = 2.0 + 10.0 * rnd(k, 33)
        w = 0.15 + 0.35 * rnd(k, 34)
        pts = []
        for y, ww in ((y0, w), (y0, -w), (y1, -w), (y1, w)):
            r = spire_r(y) * (1.0 - spire_flute(a, y)) - 0.0
            r = min(r, SPIRE_WAIST) - 0.0 + 0.0
            aa = a + ww / r
            rr = spire_r(y) * (1.0 - spire_flute(aa, y))
            pts.append((rr * math.sin(aa), y, rr * math.cos(aa)))
        s2.poly(pts, lerp(col("varnish"), col("slick_red"), 0.45), inside=(0.0, (y0 + y1) / 2, 0.0))
    empties = {"sight_top": (0.0, SPIRE_TOP, 0.0), "beam_root": (0.0, SPIRE_TOP, 0.0), "warden_anchor": SPIRE_PERCHES[0]}
    for i, p in enumerate(SPIRE_PERCHES, start=1):
        empties["perch_%d" % i] = p
    return {"base": base, "exempt": exempt, "col": colm, "nodes": [], "empties": empties, "mid": mid, "far": far,
            "shells": (s1, s2), "shell_slot": "elastomer", "clear": CLEAR}


BUILDERS = {
    "landmark_dam": build_dam,
    "landmark_penstock_tower": build_penstock_tower,
    "landmark_headframe": build_headframe,
    "landmark_sinkhole": build_sinkhole,
    "landmark_sky_island": build_sky_island,
    "landmark_spire": build_spire,
}


# ---------------------------------------------------------------- checks (fail loud before and after export)
def all_views(spec):
    out = [spec["base"], spec["exempt"], spec["col"], spec["mid"], spec["far"], *spec["shells"]]
    out += [v for v, _ in spec["nodes"]]
    return out


def node_world_verts(spec):
    """Every drawn and collider vertex of the base GLB, moving nodes included, in the landmark's local frame."""
    for view, origin in spec["nodes"]:
        for s, _ in view.surfs():
            for v in s.v:
                yield v


def check_clear(rid, spec):
    """No base geometry within spec['clear'] of warden_anchor, except the cradle, flush decking and the tether."""
    anchor = spec["empties"]["warden_anchor"]
    lim = spec["clear"]
    pool = list(verts_of([spec["base"], spec["col"]]))
    pool += [v for view, _ in spec["nodes"] if view.name.startswith("gate") for s, _ in view.surfs() for v in s.v]
    if rid == "landmark_sky_island":
        pool = [v for v in pool if vlen(vsub(v, ISLE_TIP)) > 1e-6]
    worst = min(vlen(vsub(v, anchor)) for v in pool)
    assert worst >= lim - 1e-6, (rid, "geometry inside the warden clear volume", round(worst, 3), lim)
    return round(worst, 3)


def check_card(rid, spec):
    """Each card's own pins (LANDMARK-CARDS.md 'Test that pins it') that the recipe can prove from its geometry."""
    every = list(verts_of(all_views(spec))) + list(node_world_verts(spec))
    out = {}
    if rid == "landmark_dam":
        colv = spec["col"].v
        low = [v for v in colv if v[1] < 30.0 - 1e-6 and abs(v[0]) <= DAM_CHORD]
        assert not low, (rid, "collider below y 30 inside the chord", low[:3])
        gap = min(abs(v[0]) for v in colv if v[2] > -40.0 and DAM_PLATEAU - 1e-6 <= v[1] < 137.7 and abs(v[0]) < DAM_CANYON - 1.0)
        assert gap >= DAM_TOWER[0] - 1e-6, (rid, "tower gap", gap)
        rail = [v for v in colv if -38.0 < v[2] < -34.0 and 100.0 < v[1] < 104.0 and abs(v[0]) < 150.0]
        assert not rail, (rid, "collider over the crest_rail line", rail[:3])
        out["tower_gap_m"] = round(2 * gap, 3)
        names = [v.name for v, _ in spec["nodes"]]
        assert names == ["gate_l", "gate_r"], names
    if rid == "landmark_headframe":
        hw, y0, y1 = PIT_WELL
        inside = [v for v in every if abs(v[0]) < hw and abs(v[2]) < hw and y0 < v[1] < y1]
        assert not inside, (rid, "geometry in the hive well", inside[:3])
        assert min(v[1] for v in spec["col"].v) <= -2.0, (rid, "legs do not reach the ground")
        # each rope end lies on the drum wall inside the slot; back along the rope toward its wheel, every point over the
        # house's footprint outside the slot is above the roof
        c, ax, aw, hl, hw, roof = pit_house()
        d0, d1, hq, floor = PIT_SLOT
        for s, end in zip((-1, 1), pit_rope_ends()):
            rel = vsub(end, c)
            d, q = -sky.dot(rel, PIT_ROPE), sky.dot(rel, PIT_PERP)
            assert abs(d - d0) < 1e-6 and abs(q) < hq and floor < end[1] < roof, (rid, "rope end off the drum wall", d, q, end)
            top = vadd(vadd((0.0, PIT_WHEEL_Y, 0.0), PIT_PERP, s * 3.5), PIT_ROPE, PIT_WHEEL_R - 0.3)
            for k in range(1, 401):
                p = vlerp(end, top, k / 400)
                r = vsub(p, c)
                over = abs(sky.dot(r, ax)) <= hl and abs(sky.dot(r, aw)) <= hw
                in_slot = d0 <= -sky.dot(r, PIT_ROPE) <= d1 and abs(sky.dot(r, PIT_PERP)) < hq
                assert not over or in_slot or p[1] >= roof, (rid, "rope through the hoist house roof", p)
    if rid == "landmark_sinkhole":
        r, ya, yb = SINK_POOL
        inside = [v for v in every if math.hypot(v[0], v[2]) < r and ya < v[1] < yb]
        assert not inside, (rid, "geometry in the pool cylinder", inside[:3])
        deck = max(v[1] for s, _ in spec["exempt"].surfs() for v in s.v)
        assert deck <= SINK_FLOOR + FLUSH, (rid, "ring deck not flush", deck)
        assert all(v[0] > 88.0 for v in spec["col"].v), (rid, "the sinkhole collides only at the headgear (no pilot line within 20 m)")
        lane = [v for v in every if SINK_RING[0] < math.hypot(v[0], v[2]) < SINK_RING[1] and SINK_FLOOR + 0.2 < v[1] < SINK_LANE_TOP]
        assert not lane, (rid, "geometry in the ring lane under its clear height", lane[:3])
        out["ring_deck_proud_m"] = round(deck - SINK_FLOOR, 3)
    if rid == "landmark_sky_island":
        tip, piv = spec["empties"]["tip"], spec["empties"]["pivot"]
        assert vlen(piv) < 1e-9 and abs(piv[1] - tip[1] - ISLE_PIVOT) <= 0.5, (rid, tip, piv)
        assert min(v[1] for v in spec["col"].v) > ISLE_TIP[1] + 40.0, (rid, "base collider reaches the moving tip")
    if rid == "landmark_spire":
        colv = spec["col"].v + list(verts_of([spec["base"]]))
        waist = max(math.hypot(v[0], v[2]) for v in colv if v[1] < 60.0)
        assert waist <= SPIRE_WAIST + 1e-6, (rid, "waist", waist)
        worst = 1e9
        for i in range(3):
            a, b = SPIRE_PERCHES[i], SPIRE_PERCHES[(i + 1) % 3]
            for k in range(61):
                t = k / 60
                p = (a[0] + (b[0] - a[0]) * t, a[1] + SPIRE_ARC_RISE * math.sin(math.pi * t), a[2] + (b[2] - a[2]) * t)
                near = [v for v in spec["col"].v if abs(v[1] - p[1]) < 70.0]
                worst = min(worst, math.hypot(p[0], p[2]) - max(spire_r(p[1]), max(math.hypot(v[0], v[2]) for v in near if v[1] <= 60.0)))
        assert worst >= SPIRE_ARC_CLEAR, (rid, "flight arc clearance", worst)
        out["waist_r_m"] = round(waist, 3)
        out["arc_clear_m"] = round(worst, 3)
    if rid == "landmark_penstock_tower":
        F = FRAMES[rid]
        for wx, wz in FLUME_LINE_CROSSINGS:
            p = F.local(wx, 0.0, wz)
            near = min(math.hypot(v[0] - p[0], v[2] - p[2]) for v in spec["col"].v if v[1] < 6.0)
            assert near >= 12.0, (rid, "parapet near a line crossing", (wx, wz), near)
    return out


def budgets(rid, spec):
    base_t = spec["base"].tris() + spec["exempt"].tris() + len(spec["col"].t) + sum(v.tris() for v, _ in spec["nodes"])
    rows = {"base": base_t, "col": len(spec["col"].t), "mid": spec["mid"].tris(), "far": spec["far"].tris(),
            "detail1": len(spec["shells"][0].t), "detail2": len(spec["shells"][1].t)}
    assert base_t <= HERO["tris"], (rid, "base", base_t)
    assert rows["mid"] <= HERO["mid_tris"], (rid, "mid", rows["mid"])
    assert rows["far"] <= HERO["far_tris"], (rid, "far", rows["far"])
    for k in ("detail1", "detail2"):
        assert rows[k] <= DETAIL["tris"], (rid, k, rows[k])
    for sf in all_views(spec):
        for v in verts_of([sf]):
            assert all(math.isfinite(x) for x in v), (rid, v)
    return rows


# ---------------------------------------------------------------- Blender export
def material(slot):
    mat = bpy.data.materials.get(slot)
    if mat:
        return mat
    mat = bpy.data.materials.new(slot)
    mat.use_nodes = True
    bsdf = mat.node_tree.nodes.get("Principled BSDF")
    bsdf.inputs["Roughness"].default_value = {"steel": 0.5, "glass": 0.1, "ancient_lens": 0.3}.get(slot, 0.9)
    bsdf.inputs["Metallic"].default_value = 0.5 if slot == "steel" else 0.0
    if slot == "ancient_lens":
        lin = common.rgba(col("lens"))
        bsdf.inputs["Base Color"].default_value = lin
        bsdf.inputs["Emission Color"].default_value = lin
        bsdf.inputs["Emission Strength"].default_value = 3.0
    else:
        attr = mat.node_tree.nodes.new("ShaderNodeVertexColor")
        attr.layer_name = "Color"
        mat.node_tree.links.new(attr.outputs["Color"], bsdf.inputs["Base Color"])
    return mat


# ---------------------------------------------------------------- soft toy pass (tools/blender/POLISH.md)
# Soft toy (Andrew, 18 Oct): the drawn meshes run through the polish toolkit at export. This file writes its own meshes
# (sky.Surf, one flat shaded fan per polygon) and never builds a common.Part, so the pass is an adapter: it recovers each
# polygon from its fan, welds each convex piece (a run of polygons that share edges: a box, a beam, a ring of planks) into
# a closed bmesh, bevels the hard edges of each piece to a quarter of its own thickness (thin timbers get no bevel, so
# nothing folds shut), smooths the rest and triangulates as Part does. The AO and edge-wear bake runs over the drawn
# meshes alone, before any -col mesh joins the scene, so a collider neither occludes it nor changes. polish.enable is not
# called: common.export is not used, so the colliders keep their old export path byte for byte.
SOFT = {
    "bevel": 0.06,           # the widest bevel, metres; each piece takes at most a quarter of its thinnest side
    "bevel_angle": 40.0,     # only edges sharper than this bevel (silhouette corners, not the facets of a round)
    "bevel_min": 0.45,       # shorter edges keep hard: rivets, cell rims and plank ends stay cheap
    "sharp_angle": 50.0,
    "ao_rays": 16,
    "ao_reach_m": 3.0,       # occlusion reach in metres (the toolkit's ao_reach is a fraction of the bounds)
    "ao_strength": 0.45,
    "edge": 0.12,
    "bake_slots": ("enamel", "steel", "stone", "elastomer", "glass"),
}


def fan_polys(surf):
    """The polygons of a Surf as vertex index runs: Surf.poly writes each as a fan (b, b+i, b+i+1)."""
    polys, t, i = [], surf.t, 0
    while i < len(t):
        b, last = t[i][0], t[i][2]
        assert t[i][1] == b + 1, (surf.name, "not a fan", t[i])
        j = i + 1
        while j < len(t) and t[j][0] == b and t[j][1] == last:
            last = t[j][2]
            j += 1
        polys.append(list(range(b, last + 1)))
        i = j
    return polys


def surf_pieces(surf):
    """Polygons grouped into pieces: a polygon joins the running piece when it shares an edge with it and no edge of the
    piece would then carry a third face."""
    key = lambda v: (round(v[0], 4) + 0.0, round(v[1], 4) + 0.0, round(v[2], 4) + 0.0)
    pieces, cur = [], None
    for vs in fan_polys(surf):
        keys = [key(surf.v[k]) for k in vs]
        edges = [frozenset((keys[k], keys[(k + 1) % len(keys)])) for k in range(len(keys))]
        same = frozenset(keys)
        # a polygon on the same points as one already in the piece is a two-sided card's back: its own piece keeps both windings
        if cur is not None and same not in cur[2] and any(cur[1].get(e, 0) == 1 for e in edges) and all(cur[1].get(e, 0) < 2 for e in edges):
            cur[0].append(vs)
        else:
            cur = ([vs], {}, set())
            pieces.append(cur)
        cur[2].add(same)
        for e in edges:
            cur[1][e] = cur[1].get(e, 0) + 1
    return [p[0] for p in pieces]


def piece_thickness(surf, polys):
    """The least width of a piece across any of its face normals (its true thickness, whatever its yaw)."""
    pts = sorted({surf.v[k] for vs in polys for k in vs})
    normals = set()
    for vs in polys:
        n = (0.0, 0.0, 0.0)
        for a in range(len(vs)):
            n = vadd(n, sky.cross(surf.v[vs[a]], surf.v[vs[(a + 1) % len(vs)]]))
        ln = vlen(n)
        if ln > 1e-9:
            n = vscale(n, 1.0 / ln)
            if (n[0], n[1], n[2]) < (0.0, 0.0, 0.0):
                n = vscale(n, -1.0)
            normals.add((round(n[0], 3) + 0.0, round(n[1], 3) + 0.0, round(n[2], 3) + 0.0))
    normals = sorted(normals)
    if len(normals) > 48:
        normals = normals[::len(normals) // 48 + 1]
    if not normals:
        return 0.0
    thin = 1e9
    for n in normals:
        d = [n[0] * p[0] + n[1] * p[1] + n[2] * p[2] for p in pts]
        thin = min(thin, max(d) - min(d))
    return thin


def soft_bmesh(surf, slot_index, origin, o):
    """One Surf as a polished, triangulated bmesh: faces carry slot_index and a loop colour."""
    key = lambda v: (round(v[0], 4) + 0.0, round(v[1], 4) + 0.0, round(v[2], 4) + 0.0)
    groups = {}
    for polys in surf_pieces(surf):
        w = min(o["bevel"], 0.25 * piece_thickness(surf, polys))
        w = 0.0 if w < 0.005 else round(w * 200.0) / 200.0
        groups.setdefault(w, []).append(polys)
    out = bmesh.new()
    out.loops.layers.float_color.new("Color")
    for w in sorted(groups):
        bm = bmesh.new()
        layer = bm.loops.layers.float_color.new("Color")
        for polys in groups[w]:
            weld = {}
            for vs in polys:
                ring = []
                for k in vs:
                    kk = key(surf.v[k])
                    if not ring or ring[-1][0] != kk:
                        ring.append((kk, k))
                if len(ring) > 1 and ring[0][0] == ring[-1][0]:
                    ring.pop()
                if len({r[0] for r in ring}) < 3 or len({r[0] for r in ring}) != len(ring):
                    continue
                bverts = []
                for kk, k in ring:
                    if kk not in weld:
                        weld[kk] = bm.verts.new(sky.xyz(vsub(surf.v[k], origin)))
                    bverts.append(weld[kk])
                try:
                    face = bm.faces.new(bverts)
                except ValueError:
                    raise AssertionError((surf.name, "soft pass would drop a face on existing points", [tuple(v.co) for v in bverts]))
                for loop, (kk, k) in zip(face.loops, ring):
                    loop[layer] = common.rgba(surf.c[k])
        bm.normal_update()
        bm = polish.finish(bm, dict(o, bevel_segments=1), w, 0)
        col_layer = bm.loops.layers.float_color["Color"]
        bm.normal_update()
        for f in list(bm.faces):
            if len(f.verts) > 4 and common._convex(f):
                vs = [loop.vert for loop in f.loops]
                color = tuple(f.loops[0][col_layer])

                def flat(k):
                    q = vs[k:] + vs[:k]
                    return any((q[i].co - q[0].co).cross(q[i + 1].co - q[0].co).length < 1e-9 for i in range(1, len(q) - 1))
                k = next((k for k in range(len(vs)) if not flat(k)), 0)
                vs = vs[k:] + vs[:k]
                bm.faces.remove(f)
                for i in range(1, len(vs) - 1):
                    nf = bm.faces.new((vs[0], vs[i], vs[i + 1]))
                    for loop in nf.loops:
                        loop[col_layer] = color
        fixed, alternate = [], []
        for f in bm.faces:
            if len(f.verts) != 4:
                fixed.append(f)
                continue
            c = [tuple(v.co) for v in f.verts]
            d02, d13 = math.dist(c[0], c[2]), math.dist(c[1], c[3])
            first = d02 < d13 if abs(d02 - d13) > 1e-9 * max(d02, d13) else min(c[0], c[2]) < min(c[1], c[3])
            (fixed if first else alternate).append(f)
        bmesh.ops.triangulate(bm, faces=fixed, quad_method="FIXED", ngon_method="EAR_CLIP")
        bmesh.ops.triangulate(bm, faces=alternate, quad_method="ALTERNATE", ngon_method="EAR_CLIP")
        for f in bm.faces:
            f.material_index = slot_index
        polish._append(out, bm)
        bm.free()
    return polish._canonical(out)


def soft_options(nodes):
    lo = [1e9] * 3
    hi = [-1e9] * 3
    for _, parts, _ in nodes:
        for surf, slot in parts:
            for v in surf.v:
                for k in range(3):
                    lo[k], hi[k] = min(lo[k], v[k]), max(hi[k], v[k])
    half = max(vlen(vsub(tuple(hi), tuple(lo))) * 0.5, 1.0)
    keys = ("bevel", "bevel_angle", "bevel_min", "sharp_angle", "ao_rays", "ao_strength", "edge", "bake_slots")
    o = dict(polish.DEFAULTS, **{k: SOFT[k] for k in keys})
    o["ao_reach"] = SOFT["ao_reach_m"] / half
    return o


def make_mesh(name, parts, parent, origin=(0.0, 0.0, 0.0), soft=None):
    """parts: [(Surf, slot or None)] merged into one mesh, one material per slot; vertices relative to origin."""
    if soft is not None:
        slots = []
        acc = bmesh.new()
        for surf, slot in parts:
            if not surf.t:
                continue
            if slot not in slots:
                slots.append(slot)
            bm = soft_bmesh(surf, slots.index(slot), origin, soft)
            polish._append(acc, bm)
            bm.free()
        acc = polish._canonical(acc)
        mesh = bpy.data.meshes.new(name)
        acc.to_mesh(mesh)
        acc.free()
        mesh.color_attributes.active_color = mesh.color_attributes["Color"]
        mesh.color_attributes.render_color_index = mesh.color_attributes.active_color_index
        for slot in slots:
            mesh.materials.append(material(slot))
        obj = bpy.data.objects.new(name, mesh)
        bpy.context.scene.collection.objects.link(obj)
        obj.parent = parent
        obj.location = sky.xyz(origin)
        return obj
    verts, tris, cols, mats, slots = [], [], [], [], []
    for surf, slot in parts:
        if not surf.t:
            continue
        if slot is not None and slot not in slots:
            slots.append(slot)
        mi = slots.index(slot) if slot is not None else 0
        b = len(verts)
        verts += [sky.xyz(vsub(v, origin)) for v in surf.v]
        cols += surf.c
        tris += [(a + b, c + b, d + b) for a, c, d in surf.t]
        mats += [mi] * len(surf.t)
    mesh = bpy.data.meshes.new(name)
    mesh.from_pydata(verts, [], tris)
    mesh.update()
    attr = mesh.color_attributes.new(name="Color", type="FLOAT_COLOR", domain="CORNER")
    for poly in mesh.polygons:
        poly.use_smooth = False
        poly.material_index = mats[poly.index]
        for li in poly.loop_indices:
            attr.data[li].color = common.rgba(cols[mesh.loops[li].vertex_index])
    mesh.color_attributes.active_color = attr
    for slot in slots:
        mesh.materials.append(material(slot))
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.scene.collection.objects.link(obj)
    obj.parent = parent
    obj.location = sky.xyz(origin)
    return obj


def export_glb(path, nodes, empties, soft=False):
    """nodes: [(name, parts, origin)]; empties: {name: local point}. Returns the measured row read back from the file."""
    common.reset()
    root = common.empty(Path(path).stem + "_root")
    drawn_nodes = [n for n in nodes if soft and n[1] and all(slot is not None for _, slot in n[1])]
    o = soft_options(drawn_nodes) if drawn_nodes else None
    for name, parts, origin in nodes:
        if soft and parts and all(slot is not None for _, slot in parts):
            make_mesh(name, parts, root, origin, soft=o)
    if o is not None:
        bpy.context.view_layer.update()
        polish.bake(root, o)        # before any collider joins the scene: it must not occlude the bake or take its UVs
    for name, parts, origin in nodes:
        if not (soft and parts and all(slot is not None for _, slot in parts)):
            make_mesh(name, parts, root, origin)
    for name, loc in empties.items():
        common.empty(name, sky.xyz(loc), root)
    common.export(root, str(path))
    row = sky.read_glb(path)
    row["sha256"] = hashlib.sha256(Path(path).read_bytes()).hexdigest()
    return row


def drawn(row):
    return {k: m for k, m in row["meshes"].items() if not k.endswith("-col")}


def build(rid, out_dir, count_only=False):
    spec = BUILDERS[rid]()
    rows = {"recipe": rid, "counts": budgets(rid, spec), "clear_m": check_clear(rid, spec), "pins": check_card(rid, spec)}
    if count_only:
        return rows
    out = Path(out_dir)
    merged = View(rid)
    merged.absorb(spec["base"])
    merged.absorb(spec["exempt"])
    nodes = [(rid, merged.surfs(), (0.0, 0.0, 0.0))]
    for view, origin in spec["nodes"]:
        nodes.append((view.name, view.surfs(), origin))
    nodes.append((rid + "-col-col", [(spec["col"], None)], (0.0, 0.0, 0.0)))
    glb = {}
    glb[rid] = export_glb(out / (rid + ".glb"), nodes, spec["empties"], soft=True)
    for k, sh in enumerate(spec["shells"], start=1):
        name = "%s_detail%d" % (rid, k)
        glb[name] = export_glb(out / (name + ".glb"), [(name, [(sh, spec["shell_slot"])], (0.0, 0.0, 0.0))], {}, soft=True)
    for view_name in ("mid", "far"):
        name = "%s_%s" % (rid, view_name)
        glb[name] = export_glb(out / (name + ".glb"), [(name, spec[view_name].surfs(), (0.0, 0.0, 0.0))], {})
    for name, extra in spec.get("extra", {}).items():
        glb[name] = export_glb(out / (name + ".glb"), extra["nodes"], extra["empties"])
    # read back: the base's draws, the class caps, the empties and the -col node
    b = glb[rid]
    draws = sum(m["draws"] for m in b["meshes"].values())      # every primitive, the -col mesh included, as budget_audit counts
    tris = sum(m["tris"] for m in b["meshes"].values())
    verts = sum(m["verts"] for m in b["meshes"].values())
    assert draws <= HERO["draws"] and tris <= HERO["tris"] and verts <= HERO["verts"], (rid, draws, tris, verts)
    assert rid + "-col-col" in b["meshes"], (rid, list(b["meshes"]))
    for name in spec["empties"]:
        assert name in b["nodes"], (rid, "empty", name)
    for k in (1, 2):
        m = glb["%s_detail%d" % (rid, k)]["meshes"]["%s_detail%d" % (rid, k)]
        assert m["draws"] == 1 and m["tris"] <= DETAIL["tris"] and m["verts"] <= DETAIL["verts"], (rid, k, m)
    assert sum(m["tris"] for m in glb[rid + "_mid"]["meshes"].values()) <= HERO["mid_tris"], rid
    assert sum(m["tris"] for m in glb[rid + "_far"]["meshes"].values()) <= HERO["far_tris"], rid
    rows["base_draws"] = draws
    rows["glb"] = {name: {"sha256": g["sha256"], "tris": sum(m["tris"] for m in g["meshes"].values()),
                          "verts": sum(m["verts"] for m in g["meshes"].values()), "materials": g["materials"]}
                   for name, g in glb.items()}
    return rows


def main():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    parser = argparse.ArgumentParser()
    parser.add_argument("--out-dir", default=str(MODELS))
    parser.add_argument("--only", default="")
    parser.add_argument("--count-only", action="store_true")
    args = parser.parse_args(argv)
    ids = [i for i in args.only.split(",") if i] or list(BUILDERS)
    shas = {}
    for rid in ids:
        row = build(rid, args.out_dir, args.count_only)
        print("LANDMARK", rid, json.dumps(row, sort_keys=True))
        shas.update({k: v["sha256"] for k, v in row.get("glb", {}).items()})
    if shas:
        print("LANDMARK_SHA256", json.dumps(shas, sort_keys=True))


if __name__ == "__main__":
    main()
