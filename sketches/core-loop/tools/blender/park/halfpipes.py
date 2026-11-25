"""Headless recipe for the park's half-pipe family (design-v3/PARK.md section 4, row 1; wave 13 unit KC1).

Recipes (each writes <id>.glb, <id>_detail1.glb and <id>_detail2.glb under assets/models/park/):
  half_pipe_concrete        a dam crew's poured liner: form-board seams, panel joints, a worn coping
  slot_canyon_flow          a water-cut slot canyon, straight; _bend15 and _bend30 turn right by that many degrees
  wash_dropin_lip           the drop-in onto a wash: a deck, a concrete-capped lip, a curved drop and a run-out

Convention, the same for every piece of the family (the park_recipes.gd placement rules):
  +Y up, the ride direction +Z (the fall line), the origin at the entry lip. One datum for every piece: y 0 is the ground
  height at the origin, as the park bake leaves it. A channel (half_pipe_concrete, slot_canyon_flow and its bends) starts
  ON ITS FLOOR: the bake's wash or channel stamp lowers the terrain to that floor along the footprint, the walls rise from
  it (10 m concrete, 13 m slot) and their crests, with the rim and apron sheets, meet the surrounding terrain, so the piece
  reads as a cut into the rock and not as a wall standing on the sand. The floor falls GRADE (3 percent) along the path and
  the crest is the wall height above the floor at every point. The drop-in starts on its deck (the unstamped ground behind
  the lip, z < 0) and its floor falls DROP metres below y 0. Why the channel floor and not its rim is y 0: park_recipes.gd
  puts the ride sensor from the row's y upward only, so a ball rolling in a channel cut below y 0 would never fire its
  ride fact (measured at 3e7087d, a cut-below-y-0 build: 4 of 125 checks red, all ride_chute; the attempt is kept as
  cut_datum_attempt.patch beside the build log).
  A bend turns RIGHT (toward +X) about a circle of RADIUS_* metres; a left turn is not built (follow-up).
  Reference nodes in the base GLB: socket_entry (the origin), socket_exit (where the next piece's origin goes; its yaw is
  the bend, +Y rotation), gauge_l and gauge_r (the wall crests at the exit end: their distance is the crest-to-crest
  width, their height over socket_exit the wall height). The park row's footprint is centred on its `at`, while this
  origin is the entry lip: a row placing a piece offsets by half its length (the KD chain units know the sockets).

Nodes in the base GLB: "<id>" (the drawn mesh, material "enamel", COLOR_0 vertex colour, no texture) and "<id>-col" (the
collision trimesh park_recipes.gd turns into a ConcavePolygonShape3D; never drawn). The shells carry only a drawn mesh.
The collider is the smooth channel (no seams, grooves or props) so the 1 m ball never catches on a detail.

Palette: sandstone, cream slickrock, iron oxide, desert varnish, sage and juniper for the rock; dam-era concrete grey with
form-board joints for the liners; copper #b77843 for the survey plates and anchor caps, never brass.
Guardrail (PARK.md section 4): nothing here names or depicts a living people. The drop-in's lip and the liners are dam-era
works; the canal and cliff references live elsewhere.

  blender -b --threads 2 --python-exit-code 1 -P sketches/core-loop/tools/blender/park/halfpipes.py [-- --out-dir DIR]
      [--only ID[,ID]] [--count-only] [--grade FALL]
"""
import argparse
import hashlib
import json
import math
from pathlib import Path
import sys

import bmesh
import bpy
from mathutils import Vector

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE.parent))
sys.path.insert(0, str(HERE.parent / "dig_mechanical"))
import common
import kit

MODELS = kit.SKETCH / "assets/models/park"
LANDFORM = [8000, 24000, 2]
DETAIL = [1500, 3000, 1]
SLOT = "enamel"
GRADE = 0.03
LENGTH_CONCRETE = 60.0
LENGTH_SLOT = 48.0
RADIUS_15 = LENGTH_SLOT / math.radians(15.0)
RADIUS_30 = LENGTH_SLOT / math.radians(30.0)

HEX = {
    "sand": "c6a274", "cream": "e0cfa8", "bone": "d2c5a5", "oxide": "9b513a", "rust": "86492f", "varnish": "3b2b24",
    "sage": "7f8f66", "juniper": "4b6045", "copper": "b77843", "charcoal": "242a28", "silt": "cdb487",
    "concrete": "aaa89d", "concrete_dark": "8c8a80", "concrete_pale": "c3c1b6", "joint": "4f4d47", "efflor": "dcd8c8",
    "board": "b3b1a6",
}


def c(name):
    return common.srgb(HEX[name])


def mixc(a, b, t):
    t = max(0.0, min(1.0, t))
    return tuple(a[k] + (b[k] - a[k]) * t for k in range(3))


def shade(col, f):
    return tuple(max(0.0, min(1.0, v * f)) for v in col)


def smooth(a, b, x):
    t = max(0.0, min(1.0, (x - a) / (b - a)))
    return t * t * (3 - 2 * t)


def h01(*ints):
    n = 0x9E3779B9
    for v in ints:
        n = ((n ^ (int(v) & 0xFFFFFFFF)) * 0x85EBCA6B) & 0xFFFFFFFF
        n ^= n >> 13
        n = (n * 0xC2B2AE35) & 0xFFFFFFFF
        n ^= n >> 16
    return n / 4294967295.0


def vnoise(x, seed):
    i = math.floor(x)
    f = x - i
    f = f * f * (3 - 2 * f)
    return h01(i, seed) * (1 - f) + h01(i + 1, seed) * f


class Section:
    """The cross-section: a right-half polyline [(x, u, tag)] from (0, 0) outward (x across, u over the floor), cut grooves
    at given arc lengths, mirrored into one station list. A groove is a V of half-width w and depth d cut into the surface."""

    def __init__(self, poly, grooves=(), centre_groove=0.0, flank=0.07):
        arc = [0.0]
        for p, q in zip(poly, poly[1:]):
            arc.append(arc[-1] + math.hypot(q[0] - p[0], q[1] - p[1]))
        self.arc, self.poly = arc, poly
        right = [(a, p[0], p[1], p[2], 0.0) for a, p in zip(arc, poly)]
        cuts = list(grooves)
        if centre_groove:
            right[0] = (0.0, 0.0, 0.0, poly[0][2], centre_groove)
            cuts.append((flank, 0.0, 0.0))
        for ag, w, d in cuts:
            if d == 0.0 and w == 0.0:
                right.append((ag, None, None, self._tag(ag), 0.0))
                continue
            right = [r for r in right if not (r[4] == 0.0 and ag - w + 1e-6 < r[0] < ag + w - 1e-6)]
            for da, dd in ((-w, 0.0), (0.0, d), (w, 0.0)):
                right.append((ag + da, None, None, self._tag(ag), dd))
        right.sort(key=lambda r: r[0])
        out = []
        for a, x, u, tag, d in right:
            if x is None:
                x, u = self._at(a)
            if out and a - out[-1][0] < 1e-5:
                continue
            out.append((a, x, u, tag, d))
        self.right = out
        self.stations = self._mirror(out)

    def _seg(self, a):
        k = max(1, min(len(self.arc) - 1, next((k for k, v in enumerate(self.arc) if v >= a), len(self.arc) - 1)))
        return k

    def _tag(self, a):
        return self.poly[self._seg(a) - 1][2]

    def _at(self, a):
        k = self._seg(a)
        t = (a - self.arc[k - 1]) / max(1e-9, self.arc[k] - self.arc[k - 1])
        p, q = self.poly[k - 1], self.poly[k]
        return p[0] + (q[0] - p[0]) * t, p[1] + (q[1] - p[1]) * t

    def _normals(self, pts):
        segs = []
        for p, q in zip(pts, pts[1:]):
            dx, du = q[1] - p[1], q[2] - p[2]
            ln = math.hypot(dx, du)
            segs.append((-du / ln, dx / ln))
        out = []
        for i in range(len(pts)):
            ns = [segs[k] for k in (i - 1, i) if 0 <= k < len(segs)]
            nx, nu = sum(n[0] for n in ns), sum(n[1] for n in ns)
            ln = math.hypot(nx, nu)
            out.append((nx / ln, nu / ln))
        return out

    def _mirror(self, right):
        normals = self._normals(right)
        stations = []
        for (a, x, u, tag, d), (nx, nu) in zip(reversed(right), reversed(normals)):
            if x > 1e-9:
                stations.append((-x, u, -nx, nu, d if d else 0.0, tag, -a))
        for (a, x, u, tag, d), (nx, nu) in zip(right, normals):
            stations.append((x, u, nx, nu, d, tag, a))
        return stations


def arc_pts(cx, cu, r, a0, a1, step, tag):
    """Points on a circle of radius r about (cx, cu), from angle a0 to a1 degrees (0 = +x, 90 = +u), excluding a0."""
    n = max(1, round(abs(a1 - a0) / step))
    return [(cx + r * math.cos(math.radians(a0 + (a1 - a0) * k / n)), cu + r * math.sin(math.radians(a0 + (a1 - a0) * k / n)), tag)
            for k in range(1, n + 1)]


class Grid:
    """Rows along the path by stations across the section, in Godot space. verts[j][i] is (x, y, z)."""

    def __init__(self, section, rows, path, floor, warp=None, clip=None):
        self.section, self.rows, self.path, self.floor = section, rows, path, floor
        self.n = len(section.stations)
        self.verts, self.frames, self.us = [], [], []
        for s, zd in rows:
            cx, cz, t = path(s)
            fy = floor(s)
            lat = (math.cos(t), -math.sin(t))
            st = section.stations
            xs = [q[0] for q in st]
            us = [q[1] for q in st]
            if clip is not None:
                xs, us = clip(s, xs, us)
            row = []
            for i, q in enumerate(st):
                depth = max(q[4], zd)
                x = xs[i] - q[2] * depth
                u = us[i] - q[3] * depth
                if warp is not None:
                    x, u = warp(i, q, x, u, s)
                row.append((cx + lat[0] * x, fy + u, cz + lat[1] * x))
            self.verts.append(row)
            self.frames.append((cx, cz, t, fy, lat))
        self.normals = self._normals()

    def _normals(self):
        out = []
        rows = len(self.verts)
        for j in range(rows):
            row = []
            for i in range(self.n):
                a = Vector(self.verts[j][min(i + 1, self.n - 1)]) - Vector(self.verts[j][max(i - 1, 0)])
                b = Vector(self.verts[min(j + 1, rows - 1)][i]) - Vector(self.verts[max(j - 1, 0)][i])
                nrm = b.cross(a)
                row.append(nrm.normalized() if nrm.length > 1e-9 else Vector((0, 1, 0)))
            out.append(row)
        return out

    def faces(self):
        n = self.n
        return [(j * n + i, (j + 1) * n + i, (j + 1) * n + i + 1, j * n + i + 1)
                for j in range(len(self.verts) - 1) for i in range(n - 1)]

    def flat(self):
        return [v for row in self.verts for v in row]

    def lifted(self, j, i, lift):
        v = Vector(self.verts[j][i]) + self.normals[j][i] * lift
        return tuple(v)


class Mesh:
    """Vertices, faces and per-vertex colours collected in Godot space, then made one Blender object."""

    def __init__(self, name, smooth_shading, with_colour=True):
        self.name, self.smooth, self.with_colour = name, smooth_shading, with_colour
        self.verts, self.faces, self.colors = [], [], []

    def add(self, verts, faces, colors=None, color=None):
        off = len(self.verts)
        self.verts.extend(verts)
        self.faces.extend(tuple(off + k for k in f) for f in faces)
        self.colors.extend(colors if colors is not None else [color or c("sand")] * len(verts))

    def grid(self, grid, color_fn):
        cols = []
        for j, row in enumerate(grid.verts):
            for i in range(grid.n):
                cols.append(color_fn(j, i))
        self.add(grid.flat(), grid.faces(), colors=cols)

    def patch(self, grid, j0, j1, i0, i1, lift, color_fn):
        """The cells j0..j1 by i0..i1 of the grid, lifted off its surface: a painted overlay that follows every groove."""
        verts, cols, idx = [], [], {}
        for j in range(j0, j1 + 1):
            for i in range(i0, i1 + 1):
                idx[(j, i)] = len(verts)
                verts.append(grid.lifted(j, i, lift))
                cols.append(color_fn(j, i))
        faces = [(idx[(j, i)], idx[(j + 1, i)], idx[(j + 1, i + 1)], idx[(j, i + 1)])
                 for j in range(j0, j1) for i in range(i0, i1)]
        self.add(verts, faces, colors=cols)

    def box(self, center, size, yaw, color, tilt=0.0):
        """A box at center (Godot space), turned by yaw about +Y: for coping blocks, slabs and stones."""
        hx, hy, hz = size[0] / 2, size[1] / 2, size[2] / 2
        cs, sn = math.cos(yaw), math.sin(yaw)
        pts = []
        for sx, sy, sz in [(-1, -1, -1), (1, -1, -1), (1, 1, -1), (-1, 1, -1), (-1, -1, 1), (1, -1, 1), (1, 1, 1), (-1, 1, 1)]:
            x, y, z = sx * hx, sy * hy + tilt * sx * hx, sz * hz
            pts.append((center[0] + x * cs + z * sn, center[1] + y, center[2] - x * sn + z * cs))
        self.add(pts, [(0, 3, 2, 1), (4, 5, 6, 7), (0, 1, 5, 4), (3, 7, 6, 2), (0, 4, 7, 3), (1, 2, 6, 5)], color=color)

    def lump(self, center, size, seed, color, tint=0.12):
        """A rough stone: an eight-corner block with every corner pulled by a hash, two tones by face height."""
        pts = []
        for k, (sx, sy, sz) in enumerate([(-1, -1, -1), (1, -1, -1), (1, 1, -1), (-1, 1, -1), (-1, -1, 1), (1, -1, 1), (1, 1, 1), (-1, 1, 1)]):
            j = [0.55 + 0.45 * h01(seed, k, a) for a in range(3)]
            top = sy > 0
            pts.append((center[0] + sx * size[0] / 2 * j[0] * (0.8 if top else 1.0), center[1] + (sy * size[1] / 2 * j[1] if top else -size[1] * 0.25),
                        center[2] + sz * size[2] / 2 * j[2] * (0.8 if top else 1.0)))
        cols = [shade(color, 1.0 + (tint if p[1] > center[1] else -tint)) for p in pts]
        self.add(pts, [(0, 3, 2, 1), (4, 5, 6, 7), (0, 1, 5, 4), (3, 7, 6, 2), (0, 4, 7, 3), (1, 2, 6, 5)], colors=cols)

    def prism(self, base, axis, r0, r1, sides, color, spin=0.0):
        """A frustum from base along axis (a vector whose length is the height), r0 at the base and r1 at the top."""
        a = Vector(axis)
        ln = a.length
        a = a / ln
        e1 = a.cross(Vector((0, 1, 0)) if abs(a.y) < 0.9 else Vector((1, 0, 0))).normalized()
        e2 = a.cross(e1)
        pts = []
        for r, h in ((r0, 0.0), (r1, ln)):
            for k in range(sides):
                t = spin + math.tau * k / sides
                pts.append(tuple(Vector(base) + a * h + (e1 * math.cos(t) + e2 * math.sin(t)) * r))
        faces = [(k, (k + 1) % sides, sides + (k + 1) % sides, sides + k) for k in range(sides)]
        faces.append(tuple(range(sides, 2 * sides)))
        cols = [shade(color, 0.85)] * sides + [shade(color, 1.1)] * sides
        self.add(pts, faces, colors=cols)

    def tuft(self, base, height, blades, seed, color):
        """A desert shrub: blades as thin leaning triangles about base, darker at the root."""
        for k in range(blades):
            t = math.tau * (k + h01(seed, k) * 0.6) / blades
            lean = 0.25 + 0.35 * h01(seed, k, 9)
            hgt = height * (0.7 + 0.5 * h01(seed, k, 3))
            w = height * 0.16
            tip = (base[0] + math.cos(t) * hgt * lean, base[1] + hgt, base[2] + math.sin(t) * hgt * lean)
            l0 = (base[0] - math.sin(t) * w, base[1], base[2] + math.cos(t) * w)
            l1 = (base[0] + math.sin(t) * w, base[1], base[2] - math.cos(t) * w)
            self.add([l0, l1, tip], [(0, 2, 1), (0, 1, 2)], colors=[shade(color, 0.7), shade(color, 0.7), shade(color, 1.15)])

    def to_object(self, root, material=True):
        mesh = bpy.data.meshes.new(self.name)
        mesh.from_pydata([kit.xyz(v) for v in self.verts], [], self.faces)
        mesh.update()
        if self.with_colour:
            attr = mesh.color_attributes.new(name="Color", type="FLOAT_COLOR", domain="CORNER")
            for poly in mesh.polygons:
                for li in poly.loop_indices:
                    attr.data[li].color = common.rgba(self.colors[mesh.loops[li].vertex_index])
            mesh.color_attributes.active_color = attr
        for poly in mesh.polygons:
            poly.use_smooth = self.smooth
        if material:
            mesh.materials.append(kit.material(SLOT))
        obj = bpy.data.objects.new(self.name, mesh)
        bpy.context.scene.collection.objects.link(obj)
        obj.parent = root
        tri = obj.modifiers.new("FixedTriangles", "TRIANGULATE")
        tri.quad_method = "FIXED"
        bpy.context.view_layer.objects.active = obj
        bpy.ops.object.modifier_apply(modifier=tri.name)
        return obj


def straight(s):
    return 0.0, s, 0.0


def arc_path(radius):
    def path(s):
        t = s / radius
        return radius * (1 - math.cos(t)), radius * math.sin(t), t
    return path


def fall(s):
    return -GRADE * s


class Recipe:
    """One recipe id: its base grid (drawn), collision grid, exit pose, gauge crests, colour rules and shell props."""
    id = ""
    smooth_render = False
    bend = 0.0

    def build(self):
        raise NotImplementedError

    def sockets(self):
        s_end = self.length
        cx, cz, t = self.path(s_end)
        fy = self.floor(s_end)
        crest = self.crest
        lat = (math.cos(t), -math.sin(t))
        return {
            "socket_entry": ((0.0, 0.0, 0.0), 0.0),
            "socket_exit": ((cx, fy, cz), t),
            "gauge_l": ((cx - lat[0] * crest[0], fy + crest[1], cz - lat[1] * crest[0]), 0.0),
            "gauge_r": ((cx + lat[0] * crest[0], fy + crest[1], cz + lat[1] * crest[0]), 0.0),
        }

    warp_col = None
    clip = None


def row_list(length, joints=(), flank=0.07, step=None, extra=()):
    """Rows 0..length: every `step` metres, three lines per joint (a V groove), plus the extra lines."""
    s = set([0.0, float(length)])
    if step:
        k = 0.0
        while k < length - 1e-6:
            s.add(round(k, 4))
            k += step
    out = {}
    for v in sorted(s | set(round(e, 4) for e in extra)):
        out[round(v, 4)] = 0.0
    for j in joints:
        out[round(j - flank, 4)] = 0.0
        out[round(j, 4)] = 0.05
        out[round(j + flank, 4)] = 0.0
    return sorted(out.items())


class Concrete(Recipe):
    id = "half_pipe_concrete"
    length = LENGTH_CONCRETE
    F, R, H, BATTER = 6.0, 6.0, 10.0, 0.08
    path = staticmethod(straight)
    floor = staticmethod(fall)

    def __init__(self):
        f, r, h, b = self.F, self.R, self.H, self.BATTER
        poly = [(0.0, 0.0, "floor"), (2.0, 0.0, "floor"), (4.0, 0.0, "floor"), (f, 0.0, "floor")]
        poly += arc_pts(f, r, r, -90, 0, 10, "arc")
        xw = f + r
        top = (xw + (h - r) * b, h, "wall")
        poly += [(xw + 2.0 * b, r + 2.0, "wall"), (xw + 3.0 * b, r + 3.0, "wall"), top]
        xc = top[0]
        self.crest = (xc, h)
        poly += [(xc + 0.04, h + 0.12, "coping"), (xc + 0.34, h + 0.15, "coping"), (xc + 0.58, h + 0.12, "coping"),
                 (xc + 0.60, h, "apron"), (xc + 5.0, h, "apron")]
        arc_total = [0.0]
        for p, q in zip(poly, poly[1:]):
            arc_total.append(arc_total[-1] + math.hypot(q[0] - p[0], q[1] - p[1]))
        a_floor_end = arc_total[3]
        grooves = [(a_floor_end + 1.6 * k, 0.07, 0.05) for k in range(1, 9)]
        self.section = Section(poly, grooves, centre_groove=0.05)
        joints = [6.0 * k for k in range(1, 10)]
        self.rows = row_list(self.length, joints)
        cpoly = [(0.0, 0.0, "floor"), (f, 0.0, "floor")] + arc_pts(f, r, r, -90, 0, 15, "arc")
        cpoly += [top, (xc + 0.6, h, "apron"), (xc + 4.0, h, "apron")]
        self.col_section = Section(cpoly)
        self.col_rows = [(s, 0.0) for s in [0.0, 10.0, 20.0, 30.0, 40.0, 50.0, 60.0]]

    def warp(self, i, q, x, u, s):
        if q[5] == "coping":
            wear = (vnoise(s * 0.9, 5) - 0.5) * 0.07
            return x, u + wear
        return x, u

    def colour(self, grid):
        sec = self.section
        rows = self.rows

        def panel(j):
            s = rows[j][0]
            return int(min(9, s // 6.0))

        def fn(j, i):
            st = sec.stations[i]
            tag = st[5]
            x, u = abs(st[0]), st[1]
            s, zd = rows[j]
            p = panel(j)
            base = mixc(c("concrete"), c("concrete_pale"), h01(p, 3, 1) * 0.35)
            base = mixc(base, c("concrete_dark"), h01(p, 7, 2) * 0.3)
            course = int(max(0.0, abs(st[6]) - 6.0) // 1.6)
            base = shade(base, 0.94 + 0.11 * h01(p, course, 4))
            depth = max(st[4], zd)
            if depth > 0.0:
                base = mixc(base, c("joint"), 0.78)
            if tag in ("wall", "arc"):
                streak = h01(int(s * 0.7), 11, int(st[0] > 0))
                if u > 5.0 and streak > 0.72:
                    base = mixc(base, c("efflor"), 0.55 * smooth(5.0, 9.5, u))
                if streak < 0.12:
                    base = mixc(base, c("rust"), 0.32)
            fill = smooth(1.4, 0.0, u) * (0.55 + 0.4 * vnoise(s * 0.18 + x * 0.3, 8))
            if tag in ("floor", "arc"):
                base = mixc(base, c("silt"), fill * (0.5 + 0.4 * smooth(10.0, 55.0, s)))
                if tag == "floor" and x < 1.4:
                    base = shade(base, 0.93)
            if tag == "coping":
                base = mixc(base, c("concrete_pale"), 0.55)
                if h01(int(s * 1.7), 21, int(st[0] > 0)) > 0.78:
                    base = shade(base, 0.8)
            if tag == "apron":
                base = mixc(c("sand"), c("silt"), 0.5 + 0.3 * vnoise(s * 0.2, 4))
            return shade(base, 0.78 + 0.22 * smooth(0.0, 9.0, u))
        return fn


SLOT_POLY = [(0.0, 0.0), (1.3, 0.02), (2.6, 0.08), (3.7, 0.45), (4.6, 1.2), (5.35, 2.3), (5.95, 3.6), (6.4, 5.0), (6.7, 6.5),
             (6.85, 8.0), (6.85, 9.4), (6.7, 10.7), (6.55, 11.8), (6.75, 12.55), (7.2, 12.92), (7.5, 13.0), (8.6, 13.0),
             (10.5, 12.85), (13.0, 12.6)]
SLOT_TAGS = ["floor", "floor", "floor", "arc", "arc", "arc", "wall", "wall", "wall", "wall", "wall", "wall", "wall", "coping",
             "coping", "coping", "apron", "apron", "apron"]
STRATA = [(1.7, "sand"), (0.8, "oxide"), (2.6, "cream"), (1.1, "sand"), (0.6, "rust"), (2.1, "bone"), (1.4, "sand"), (0.9, "oxide")]


class Slot(Recipe):
    smooth_render = True
    length = LENGTH_SLOT
    HALF_CREST = 7.5
    WALL = 13.0
    FLUTES = 4

    def __init__(self, id, bend_deg):
        self.id = id
        self.bend = bend_deg
        self.crest = (self.HALF_CREST, self.WALL)
        self.floor = fall
        self.path = straight if bend_deg == 0.0 else arc_path(self.length / math.radians(bend_deg))
        poly = [(x, u, SLOT_TAGS[k]) for k, (x, u) in enumerate(SLOT_POLY)]
        dense = [poly[0]]
        for p, q in zip(poly, poly[1:]):
            n = max(1, int(math.hypot(q[0] - p[0], q[1] - p[1]) / 0.5))
            for k in range(1, n + 1):
                t = k / n
                dense.append((p[0] + (q[0] - p[0]) * t, p[1] + (q[1] - p[1]) * t, q[2] if k == n else p[2]))
        self.section = Section(dense)
        self.rows = [(round(k * 1.2, 4), 0.0) for k in range(int(self.length / 1.2) + 1)]
        if self.rows[-1][0] != self.length:
            self.rows.append((self.length, 0.0))
        cpoly = [(x, u, SLOT_TAGS[k]) for k, (x, u) in enumerate(SLOT_POLY)]
        self.col_section = Section(cpoly)
        self.col_rows = [(round(k * 3.0, 4), 0.0) for k in range(int(self.length / 3.0) + 1)]
        if self.col_rows[-1][0] != self.length:
            self.col_rows.append((self.length, 0.0))

    def flute(self, x, u, s):
        """Lateral wave of the walls, zero at the floor and at the crest, whole periods over the piece."""
        bell = math.sin(math.pi * smooth(0.6, 11.8, u)) ** 2 * (1.0 if u < 12.0 else 0.0)
        side = 1.0 if x > 0 else -1.0
        k = math.tau * self.FLUTES / self.length
        wave = 0.42 * math.sin(k * s + (0.6 if side > 0 else 2.1) + 0.55 * u) + 0.22 * math.sin(2 * k * s + 1.3 * side + 0.9 * u)
        return side * bell * wave

    def warp(self, i, q, x, u, s):
        if abs(x) < 3.2:
            ripple = 0.10 * math.sin(math.tau * 3 * s / self.length + 0.4) * smooth(3.2, 0.5, abs(x))
            return x, u + ripple
        return x + self.flute(x, u, s), u

    def warp_col(self, i, q, x, u, s):
        return self.warp(i, q, x, u, s)

    def colour(self, grid):
        sec = self.section
        rows = self.rows

        def fn(j, i):
            st = sec.stations[i]
            x, u, tag = st[0], st[1], st[5]
            s = rows[j][0]
            band = u + 0.35 * math.sin(0.21 * s + (1.0 if x > 0 else 0.0)) + 0.5 * math.sin(0.043 * s * 3 + x * 0.1)
            band = band % sum(b[0] for b in STRATA)
            acc = 0.0
            col = c("sand")
            for thick, name in STRATA:
                acc += thick
                if band < acc:
                    col = c(name)
                    break
            col = shade(col, 0.92 + 0.14 * vnoise(u * 0.9 + s * 0.05, 3))
            streak = vnoise(s * 0.55 + (3.0 if x > 0 else 0.0), 13)
            if u > 3.0 and streak > 0.66:
                col = mixc(col, c("varnish"), 0.55 * smooth(3.0, 9.0, u) * smooth(0.66, 0.85, streak))
            if tag in ("floor",) or (tag == "arc" and u < 1.0):
                col = mixc(col, c("silt"), 0.75 * smooth(1.6, 0.0, u))
                if abs(x) < 1.6:
                    col = shade(col, 0.95)
            if tag == "apron":
                col = mixc(c("cream"), c("sand"), 0.5 + 0.5 * vnoise(s * 0.3 + x * 0.2, 2))
            if tag == "coping":
                col = mixc(col, c("cream"), 0.4)
            return shade(col, 0.55 + 0.45 * smooth(0.0, 11.0, u))
        return fn


class Dropin(Recipe):
    id = "wash_dropin_lip"
    smooth_render = True
    length = 60.0
    DROP = 8.0
    ANGLE = 50.0
    DECK = 12.0
    F, R = 5.0, 5.0
    BATTER = 0.08
    path = staticmethod(straight)

    def __init__(self):
        d = self.DROP
        self.radius = d / (1 - math.cos(math.radians(self.ANGLE)))
        self.zd = self.radius * math.sin(math.radians(self.ANGLE))
        f, r, b = self.F, self.R, self.BATTER
        poly = [(0.0, 0.0, "floor"), (2.5, 0.0, "floor"), (f, 0.0, "floor")] + arc_pts(f, r, r, -90, 0, 10, "arc")
        xw = f + r
        top = (xw + (d - r) * b, d, "wall")
        poly += [(xw + 1.5 * b, r + 1.5, "wall"), top]
        self.crest = (top[0], d)
        poly += [(top[0] + 0.5, d, "apron"), (top[0] + 5.5, d, "apron")]
        self.poly = poly
        self.section = Section(poly)
        self.col_section = Section([p for k, p in enumerate(poly) if k % 1 == 0])
        extra = []
        deck = [(-self.DECK + 2.0 * k) for k in range(int(self.DECK / 2.0))]
        arcs = [0.9 * k for k in range(0, int(self.zd / 0.9) + 1) if self.zd - 0.9 * k > 0.3] + [self.zd]
        run = [self.zd + 3.0 * k for k in range(1, int((self.length - self.zd) / 3.0) + 1)] + [self.length]
        ss = sorted(set(round(v, 4) for v in deck + arcs + run if v <= self.length))
        self.rows = [(s, 0.0) for s in ss]
        self.col_rows = [(s, 0.0) for s in sorted(set(round(v, 4) for v in [-self.DECK] + [-4.0, 0.0] + [1.8 * k for k in range(1, int(self.zd / 1.8) + 1)] + [self.zd] + [self.zd + 6.0 * k for k in range(1, int((self.length - self.zd) / 6.0) + 1)] + [self.length]))]

    def floor(self, s):
        if s <= 0.0:
            return 0.0
        if s >= self.zd:
            return -self.DROP - GRADE * (s - self.zd)
        rr = self.radius
        return (-self.DROP + rr) - math.sqrt(rr * rr - (s - self.zd) ** 2)

    def clip(self, s, xs, us):
        """The wash cut into the ground: wall height over the floor is limited to the ground's level (y 0 on the deck, then
        the floor plus the wall height). Stations above that level lie flat on it, the first one moved to the crease."""
        cap = min(0.0, self.floor(s) + self.DROP) if s > 0 else 0.0
        h = cap - self.floor(s)
        out_x, out_u = list(xs), list(us)
        n = len(xs)
        mid = n // 2
        for side in (1, -1):
            idx = range(mid, n) if side == 1 else range(mid, -1, -1)
            prev = None
            for i in idx:
                if us[i] > h + 1e-9:
                    if prev is not None and us[prev] < h - 1e-9:
                        t = (h - us[prev]) / (us[i] - us[prev])
                        if t > 0.2:
                            out_x[i] = xs[prev] + (xs[i] - xs[prev]) * t
                    out_u[i] = h
                prev = i
        return out_x, out_u

    def warp(self, i, q, x, u, s):
        return x, u

    def colour(self, grid):
        sec = self.section
        rows = self.rows

        def fn(j, i):
            st = sec.stations[i]
            x, u, tag = st[0], st[1], st[5]
            s = rows[j][0]
            fy = grid.frames[j][3]
            yy = fy + u
            band = (yy * 1.1 + 0.4 * math.sin(0.3 * s + (1 if x > 0 else 0))) % 7.0
            col = c("sand")
            acc = 0.0
            for thick, name in ((2.0, "sand"), (0.9, "oxide"), (2.4, "cream"), (1.7, "sand")):
                acc += thick
                if band < acc:
                    col = c(name)
                    break
            col = shade(col, 0.92 + 0.14 * vnoise(yy * 0.8 + s * 0.06, 6))
            if tag == "floor" or (tag == "arc" and u < 1.2):
                col = mixc(col, c("silt"), 0.8 * smooth(1.5, 0.0, u))
            if tag == "apron" or yy > -0.001 and s <= 0.5:
                col = mixc(c("cream"), c("sand"), 0.5 + 0.4 * vnoise(s * 0.25 + x * 0.2, 7))
            y_world = grid.verts[j][i][1]
            if s <= 0.001 or y_world > -0.5:
                w = smooth(-2.0, -0.3, s) if s <= 0.0 else smooth(1.8, 0.9, s)
                col = mixc(col, c("concrete"), 0.92 * w)
            streak = vnoise(s * 0.5 + (4.0 if x > 0 else 0.0), 17)
            if u > 2.5 and streak > 0.68 and s > 6.0:
                col = mixc(col, c("varnish"), 0.5 * smooth(2.5, 7.0, u))
            return shade(col, 0.62 + 0.38 * smooth(0.0, 7.0, u) if s > 0 else 1.0)
        return fn


RECIPES = {}


def recipes():
    if not RECIPES:
        for r in (Concrete(), Slot("slot_canyon_flow", 0.0), Slot("slot_canyon_flow_bend15", 15.0),
                  Slot("slot_canyon_flow_bend30", 30.0), Dropin()):
            RECIPES[r.id] = r
    return RECIPES


def grid_of(r):
    return Grid(r.section, r.rows, r.path, r.floor, getattr(r, "warp", None), getattr(r, "clip", None))


def col_grid_of(r):
    return Grid(r.col_section, r.col_rows, r.path, r.floor, getattr(r, "warp_col", None), getattr(r, "clip", None))


def base_meshes(r):
    g = grid_of(r)
    m = Mesh(r.id, r.smooth_render)
    m.grid(g, r.colour(g))
    cg = col_grid_of(r)
    col = Mesh(r.id + "-col", False, with_colour=False)
    col.add(cg.flat(), cg.faces(), colors=[(0, 0, 0)] * (cg.n * len(cg.verts)))
    return g, m, cg, col


def surface_sample(r, grid, x, s):
    """The base surface at lateral x and path s, by the grid's nearest row pair and station pair (props stand on it)."""
    rows = [q[0] for q in r.rows]
    j = max(0, min(len(rows) - 2, next((k for k, v in enumerate(rows) if v > s), len(rows) - 1) - 1))
    tj = (s - rows[j]) / max(1e-9, rows[j + 1] - rows[j])
    st = r.section.stations
    best = None
    for jj, w in ((j, 1.0 - tj), (j + 1, tj)):
        row = grid.verts[jj]
        lat = grid.frames[jj][4]
        cx, cz = grid.frames[jj][0], grid.frames[jj][1]
        xs = [(row[i][0] - cx) * lat[0] + (row[i][2] - cz) * lat[1] for i in range(grid.n)]
        for i in range(grid.n - 1):
            if xs[i] <= x <= xs[i + 1] and xs[i + 1] - xs[i] > 1e-6:
                t = (x - xs[i]) / (xs[i + 1] - xs[i])
                y = row[i][1] + (row[i + 1][1] - row[i][1]) * t
                nrm = (grid.normals[jj][i] * (1 - t) + grid.normals[jj][i + 1] * t).normalized()
                px = row[i][0] + (row[i + 1][0] - row[i][0]) * t
                pz = row[i][2] + (row[i + 1][2] - row[i][2]) * t
                if best is None:
                    best = [0.0, 0.0, 0.0, 0.0, Vector((0, 0, 0)), 0.0]
                best[0] += w * px
                best[1] += w * y
                best[2] += w * pz
                best[4] += w * nrm
                best[5] += w
                break
    if best is None or best[5] <= 0:
        return None
    return Vector((best[0] / best[5], best[1] / best[5], best[2] / best[5])), best[4].normalized()


def lift_pt(p, n, h):
    return tuple(p + n * h)


def stations_between(r, x0, x1):
    xs = [q[0] for q in r.section.stations]
    return [i for i, x in enumerate(xs) if x0 - 1e-6 <= x <= x1 + 1e-6]


def feather(base_fn, tint, strength, j0, j1, i0, i1):
    """A patch colour that is the base colour on the patch's rim and mixes toward tint inside, so no edge shows."""
    def fn(j, i):
        w = min(1.0, float(min(j - j0, j1 - j, i - i0, i1 - i))) * strength
        return mixc(base_fn(j, i), tint, w)
    return fn


def paint(m, g, base_fn, j0, j1, i0, i1, tint, strength, lift):
    j0, j1 = max(0, j0), min(len(g.verts) - 1, j1)
    i0, i1 = max(0, i0), min(g.n - 1, i1)
    if j1 - j0 >= 2 and i1 - i0 >= 2:
        m.patch(g, j0, j1, i0, i1, lift, feather(base_fn, tint, strength, j0, j1, i0, i1))


def shell_concrete(r, g, which):
    m = Mesh("%s_detail%d" % (r.id, which), False)
    base = r.colour(g)
    sec = r.section
    st = sec.stations
    rows = r.rows
    crest_x = r.crest[0]
    if which == 1:
        for side in (-1, 1):
            for p in range(10):
                s0, s1 = 6.0 * p + 0.25, 6.0 * p + 5.75
                hgt = 0.07 + 0.04 * h01(p, side, 1)
                smp = surface_sample(r, g, side * (crest_x + 0.34), (s0 + s1) / 2)
                if smp is None:
                    continue
                pos, _ = smp
                m.box((pos.x, pos.y + hgt / 2 - 0.02, pos.z), (0.42, hgt, s1 - s0), 0.0, shade(c("concrete_pale"), 0.95 + 0.1 * h01(p, side, 2)))
                if h01(p, side, 3) > 0.55:
                    m.box((pos.x + side * 0.1, pos.y + hgt + 0.02, pos.z + (h01(p, side, 4) - 0.5) * 3.0), (0.3, 0.05, 0.5), 0.0, c("concrete_dark"))
        jn = len(rows)
        for side in (-1, 1):
            for k in range(9):
                s_at = 2.0 + 6.4 * k + 1.7 * h01(k, side, 7)
                j0 = min(jn - 2, next((q for q, v in enumerate(rows) if v[0] >= s_at), jn - 2))
                j1 = j0 + 3
                ids = [i for i, q in enumerate(st) if q[0] * side > 0 and 6.0 <= q[1] <= 9.9]
                if len(ids) < 6:
                    continue
                i0 = ids[0] + (k % 3)
                i1 = min(ids[-1], i0 + 5 + (k % 2))
                tint = c("efflor") if k % 3 else c("rust")
                paint(m, g, base, j0, j1, i0, i1, tint, 0.55, 0.015)
        for side in (-1, 1):
            for k in range(9):
                s_at = 3.0 + 6.0 * k + 2.0 * h01(k, side, 8)
                smp = surface_sample(r, g, side * (r.F + 0.9 + 0.5 * h01(k, side, 9)), s_at)
                if smp is None:
                    continue
                pos, nrm = smp
                m.lump((pos.x, pos.y + 0.08, pos.z), (1.6 + h01(k, side) * 1.4, 0.25, 2.4 + h01(k, side, 3) * 1.5), k * 3 + side + 40, mixc(c("silt"), c("concrete_dark"), 0.45), 0.04)
    else:
        for side in (-1, 1):
            for p in range(10):
                smp = surface_sample(r, g, side * (crest_x + 0.34), 6.0 * p + 3.0)
                if smp is None:
                    continue
                pos, _ = smp
                for dz in (-1.8, 1.8):
                    m.prism((pos.x, pos.y + 0.05, pos.z + dz), (0, 0.08, 0), 0.07, 0.06, 6, c("copper"))
            for p in range(5):
                smp = surface_sample(r, g, side * (r.F + r.R * 0.97), 5.0 + 11.0 * p)
                if smp is None:
                    continue
                pos, nrm = smp
                m.prism(tuple(pos + nrm * 0.0), tuple(nrm * 0.22), 0.1, 0.1, 6, c("joint"))
                m.prism(tuple(pos + nrm * 0.22), tuple(nrm * 0.02), 0.06, 0.06, 6, c("rust"))
            for tick in range(7):
                u_at = r.R + 0.4 + tick * 0.5
                xw = r.F + r.R + max(0.0, u_at - r.R) * r.BATTER
                smp = surface_sample(r, g, side * xw, 47.2)
                if smp is None:
                    continue
                pos, nrm = smp
                m.box(tuple(pos + nrm * 0.02), (0.02, 0.07, 0.5 if tick % 2 == 0 else 0.3), 0.0, c("oxide"))
        for p in range(10):
            if h01(p, 5, 6) < 0.45:
                continue
            x0 = -3.0 + 6.0 * h01(p, 5, 7)
            s0 = 6.0 * p + 1.0 + 2.5 * h01(p, 5, 8)
            pts = []
            for k in range(6):
                smp = surface_sample(r, g, x0 + k * 0.7 + 0.3 * math.sin(k + p), s0 + k * 0.5 + 0.2 * math.cos(k * 2 + p))
                if smp is not None:
                    pts.append(smp)
            for a, b in zip(pts, pts[1:]):
                pa, pb = a[0] + a[1] * 0.012, b[0] + b[1] * 0.012
                d = (pb - pa)
                w = Vector((d.z, 0, -d.x)).normalized() * 0.03 if (d.x or d.z) else Vector((0.03, 0, 0))
                m.add([tuple(pa - w), tuple(pa + w), tuple(pb + w), tuple(pb - w)], [(0, 3, 2, 1)], color=c("joint"))
        for k in range(12):
            smp = surface_sample(r, g, -4.5 + 9.0 * h01(k, 3, 3), 2.0 + 56.0 * h01(k, 4, 4))
            if smp is None:
                continue
            pos, _ = smp
            m.lump((pos.x, pos.y + 0.03, pos.z), (0.22, 0.14, 0.22), 100 + k, shade(c("concrete_dark"), 0.9 + 0.2 * h01(k, 9)), 0.1)
    return m


def shell_slot(r, g, which):
    m = Mesh("%s_detail%d" % (r.id, which), True)
    base = r.colour(g)
    sec = r.section
    st = sec.stations
    rows = r.rows
    crest = r.HALF_CREST
    if which == 1:
        for k in range(16):
            side = 1 if k % 2 else -1
            s_at = 1.5 + 3.0 * k
            xx = side * (3.5 + 2.0 * h01(k, 1, 1))
            smp = surface_sample(r, g, xx, s_at)
            if smp is None:
                continue
            pos, nrm = smp
            sz = 0.7 + 1.1 * h01(k, 2, 2)
            m.lump((pos.x, pos.y + sz * 0.28, pos.z), (sz * 1.3, sz, sz * 1.1), 200 + k, shade(mixc(c("sand"), c("oxide"), 0.12 + 0.3 * h01(k, 5)), 0.8), 0.12)
        for k in range(8):
            smp = surface_sample(r, g, -1.4 + 2.8 * h01(k, 8, 8), 3.0 + 5.8 * k)
            if smp is None:
                continue
            pos, _ = smp
            m.lump((pos.x, pos.y + 0.06, pos.z), (2.4, 0.3, 3.4), 300 + k, mixc(c("silt"), c("varnish"), 0.35), 0.03)
        for side in (-1, 1):
            for k in range(8):
                s_at = 2.0 + 6.0 * k + 2.0 * h01(k, side, 3)
                smp = surface_sample(r, g, side * (crest + 2.0 + 2.5 * h01(k, side, 4)), s_at)
                if smp is None:
                    continue
                pos, _ = smp
                m.tuft((pos.x, pos.y, pos.z), 0.9 + 0.7 * h01(k, side, 5), 5, 400 + k + side * 7, c("sage") if k % 3 else c("juniper"))
        jn = len(rows)
        for side in (-1, 1):
            ids = [i for i, q in enumerate(st) if q[0] * side > 0 and 1.0 <= q[1] <= 6.0]
            if len(ids) >= 6:
                for k in range(0, jn - 5, 5):
                    j0 = k + int(2 * h01(k, side, 6))
                    i0 = ids[0] + (k // 5) % 2
                    paint(m, g, base, j0, j0 + 4, i0, min(ids[-1], i0 + 6), c("cream"), 0.45, 0.02)
    else:
        for k in range(34):
            smp = surface_sample(r, g, -2.3 + 4.6 * h01(k, 12, 1), 1.0 + 46.0 * h01(k, 13, 2))
            if smp is None:
                continue
            pos, _ = smp
            m.lump((pos.x, pos.y + 0.05, pos.z), (0.25 + 0.15 * h01(k, 1), 0.16, 0.22), 500 + k, mixc(c("bone"), c("oxide"), h01(k, 3) * 0.6), 0.1)
        for k in range(10):
            side = 1 if k % 2 else -1
            smp = surface_sample(r, g, side * (3.0 + 0.9 * h01(k, 14, 1)), 2.0 + 4.6 * k)
            if smp is None:
                continue
            pos, _ = smp
            yaw = 0.5 + 2.0 * h01(k, 15, 2)
            m.box((pos.x, pos.y + 0.1, pos.z), (0.07, 0.07, 1.1 + 0.8 * h01(k, 16, 3)), yaw, c("varnish") if k % 2 else c("rust"))
        jn = len(rows)
        for side in (-1, 1):
            ids = [i for i, q in enumerate(st) if q[0] * side > 0 and 7.0 <= q[1] <= 11.5]
            if len(ids) >= 6:
                for k in range(0, jn - 5, 4):
                    if h01(k, side, 21) < 0.4:
                        continue
                    paint(m, g, base, k, k + 4, ids[0] + (k % 2), min(ids[-1], ids[0] + 7), c("varnish"), 0.5, 0.02)
        for side in (-1, 1):
            for k in range(7):
                smp = surface_sample(r, g, side * (crest + 3.0 + 2.5 * h01(k, side, 17)), 3.0 + 7.0 * k)
                if smp is None:
                    continue
                pos, _ = smp
                m.lump((pos.x, pos.y + 0.12, pos.z), (0.6, 0.32, 0.5), 600 + k + side * 9, c("sand"), 0.1)
    return m


def shell_dropin(r, g, which):
    m = Mesh("%s_detail%d" % (r.id, which), True)
    base = r.colour(g)
    st = r.section.stations
    crest = r.crest[0]
    if which == 1:
        halfw = crest + 4.0
        n = 11
        for k in range(n):
            xx = -halfw + (2 * halfw) * (k + 0.5) / n
            smp = surface_sample(r, g, xx, 0.0)
            if smp is None:
                continue
            pos, _ = smp
            m.box((pos.x, pos.y + 0.06, pos.z - 0.05), (2 * halfw / n - 0.12, 0.2, 1.3), 0.0, shade(c("concrete"), 0.94 + 0.1 * h01(k, 1)))
        for k in range(14):
            side = 1 if k % 2 else -1
            smp = surface_sample(r, g, side * (1.0 + 4.0 * h01(k, 2, 2)), r.zd + 1.0 + 5.0 * k * 0.5)
            if smp is None:
                continue
            pos, _ = smp
            sz = 0.5 + 0.9 * h01(k, 3, 3)
            m.lump((pos.x, pos.y + sz * 0.25, pos.z), (sz * 1.2, sz, sz), 700 + k, shade(mixc(c("sand"), c("oxide"), 0.1 + 0.3 * h01(k, 5)), 0.8), 0.1)
        jn = len(r.rows)
        first = next(q for q, v in enumerate(r.rows) if v[0] >= r.zd - 0.5)
        for side in (-1, 1):
            low = [i for i, q in enumerate(st) if q[0] * side > 0 and 0.5 <= q[1] <= 4.5]
            high = [i for i, q in enumerate(st) if q[0] * side > 0 and 4.5 <= q[1] <= 7.8]
            for k in range(first, jn - 5, 5):
                if len(low) >= 5:
                    paint(m, g, base, k, k + 4, low[0], min(low[-1], low[0] + 6), c("cream"), 0.45, 0.02)
                if len(high) >= 5 and h01(k, side, 31) > 0.35:
                    paint(m, g, base, k + 1, k + 5, high[0], min(high[-1], high[0] + 6), c("varnish"), 0.5, 0.02)
        for k in range(10):
            side = 1 if k % 2 else -1
            smp = surface_sample(r, g, side * (3.0 + 9.0 * h01(k, 6, 6)), -10.0 + 8.5 * h01(k, 7, 7))
            if smp is None:
                continue
            pos, _ = smp
            m.tuft((pos.x, pos.y, pos.z), 0.9 + 0.8 * h01(k, 8, 8), 5, 800 + k, c("sage") if k % 3 else c("juniper"))
    else:
        halfw = crest + 4.0
        n = 11
        for k in range(n):
            xx = -halfw + (2 * halfw) * (k + 0.5) / n
            smp = surface_sample(r, g, xx, 0.0)
            if smp is None:
                continue
            pos, _ = smp
            m.prism((pos.x, pos.y + 0.25, pos.z - 0.05), (0, 0.07, 0), 0.09, 0.08, 6, c("copper"))
        for k in range(60):
            smp = surface_sample(r, g, -3.5 + 7.0 * h01(k, 21, 1), r.zd + 2.0 + (r.length - r.zd - 4.0) * h01(k, 22, 2))
            if smp is None:
                continue
            pos, _ = smp
            m.lump((pos.x, pos.y + 0.05, pos.z), (0.26, 0.16, 0.22), 900 + k, mixc(c("bone"), c("oxide"), h01(k, 3) * 0.6), 0.1)
        for k in range(6):
            x0 = -halfw + 2 * halfw * h01(k, 23, 1)
            s0 = -9.0 + 7.0 * h01(k, 24, 2)
            pts = []
            for q in range(6):
                smp = surface_sample(r, g, x0 + q * 0.8 + 0.3 * math.sin(q + k), s0 + q * 0.6)
                if smp is not None:
                    pts.append(smp)
            for a, b in zip(pts, pts[1:]):
                pa, pb = a[0] + a[1] * 0.012, b[0] + b[1] * 0.012
                d = pb - pa
                w = Vector((d.z, 0, -d.x)).normalized() * 0.02 if (d.x or d.z) else Vector((0.02, 0, 0))
                m.add([tuple(pa - w), tuple(pa + w), tuple(pb + w), tuple(pb - w)], [(0, 3, 2, 1)], color=shade(c("sand"), 0.5))
    return m


SHELLS = {Concrete: shell_concrete, Slot: shell_slot, Dropin: shell_dropin}


def shell_for(r, g, which):
    for cls, fn in SHELLS.items():
        if isinstance(r, cls):
            return fn(r, g, which)
    raise KeyError(r.id)


def metrics_of(path):
    return kit.gltf_metrics(Path(path))


def checks(r, g, cg):
    """Fail loud on the contract: contiguous rows, upward floor faces and inward wall faces on the collider, sockets sane."""
    n = cg.n
    mid = n // 2
    bad_floor = bad_wall = 0
    for j in range(len(cg.verts) - 1):
        for i in range(n - 1):
            p = [Vector(cg.verts[j][i]), Vector(cg.verts[j + 1][i]), Vector(cg.verts[j + 1][i + 1]), Vector(cg.verts[j][i + 1])]
            nrm = (p[1] - p[0]).cross(p[3] - p[0])
            if nrm.length < 1e-9:
                continue
            nrm.normalize()
            q = r.col_section.stations[i]
            lat = Vector((cg.frames[j][4][0], 0, cg.frames[j][4][1]))
            want = lat * q[2] + Vector((0, 1, 0)) * q[3]
            if want.length > 1e-9 and nrm.dot(want.normalized()) < -0.2:
                if q[5] == "floor":
                    bad_floor += 1
                else:
                    bad_wall += 1
    assert bad_floor == 0 and bad_wall == 0, (r.id, "collider winding", bad_floor, bad_wall)
    xs = [v for row in cg.verts for v in row]
    for v in xs:
        assert all(math.isfinite(a) for a in v), (r.id, "non-finite collider vertex")
    sk = r.sockets()
    width = (Vector(sk["gauge_l"][0]) - Vector(sk["gauge_r"][0])).length
    wall = sk["gauge_l"][0][1] - sk["socket_exit"][0][1]
    assert 12.0 <= width <= 40.0 and 6.0 <= wall <= 14.0, (r.id, "size", width, wall)
    assert abs(math.degrees(sk["socket_exit"][1]) - r.bend) < 0.01, (r.id, "bend", sk["socket_exit"][1], r.bend)
    return {"crest_to_crest": round(width, 3), "wall": round(wall, 3), "exit": [round(v, 3) for v in sk["socket_exit"][0]]}


def export_one(r, kind, out_dir, count_only=False):
    g, m, cg, col = base_meshes(r)
    info = checks(r, g, cg)
    if kind == "base":
        name, meshes = r.id, [m, col]
    else:
        which = int(kind[-1])
        name = "%s_detail%d" % (r.id, which)
        meshes = [shell_for(r, g, which)]
    if count_only:
        tris = 0
        for mm in meshes:
            for f in mm.faces:
                tris += len(f) - 2
        print("HALFPIPES_COUNT", name, "tris", tris, "verts", sum(len(mm.verts) for mm in meshes),
              json.dumps([[mm.name, sum(len(f) - 2 for f in mm.faces)] for mm in meshes]))
        return None
    common.reset()
    kit.PARTS.clear()
    root = common.empty(name + "_root")
    for mm in meshes:
        mm.to_object(root, material=not mm.name.endswith("-col"))
    if kind == "base":
        for sname, (loc, yaw) in r.sockets().items():
            e = kit.empty(sname, loc, root)
            e.rotation_euler = (0.0, 0.0, yaw)
    path = Path(out_dir) / (name + ".glb")
    common.export(root, str(path))
    metrics = kit.gltf_metrics(path)
    cap = LANDFORM if kind == "base" else DETAIL
    assert metrics["triangles"] <= cap[0] and metrics["vertices"] <= cap[1] and metrics["draws"] <= cap[2], (name, metrics, cap)
    row = {**metrics, "file": path.name, "sha256": hashlib.sha256(path.read_bytes()).hexdigest(), **({"geometry": info} if kind == "base" else {})}
    print("HALFPIPES_EXPORT", name, json.dumps(row, sort_keys=True))
    return row


def main():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    parser = argparse.ArgumentParser()
    parser.add_argument("--out-dir", default=str(MODELS))
    parser.add_argument("--only", default="")
    parser.add_argument("--count-only", action="store_true")
    parser.add_argument("--grade", type=float, default=None, help="override the channel fall (a seeded-defect build for the family test)")
    args = parser.parse_args(argv)
    if args.grade is not None:
        globals()["GRADE"] = args.grade
    chosen = [s for s in args.only.split(",") if s] or list(recipes())
    for rid in chosen:
        r = recipes()[rid]
        for kind in ("base", "detail1", "detail2"):
            export_one(r, kind, args.out_dir, args.count_only)


if __name__ == "__main__":
    main()
