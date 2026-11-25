"""Park recipe family "anchors": the harpoon anchor posts a `greybox:anchor_field` park row stands up in a lattice.

  anchor_hoodoo_a/_b/_c    sandstone hoodoo: a talus skirt, a column of banded red and cream strata narrowing to a waist,
                           and a darker caprock on top. a: upright, six bands, broad cap; b: leaning, eight thin bands,
                           tilted cap; c: squat waist high up, five thick bands, a two-slab cap.
                           (hoodoo_field, slickrock, butte, spire, mesa_rim)
  anchor_basalt_a/_b/_c    dark basalt lava pillars: hexagonal columns, each with a cooled crust lip at its top and drips
                           hanging down its faces, and a faint warm glow band (vertex colour only) just above the ground.
                           a: a cluster of five; b: one leaning pillar with two stubs; c: six columns stepping up.
                           (lava_tube, sinkhole, cenote_pool)
  anchor_timber_a/_b/_c    mine timber set post on a stone footing: square timber with iron strap bands, a bolted cap
                           block, and a riveted copper plate with a brass lug and anchor ring near the top.
                           a: four timbers, three straps; b: one solid timber, two straps, knee braces under a wide cap;
                           c: two timbers, four straps, a tall cap turned along z.
                           (adit, flume, penstock, dam_face, cliff_dwelling)
  anchor_saguaro_a/_b/_c   saguaro cactus, ribbed, on a sand mound, with an iron collar and anchor ring under its crown.
                           a: two arms opposite; b: one arm and a slight lean; c: two arms, one low and one high.
                           (saguaro_stand)
  anchor_cairn_a/_b/_c     stacked flat-stone cairn with an iron pin and cable ring on the top stone.
                           a: eight neat stones; b: ten thin stones drifting to one side; c: six chunky stones.
                           (sky_island)

Soft toy (Andrew, 18 Oct): polish.enable below opts the kit into tools/blender/POLISH.md. Each convex piece is bevelled on its
hard edges (a few cm to 0.2 m, never more than a quarter of the piece's thinnest side) and smooth shaded; edges past a
per-piece crease angle stay hard (hex basalt corners, timber and strap corners keep a crisp bevelled edge). Round profiles
carry 8 to 24 sides (hoodoo 12 to 14, cairn 12 to 16, saguaro 24 sides with 12 ribs, the small rings 12 segments of 4), and the AO and edge-wear bake
multiplies the `enamel` vertex colour. The bake runs on the render mesh before the `-col` box is attached, so the box
casts no occlusion and gets no UV. The render mesh carries a zeroed TEXCOORD_0 and the `Bake` UV map (TEXCOORD_1); the
loader ignores UVs. Whether normals stay right under the loader's Y stretch is NOT verified here: it depends on how the
MultiMesh path of Godot's scene shader builds the normal matrix (no engine shader source was available to read), so check
the shading of a strongly stretched post on screen before trusting it.

Open joints: the strata bands (hoodoo) and the cairn stones sit on the piece below with their bottom ring overhanging its
bevelled top, so each band or stone after the first gets a flat, unbevelled bottom cap (`Surface.floor`, one n-gon facing
down, its own piece so the bevel never rounds that hidden rim). No player sees through a joint from under a ledge, and
check_recipe asserts every joint is either floored or inside its support.

Authoring contract (the machine-side change to park_recipes.gd place_anchor_field reads it):
  +Y up; the origin at the post's base centre on the ground; the footprint inside the 8 m x 8 m post square
  (ANCHOR_POST_M): x and z in [-4, 4]. Authored height exactly 10.0 m, of which 1.0 m (y -1 to 0) is the part sunk into
  the ground (ANCHOR_SINK_M): geometry spans y -1 to 9. The loader stretches Y only, by tall / 10 per row (tall =
  size[1] + ANCHOR_SINK_M, 0.3x to 3x and beyond), with the instance at y = ground - ANCHOR_SINK_M + tall / 10, so authored
  y -1 meets the box collider's bottom and y 9 its top. The identity feature (caprock, crust and drips, cap block and
  eye, crown and collar, pin and ring) sits in the top 20 % (y 7 and up); every round feature is a horizontal ring or a
  vertical column, which stay round under a Y stretch. Geometry is continuous from y -1 up, so no part floats at any
  stretch.
  Instanced through one MultiMesh per field: each render mesh is at most 1,000 triangles (BASE_TRIS; 400 before the soft-toy
  pass, 700 before the 19 Oct ruling on #149; the dam and crown fields each draw over 6,000 posts, so going above 1,000 needs a
  quiet-machine 4080 frame check first), a single mesh, a single material (`enamel`, vertex colour as albedo, as ledges.py). Deliberate deviation from the park family convention: no detail
  shells (_detail1/_detail2); instanced posts get no shells. Each GLB still carries the collision mesh `<id>-col`
  (the 8 x 8 x 10 post box, never drawn) so it matches the family's file shape; the loader keeps its BoxShape3D colliders.

Files per recipe id (assets/asset_budgets.json class detail: 4,000 triangles, 8,000 vertices, one draw):
  <id>.glb   the render mesh `<id>` and the collision mesh `<id>-col`

Colour: Southwest palette as vertex colour: sandstone c6a274, cream e6d9b8, iron-oxide red 9b513a, desert varnish 3a3027,
sage 7d8b6a, juniper 3f5a3e, basalt charcoal 242a28. The timber post is industrial, so iron, copper b77843 and brass
d9b44a appear there (and iron on the saguaro collar and the cairn ring). The basalt glow is a warm vertex colour, not an
emission. No texture, no light.

  prlimit -v12884901888 blender --background --threads 2 --python-exit-code 1 --python \\
      sketches/core-loop/tools/blender/park/anchors.py -- [--out-dir DIR] [--count-only] [--log FILE]
"""
import argparse
import hashlib
import json
import math
from pathlib import Path
import random
import struct
import sys

import bmesh
import bpy

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE.parent))
import common
import polish

polish.enable(bevel=0.06, bevel_angle=50.0, sharp_angle=50.0, ao_rays=24, ao_reach=0.18, ao_strength=0.5, edge=0.12,
              bake_slots=("enamel",))

MODELS = Path(common.SKETCH) / "assets/models/park"

POST_HALF = 4.0
SINK = 1.0
TOP = 9.0
BASE_TRIS = 1000
DETAIL_VERTS = 8000
IDENTITY_Y = TOP - 2.0

RED = ("a65f43", "9b513a", "6a3626")
REDS = [RED, ("b3694a", "a85b3e", "78432d"), ("86513c", "7a4733", "52301f")]
CREAM = ("e6d9b8", "d2c5a5", "a39373")
CREAMS = [CREAM, ("ead8b4", "dac9a6", "a99a78")]
SANDTOP = ("d0b88c", "c6a274", "8a6c48")
CAPROCK = ("6e5c48", "5a4a3a", "3a3027")
CAPROCK2 = ("5e5040", "4a3e32", "2b241d")
VARNISH = ("3a3027", "3a3027", "2b241d")
BASALT = ("3b3f3c", "2c302e", "1f2321")
BASALT2 = ("464340", "363432", "242220")
CRUST = ("55493e", "443a31", "2b241d")
GLOW = ("a8582c", "8f4a26", "5e3020")
EMBER = ("c46a32", "b05c2a", "7a3a1c")
TIMBER = ("8a6440", "7a5636", "4a3220")
TIMBER_DARK = ("6b4a30", "5e4128", "3a2819")
FOOTING = ("b2a68e", "9c907a", "6e6454")
IRON = ("5a5853", "4a4844", "33312e")
COPPER = ("c48a52", "b77843", "7a4e2a")
BRASS = ("e0c060", "d9b44a", "9a7e30")
SAGUARO = ("7d8b6a", "5f7552", "3f5a3e")
SAGUARO_RIB = ("8a9876", "6b7f5c", "4c6a4b")
SAND = ("d8c39a", "c9ad80", "8a7050")
STONES = [SANDTOP, CREAM, RED, ("c8b494", "b3a07e", "7a6a50"), ("b78a62", "a8794f", "6e4e34")]
WARM_STONES = [RED, ("b78a62", "a8794f", "6e4e34")]
PALE_STONES = [SANDTOP, CREAM, ("c8b494", "b3a07e", "7a6a50")]


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


def unit(a):
    n = math.sqrt(dot(a, a))
    return tuple(c / n for c in a)


class Surface:
    """Convex pieces added in Godot coordinates; every face is wound outward from its piece's centre, then fanned to
    triangles, so no winding is hand-written (ledges.py's Surface, trimmed to posts). The flat triangles feed the bounds and
    the triangle count; `finish` rebuilds each piece from its faces, bevels and smooths it (polish.finish) and joins them.
    `look` is the polish setting the next pieces take: bevel (m), segments, subsurf levels, bevel_angle (edges sharper than
    this are bevelled), sharp (edges sharper than this stay hard after the bevel) and fit (scale back to the unpolished box)."""

    def __init__(self, name, seed, colored=True):
        self.name, self.colored = name, colored
        self.rng = random.Random(seed)
        self.crng = random.Random(seed * 7919 + 17)
        self.floors = []
        self.joints = []
        self.verts, self.tris, self.colors = [], [], []
        self.pieces = []
        self.look = {}

    def add(self, verts, faces, tone=SANDTOP, mottle=0.1, centre=None):
        used = sorted({i for f in faces for i in f})
        remap = {old: k for k, old in enumerate(used)}
        pts = [verts[i] for i in used]
        if centre is None:
            centre = tuple(sum(p[k] for p in pts) / len(pts) for k in range(3))
        off = len(self.verts)
        self.verts.extend(pts)
        kept = []
        flat_tone = polish.options() is None
        piece_t = 0.0 if flat_tone else self.crng.uniform(-1, 1) * mottle
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
            kept.append(([i - off for i in idx], None))
            ny = n[1] / length
            base = hexf(tone[0] if ny > .6 else tone[2] if ny < -.6 else tone[1])
            if flat_tone:
                t = self.crng.uniform(-1, 1) * mottle
            else:
                t = piece_t
            c = mixf(base, hexf(VARNISH[0]) if t < 0 else hexf(CREAM[0]), abs(t))
            kept[-1] = (kept[-1][0], c)
            for k in range(1, len(idx) - 1):
                self.tris.append((idx[0], idx[k], idx[k + 1]))
                self.colors.append(c)
        if kept:
            self.pieces.append((pts, kept, dict(self.look)))

    def box(self, lo, hi, tone=SANDTOP, yaw=0.0, skip=(), mottle=0.1):
        xs, ys, zs = (lo[0], hi[0]), (lo[1], hi[1]), (lo[2], hi[2])
        pts = [(xs[i], ys[j], zs[k]) for i in (0, 1) for j in (0, 1) for k in (0, 1)]
        if yaw:
            cx, cz = (lo[0] + hi[0]) / 2, (lo[2] + hi[2]) / 2
            cs, sn = math.cos(yaw), math.sin(yaw)
            pts = [(cx + (p[0] - cx) * cs + (p[2] - cz) * sn, p[1], cz - (p[0] - cx) * sn + (p[2] - cz) * cs) for p in pts]
        faces = {"-x": (0, 1, 3, 2), "+x": (4, 5, 7, 6), "-y": (0, 1, 5, 4), "+y": (2, 3, 7, 6), "-z": (0, 2, 6, 4), "+z": (1, 3, 7, 5)}
        self.add(pts, [f for name, f in faces.items() if name not in skip], tone, mottle)

    def prism_z(self, poly_xy, z0, z1, tone, mottle=0.1):
        """A profile in (x, y) extruded along z from z0 to z1."""
        n = len(poly_xy)
        pts = [(x, y, z0) for x, y in poly_xy] + [(x, y, z1) for x, y in poly_xy]
        faces = [tuple(range(n)), tuple(range(n, 2 * n))]
        faces += [(i, (i + 1) % n, n + (i + 1) % n, n + i) for i in range(n)]
        self.add(pts, faces, tone, mottle)

    def prism_x(self, poly_zy, x0, x1, tone, mottle=0.1):
        """A profile in (z, y) extruded across x from x0 to x1."""
        n = len(poly_zy)
        pts = [(x0, y, z) for z, y in poly_zy] + [(x1, y, z) for z, y in poly_zy]
        faces = [tuple(range(n)), tuple(range(n, 2 * n))]
        faces += [(i, (i + 1) % n, n + (i + 1) % n, n + i) for i in range(n)]
        self.add(pts, faces, tone, mottle)

    def frustum(self, y0, y1, r0, r1, sides, tone, c0=(0.0, 0.0), c1=None, phase=0.0, radii=None, caps=(True, True), mottle=0.1):
        """A vertical column piece: an n-gon ring at y0 around c0 to one at y1 around c1 (x, z). `radii` multiplies each
        corner's radius (both rings alike, so the faces stay planar enough to read as cut stone). r1 0 ends in an apex."""
        c1 = c0 if c1 is None else c1
        radii = radii or [1.0] * sides
        ang = [phase + 2 * math.pi * k / sides for k in range(sides)]
        lo = [(c0[0] + math.cos(a) * r0 * m, y0, c0[1] + math.sin(a) * r0 * m) for a, m in zip(ang, radii)]
        if r1 <= 0.0:
            pts = lo + [(c1[0], y1, c1[1])]
            faces = [(k, (k + 1) % sides, sides) for k in range(sides)]
            if caps[0]:
                faces.append(tuple(range(sides)))
            self.add(pts, faces, tone, mottle)
            return lo, None
        hi = [(c1[0] + math.cos(a) * r1 * m, y1, c1[1] + math.sin(a) * r1 * m) for a, m in zip(ang, radii)]
        pts = lo + hi
        faces = [(k, (k + 1) % sides, sides + (k + 1) % sides, sides + k) for k in range(sides)]
        if caps[0]:
            faces.append(tuple(range(sides)))
        if caps[1]:
            faces.append(tuple(range(sides, 2 * sides)))
        self.add(pts, faces, tone, mottle)
        return lo, hi

    def floor(self, ring, tone, mottle=0.1):
        """Close a piece's open bottom ring with one flat n-gon facing down, as its own unbevelled piece (the rim sits hidden
        in the joint). Restores the caller's look."""
        keep, self.look = self.look, {"bevel": 0.0}
        cx = sum(p[0] for p in ring) / len(ring)
        cz = sum(p[2] for p in ring) / len(ring)
        self.add(list(ring), [tuple(range(len(ring)))], tone, mottle, centre=(cx, ring[0][1] + 1.0, cz))
        self.look = keep
        self.floors.append(ring)

    def rod(self, a, b, r, tone, sides=8, caps=(True, True)):
        """A round pole from a to b."""
        d = unit(sub(b, a))
        up = (0.0, 1.0, 0.0) if abs(d[1]) < .9 else (1.0, 0.0, 0.0)
        u = unit(cross(d, up))
        v = cross(d, u)
        ring = [tuple(math.cos(2 * math.pi * k / sides) * r * u[i] + math.sin(2 * math.pi * k / sides) * r * v[i] for i in range(3)) for k in range(sides)]
        pts = [tuple(a[i] + q[i] for i in range(3)) for q in ring] + [tuple(b[i] + q[i] for i in range(3)) for q in ring]
        faces = [(i, (i + 1) % sides, sides + (i + 1) % sides, sides + i) for i in range(sides)]
        if caps[0]:
            faces.append(tuple(range(sides)))
        if caps[1]:
            faces.append(tuple(range(sides, 2 * sides)))
        self.add(pts, faces, tone, 0.12)

    def ring(self, centre, radius, tube, tone, segments=8, sides=4):
        """A horizontal ring (anchor or cable ring) as open tube segments, each its own convex piece; lying flat, it stays
        round under the loader's Y stretch."""
        for s in range(segments):
            a0, a1 = 2 * math.pi * s / segments, 2 * math.pi * (s + 1) / segments
            ends = []
            for a in (a0, a1):
                out = (math.cos(a), 0.0, math.sin(a))
                ends.append([(centre[0] + out[0] * (radius + math.cos(2 * math.pi * k / sides) * tube),
                              centre[1] + math.sin(2 * math.pi * k / sides) * tube,
                              centre[2] + out[2] * (radius + math.cos(2 * math.pi * k / sides) * tube)) for k in range(sides)])
            pts = ends[0] + ends[1]
            faces = [(k, (k + 1) % sides, sides + (k + 1) % sides, sides + k) for k in range(sides)]
            self.add(pts, faces, tone, 0.08)

    def drip(self, cx, cz, angle, apothem, y_top, length, width, tone):
        """A cooled drip hanging down a column face: a thin tetrahedron hugging the face at `angle`."""
        d = (math.cos(angle), math.sin(angle))
        t = (-d[1], d[0])
        a = apothem - .03
        pts = [(cx + d[0] * a + t[0] * width, y_top, cz + d[1] * a + t[1] * width),
               (cx + d[0] * a - t[0] * width, y_top, cz + d[1] * a - t[1] * width),
               (cx + d[0] * (a + .28), y_top - length * .3, cz + d[1] * (a + .28)),
               (cx + d[0] * a, y_top - length, cz + d[1] * a)]
        self.add(pts, [(0, 1, 2), (0, 1, 3), (0, 2, 3), (1, 2, 3)], tone, 0.1)

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

    def bounds(self):
        lo = [min(v[k] for v in self.verts) for k in range(3)]
        hi = [max(v[k] for v in self.verts) for k in range(3)]
        return lo, hi

    def polished(self):
        """The pieces as one bmesh: each bevelled and smoothed alone under its own look, so a bevel never folds a thin piece
        into its neighbour, then triangulated the way common.Part does under polish."""
        opts = polish.options()
        out = bmesh.new()
        out.loops.layers.float_color.new("Color")
        for pts, faces, look in self.pieces:
            bm = bmesh.new()
            layer = bm.loops.layers.float_color.new("Color")
            vs = [bm.verts.new(xyz(p)) for p in pts]
            for idx, c in faces:
                face = bm.faces.new([vs[i] for i in idx])
                for loop in face.loops:
                    loop[layer] = common.rgba(c)
            bm.normal_update()
            o = dict(opts, bevel_segments=look.get("segments", 1), bevel_angle=look.get("bevel_angle", opts["bevel_angle"]),
                     sharp_angle=look.get("sharp", opts["sharp_angle"]), fit=look.get("fit", False))
            bm = polish.finish(bm, o, look.get("bevel", opts["bevel"]), look.get("subsurf", 0))
            polish._append(out, bm)
            bm.free()
        col = out.loops.layers.float_color["Color"]
        out.normal_update()
        for f in list(out.faces):
            if len(f.verts) > 4 and common._convex(f):
                vs = [loop.vert for loop in f.loops]
                color = tuple(f.loops[0][col])

                def flat(k):
                    w = vs[k:] + vs[:k]
                    return any((w[i].co - w[0].co).cross(w[i + 1].co - w[0].co).length < 1e-9 for i in range(1, len(w) - 1))
                k = next((k for k in range(len(vs)) if not flat(k)), 0)
                vs = vs[k:] + vs[:k]
                out.faces.remove(f)
                for i in range(1, len(vs) - 1):
                    nf = out.faces.new((vs[0], vs[i], vs[i + 1]))
                    for loop in nf.loops:
                        loop[col] = color
        fixed, alternate = [], []
        for f in out.faces:
            if len(f.verts) != 4:
                fixed.append(f)
                continue
            c = [tuple(v.co) for v in f.verts]
            d02, d13 = math.dist(c[0], c[2]), math.dist(c[1], c[3])
            first = d02 < d13 if abs(d02 - d13) > 1e-9 * max(d02, d13) else min(c[0], c[2]) < min(c[1], c[3])
            (fixed if first else alternate).append(f)
        bmesh.ops.triangulate(out, faces=fixed, quad_method="FIXED", ngon_method="EAR_CLIP")
        bmesh.ops.triangulate(out, faces=alternate, quad_method="ALTERNATE", ngon_method="EAR_CLIP")
        return polish._canonical(out)

    def finish(self, root):
        mesh = bpy.data.meshes.new(self.name)
        if self.colored and polish.options() is not None:
            bm = self.polished()
            bm.to_mesh(mesh)
            bm.free()
            self.polished_tris = len(mesh.polygons)
        else:
            mesh.from_pydata([xyz(v) for v in self.verts], [], [tuple(t) for t in self.tris])
            mesh.update()
            for poly in mesh.polygons:
                poly.use_smooth = False
        if self.colored:
            if mesh.color_attributes.get("Color") is None:
                attr = mesh.color_attributes.new(name="Color", type="FLOAT_COLOR", domain="CORNER")
                for poly, c in zip(mesh.polygons, self.colors):
                    for li in poly.loop_indices:
                        attr.data[li].color = common.rgba(c)
            mesh.color_attributes.active_color = mesh.color_attributes["Color"]
            mesh.color_attributes.render_color_index = mesh.color_attributes.active_color_index
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


ROCK_LOOK = {"bevel": 0.0}


def jitter(rng, sides, amount):
    return [1.0 + rng.uniform(-amount, amount) for _ in range(sides)]


def inside_by(ring, poly, margin):
    """True when every point of `ring` lies inside the convex polygon `poly` (3D points in order, x and z used) by at least
    `margin`."""
    n = len(poly)
    area = sum(poly[i][0] * poly[(i + 1) % n][2] - poly[(i + 1) % n][0] * poly[i][2] for i in range(n))
    sign = 1.0 if area > 0 else -1.0
    for q in ring:
        for i in range(n):
            a, b = poly[i], poly[(i + 1) % n]
            ex, ez = b[0] - a[0], b[2] - a[2]
            d = sign * (ex * (q[2] - a[2]) - ez * (q[0] - a[0])) / math.hypot(ex, ez)
            if d < margin - 1e-6:
                return False
    return True


def lerp_profile(profile, y):
    """Piecewise-linear radius along y from a [(y, r)] list."""
    if y <= profile[0][0]:
        return profile[0][1]
    for (ya, ra), (yb, rb) in zip(profile, profile[1:]):
        if y <= yb:
            return ra + (rb - ra) * (y - ya) / (yb - ya)
    return profile[-1][1]


HOODOO = {
    "a": {"sides": 14, "bands": 6, "profile": [(.3, 3.05), (2.4, 2.55), (5.2, 1.4), (6.6, 1.7), (7.4, 2.05)], "lean": (0.0, 0.0), "cap_y": 7.4,
          "cap": [(2.95, 3.25, 1.0), (2.75, 2.3, .6)], "tilt": (0.0, 0.0)},
    "b": {"sides": 12, "bands": 8, "profile": [(.3, 2.7), (3.0, 2.1), (5.6, 1.2), (7.1, 1.5), (7.7, 1.8)], "lean": (.11, .04), "cap_y": 7.7,
          "cap": [(2.35, 2.6, .8), (2.4, 1.9, .5)], "tilt": (.35, -.15)},
    "c": {"sides": 14, "bands": 5, "profile": [(.3, 3.3), (2.6, 3.0), (4.6, 2.1), (6.4, 1.3), (7.0, 1.6)], "lean": (-.04, .05), "cap_y": 7.0,
          "cap": [(2.6, 2.75, .9), (1.9, 2.05, .55), (1.25, .9, .55)], "tilt": (-.2, .3)},
}


def hoodoo(base, variant):
    p = HOODOO[variant]
    r = base.rng
    lean = p["lean"]

    def centre(y):
        return (lean[0] * (y + SINK), lean[1] * (y + SINK))

    sides = p["sides"]
    base.look = {"bevel": .1, "sharp": 80.0}
    base.frustum(-SINK, .4, 3.75, 3.2, 12, SANDTOP, centre(-SINK), centre(.4), phase=r.uniform(0, 1), radii=jitter(r, 12, .05), caps=(False, True))
    base.look = ROCK_LOOK
    for k in range(3):
        a = r.uniform(0, 2 * math.pi)
        base.rock((math.cos(a) * 3.1, .15, math.sin(a) * 3.1), (r.uniform(.7, 1.1), r.uniform(.5, .8), r.uniform(.7, 1.1)), SANDTOP)
    y0, y1 = .3, p["cap_y"] + .05
    n = p["bands"]
    base.look = {"bevel": .08, "sharp": 80.0}
    edges = [y0] + sorted(y0 + (y1 - y0) * (k + r.uniform(-.25, .25)) / n for k in range(1, n)) + [y1]
    for k in range(n):
        ya, yb = edges[k], edges[k + 1]
        step = 1.0 + r.uniform(-.06, .07)
        tone = REDS[k % 3] if k % 2 == 0 else CREAMS[(k // 2) % 2]
        lo_ring, top_ring = base.frustum(ya, yb, lerp_profile(p["profile"], ya) * step, lerp_profile(p["profile"], yb) * step, sides, tone,
                                         centre(ya), centre(yb), phase=r.uniform(0, 1), radii=jitter(r, sides, .07), caps=(k == 0, True))
        if k:
            base.floor(lo_ring, tone)
            base.joints.append(("band %d" % k, lo_ring, below_top, .08))
        below_top = top_ring
    y = p["cap_y"]
    total = sum(h for _, _, h in p["cap"])
    scale = (TOP - y) / total
    tilt = p["tilt"]
    base.look = {"bevel": .15, "sharp": 80.0, "segments": 2}
    cap_top = None
    for k, (ra, rb, h) in enumerate(p["cap"]):
        h *= scale
        ca, cb = centre(y), centre(y + h)
        off = (tilt[0] * k, tilt[1] * k)
        tone = CAPROCK if k % 2 == 0 else CAPROCK2
        lo_ring, top_ring = base.frustum(y, y + h, ra, rb, sides, tone, (ca[0] + off[0], ca[1] + off[1]),
                                         (cb[0] + off[0] + tilt[0] * .5, cb[1] + off[1] + tilt[1] * .5), phase=r.uniform(0, 1),
                                         radii=jitter(r, sides, .05), caps=(k == 0, True))
        if k:
            if not inside_by(lo_ring, cap_top, .15):
                base.floor(lo_ring, tone)
            base.joints.append(("cap slab %d" % k, lo_ring, cap_top, .15))
        cap_top = top_ring
        y += h


BASALT_COLS = {
    "a": [(0.0, 0.0, 1.75, TOP, 0.0, 0.0, 3), (2.15, .6, 1.25, 7.6, .25, .05, 2), (-1.6, 1.55, 1.2, 6.8, -.2, .2, 2),
          (-.9, -2.05, 1.3, 8.2, -.1, -.25, 2), (1.35, -1.85, 1.0, 5.6, .2, -.15, 2)],
    "b": [(-.4, -.2, 2.2, TOP, .9, .35, 4), (2.2, 1.5, 1.05, 4.2, .1, .1, 2), (-2.3, 1.6, 1.0, 3.1, -.1, .15, 1)],
    "c": [(-2.2, -1.2, 1.15, 5.2, 0, 0, 1), (-.6, -1.9, 1.15, 6.1, 0, 0, 1), (1.05, -1.0, 1.2, 7.0, 0, 0, 1),
          (.8, 1.0, 1.25, 7.9, 0, 0, 1), (-.95, .9, 1.3, TOP, 0, 0, 1), (2.45, .5, .95, 4.4, 0, 0, 1)],
}


def basalt(base, variant):
    r = base.rng
    base.look = {"bevel": .1}
    base.frustum(-SINK, .25, 3.72, 3.3, 8, BASALT2, phase=r.uniform(0, 1), radii=jitter(r, 8, .05), caps=(False, True))
    for x, z, rad, top, lx, lz, drips in BASALT_COLS[variant]:
        phase = r.uniform(0, math.pi / 3)
        span = top - .25
        tone = BASALT if base.crng.random() < .6 else BASALT2

        def at(y, x=x, z=z, lx=lx, lz=lz, span=span):
            f = (y - .25) / span
            return (x + lx * f, z + lz * f)

        g0, g1 = -.2, .95
        crust_h = .45 + .05 * rad
        base.look = {"bevel": .08}
        base.frustum(g0, g1, rad * 1.03, rad, 6, GLOW, at(g0), at(g1), phase, caps=(False, False), mottle=.04)
        base.look = {"bevel": .13, "segments": 2}
        base.frustum(g1, top - crust_h, rad, rad * .94, 6, tone, at(g1), at(top - crust_h), phase, caps=(False, False))
        base.look = {"bevel": .13}
        base.frustum(top - crust_h, top, rad * 1.1, rad * 1.04, 6, CRUST, at(top - crust_h), at(top), phase)
        cx, cz = at(top - crust_h)
        base.look = {"bevel": 0.0}
        for k in range(drips):
            face = phase + math.pi / 6 + (math.pi / 3) * r.randrange(6)
            base.drip(cx, cz, face, rad * .94 * math.cos(math.pi / 6), top - crust_h + .02, r.uniform(.9, 1.8) * (rad / 1.5 + .3), r.uniform(.18, .3), CRUST)
    base.look = ROCK_LOOK
    for k in range(1):
        a = r.uniform(0, 2 * math.pi)
        base.rock((math.cos(a) * 3.2, .3, math.sin(a) * 3.2), (.6, .35, .6), EMBER)


TIMBER_V = {
    "a": {"grid": (2, 2), "hw": 2.15, "straps": (2.2, 4.4, 6.4), "cap": (3.7, 2.8, 8.15), "braces": False, "eye": "+z", "footing": .5},
    "b": {"grid": (1, 1), "hw": 1.85, "straps": (3.0, 6.0), "cap": (3.95, 2.6, 7.9), "braces": True, "eye": "+z", "footing": .35},
    "c": {"grid": (1, 2), "hw": 2.0, "straps": (1.6, 3.3, 5.0, 6.6), "cap": (2.7, 3.8, 7.75), "braces": False, "eye": "+x", "footing": .8},
}


def timber(base, variant):
    p = TIMBER_V[variant]
    r = base.rng
    hw = p["hw"]
    fy = p["footing"]
    base.look = {"bevel": .12, "segments": 2}
    base.box((-3.8, -SINK, -3.8), (3.8, fy, 3.8), FOOTING, skip=("-y",), mottle=.12)
    cx_, cz_, cap_y = p["cap"]
    nx, nz = p["grid"]
    gap = .12
    wx, wz = (2 * hw - gap * (nx - 1)) / nx, (2 * hw - gap * (nz - 1)) / nz
    base.look = {"bevel": .1}
    for i in range(nx):
        for k in range(nz):
            x0, z0 = -hw + i * (wx + gap), -hw + k * (wz + gap)
            base.box((x0, fy - .1, z0), (x0 + wx, cap_y + .05, z0 + wz), TIMBER if (i + k) % 2 == 0 else TIMBER_DARK, skip=("-y", "+y"), mottle=.14)
    base.look = {"bevel": .06, "segments": 2}
    for y in p["straps"]:
        base.box((-hw - .1, y, -hw - .1), (hw + .1, y + .38, hw + .1), IRON, mottle=.06)
    if p["braces"]:
        base.look = {"bevel": .08}
        for s in (1, -1):
            a, b = hw - .02, cx_ - .25
            poly = [(s * a, cap_y - 2.2), (s * a, cap_y - 1.5), (s * b, cap_y + .02), (s * (b - .7), cap_y + .02)]
            base.prism_z(poly, -.55, .55, TIMBER_DARK, mottle=.1)
    base.look = {"bevel": .16, "segments": 2}
    base.box((-cx_, cap_y, -cz_), (cx_, TOP, cz_), TIMBER_DARK, mottle=.1)
    ym = (cap_y + TOP) / 2
    base.look = {"bevel": 0.0}
    for s in (1, -1):
        for f in (-.55, .55):
            x = f * cx_
            base.box((x - .16, ym - .16, s * cz_ - (.1 if s < 0 else 0)), (x + .16, ym + .16, s * cz_ + (.1 if s > 0 else 0)), IRON,
                     skip=("+z",) if s < 0 else ("-z",), mottle=.04)
    ey = IDENTITY_Y + .3
    base.look = {"bevel": 0.0}
    if p["eye"] == "+z":
        face = hw
        base.box((-.85, ey - .65, face), (.85, ey + .65, face + .1), COPPER, skip=("-z",), mottle=.06)
        for dx in (-.6, .6):
            for dy in (-.42, .42):
                base.box((dx - .07, ey + dy - .07, face + .1), (dx + .07, ey + dy + .07, face + .18), BRASS, skip=("-z",), mottle=.03)
        base.box((-.22, ey - .12, face + .1), (.22, ey + .12, face + .78), BRASS, skip=("-z",), mottle=.04)
        base.ring((0.0, ey, face + .78), .42, .09, BRASS, segments=12, sides=4)
    else:
        face = hw
        base.box((face, ey - .65, -.85), (face + .1, ey + .65, .85), COPPER, skip=("-x",), mottle=.06)
        for dz in (-.6, .6):
            for dy in (-.42, .42):
                base.box((face + .1, ey + dy - .07, dz - .07), (face + .18, ey + dy + .07, dz + .07), BRASS, skip=("-x",), mottle=.03)
        base.box((face + .1, ey - .12, -.22), (face + .78, ey + .12, .22), BRASS, skip=("-x",), mottle=.04)
        base.ring((face + .78, ey, 0.0), .42, .09, BRASS, segments=12, sides=4)


SAGUARO_V = {
    "a": {"r": 1.45, "lean": (0.0, 0.0), "arms": [(0.15, 3.9, 2.75, 6.6, .72), (math.pi + .1, 4.7, 2.6, 7.1, .68)]},
    "b": {"r": 1.55, "lean": (.45, -.3), "arms": [(2.3, 4.4, 2.7, 7.0, .78)]},
    "c": {"r": 1.35, "lean": (-.2, .25), "arms": [(-.5, 3.0, 2.7, 5.4, .66), (2.2, 5.3, 2.5, 7.4, .62)]},
}


def saguaro(base, variant):
    p = SAGUARO_V[variant]
    r = base.rng
    rad = p["r"]
    lean = p["lean"]
    ribs = 24
    rib = [1.0 if k % 2 == 0 else .88 for k in range(ribs)]

    def at(y):
        f = max(0.0, y) / TOP
        return (lean[0] * f * f, lean[1] * f * f)

    base.look = {"bevel": .1, "sharp": 75.0}
    base.frustum(-SINK, .35, 2.9, 2.0, 12, SAND, phase=r.uniform(0, 1), radii=jitter(r, 12, .08), caps=(False, True))
    base.look = {"bevel": 0.0, "sharp": 75.0}
    collar0, collar1 = 7.25, 7.75
    ys = [.2, 2.6, 5.0, collar0, 8.35, 8.8]
    rs = [rad * 1.02, rad, rad * .98, rad * .95, rad * .86, rad * .55]
    for k in range(len(ys) - 1):
        tone = SAGUARO if k % 2 == 0 else SAGUARO_RIB
        base.frustum(ys[k], ys[k + 1], rs[k], rs[k + 1], ribs, tone, at(ys[k]), at(ys[k + 1]), radii=rib, caps=(False, False), mottle=.06)
    base.frustum(ys[-1], TOP, rs[-1], 0.0, ribs, SAGUARO_RIB, at(ys[-1]), at(TOP), radii=rib, caps=(False, False), mottle=.04)
    for ang, ye, reach, tip, ar in p["arms"]:
        c = at(ye)
        d = (math.cos(ang), math.sin(ang))
        start = (c[0] + d[0] * rad * .5, ye - .35, c[1] + d[1] * rad * .5)
        elbow = (c[0] + d[0] * reach, ye + .35, c[1] + d[1] * reach)
        arm = [1.0 if k % 2 == 0 else .88 for k in range(16)]
        base.rod(start, elbow, ar, SAGUARO, sides=16, caps=(False, False))
        base.frustum(ye - ar * .6, tip - .45, ar * 1.02, ar * .95, 16, SAGUARO_RIB, (elbow[0], elbow[2]), (elbow[0], elbow[2]),
                     radii=arm, caps=(True, False), mottle=.06)
        base.frustum(tip - .45, tip, ar * .95, 0.0, 16, SAGUARO, (elbow[0], elbow[2]), (elbow[0], elbow[2]),
                     radii=arm, caps=(False, False), mottle=.04)
    cc = at((collar0 + collar1) / 2)
    base.look = {"bevel": .06}
    base.frustum(collar0, collar1, rad * 1.06, rad * 1.05, 24, IRON, at(collar0), at(collar1), mottle=.05)
    base.look = {"bevel": 0.0}
    ang = p["arms"][0][0] + math.pi / 2
    d = (math.cos(ang), math.sin(ang))
    lug0 = rad * 1.0
    lug1 = rad * 1.05 + .55
    ym = (collar0 + collar1) / 2
    base.rod((cc[0] + d[0] * lug0, ym, cc[1] + d[1] * lug0), (cc[0] + d[0] * lug1, ym, cc[1] + d[1] * lug1), .13, IRON, sides=4)
    base.ring((cc[0] + d[0] * (lug1 + .3), ym, cc[1] + d[1] * (lug1 + .3)), .38, .08, IRON, segments=12, sides=4)


CAIRN_V = {
    "a": {"sides": 16, "h": [1.5, 1.1, 1.0, 1.05, .95, .9, .85, .8], "r": [3.6, 3.25, 2.95, 2.6, 2.3, 2.0, 1.7, 1.4], "drift": (0.0, 0.0), "pin": .9},
    "b": {"sides": 13, "h": [1.4, .8, .75, .8, .7, .75, .7, .65, .7, .6], "r": [3.5, 3.0, 2.8, 2.55, 2.35, 2.15, 1.9, 1.7, 1.5, 1.3], "drift": (.2, .09), "pin": .85},
    "c": {"sides": 16, "h": [1.9, 1.5, 1.4, 1.35, 1.2, 1.1], "r": [3.62, 3.3, 2.8, 2.35, 1.9, 1.5], "drift": (-.08, .12), "pin": 1.0},
}


def cairn(base, variant):
    p = CAIRN_V[variant]
    r = base.rng
    pin = p["pin"]
    overlap = .05
    span = TOP - pin + SINK + overlap * (len(p["h"]) - 1)
    hs = [h * span / sum(p["h"]) for h in p["h"]]
    y = -SINK
    cx = cz = 0.0
    base.look = {"bevel": .2, "sharp": 80.0}
    below_top = None
    warm0 = base.crng.randrange(2)
    for k, (h, rad) in enumerate(zip(hs, p["r"])):
        sides = p["sides"] - k % 2
        base.look = {"bevel": .2, "sharp": 80.0, "segments": 3 if k + 1 == len(hs) else 1}
        taper = r.uniform(.9, .97)
        pool = WARM_STONES if (k + warm0) % 2 == 0 else PALE_STONES
        tone = pool[base.crng.randrange(len(pool))]
        phase, radii = r.uniform(0, 2 * math.pi), jitter(r, sides, .08)
        lo_ring, top_ring = base.frustum(y, y + h, rad, rad * taper, sides, tone, (cx, cz), (cx, cz),
                                         phase=phase, radii=radii, caps=(False, True), mottle=.12)
        if below_top is not None:
            base.floor(lo_ring, tone, .12)
            base.joints.append(("stone %d" % k, lo_ring, below_top, .2))
        below_top = top_ring
        y += h - overlap
        if k + 1 < len(hs):
            cx += max(-.2, min(.2, p["drift"][0] + r.uniform(-.12, .12)))
            cz += max(-.2, min(.2, p["drift"][1] + r.uniform(-.12, .12)))
    ytop = y + overlap
    base.look = ROCK_LOOK
    for k in range(2):
        a = r.uniform(0, 2 * math.pi)
        base.rock((math.cos(a) * 2.6, .1, math.sin(a) * 2.6), (r.uniform(.6, .9), r.uniform(.4, .6), r.uniform(.6, .9)), STONES[base.crng.randrange(len(STONES))])
    base.look = {"bevel": .04}
    base.box((cx - .16, ytop - .1, cz - .16), (cx + .16, TOP, cz + .16), IRON, skip=("-y",), mottle=.04)
    base.look = {"bevel": 0.0}
    base.ring((cx, ytop + pin * .45, cz), .5, .1, IRON, segments=12, sides=4)


FAMILIES = {"hoodoo": (hoodoo, 1301), "basalt": (basalt, 1311), "timber": (timber, 1321), "saguaro": (saguaro, 1331), "cairn": (cairn, 1341)}
RECIPES = {"anchor_%s_%s" % (fam, v): (fn, seed + k, v) for fam, (fn, seed) in FAMILIES.items() for k, v in enumerate("abc")}


def check_recipe(rid, base, col):
    """Fails loud on anything the authoring contract names."""
    lo, hi = base.bounds()
    assert abs(lo[1] + SINK) < 1e-4 and abs(hi[1] - TOP) < 1e-4, (rid, "render mesh spans y -1 to 9", lo, hi)
    for k in (0, 2):
        assert lo[k] >= -POST_HALF and hi[k] <= POST_HALF, (rid, "footprint inside the 8 m post square", lo, hi)
    assert 0 < len(base.tris), (rid, "no triangles")
    for name, ring, poly, margin in base.joints:
        assert any(ring is f for f in base.floors) or inside_by(ring, poly, margin), (rid, name, "open bottom ring floored or inside the piece below")
    if polish.options() is None:
        assert len(base.tris) <= BASE_TRIS, (rid, "instanced post triangle cap (flat)", len(base.tris), BASE_TRIS)
    else:
        bm = base.polished()
        count = len(bm.faces)
        plo = [min(v.co[0] for v in bm.verts), min(v.co[2] for v in bm.verts), min(-v.co[1] for v in bm.verts)]
        phi = [max(v.co[0] for v in bm.verts), max(v.co[2] for v in bm.verts), max(-v.co[1] for v in bm.verts)]
        bm.free()
        assert 0 < count <= BASE_TRIS, (rid, "instanced post triangle cap", count, BASE_TRIS)
        assert abs(plo[1] + SINK) < 1e-4 and abs(phi[1] - TOP) < 1e-4, (rid, "polished mesh spans y -1 to 9", plo, phi)
        for k in (0, 2):
            assert plo[k] >= -POST_HALF and phi[k] <= POST_HALF, (rid, "polished footprint inside the post square", plo, phi)
        base.polished_count = count
    clo, chi = col.bounds()
    assert clo == [-POST_HALF, -SINK, -POST_HALF] and chi == [POST_HALF, TOP, POST_HALF], (rid, "collider is the post box", clo, chi)


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
        if s.colored and common.POLISH is not None:
            bpy.context.view_layer.update()
            polish.bake(root, common.POLISH)
    bake = polish.bake
    polish.bake = lambda *a, **k: None
    try:
        common.export(root, str(path))
    finally:
        polish.bake = bake
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
    for rid, (fn, seed, variant) in RECIPES.items():
        base = Surface(rid, seed)
        col = Surface(rid + "-col", seed, colored=False)
        fn(base, variant)
        col.box((-POST_HALF, -SINK, -POST_HALF), (POST_HALF, TOP, POST_HALF))
        check_recipe(rid, base, col)
        counts = {"base": getattr(base, "polished_count", len(base.tris)), "flat": len(base.tris), "col": len(col.tris)}
        print("ANCHORS_COUNT", rid, json.dumps(counts, sort_keys=True))
        if args.count_only:
            continue
        path = out / (rid + ".glb")
        m = export_one(path, rid, [base, col])
        assert m["vertices"] <= DETAIL_VERTS, (rid, "detail class verts cap", m["vertices"], DETAIL_VERTS)
        rows[rid] = {"counts": counts, "file": path.name, "sha256": hashlib.sha256(path.read_bytes()).hexdigest(), "triangles": m["triangles"],
                     "vertices": m["vertices"], "primitives": m["primitives"], "materials": m["materials"], "nodes": m["nodes"], "bounds": m["bounds"]}
        print("ANCHORS_EXPORT", rid, json.dumps(rows[rid], sort_keys=True))
    if args.log and rows:
        Path(args.log).parent.mkdir(parents=True, exist_ok=True)
        Path(args.log).write_text(json.dumps(rows, indent=1, sort_keys=True) + "\n")


if __name__ == "__main__":
    main()
