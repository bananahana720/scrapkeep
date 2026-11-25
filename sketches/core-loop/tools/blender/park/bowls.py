"""Headless recipes for the bowls and terraces family (design-v3/PARK.md section 4, unit KC3): bench_coping, tailings_lip
pit_haul_ramp and pit_haul_lane, each with two detail shells.

  bench_coping   an open-pit copper mine bench pair: two blasted benches stepping down 4 m each, a rounded coping lip of
                 1.5 m radius on every crest, windrow berms on both edges, a ragged blast-line crest in plan.
  tailings_lip   a tailings dam stepped in three lifts (3, 3 and 2.5 m), soft 1.5 m coping on each crest, long concave
                 toes, a crest that bows in plan so the lip cups a ball toward the centre line.
  pit_haul_ramp  a haul road tile on a 10 percent grade: crowned running surface, windrow berm on the outer edge, ditch
                 and cut bank on the inner edge, and two trolley poles 35 m apart on the berm (harpoon anchors).
  pit_haul_lane  the haul road tile LEVEL: pit_haul_ramp's cross-section (haul_cross) on a flat 40 m run from the lip, so
                 the entry and exit -col cross-sections match (park_recipes.gd tile_ends tileable) and the exit is at y 0;
                 trolley poles at z 2 and 22, 20 m apart within a tile and across copies.

The bowl floor itself is the terrain height stamp (park_bake); these recipes sit on it. Each recipe is one GLB:
  <id>.glb          the drawn mesh (one "stone" surface; the haul ramp's poles are steel and copper by vertex colour) and the
                    "<id>-col" mesh that park_recipes.gd turns into a ConcavePolygonShape3D (never drawn); the GLB node is
                    named "<id>-col-col" because the importer strips one -col hint (see build_recipe)
  <id>_detail1.glb  detail shell 1 (mid range), one "stone" surface, class `detail`
  <id>_detail2.glb  detail shell 2 (close range), one "stone" surface, class `detail`
The -col mesh counts toward triangles and vertices but not draws (asset_registry_test and asset-inspect collision_nodes,
KC-INT), so each base is 1 draw inside the landform class with no registry exception.

Convention, the same for the whole family: metres, +Y up, the ride direction and the fall line are +Z, the origin is the
centre of the ENTRY LIP on the ground: the level approach runs from z -4 to z 0 at y 0, the first coping fillet starts at
z 0, and the footprint is centred on x 0. A park row places the node with position, size and yaw only (no scale). The
-col mesh is the drawn skin without its skirts, so the ball meets exactly what is drawn. Shell features stand at most
SHELL_PROUD above the ride surface inside the ride corridor |x| <= corridor; boulders and poles stand outside it.

Palette: stone vertex colour is a multiplier on the sandstone bed shader (assets/materials/dig_stone/stone.tres):
iron-oxide faces, bone worn coping, copper-green bloom on tailings, varnish on the berms. Machinery is steel with
copper (#b77843) arms, never brass. No texture, no light, no mesh from any other source.

  prlimit (12 GiB address-space cap) blender --background --threads 2 --python-exit-code 1 \\
      --python sketches/core-loop/tools/blender/park/bowls.py -- [--out-dir DIR] [--recipe ID] [--count-only]
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

MODELS = Path(common.MODELS) / "park"
LANDFORM = {"tris": 8000, "verts": 24000, "draws": 1}
DETAIL = {"tris": 1500, "verts": 3000, "draws": 1}
SHELL_PROUD = 0.07
APPROACH = 4.0
SLOPE_STEP = 7.0
COPING_R = 1.5


def arc_steps(angle):
    return max(2, math.ceil(angle / SLOPE_STEP))


def build_profile(segs):
    """The centre-line profile as [(z, y)] from z -APPROACH. Segments: ("flat", length); ("down", angle, drop, rc, rv)
    a convex fillet of radius rc into a straight face at `angle` degrees and a concave fillet of radius rv back to
    level, `drop` metres in all; ("ramp", angle, straight_length, rc, rv) the same with the straight length given."""
    pts = [(-APPROACH, 0.0)]
    for seg in segs:
        z, y = pts[-1]
        if seg[0] == "flat":
            pts.append((z + seg[1], y))
            continue
        kind, angle, amount, rc, rv = seg
        a = math.radians(angle)
        if kind == "down":
            straight = (amount - (rc + rv) * (1 - math.cos(a))) / math.sin(a)
        else:
            straight = amount
        assert straight >= 0.0, ("drop too small for the fillets", seg)
        n = arc_steps(angle)
        for k in range(1, n + 1):
            t = a * k / n
            pts.append((z + rc * math.sin(t), y - rc * (1 - math.cos(t))))
        z, y = pts[-1]
        pts.append((z + straight * math.cos(a), y - straight * math.sin(a)))
        z, y = pts[-1]
        cz, cy = z + rv * math.sin(a), y + rv * math.cos(a)
        for k in range(1, n + 1):
            t = a * (1 - k / n)
            pts.append((cz - rv * math.sin(t), cy - rv * math.cos(t)))
    return pts


def lerp_profile(pts, z):
    if z <= pts[0][0]:
        return pts[0][1]
    for (z0, y0), (z1, y1) in zip(pts, pts[1:]):
        if z <= z1:
            return y0 if z1 == z0 else y0 + (y1 - y0) * (z - z0) / (z1 - z0)
    return pts[-1][1]


def smooth(t):
    t = min(1.0, max(0.0, t))
    return t * t * (3 - 2 * t)


def bench_warp(x):
    return (0.8 * math.sin(0.5 * x) + 0.35 * math.sin(1.7 * x + 0.8)) - 0.35 * math.sin(0.8)


def tailings_warp(x):
    return x * x / 160.0


def windrow(u, a, c, h, outer=0.2):
    """A berm cross-section: level to a, rising to h at c, falling to outer * h at the edge. u is |x|."""
    if u <= a:
        return 0.0
    if u <= c:
        return h * smooth((u - a) / (c - a))
    return h * (1 - (1 - outer) * smooth((u - c) / max(1e-6, (c + 2.5) - c)))


def bench_berm(x):
    return windrow(abs(x), 7.5, 10.5, 1.4)


def tailings_berm(x):
    return windrow(abs(x), 9.0, 12.0, 1.0)


def haul_cross(x):
    """Haul section: windrow berm on the outer (-x) edge; crowned road, ditch and cut bank on the inner (+x) edge."""
    crown = -0.12 * min(1.0, (x / 11.0) ** 2)
    if x < 0:
        return crown + windrow(-x, 11.0, 13.2, 1.4)
    if x <= 10.0:
        return crown
    if x <= 11.2:
        return crown - 0.3 * smooth((x - 10.0) / 1.2)
    return -0.42 + 3.8 * smooth((x - 11.2) / 3.8) if x <= 15.0 else 3.38


RECIPES = {
    "bench_coping": {
        "segs": [("flat", 4.0), ("down", 38, 4.0, COPING_R, 10.0), ("flat", 5.0), ("down", 38, 4.0, COPING_R, 10.0), ("flat", 6.0)],
        "half": 12.0, "cross": bench_berm, "warp": bench_warp, "corridor": 7.0, "lip": True, "draws": 2,
        "xs": [-12, -11.25, -10.5, -9.75, -9.0, -8.25, -7.5, -5.0, -2.5, 0, 2.5, 5.0, 7.5, 8.25, 9.0, 9.75, 10.5, 11.25, 12],
        "size": [34.0, 8.0, 24.0],
    },
    "tailings_lip": {
        "segs": [("flat", 4.0), ("down", 30, 3.0, COPING_R, 12.0), ("flat", 4.0), ("down", 30, 3.0, COPING_R, 12.0),
                 ("flat", 4.0), ("down", 30, 2.5, COPING_R, 14.0), ("flat", 6.0)],
        "half": 14.0, "cross": tailings_berm, "warp": tailings_warp, "corridor": 8.5, "lip": True, "draws": 2,
        "xs": [-14, -13, -12, -11, -10, -9, -8, -6, -4, -2, 0, 2, 4, 6, 8, 9, 10, 11, 12, 13, 14],
        "size": [40.0, 9.0, 28.0],
    },
    "pit_haul_ramp": {
        "segs": [("flat", 4.0), ("ramp", math.degrees(math.atan(0.10)), 44.0, 30.0, 30.0), ("flat", 5.0)],
        "half": 15.0, "cross": haul_cross, "warp": None, "corridor": 10.0, "lip": False, "draws": 2,
        "xs": [-15, -14.2, -13.2, -12.2, -11, -8.8, -6.6, -4.4, -2.2, 0, 2.2, 4.4, 6.6, 8.8, 10.0, 11.2, 12.3, 13.4, 14.4, 15],
        "size": [56.0, 5.0, 30.0],
    },
    "pit_haul_lane": {
        "segs": [("flat", 4.0), ("flat", 40.0)],
        "half": 15.0, "cross": haul_cross, "warp": None, "corridor": 10.0, "lip": False, "draws": 2, "level": True,
        "xs": [-15, -14.2, -13.2, -12.2, -11, -8.8, -6.6, -4.4, -2.2, 0, 2.2, 4.4, 6.6, 8.8, 10.0, 11.2, 12.3, 13.4, 14.4, 15],
        "size": [40.0, 4.0, 30.0],
    },
}
POLES = [(-14.6, 12.0), (-14.6, 47.0)]
RECIPE_POLES = {"pit_haul_ramp": POLES, "pit_haul_lane": [(-14.6, 2.0), (-14.6, 22.0)]}


class Skin:
    """The analytic ride surface of a recipe: y(x, z) and the grid the drawn skin and the -col mesh share."""

    def __init__(self, spec):
        self.spec = spec
        self.profile = build_profile(spec["segs"])
        self.xs = [float(x) for x in spec["xs"]]
        self.cross = spec["cross"]
        self.warp_fn = spec["warp"]
        self.z_first = self.profile[0][0]
        self.z_flat_end = self.z_first + APPROACH

    def warp(self, x, z):
        if self.warp_fn is None:
            return 0.0
        return self.warp_fn(x) * smooth((z - self.z_first) / APPROACH)

    def y(self, x, z):
        zp = z
        for _ in range(6):
            zp = z - self.warp(x, zp)
        return lerp_profile(self.profile, zp) + self.cross(x)

    def grid(self):
        return [[(x, lerp_profile(self.profile, zi) + self.cross(x), zi + self.warp(x, zi)) for x in self.xs] for zi, _ in self.profile]

    def slope_x(self):
        return self.xs

    def y_end(self):
        return self.profile[-1][1]


def sub(a, b):
    return (a[0] - b[0], a[1] - b[1], a[2] - b[2])


def cross(a, b):
    return (a[1] * b[2] - a[2] * b[1], a[2] * b[0] - a[0] * b[2], a[0] * b[1] - a[1] * b[0])


def dot(a, b):
    return a[0] * b[0] + a[1] * b[1] + a[2] * b[2]


class Mesh:
    """Vertices, triangles (right-hand normal outward) and per-vertex colour, in Godot metres."""

    def __init__(self):
        self.v, self.t, self.c = [], [], []

    def vert(self, p, color):
        self.v.append(tuple(p))
        self.c.append(color)
        return len(self.v) - 1

    def tri(self, a, b, c, toward=None):
        """A triangle by vertex index; flipped when its normal faces away from `toward` (a direction)."""
        n = cross(sub(self.v[b], self.v[a]), sub(self.v[c], self.v[a]))
        if toward is not None and dot(n, toward) < 0:
            b, c = c, b
        self.t.append((a, b, c))

    def quad(self, a, b, c, d, toward):
        self.tri(a, b, c, toward)
        self.tri(a, c, d, toward)

    def solid_lump(self, centre, radius, height, yaw, color, ground, sides=5):
        """A low faceted lump (a pyramid frustum) standing on `centre` (x, y, z), base open: sides*3 triangles."""
        base = []
        top = []
        for k in range(sides):
            t = yaw + math.tau * k / sides
            r = radius * (0.85 + 0.3 * ((k * 7 + int(abs(yaw) * 10)) % 5) / 4)
            bx, bz = centre[0] + r * math.cos(t), centre[2] + r * math.sin(t)
            base.append(self.vert((bx, ground(bx, bz) - 0.12, bz), color))
            top.append(self.vert((centre[0] + 0.45 * r * math.cos(t + 0.3), centre[1] + height, centre[2] + 0.45 * r * math.sin(t + 0.3)), color))
        cap = self.vert((centre[0], centre[1] + height * 1.05, centre[2]), color)
        for k in range(sides):
            n = (k + 1) % sides
            mid = ((self.v[base[k]][0] + self.v[top[n]][0]) / 2 - centre[0], 0.3, (self.v[base[k]][2] + self.v[top[n]][2]) / 2 - centre[2])
            self.quad(base[k], base[n], top[n], top[k], mid)
            self.tri(top[k], top[n], cap, (0, 1, 0))


def lin(r, g, b):
    return (r, g, b, 1.0)


def rgba_name(name):
    return common.rgba(name)


OXIDE = lin(0.95, 0.60, 0.48)
SAND = lin(1.0, 0.95, 0.84)
BONE = lin(1.0, 0.97, 0.90)
VARNISH = lin(0.62, 0.52, 0.44)
BLOOM = lin(0.62, 0.90, 0.72)
FINES = lin(1.0, 0.99, 0.92)
FINES_RUST = lin(1.0, 0.74, 0.60)
ROAD = lin(0.60, 0.56, 0.50)
RUT = lin(0.40, 0.37, 0.34)
CUT = lin(0.98, 0.76, 0.66)
STEEL_DARK = lin(0.12, 0.13, 0.13)
COPPER = common.rgba("copper")


def skin_color(name, skin, x, y, z, nrm_y):
    """The vertex tint of the drawn skin at a point, by recipe, from the shape of the ground there."""
    u = abs(x)
    if name == "bench_coping":
        if nrm_y < 0.93:
            return OXIDE if int((y + 40) * 1.7) % 3 else lin(0.78, 0.44, 0.35)
        if u > 8.0 and skin.cross(x) > 0.3:
            return VARNISH
        return BONE if nrm_y > 0.985 and skin.cross(x) == 0.0 and y > -0.5 else SAND
    if name == "tailings_lip":
        if nrm_y < 0.93:
            return BLOOM if int((y + 40) * 1.3) % 4 == 0 else FINES_RUST
        return VARNISH if u > 10.0 else FINES
    if x > 11.2:
        return CUT
    if x < -11.0:
        return VARNISH
    return ROAD


def skin_normal_y(skin, x, z):
    e = 0.2
    dydx = (skin.y(x + e, z) - skin.y(x - e, z)) / (2 * e)
    dydz = (skin.y(x, z + e) - skin.y(x, z - e)) / (2 * e)
    return 1.0 / math.sqrt(1 + dydx * dydx + dydz * dydz)


def build_base(name, skin):
    """(drawn Mesh, col Mesh); the haul ramp's poles are built into the drawn mesh (steel and copper by vertex colour)."""
    grid = skin.grid()
    rows, cols = len(grid), len(grid[0])
    up = (0, 1, 0)
    drawn, col = Mesh(), Mesh()
    for mesh, tinted in ((drawn, True), (col, False)):
        index = [[mesh.vert(p, skin_color(name, skin, p[0], p[1], p[2], skin_normal_y(skin, p[0], p[2])) if tinted else None) for p in row]
                 for row in grid]
        for i in range(rows - 1):
            for j in range(cols - 1):
                mesh.quad(index[i][j], index[i + 1][j], index[i + 1][j + 1], index[i][j + 1], up)
    floor = min(p[1] for row in grid for p in row) - 1.5
    edges = [([grid[i][0] for i in range(rows)], (-1, 0, 0)), ([grid[i][-1] for i in range(rows)], (1, 0, 0)),
             (list(grid[-1]), (0, 0, 1))]
    for pts, out in edges:
        top = [drawn.vert(p, skin_color(name, skin, p[0], p[1], p[2], 0.5)) for p in pts]
        low = [drawn.vert((p[0], floor if out[2] == 0 else floor, p[2]), VARNISH) for p in pts]
        for k in range(len(pts) - 1):
            drawn.quad(top[k], top[k + 1], low[k + 1], low[k], out)
    if name in RECIPE_POLES:
        for px, pz in RECIPE_POLES[name]:
            build_pole(drawn, col, skin, px, pz)
    return drawn, col


def build_pole(poles, col, skin, px, pz):
    """A trolley pole: an 8-sided tapered steel tube 10 m tall with a copper cross-arm over the road."""
    base_y = skin.y(px, pz) - 0.3
    sides, height, r0, r1 = 8, 10.0, 0.34, 0.22
    for mesh, tint in ((poles, STEEL_DARK), (col, None)):
        ring0 = [mesh.vert((px + r0 * math.cos(math.tau * k / sides), base_y, pz + r0 * math.sin(math.tau * k / sides)), tint) for k in range(sides)]
        ring1 = [mesh.vert((px + r1 * math.cos(math.tau * k / sides), base_y + height, pz + r1 * math.sin(math.tau * k / sides)), tint) for k in range(sides)]
        for k in range(sides):
            n = (k + 1) % sides
            ang = math.tau * (k + 0.5) / sides
            mesh.quad(ring0[k], ring0[n], ring1[n], ring1[k], (math.cos(ang), 0, math.sin(ang)))
        mesh.tri(ring1[0], ring1[2], ring1[1], (0, 1, 0))
        for k in range(1, sides - 1):
            mesh.tri(ring1[0], ring1[k + 1], ring1[k], (0, 1, 0))
        if mesh is poles:
            arm_y = base_y + height - 0.5
            for (x0, x1, y0, y1, z0, z1, color) in ((px, px + 6.0, arm_y, arm_y + 0.22, pz - 0.11, pz + 0.11, COPPER),
                                                    (px + 5.7, px + 5.9, arm_y - 0.8, arm_y, pz - 0.06, pz + 0.06, COPPER)):
                box(mesh, x0, x1, y0, y1, z0, z1, color)


def box(mesh, x0, x1, y0, y1, z0, z1, color):
    corners = [mesh.vert((x, y, z), color) for x in (x0, x1) for y in (y0, y1) for z in (z0, z1)]
    for axis_pair, out in (((0, 1, 3, 2), (-1, 0, 0)), ((4, 6, 7, 5), (1, 0, 0)), ((0, 4, 5, 1), (0, -1, 0)),
                           ((2, 3, 7, 6), (0, 1, 0)), ((0, 2, 6, 4), (0, 0, -1)), ((1, 5, 7, 3), (0, 0, 1))):
        a, b, c, d = (corners[k] for k in axis_pair)
        mesh.quad(a, b, c, d, out)


def h01(i, seed):
    v = math.sin(i * 12.9898 + seed * 78.233) * 43758.5453
    return v - math.floor(v)


def ridge_across(mesh, skin, zp, width, height, x0, x1, step, color, lift=0.01):
    """A low ridge across the slope at profile station zp, from x0 to x1, following the ground."""
    xs = [x0 + (x1 - x0) * k / max(1, round((x1 - x0) / step)) for k in range(max(1, round((x1 - x0) / step)) + 1)]
    rows = []
    for x in xs:
        z = zp + skin.warp(x, zp)
        a = (x, skin.y(x, z - width / 2) + lift, z - width / 2)
        b = (x, skin.y(x, z) + lift + height, z)
        c = (x, skin.y(x, z + width / 2) + lift, z + width / 2)
        rows.append([mesh.vert(p, color) for p in (a, b, c)])
    for r0, r1 in zip(rows, rows[1:]):
        mesh.quad(r0[0], r0[1], r1[1], r1[0], (0, 1, -0.5))
        mesh.quad(r0[1], r0[2], r1[2], r1[1], (0, 1, 0.5))


def rill_down(mesh, skin, x, z0, z1, width, height, color, lift=0.01):
    """A low ridge running down the fall line at column x from z0 to z1."""
    n = max(2, round((z1 - z0) / 0.9))
    rows = []
    for k in range(n + 1):
        z = z0 + (z1 - z0) * k / n
        rows.append([mesh.vert(p, color) for p in (
            (x - width / 2, skin.y(x - width / 2, z) + lift, z), (x, skin.y(x, z) + lift + height, z), (x + width / 2, skin.y(x + width / 2, z) + lift, z))])
    for r0, r1 in zip(rows, rows[1:]):
        mesh.quad(r0[0], r0[1], r1[1], r1[0], (-0.5, 1, 0))
        mesh.quad(r0[1], r0[2], r1[2], r1[1], (0.5, 1, 0))


def disc(mesh, skin, x, z, radius, height, color, sides=6, lift=0.012):
    cy = skin.y(x, z) + lift + height
    centre = mesh.vert((x, cy, z), color)
    ring = [mesh.vert((x + radius * math.cos(math.tau * k / sides), skin.y(x + radius * math.cos(math.tau * k / sides), z + radius * math.sin(math.tau * k / sides)) + lift,
                       z + radius * math.sin(math.tau * k / sides)), color) for k in range(sides)]
    for k in range(sides):
        mesh.tri(centre, ring[k], ring[(k + 1) % sides], (0, 1, 0))


def boulder(mesh, skin, x, z, radius, height, yaw, color):
    mesh.solid_lump((x, skin.y(x, z), z), radius, height, yaw, color, skin.y)


def pebble(mesh, skin, x, z, size, color):
    tip = mesh.vert((x, skin.y(x, z) + size * 0.5, z), color)
    ring = []
    for k in range(3):
        px, pz = x + size * math.cos(math.tau * k / 3 + 0.4), z + size * math.sin(math.tau * k / 3 + 0.4)
        ring.append(mesh.vert((px, skin.y(px, pz) + 0.005, pz), color))
    for k in range(3):
        a = math.tau * (k + .5) / 3 + .4
        mesh.tri(tip, ring[k], ring[(k + 1) % 3], (math.cos(a), 0.3, math.sin(a)))


def face_stations(skin):
    """(z0, z1) of each steep run of the centre line: the faces between a coping lip and its toe."""
    out = []
    run = None
    for (z0, y0), (z1, y1) in zip(skin.profile, skin.profile[1:]):
        steep = y1 < y0 and (y0 - y1) / (z1 - z0) > 0.25
        if steep and run is None:
            run = [z0, z1]
        elif steep:
            run[1] = z1
        elif run is not None:
            out.append(tuple(run))
            run = None
    if run is not None:
        out.append(tuple(run))
    return out


def build_detail(name, skin, which):
    m = Mesh()
    corridor = skin.spec["corridor"]
    half = skin.spec["half"]
    seed = {"bench_coping": 3, "tailings_lip": 5, "pit_haul_ramp": 7, "pit_haul_lane": 9}[name] * 10 + which
    run, rocks, grit = (54.0, 52.0, 60.0) if name == "pit_haul_ramp" else (skin.profile[-1][0], skin.profile[-1][0] - 4.0, skin.profile[-1][0] + 3.0)
    if name == "bench_coping":
        if which == 1:
            for (z0, z1) in face_stations(skin):
                for k in range(3):
                    zp = z0 + (z1 - z0) * (k + 0.8) / 3.8
                    ridge_across(m, skin, zp, 0.34, 0.055, -half + 1.0, half - 1.0, 1.0, OXIDE if k % 2 else lin(0.9, 0.68, 0.58))
            for lip_z in (-0.2, 14.2):
                for k in range(-3, 4):
                    x = k * 3.0
                    disc(m, skin, x, lip_z + skin.warp(x, lip_z), 0.42, 0.04, lin(0.55, 0.45, 0.38), 6)
            for k in range(26):
                side = -1 if k % 2 else 1
                x = side * (corridor + 0.8 + 3.5 * h01(k, seed))
                z = [8.0, 13.0, 24.0, 27.0][k % 4] + 2.5 * h01(k + 50, seed) - 1.0
                boulder(m, skin, x, z + skin.warp(x, z), 0.45 + 0.55 * h01(k + 100, seed), 0.5 + 0.7 * h01(k + 150, seed), 6.0 * h01(k + 200, seed), OXIDE)
        else:
            for (z0, z1) in face_stations(skin):
                for k in range(-8, 9):
                    x = k * 1.35
                    rill_down(m, skin, x, z0 - 0.5 + skin.warp(x, z0) * 0, z1 + 0.5, 0.18, 0.035, lin(0.50, 0.40, 0.34))
            for k in range(70):
                x = (h01(k, seed) - 0.5) * 2 * (half - 1.0)
                z = -3.5 + 32.0 * h01(k + 300, seed)
                pebble(m, skin, x, z + skin.warp(x, z), 0.06 + 0.07 * h01(k + 400, seed), SAND)
    elif name == "tailings_lip":
        if which == 1:
            for (z0, z1) in face_stations(skin):
                for k in range(-8, 9):
                    x = k * 1.6 + 0.4 * h01(k + int(z0), seed)
                    rill_down(m, skin, x, z0 + 0.3, z1 - 0.3, 0.30, 0.05, FINES_RUST)
            for k in range(22):
                x = (h01(k, seed) - 0.5) * 2 * (half - 2.0)
                z = [1.0, 11.0, 21.0, 31.0][k % 4] + 5.0 * h01(k + 60, seed)
                disc(m, skin, x, z + skin.warp(x, z), 0.8 + 0.5 * h01(k + 90, seed), 0.03, BLOOM, 6)
            for k in range(10):
                side = -1 if k % 2 else 1
                x = side * (corridor + 0.8 + 3.0 * h01(k + 130, seed))
                z = 6.0 + 34.0 * h01(k + 170, seed)
                boulder(m, skin, x, z + skin.warp(x, z), 0.7 + 0.7 * h01(k + 210, seed), 0.35 + 0.4 * h01(k + 250, seed), 6.0 * h01(k + 290, seed), FINES)
        else:
            for zp in [-3.0 + 2.0 * k for k in range(22)]:
                ridge_across(m, skin, zp, 0.28, 0.03, -corridor, corridor, 2.0, FINES)
            for k in range(24):
                x = (h01(k, seed) - 0.5) * 2 * (half - 2.0)
                z = -2.0 + 42.0 * h01(k + 80, seed)
                disc(m, skin, x, z + skin.warp(x, z), 0.35 + 0.25 * h01(k + 120, seed), 0.02, BLOOM, 5)
            for k in range(40):
                x = (h01(k + 500, seed) - 0.5) * 2 * (half - 1.0)
                z = -3.0 + 44.0 * h01(k + 600, seed)
                pebble(m, skin, x, z + skin.warp(x, z), 0.06 + 0.07 * h01(k + 700, seed), SAND)
    else:
        if which == 1:
            for rx in (-4.0, 4.0):
                rill_down(m, skin, rx, 0.0, run, 0.9, 0.0, RUT, lift=0.03)
            for k in range(18):
                x = -(11.6 + 1.5 * h01(k, seed))
                z = 2.0 + rocks * h01(k + 40, seed)
                boulder(m, skin, x, z, 0.7 + 0.8 * h01(k + 80, seed), 0.6 + 0.8 * h01(k + 120, seed), 6.0 * h01(k + 160, seed), VARNISH)
            for k in range(12):
                x = 12.6 + 1.2 * h01(k + 200, seed)
                z = 2.0 + rocks * h01(k + 240, seed)
                boulder(m, skin, x, z, 0.6 + 0.7 * h01(k + 280, seed), 0.5 + 0.7 * h01(k + 320, seed), 6.0 * h01(k + 360, seed), CUT)
            for k in range(int((run - 4.0) / 7.0) + 1):
                z = 4.0 + 7.0 * k
                stake(m, skin, -11.8, z)
        else:
            for k in range(110):
                x = (h01(k, seed) - 0.5) * 2 * 10.0
                z = -3.5 + grit * h01(k + 400, seed)
                pebble(m, skin, x, z, 0.06 + 0.07 * h01(k + 800, seed), SAND)
            for zp in [4.0 + 5.0 * k for k in range(min(10, int((run - 4.0) / 5.0) + 1))]:
                ridge_across(m, skin, zp, 0.5, 0.025, -9.0, 9.0, 1.5, RUT)
    return m


def stake(mesh, skin, x, z):
    y = skin.y(x, z)
    box(mesh, x - 0.05, x + 0.05, y, y + 0.9, z - 0.05, z + 0.05, lin(0.9, 0.55, 0.3))


def circumradius(a, b, c):
    area2 = abs((b[0] - a[0]) * (c[1] - a[1]) - (b[1] - a[1]) * (c[0] - a[0]))
    if area2 < 1e-9:
        return math.inf
    return math.dist(a, b) * math.dist(b, c) * math.dist(a, c) / (2 * area2)


def check_surface(name, skin):
    """Fail loud on the family convention: origin on the lip, centred, falling toward +Z, a 1.5 m coping fillet."""
    spec = skin.spec
    assert abs(skin.y(0.0, -2.0)) < 1e-6, (name, "the approach must sit on the ground at the lip", skin.y(0.0, -2.0))
    assert abs(skin.xs[0] + skin.xs[-1]) < 1e-9 and abs(skin.xs[-1] - spec["half"]) < 1e-9, (name, "centred across x")
    drop = skin.y(0.0, -2.0) - skin.y(0.0, skin.profile[-1][0] - 1.0)
    if spec.get("level"):
        assert abs(drop) < 1e-6 and abs(skin.y_end()) < 1e-9, (name, "a level tile ends at y 0", drop)
    else:
        assert drop >= (7.5 if name == "bench_coping" else 8.0 if name == "tailings_lip" else 4.0), (name, "drop", drop)
    steepest = 0.0
    prev = skin.y(0.0, -3.5)
    z = -3.5
    while z <= skin.profile[-1][0] - 1.0:
        yy = skin.y(0.0, z)
        steepest = max(steepest, abs(yy - prev) / 0.25)
        prev = yy
        z += 0.25
    assert steepest <= 1.0, (name, "slope over 45 degrees", steepest)
    best = math.inf
    if spec["lip"]:
        zc = -1.0
        while zc <= 4.0:
            p = [(zc + d, skin.y(0.0, zc + d)) for d in (-0.5, 0.0, 0.5)]
            turn = (p[1][0] - p[0][0]) * (p[2][1] - p[1][1]) - (p[1][1] - p[0][1]) * (p[2][0] - p[1][0])
            if turn < -1e-4:
                best = min(best, circumradius(*p))
            zc += 0.25
        assert COPING_R * 0.8 <= best <= COPING_R * 1.2, (name, "coping lip radius", best)
    return {"drop": round(drop, 3), "steepest": round(steepest, 3), "coping_radius": None if best == math.inf else round(best, 3)}


def check_shell(name, skin, mesh, which):
    corridor = skin.spec["corridor"]
    worst = -1e9
    for x, y, z in mesh.v:
        over = y - skin.y(x, z)
        if abs(x) <= corridor:
            worst = max(worst, over)
            assert over <= SHELL_PROUD + 1e-6, (name, which, "a shell feature stands proud in the ride corridor", (x, y, z), over)
        assert over >= -1.0, (name, which, "a shell vertex floats below the ground", (x, y, z), over)
    return round(worst, 4)


def material(slot):
    mat = bpy.data.materials.get(slot)
    if mat is not None:
        return mat
    mat = bpy.data.materials.new(slot)
    mat.use_nodes = True
    nodes = mat.node_tree.nodes
    bsdf = nodes.get("Principled BSDF")
    bsdf.inputs["Roughness"].default_value = 0.95 if slot == "stone" else 0.82
    bsdf.inputs["Metallic"].default_value = 0.22 if slot == "steel" else 0.0
    attr = nodes.new("ShaderNodeVertexColor")
    attr.layer_name = "Color"
    mat.node_tree.links.new(attr.outputs["Color"], bsdf.inputs["Base Color"])
    return mat


def to_blender(p):
    return (p[0], -p[2], p[1])


def make_object(name, mesh, slot, root, smooth_shading=True):
    data = bpy.data.meshes.new(name)
    data.from_pydata([to_blender(p) for p in mesh.v], [], mesh.t)
    data.update()
    if slot is not None:
        attr = data.color_attributes.new(name="Color", type="FLOAT_COLOR", domain="CORNER")
        for poly in data.polygons:
            for li in poly.loop_indices:
                attr.data[li].color = mesh.c[data.loops[li].vertex_index]
        data.color_attributes.active_color = attr
        data.materials.append(material(slot))
    for poly in data.polygons:
        poly.use_smooth = smooth_shading
    obj = bpy.data.objects.new(name, data)
    bpy.context.scene.collection.objects.link(obj)
    obj.parent = root
    return obj


def gltf_metrics(path):
    data = path.read_bytes()
    length = struct.unpack_from("<I", data, 12)[0]
    doc = json.loads(data[20:20 + length])
    tris = verts = draws = 0
    lo, hi = [math.inf] * 3, [-math.inf] * 3
    for mesh in doc["meshes"]:
        for prim in mesh["primitives"]:
            pos = doc["accessors"][prim["attributes"]["POSITION"]]
            verts += pos["count"]
            tris += doc["accessors"][prim["indices"]]["count"] // 3
            draws += 1
            for k in range(3):
                lo[k], hi[k] = min(lo[k], pos["min"][k]), max(hi[k], pos["max"][k])
    return {"tris": tris, "verts": verts, "draws": draws, "materials": sorted(m["name"] for m in doc.get("materials", [])),
            "nodes": sorted(n["name"] for n in doc["nodes"]), "bounds": {"min": [round(v, 3) for v in lo], "max": [round(v, 3) for v in hi]}}


def export(glb_name, parts, out_dir, caps, count_only):
    """parts: [(object name, Mesh, slot or None, smooth)]; returns the metrics row."""
    common.reset()
    root = common.empty(glb_name)
    for pname, mesh, slot, smooth_shading in parts:
        make_object(pname, mesh, slot, root, smooth_shading)
    expected_tris = sum(len(mesh.t) for _, mesh, _, _ in parts)
    assert expected_tris <= caps["tris"], (glb_name, "triangles", expected_tris, caps)
    assert len(parts) <= caps["draws"], (glb_name, "draws", len(parts), caps)
    if count_only:
        print("BOWLS_COUNT", glb_name, json.dumps({"tris": expected_tris, "draws": len(parts)}, sort_keys=True))
        return {"file": glb_name + ".glb", "tris": expected_tris, "draws": len(parts)}
    path = Path(out_dir) / (glb_name + ".glb")
    common.export(root, str(path))
    metrics = gltf_metrics(path)
    assert metrics["tris"] <= caps["tris"] and metrics["verts"] <= caps["verts"] and metrics["draws"] <= caps["draws"], (glb_name, metrics, caps)
    row = {**metrics, "file": path.name, "sha256": hashlib.sha256(path.read_bytes()).hexdigest()}
    print("BOWLS_EXPORT", glb_name, json.dumps(row, sort_keys=True))
    return row


def build_recipe(name, out_dir, count_only):
    spec = RECIPES[name]
    skin = Skin(spec)
    surface = check_surface(name, skin)
    drawn, col = build_base(name, skin)
    parts = [(name + "_ground", drawn, "stone", True)]
    parts.append((name + "-col-col", col, None, False))
    caps = {**LANDFORM, "draws": spec["draws"]}
    rows = [export(name, parts, out_dir, caps, count_only)]
    proud = []
    for which in (1, 2):
        shell = build_detail(name, skin, which)
        proud.append(check_shell(name, skin, shell, which))
        rows.append(export("%s_detail%d" % (name, which), [("%s_detail%d_mesh" % (name, which), shell, "stone", True)], out_dir, DETAIL, count_only))
    for r in rows:
        r["surface"] = surface
        r["shell_proud"] = proud
    return rows


def main():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    parser = argparse.ArgumentParser()
    parser.add_argument("--out-dir", default=str(MODELS))
    parser.add_argument("--recipe", action="append", choices=sorted(RECIPES))
    parser.add_argument("--count-only", action="store_true")
    args = parser.parse_args(argv)
    for name in args.recipe or sorted(RECIPES):
        build_recipe(name, args.out_dir, args.count_only)


if __name__ == "__main__":
    main()
