"""Park recipe family "ledges" (design-v3/PARK.md section 4, wave 13 KC6): the elevated lines and ledges.

  cliff_dwelling_row  a sandstone shelf under a brow, a row of masonry rooms stepped back against the cliff, roof beams
                      (vigas) projecting from the roofs. The fictional cliff builders' work; the Ancestral Puebloan
                      cliff dwellings are a shaped reference only (PARK.md section 4, real-culture guardrail).
  mesa_rim_ledge      a broad mesa-rim shelf: banded red and cream strata under it, a banked lip on the open edge and the
                      mesa rising behind. Stage 5's tram station stands on one; stages 1 to 4 ride them as ledges.
  viga_pivot          a short shelf with a masonry wall at its back and four long beams projecting from the wall across the
                      lane and out over the open edge: the pivot posts the harpoon bites for a swing.

Convention, the same for all three (PARK.md section 4, KC contract): +Y up, the ride direction +Z (the fall line), the origin
at the entry lip on the ground, centred on x. The shelf rises on a ramp from y 0 at z 0 to SHELF_Y (2.5 m) at z RAMP, runs
level, and falls on a ramp back to y 0 at z LENGTH. Open edge on +x, the cliff or wall on -x. The ball rolls the shelf's clear
lane (at least 8 m of x); the rooms, the wall and the mesa back stand outside it. A recipe is built at its own size and the
loader does not scale it, so a park row's `size` names the footprint the row wants and a longer line is a chain of rows.

Files per recipe id (the names park_recipes.gd reads, assets/asset_budgets.json class landform / detail):
  <id>.glb          the render mesh `<id>` (one draw, vertex colour in the material `enamel`, the slot role whose StandardMaterial reads vertex colour as albedo,
                    park_recipes.gd maps it to) and the collision mesh `<id>-col` (low-poly trimesh, never drawn)
  <id>_detail1.glb  the mid shell (door frames, parapets, talus, sage), one mesh, visible to 120 m
  <id>_detail2.glb  the near shell (masonry courses, sherds, stone chips), one mesh, visible to 50 m

Colour: Southwest palette only, as vertex colour: sandstone c6a274, cream e6d9b8, iron-oxide red 9b513a, desert varnish
3a3027, sage 7d8b6a, juniper 3f5a3e. No copper machinery here (no machinery), no brass, no texture, no light.
Lore: the cliff builders' rooms are dry-laid sandstone with log beams; nothing here names a living people.

  prlimit -v12884901888 blender --background --threads 2 --python-exit-code 1 --python \\
      sketches/core-loop/tools/blender/park/ledges.py -- [--out-dir DIR] [--count-only] [--log FILE]
"""
import argparse
import hashlib
import json
import math
from pathlib import Path
import random
import struct
import sys

import bpy

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE.parent))
import common

MODELS = Path(common.SKETCH) / "assets/models/park"

SHELF_Y = 2.5
LANDFORM_TRIS = 8000
DETAIL_TRIS = 1500
DETAIL_VERTS = 3000
MIN_DEPTH = 8.0
CLEAR_ABOVE = 5.5
LANE_PAD = 0.6

RED = ("a65f43", "9b513a", "6a3626")
CREAM = ("e3d4b0", "d2c5a5", "a39373")
SANDTOP = ("d0b88c", "c6a274", "8a6c48")
MASONRY = ("d9c9a8", "c9ad7e", "8a6e4a")
ADOBE = ("c6a97c", "b89a6e", "7c6445")
VARNISH = ("3a3027", "3a3027", "2b241d")
REDS = [RED, ("b3694a", "a85b3e", "78432d"), ("86513c", "7a4733", "52301f")]
CREAMS = [CREAM, ("ead8b4", "dac9a6", "a99a78")]
SANDS = [SANDTOP, ("d4b98c", "c19d6b", "86684a")]
SHADOW = ("2b2420", "2b2420", "1f1a17")
LOG = ("7a5636", "6b4a30", "4a3220")
LOGEND = ("5e4128", "4f3723", "3a2819")
SAGE = ("8a9876", "7d8b6a", "55604a")
JUNIPER = ("4c6a4b", "3f5a3e", "2b402b")
CONCRETE = ("a6a69d", "9a9a92", "70706a")


def hexf(h):
    return tuple(int(h[i:i + 2], 16) / 255.0 for i in (0, 2, 4))


def mixf(a, b, t):
    return tuple(a[i] + (b[i] - a[i]) * t for i in range(3))


def xyz(v):
    return (v[0], -v[2], v[1])


def sub(a, b):
    return (a[0] - b[0], a[1] - b[1], a[2] - b[2])


def cross(a, b):
    return (a[1] * b[2] - a[2] * b[1], a[2] * b[0] - a[0] * b[2], a[0] * b[1] - a[1] * b[0])


def dot(a, b):
    return a[0] * b[0] + a[1] * b[1] + a[2] * b[2]


class Surface:
    """Convex pieces added in Godot coordinates; every face is wound outward from its piece's centre, then fanned to
    triangles, so no winding is hand-written and the export is flat shaded."""

    def __init__(self, name, seed, colored=True):
        self.name, self.colored = name, colored
        self.rng = random.Random(seed)
        self.verts, self.tris, self.colors = [], [], []

    def add(self, verts, faces, tone=SANDTOP, mottle=0.1):
        used = sorted({i for f in faces for i in f})
        remap = {old: k for k, old in enumerate(used)}
        pts = [verts[i] for i in used]
        centre = tuple(sum(p[k] for p in pts) / len(pts) for k in range(3))
        off = len(self.verts)
        self.verts.extend(pts)
        for f in faces:
            ring = [pts[remap[i]] for i in f]
            n = (0.0, 0.0, 0.0)
            for k in range(1, len(ring) - 1):
                c = cross(sub(ring[k], ring[0]), sub(ring[k + 1], ring[0]))
                n = (n[0] + c[0], n[1] + c[1], n[2] + c[2])
            mid = tuple(sum(p[k] for p in ring) / len(ring) for k in range(3))
            idx = [off + remap[i] for i in f]
            if dot(n, sub(mid, centre)) < 0:
                idx.reverse()
                n = (-n[0], -n[1], -n[2])
            length = math.sqrt(dot(n, n))
            if length < 1e-9:
                continue
            ny = n[1] / length
            base = hexf(tone[0] if ny > .6 else tone[2] if ny < -.6 else tone[1])
            t = self.rng.uniform(-1, 1) * mottle
            c = mixf(base, hexf(VARNISH[0]) if t < 0 else hexf(CREAM[0]), abs(t))
            for k in range(1, len(idx) - 1):
                self.tris.append((idx[0], idx[k], idx[k + 1]))
                self.colors.append(c)

    def box(self, lo, hi, tone=SANDTOP, yaw=0.0, skip=(), mottle=0.1):
        xs, ys, zs = (lo[0], hi[0]), (lo[1], hi[1]), (lo[2], hi[2])
        pts = [(xs[i], ys[j], zs[k]) for i in (0, 1) for j in (0, 1) for k in (0, 1)]
        if yaw:
            cx, cz = (lo[0] + hi[0]) / 2, (lo[2] + hi[2]) / 2
            cs, sn = math.cos(yaw), math.sin(yaw)
            pts = [(cx + (p[0] - cx) * cs + (p[2] - cz) * sn, p[1], cz - (p[0] - cx) * sn + (p[2] - cz) * cs) for p in pts]
        faces = {"-x": (0, 1, 3, 2), "+x": (4, 5, 7, 6), "-y": (0, 1, 5, 4), "+y": (2, 3, 7, 6), "-z": (0, 2, 6, 4), "+z": (1, 3, 7, 5)}
        self.add(pts, [f for name, f in faces.items() if name not in skip], tone, mottle)

    def prism_x(self, poly_zy, x0, x1, tone, mottle=0.1):
        """A profile in (z, y) extruded across x from x0 to x1."""
        n = len(poly_zy)
        pts = [(x0, y, z) for z, y in poly_zy] + [(x1, y, z) for z, y in poly_zy]
        faces = [tuple(range(n)), tuple(range(n, 2 * n))]
        faces += [(i, (i + 1) % n, n + (i + 1) % n, n + i) for i in range(n)]
        self.add(pts, faces, tone, mottle)

    def prism_z(self, poly_xy, z0, z1, tone, mottle=0.1):
        """A profile in (x, y) extruded along z from z0 to z1."""
        n = len(poly_xy)
        pts = [(x, y, z0) for x, y in poly_xy] + [(x, y, z1) for x, y in poly_xy]
        faces = [tuple(range(n)), tuple(range(n, 2 * n))]
        faces += [(i, (i + 1) % n, n + (i + 1) % n, n + i) for i in range(n)]
        self.add(pts, faces, tone, mottle)

    def rod(self, a, b, r, tone, sides=8):
        """A round pole from a to b."""
        d = sub(b, a)
        ln = math.sqrt(dot(d, d))
        d = tuple(c / ln for c in d)
        up = (0.0, 1.0, 0.0) if abs(d[1]) < .9 else (1.0, 0.0, 0.0)
        u = cross(d, up)
        lu = math.sqrt(dot(u, u))
        u = tuple(c / lu for c in u)
        v = cross(d, u)
        ring = [tuple(math.cos(2 * math.pi * k / sides) * r * u[i] + math.sin(2 * math.pi * k / sides) * r * v[i] for i in range(3)) for k in range(sides)]
        pts = [tuple(a[i] + q[i] for i in range(3)) for q in ring] + [tuple(b[i] + q[i] for i in range(3)) for q in ring]
        faces = [tuple(range(sides)), tuple(range(sides, 2 * sides))]
        faces += [(i, (i + 1) % sides, sides + (i + 1) % sides, sides + i) for i in range(sides)]
        self.add(pts, faces, tone, 0.12)

    def rod_x(self, y, z, x0, x1, r, tone, sides=8):
        """A round log along x with its axis at (y, z)."""
        self.rod((x0, y, z), (x1, y, z), r, tone, sides)

    def rock(self, centre, size, tone, yaw=None):
        """A jittered, chunky stone: a box with its corners moved by up to a quarter of its size."""
        r = self.rng
        lo = (centre[0] - size[0] / 2, centre[1] - size[1] / 2, centre[2] - size[2] / 2)
        pts = []
        for i in (0, 1):
            for j in (0, 1):
                for k in (0, 1):
                    p = [lo[0] + i * size[0], lo[1] + j * size[1], lo[2] + k * size[2]]
                    for a in range(3):
                        p[a] += r.uniform(-.25, .25) * size[a]
                    pts.append(tuple(p))
        faces = [(0, 1, 3, 2), (4, 5, 7, 6), (0, 1, 5, 4), (2, 3, 7, 6), (0, 2, 6, 4), (1, 3, 7, 5)]
        a = r.uniform(0, math.pi) if yaw is None else yaw
        cs, sn = math.cos(a), math.sin(a)
        pts = [(centre[0] + (p[0] - centre[0]) * cs + (p[2] - centre[2]) * sn, p[1],
                centre[2] - (p[0] - centre[0]) * sn + (p[2] - centre[2]) * cs) for p in pts]
        self.add(pts, faces, tone, 0.14)

    def tuft(self, centre, radius, tone):
        """A sage or juniper clump: a jittered octahedron."""
        r = self.rng
        pts = [(centre[0] + dx * radius * r.uniform(.8, 1.2), centre[1] + dy * radius * r.uniform(.5, .8), centre[2] + dz * radius * r.uniform(.8, 1.2))
               for dx, dy, dz in ((1, 0, 0), (-1, 0, 0), (0, 1, 0), (0, -1, 0), (0, 0, 1), (0, 0, -1))]
        pts[3] = (centre[0], centre[1] - radius * .1, centre[2])
        self.add(pts, [(0, 2, 4), (4, 2, 1), (1, 2, 5), (5, 2, 0), (0, 3, 4), (4, 3, 1), (1, 3, 5), (5, 3, 0)], tone, 0.12)

    def bounds(self):
        lo = [min(v[k] for v in self.verts) for k in range(3)]
        hi = [max(v[k] for v in self.verts) for k in range(3)]
        return lo, hi

    def finish(self, root):
        mesh = bpy.data.meshes.new(self.name)
        mesh.from_pydata([xyz(v) for v in self.verts], [], [tuple(t) for t in self.tris])
        mesh.update()
        for poly in mesh.polygons:
            poly.use_smooth = False
        if self.colored:
            attr = mesh.color_attributes.new(name="Color", type="FLOAT_COLOR", domain="CORNER")
            for poly, c in zip(mesh.polygons, self.colors):
                for li in poly.loop_indices:
                    attr.data[li].color = common.rgba(c)
            mesh.color_attributes.active_color = attr
            mesh.materials.append(stone_material())
        obj = bpy.data.objects.new(self.name, mesh)
        bpy.context.scene.collection.objects.link(obj)
        obj.parent = root
        return obj


def stone_material():
    mat = bpy.data.materials.get("enamel")
    if mat is not None:
        return mat
    mat = bpy.data.materials.new("enamel")
    mat.use_nodes = True
    bsdf = mat.node_tree.nodes.get("Principled BSDF")
    bsdf.inputs["Roughness"].default_value = .93
    bsdf.inputs["Metallic"].default_value = 0.0
    attr = mat.node_tree.nodes.new("ShaderNodeVertexColor")
    attr.layer_name = "Color"
    mat.node_tree.links.new(attr.outputs["Color"], bsdf.inputs["Base Color"])
    return mat


def clip_range(poly, axis, lo, hi):
    """A convex 2-D polygon cut to lo <= p[axis] <= hi (Sutherland-Hodgman against two lines)."""
    def cut(points, keep, v):
        out = []
        for i, p in enumerate(points):
            q = points[(i + 1) % len(points)]
            pin, qin = keep(p[axis]), keep(q[axis])
            if pin:
                out.append(p)
            if pin != qin:
                t = (v - p[axis]) / (q[axis] - p[axis])
                out.append((p[0] + (q[0] - p[0]) * t, p[1] + (q[1] - p[1]) * t))
        return out
    pts = cut(list(poly), lambda v: v >= lo - 1e-9, lo)
    pts = cut(pts, lambda v: v <= hi + 1e-9, hi) if pts else []
    return pts


def clip_band(poly, ya, yb):
    return clip_range(poly, 1, ya, yb)


def profile(length, ramp, depth=8.0):
    """The shelf in (z, y): ramp up from the entry lip, level at SHELF_Y, ramp down, mass under to -depth."""
    return [(0.0, -depth), (0.0, 0.0), (ramp, SHELF_Y), (length - ramp, SHELF_Y), (length, 0.0), (length, -depth)]


def segments(rng, z0, z1, lo=2.6, hi=6.2):
    """Z windows of random width covering z0 to z1."""
    out, z = [], z0
    while z < z1 - 1e-6:
        w = rng.uniform(lo, hi)
        if z1 - (z + w) < lo * .8:
            w = z1 - z
        out.append((z, min(z + w, z1)))
        z += w
    return out


def pick(rng, tones, last):
    choices = [t for t in tones if t is not last]
    return rng.choice(choices)


def strata(s, rng, poly, x_lo, x_hi, bands, recede=(-1.3, .3)):
    """The mass under the shelf, cut into z windows of random width. Each window stacks bands (a (y0, y1, tones) list, the
    last one the shelf's own top band) with thicknesses drifting by up to 0.45 m and an open-edge offset per band drawn from
    `recede`, except the top band, which sits exactly on x_hi so the ball's lip is the collider's lip."""
    z0 = min(p[0] for p in poly)
    z1 = max(p[0] for p in poly)
    last = None
    for za, zb in segments(rng, z0, z1):
        part = clip_range(poly, 0, za, zb)
        if len(part) < 3:
            continue
        edges = [bands[0][0]] + [b[1] + rng.uniform(-.45, .45) for b in bands[:-1]] + [bands[-1][1]]
        for k, (ya, yb, tones) in enumerate(bands):
            band = clip_band(part, edges[k], edges[k + 1])
            if len(band) < 3:
                continue
            tone = pick(rng, tones, last)
            last = tone
            front = 0.0 if k == len(bands) - 1 else rng.uniform(*recede)
            s.prism_x(band, x_lo, x_hi + front, tone)


def cliff(base, col, rng, x_back, x_front, z0, z1, y0, y1, bands, recede=(-1.2, .3), col_front=None):
    """A cliff wall behind a shelf: z windows of random width, each a stack of boxes from x_back to x_front plus a per-band
    offset. The collider is one box per window at col_front (default the most receded face), so the ball meets rock where the
    picture shows it, give or take the recede."""
    last = None
    cf = x_front + recede[0] if col_front is None else col_front
    for za, zb in segments(rng, z0, z1):
        lows = [y0] + sorted(rng.uniform(y0 + (y1 - y0) * f - .6, y0 + (y1 - y0) * f + .6) for f in [k / len(bands) for k in range(1, len(bands))]) + [y1]
        for k, tones in enumerate(bands):
            tone = pick(rng, tones, last)
            last = tone
            base.box((x_back, lows[k], za), (x_front + rng.uniform(*recede), lows[k + 1], zb), tone)
        col.box((x_back, y0, za), (cf, y1, zb))


def courses_front(s, x, z0, z1, y0, y1, rng, tone, rows, per_row, face=1):
    """Dry-laid sandstone courses as thin blocks 3 cm proud of a wall at x, facing `face` on x."""
    h = (y1 - y0) / rows
    for r in range(rows):
        cuts = sorted(rng.uniform(.2, .8) for _ in range(per_row - 1))
        edges = [0.0] + cuts + [1.0]
        shift = rng.uniform(-.06, .06)
        for k in range(per_row):
            a = z0 + (z1 - z0) * min(max(edges[k] + shift, 0.0), 1.0)
            b = z0 + (z1 - z0) * min(max(edges[k + 1] + shift - .012, 0.0), 1.0)
            if b - a < .08:
                continue
            xa, xb = (x, x + .035 * face)
            s.box((min(xa, xb), y0 + r * h + .015, a), (max(xa, xb), y0 + (r + 1) * h - .015, b), tone, skip=("-x" if face > 0 else "+x",), mottle=.16)


def shelf_col(c, length, ramp, x_lo, x_hi):
    c.prism_x(profile(length, ramp, 3.0), x_lo, x_hi, SANDTOP)


A_LEN, A_RAMP, A_W = 60.0, 12.0, 14.0
ROOM_Z0, ROOM_STEP, ROOM_W, ROOMS = 12.5, 6.0, 5.0, 6
ROOM_FRONT = -3.5
ROOM_H = 3.2
UPPER_FRONT = -4.8
VIGA_LOW = SHELF_Y + 2.55
VIGA_R = .17


def room_z(i):
    return ROOM_Z0 + ROOM_STEP * i


def upper_room(i):
    return i % 2 == 0


def cliff_dwelling_row(base, col, d1, d2):
    hx = A_W / 2
    poly = profile(A_LEN, A_RAMP)
    r = base.rng
    strata(base, r, poly, -hx, hx, [(-8.0, -5.6, REDS), (-5.6, -3.2, CREAMS), (-3.2, -.5, REDS), (-.5, SHELF_Y + .1, SANDS)])
    shelf_col(col, A_LEN, A_RAMP, -hx, hx)
    cliff(base, col, r, -14.0, -hx, 3.0, A_LEN - 3.0, -8.0, SHELF_Y + 8.5, [REDS, CREAMS, REDS], col_front=-hx - 1.3)
    for za, zb in segments(r, 4.0, A_LEN - 4.0, 3.0, 7.0):
        top = SHELF_Y + 11.0 + r.uniform(-.5, 1.0)
        base.box((-14.0, SHELF_Y + 8.3 + r.uniform(-.3, .3), za), (-5.4 + r.uniform(-.9, .6), top, zb), pick(r, CREAMS + SANDS, None))
    col.box((-14.0, SHELF_Y + 8.5, 4.0), (-6.2, SHELF_Y + 11.0, A_LEN - 4.0))
    for i in range(ROOMS):
        z0 = room_z(i)
        base.box((-hx - 1.5, SHELF_Y, z0), (ROOM_FRONT, SHELF_Y + ROOM_H, z0 + ROOM_W), MASONRY, mottle=.08)
        base.box((-hx, SHELF_Y + ROOM_H, z0 - .12), (ROOM_FRONT + .2, SHELF_Y + ROOM_H + .3, z0 + ROOM_W + .12), ADOBE, mottle=.06)
        col.box((-hx, SHELF_Y, z0), (ROOM_FRONT, SHELF_Y + ROOM_H, z0 + ROOM_W))
        col.box((-hx, SHELF_Y + ROOM_H, z0 - .12), (ROOM_FRONT + .2, SHELF_Y + ROOM_H + .3, z0 + ROOM_W + .12))
        zc = z0 + ROOM_W / 2
        base.box((ROOM_FRONT, SHELF_Y, zc - .5), (ROOM_FRONT + .04, SHELF_Y + 1.5, zc + .5), SHADOW, mottle=0)
        base.box((ROOM_FRONT, SHELF_Y + 1.5, zc - .8), (ROOM_FRONT + .04, SHELF_Y + 2.0, zc + .8), SHADOW, mottle=0)
        for dz in (1.0, 2.5, 4.0):
            z = z0 + dz
            base.rod_x(VIGA_LOW, z, ROOM_FRONT - .1, ROOM_FRONT + 1.4, VIGA_R, LOG)
            base.rod_x(VIGA_LOW, z, ROOM_FRONT + 1.38, ROOM_FRONT + 1.42, VIGA_R * .85, LOGEND)
            col.box((ROOM_FRONT - .1, VIGA_LOW - VIGA_R, z - VIGA_R), (ROOM_FRONT + 1.4, VIGA_LOW + VIGA_R, z + VIGA_R))
        if upper_room(i):
            u0, u1 = z0 + .5, z0 + ROOM_W - .5
            ytop = SHELF_Y + ROOM_H + .3
            base.box((-hx - 1.5, ytop, u0), (UPPER_FRONT, ytop + 2.5, u1), MASONRY, mottle=.08)
            base.box((-hx, ytop + 2.5, u0 - .1), (UPPER_FRONT + .2, ytop + 2.8, u1 + .1), ADOBE, mottle=.06)
            col.box((-hx, ytop, u0), (UPPER_FRONT, ytop + 2.5, u1))
            base.box((UPPER_FRONT, ytop + .6, zc - .35), (UPPER_FRONT + .04, ytop + 1.4, zc + .35), SHADOW, mottle=0)
            for dz in (1.0, 2.0, 3.0):
                z = u0 + dz
                yb = ytop + 2.2
                base.rod_x(yb, z, UPPER_FRONT - .1, UPPER_FRONT + 1.2, VIGA_R * .9, LOG, sides=6)
                col.box((UPPER_FRONT - .1, yb - VIGA_R, z - VIGA_R), (UPPER_FRONT + 1.2, yb + VIGA_R, z + VIGA_R))
    for k in range(7):
        base.rock((r.uniform(-6.5, -3.9), SHELF_Y + .2, r.choice([r.uniform(8.0, 11.5), r.uniform(48.5, 52.0)])), (r.uniform(.8, 1.6), r.uniform(.6, 1.1), r.uniform(.8, 1.6)), SANDTOP)

    d = d1
    for i in range(ROOMS):
        z0 = room_z(i)
        zc = z0 + ROOM_W / 2
        d.box((ROOM_FRONT - .06, SHELF_Y + 2.0, zc - 1.0), (ROOM_FRONT + .06, SHELF_Y + 2.18, zc + 1.0), LOG, mottle=.1)
        d.box((ROOM_FRONT - .06, SHELF_Y - .02, zc - 1.05), (ROOM_FRONT + .02, SHELF_Y + .12, zc - .55), CREAM)
        d.box((ROOM_FRONT - .06, SHELF_Y - .02, zc + .55), (ROOM_FRONT + .02, SHELF_Y + .12, zc + 1.05), CREAM)
        d.box((-hx, SHELF_Y + ROOM_H + .3, z0 - .12), (ROOM_FRONT + .22, SHELF_Y + ROOM_H + .62, z0 + .14), CREAM)
        d.box((-hx, SHELF_Y + ROOM_H + .3, z0 + ROOM_W - .14), (ROOM_FRONT + .22, SHELF_Y + ROOM_H + .62, z0 + ROOM_W + .12), CREAM)
        d.box((ROOM_FRONT - .05, SHELF_Y + ROOM_H + .3, z0 - .12), (ROOM_FRONT + .22, SHELF_Y + ROOM_H + .62, z0 + ROOM_W + .12), CREAM)
        d.box((ROOM_FRONT + .0, SHELF_Y + ROOM_H - .35, zc + 1.6), (ROOM_FRONT + .55, SHELF_Y + ROOM_H - .15, zc + 1.9), ADOBE)
        if upper_room(i):
            ytop = SHELF_Y + ROOM_H + .3
            d.box((UPPER_FRONT - .05, ytop + .5, zc - .5), (UPPER_FRONT + .03, ytop + .6, zc + .5), CREAM)
            for dz in (-1.6, 1.6):
                d.rock((UPPER_FRONT + .15, ytop + 2.8 + .1, zc + dz), (.5, .22, .5), CREAM)
    zl = room_z(0) + 4.4
    ytop0 = SHELF_Y + ROOM_H + .3
    foot, head = (ROOM_FRONT - .4, ytop0), (UPPER_FRONT + .12, ytop0 + 2.6)
    for dz in (-.3, .3):
        d.rod((foot[0], foot[1], zl + dz), (head[0], head[1], zl + dz), .045, LOG, sides=4)
    for k in range(1, 7):
        t = k / 7.0
        px, py = foot[0] + (head[0] - foot[0]) * t, foot[1] + (head[1] - foot[1]) * t
        d.rod((px, py, zl - .3), (px, py, zl + .3), .035, LOG, sides=4)
    for k in range(10):
        d.rock((r.uniform(-6.6, -4.2), SHELF_Y + .15, r.uniform(8.0, 52.0)), (r.uniform(.4, .9), r.uniform(.3, .6), r.uniform(.4, .9)), SANDTOP)
    for k in range(12):
        d.tuft((r.uniform(-6.8, -5.2), SHELF_Y + .12, r.uniform(8.0, 52.0)), r.uniform(.3, .6), SAGE)
    for z in (6.0, 54.0):
        d.tuft((-5.0, SHELF_Y * .5, z), .9, JUNIPER)
    for k in range(10):
        d.rock((hx - r.uniform(.2, 1.0), -r.uniform(.2, 3.5), r.uniform(10.0, 50.0)), (r.uniform(.7, 1.4), r.uniform(.4, .8), r.uniform(.7, 1.4)), RED)

    d = d2
    cr = random.Random(77)
    for i in range(ROOMS):
        z0 = room_z(i)
        courses_front(d, ROOM_FRONT, z0 + .05, z0 + ROOM_W - .05, SHELF_Y + .02, SHELF_Y + ROOM_H - .03, cr, MASONRY, 6, 2)
        if upper_room(i):
            ytop = SHELF_Y + ROOM_H + .3
            courses_front(d, UPPER_FRONT, z0 + .55, z0 + ROOM_W - .55, ytop + .02, ytop + 2.45, cr, MASONRY, 4, 2)
    for k in range(28):
        x, z = r.uniform(-3.3, -0.9), r.uniform(13.0, 47.0)
        w = r.uniform(.12, .3)
        d.box((x, SHELF_Y, z), (x + w, SHELF_Y + .025, z + w * r.uniform(.6, 1.2)), r.choice([RED, CREAM, ADOBE]), mottle=.2)
    return "cliff_dwelling_row"


B_LEN, B_RAMP, B_W = 60.0, 12.0, 18.0


def mesa_rim_ledge(base, col, d1, d2):
    hx = B_W / 2
    r = base.rng
    poly = profile(B_LEN, B_RAMP)
    strata(base, r, poly, -hx, hx, [(-8.0, -6.0, REDS), (-6.0, -3.6, CREAMS), (-3.6, -1.2, REDS), (-1.2, SHELF_Y + .1, SANDS)], recede=(-1.8, .3))
    shelf_col(col, B_LEN, B_RAMP, -hx, hx)
    lip_a, lip_d = B_RAMP + 2.0, B_LEN - B_RAMP - 2.0
    lip_b, lip_c = lip_a + 4.0, lip_d - 4.0
    lip_pts = [(hx - 2.0, SHELF_Y, lip_a), (hx, SHELF_Y, lip_a), (hx - 2.0, SHELF_Y, lip_d), (hx, SHELF_Y, lip_d),
               (hx, SHELF_Y + .8, lip_b), (hx, SHELF_Y + .8, lip_c)]
    lip_faces = [(0, 1, 3, 2), (1, 3, 5, 4), (0, 2, 5, 4), (0, 1, 4), (2, 3, 5)]
    base.add(lip_pts, lip_faces, CREAM)
    col.add(lip_pts, lip_faces, CREAM)
    benches = []
    for za, zb in segments(r, 0.0, B_LEN, 3.5, 8.0):
        f1 = -hx + r.uniform(0.0, 1.2)
        b1, b2 = r.uniform(2.2, 3.6), r.uniform(2.2, 3.6)
        h1 = SHELF_Y + r.uniform(1.8, 2.8)
        h2 = h1 + r.uniform(2.0, 3.0)
        h3 = h2 + r.uniform(1.8, 2.8)
        for xf, xb, ytop, tones in ((f1, f1 - b1, h1, REDS), (f1 - b1, f1 - b1 - b2, h2, CREAMS), (f1 - b1 - b2, f1 - b1 - b2 - 3.0, h3, SANDS)):
            tone = pick(r, tones, None)
            base.box((-hx - 16.0, -8.0, za), (xf, ytop, zb), tone)
            col.box((-hx - 16.0, -8.0, za), (xf, ytop, zb))
            benches.append((za, zb, xb, xf, ytop))
    d = d1
    for za, zb, xb, xf, yt in benches:
        for k in range(1):
            d.rock((r.uniform(xb + .5, xf - .5), yt + .15, r.uniform(za + .5, zb - .5)), (r.uniform(.6, 1.4), r.uniform(.4, .9), r.uniform(.6, 1.4)), pick(r, REDS + SANDS + CREAMS, None))
        d.tuft((r.uniform(xb + .5, xf - .5), yt + .05, r.uniform(za + .5, zb - .5)), r.uniform(.4, .8), SAGE)
    for z in (9.0, 24.0, 41.0, 53.0):
        d.tuft((-hx + 1.4, SHELF_Y + .05, z), 1.0, JUNIPER)
    for k in range(10):
        d.tuft((-hx + r.uniform(1.4, 3.0), SHELF_Y + .08, r.uniform(3.0, 57.0)), r.uniform(.25, .5), SAGE)
    for k in range(10):
        d.rock((hx - r.uniform(.1, 1.2), -r.uniform(.2, 4.2), r.uniform(6.0, 54.0)), (r.uniform(.7, 1.5), r.uniform(.4, .9), r.uniform(.7, 1.5)), r.choice([RED, CREAM]))
    for k in range(6):
        z = 14.0 + k * 6.4
        d.box((hx - 2.0, SHELF_Y + .01, z), (hx - .2, SHELF_Y + .05, z + .5), VARNISH, mottle=.2)
    d = d2
    for k in range(44):
        x, z = r.uniform(-hx + 1.6, hx - .4), r.uniform(1.0, B_LEN - 1.0)
        if abs(x) < 7.0 and (z < B_RAMP or z > B_LEN - B_RAMP):
            continue
        if z < B_RAMP or z > B_LEN - B_RAMP:
            continue
        w = r.uniform(.1, .32)
        d.box((x, SHELF_Y, z), (x + w, SHELF_Y + .03, z + w * r.uniform(.5, 1.3)), r.choice([RED, CREAM, SANDTOP]), mottle=.2)
    for za, zb, xb, xf, yt in benches:
        for k in range(2):
            d.rock((r.uniform(xb + .3, xf - .3), yt + .08, r.uniform(za + .3, zb - .3)), (r.uniform(.25, .6), r.uniform(.2, .4), r.uniform(.25, .6)), pick(r, REDS + SANDS, None))
    return "mesa_rim_ledge"


C_LEN, C_RAMP, C_W = 36.0, 8.0, 12.0
C_WALL_FRONT = -3.5
C_BEAM_Y = SHELF_Y + 6.1
C_BEAM_R = .28
C_BEAM_ZS = (11.5, 16.0, 20.5, 25.0)
C_BEAM_TIP = 8.0


def viga_pivot(base, col, d1, d2):
    hx = C_W / 2
    r = base.rng
    poly = profile(C_LEN, C_RAMP)
    strata(base, r, poly, -hx, hx, [(-8.0, -5.6, REDS), (-5.6, -3.2, CREAMS), (-3.2, -.5, REDS), (-.5, SHELF_Y + .1, SANDS)])
    shelf_col(col, C_LEN, C_RAMP, -hx, hx)
    cliff(base, col, r, -12.0, -hx, 3.0, C_LEN - 3.0, -8.0, SHELF_Y + 8.2, [REDS, CREAMS], col_front=-hx - 1.3)
    base.box((-hx - 1.5, SHELF_Y, C_BEAM_ZS[0] - 3.0), (C_WALL_FRONT, SHELF_Y + 6.5, C_BEAM_ZS[-1] + 3.0), MASONRY, mottle=.08)
    base.box((-hx, SHELF_Y + 6.5, C_BEAM_ZS[0] - 3.1), (C_WALL_FRONT + .2, SHELF_Y + 6.85, C_BEAM_ZS[-1] + 3.1), ADOBE, mottle=.06)
    col.box((-hx, SHELF_Y, C_BEAM_ZS[0] - 3.0), (C_WALL_FRONT, SHELF_Y + 6.85, C_BEAM_ZS[-1] + 3.0))
    for z in C_BEAM_ZS:
        base.box((C_WALL_FRONT - .5, C_BEAM_Y - C_BEAM_R - .45, z - .4), (C_WALL_FRONT, C_BEAM_Y - C_BEAM_R, z + .4), CREAM)
        base.rod_x(C_BEAM_Y, z, C_WALL_FRONT - .05, C_BEAM_TIP, C_BEAM_R, LOG)
        base.rod_x(C_BEAM_Y, z, C_BEAM_TIP - .06, C_BEAM_TIP + .02, C_BEAM_R * .9, LOGEND)
        base.rod_x(C_BEAM_Y, z, C_BEAM_TIP - 1.4, C_BEAM_TIP - .9, C_BEAM_R * 1.12, LOGEND)
        col.box((C_WALL_FRONT - .05, C_BEAM_Y - C_BEAM_R, z - C_BEAM_R), (C_BEAM_TIP, C_BEAM_Y + C_BEAM_R, z + C_BEAM_R))
    for k in range(5):
        base.rock((r.uniform(-5.6, -4.0), SHELF_Y + .2, r.choice([r.uniform(6.0, 9.0), r.uniform(29.0, 31.5)])), (r.uniform(.8, 1.5), r.uniform(.6, 1.0), r.uniform(.8, 1.5)), SANDTOP)

    d = d1
    for z in C_BEAM_ZS:
        d.box((C_WALL_FRONT - .05, C_BEAM_Y + C_BEAM_R - .02, z - .5), (C_WALL_FRONT + .02, C_BEAM_Y + C_BEAM_R + .55, z + .5), CREAM)
        d.box((C_WALL_FRONT - .6, C_BEAM_Y - C_BEAM_R - .52, z - .5), (C_WALL_FRONT - .02, C_BEAM_Y - C_BEAM_R - .45, z + .5), ADOBE)
    d.box((-hx, SHELF_Y + 6.85, C_BEAM_ZS[0] - 3.1), (C_WALL_FRONT + .22, SHELF_Y + 7.2, C_BEAM_ZS[0] - 2.8), CREAM)
    d.box((-hx, SHELF_Y + 6.85, C_BEAM_ZS[-1] + 2.8), (C_WALL_FRONT + .22, SHELF_Y + 7.2, C_BEAM_ZS[-1] + 3.1), CREAM)
    d.box((C_WALL_FRONT - .05, SHELF_Y + 6.85, C_BEAM_ZS[0] - 3.1), (C_WALL_FRONT + .22, SHELF_Y + 7.2, C_BEAM_ZS[-1] + 3.1), CREAM)
    for k in range(12):
        d.rock((r.uniform(-5.8, -4.0), SHELF_Y + .15, r.uniform(5.0, 33.0)), (r.uniform(.4, .9), r.uniform(.3, .6), r.uniform(.4, .9)), SANDTOP)
    for k in range(14):
        d.tuft((r.uniform(-5.9, -4.4), SHELF_Y + .12, r.uniform(5.0, 33.0)), r.uniform(.3, .6), SAGE)
    for k in range(12):
        d.rock((hx - r.uniform(.2, 1.0), -r.uniform(.2, 3.5), r.uniform(6.0, 30.0)), (r.uniform(.7, 1.4), r.uniform(.4, .8), r.uniform(.7, 1.4)), RED)
    d = d2
    cr = random.Random(78)
    courses_front(d, C_WALL_FRONT, C_BEAM_ZS[0] - 2.9, C_BEAM_ZS[-1] + 2.9, SHELF_Y + .02, C_BEAM_Y - C_BEAM_R - .5, cr, MASONRY, 6, 7)
    courses_front(d, C_WALL_FRONT, C_BEAM_ZS[0] - 2.9, C_BEAM_ZS[-1] + 2.9, C_BEAM_Y + C_BEAM_R + .6, SHELF_Y + 6.48, cr, MASONRY, 1, 7)
    for z in C_BEAM_ZS:
        for k in range(6):
            xk = cr.uniform(0.0, C_BEAM_TIP - 1.0)
            d.box((xk, C_BEAM_Y + C_BEAM_R - .01, z - .08), (xk + cr.uniform(.12, .3), C_BEAM_Y + C_BEAM_R + .015, z + .08), CREAM, mottle=.1)
    for k in range(40):
        x, z = r.uniform(-3.4, hx - .4), r.uniform(C_RAMP + .5, C_LEN - C_RAMP - .5)
        w = r.uniform(.12, .3)
        d.box((x, SHELF_Y, z), (x + w, SHELF_Y + .025, z + w * r.uniform(.6, 1.2)), r.choice([RED, CREAM, ADOBE]), mottle=.2)
    return "viga_pivot"


RECIPES = {
    "cliff_dwelling_row": (cliff_dwelling_row, 1101, A_LEN),
    "mesa_rim_ledge": (mesa_rim_ledge, 1102, B_LEN),
    "viga_pivot": (viga_pivot, 1103, C_LEN),
}


def check_recipe(rid, length, base, col, d1, d2):
    """Fails loud on anything the contract names."""
    lo, hi = col.bounds()
    assert abs(lo[2]) < 1e-6 and abs(hi[2] - length) < 1e-6, (rid, "collider runs z 0 to length", lo, hi)
    assert lo[1] < 0 and hi[1] > SHELF_Y, (rid, "+Y up", lo, hi)
    blo, bhi = base.bounds()
    assert blo[2] > -.05 and bhi[2] < length + .05, (rid, "render mesh stays inside the length", blo, bhi)
    for name, s, cap in (("base+col", None, LANDFORM_TRIS), ("detail1", d1, DETAIL_TRIS), ("detail2", d2, DETAIL_TRIS)):
        n = len(base.tris) + len(col.tris) if s is None else len(s.tris)
        assert 0 < n <= cap, (rid, name, n, cap)
    lane = LANE[rid]
    for t in col.tris:
        pts = [col.verts[i] for i in t]
        if not (length_zone(rid, pts)):
            continue
        xs = [p[0] for p in pts]
        ys = [p[1] for p in pts]
        if max(xs) > lane[0] + LANE_PAD and min(xs) < lane[1] and min(ys) > SHELF_Y + .02 and min(ys) < SHELF_Y + CLEAR_ABOVE and max(ys) > SHELF_Y + .02:
            raise AssertionError((rid, "solid inside the ball's lane", pts))
    assert lane[1] - lane[0] >= MIN_DEPTH, (rid, "lane at least 8 m deep", lane)


LANE = {"cliff_dwelling_row": (ROOM_FRONT + 1.5, A_W / 2), "mesa_rim_ledge": (-B_W / 2 + 1.3, B_W / 2 - 2.0), "viga_pivot": (C_WALL_FRONT, C_W / 2)}


def length_zone(rid, pts):
    return all(p[2] >= 0 for p in pts)


def gltf_metrics(path):
    data = Path(path).read_bytes()
    length = struct.unpack_from("<I", data, 12)[0]
    doc = json.loads(data[20:20 + length])
    tris = verts = draws = 0
    lo, hi = [float("inf")] * 3, [-float("inf")] * 3
    for mesh in doc["meshes"]:
        for prim in mesh["primitives"]:
            p = doc["accessors"][prim["attributes"]["POSITION"]]
            verts += p["count"]
            tris += doc["accessors"][prim["indices"]]["count"] // 3
            draws += 1
            for k in range(3):
                lo[k], hi[k] = min(lo[k], p["min"][k]), max(hi[k], p["max"][k])
    return {"triangles": tris, "vertices": verts, "primitives": draws, "materials": [m["name"] for m in doc.get("materials", [])],
            "nodes": [n["name"] for n in doc["nodes"]], "bounds": {"min": lo, "max": hi}}


def export_one(path, name, surfaces):
    common.reset()
    root = common.empty(name + "_root")
    for s in surfaces:
        s.finish(root)
    common.export(root, str(path))
    return gltf_metrics(path)


def main():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    parser = argparse.ArgumentParser()
    parser.add_argument("--out-dir", default=str(MODELS))
    parser.add_argument("--count-only", action="store_true")
    parser.add_argument("--log", default=None)
    args = parser.parse_args(argv)
    out = Path(args.out_dir)
    rows = {}
    for rid, (fn, seed, length) in RECIPES.items():
        base = Surface(rid, seed)
        col = Surface(rid + "-col", seed, colored=False)
        d1 = Surface(rid + "_detail1", seed + 100)
        d2 = Surface(rid + "_detail2", seed + 200)
        fn(base, col, d1, d2)
        check_recipe(rid, length, base, col, d1, d2)
        counts = {"base": len(base.tris), "col": len(col.tris), "detail1": len(d1.tris), "detail2": len(d2.tris)}
        print("LEDGES_COUNT", rid, json.dumps(counts, sort_keys=True))
        if args.count_only:
            continue
        rows[rid] = {"counts": counts}
        for fname, surfaces in ((rid, [base, col]), (rid + "_detail1", [d1]), (rid + "_detail2", [d2])):
            path = out / (fname + ".glb")
            m = export_one(path, fname, surfaces)
            if fname != rid:
                assert m["vertices"] <= DETAIL_VERTS, (fname, "detail class verts cap", m["vertices"], DETAIL_VERTS)
            rows[rid][fname] = {"file": path.name, "sha256": hashlib.sha256(path.read_bytes()).hexdigest(), "triangles": m["triangles"],
                                "vertices": m["vertices"], "primitives": m["primitives"], "materials": m["materials"], "nodes": m["nodes"]}
            print("LEDGES_EXPORT", fname, json.dumps(rows[rid][fname], sort_keys=True))
    if args.log and rows:
        Path(args.log).parent.mkdir(parents=True, exist_ok=True)
        Path(args.log).write_text(json.dumps(rows, indent=1, sort_keys=True) + "\n")


if __name__ == "__main__":
    main()
