"""Headless recipes for the grind-line family of the park (design-v3/PARK.md section 4, unit KC2): canal_lip, flume_span,
penstock_run and pipeline_rail. Each recipe id builds three GLBs under assets/models/park/: <id>.glb (the render mesh, a
"<id>-col" collision mesh and the rail line), <id>_detail1.glb and <id>_detail2.glb (the two detail shells that
park_recipes.gd draws at 60 m and 25 m).

Convention, the same for the whole family (a park row places the GLB with position, yaw and, for the ground, nothing else;
park_recipes.gd does not scale a GLB):
  +Y up, the ride direction is +Z (the fall line), the origin is the piece's entry lip: x 0 on the piece's centre line,
  y 0 on the entry ground, z 0 at the entry. The piece is LENGTH (120 m) long and falls FALL (3 m) over that length,
  so the whole structure is built level and then pitched about the origin by atan(FALL / LENGTH). Ends match across
  the family's pieces of one id, so a row longer than one piece tiles them end to end (the exit of one is the entry of
  the next at z = LENGTH, y = -FALL).
  The rideable top of each piece is a flat strip at least 2 m wide (a ball is 2 m across); every other face the harpoon
  can reach is steep (normal.y at most 0.7, augments.gd WALKABLE_Y), so the line bites a wall, a pipe flank or a deck edge
  and never the top.

The rail line is data the GLB carries: empties named "<id>-rail_00", "<id>-rail_01", ... in ride order, each ON the rideable
top (the ball's centre rides one radius, 1 m, above it). The collision mesh is the mesh object named "<id>-col-col" in the same
GLB (the importer strips one suffix, see COL_NODE), which imports as "<id>-col"; park_recipes.gd makes its one ConcaveShape
from the importer's body and never draws it. One material slot, "enamel" (a vertex-colour slot),
colours are palette-and-Southwest hexes only: sandstone, cream, red slickrock, iron oxide, desert varnish, sage, juniper,
dam-era concrete grey, copper #b77843 for machinery (never brass).

Real-culture guardrail (PARK.md section 4): the canal lip is a shaped reference to how an irrigation canal holds a lip and
nothing in it names, depicts or speaks for a living people.

  prlimit (12 GiB address space) -- blender --background --threads 2 --python-exit-code 1 --python \
      sketches/core-loop/tools/blender/park/grind.py -- [--out-dir DIR] [--only ID] [--count-only]
"""
import argparse
import hashlib
import json
import math
from pathlib import Path
import struct
import sys
import tempfile

from mathutils import Vector

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE.parent / "dig_mechanical"))
import kit
import common

MODELS = kit.SKETCH / "assets/models/park"
COL_NODE = "-col-col"

LENGTH = 120.0
FALL = 3.0
PITCH = math.atan2(FALL, LENGTH)
BUDGET = {"base": {"tris": 8000, "draws": 2}, "detail": {"tris": 1500, "draws": 1}}
MIN_TOP = 2.0
RIDE_PROUD = 0.02
RAIL_STEP = 30.0
END_INSET = 0.5

SAND = "c6a274"
CREAM = "dccaa2"
SLICK = "b0653f"
OXIDE = "9b513a"
IRON = "7a4332"
VARNISH = "4a3a30"
CONCRETE = "a7a49a"
FORM = "8b8880"
SAGE = "8a9a78"
JUNIPER = "4f6b4a"
COPPER = "b77843"
DARK = "2f2a26"

SIZE = {
    "canal_lip": [LENGTH, 3.0, 8.8],
    "flume_span": [LENGTH, 8.0, 8.0],
    "penstock_run": [LENGTH, 5.0, 4.4],
    "pipeline_rail": [LENGTH, 3.0, 4.2],
}
IDS = list(SIZE)


def tilt(p):
    """A level-frame point pitched about the entry origin so +Z falls FALL over LENGTH."""
    x, y, z = p
    c, s = math.cos(PITCH), math.sin(PITCH)
    return (x, y * c - z * s, z * c + y * s)


def tone(base, other=None, k=0, span=0.22):
    """A deterministic jitter of a palette hex toward another, by index k: no randomness, so a rebuild is byte-identical."""
    other = other or VARNISH
    t = ((k * 37 + 11) % 13) / 12.0 * span
    return common.mix(base, other, t)


class Surf(kit.Surface):
    def add(self, verts, faces, color="petrol", colors=None):
        super().add([tilt(v) for v in verts], faces, color, colors)


def solid(s, ring, z0, z1, color):
    """A closed prism: the (x, y) ring extruded from z0 to z1 (convex rings only, so every cap is one polygon)."""
    n = len(ring)
    verts = [(x, y, z0) for x, y in ring] + [(x, y, z1) for x, y in ring]
    faces = [tuple(reversed(range(n))), tuple(range(n, 2 * n))]
    faces += [(i, (i + 1) % n, n + (i + 1) % n, n + i) for i in range(n)]
    s.add(verts, faces, color)


def block(s, x0, x1, y0, y1, z0, z1, color):
    solid(s, [(x0, y0), (x1, y0), (x1, y1), (x0, y1)], z0, z1, color)


def disc(cx, cy, r, n=16, spin=0.0):
    return [(cx + r * math.cos(spin + math.tau * i / n), cy + r * math.sin(spin + math.tau * i / n)) for i in range(n)]


def strut(s, a, b, w, color, d=None):
    """A square-section bar from a to b (any direction), w by d across."""
    a, b = Vector(a), Vector(b)
    axis = (b - a).normalized()
    ref = Vector((0, 0, 1)) if abs(axis.z) < 0.9 else Vector((1, 0, 0))
    e1 = axis.cross(ref).normalized() * (w / 2)
    e2 = axis.cross(e1).normalized() * ((d or w) / 2)
    corners = [-e1 - e2, e1 - e2, e1 + e2, -e1 + e2]
    verts = [tuple(a + c) for c in corners] + [tuple(b + c) for c in corners]
    faces = [(3, 2, 1, 0), (4, 5, 6, 7)] + [(i, (i + 1) % 4, 4 + (i + 1) % 4, 4 + i) for i in range(4)]
    s.add(verts, faces, color)


def stud(s, c, axis, r, h, color, sides=4):
    """A bolt head: a short frustum standing on c along axis (base open, it sits on a surface)."""
    a = Vector(axis).normalized()
    e1 = a.cross(Vector((0, 1, 0)) if abs(a.y) < 0.9 else Vector((1, 0, 0))).normalized()
    e2 = a.cross(e1)
    c = Vector(c)
    base = [tuple(c + (e1 * math.cos(math.pi / 4 + math.tau * i / sides) + e2 * math.sin(math.pi / 4 + math.tau * i / sides)) * r) for i in range(sides)]
    top = [tuple(c + a * h + (e1 * math.cos(math.pi / 4 + math.tau * i / sides) + e2 * math.sin(math.pi / 4 + math.tau * i / sides)) * r * 0.7) for i in range(sides)]
    faces = [(i, (i + 1) % sides, sides + (i + 1) % sides, sides + i) for i in range(sides)] + [tuple(range(sides, 2 * sides))]
    s.add(base + top, faces, color)


def tuft(s, x, y, z, size, k):
    """A sage or juniper tuft: three leaning cones, 5 sides each."""
    for j in range(3):
        a = math.tau * (j / 3.0 + 0.11 * (k % 5))
        lean = Vector((math.cos(a), 0.0, math.sin(a))) * size * 0.28
        base = [(x + size * 0.14 * math.cos(math.tau * i / 5), y, z + size * 0.14 * math.sin(math.tau * i / 5)) for i in range(5)]
        tip = (x + lean.x, y + size * (0.9 - 0.15 * j), z + lean.z)
        s.add(base + [tip], [(4, 3, 2, 1, 0)] + [(i, (i + 1) % 5, 5) for i in range(5)], tone(SAGE if (k + j) % 3 else JUNIPER, VARNISH, k + j, 0.3))


def rocks(s, rows, color_a, color_b):
    """Rows of (x, y, z, size, yaw): irregular boulders, 8 faces each, seated half in the ground."""
    for k, (x, y, z, size, yaw) in enumerate(rows):
        h = size / 2.0
        ring = [(x + h * math.cos(yaw + math.tau * i / 5) * (0.8 + 0.2 * ((i + k) % 3)), z + h * math.sin(yaw + math.tau * i / 5) * (0.8 + 0.2 * ((i * 2 + k) % 3))) for i in range(5)]
        low = [(px, y - size * 0.1, pz) for px, pz in ring]
        high = [(x + (px - x) * 0.55, y + size * 0.55, z + (pz - z) * 0.55) for px, pz in ring]
        faces = [(0, 1, 2, 3, 4)[::-1], (5, 6, 7, 8, 9)] + [(i, (i + 1) % 5, 5 + (i + 1) % 5, 5 + i) for i in range(5)]
        s.add(low + high, faces, tone(color_a, color_b, k, 0.35))


CANAL = {"floor": 1.5, "crest_in": 1.9, "crest_out": 4.0, "toe": 4.4, "top": 3.0, "bottom": -4.0, "bay": 6.0}
CANAL_RAIL_X = (CANAL["crest_in"] + CANAL["crest_out"]) / 2


def canal_ring(side):
    c = CANAL
    ring = [(c["floor"], c["bottom"]), (c["toe"], c["bottom"]), (c["crest_out"], c["top"]), (c["crest_in"], c["top"]), (c["floor"], 0.0)]
    return [(side * x, y) for x, y in ring] if side > 0 else [(side * x, y) for x, y in ring][::-1]


def canal_col(s):
    c = CANAL
    for side in (-1, 1):
        solid(s, canal_ring(side), 0.0, LENGTH, DARK)
    block(s, -c["floor"], c["floor"], c["bottom"], 0.0, 0.0, LENGTH, DARK)


def canal_body(s):
    c = CANAL
    bays = int(LENGTH / c["bay"])
    for k in range(bays):
        z0, z1 = k * c["bay"], (k + 1) * c["bay"]
        for side in (-1, 1):
            ring = [(side * x, y) for x, y in [(c["floor"], c["bottom"]), (c["toe"], c["bottom"]), (c["crest_out"], c["top"] - 0.04), (c["crest_in"], c["top"] - 0.04), (c["floor"], 0.0)]]
            solid(s, ring if side > 0 else ring[::-1], z0, z1, tone(SLICK, SAND, k + (side > 0), 0.35))
            xa, xb = sorted((side * c["crest_in"], side * c["crest_out"]))
            block(s, xa, xb, c["top"] - 0.04, c["top"], z0 + 0.02, z1 - 0.02, tone(CREAM, SAND, k * 3 + (side > 0), 0.2))
            wall = [(side * (c["floor"] + 0.001), 0.0), (side * (c["crest_in"] + 0.001), c["top"] - 0.04)]
            ring = [wall[0], (wall[0][0] + side * 0.04, wall[0][1]), (wall[1][0] + side * 0.04, wall[1][1]), wall[1]]
            solid(s, ring if side > 0 else ring[::-1], z0 + 0.03, z1 - 0.03, tone(CONCRETE, VARNISH, k + 2 * (side > 0), 0.35))
    gz = 60.0
    for dz in (-1.0, 1.0):
        block(s, -3.7, -2.3, c["top"], c["top"] + 1.6, gz + dz - 0.3, gz + dz + 0.3, tone(CONCRETE, FORM, 3))
    block(s, -3.7, -2.3, c["top"] + 1.6, c["top"] + 1.8, gz - 1.3, gz + 1.3, tone(CREAM, SAND, 1))
    block(s, -c["floor"] + 0.05, c["floor"] - 0.05, 0.0, 2.2, gz - 0.08, gz + 0.08, tone(IRON, VARNISH, 2))
    strut(s, (-3.0, c["top"] + 1.8, gz), (-0.3, 2.1, gz), 0.1, tone(IRON, VARNISH, 5))
    s.add(*_wheel(-3.0, c["top"] + 2.2, gz, 0.42), color=COPPER)
    rows = []
    for k in range(20):
        side = -1 if k % 2 else 1
        rows.append((side * (c["toe"] + 0.1 + 0.3 * ((k * 5) % 3)), -0.6 - ((k * 7) % 4) * 0.12, 3.0 + k * 5.9, 0.9 + 0.5 * ((k * 3) % 4), 0.4 * k))
    rocks(s, rows, SLICK, SAND)


def _wheel(x, y, z, r):
    """A hand wheel in the x-y plane: a 10-sided rim ring and four spokes, as one vertex-and-face list."""
    n = 10
    outer = [(x + r * math.cos(math.tau * i / n), y + r * math.sin(math.tau * i / n), z - 0.03) for i in range(n)]
    inner = [(x + r * 0.8 * math.cos(math.tau * i / n), y + r * 0.8 * math.sin(math.tau * i / n), z - 0.03) for i in range(n)]
    outer2 = [(a, b, z + 0.03) for a, b, _ in outer]
    inner2 = [(a, b, z + 0.03) for a, b, _ in inner]
    verts = outer + inner + outer2 + inner2
    faces = []
    for i in range(n):
        j = (i + 1) % n
        faces += [(i, j, n + j, n + i), (2 * n + i, 3 * n + i, 3 * n + j, 2 * n + j), (i, 2 * n + i, 2 * n + j, j), (n + i, n + j, 3 * n + j, 3 * n + i)]
    return verts, faces


def canal_rail():
    return [(CANAL_RAIL_X, CANAL["top"], z) for z in _stops()]


def canal_detail1(s):
    c = CANAL
    for k in range(1, int(LENGTH / c["bay"])):
        z = k * c["bay"]
        if k % 2 == 0:
            for side in (-1, 1):
                xa, xb = sorted((side * (c["crest_in"] + 0.15), side * (c["crest_out"] - 0.15)))
                block(s, xa, xb, c["top"], c["top"] + 0.012, z - 0.12, z + 0.12, tone(IRON, VARNISH, k))
        for side in (-1, 1):
            for dy in ((0.9, 2.1) if k % 2 else ()):
                stud(s, (side * (c["floor"] + (c["crest_in"] - c["floor"]) * dy / c["top"] + 0.045), dy, z), (-side, 0.0, 0.0), 0.05, 0.03, tone(IRON, DARK, k))
    for dz in (-1.0, 1.0):
        for dy in (0.3, 0.9, 1.4):
            for sx in (-3.7, -2.3):
                stud(s, (sx, c["top"] + dy, 60.0 + dz + 0.3), (0, 0, 1), 0.06, 0.04, tone(IRON, DARK, 1))
    for yy in (0.4, 1.1, 1.8):
        for xx in (-1.1, -0.4, 0.4, 1.1):
            stud(s, (xx, yy, 60.08), (0, 0, 1), 0.05, 0.03, tone(IRON, DARK, 2))
    for z in range(6, 120, 24):
        for side in (-1, 1):
            block(s, side * (c["toe"] + 0.7) - 0.07, side * (c["toe"] + 0.7) + 0.07, -0.4, 0.5, z - 0.07, z + 0.07, tone(IRON, VARNISH, z))


def canal_detail2(s):
    c = CANAL
    for k in range(16):
        side = -1 if k % 2 else 1
        tuft(s, side * (c["toe"] + 0.9 + 0.35 * ((k * 5) % 3)), -0.5, 2.0 + k * 7.4, 0.7 + 0.18 * (k % 4), k)
    rows = [(((k * 13) % 7 - 3) * 0.3, 0.0, 1.0 + k * 2.9, 0.22 + 0.06 * (k % 4), 0.7 * k) for k in range(40)]
    rocks(s, rows, SAND, VARNISH)
    for k in range(10):
        z = 4.5 + k * 11.3
        for side in (-1, 1):
            if (k + (side > 0)) % 2:
                continue
            xin = side * (c["floor"] + (c["crest_in"] - c["floor"]) * 0.5 + 0.052)
            block(s, xin, xin + side * 0.008, 0.4, 2.9, z, z + 0.16, VARNISH)


FLUME = {"floor_y": 5.0, "under": 4.0, "wall_in": 1.6, "crest_in": 1.9, "crest_out": 4.0, "base_out": 3.6, "top": 8.0, "bent": 12.0, "ground": -6.0}
FLUME_RAIL_X = (FLUME["crest_in"] + FLUME["crest_out"]) / 2


def flume_ring(side):
    f = FLUME
    ring = [(f["wall_in"], f["under"]), (f["base_out"], f["under"]), (f["crest_out"], f["top"]), (f["crest_in"], f["top"]), (f["wall_in"], f["floor_y"])]
    return [(side * x, y) for x, y in ring] if side > 0 else [(side * x, y) for x, y in ring][::-1]


def flume_bents():
    return [k * FLUME["bent"] for k in range(int(LENGTH / FLUME["bent"]) + 1)]


def flume_frame(s, z, col, k=0):
    """One trestle bent: two splayed legs, a cap beam and an X brace."""
    f = FLUME
    w = 0.5
    paint = lambda a, i=0: DARK if col else tone(a, VARNISH, k + i)
    for side in (-1, 1):
        strut(s, (side * 2.6, f["under"] - 0.05, z), (side * 3.7, f["ground"], z), w, paint(IRON))
    block(s, -4.3, 4.3, f["under"] - 0.6, f["under"], z - 0.35, z + 0.35, paint(IRON, 1))
    if not col:
        strut(s, (-3.4, f["ground"] + 1.5, z), (3.4, f["under"] - 0.6, z), 0.22, paint(OXIDE, 2))
        strut(s, (3.4, f["ground"] + 1.5, z), (-3.4, f["under"] - 0.6, z), 0.22, paint(OXIDE, 3))


def flume_col(s):
    f = FLUME
    for side in (-1, 1):
        solid(s, flume_ring(side), 0.0, LENGTH, DARK)
    block(s, -f["wall_in"], f["wall_in"], f["under"], f["floor_y"], 0.0, LENGTH, DARK)
    for z in flume_bents():
        flume_frame(s, z, True)


def flume_body(s):
    f = FLUME
    bays = int(LENGTH / 3.0)
    for k in range(bays):
        z0, z1 = k * 3.0, (k + 1) * 3.0
        for side in (-1, 1):
            ring = [(side * x, y) for x, y in [(f["wall_in"], f["under"]), (f["base_out"], f["under"]), (f["crest_out"], f["top"] - 0.04), (f["crest_in"], f["top"] - 0.04), (f["wall_in"], f["floor_y"])]]
            solid(s, ring if side > 0 else ring[::-1], z0, z1, tone(CONCRETE, FORM, k + (side > 0), 0.4))
            xa, xb = sorted((side * f["crest_in"], side * f["crest_out"]))
            block(s, xa, xb, f["top"] - 0.04, f["top"], z0 + 0.02, z1 - 0.02, tone(CONCRETE, CREAM, k * 5 + (side > 0), 0.3))
        block(s, -f["wall_in"], f["wall_in"], f["under"], f["floor_y"], z0, z1, tone(VARNISH, CONCRETE, k, 0.5))
    for k, z in enumerate(flume_bents()):
        flume_frame(s, z, False, k)
    for z in flume_bents():
        for side in (-1, 1):
            ring = [(side * f["base_out"], f["under"]), (side * (f["base_out"] + 0.06), f["under"]), (side * (f["crest_out"] + 0.06), f["top"] - 0.5), (side * f["crest_out"], f["top"] - 0.5)]
            solid(s, ring if side > 0 else ring[::-1], z - 0.2, z + 0.2, tone(IRON, DARK, int(z)))


def flume_rail():
    return [(FLUME_RAIL_X, FLUME["top"], z) for z in _stops()]


def flume_detail1(s):
    f = FLUME
    for z in flume_bents():
        for side in (-1, 1):
            for dy in (4.8, 6.6):
                frac = (dy - f["under"]) / (f["top"] - f["under"])
                stud(s, (side * (f["base_out"] + 0.06 + (f["crest_out"] - f["base_out"]) * frac), dy, z + 0.2), (0, 0, 1), 0.06, 0.04, tone(IRON, DARK, int(z)))
        for sx in (-3.7, 3.7):
            stud(s, (sx, f["under"] - 0.3, z + 0.35), (0, 0, 1), 0.07, 0.05, tone(IRON, DARK, 3))
    for k in range(1, int(LENGTH / 3.0)):
        z = k * 3.0
        if k % 4 == 0:
            for side in (-1, 1):
                xa, xb = sorted((side * (f["crest_in"] + 0.15), side * (f["crest_out"] - 0.15)))
                block(s, xa, xb, f["top"], f["top"] + 0.012, z - 0.1, z + 0.1, tone(IRON, VARNISH, k))


def flume_detail2(s):
    f = FLUME
    for k in range(18):
        z = 1.6 + k * 6.7
        side = -1 if k % 2 else 1
        xo = side * (f["base_out"] + 0.4 * (0.5 + 0.5 * ((k * 3) % 4) / 3.0)) + side * 0.015
        block(s, min(xo, xo + side * 0.008), max(xo, xo + side * 0.008), f["under"] + 0.4, f["under"] + 3.0, z, z + 0.18, VARNISH)
    for z in flume_bents():
        for side in (-1, 1):
            block(s, side * 3.9 - 0.04, side * 3.9 + 0.04, f["under"] - 0.5, f["under"] - 0.05, z + 0.2, z + 0.3, tone(OXIDE, IRON, int(z)))
    for k, z in enumerate(flume_bents()):
        tuft(s, 3.9 + 0.2 * (k % 3), 0.0, z + 0.8, 0.9, k)
        tuft(s, -3.9 - 0.2 * (k % 3), 0.0, z - 0.8, 0.8, k + 1)


PEN = {"cy": 2.6, "r": 1.8, "n": 16, "deck_y": 5.0, "deck_half": 1.1, "deck_thick": 0.12, "saddle": 15.0, "flange": 10.0, "ground": -6.0}
PEN_RAIL_X = 0.0


def pen_col(s):
    p = PEN
    solid(s, disc(0.0, p["cy"], p["r"], p["n"], math.pi / p["n"]), 0.0, LENGTH, DARK)
    block(s, -p["deck_half"], p["deck_half"], p["deck_y"] - p["deck_thick"], p["deck_y"], 0.0, LENGTH, DARK)
    for z in _saddles():
        block(s, -2.2, 2.2, p["ground"], p["cy"] - p["r"] * 0.55, z - 1.0, z + 1.0, DARK)
    for z in (0.0, LENGTH):
        block(s, -2.2, 2.2, p["ground"], p["cy"] + p["r"] * 0.6, z - 1.2 if z else z, z if z else z + 1.2, DARK)


def _saddles():
    return [k * PEN["saddle"] for k in range(1, int(LENGTH / PEN["saddle"]))] + [7.5]


def pen_body(s):
    p = PEN
    segs = int(LENGTH / 5.0)
    for k in range(segs):
        z0, z1 = k * 5.0, (k + 1) * 5.0
        solid(s, disc(0.0, p["cy"], p["r"], p["n"], math.pi / p["n"]), z0 + 0.01, z1 - 0.01, tone(IRON, SLICK, k, 0.3 + 0.1 * (k % 3)))
    for k in range(1, int(LENGTH / p["flange"])):
        z = k * p["flange"]
        solid(s, disc(0.0, p["cy"], p["r"] + 0.16, p["n"], math.pi / p["n"]), z - 0.14, z + 0.14, tone(OXIDE, DARK, k, 0.4))
    for z in sorted(set(_saddles())):
        block(s, -2.2, 2.2, p["ground"], p["cy"] - p["r"] * 0.55, z - 1.0, z + 1.0, tone(CONCRETE, FORM, int(z)))
        block(s, -2.45, 2.45, p["cy"] - p["r"] * 0.55 - 0.3, p["cy"] - p["r"] * 0.55, z - 1.2, z + 1.2, tone(CONCRETE, FORM, int(z) + 1))
    for z, a, b in ((0.0, -1.2, 0.0), (LENGTH, 0.0, 1.2)):
        block(s, -2.2, 2.2, p["ground"], p["cy"] + p["r"] * 0.6, z + a, z + b, tone(CONCRETE, FORM, 9))
    block(s, -p["deck_half"], p["deck_half"], p["deck_y"] - p["deck_thick"], p["deck_y"], 0.0, LENGTH, tone(IRON, DARK, 4, 0.5))
    for z in range(3, int(LENGTH), 6):
        for sx in (-0.8, 0.8):
            block(s, sx - 0.08, sx + 0.08, p["cy"] + p["r"] - 0.15, p["deck_y"] - p["deck_thick"], z - 0.08, z + 0.08, tone(IRON, DARK, z))
    strut(s, (-p["r"] - 0.05, p["cy"] - 0.4, 45.0), (-p["r"] - 0.7, p["cy"] - 0.4, 45.0), 0.18, COPPER)
    s.add(*_rim(-p["r"] - 0.7, p["cy"] - 0.4, 45.0, 0.3), color=COPPER)
    ring = [(-p["r"] + 0.02 - 0.1 * math.cos(a), p["cy"] + 0.45 * math.sin(a)) for a in (math.tau * i / 8 for i in range(8))]
    solid(s, [(x, y) for x, y in ring], 89.5, 90.5, tone(COPPER, VARNISH, 1, 0.15))


def _rim(x, y, z, r):
    """A hand wheel in the y-z plane (a wheel on a stem along x), reusing the x-y wheel with axes swapped."""
    verts, faces = _wheel(0.0, 0.0, 0.0, r)
    return [(x + c, y + a, z + b) for a, b, c in verts], faces


def pen_rail():
    return [(PEN_RAIL_X, PEN["deck_y"], z) for z in _stops()]


def pen_detail1(s):
    p = PEN
    n = p["n"]
    for k in range(1, int(LENGTH / p["flange"])):
        z = k * p["flange"]
        for i in range(n):
            a = math.pi / n + math.tau * i / n
            if i % 4 or math.sin(a) > 0.82:
                continue
            for dz in (-0.14, 0.14):
                stud(s, (math.cos(a) * (p["r"] + 0.16), p["cy"] + math.sin(a) * (p["r"] + 0.16), z + dz), (0, 0, dz), 0.07, 0.05, tone(IRON, DARK, k + i))
    for k in range(1, int(LENGTH / 5.0)):
        z = k * 5.0
        if k % 4 != 1:
            continue
        for side in (-1, 1):
            for dy in (-0.9, 0.0, 0.9):
                ang = math.asin(dy / p["r"])
                stud(s, (side * math.cos(ang) * p["r"], p["cy"] + dy, z), (side, 0, 0), 0.05, 0.03, tone(IRON, DARK, k))


def pen_detail2(s):
    p = PEN
    for k in range(10):
        z = 6.0 + k * 11.3
        side = -1 if k % 2 else 1
        ang = math.radians(10 + 12 * (k % 4))
        block(s, side * (p["r"] * math.cos(ang)) - 0.01, side * (p["r"] * math.cos(ang)) + 0.01, p["cy"] - 1.2, p["cy"] + 0.6, z, z + 0.14, VARNISH)
    for k, z in enumerate(_saddles()):
        tuft(s, 2.6, 0.0, z + 0.9, 0.9, k)
        tuft(s, -2.6, 0.0, z - 0.9, 0.8, k + 1)
    rocks(s, [(((k * 5) % 7 - 3) * 0.9, 0.0, 2.0 + k * 6.3, 0.5 + 0.15 * (k % 3), 0.5 * k) for k in range(18)], SAND, SLICK)


PIPE = {"deck_y": 3.0, "deck_half": 1.2, "deck_thick": 0.12, "beam_lo": 2.4, "pipe_x": 0.7, "pipe_y": 1.55, "pipe_r": 0.55, "tie_y": 0.9, "stand": 8.0, "ground": -5.0, "foot": 2.1}
PIPE_RAIL_X = 0.0


def pipe_stands():
    return [k * PIPE["stand"] for k in range(int(LENGTH / PIPE["stand"]) + 1)]


def pipe_stand(s, z, col, k=0):
    p = PIPE
    paint = lambda a, i=0: DARK if col else tone(a, VARNISH, k + i)
    block(s, -1.5, 1.5, p["beam_lo"], p["deck_y"] - p["deck_thick"], z - 0.18, z + 0.18, paint(IRON))
    for side in (-1, 1):
        strut(s, (side * 1.3, p["beam_lo"], z), (side * p["foot"], p["ground"], z), 0.28, paint(IRON, 1))
    block(s, -1.6, 1.6, p["tie_y"] - 0.2, p["tie_y"], z - 0.16, z + 0.16, paint(OXIDE, 2))
    if not col:
        strut(s, (-1.4, p["tie_y"], z), (p["foot"] - 0.2, p["ground"] + 1.0, z), 0.14, paint(OXIDE, 3))
        strut(s, (1.4, p["tie_y"], z), (-(p["foot"] - 0.2), p["ground"] + 1.0, z), 0.14, paint(OXIDE, 4))


def pipe_col(s):
    p = PIPE
    block(s, -p["deck_half"], p["deck_half"], p["deck_y"] - p["deck_thick"], p["deck_y"], 0.0, LENGTH, DARK)
    for sx in (-1, 1):
        solid(s, disc(sx * p["pipe_x"], p["pipe_y"], p["pipe_r"], 12), 0.0, LENGTH, DARK)
    for z in pipe_stands():
        pipe_stand(s, z, True)


def pipe_body(s):
    p = PIPE
    for sx in (-1, 1):
        for k in range(int(LENGTH / 4.0)):
            z0 = k * 4.0
            solid(s, disc(sx * p["pipe_x"], p["pipe_y"], p["pipe_r"], 12), z0 + 0.01, z0 + 3.99, tone(CONCRETE, OXIDE, k + (sx > 0), 0.4))
    for z in range(8, int(LENGTH), 8):
        for sx in (-1, 1):
            solid(s, disc(sx * p["pipe_x"], p["pipe_y"], p["pipe_r"] + 0.08, 12), z - 0.12, z + 0.12, tone(IRON, DARK, z))
    for z in (32.0, 64.0, 96.0):
        for sx in (-1, 1):
            for dz in (-0.22, 0.22):
                solid(s, disc(sx * p["pipe_x"], p["pipe_y"], p["pipe_r"] + 0.12, 12), z + dz - 0.08, z + dz + 0.08, COPPER)
    strut(s, (p["pipe_x"] + 0.4, p["pipe_y"] - 0.3, 60.0), (p["pipe_x"] + 1.0, p["pipe_y"] - 0.3, 60.0), 0.14, tone(IRON, DARK, 6))
    s.add(*_rim(p["pipe_x"] + 1.0, p["pipe_y"] - 0.3, 60.0, 0.32), color=COPPER)
    block(s, -p["deck_half"], p["deck_half"], p["deck_y"] - p["deck_thick"], p["deck_y"], 0.0, LENGTH, tone(IRON, DARK, 7, 0.5))
    for z in pipe_stands():
        pipe_stand(s, z, False, int(z))


def pipe_rail():
    return [(PIPE_RAIL_X, PIPE["deck_y"], z) for z in _stops()]


def pipe_detail1(s):
    p = PIPE
    for z in range(16, int(LENGTH), 16):
        for sx in (-1, 1):
            for i in range(0, 8, 3):
                a = math.tau * i / 8 + 0.2
                if math.sin(a) > 0.7:
                    continue
                for dz in (-0.12, 0.12):
                    stud(s, (sx * p["pipe_x"] + math.cos(a) * (p["pipe_r"] + 0.08), p["pipe_y"] + math.sin(a) * (p["pipe_r"] + 0.08), z + dz), (0, 0, dz), 0.045, 0.035, tone(IRON, DARK, z + i))
    for z in pipe_stands():
        for sx in (-1.3, 1.3):
            stud(s, (sx, p["beam_lo"] + 0.2, z + 0.18), (0, 0, 1), 0.06, 0.04, tone(IRON, DARK, int(z)))


def pipe_detail2(s):
    p = PIPE
    for k, z in enumerate(pipe_stands()):
        tuft(s, 2.4, 0.0, z + 0.6, 0.8, k)
        tuft(s, -2.4, 0.0, z - 0.6, 0.8, k + 1)
    for k in range(12):
        z = 3.0 + k * 9.7
        sx = -1 if k % 2 else 1
        block(s, sx * p["pipe_x"] - 0.12, sx * p["pipe_x"] + 0.12, p["pipe_y"] - p["pipe_r"] - 0.006, p["pipe_y"] - p["pipe_r"] + 0.0, z, z + 0.2, VARNISH)
    rocks(s, [(((k * 5) % 7 - 3) * 0.7, 0.0, 2.0 + k * 6.3, 0.4 + 0.12 * (k % 3), 0.5 * k) for k in range(16)], SAND, SLICK)


def _stops():
    """Rail points from END_INSET inside the entry to END_INSET inside the exit: the ends sit on the top, never on the cut face."""
    n = int(round(LENGTH / RAIL_STEP))
    return [END_INSET + (LENGTH - 2 * END_INSET) * k / n for k in range(n + 1)]


RECIPES = {
    "canal_lip": {"col": canal_col, "body": canal_body, "rail": canal_rail, "d1": canal_detail1, "d2": canal_detail2, "top": (CANAL_RAIL_X, 2.1)},
    "flume_span": {"col": flume_col, "body": flume_body, "rail": flume_rail, "d1": flume_detail1, "d2": flume_detail2, "top": (FLUME_RAIL_X, 2.1)},
    "penstock_run": {"col": pen_col, "body": pen_body, "rail": pen_rail, "d1": pen_detail1, "d2": pen_detail2, "top": (PEN_RAIL_X, 2.2)},
    "pipeline_rail": {"col": pipe_col, "body": pipe_body, "rail": pipe_rail, "d1": pipe_detail1, "d2": pipe_detail2, "top": (PIPE_RAIL_X, 2.4)},
}


def export(name, builders, rail, out_dir):
    """One GLB: each builder is (mesh object name, function). The rail empties come last, in ride order."""
    common.reset()
    kit.PARTS.clear()
    root = common.empty(name + "_recipe")
    for obj_name, fn in builders:
        s = Surf(obj_name, "enamel", smooth=False)
        fn(s)
        s.finish(root)
    for k, p in enumerate(rail):
        common.empty("%s-rail_%02d" % (name, k), kit.xyz(tilt(p)), root)
    path = Path(out_dir) / (name + ".glb")
    common.export(root, str(path))
    return path


def gltf_info(path):
    data = path.read_bytes()
    length = struct.unpack_from("<I", data, 12)[0]
    doc = json.loads(data[20:20 + length])
    meshes = []
    for node in doc["nodes"]:
        if "mesh" in node:
            tris = sum(doc["accessors"][prim["indices"]]["count"] // 3 for prim in doc["meshes"][node["mesh"]]["primitives"])
            meshes.append((node["name"], tris))
    return {"meshes": meshes, "nodes": [n["name"] for n in doc["nodes"]], "metrics": kit.gltf_metrics(path), "lights": "KHR_lights_punctual" in doc.get("extensionsUsed", [])}


def build(rid, out_dir):
    spec = RECIPES[rid]
    rail = spec["rail"]()
    rows = []
    plans = [
        (rid, [(rid + "_body", spec["body"]), (rid + COL_NODE, spec["col"])], rail, "base"),
        (rid + "_detail1", [(rid + "_detail1_mesh", spec["d1"])], [], "detail"),
        (rid + "_detail2", [(rid + "_detail2_mesh", spec["d2"])], [], "detail"),
    ]
    for name, builders, rails, kind in plans:
        path = export(name, builders, rails, out_dir)
        info = gltf_info(path)
        budget = BUDGET[kind]
        tris = info["metrics"]["triangles"]
        assert tris <= budget["tris"], (name, tris, budget)
        assert not info["lights"], (name, "light extension")
        assert info["metrics"]["materials"] == ["enamel"], (name, info["metrics"]["materials"])
        if kind == "base":
            names = [m[0] for m in info["meshes"]]
            assert (rid + COL_NODE) in names, (name, names)
            assert sum(1 for n in info["nodes"] if n.startswith(rid + "-rail_")) == len(rail), (name, info["nodes"])
            size = info["metrics"]["bounds"]["size"]
            want = SIZE[rid]
            assert LENGTH - 1.0 <= size[2] <= LENGTH + 3.0, ("length", size)
            assert 0.8 * want[2] <= size[0] <= 1.6 * want[2], ("width", size, want)
        row = {"file": path.name, "triangles": tris, "draws": info["metrics"]["draws"], "meshes": info["meshes"], "bounds": info["metrics"]["bounds"],
               "sha256": hashlib.sha256(path.read_bytes()).hexdigest()}
        print("GRIND_EXPORT", rid, json.dumps(row, sort_keys=True))
        rows.append(row)
    return rows


def main():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    parser = argparse.ArgumentParser()
    parser.add_argument("--out-dir", default=str(MODELS))
    parser.add_argument("--only", default="")
    parser.add_argument("--count-only", action="store_true", help="build into a scratch directory and print counts; ship nothing")
    args = parser.parse_args(argv)
    out_dir = args.out_dir
    if args.count_only:
        out_dir = tempfile.mkdtemp(prefix="grind_count_")
    for rid in IDS:
        if args.only and rid != args.only:
            continue
        build(rid, out_dir)


if __name__ == "__main__":
    main()
