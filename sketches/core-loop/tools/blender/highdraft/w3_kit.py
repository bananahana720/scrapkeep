"""World 3 (The Highdraft) valley and Crown Sky-Deck dressing kit (W49-MAPS).

Blender 5.3.0 headless build (metres, +Y up in glTF, no external textures):
  blender -b --factory-startup --threads 2 --python-exit-code 1 \
    --python sketches/core-loop/tools/blender/highdraft/w3_kit.py -- [--out-root DIR]

New Mexico grounding (worlds-2-3-storyboard.md section 2, master bible section 3.3):
  - Stage 5 Hanging Isle: Shiprock's twin volcanic dikes (black basalt wall fins), Acoma
    golden-hour mesas, aerial ore tramway towers and buckets over the gypsum-white cloud sea.
  - Stage 6 Crown Works: Chaco bajada balanced hoodoos, Lightning Field copper grounding rods
    with their grounding lines, and kite-tether thermal updraft rings.
  - The Mind's Crown Sky-Deck: iron bounce-cable posts round the open deck edge.

Colour law (rubric B6, palette.gd): Old Works petrol only as Palette.VERDIGRIS #365754, no brass
(#d9b44a) anywhere, no HAZARD #FF5A3C, no mint #8BF0D3 and no Kindness purple on any static piece.
Copper is the muted Palette.COPPER #b77843 (darkened toward charcoal), never bright orange.
Every piece is one surface on a vertex-colour material, no emission, no light.

Exports under sketches/core-loop/assets/models/highdraft/:
  w3_shiprock_dike.glb, w3_tram_tower.glb, w3_ore_bucket.glb, w3_balanced_hoodoo.glb,
  w3_lightning_rod.glb, w3_kite_ring.glb, w3_deck_post.glb
"""

import argparse
import hashlib
import json
import math
from pathlib import Path
import struct
import sys

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE.parent))

import bmesh
import bpy
from mathutils import Euler, Matrix, Vector

import common

SKETCH = HERE.parents[2]
MODELS = SKETCH / "assets/models"

PETROL = "365754"
BONE = "d2c5a5"
SANDSTONE = "c6a274"
RUST = "9b513a"
COPPER = "b77843"
CHARCOAL = "242a28"
CABLE = "2a3231"
STEEL = "9aa0a0"
BASALT_DARK = "1f2427"
BASALT_EDGE = "3d4549"
DIKE_RUST = "5a3a2e"
MESA_GOLD = "c98a52"
HOODOO_RED = "b0603e"
HOODOO_PALE = "d8b48a"
CAPROCK = "8d7a66"
TIMBER_DARK = "5b3c26"
TIMBER_LIGHT = "7d5436"
OCHRE = "b8873f"
COPPER_MUTED = "8a5f3c"
IRON = "3a403f"


def srgb(h):
    return tuple(int(h[i:i + 2], 16) / 255.0 for i in (0, 2, 4))


def mix_hex(a, b, t):
    ca, cb = srgb(a), srgb(b)
    return tuple(ca[i] + (cb[i] - ca[i]) * t for i in range(3))


def ensure_vc_material(name, rough=0.84, metal=0.0):
    mat = bpy.data.materials.get(name)
    if mat is not None:
        return mat
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    nodes = mat.node_tree.nodes
    bsdf = nodes.get("Principled BSDF")
    bsdf.inputs["Roughness"].default_value = rough
    bsdf.inputs["Metallic"].default_value = metal
    attr = nodes.new("ShaderNodeVertexColor")
    attr.layer_name = "Color"
    mat.node_tree.links.new(attr.outputs["Color"], bsdf.inputs["Base Color"])
    return mat


class Builder:
    """bmesh builder in Blender Z-up (export_yup maps Z->Y, -Y->Z)."""

    def __init__(self, name, material_name, rough=0.84, metal=0.0):
        self.name = name
        self.material_name = material_name
        self.rough = rough
        self.metal = metal
        self.bm = bmesh.new()
        self.col = self.bm.loops.layers.float_color.new("Color")

    def _paint(self, faces, rgb):
        rgba = common.rgba(rgb if isinstance(rgb, tuple) else srgb(rgb))
        for f in faces:
            for loop in f.loops:
                loop[self.col] = rgba

    def add_box(self, size, loc=(0, 0, 0), rot=(0, 0, 0), color=BONE):
        before = set(self.bm.faces)
        mtx = Matrix.LocRotScale(Vector(loc), Euler(rot).to_quaternion(), Vector(size))
        bmesh.ops.create_cube(self.bm, size=1.0, matrix=mtx)
        new_faces = [f for f in self.bm.faces if f not in before]
        self._paint(new_faces, color)
        return new_faces

    def add_beam(self, a, b, thick, color):
        """A square beam from point a to point b (Blender frame)."""
        va, vb = Vector(a), Vector(b)
        d = vb - va
        length = d.length
        if length < 1e-4:
            return []
        quat = Vector((0, 0, 1)).rotation_difference(d.normalized())
        mtx = Matrix.LocRotScale((va + vb) * 0.5, quat, Vector((thick, thick, length)))
        before = set(self.bm.faces)
        bmesh.ops.create_cube(self.bm, size=1.0, matrix=mtx)
        new_faces = [f for f in self.bm.faces if f not in before]
        self._paint(new_faces, color)
        return new_faces

    def add_tube(self, rings, colors, closed_ends=True):
        vrings = [[self.bm.verts.new(Vector(p)) for p in r] for r in rings]
        n = len(rings[0])
        for s in range(len(rings) - 1):
            r0, r1 = vrings[s], vrings[s + 1]
            seg = []
            for i in range(n):
                j = (i + 1) % n
                seg.append(self.bm.faces.new((r0[i], r0[j], r1[j], r1[i])))
            self._paint(seg, colors[s])
        if closed_ends:
            f0 = self.bm.faces.new(list(reversed(vrings[0])))
            f1 = self.bm.faces.new(vrings[-1])
            self._paint([f0], colors[0])
            self._paint([f1], colors[-1])

    def add_cylinder(self, radius, z0, z1, color, segs=10, top_radius=None, cx=0.0, cy=0.0, cap=True):
        top_radius = radius if top_radius is None else top_radius
        bot = [(cx + radius * math.cos(k * math.tau / segs), cy + radius * math.sin(k * math.tau / segs), z0) for k in range(segs)]
        top = [(cx + top_radius * math.cos(k * math.tau / segs), cy + top_radius * math.sin(k * math.tau / segs), z1) for k in range(segs)]
        self.add_tube([bot, top], [color], closed_ends=cap)

    def add_torus(self, major, minor, z, colors, segs=24, tube=6):
        rings = []
        for s in range(segs + 1):
            a = s * math.tau / segs
            ca, sa = math.cos(a), math.sin(a)
            ring = []
            for t in range(tube):
                b = t * math.tau / tube
                r = major + minor * math.cos(b)
                ring.append((ca * r, sa * r, z + minor * math.sin(b)))
            rings.append(ring)
        cols = [colors[s % len(colors)] for s in range(segs)]
        self.add_tube(rings, cols, closed_ends=False)

    def to_object(self, parent):
        bmesh.ops.remove_doubles(self.bm, verts=list(self.bm.verts), dist=1e-5)
        bmesh.ops.recalc_face_normals(self.bm, faces=list(self.bm.faces))
        bmesh.ops.triangulate(self.bm, faces=list(self.bm.faces), quad_method="FIXED", ngon_method="BEAUTY")
        mesh = bpy.data.meshes.new(self.name)
        self.bm.to_mesh(mesh)
        self.bm.free()
        for ca in list(mesh.color_attributes):
            if ca.name != "Color":
                mesh.color_attributes.remove(ca)
        if len(mesh.color_attributes) > 0:
            mesh.color_attributes.active_color_index = 0
            mesh.color_attributes.render_color_index = 0
        mesh.materials.append(ensure_vc_material(self.material_name, self.rough, self.metal))
        obj = bpy.data.objects.new(self.name, mesh)
        bpy.context.scene.collection.objects.link(obj)
        obj.parent = parent
        return obj


def export_glb(root, path: Path, caps):
    path.parent.mkdir(parents=True, exist_ok=True)
    bpy.ops.object.select_all(action="DESELECT")
    for obj in common.tree(root):
        obj.select_set(True)
    bpy.context.view_layer.objects.active = root
    bpy.ops.export_scene.gltf(
        filepath=str(path),
        export_format="GLB",
        use_selection=True,
        export_yup=True,
        export_materials="EXPORT",
        export_vertex_color="ACTIVE",
        export_all_vertex_colors=False,
        export_extras=False,
        export_cameras=False,
        export_lights=False,
    )
    common.canonical_indices(str(path), vertices=False)
    blob = path.read_bytes()
    n = struct.unpack_from("<I", blob, 12)[0]
    gltf = json.loads(blob[20:20 + n])
    tris = verts = draws = 0
    for mesh in gltf.get("meshes", []):
        for p in mesh["primitives"]:
            attrs = p["attributes"]
            assert "COLOR_1" not in attrs and "COLOR_0" in attrs, (path.name, attrs)
            tris += gltf["accessors"][p["indices"]]["count"] // 3
            verts += gltf["accessors"][attrs["POSITION"]]["count"]
            draws += 1
    assert not gltf.get("extensions", {}).get("KHR_lights_punctual"), path.name
    assert 0 < tris <= caps[0] and verts <= caps[1] and draws <= caps[2], (path.name, tris, verts, draws, caps)
    info = {"file": path.name, "tris": tris, "verts": verts, "draws": draws, "bytes": len(blob),
            "sha256": hashlib.sha256(blob).hexdigest()}
    print("W49_GLB", json.dumps(info, sort_keys=True))
    return info


def _jag(x, seed):
    return (math.sin(x * 0.37 + seed) * 0.5 + math.sin(x * 0.91 + seed * 1.7) * 0.3
            + math.sin(x * 2.3 + seed * 0.6) * 0.2)


def build_shiprock_dike(out_root: Path):
    common.reset()
    root = common.empty("w3_shiprock_dike")
    b = Builder("ShiprockDike", "stone", rough=0.92)
    steps = 28
    length = 84.0
    rings = []
    colors = []
    for s in range(steps + 1):
        u = s / steps
        x = (u - 0.5) * length
        end = math.sin(math.pi * u) ** 0.55
        crest = 10.0 + 24.0 * end * (0.72 + 0.28 * _jag(x, 1.3))
        half = (1.5 + 1.6 * end) * (1.0 + 0.12 * _jag(x, 4.1))
        lean = 0.9 * _jag(x, 2.2)
        prof = [(-half * 1.25, -2.0), (half * 1.25, -2.0), (half, crest * 0.45),
                (half * 0.35 + lean * 0.3, crest), (-half * 0.35 + lean * 0.3, crest * 0.97), (-half, crest * 0.5)]
        rings.append([(x, py, pz) for py, pz in prof])
        if s < steps:
            colors.append(BASALT_DARK if s % 3 else BASALT_EDGE)
    b.add_tube(rings, colors, closed_ends=True)
    for k in range(9):
        x = -36.0 + k * 9.0 + 2.0 * math.sin(k * 1.9)
        side = 1.0 if k % 2 else -1.0
        b.add_box((4.2, 3.0, 2.2), loc=(x, side * 3.4, -0.6), rot=(0.1 * side, 0.15, 0.4 * k), color=DIKE_RUST)
        b.add_box((2.6, 2.0, 1.6), loc=(x + 2.4, side * 4.6, -0.8), rot=(0.0, -0.2, 0.7 * k), color=BASALT_EDGE)
    b.to_object(root)
    return export_glb(root, out_root / "highdraft/w3_shiprock_dike.glb", (4000, 8000, 1))


def build_tram_tower(out_root: Path):
    common.reset()
    root = common.empty("w3_tram_tower")
    b = Builder("TramTower", "steel", rough=0.86, metal=0.1)
    top = 19.2
    for sx in (-1.0, 1.0):
        for sy in (-1.0, 1.0):
            b.add_beam((sx * 3.4, sy * 2.2, 0.0), (sx * 0.9, sy * 1.2, top), 0.55, TIMBER_DARK)
            b.add_box((1.4, 1.4, 0.9), loc=(sx * 3.4, sy * 2.2, 0.2), color=IRON)
    for z, w in ((5.0, 2.8), (10.0, 2.1), (15.0, 1.4)):
        for sy in (-1.0, 1.0):
            b.add_beam((-w, sy * (1.2 + (top - z) / top), z), (w, sy * (1.2 + (top - z) / top), z), 0.32, TIMBER_LIGHT)
        b.add_beam((-w, -1.6, z), (w, 1.6, z + 4.6), 0.22, TIMBER_LIGHT)
    b.add_box((2.6, 8.6, 0.6), loc=(0.0, 0.0, top + 0.3), color=TIMBER_LIGHT)
    for sy in (-3.6, 3.6):
        b.add_box((0.3, 0.6, 1.9), loc=(0.0, sy, top + 0.9), color=CHARCOAL)
        b.add_box((1.9, 0.6, 0.3), loc=(0.0, sy, top + 0.9), color=CHARCOAL)
        b.add_box((0.5, 0.7, 0.5), loc=(0.0, sy, top + 0.9), color=RUST)
    b.to_object(root)
    return export_glb(root, out_root / "highdraft/w3_tram_tower.glb", (2400, 4800, 1))


def build_ore_bucket(out_root: Path):
    common.reset()
    root = common.empty("w3_ore_bucket")
    b = Builder("OreBucket", "steel", rough=0.82, metal=0.15)
    b.add_box((1.6, 0.5, 0.5), loc=(0.0, 0.0, 0.0), color=CHARCOAL)
    for sx in (-0.55, 0.55):
        b.add_cylinder(0.32, -0.12, 0.12, IRON, segs=10, cx=sx, cy=0.0)
    b.add_beam((0.0, 0.0, -0.2), (0.0, 0.0, -3.0), 0.16, IRON)
    b.add_beam((-0.9, 0.0, -3.0), (0.9, 0.0, -3.0), 0.14, IRON)
    b.add_cylinder(1.05, -4.9, -3.1, RUST, segs=12, top_radius=1.25)
    b.add_cylinder(1.18, -3.3, -3.05, mix_hex(RUST, CHARCOAL, 0.4), segs=12, top_radius=1.28)
    b.add_cylinder(1.0, -3.15, -2.85, mix_hex(COPPER_MUTED, SANDSTONE, 0.25), segs=12, top_radius=0.35)
    b.to_object(root)
    return export_glb(root, out_root / "highdraft/w3_ore_bucket.glb", (800, 1600, 1))


def build_balanced_hoodoo(out_root: Path):
    common.reset()
    root = common.empty("w3_balanced_hoodoo")
    b = Builder("BalancedHoodoo", "stone", rough=0.93)
    segs = 9
    rings = []
    colors = []
    levels = [(-2.0, 5.2), (0.0, 5.0), (3.0, 4.2), (6.5, 3.7), (10.0, 3.4), (13.5, 3.0), (17.0, 2.5), (20.0, 2.0), (22.4, 1.55)]
    for i, (z, r) in enumerate(levels):
        wob = 1.0 + 0.08 * math.sin(i * 1.7)
        rings.append([(r * wob * math.cos(k * math.tau / segs + i * 0.21), r * math.sin(k * math.tau / segs + i * 0.21), z)
                      for k in range(segs)])
        if i < len(levels) - 1:
            colors.append(HOODOO_PALE if i % 3 == 1 else (HOODOO_RED if i % 3 == 0 else mix_hex(HOODOO_RED, RUST, 0.45)))
    b.add_tube(rings, colors, closed_ends=True)
    b.add_box((7.6, 6.4, 1.9), loc=(0.6, -0.3, 23.4), rot=(0.06, -0.08, 0.35), color=CAPROCK)
    b.add_box((6.4, 5.4, 1.0), loc=(0.4, -0.2, 24.6), rot=(0.06, -0.08, 0.35), color=mix_hex(CAPROCK, BONE, 0.3))
    for k in range(6):
        a = k * math.tau / 6 + 0.4
        b.add_box((2.6, 2.0, 1.4), loc=(math.cos(a) * 5.8, math.sin(a) * 5.8, -0.6), rot=(0.2, 0.1, a), color=HOODOO_RED)
    b.to_object(root)
    return export_glb(root, out_root / "highdraft/w3_balanced_hoodoo.glb", (1600, 3200, 1))


def build_lightning_rod(out_root: Path):
    common.reset()
    root = common.empty("w3_lightning_rod")
    b = Builder("LightningRod", "steel", rough=0.6, metal=0.35)
    top = 27.0
    for k in range(3):
        a = k * math.tau / 3
        b.add_beam((math.cos(a) * 1.6, math.sin(a) * 1.6, 0.0), (math.cos(a) * 0.45, math.sin(a) * 0.45, top), 0.26, IRON)
    for z in range(2, int(top), 3):
        r = 1.6 - 1.15 * (z / top)
        r2 = 1.6 - 1.15 * ((z + 3) / top)
        for k in range(3):
            a0 = k * math.tau / 3
            a1 = (k + 1) * math.tau / 3
            b.add_beam((math.cos(a0) * r, math.sin(a0) * r, z), (math.cos(a1) * r2, math.sin(a1) * r2, z + 3), 0.1, CHARCOAL)
    for i, z in enumerate((top + 0.2, top + 0.9, top + 1.6)):
        b.add_cylinder(0.55 - i * 0.08, z, z + 0.45, BONE, segs=10, top_radius=0.25)
    b.add_cylinder(0.14, top + 2.0, top + 4.5, COPPER_MUTED, segs=8, top_radius=0.03)
    b.add_box((0.9, 0.9, 0.12), loc=(0.0, 0.0, top + 2.0), color=COPPER_MUTED)
    for k in range(4):
        a = k * math.tau / 4 + math.pi / 4
        b.add_beam((math.cos(a) * 0.5, math.sin(a) * 0.5, top * 0.7), (math.cos(a) * 9.0, math.sin(a) * 9.0, 0.0), 0.07, CABLE)
        b.add_box((0.8, 0.8, 0.5), loc=(math.cos(a) * 9.0, math.sin(a) * 9.0, 0.0), color=IRON)
    b.add_beam((0.0, 0.0, top + 2.0), (-0.45, 0.0, top), 0.12, COPPER_MUTED)
    b.add_beam((-0.45, 0.0, top), (-1.6, 0.0, 0.2), 0.12, COPPER_MUTED)
    b.add_box((2.4, 2.4, 0.2), loc=(-2.2, 0.0, 0.05), color=mix_hex(COPPER_MUTED, CHARCOAL, 0.35))
    b.add_box((2.8, 2.8, 0.5), loc=(0.0, 0.0, 0.1), color=IRON)
    b.to_object(root)
    return export_glb(root, out_root / "highdraft/w3_lightning_rod.glb", (2400, 4800, 1))


def build_kite_ring(out_root: Path):
    common.reset()
    root = common.empty("w3_kite_ring")
    b = Builder("KiteRing", "steel", rough=0.88, metal=0.05)
    b.add_torus(7.0, 0.28, 0.0, [CHARCOAL, OCHRE, CHARCOAL, BONE], segs=32, tube=6)
    for k in range(4):
        a = k * math.tau / 4 + math.pi / 4
        cx, cy = math.cos(a) * 7.0, math.sin(a) * 7.0
        kx, ky = math.cos(a) * 8.6, math.sin(a) * 8.6
        b.add_beam((cx, cy, 0.0), (kx, ky, 3.4), 0.05, CABLE)
        b.add_box((1.3, 0.12, 1.3), loc=(kx, ky, 4.0), rot=(0.0, math.pi / 4, a), color=OCHRE)
        b.add_box((1.0, 0.14, 1.0), loc=(kx, ky, 4.0), rot=(0.0, math.pi / 4, a + math.pi / 2), color=BONE)
        b.add_beam((kx, ky, 3.2), (kx, ky, 2.2), 0.04, BONE)
    for k in range(4):
        a = k * math.tau / 4
        b.add_beam((0.0, 0.0, 0.0), (math.cos(a) * 6.8, math.sin(a) * 6.8, 0.0), 0.06, CABLE)
    b.add_cylinder(0.5, -0.2, 0.2, IRON, segs=10)
    b.to_object(root)
    return export_glb(root, out_root / "highdraft/w3_kite_ring.glb", (2400, 4800, 1))


def build_deck_post(out_root: Path):
    common.reset()
    root = common.empty("w3_deck_post")
    b = Builder("DeckPost", "steel", rough=0.7, metal=0.3)
    b.add_box((0.9, 0.7, 0.24), loc=(0.0, 0.0, 0.1), color=IRON)
    b.add_box((0.44, 0.36, 1.5), loc=(0.0, 0.0, 0.85), color=mix_hex(IRON, CHARCOAL, 0.5))
    b.add_box((0.52, 0.44, 0.12), loc=(0.0, 0.0, 0.62), color=COPPER_MUTED)
    b.add_box((0.6, 0.5, 0.28), loc=(0.0, 0.0, 1.2), color=OCHRE)
    b.add_box((0.5, 0.42, 0.3), loc=(0.0, -0.04, 1.62), rot=(0.25, 0.0, 0.0), color=CHARCOAL)
    b.to_object(root)
    return export_glb(root, out_root / "highdraft/w3_deck_post.glb", (400, 800, 1))


def main():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    ap = argparse.ArgumentParser()
    ap.add_argument("--out-root", type=Path, default=MODELS)
    args = ap.parse_args(argv)
    out = [
        build_shiprock_dike(args.out_root),
        build_tram_tower(args.out_root),
        build_ore_bucket(args.out_root),
        build_balanced_hoodoo(args.out_root),
        build_lightning_rod(args.out_root),
        build_kite_ring(args.out_root),
        build_deck_post(args.out_root),
    ]
    print("W49_KIT_DONE", len(out))


if __name__ == "__main__":
    main()
