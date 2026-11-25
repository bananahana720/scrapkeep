"""Tunnels and drops: the park_large recipes lava_tube_run, adit_mouth, shaft_drop and spillway_tunnel
(design-v3/PARK.md section 4, wave 13 unit KC4). Each id builds <id>.glb (the drawn mesh <id>, the collision mesh <id>-col
that src/world/park/park_recipes.gd turns into a ConcavePolygonShape3D, and a socket_exit node) plus the two detail shells
<id>_detail1.glb and <id>_detail2.glb that the loader fades by range. lava_tube_run also ships its two 30 degree bends as
lava_tube_run_bend_p30 and lava_tube_run_bend_n30 (p turns toward +X), each with its own shells, so a stage can chain
straight and bent segments: every segment's end ring is the same profile, and socket_exit is where the next one's origin goes.

CONVENTION, the same for the whole family (Godot axes, metres):
  +Y up. The ride runs along +Z, the fall line. The origin is the entry lip: the centre of the floor at the mouth, on the ground.
  The floor descends along the run, so socket_exit sits below the origin; its yaw is the heading the next piece starts with.
  A row places a recipe with position, size and yaw only (park_recipes.place; the loader never scales a GLB). size is
  [length, interior height, interior width]: lava_tube_run [48, 12, 16], adit_mouth [56, 6, 8], shaft_drop [26, 18, 12],
  spillway_tunnel [90, 9, 11]. The ride sensor is built from the row's size, so a row copies these numbers.
  Mouths face along the fall line. Every tube's roof lip bevels back 3 m: the hull is the interior profile pushed out by
  min(thickness, distance from the nearest end), so the face a ball in flight meets slopes at 40 to 50 degrees instead of
  standing as a wall (TRAVERSAL.md:110). The -col mesh holds the clean interior, the bevelled hull and nothing else; ribs,
  timbers, rails and rubble are drawn only. hole is true at the mouths; the stage cuts it, the recipe supplies the surface under it.
  Materials: one vertex-colour material named "enamel" (the runtime slot that turns vertex colour on), no textures. Draws: the drawn mesh plus the -col mesh is 2, the park_large
  ceiling; each shell is 1 draw in the detail class. Arizona palette: basalt and scoria for the lava tube, sandstone and iron oxide
  rock with weathered timber and copper (#b77843, never brass) for the adit and shaft, dam-era concrete grey with form-board joints
  for the spillway. Nothing here names a living people; the ids stay as the PARK.md table gives them.

Run (memory-capped with prlimit, 12 GiB of address space):
  prlimit <address-space cap> -- blender --background --threads 2 --python-exit-code 1 --python \
    sketches/core-loop/tools/blender/park/tunnels.py -- [--out DIR] [--only ID[,ID]] [--count-only]
"""
import argparse
import hashlib
import json
import math
from pathlib import Path
import struct
import sys

import bpy
from mathutils import Euler, Vector

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE.parent))
import common

SKETCH = HERE.parents[2]
MODELS = SKETCH / "assets/models/park"

PARK_LARGE = {"tris": 16000, "draws": 2}
DETAIL = {"tris": 1500, "draws": 1}
BEVEL = 3.0

C = {
    "basalt": common.mix("charcoal", "oxide", .58),
    "basalt_dark": common.mix("charcoal", "oxide", .40),
    "scoria": common.mix("oxide", "charcoal", .45),
    "varnish": common.mix("charcoal", "oxide", .50),
    "dust": common.mix("sandstone", "bone", .30),
    "sand": common.srgb("sandstone"),
    "sandstone_wall": common.mix("sandstone", "oxide", .28),
    "oxide": common.srgb("oxide"),
    "rock_red": common.mix("oxide", "sandstone", .35),
    "timber": common.mix("oxide", "charcoal", .55),
    "timber_pale": common.mix("sandstone", "charcoal", .45),
    "copper": common.srgb("copper"),
    "concrete": common.mix("bone", "charcoal", .42),
    "concrete_dark": common.mix("bone", "charcoal", .58),
    "concrete_light": common.mix("bone", "charcoal", .30),
    "stain": common.mix("oxide", "charcoal", .55),
    "concrete_stain": common.mix("bone", "oxide", .22),
    "cream": common.mix("bone", "sandstone", .35),
    "sage": common.mix("petrol", "bone", .40),
}


def hash01(a, b=0, c=0):
    v = math.sin(a * 12.9898 + b * 78.233 + c * 37.719 + 4.1414) * 43758.5453
    return v - math.floor(v)


def smooth(lo, hi, x):
    t = min(1.0, max(0.0, (x - lo) / (hi - lo)))
    return t * t * (3 - 2 * t)


def tint(color, amount, seed):
    """A small deterministic brightness wobble so flat faces do not read as one flat colour."""
    k = 1.0 + (hash01(seed, 3) - .5) * 2 * amount
    return tuple(min(1.0, max(0.0, c * k)) for c in color)


def strata(tube, s, i, palette, thickness=1.5):
    """Bedding colour for a hull face: bands by world height, so the rock reads as layered stone, not as ribs."""
    x, y, _ = tube.profile[i % len(tube.profile)]
    wy = tube.world(s, 0, y).y
    k = int(math.floor(wy / thickness))
    return tint(palette[k % len(palette)], .06, int(s) * 3 + i)


class Soup:
    """Godot-space polygons with one colour per face, triangulated with a fixed quad split."""

    def __init__(self):
        self.verts, self.faces, self.colors, self.smooth = [], [], [], []

    def add_vert(self, p):
        self.verts.append(tuple(float(v) for v in p))
        return len(self.verts) - 1

    def face(self, idx, color, smooth=False):
        self.faces.append(tuple(idx))
        self.colors.append(color)
        self.smooth.append(smooth)

    def strip(self, rings, color_fn, facing, axis_fn, closed=True, smooth=False):
        """Quads between consecutive rings (lists of Vectors). facing 'in' makes the normals point at axis_fn(r), 'out' away.
        color_fn(r, i) picks the face colour. The whole strip is flipped when its normals sum to the wrong side."""
        base = []
        for ring in rings:
            base.append([self.add_vert(p) for p in ring])
        n = len(rings[0])
        quads, score = [], 0.0
        for r in range(len(rings) - 1):
            for i in range(n if closed else n - 1):
                j = (i + 1) % n
                q = (base[r][i], base[r][j], base[r + 1][j], base[r + 1][i])
                a, b, c, d = (Vector(self.verts[k]) for k in q)
                normal = (b - a).cross(d - a) + (c - b).cross(d - b)
                centre = (a + b + c + d) / 4
                toward = Vector(axis_fn(r)) - centre
                score += normal.dot(toward) if normal.length > 1e-9 else 0.0
                quads.append((q, color_fn(r, i)))
        want = score > 0 if facing == "in" else score < 0
        for q, color in quads:
            self.face(q if want else tuple(reversed(q)), color, smooth)

    def outward(self, idx, inside, color):
        """Add one face wound so its normal points away from the point inside."""
        a, b, c = (Vector(self.verts[k]) for k in idx[:3])
        normal = (b - a).cross(c - a)
        centre = sum((Vector(self.verts[k]) for k in idx), Vector()) / len(idx)
        self.face(idx if normal.dot(centre - Vector(inside)) >= 0 else tuple(reversed(idx)), color)

    def box(self, center, size, color, yaw=0.0, tilt=0.0, roll=0.0):
        hx, hy, hz = (v / 2 for v in size)
        rot = Euler((math.radians(tilt), math.radians(yaw), math.radians(roll)), "YXZ").to_matrix()
        pts = [Vector(center) + rot @ Vector((sx * hx, sy * hy, sz * hz))
               for sx in (-1, 1) for sy in (-1, 1) for sz in (-1, 1)]
        ix = [self.add_vert(p) for p in pts]
        quads = [(0, 1, 3, 2), (4, 6, 7, 5), (0, 4, 5, 1), (2, 3, 7, 6), (0, 2, 6, 4), (1, 5, 7, 3)]
        for q in quads:
            self.outward(tuple(ix[k] for k in q), center, color)

    def cone(self, base, radius, height, sides, color, down=False):
        ring = [Vector(base) + Vector((radius * math.cos(a), 0, radius * math.sin(a)))
                for a in (math.tau * k / sides for k in range(sides))]
        tip = Vector(base) + Vector((0, -height if down else height, 0))
        ri = [self.add_vert(p) for p in ring]
        ti = self.add_vert(tip)
        inside = Vector(base) + Vector((0, -height / 2 if down else height / 2, 0))
        for k in range(sides):
            self.outward((ri[k], ri[(k + 1) % sides], ti), inside, color)

    def tris(self):
        out = []
        for f, color, smooth in zip(self.faces, self.colors, self.smooth):
            for k in range(1, len(f) - 1):
                out.append(((f[0], f[k], f[k + 1]), color, smooth))
        return out


def palette_material():
    """The one vertex-colour material, named for the runtime slot 'enamel' (assets/materials/dig_mechanical/enamel.tres: a
    StandardMaterial3D with vertex_color_use_as_albedo, roughness 0.87). park_recipes.gd swaps any surface named for a slot role
    for that slot's material, and the importer alone would not turn on vertex colour, so the name is what colours the recipe in game."""
    mat = bpy.data.materials.get("enamel")
    if mat is not None:
        return mat
    mat = bpy.data.materials.new("enamel")
    mat.use_nodes = True
    bsdf = mat.node_tree.nodes.get("Principled BSDF")
    bsdf.inputs["Roughness"].default_value = .87
    attr = mat.node_tree.nodes.new("ShaderNodeVertexColor")
    attr.layer_name = "Color"
    mat.node_tree.links.new(attr.outputs["Color"], bsdf.inputs["Base Color"])
    return mat


def bpy_xyz(p):
    return (p[0], -p[2], p[1])


def make_object(name, soup, root, painted):
    tris = soup.tris()
    mesh = bpy.data.meshes.new(name)
    mesh.from_pydata([bpy_xyz(v) for v in soup.verts], [], [t for t, _, _ in tris])
    mesh.update()
    if painted:
        attr = mesh.color_attributes.new(name="Color", type="FLOAT_COLOR", domain="CORNER")
        for poly, (_, color, _) in zip(mesh.polygons, tris):
            for li in poly.loop_indices:
                attr.data[li].color = common.rgba(color)
        mesh.color_attributes.active_color = attr
        mesh.materials.append(palette_material())
    for poly, (_, _, smooth) in zip(mesh.polygons, tris):
        poly.use_smooth = smooth
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.scene.collection.objects.link(obj)
    obj.parent = root
    return obj, len(tris)


class Tube:
    """A profile swept along a straight or 30 degree arc centreline that descends at a constant slope."""

    def __init__(self, rid, profile, length, drop, bend_deg, thickness, centre_y, stations, noise, palette, joints=(), smooth=False):
        self.rid, self.profile, self.L, self.drop = rid, profile, length, drop
        self.bend = math.radians(bend_deg)
        self.thickness, self.cy, self.noise, self.palette = thickness, centre_y, noise, palette
        self.stations = stations
        self.joints = joints
        self.R = length / abs(self.bend) if self.bend else 0.0
        self.rendering = False
        self.smooth = smooth

    def frame(self, s):
        """Floor-centre point and heading yaw (radians) at arc length s."""
        y = -self.drop * s / self.L
        if not self.bend:
            return Vector((0, y, s)), 0.0
        th = abs(self.bend) * s / self.L
        sign = 1.0 if self.bend > 0 else -1.0
        return Vector((sign * self.R * (1 - math.cos(th)), y, self.R * math.sin(th))), sign * th

    def world(self, s, x, y):
        pos, yaw = self.frame(s)
        return pos + Vector((x * math.cos(yaw), y, -x * math.sin(yaw)))

    def end_socket(self):
        pos, yaw = self.frame(self.L)
        return pos, yaw

    def window(self, s):
        return smooth(BEVEL + .5, BEVEL + 5, min(s, self.L - s))

    def inset(self, s):
        if not self.rendering:
            return 0.0
        for j in self.joints:
            if j - .15 <= s <= j + .15:
                return .12
        return 0.0

    def interior_pt(self, s, k):
        x, y, kind = self.profile[k]
        if kind != "floor":
            ax, ay = x, y - self.cy
            d = math.hypot(ax, ay)
            amp = self.noise * (hash01(s * 3.1, k * 1.7, 1.0) - .5) * 2 * self.window(s)
            off = amp - self.inset(s)
            x, y = x - ax / d * off, y - ay / d * off
        return self.world(s, x, y)

    def hull_pt(self, s, k):
        x, y, _ = self.profile[k]
        ax, ay = x, y - self.cy
        d = math.hypot(ax, ay)
        off = min(self.thickness, s, self.L - s)
        off += self.noise * 2.2 * (hash01(s * 1.3, k * 2.9, 2.0) - .5) * 2 * self.window(s) * self.thickness / 3
        return self.world(s, x + ax / d * off, y + ay / d * off)

    def axis(self, s):
        return self.world(s, 0, self.cy)

    def station_list(self, render):
        out = list(self.stations)
        if render:
            for j in self.joints:
                out += [j - .17, j - .15, j + .15, j + .17]
        return sorted(set(out))

    def build(self, render):
        soup = Soup()
        self.rendering = render
        st = self.station_list(render)
        hs = self.station_list(False)
        n = len(self.profile)
        inner = [[self.interior_pt(s, k) for k in range(n)] for s in st]
        outer = [[self.hull_pt(s, k) for k in range(n)] for s in hs]
        in_axes = [self.axis(s) for s in st]
        out_axes = [self.axis(s) for s in hs]
        if render:
            soup.strip(inner, lambda r, i: self.palette("in", st[r], i, self), "in", lambda r: in_axes[r], smooth=self.smooth)
            soup.strip(outer, lambda r, i: self.palette("out", hs[r], i, self), "out", lambda r: out_axes[r], smooth=self.smooth)
        else:
            soup.strip(inner, lambda r, i: C["sand"], "in", lambda r: in_axes[r])
            soup.strip(outer, lambda r, i: C["sand"], "out", lambda r: out_axes[r])
        return soup


def ellipse(cx, cy, a, b, t0, t1, n):
    return [(cx + a * math.cos(t0 + (t1 - t0) * k / (n - 1)), cy + b * math.sin(t0 + (t1 - t0) * k / (n - 1))) for k in range(n)]


def lava_profile():
    pts = [(x, .7 * (x / 7.0) ** 2, "floor") for x in range(-7, 8)]
    pts.append((7.6, 1.8, "wall"))
    pts += [(x, y, "roof") for x, y in ellipse(0, 3.6, 8.0, 7.4, 0.0, math.pi, 13)]
    pts.append((-7.6, 1.8, "wall"))
    return pts


def lava_palette(side, s, i, tube):
    kind = tube.profile[i % len(tube.profile)][2]
    seed = s * 7 + i
    if side == "in":
        if kind == "floor":
            return tint(C["dust"], .035, seed)
        if kind == "roof":
            return tint(C["basalt_dark"], .10, seed)
        return tint(C["scoria"] if hash01(i // 2, 5) > .5 else C["basalt"], .08, seed)
    return strata(tube, s, i, [C["varnish"], C["scoria"], C["varnish"], C["rock_red"]])


def adit_profile():
    pts = [(x, .3 * (x / 4.0) ** 2, "floor") for x in (-3.5, -2.5, -1.5, -.5, .5, 1.5, 2.5, 3.5)]
    pts.append((4.0, 1.6, "wall"))
    pts += [(x, y, "roof") for x, y in ellipse(0, 3.6, 4.0, 2.0, 0.0, math.pi, 9)]
    pts.append((-4.0, 1.6, "wall"))
    return pts


def adit_palette(side, s, i, tube):
    kind = tube.profile[i % len(tube.profile)][2]
    seed = s * 5 + i
    if side == "in":
        if kind == "floor":
            return tint(C["dust"], .04, seed)
        if kind == "roof":
            return tint(C["sandstone_wall"], .07, seed)
        return tint(C["rock_red"] if hash01(i // 2, 3) > .5 else C["sandstone_wall"], .07, seed)
    return strata(tube, s, i, [C["sand"], C["rock_red"], C["cream"], C["sandstone_wall"]])


def spillway_profile():
    pts = [(x, .15 * (x / 5.5) ** 2, "floor") for x in range(-5, 6)]
    pts.append((5.5, 1.2, "wall"))
    pts.append((5.5, 2.4, "wall"))
    pts.append((5.5, 3.6, "wall"))
    pts += [(x, y, "roof") for x, y in ellipse(0, 4.5, 5.5, 4.5, 0.0, math.pi, 13)]
    pts.append((-5.5, 3.6, "wall"))
    pts.append((-5.5, 2.4, "wall"))
    pts.append((-5.5, 1.2, "wall"))
    return pts


def spillway_palette(side, s, i, tube):
    x, y, kind = tube.profile[i % len(tube.profile)]
    seed = s * 3 + i
    if side == "in":
        if kind == "floor":
            return tint(C["concrete_dark"], .03, seed)
        band = int(max(0.0, y) / 1.2)
        board = C["concrete_light"] if band % 2 == 0 else C["concrete"]
        if hash01(band, int(s / 3), 5) > .965:
            board = C["concrete_stain"]
        return tint(board, .035, int(s / 6) * 5 + band)
    return tint(C["concrete"] if int(s / 6) % 2 == 0 else C["concrete_light"], .04, int(s / 6) * 3 + i)


def tube_for(rid):
    if rid.startswith("lava_tube_run"):
        bend = 30 if rid.endswith("p30") else -30 if rid.endswith("n30") else 0
        stations = [0, 3, 7, 11, 15, 19, 23, 27, 31, 35, 39, 43, 45, 48]
        return Tube(rid, lava_profile(), 48.0, 48.0 * math.tan(math.radians(6)), bend, 3.0, 3.6, stations, .35, lava_palette, smooth=True)
    if rid == "adit_mouth":
        stations = [0, 3, 8, 14, 20, 26, 32, 38, 44, 50, 53, 56]
        return Tube(rid, adit_profile(), 56.0, 56.0 * math.tan(math.radians(4)), 0, 2.5, 3.6, stations, .12, adit_palette)
    if rid == "spillway_tunnel":
        stations = [0, 3] + list(range(6, 85, 6)) + [87, 90]
        joints = [20, 40, 60, 80]
        return Tube(rid, spillway_profile(), 90.0, 35.5, 0, 2.0, 4.5, stations, 0.0, spillway_palette, joints)
    raise KeyError(rid)


def lava_shell1(tube):
    soup = Soup()
    for k in range(12):
        for side in (-1, 1):
            if hash01(k, side, 11) < .25:
                continue
            s = 6 + k * 3.4 + hash01(k, side, 12) * 1.2
            ln = 3.2 + hash01(k, side, 13) * 2.4
            pos = tube.world(s, side * 7.55, 2.1 + hash01(k, side, 14) * .5)
            soup.box(pos, (.9, .45, ln), tint(C["scoria"], .12, k * 2 + side), yaw=math.degrees(tube.frame(s)[1]))
    for k in range(16):
        s = 6 + hash01(k, 1, 21) * 36
        x = (hash01(k, 2, 22) - .5) * 9
        top = 3.6 + 7.4 * math.sqrt(max(0.0, 1 - (x / 8.0) ** 2)) - .15
        pos = tube.world(s, x, top)
        soup.cone(pos, .22 + hash01(k, 3, 23) * .22, 1.1 + hash01(k, 4, 24) * 1.5, 6, tint(C["basalt_dark"], .25, k), down=True)
    for k in range(26):
        s = 5 + hash01(k, 1, 31) * 38
        side = -1 if k % 2 else 1
        x = side * (5.0 + hash01(k, 2, 32) * 1.7)
        sz = .5 + hash01(k, 3, 33) * .9
        pos = tube.world(s, x, .7 * (x / 7) ** 2 + sz * .35)
        soup.box(pos, (sz, sz * .7, sz * 1.1), tint(C["basalt"], .3, k), yaw=hash01(k, 4, 34) * 180, tilt=hash01(k, 5, 35) * 18)
    return soup


def lava_shell2(tube):
    soup = Soup()
    for k in range(64):
        s = 3 + hash01(k, 1, 41) * 42
        side = -1 if k % 2 else 1
        x = side * (3.4 + hash01(k, 2, 42) * 3.3)
        sz = .16 + hash01(k, 3, 43) * .28
        pos = tube.world(s, x, .7 * (x / 7) ** 2 + sz * .3)
        soup.box(pos, (sz, sz * .6, sz), tint(C["scoria"] if k % 3 else C["basalt"], .3, k), yaw=hash01(k, 4, 44) * 180)
    for k in range(18):
        s = 4 + hash01(k, 1, 51) * 40
        x = (hash01(k, 2, 52) - .5) * 11
        top = 3.6 + 7.4 * math.sqrt(max(0.0, 1 - (x / 8.0) ** 2)) - .1
        soup.cone(tube.world(s, x, top), .09 + hash01(k, 3, 53) * .08, .45 + hash01(k, 4, 54) * .6, 5, tint(C["scoria"], .3, k), down=True)
    for k in range(20):
        s = 4 + k * 2.1
        side = -1 if k % 2 else 1
        x = side * (5.3 + hash01(k, 1, 61) * .8)
        soup.box(tube.world(s, x, .7 * (x / 7) ** 2 + .1), (.5, .14, 1.6 + hash01(k, 2, 62)), tint(C["basalt_dark"], .25, k),
                 yaw=math.degrees(tube.frame(s)[1]) + (hash01(k, 3, 63) - .5) * 40)
    return soup


def adit_sets(tube):
    return [3.5 + 6 * k for k in range(9)]


def adit_timbers(tube):
    """Post-and-cap sets every 6 m from a heavy portal frame at 3.5 m; drawn only, so the -col mesh stays clean."""
    soup = Soup()
    for k, s in enumerate(adit_sets(tube)):
        w = .6 if k == 0 else .42
        yaw = math.degrees(tube.frame(s)[1])
        for side in (-1, 1):
            soup.box(tube.world(s, side * 3.72, 1.95), (w, 3.9, w), tint(C["timber"], .2, k * 2 + side), yaw=yaw)
        soup.box(tube.world(s, 0, 4.2), (8.0, w, w), tint(C["timber"], .2, k + 40), yaw=yaw)
    return soup


def adit_shell1(tube):
    soup = Soup()
    for k in range(27):
        s = 2 + k * 2.0
        soup.box(tube.world(s, 0, .12), (3.0, .16, .28), C["timber"], yaw=math.degrees(tube.frame(s)[1]))
    for side in (-1, 1):
        for c in range(7):
            s0 = 1 + c * 8
            soup.box(tube.world(s0 + 4, side * 1.0, .30), (.12, .14, 8.0), C["copper"], yaw=math.degrees(tube.frame(s0 + 4)[1]))
    for k, s in enumerate(range(6, 54, 6)):
        for side in (-1, 1):
            soup.box(tube.world(s + 3, side * 4.08, 2.2), (.14, 3.4, 4.6), tint(C["timber_pale"], .2, k * 2 + side), yaw=math.degrees(tube.frame(s)[1]))
    return soup


def adit_shell2(tube):
    soup = Soup()
    for k, s in enumerate(adit_sets(tube)):
        for side in (-1, 1):
            yaw = math.degrees(tube.frame(s)[1])
            soup.box(tube.world(s, side * 3.55, 2.4), (.12, .34, .34), C["copper"], yaw=yaw)
            soup.box(tube.world(s, side * 3.55, 1.0), (.12, .20, .20), C["copper"], yaw=yaw)
        soup.box(tube.world(s, 0, 4.9), (.12, .22, .12), C["copper"], yaw=math.degrees(tube.frame(s)[1]))
    for k in range(40):
        s = 2 + hash01(k, 1, 71) * 52
        side = -1 if k % 2 else 1
        x = side * (2.6 + hash01(k, 2, 72) * .9)
        sz = .14 + hash01(k, 3, 73) * .2
        soup.box(tube.world(s, x, .3 * (x / 4) ** 2 + sz * .3), (sz, sz * .6, sz), tint(C["oxide"], .3, k), yaw=hash01(k, 4, 74) * 180)
    return soup


def spillway_shell1(tube):
    soup = Soup()
    for j in tube.joints:
        for side in (-1, 1):
            for h in (1.0, 2.2, 3.4):
                soup.box(tube.world(j, side * 5.46, h), (.1, .22, .22), C["concrete_dark"])
    for k in range(18):
        s = 4 + k * 4.8
        side = -1 if k % 2 else 1
        soup.box(tube.world(s, side * 5.49, 2.0 + hash01(k, 1, 81) * 1.2), (.04, 1.8 + hash01(k, 2, 82) * 1.4, .5), tint(C["stain"], .2, k))
    return soup


def spillway_shell2(tube):
    soup = Soup()
    for k in range(34):
        s = 2 + hash01(k, 1, 91) * 86
        side = -1 if k % 2 else 1
        h = .6 + hash01(k, 2, 92) * 3.6
        soup.box(tube.world(s, side * 5.5, h), (.04, .16 + hash01(k, 3, 93) * .3, .2 + hash01(k, 4, 94) * .5),
                 tint(C["stain"] if k % 3 else C["concrete_light"], .15, k))
    for k in range(30):
        s = 3 + hash01(k, 1, 95) * 84
        side = -1 if k % 2 else 1
        x = side * (4.2 + hash01(k, 2, 96) * 1.1)
        sz = .12 + hash01(k, 3, 97) * .18
        soup.box(tube.world(s, x, .15 * (x / 5.5) ** 2 + sz * .3), (sz, sz * .5, sz), tint(C["concrete_dark"], .2, k), yaw=hash01(k, 4, 98) * 180)
    for h in range(8):
        s = 8 + h * 10
        soup.box(tube.world(s, -5.35, 4.1), (.28, .28, 1.4), C["copper"])
    return soup


PIT_W, PIT_L, PIT_DEPTH = 6.0, 20.0, 18.0
PIT_TAN = math.tan(math.radians(12))
DRIFT_L, DRIFT_TAN = 6.0, math.tan(math.radians(4))


def pit_floor_y(z):
    return -PIT_DEPTH - PIT_TAN * z


def shaft_drift():
    """The exit drift, an arch tube leaving the pit's south wall."""
    prof = [(x, .2 * (x / 3.5) ** 2, "floor") for x in (-3, -2, -1, 0, 1, 2, 3)]
    prof.append((3.5, 1.4, "wall"))
    prof += [(x, y, "roof") for x, y in ellipse(0, 2.8, 3.5, 2.6, 0.0, math.pi, 9)]
    prof.append((-3.5, 1.4, "wall"))
    return prof


def shaft_palette(side, s, i, tube):
    kind = tube.profile[i % len(tube.profile)][2]
    seed = s * 5 + i
    if side == "in":
        if kind == "floor":
            return tint(C["dust"], .04, seed)
        return tint(C["timber"] if int(s / 2) % 2 == 0 else C["timber_pale"], .08, seed)
    return strata(tube, s, i, [C["rock_red"], C["sand"], C["sandstone_wall"]])


def build_shaft(render):
    soup = Soup()
    drift = Tube("shaft_drop", shaft_drift(), DRIFT_L, DRIFT_L * DRIFT_TAN, 0, 2.5, 2.8, [0, 2, 4, 6],
                 .08, shaft_palette)
    y0 = pit_floor_y(PIT_L)
    d = drift.build(render)
    d.verts = [tuple(Vector(v) + Vector((0, y0, PIT_L))) for v in d.verts]
    rows = [0, 4, 8, 12, 16, 20]
    cols = [-PIT_W, -PIT_W / 3, PIT_W / 3, PIT_W]
    ts = (0, .25, .5, .75, 1.0)
    floor = [[Vector((x, pit_floor_y(z), z)) for x in cols] for z in rows]
    soup.strip(floor, lambda r, i: tint(C["dust"], .04, r * 4 + i), "in", lambda r: Vector((0, pit_floor_y(rows[r]) + 5, rows[r])), closed=False)
    for side in (-1, 1):
        wall = [[Vector((side * PIT_W, pit_floor_y(z) * t, z)) for t in ts] for z in rows]
        soup.strip(wall, lambda r, i, side=side: shaft_wall_color(i, r, side), "in", lambda r: Vector((0, -6, rows[r])), closed=False)
    north = [[Vector((x, pit_floor_y(0) * t, 0)) for t in ts] for x in cols]
    soup.strip(north, lambda r, i: shaft_wall_color(i, r, 0), "in", lambda r: Vector((cols[r], -6, 4)), closed=False)
    inner = [(-3.0, drift_floor(-3.0)), (-3.5, 1.4)] + ellipse(0, 2.8, 3.5, 2.6, math.pi, 0.0, 9) + [(3.5, 1.4), (3.0, drift_floor(3.0))]
    top = -y0
    outer = rect_loop(len(inner), PIT_W, top)
    w_in = [Vector((x, y0 + y, PIT_L)) for x, y in inner]
    w_out = [Vector((x, y0 + y, PIT_L)) for x, y in outer]
    soup.strip([w_in, w_out], lambda r, i: shaft_wall_color(0, 2, 1), "in", lambda r: Vector((0, -10, PIT_L / 2)), closed=False)
    merge(soup, d)
    if render:
        merge(soup, shaft_collar())
    return soup


def drift_floor(x):
    return .2 * (x / 3.5) ** 2


def rect_loop(n, half, top):
    """n points along the open rectangle from (-half, 0) up to (-half, top), across, and down to (half, 0)."""
    length = 2 * top + 2 * half
    out = []
    for k in range(n):
        d = length * k / (n - 1)
        if d <= top:
            out.append((-half, d))
        elif d <= top + 2 * half:
            out.append((-half + (d - top), top))
        else:
            out.append((half, top - (d - top - 2 * half)))
    return out


def shaft_collar():
    """A timber collar set into the ground on the three sides the ball does not enter by: drawn only, 0.5 m high."""
    soup = Soup()
    soup.box(Vector((-PIT_W - .4, .1, PIT_L / 2)), (.8, .5, PIT_L + 1.6), C["timber"])
    soup.box(Vector((PIT_W + .4, .1, PIT_L / 2)), (.8, .5, PIT_L + 1.6), C["timber"])
    soup.box(Vector((0, .1, PIT_L + .4)), (2 * PIT_W, .5, .8), C["timber"])
    return soup


def shaft_wall_color(i, r, side):
    if i <= 2:
        return tint(C["timber"] if i % 2 == 0 else C["timber_pale"], .06, i * 7)
    return tint(C["rock_red"] if side else C["sandstone_wall"], .06, i * 3 + side)


def merge(dst, src):
    off = len(dst.verts)
    dst.verts += src.verts
    for f, c, sm in zip(src.faces, src.colors, src.smooth):
        dst.faces.append(tuple(k + off for k in f))
        dst.colors.append(c)
        dst.smooth.append(sm)


def shaft_shell1():
    soup = Soup()
    for k in range(29):
        soup.box(Vector((-PIT_W + .22, -18.3 + k * .62, 2.0)), (.1, .06, .7), C["timber_pale"])
    for z in (1.65, 2.35):
        soup.box(Vector((-PIT_W + .22, -9.5, z)), (.1, 17.8, .08), C["timber"])
    for k, h in enumerate([-16, -12.5, -9, -5.5, -2]):
        soup.box(Vector((0, h - PIT_TAN * 6, .25)), (2 * PIT_W - .1, .4, .5), tint(C["timber"], .2, k))
        for side in (-1, 1):
            soup.box(Vector((side * (PIT_W - .25), h - PIT_TAN * PIT_L / 2, PIT_L / 2)), (.5, .4, PIT_L - .2), tint(C["timber"], .2, k + 7 * side))
    return soup


def shaft_shell2():
    soup = Soup()
    soup.box(Vector((PIT_W - .3, -9.0, 5.0)), (.1, 18.0, .1), C["copper"])
    for k in range(18):
        soup.box(Vector((PIT_W - .22, -17 + k, 5.0)), (.14, .22, .22), C["copper"])
    for k in range(20):
        side = -1 if k % 2 else 1
        x = side * (3.6 + hash01(k, 1, 101) * 1.8)
        z = 1 + hash01(k, 2, 102) * 9
        sz = .3 + hash01(k, 3, 103) * .6
        soup.box(Vector((x, pit_floor_y(z) + sz * .3, z)), (sz, sz * .7, sz), tint(C["rock_red"], .3, k), yaw=hash01(k, 4, 104) * 180)
    soup.cone(Vector((PIT_W - .6, -2.4, 8.0)), .5, 1.0, 8, C["timber"], down=True)
    return soup


RECIPES = {
    "lava_tube_run": {"fact": "ride_chute", "size": [48, 12, 16]},
    "lava_tube_run_bend_p30": {"fact": "ride_chute", "size": [48, 12, 16]},
    "lava_tube_run_bend_n30": {"fact": "ride_chute", "size": [48, 12, 16]},
    "adit_mouth": {"fact": "ride_chute", "size": [56, 6, 8]},
    "shaft_drop": {"fact": "ride_drop", "size": [26, 18, 12]},
    "spillway_tunnel": {"fact": "ride_drop", "size": [90, 9, 11]},
}
def shells_for(rid, tube):
    if rid.startswith("lava"):
        return [lava_shell1(tube), lava_shell2(tube)]
    if rid == "adit_mouth":
        return [adit_shell1(tube), adit_shell2(tube)]
    if rid == "spillway_tunnel":
        return [spillway_shell1(tube), spillway_shell2(tube)]
    return [shaft_shell1(), shaft_shell2()]


def exit_socket(rid, tube):
    if rid == "shaft_drop":
        return Vector((0, pit_floor_y(PIT_L) - DRIFT_L * DRIFT_TAN, PIT_L + DRIFT_L)), 0.0
    return tube.end_socket()


def build_glb(rid, out_dir, count_only):
    tube = None if rid == "shaft_drop" else tube_for(rid)
    render = build_shaft(True) if tube is None else tube.build(True)
    if rid == "adit_mouth":
        merge(render, adit_timbers(tube))
    col = build_shaft(False) if tube is None else tube.build(False)
    shells = shells_for(rid, tube)
    counts = {"render": len(render.tris()), "col": len(col.tris()), "shell1": len(shells[0].tris()), "shell2": len(shells[1].tris())}
    if count_only:
        print("TUNNELS_COUNT", rid, json.dumps(counts, sort_keys=True))
        return counts
    rows = {}
    pos, yaw = exit_socket(rid, tube)
    common.reset()
    root = common.empty(rid + "_root")
    make_object(rid, render, root, True)
    make_object(rid + "-col", col, root, False)
    sock = common.empty("socket_exit", bpy_xyz(pos), root)
    sock.rotation_euler = (0, 0, yaw)
    path = Path(out_dir) / (rid + ".glb")
    common.export(root, str(path))
    rows[rid] = check_glb(path, rid, counts, PARK_LARGE, 2, [rid, rid + "-col", "socket_exit"], pos, yaw)
    for k, shell in enumerate(shells, 1):
        common.reset()
        sroot = common.empty("%s_detail%d_root" % (rid, k))
        make_object("%s_detail%d" % (rid, k), shell, sroot, True)
        spath = Path(out_dir) / ("%s_detail%d.glb" % (rid, k))
        common.export(sroot, str(spath))
        rows["%s_detail%d" % (rid, k)] = check_glb(spath, rid, counts, DETAIL, 1, ["%s_detail%d" % (rid, k)], None, None)
    return rows


def gltf_doc(path):
    data = path.read_bytes()
    length = struct.unpack_from("<I", data, 12)[0]
    return json.loads(data[20:20 + length])


def check_glb(path, rid, counts, budget, draws, names, pos, yaw):
    doc = gltf_doc(path)
    tris = verts = prims = 0
    lo, hi = [1e18] * 3, [-1e18] * 3
    mesh_tris = {}
    for mesh in doc["meshes"]:
        for prim in mesh["primitives"]:
            acc = doc["accessors"][prim["attributes"]["POSITION"]]
            n = doc["accessors"][prim["indices"]]["count"] // 3
            tris += n
            verts += acc["count"]
            prims += 1
            mesh_tris[mesh.get("name", "")] = n
            for k in range(3):
                lo[k] = min(lo[k], acc["min"][k])
                hi[k] = max(hi[k], acc["max"][k])
    node_names = [n.get("name", "") for n in doc["nodes"]]
    assert tris <= budget["tris"], (path.name, tris, budget)
    assert prims == draws, (path.name, "draws", prims, draws)
    for name in names:
        assert name in node_names, (path.name, "missing node", name, node_names)
    assert "KHR_lights_punctual" not in doc.get("extensionsUsed", []), (path.name, "light in recipe")
    assert [m["name"] for m in doc.get("materials", [])] in (["enamel"], []), (path.name, doc.get("materials"))
    if pos is not None:
        sock = doc["nodes"][node_names.index("socket_exit")]
        t = sock.get("translation", [0, 0, 0])
        assert all(abs(a - b) < 1e-3 for a, b in zip(t, pos)), (path.name, "socket", t, tuple(pos))
        q = sock.get("rotation", [0, 0, 0, 1])
        assert abs(2 * math.atan2(q[1], q[3]) - yaw) < 1e-3, (path.name, "socket yaw", q, yaw)
    row = {"file": path.name, "triangles": tris, "vertices": verts, "draws": prims, "mesh_triangles": mesh_tris,
           "size": [round(hi[k] - lo[k], 3) for k in range(3)], "min": [round(v, 3) for v in lo], "max": [round(v, 3) for v in hi],
           "sha256": hashlib.sha256(path.read_bytes()).hexdigest()}
    print("TUNNELS_EXPORT", json.dumps(row, sort_keys=True))
    return row


def main():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    parser = argparse.ArgumentParser()
    parser.add_argument("--out", default=str(MODELS))
    parser.add_argument("--only", default="")
    parser.add_argument("--count-only", action="store_true")
    args = parser.parse_args(argv)
    ids = [i for i in args.only.split(",") if i] or list(RECIPES)
    Path(args.out).mkdir(parents=True, exist_ok=True)
    for rid in ids:
        build_glb(rid, args.out, args.count_only)


if __name__ == "__main__":
    main()
