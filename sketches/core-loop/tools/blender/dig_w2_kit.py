"""World 2 (The Dig) curated valley & Waking boss dressing kit (W48-MAPS).

Blender 5.3.0 headless build (metres, +Y up in glTF, no external textures):
  blender -b --factory-startup --threads 2 --python-exit-code 1 \
    --python sketches/core-loop/tools/blender/dig_w2_kit.py -- [--out-root DIR]

Visual Canon Guards enforced in geometry & vertex colours:
  - Guard 1: Old Works petrol strictly Palette.VERDIGRIS #365754 + uranium-glass
    green #9DFF3C (Palette.ANCIENT) seams ONLY — NEVER brass (#d9b44a).
  - Guard 3: ZERO 45-degree HAZARD (#ff5a3c) stripes on static Waking collapsing
    shaft rims — static rims use AMBER (#e5a044), bone (#d2c5a5), and charcoal
    (#242a28) exclusively.

Exports 7 GLBs under sketches/core-loop/assets/models/:
  dig_stone/moab_arch.glb
  dig_stone/copper_vein_face.glb
  dig_stone/basalt_column_rib.glb
  dig_mechanical/timber_rock_strut.glb
  bosses/waking_drill_crown.glb
  bosses/waking_hatch_frame.glb
  bosses/waking_rim_coping.glb
"""

import argparse
import hashlib
import json
import math
import os
from pathlib import Path
import struct
import sys

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))

import bmesh  # noqa: E402
import bpy  # noqa: E402
from mathutils import Euler, Matrix, Vector  # noqa: E402

import common  # noqa: E402

SKETCH = HERE.parents[1]
MODELS = SKETCH / "assets/models"

# Palette constants matching src/core/palette.gd (strictly zero brass, zero hazard).
PETROL = "365754"       # Palette.VERDIGRIS
ANCIENT = "9dff3c"      # Palette.ANCIENT
BONE = "d2c5a5"         # Palette.SAND
SANDSTONE = "c6a274"    # Palette.SANDSTONE
RUST = "9b513a"         # Palette.RUST (Moab red-rock strata)
COPPER = "b77843"       # Palette.COPPER (weathered timber / earth)
CHARCOAL = "242a28"     # Palette.CHARCOAL
AMBER = "e5a044"        # Palette.AMBER (static rim coping trim — never HAZARD!)
TURQ_PATINA = "42b8a8"  # Oxidized copper turquoise patina (w2-dig-pit-sinkhole.png)
TURQ_DEEP = "2d7f76"    # Deep oxidized copper streak
BASALT_DARK = "1e2326"  # El Malpais volcanic basalt core
BASALT_EDGE = "3c454a"  # Basalt fractured edge highlight
TIMBER_DARK = "5b3c26"  # Aged mine cribbing timber
TIMBER_LIGHT = "7d5436" # Sun-bleached timber edge


def srgb(h):
    return tuple(int(h[i:i + 2], 16) / 255.0 for i in (0, 2, 4))


def mix_hex(a, b, t):
    ca, cb = srgb(a), srgb(b)
    return tuple(ca[i] + (cb[i] - ca[i]) * t for i in range(3))


def ensure_vc_material(name, rough=0.84, metal=0.0, emit_hex=None, emit_strength=0.0):
    mat = bpy.data.materials.get(name)
    if mat is not None:
        return mat
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    nodes = mat.node_tree.nodes
    bsdf = nodes.get("Principled BSDF")
    bsdf.inputs["Roughness"].default_value = rough
    bsdf.inputs["Metallic"].default_value = metal
    if emit_hex is not None:
        lin = common.rgba(srgb(emit_hex))
        bsdf.inputs["Base Color"].default_value = lin
        bsdf.inputs["Emission Color"].default_value = lin
        bsdf.inputs["Emission Strength"].default_value = emit_strength
    else:
        attr = nodes.new("ShaderNodeVertexColor")
        attr.layer_name = "Color"
        mat.node_tree.links.new(attr.outputs["Color"], bsdf.inputs["Base Color"])
    return mat


class Builder:
    """Clean bmesh builder in Blender Z-up (export_yup maps Z->Y, -Y->Z)."""

    def __init__(self, name, material_name, rough=0.84, metal=0.0, emit_hex=None, emit_strength=0.0):
        self.name = name
        self.material_name = material_name
        self.rough = rough
        self.metal = metal
        self.emit_hex = emit_hex
        self.emit_strength = emit_strength
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

    def add_prism(self, ring_bot, ring_top, color=BONE, side_color=None, cap_bot=True, cap_top=True):
        """Loft between two same-length 3D point loops."""
        n = len(ring_bot)
        vb = [self.bm.verts.new(Vector(p)) for p in ring_bot]
        vt = [self.bm.verts.new(Vector(p)) for p in ring_top]
        side_faces = []
        for i in range(n):
            j = (i + 1) % n
            f = self.bm.faces.new((vb[i], vb[j], vt[j], vt[i]))
            side_faces.append(f)
        self._paint(side_faces, side_color if side_color is not None else color)
        caps = []
        if cap_bot:
            caps.append(self.bm.faces.new(list(reversed(vb))))
        if cap_top:
            caps.append(self.bm.faces.new(vt))
        if caps:
            self._paint(caps, color)
        return side_faces + caps

    def add_tube(self, rings, colors, closed_ends=True):
        """Loft a sequence of cross-section loops; colors is list of len(rings)-1."""
        vrings = [[self.bm.verts.new(Vector(p)) for p in r] for r in rings]
        n = len(rings[0])
        for s in range(len(rings) - 1):
            r0, r1 = vrings[s], vrings[s + 1]
            c = colors[s]
            seg_faces = []
            for i in range(n):
                j = (i + 1) % n
                seg_faces.append(self.bm.faces.new((r0[i], r0[j], r1[j], r1[i])))
            self._paint(seg_faces, c)
        if closed_ends:
            f0 = self.bm.faces.new(list(reversed(vrings[0])))
            f1 = self.bm.faces.new(vrings[-1])
            self._paint([f0], colors[0])
            self._paint([f1], colors[-1])

    def to_object(self, parent):
        bmesh.ops.recalc_face_normals(self.bm, faces=list(self.bm.faces))
        bmesh.ops.triangulate(self.bm, faces=list(self.bm.faces), quad_method="FIXED", ngon_method="BEAUTY")
        mesh = bpy.data.meshes.new(self.name)
        self.bm.to_mesh(mesh)
        self.bm.free()
        # Keep ONLY our painted "Color" attribute so glTF exports it as COLOR_0 (never COLOR_1!).
        for ca in list(mesh.color_attributes):
            if ca.name != "Color":
                mesh.color_attributes.remove(ca)
        if len(mesh.color_attributes) > 0:
            mesh.color_attributes.active_color_index = 0
            mesh.color_attributes.render_color_index = 0
        mesh.materials.append(
            ensure_vc_material(self.material_name, self.rough, self.metal, self.emit_hex, self.emit_strength)
        )
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
            assert "COLOR_1" not in attrs, (path.name, attrs)
            tris += gltf["accessors"][p["indices"]]["count"] // 3
            verts += gltf["accessors"][attrs["POSITION"]]["count"]
            draws += 1
    assert 0 < tris <= caps[0] and verts <= caps[1] and draws <= caps[2], (path.name, tris, verts, draws, caps)
    info = {
        "file": path.name,
        "tris": tris,
        "verts": verts,
        "draws": draws,
        "bytes": len(blob),
        "sha256": hashlib.sha256(blob).hexdigest(),
    }
    print("W48_GLB", json.dumps(info, sort_keys=True))
    return info


# 1. Utah Moab natural sandstone arch (22 m span, 14 m peak, stratified red-rock)
def build_moab_arch(out_root: Path):
    common.reset()
    root = common.empty("moab_arch")
    b = Builder("MoabArch", "moab_stone", rough=0.90)
    steps = 14
    rings = []
    colors = []
    span_half = 11.5
    peak_h = 13.5
    strata = [RUST, mix_hex(RUST, SANDSTONE, 0.55), SANDSTONE, mix_hex(SANDSTONE, BONE, 0.45), SANDSTONE, RUST]
    for s in range(steps + 1):
        u = s / steps
        ang = math.pi * u  # 0 (right foot) -> pi (left foot)
        cx = math.cos(ang) * span_half
        cz = max(-1.2, math.sin(ang) * peak_h - 0.8)
        # Thicker abutments at feet, sculpted thinner bridge span at crown.
        foot_w = 1.0 + 1.35 * (abs(math.cos(ang)) ** 1.6)
        half_t = 1.9 * foot_w
        half_d = 2.6 * (0.85 + 0.55 * abs(math.cos(ang)))
        # Outward radial direction in XZ plane for arch rib section.
        rx = math.cos(ang)
        rz = math.sin(ang)
        # 8-sided chamfered sandstone rib cross-section with strata shelf steps.
        profile = [
            (-1.0, -0.55), (-0.6, -1.0), (0.6, -1.0), (1.0, -0.55),
            (1.0, 0.55), (0.55, 1.0), (-0.55, 1.0), (-1.0, 0.55),
        ]
        jitter = 1.0 + 0.08 * math.sin(s * 2.3)
        ring = []
        for py, pr in profile:
            y = py * half_d * jitter
            radial = pr * half_t * (1.0 + 0.07 * math.cos(s * 1.7 + py))
            ring.append((cx + rx * radial, y, cz + rz * radial))
        rings.append(ring)
        if s < steps:
            colors.append(strata[s % len(strata)])
    b.add_tube(rings, colors, closed_ends=True)
    # Sculpted stratified abutment ledges at both feet so arch anchors visually into canyon rim.
    for side in (-1.0, 1.0):
        b.add_box((5.6, 6.2, 3.2), loc=(side * 12.2, 0.0, 0.6), color=RUST)
        b.add_box((4.4, 5.0, 2.2), loc=(side * 11.4, 0.3, 3.0), color=mix_hex(RUST, SANDSTONE, 0.45))
        b.add_box((3.2, 4.0, 1.4), loc=(side * 10.6, -0.2, 4.6), color=SANDSTONE)
    b.to_object(root)
    return export_glb(root, out_root / "dig_stone/moab_arch.glb", (8000, 16000, 2))


# 2. Oxidized turquoise-patina copper bench face (w2-dig-pit-sinkhole.png signature)
def build_copper_vein_face(out_root: Path):
    common.reset()
    root = common.empty("copper_vein_face")
    b = Builder("CopperVeinFace", "copper_stone", rough=0.86)
    # Pale stepped Moab sandstone bench face backing (14 m wide x 10 m tall).
    b.add_box((14.0, 1.6, 3.2), loc=(0.0, 0.4, 1.6), color=mix_hex(SANDSTONE, BONE, 0.35))
    b.add_box((13.4, 1.8, 3.4), loc=(0.0, 0.6, 4.8), color=SANDSTONE)
    b.add_box((14.2, 1.4, 3.0), loc=(0.0, 0.3, 8.0), color=mix_hex(SANDSTONE, BONE, 0.50))
    # Horizontal oxidized copper ore seam bands + dripping turquoise patina streaks.
    b.add_box((13.6, 0.45, 0.9), loc=(0.0, -0.45, 7.2), color=TURQ_PATINA)
    b.add_box((11.2, 0.40, 0.65), loc=(-0.8, -0.42, 4.1), color=TURQ_DEEP)
    streak_specs = [
        (-4.6, 1.6, 5.4, 4.6, TURQ_PATINA),
        (-2.1, 1.2, 4.2, 5.2, TURQ_DEEP),
        (0.5, 2.2, 6.2, 4.2, TURQ_PATINA),
        (3.4, 1.4, 4.8, 4.8, TURQ_PATINA),
        (5.2, 1.0, 3.2, 5.5, TURQ_DEEP),
    ]
    for sx, sw, sh, sz, col in streak_specs:
        b.add_box((sw, 0.42, sh), loc=(sx, -0.52, sz), color=col)
    # Foot scree boulders (cinder-red sandstone + patina chips).
    b.add_box((2.4, 1.6, 1.2), loc=(-4.5, -0.8, 0.5), rot=(0.1, 0.0, 0.25), color=RUST)
    b.add_box((2.0, 1.4, 1.0), loc=(3.8, -0.9, 0.4), rot=(-0.05, 0.1, -0.3), color=mix_hex(RUST, SANDSTONE, 0.4))
    b.to_object(root)
    return export_glb(root, out_root / "dig_stone/copper_vein_face.glb", (8000, 16000, 2))


# 3. NM El Malpais hexagonal black volcanic basalt column cluster & arch rib
def build_basalt_column_rib(out_root: Path):
    common.reset()
    root = common.empty("basalt_column_rib")
    b = Builder("BasaltColumnRib", "basalt_stone", rough=0.88)
    columns = [
        (-2.4, -0.4, 0.95, 6.8, 0.05, BASALT_DARK),
        (-1.1, 0.3, 1.15, 9.2, -0.04, BASALT_EDGE),
        (0.2, -0.2, 1.25, 11.4, 0.02, BASALT_DARK),
        (1.6, 0.4, 1.05, 8.6, -0.06, CHARCOAL),
        (2.8, -0.3, 0.90, 5.8, 0.08, BASALT_EDGE),
        (-1.6, -1.2, 0.80, 4.2, 0.10, CHARCOAL),
        (1.2, -1.1, 0.85, 4.8, -0.09, BASALT_DARK),
    ]
    for cx, cy, r, h, lean, col in columns:
        bot = [(cx + r * math.cos(k * math.tau / 6.0), cy + r * math.sin(k * math.tau / 6.0), -0.6) for k in range(6)]
        top = [(cx + lean * h + r * 0.92 * math.cos(k * math.tau / 6.0),
                cy + r * 0.92 * math.sin(k * math.tau / 6.0), h) for k in range(6)]
        b.add_prism(bot, top, color=mix_hex(BASALT_EDGE, BONE, 0.12), side_color=col)
    b.to_object(root)
    return export_glb(root, out_root / "dig_stone/basalt_column_rib.glb", (8000, 16000, 2))


# 4. Utah Moab grapple-pullable unstable timber/rock support strut (g14 row 1)
def build_timber_rock_strut(out_root: Path):
    common.reset()
    root = common.empty("timber_rock_strut")
    b = Builder("TimberRockStrut", "steel", rough=0.84, metal=0.14)
    # Twin splayed heavy mine timber posts (3.6 m clear opening for ball / enemy lane).
    b.add_box((0.55, 0.55, 5.2), loc=(-2.2, 0.0, 2.5), rot=(0.0, 0.08, 0.0), color=TIMBER_DARK)
    b.add_box((0.55, 0.55, 5.2), loc=(2.2, 0.0, 2.5), rot=(0.0, -0.08, 0.0), color=TIMBER_DARK)
    # Diagonal knee braces & heavy timber cap lintel.
    b.add_box((5.6, 0.65, 0.65), loc=(0.0, 0.0, 5.05), color=TIMBER_LIGHT)
    b.add_box((0.35, 0.35, 2.1), loc=(-1.35, 0.0, 4.1), rot=(0.0, 0.78, 0.0), color=TIMBER_LIGHT)
    b.add_box((0.35, 0.35, 2.1), loc=(1.35, 0.0, 4.1), rot=(0.0, -0.78, 0.0), color=TIMBER_LIGHT)
    # Bolted charcoal iron gusset brackets + grapple pull ring lug in AMBER/bone (never brass/hazard!).
    for sx in (-1.95, 1.95):
        b.add_box((0.85, 0.78, 0.78), loc=(sx, 0.0, 5.05), color=CHARCOAL)
        b.add_box((0.78, 0.72, 0.45), loc=(sx * 1.12, 0.0, 0.25), color=CHARCOAL)
    b.add_box((0.45, 0.90, 0.45), loc=(0.0, -0.45, 5.05), color=AMBER)
    # Unstable wedged Moab red-rock keystone boulders perched atop the timber cap!
    b.add_box((2.4, 1.9, 1.5), loc=(-1.1, 0.1, 6.05), rot=(0.08, 0.12, 0.2), color=RUST)
    b.add_box((2.6, 2.1, 1.7), loc=(1.0, -0.1, 6.15), rot=(-0.06, -0.14, -0.18), color=mix_hex(RUST, SANDSTONE, 0.45))
    b.add_box((1.8, 1.5, 1.2), loc=(0.0, 0.0, 7.15), rot=(0.12, 0.05, 0.35), color=SANDSTONE)
    b.to_object(root)
    return export_glb(root, out_root / "dig_mechanical/timber_rock_strut.glb", (1200, 2400, 2))


# 5. The Waking cast petrol-enamel excavator drill crown + uranium-green seams (w2-boss-the-waking.png & g08)
def build_waking_drill_crown(out_root: Path):
    common.reset()
    root = common.empty("waking_drill_crown")
    enamel = Builder("WakingCrownBody", "ancient_enamel", rough=0.62, metal=0.12)
    seams = Builder("WakingCrownSeams", "ancient_light", rough=0.25, metal=0.0, emit_hex=ANCIENT, emit_strength=3.2)

    # Domed cast petrol-enamel excavator crown collar (sits around CombatSeat / CoreSocket, clear of WeakPoint core).
    # Lower cast shoulder collar (z 1.4..2.8) + 8 heavy chamfered excavator cutter ribs curving up to z 6.6.
    segs = 16
    r_in, r_out = 2.05, 2.75
    bot_in = [(r_in * math.cos(k * math.tau / segs), r_in * math.sin(k * math.tau / segs), 1.35) for k in range(segs)]
    top_out = [(r_out * math.cos(k * math.tau / segs), r_out * math.sin(k * math.tau / segs), 2.35) for k in range(segs)]
    enamel.add_prism(bot_in, top_out, color=mix_hex(PETROL, CHARCOAL, 0.25), side_color=PETROL, cap_bot=False, cap_top=False)

    for i in range(8):
        a = i * math.tau / 8.0
        ca, sa = math.cos(a), math.sin(a)
        # Stepped cast petrol-enamel drill rib blades (matching w2-boss-the-waking.png drill crown).
        enamel.add_box((0.55, 0.62, 2.2), loc=(ca * 2.55, sa * 2.55, 2.65), rot=(0.0, 0.0, a), color=PETROL)
        enamel.add_box((0.46, 0.50, 1.8), loc=(ca * 2.25, sa * 2.25, 4.45), rot=(0.0, -0.22, a), color=mix_hex(PETROL, BONE, 0.14))
        # Cast charcoal cutter teeth along rib spine (zero brass!).
        for zt in (2.1, 3.1, 4.2):
            rt = 2.88 if zt < 3.5 else 2.58
            enamel.add_box((0.28, 0.34, 0.32), loc=(ca * rt, sa * rt, zt), rot=(0.0, 0.0, a), color=CHARCOAL)
        # Uranium-glass green (#9DFF3C) recessed vertical seam strip between ribs!
        sa_mid = a + math.tau / 16.0
        cm, sm = math.cos(sa_mid), math.sin(sa_mid)
        seams.add_box((0.12, 0.14, 3.1), loc=(cm * 2.42, sm * 2.42, 3.25), rot=(0.0, -0.08, sa_mid), color=ANCIENT)

    # Upper crown uranium-green harmonic ring (z 5.45, clear of 2.6 m CoreSocket aperture).
    for i in range(12):
        a = i * math.tau / 12.0
        seams.add_box((0.14, 0.56, 0.14), loc=(math.cos(a) * 1.92, math.sin(a) * 1.92, 5.45), rot=(0.0, 0.0, a), color=ANCIENT)

    enamel.to_object(root)
    seams.to_object(root)
    return export_glb(root, out_root / "bosses/waking_drill_crown.glb", (4000, 8000, 2))


# 6. The Waking sculpted service hatch surround (replaces greybox WeakPart BoxMeshes; Guard 1 & 3 compliant)
def build_waking_hatch_frame(out_root: Path):
    common.reset()
    root = common.empty("waking_hatch_frame")
    body = Builder("WakingHatchBody", "ancient_enamel", rough=0.68, metal=0.18)
    seams = Builder("WakingHatchSeams", "ancient_light", rough=0.25, metal=0.0, emit_hex=ANCIENT, emit_strength=2.6)

    # Heavy cast petrol-enamel bevelled bulkhead surround matching WeakPart.SIZE (3.2 x 2.4 x 0.8 m).
    # Godot -Z is Blender +Y, so the front face sits toward Blender +Y.
    body.add_box((4.1, 0.85, 0.42), loc=(0.0, 0.05, 1.42), color=PETROL)
    body.add_box((4.1, 0.85, 0.42), loc=(0.0, 0.05, -1.42), color=PETROL)
    body.add_box((0.46, 0.85, 2.42), loc=(-1.82, 0.05, 0.0), color=PETROL)
    body.add_box((0.46, 0.85, 2.42), loc=(1.82, 0.05, 0.0), color=PETROL)
    # Recessed charcoal inner clamp flange + corner cast lugs (zero brass, zero hazard stripes!).
    body.add_box((3.4, 0.55, 0.18), loc=(0.0, 0.25, 1.18), color=CHARCOAL)
    body.add_box((3.4, 0.55, 0.18), loc=(0.0, 0.25, -1.18), color=CHARCOAL)
    for sx in (-1.82, 1.82):
        for sz in (-1.35, 1.35):
            body.add_box((0.62, 0.96, 0.52), loc=(sx, 0.12, sz), color=mix_hex(PETROL, BONE, 0.16))
            seams.add_box((0.18, 0.10, 0.34), loc=(sx * 0.86, 0.52, sz * 0.78), color=ANCIENT)

    body.to_object(root)
    seams.to_object(root)
    return export_glb(root, out_root / "bosses/waking_hatch_frame.glb", (1200, 2400, 2))


# 7. The Waking collapsing shaft rim coping (Guard 3: strictly AMBER/bone/charcoal — ZERO 45-deg HAZARD stripes!)
def build_waking_rim_coping(out_root: Path):
    common.reset()
    root = common.empty("waking_rim_coping")
    b = Builder("WakingRimCoping", "steel", rough=0.78, metal=0.18)
    # 15-degree curved coping block seated along r = 35.6..36.4 at top of quarter-pipe rim bank.
    # Strictly horizontal cast steel plates in CHARCOAL + BONE lip + clean AMBER indicator key blocks (NO 45-deg HAZARD!).
    steps = 6
    a0 = math.radians(0.25)
    a1 = math.radians(14.75)
    rings = []
    colors = []
    # Cross section (radius, z_offset)
    profile = [(35.55, 0.0), (36.35, 0.0), (36.45, 0.55), (35.95, 0.85), (35.45, 0.55)]
    for s in range(steps + 1):
        a = a0 + (a1 - a0) * (s / steps)
        ca, sa = math.cos(a), math.sin(a)
        rings.append([(r * ca, r * sa, z) for r, z in profile])
        if s < steps:
            # Clean orthogonal coping bays: charcoal plate, bone lip, central warm AMBER (#e5a044) key block.
            if s in (2, 3):
                colors.append(AMBER)
            elif s in (1, 4):
                colors.append(BONE)
            else:
                colors.append(CHARCOAL)
    b.add_tube(rings, colors, closed_ends=True)
    b.to_object(root)
    return export_glb(root, out_root / "bosses/waking_rim_coping.glb", (800, 1600, 1))


def main():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    ap = argparse.ArgumentParser()
    ap.add_argument("--out-root", type=Path, default=MODELS)
    args = ap.parse_args(argv)
    out = [
        build_moab_arch(args.out_root),
        build_copper_vein_face(args.out_root),
        build_basalt_column_rib(args.out_root),
        build_timber_rock_strut(args.out_root),
        build_waking_drill_crown(args.out_root),
        build_waking_hatch_frame(args.out_root),
        build_waking_rim_coping(args.out_root),
    ]
    print("W48_KIT_DONE", len(out))


if __name__ == "__main__":
    main()
